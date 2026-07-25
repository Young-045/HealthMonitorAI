import Foundation
import Testing
@testable import HealthMonitorCore

@Test func mealRequestEncodesWithoutHealthData() throws {
    let request = MealAnalysisRequest(
        requestId: "test-001",
        locale: "zh-CN",
        description: "米饭150克",
        image: nil
    )

    let data = try JSONEncoder().encode(request)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(Set(object.keys) == ["requestId", "locale", "description"])
    #expect(object["description"] as? String == "米饭150克")
    #expect(object["heartRate"] == nil)
    #expect(object["sleep"] == nil)
    #expect(object["healthSummary"] == nil)
}

@Test func mealRequestIncludesOnlyExplicitlyAuthorizedAggregateHealthSummary() throws {
    let request = MealAnalysisRequest(
        requestId: "test-health",
        locale: "zh-CN",
        description: "午餐",
        image: nil,
        healthSummary: MealHealthSummary(
            steps: 6_000,
            activeEnergyKilocalories: 320,
            exerciseMinutes: nil,
            recentSleepDayMinutes: 450
        )
    )

    let data = try JSONEncoder().encode(request)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let summary = try #require(object["healthSummary"] as? [String: Any])

    #expect(summary["steps"] as? Int == 6_000)
    #expect(summary["activeEnergyKilocalories"] as? Int == 320)
    #expect(summary["recentSleepDayMinutes"] as? Int == 450)
    #expect(summary["exerciseMinutes"] == nil)
    #expect(summary["heartRate"] == nil)
    #expect(summary["weight"] == nil)
}

@Test func mealAnalysisResultRoundTripsThroughJSON() throws {
    let expected = MealAnalysisResult(
        schemaVersion: "1.0",
        requestId: "test-002",
        foods: [RecognizedFood(
            name: "番茄炒蛋",
            estimatedWeightGrams: 220,
            weightRange: WeightRange(minimumGrams: 170, maximumGrams: 280),
            cookingMethod: "stir_fried",
            confidence: 0.78,
            uncertainties: ["食用油用量不可见"]
        )],
        warnings: [],
        model: "test-model",
        processingTimeMilliseconds: 100
    )

    let data = try JSONEncoder().encode(expected)
    let actual = try JSONDecoder().decode(MealAnalysisResult.self, from: data)

    #expect(actual == expected)
}
