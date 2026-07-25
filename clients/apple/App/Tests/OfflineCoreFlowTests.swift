import HealthMonitorCore
import SwiftData
import XCTest
@testable import HealthMonitorAI

@MainActor
final class OfflineCoreFlowTests: XCTestCase {
    func testManualNutritionAndScoringWorkWhenAIIsUnavailable() async throws {
        let provider = UnavailableAIProvider()
        do {
            _ = try await provider.analyzeMeal(MealAnalysisRequest(
                requestId: "offline",
                locale: "zh-CN",
                description: "米饭 150 克",
                image: nil
            ))
            XCTFail("Expected the unavailable provider to throw")
        } catch {
            XCTAssertTrue(error is OfflineTestError)
        }

        let meal = MealRecord(
            eatenAt: Date(),
            mealType: .lunch,
            foodName: "手动记录",
            calories: 0,
            proteinGrams: 0,
            carbohydrateGrams: 0,
            fatGrams: 0
        )
        meal.foodItems = [MealFoodItem(
            catalogIdentifierSnapshot: "offline.rice",
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
            sourceDataVersion: "offline-v1",
            meal: meal
        )]
        try MealNutritionCalculator.recalculate(meal)

        let container = try ModelContainer(
            for: MealRecord.self,
            MealFoodItem.self,
            FoodCatalogItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        container.mainContext.insert(meal)
        try container.mainContext.save()

        let aggregate = try DailyHealthCalculator.aggregate(
            day: meal.eatenAt,
            meals: [meal],
            activity: .empty,
            overview: .empty
        )
        let score = try DailyHealthEngine.score(
            aggregate: aggregate,
            targets: DailyHealthTargets(
                energyKilocalories: 1_500,
                proteinGrams: 80,
                fiberGrams: 25,
                sugarLimitGrams: 50,
                sodiumLimitMilligrams: 2_000,
                steps: nil,
                exerciseMinutes: nil,
                sleepMinutes: nil
            ),
            recoveryBaseline: PersonalRecoveryBaseline(
                restingHeartRate: nil,
                heartRateVariabilityMilliseconds: nil
            ),
            habitConsistency: nil
        )

        XCTAssertEqual(meal.calories, 150)
        XCTAssertEqual(meal.nutritionAlgorithmVersion, NutritionEngine.algorithmVersion)
        XCTAssertEqual(aggregate.mealCount, 1)
        XCTAssertNotNil(score.totalScore)
        XCTAssertTrue(score.reasonCodes.contains(.insufficientData))
    }
}

private struct UnavailableAIProvider: AIProvider {
    let capabilities = AICapabilities(
        supportsVision: false,
        supportsStructuredOutput: false
    )

    func analyzeMeal(_ request: MealAnalysisRequest) async throws -> MealAnalysisResult {
        throw OfflineTestError.unavailable
    }

    func testConnection() async throws -> ConnectionTestResult {
        throw OfflineTestError.unavailable
    }
}

private enum OfflineTestError: Error {
    case unavailable
}
