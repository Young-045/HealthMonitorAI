import Foundation

enum UserFoodCatalogDraftError: LocalizedError, Equatable {
    case missingName
    case invalidServing
    case invalidNutrient(String)

    var errorDescription: String? {
        switch self {
        case .missingName: "请填写食物名称。"
        case .invalidServing: "默认份量必须是大于 0 的数字，或留空。"
        case .invalidNutrient(let name): "\(name)必须是大于或等于 0 的数字。"
        }
    }
}

struct UserFoodCatalogDraft {
    var name: String
    var aliases: String
    var category: FoodCategory
    var defaultServingGrams: String
    var energyKilocalories: String
    var proteinGrams: String
    var carbohydrateGrams: String
    var fatGrams: String
    var fiberGrams: String
    var sugarGrams: String
    var sodiumMilligrams: String

    func makeCatalogItem(identifier: UUID = UUID()) throws -> FoodCatalogItem {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { throw UserFoodCatalogDraftError.missingName }

        let serving: Double?
        if defaultServingGrams.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            serving = nil
        } else {
            guard let value = number(defaultServingGrams), value > 0 else {
                throw UserFoodCatalogDraftError.invalidServing
            }
            serving = value
        }

        let nutrients = NutrientProfile(
            energyKilocalories: try requiredNumber(energyKilocalories, name: "热量"),
            proteinGrams: try requiredNumber(proteinGrams, name: "蛋白质"),
            carbohydrateGrams: try requiredNumber(carbohydrateGrams, name: "碳水"),
            fatGrams: try requiredNumber(fatGrams, name: "脂肪"),
            fiberGrams: try requiredNumber(fiberGrams, name: "膳食纤维"),
            sugarGrams: try requiredNumber(sugarGrams, name: "糖"),
            sodiumMilligrams: try requiredNumber(sodiumMilligrams, name: "钠")
        )
        return FoodCatalogItem(
            catalogIdentifier: "user.\(identifier.uuidString.lowercased())",
            name: normalizedName,
            aliases: parsedAliases,
            category: category,
            defaultServingGrams: serving,
            nutrientsPer100Grams: nutrients,
            sourceName: "user",
            dataVersion: "user-v1",
            isUserCreated: true
        )
    }

    private var parsedAliases: [String] {
        aliases
            .components(separatedBy: CharacterSet(charactersIn: "，,、\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func requiredNumber(_ text: String, name: String) throws -> Double {
        guard let value = number(text), value >= 0 else {
            throw UserFoodCatalogDraftError.invalidNutrient(name)
        }
        return value
    }

    private func number(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
}
