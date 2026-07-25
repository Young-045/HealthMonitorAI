import HealthMonitorCore
import XCTest
@testable import HealthMonitorAI

final class FoodCatalogMatcherTests: XCTestCase {
    private let nutrients = NutrientProfile(
        energyKilocalories: 116,
        proteinGrams: 2.6,
        carbohydrateGrams: 25.9,
        fatGrams: 0.3,
        fiberGrams: 0.3,
        sugarGrams: 0.1,
        sodiumMilligrams: 1
    )

    func testExactAliasMatchCreatesVersionedSnapshot() throws {
        let catalog = FoodCatalogItem(
            catalogIdentifier: "food.rice.cooked",
            name: "熟米饭",
            aliases: ["米饭"],
            category: .staple,
            nutrientsPer100Grams: nutrients,
            sourceName: "test",
            dataVersion: "2026.1"
        )
        let recognized = recognizedFood(name: " 米 饭 ", weight: 150)

        let match = try XCTUnwrap(FoodCatalogMatcher.match(
            recognizedFood: recognized,
            catalog: [catalog]
        ))
        let item = FoodCatalogMatcher.mealFoodItem(
            recognizedFood: recognized,
            confirmedWeightGrams: 180,
            match: match
        )

        XCTAssertEqual(match.kind, .alias)
        XCTAssertEqual(item.catalogIdentifierSnapshot, "food.rice.cooked")
        XCTAssertEqual(item.weightGrams, 180)
        XCTAssertEqual(item.nutrientsPer100Grams, nutrients)
        XCTAssertEqual(item.sourceDataVersion, "2026.1")

        let calculation = try MealNutritionCalculator.calculate(foodItems: [item])
        XCTAssertEqual(NSDecimalNumber(decimal: calculation.total.energyKilocalories).doubleValue, 208.8)
        XCTAssertEqual(NSDecimalNumber(decimal: calculation.total.carbohydrateGrams).doubleValue, 46.62)
    }

    func testCanonicalAndUserCreatedMatchesWinDeterministically() throws {
        let alias = makeCatalog(id: "a", name: "熟米饭", aliases: ["米饭"], userCreated: false)
        let canonicalBuiltIn = makeCatalog(id: "b", name: "米饭", aliases: [], userCreated: false)
        let canonicalUser = makeCatalog(id: "c", name: "米饭", aliases: [], userCreated: true)

        let match = try XCTUnwrap(FoodCatalogMatcher.match(
            recognizedFood: recognizedFood(name: "米饭", weight: 100),
            catalog: [alias, canonicalBuiltIn, canonicalUser]
        ))

        XCTAssertEqual(match.kind, .canonicalName)
        XCTAssertEqual(match.item.catalogIdentifier, "c")
    }

    func testFuzzyOrPartialNameDoesNotMatch() {
        let catalog = makeCatalog(id: "rice", name: "熟米饭", aliases: ["米饭"], userCreated: false)

        XCTAssertNil(FoodCatalogMatcher.match(
            recognizedFood: recognizedFood(name: "一碗米饭", weight: 150),
            catalog: [catalog]
        ))
    }

    private func makeCatalog(
        id: String,
        name: String,
        aliases: [String],
        userCreated: Bool
    ) -> FoodCatalogItem {
        FoodCatalogItem(
            catalogIdentifier: id,
            name: name,
            aliases: aliases,
            category: .staple,
            nutrientsPer100Grams: nutrients,
            sourceName: "test",
            dataVersion: "1",
            isUserCreated: userCreated
        )
    }

    private func recognizedFood(name: String, weight: Decimal) -> RecognizedFood {
        RecognizedFood(
            name: name,
            estimatedWeightGrams: weight,
            weightRange: WeightRange(minimumGrams: weight, maximumGrams: weight),
            cookingMethod: "steamed",
            confidence: 0.9,
            uncertainties: []
        )
    }
}
