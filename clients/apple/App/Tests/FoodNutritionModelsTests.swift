import SwiftData
import XCTest
@testable import HealthMonitorAI

final class FoodNutritionModelsTests: XCTestCase {
    private let profile = NutrientProfile(
        energyKilocalories: 116,
        proteinGrams: 2.6,
        carbohydrateGrams: 25.9,
        fatGrams: 0.3,
        fiberGrams: 0.3,
        sugarGrams: 0.1,
        sodiumMilligrams: 1
    )

    func testCatalogItemPreservesVersionedNutrientProfile() {
        let item = FoodCatalogItem(
            catalogIdentifier: "food.rice.cooked",
            name: "熟米饭",
            aliases: ["米饭", " 米饭 ", ""],
            category: .staple,
            defaultServingGrams: 150,
            nutrientsPer100Grams: profile,
            sourceName: "test",
            dataVersion: "2026.1"
        )

        XCTAssertEqual(item.aliases, ["米饭"])
        XCTAssertEqual(item.category, .staple)
        XCTAssertEqual(item.nutrientsPer100Grams, profile)
        XCTAssertEqual(item.dataVersion, "2026.1")
    }

    func testMealItemKeepsNutritionSnapshotIndependentOfCatalog() {
        let catalog = FoodCatalogItem(
            catalogIdentifier: "food.rice.cooked",
            name: "熟米饭",
            category: .staple,
            nutrientsPer100Grams: profile,
            sourceName: "test",
            dataVersion: "2026.1"
        )
        let mealItem = MealFoodItem(
            catalogIdentifierSnapshot: catalog.catalogIdentifier,
            foodNameSnapshot: catalog.name,
            weightGrams: 180,
            nutrientsPer100Grams: catalog.nutrientsPer100Grams,
            sourceDataVersion: catalog.dataVersion
        )

        catalog.energyKilocaloriesPer100Grams = 999

        XCTAssertEqual(mealItem.nutrientsPer100Grams, profile)
        XCTAssertEqual(mealItem.sourceDataVersion, "2026.1")
    }

    func testNutrientProfileRejectsNegativeAndNonfiniteValues() {
        XCTAssertTrue(profile.isValid)
        XCTAssertFalse(NutrientProfile(
            energyKilocalories: .infinity,
            proteinGrams: -1,
            carbohydrateGrams: 0,
            fatGrams: 0,
            fiberGrams: 0,
            sugarGrams: 0,
            sodiumMilligrams: 0
        ).isValid)
    }

    @MainActor
    func testSwiftDataPersistsCatalogAndCascadesMealItems() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MealRecord.self,
            MealFoodItem.self,
            FoodCatalogItem.self,
            configurations: configuration
        )
        let context = container.mainContext
        let catalog = FoodCatalogItem(
            catalogIdentifier: "food.rice.cooked",
            name: "熟米饭",
            category: .staple,
            nutrientsPer100Grams: profile,
            sourceName: "test",
            dataVersion: "2026.1"
        )
        let meal = MealRecord(
            eatenAt: Date(),
            mealType: .lunch,
            foodName: "米饭",
            calories: 208,
            proteinGrams: 4.7,
            carbohydrateGrams: 46.6,
            fatGrams: 0.5
        )
        let item = MealFoodItem(
            catalogIdentifierSnapshot: catalog.catalogIdentifier,
            foodNameSnapshot: catalog.name,
            weightGrams: 180,
            nutrientsPer100Grams: profile,
            sourceDataVersion: catalog.dataVersion,
            meal: meal
        )
        meal.foodItems.append(item)
        context.insert(catalog)
        context.insert(meal)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodCatalogItem>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealFoodItem>()), 1)

        context.delete(meal)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealFoodItem>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodCatalogItem>()), 1)
    }
}
