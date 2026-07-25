import HealthMonitorCore
import XCTest
@testable import HealthMonitorAI

final class MealNutritionCalculatorTests: XCTestCase {
    func testRecalculateWritesDeterministicTotalsAndVersionToMeal() throws {
        let meal = MealRecord(
            eatenAt: Date(),
            mealType: .lunch,
            foodName: "米饭和鸡胸肉",
            calories: 0,
            proteinGrams: 0,
            carbohydrateGrams: 0,
            fatGrams: 0
        )
        let rice = MealFoodItem(
            catalogIdentifierSnapshot: "rice",
            foodNameSnapshot: "米饭",
            weightGrams: 150,
            nutrientsPer100Grams: NutrientProfile(
                energyKilocalories: 100,
                proteinGrams: 2,
                carbohydrateGrams: 20,
                fatGrams: 1,
                fiberGrams: 1,
                sugarGrams: 0,
                sodiumMilligrams: 2
            ),
            sourceDataVersion: "1",
            meal: meal
        )
        let chicken = MealFoodItem(
            catalogIdentifierSnapshot: "chicken",
            foodNameSnapshot: "鸡胸肉",
            weightGrams: 100,
            nutrientsPer100Grams: NutrientProfile(
                energyKilocalories: 120,
                proteinGrams: 25,
                carbohydrateGrams: 0,
                fatGrams: 2,
                fiberGrams: 0,
                sugarGrams: 0,
                sodiumMilligrams: 50
            ),
            sourceDataVersion: "1",
            meal: meal
        )
        meal.foodItems = [rice, chicken]

        try MealNutritionCalculator.recalculate(meal)

        XCTAssertEqual(meal.calories, 270)
        XCTAssertEqual(meal.proteinGrams, 28)
        XCTAssertEqual(meal.carbohydrateGrams, 30)
        XCTAssertEqual(meal.fatGrams, 3.5)
        XCTAssertEqual(meal.fiberGrams, 1.5)
        XCTAssertEqual(meal.sodiumMilligrams, 53)
        XCTAssertEqual(meal.nutritionAlgorithmVersion, NutritionEngine.algorithmVersion)
    }

    func testInvalidSnapshotIsRejectedBeforeCoreCalculation() {
        let itemID = UUID()
        let item = MealFoodItem(
            id: itemID,
            catalogIdentifierSnapshot: nil,
            foodNameSnapshot: "错误数据",
            weightGrams: .infinity,
            nutrientsPer100Grams: .zero,
            sourceDataVersion: "test"
        )

        XCTAssertThrowsError(try MealNutritionCalculator.calculate(foodItems: [item])) { error in
            XCTAssertEqual(error as? MealNutritionCalculatorError, .invalidSnapshot(itemID: itemID))
        }
    }
}
