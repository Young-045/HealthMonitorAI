import Foundation
import SwiftData

enum FoodCategory: String, CaseIterable, Codable, Sendable {
    case staple
    case protein
    case vegetable
    case fruit
    case dairy
    case fatAndOil
    case beverage
    case preparedDish
    case condiment
    case other
}

struct NutrientProfile: Codable, Equatable, Sendable {
    let energyKilocalories: Double
    let proteinGrams: Double
    let carbohydrateGrams: Double
    let fatGrams: Double
    let fiberGrams: Double
    let sugarGrams: Double
    let sodiumMilligrams: Double

    static let zero = NutrientProfile(
        energyKilocalories: 0,
        proteinGrams: 0,
        carbohydrateGrams: 0,
        fatGrams: 0,
        fiberGrams: 0,
        sugarGrams: 0,
        sodiumMilligrams: 0
    )

    var isValid: Bool {
        values.allSatisfy { $0.isFinite && $0 >= 0 }
    }

    private var values: [Double] {
        [
            energyKilocalories,
            proteinGrams,
            carbohydrateGrams,
            fatGrams,
            fiberGrams,
            sugarGrams,
            sodiumMilligrams
        ]
    }
}

@Model
final class FoodCatalogItem {
    @Attribute(.unique) var catalogIdentifier: String
    var name: String
    var aliasesStorage: String
    var categoryRawValue: String
    var defaultServingGrams: Double?
    var energyKilocaloriesPer100Grams: Double
    var proteinGramsPer100Grams: Double
    var carbohydrateGramsPer100Grams: Double
    var fatGramsPer100Grams: Double
    var fiberGramsPer100Grams: Double
    var sugarGramsPer100Grams: Double
    var sodiumMilligramsPer100Grams: Double
    var sourceName: String
    var dataVersion: String
    var isUserCreated: Bool
    var updatedAt: Date

    init(
        catalogIdentifier: String,
        name: String,
        aliases: [String] = [],
        category: FoodCategory,
        defaultServingGrams: Double? = nil,
        nutrientsPer100Grams: NutrientProfile,
        sourceName: String,
        dataVersion: String,
        isUserCreated: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.catalogIdentifier = catalogIdentifier
        self.name = name
        aliasesStorage = Self.encodeAliases(aliases)
        categoryRawValue = category.rawValue
        self.defaultServingGrams = defaultServingGrams
        energyKilocaloriesPer100Grams = nutrientsPer100Grams.energyKilocalories
        proteinGramsPer100Grams = nutrientsPer100Grams.proteinGrams
        carbohydrateGramsPer100Grams = nutrientsPer100Grams.carbohydrateGrams
        fatGramsPer100Grams = nutrientsPer100Grams.fatGrams
        fiberGramsPer100Grams = nutrientsPer100Grams.fiberGrams
        sugarGramsPer100Grams = nutrientsPer100Grams.sugarGrams
        sodiumMilligramsPer100Grams = nutrientsPer100Grams.sodiumMilligrams
        self.sourceName = sourceName
        self.dataVersion = dataVersion
        self.isUserCreated = isUserCreated
        self.updatedAt = updatedAt
    }

    var aliases: [String] {
        Self.decodeAliases(aliasesStorage)
    }

    var category: FoodCategory {
        FoodCategory(rawValue: categoryRawValue) ?? .other
    }

    var nutrientsPer100Grams: NutrientProfile {
        NutrientProfile(
            energyKilocalories: energyKilocaloriesPer100Grams,
            proteinGrams: proteinGramsPer100Grams,
            carbohydrateGrams: carbohydrateGramsPer100Grams,
            fatGrams: fatGramsPer100Grams,
            fiberGrams: fiberGramsPer100Grams,
            sugarGrams: sugarGramsPer100Grams,
            sodiumMilligrams: sodiumMilligramsPer100Grams
        )
    }

    private static func encodeAliases(_ aliases: [String]) -> String {
        aliases
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, alias in
                if !result.contains(alias) { result.append(alias) }
            }
            .joined(separator: "\n")
    }

    private static func decodeAliases(_ storage: String) -> [String] {
        storage.split(separator: "\n").map(String.init)
    }
}

@Model
final class MealFoodItem {
    @Attribute(.unique) var id: UUID
    var catalogIdentifierSnapshot: String?
    var foodNameSnapshot: String
    var weightGrams: Double
    var servingDescription: String
    var cookingMethod: String
    var energyKilocaloriesPer100Grams: Double
    var proteinGramsPer100Grams: Double
    var carbohydrateGramsPer100Grams: Double
    var fatGramsPer100Grams: Double
    var fiberGramsPer100Grams: Double
    var sugarGramsPer100Grams: Double
    var sodiumMilligramsPer100Grams: Double
    var sourceDataVersion: String
    var createdAt: Date
    var meal: MealRecord?

    init(
        id: UUID = UUID(),
        catalogIdentifierSnapshot: String?,
        foodNameSnapshot: String,
        weightGrams: Double,
        servingDescription: String = "",
        cookingMethod: String = "",
        nutrientsPer100Grams: NutrientProfile,
        sourceDataVersion: String,
        createdAt: Date = Date(),
        meal: MealRecord? = nil
    ) {
        self.id = id
        self.catalogIdentifierSnapshot = catalogIdentifierSnapshot
        self.foodNameSnapshot = foodNameSnapshot
        self.weightGrams = weightGrams
        self.servingDescription = servingDescription
        self.cookingMethod = cookingMethod
        energyKilocaloriesPer100Grams = nutrientsPer100Grams.energyKilocalories
        proteinGramsPer100Grams = nutrientsPer100Grams.proteinGrams
        carbohydrateGramsPer100Grams = nutrientsPer100Grams.carbohydrateGrams
        fatGramsPer100Grams = nutrientsPer100Grams.fatGrams
        fiberGramsPer100Grams = nutrientsPer100Grams.fiberGrams
        sugarGramsPer100Grams = nutrientsPer100Grams.sugarGrams
        sodiumMilligramsPer100Grams = nutrientsPer100Grams.sodiumMilligrams
        self.sourceDataVersion = sourceDataVersion
        self.createdAt = createdAt
        self.meal = meal
    }

    var nutrientsPer100Grams: NutrientProfile {
        NutrientProfile(
            energyKilocalories: energyKilocaloriesPer100Grams,
            proteinGrams: proteinGramsPer100Grams,
            carbohydrateGrams: carbohydrateGramsPer100Grams,
            fatGrams: fatGramsPer100Grams,
            fiberGrams: fiberGramsPer100Grams,
            sugarGrams: sugarGramsPer100Grams,
            sodiumMilligrams: sodiumMilligramsPer100Grams
        )
    }
}
