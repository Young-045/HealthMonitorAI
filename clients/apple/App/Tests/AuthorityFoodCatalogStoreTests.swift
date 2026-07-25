import XCTest
@testable import HealthMonitorAI

final class AuthorityFoodCatalogStoreTests: XCTestCase {
    func testBundledCatalogOpensAndReportsVersion() throws {
        let store = try XCTUnwrap(AuthorityFoodCatalogStore.bundled)
        XCTAssertEqual(store.catalogVersion, "2026-04+pipeline.1")
    }

    func testExactUSDANameReturnsVersionedNutrients() throws {
        let store = try XCTUnwrap(AuthorityFoodCatalogStore.bundled)
        let item = try XCTUnwrap(store.exactMatch(
            name: "Hummus, commercial",
            locale: Locale(identifier: "en_US")
        ))

        XCTAssertEqual(item.sourceCode, "usda-foundation")
        XCTAssertEqual(item.sourceRelease, "2026-04")
        XCTAssertEqual(item.nutrients["energy_kcal"], 229)
    }

    func testMEXTMissingSugarDoesNotBecomeZeroOrCompleteProfile() throws {
        let store = try XCTUnwrap(AuthorityFoodCatalogStore.bundled)
        let item = try XCTUnwrap(store.exactMatch(
            name: "アマランサス　玄穀",
            locale: Locale(identifier: "ja_JP")
        ))

        XCTAssertEqual(item.sourceCode, "mext-2020")
        XCTAssertNil(item.nutrients["sugars_g"])
        XCTAssertNil(item.nutrientsPer100Grams)
    }
}
