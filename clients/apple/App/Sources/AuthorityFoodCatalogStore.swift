import Foundation
import SQLite3

struct AuthorityFoodCatalogItem: Equatable, Sendable {
    let identifier: String
    let name: String
    let sourceCode: String
    let sourceRelease: String
    let foodState: String
    let nutrients: [String: Double]

    var sourceDisplayName: String {
        switch sourceCode {
        case "mext-2020": "日本文部科学省"
        case "usda-foundation": "USDA Foundation Foods"
        default: sourceCode
        }
    }

    var nutrientsPer100Grams: NutrientProfile? {
        guard let energy = nutrients["energy_kcal"],
              let protein = nutrients["protein_g"],
              let carbohydrate = nutrients["carbohydrate_g"],
              let fat = nutrients["fat_g"],
              let fiber = nutrients["fiber_g"],
              let sugar = nutrients["sugars_g"],
              let sodium = nutrients["sodium_mg"] else {
            return nil
        }
        return NutrientProfile(
            energyKilocalories: energy,
            proteinGrams: protein,
            carbohydrateGrams: carbohydrate,
            fatGrams: fat,
            fiberGrams: fiber,
            sugarGrams: sugar,
            sodiumMilligrams: sodium
        )
    }
}

enum AuthorityFoodCatalogError: Error, Equatable {
    case bundledDatabaseMissing
    case openFailed
    case queryFailed
    case unsupportedSchema
}

final class AuthorityFoodCatalogStore: @unchecked Sendable {
    static let bundled: AuthorityFoodCatalogStore? = try? AuthorityFoodCatalogStore(
        databaseURL: bundledDatabaseURL()
    )

    private let connection: OpaquePointer

    init(databaseURL: URL) throws {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &database, flags, nil) == SQLITE_OK,
              let database else {
            if let database { sqlite3_close(database) }
            throw AuthorityFoodCatalogError.openFailed
        }
        connection = database
        guard metadataValue(for: "schemaVersion") == "1" else {
            sqlite3_close(database)
            throw AuthorityFoodCatalogError.unsupportedSchema
        }
    }

    deinit {
        sqlite3_close(connection)
    }

    var catalogVersion: String? {
        metadataValue(for: "catalogVersion")
    }

    func exactMatch(name: String, locale: Locale = .current) throws -> AuthorityFoodCatalogItem? {
        let normalized = Self.normalized(name)
        guard !normalized.isEmpty else { return nil }

        let preferredSource = locale.language.languageCode?.identifier == "ja"
            ? "mext-2020"
            : "usda-foundation"
        let sql = """
        SELECT f.id, f.canonical_name, f.source_code, f.source_release, f.food_state,
               fn.name_type, n.nutrient_key, n.amount
        FROM food_name fn
        JOIN food f ON f.id = fn.food_id
        LEFT JOIN food_nutrient n ON n.food_id = f.id
        WHERE fn.normalized_name = ?
        ORDER BY CASE WHEN fn.name_type = 'canonical' THEN 0 ELSE 1 END,
                 CASE WHEN f.source_code = ? THEN 0 ELSE 1 END,
                 f.id,
                 n.nutrient_key
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw AuthorityFoodCatalogError.queryFailed
        }
        defer { sqlite3_finalize(statement) }
        Self.bind(normalized, at: 1, to: statement)
        Self.bind(preferredSource, at: 2, to: statement)

        var selectedID: String?
        var selectedName = ""
        var sourceCode = ""
        var sourceRelease = ""
        var foodState = "unknown"
        var nutrients: [String: Double] = [:]

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let identifier = Self.text(statement, column: 0) else { continue }
            if let selectedID, identifier != selectedID { break }
            if selectedID == nil {
                selectedID = identifier
                selectedName = Self.text(statement, column: 1) ?? ""
                sourceCode = Self.text(statement, column: 2) ?? ""
                sourceRelease = Self.text(statement, column: 3) ?? ""
                foodState = Self.text(statement, column: 4) ?? "unknown"
            }
            if let nutrientKey = Self.text(statement, column: 6),
               sqlite3_column_type(statement, 7) != SQLITE_NULL {
                nutrients[nutrientKey] = sqlite3_column_double(statement, 7)
            }
        }
        guard let selectedID else { return nil }
        return AuthorityFoodCatalogItem(
            identifier: selectedID,
            name: selectedName,
            sourceCode: sourceCode,
            sourceRelease: sourceRelease,
            foodState: foodState,
            nutrients: nutrients
        )
    }

    private func metadataValue(for key: String) -> String? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            connection,
            "SELECT value FROM metadata WHERE key = ?",
            -1,
            &statement,
            nil
        ) == SQLITE_OK, let statement else {
            return nil
        }
        defer { sqlite3_finalize(statement) }
        Self.bind(key, at: 1, to: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return Self.text(statement, column: 0)
    }

    private static func bundledDatabaseURL() throws -> URL {
        let bundles = [Bundle.main, Bundle(for: BundleToken.self)]
        for bundle in bundles {
            if let url = bundle.url(
                forResource: "catalog-core",
                withExtension: "sqlite",
                subdirectory: "FoodCatalog"
            ) ?? bundle.url(forResource: "catalog-core", withExtension: "sqlite") {
                return url
            }
        }
        throw AuthorityFoodCatalogError.bundledDatabaseMissing
    }

    private static func bind(_ value: String, at index: Int32, to statement: OpaquePointer) {
        sqlite3_bind_text(
            statement,
            index,
            value,
            -1,
            unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        )
    }

    private static func text(_ statement: OpaquePointer, column: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: pointer)
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }
}

private final class BundleToken {}
