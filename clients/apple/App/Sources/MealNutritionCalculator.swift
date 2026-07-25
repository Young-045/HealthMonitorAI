import Foundation
import HealthMonitorCore

enum MealNutritionCalculatorError: Error, Equatable {
    case invalidSnapshot(itemID: UUID)
}

enum MealNutritionCalculator {
    static func calculate(foodItems: [MealFoodItem]) throws -> NutritionCalculationResult {
        let portions = try foodItems.map { item in
            guard item.weightGrams.isFinite,
                  item.nutrientsPer100Grams.isValid else {
                throw MealNutritionCalculatorError.invalidSnapshot(itemID: item.id)
            }
            return NutritionPortionInput(
                lineIdentifier: item.id.uuidString,
                foodIdentifier: item.catalogIdentifierSnapshot,
                foodName: item.foodNameSnapshot,
                weightGrams: decimal(item.weightGrams),
                nutrientsPer100Grams: item.nutrientsPer100Grams.coreFacts,
                sourceDataVersion: item.sourceDataVersion
            )
        }
        return try NutritionEngine.calculate(portions: portions)
    }

    static func recalculate(_ meal: MealRecord) throws {
        let result = try calculate(foodItems: meal.foodItems)
        meal.calories = double(result.total.energyKilocalories)
        meal.proteinGrams = double(result.total.proteinGrams)
        meal.carbohydrateGrams = double(result.total.carbohydrateGrams)
        meal.fatGrams = double(result.total.fatGrams)
        meal.fiberGrams = double(result.total.fiberGrams)
        meal.sugarGrams = double(result.total.sugarGrams)
        meal.sodiumMilligrams = double(result.total.sodiumMilligrams)
        meal.nutritionAlgorithmVersion = result.algorithmVersion
    }

    private static func decimal(_ value: Double) -> Decimal {
        Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) ?? .nan
    }

    private static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}

private extension NutrientProfile {
    var coreFacts: NutritionFacts {
        NutritionFacts(
            energyKilocalories: decimal(energyKilocalories),
            proteinGrams: decimal(proteinGrams),
            carbohydrateGrams: decimal(carbohydrateGrams),
            fatGrams: decimal(fatGrams),
            fiberGrams: decimal(fiberGrams),
            sugarGrams: decimal(sugarGrams),
            sodiumMilligrams: decimal(sodiumMilligrams)
        )
    }

    private func decimal(_ value: Double) -> Decimal {
        Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) ?? .nan
    }
}
