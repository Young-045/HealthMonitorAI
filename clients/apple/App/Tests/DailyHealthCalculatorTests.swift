import HealthMonitorCore
import XCTest
@testable import HealthMonitorAI

final class DailyHealthCalculatorTests: XCTestCase {
    func testAggregateFiltersMealsByLocalDayAndMapsHealthData() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let day = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 20,
            hour: 12
        )))
        let todayMeal = meal(at: day, calories: 500)
        let previousMeal = meal(
            at: try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: day)),
            calories: 900
        )
        let activity = TodayActivitySummary(
            steps: 6_000,
            activeEnergyKilocalories: 400,
            restingEnergyKilocalories: 1_200,
            exerciseMinutes: 25,
            unavailableMetrics: []
        )
        let overview = HealthOverview(
            heightCentimeters: nil,
            weightKilograms: nil,
            bodyFatPercentage: nil,
            workoutCount: 1,
            workoutMinutes: 25,
            workoutEnergyKilocalories: 200,
            sleepMinutes: 420,
            restingHeartRate: 62,
            heartRateVariabilityMilliseconds: 48
        )

        let result = try DailyHealthCalculator.aggregate(
            day: day,
            meals: [todayMeal, previousMeal],
            activity: activity,
            overview: overview,
            calendar: calendar
        )

        XCTAssertEqual(result.mealCount, 1)
        XCTAssertEqual(result.nutrition.energyKilocalories, 500)
        XCTAssertEqual(result.measurements.steps, 6_000)
        XCTAssertEqual(result.measurements.sleepMinutes, 420)
        XCTAssertEqual(
            DailyHealthCalculator.dayIdentifier(for: day, calendar: calendar),
            "2026-07-20@Asia/Shanghai"
        )
    }

    func testScoreRecordPreservesReasonCodesAndVersion() {
        let result = DailyScoreResult(
            totalScore: 72.5,
            components: DailyScoreComponents(
                energyBalance: 80,
                nutritionQuality: 70,
                activityCompletion: 75,
                sleepAndRecovery: 65,
                habitStability: nil
            ),
            dataCompleteness: 81.8,
            reasonCodes: [.lowSleepDuration, .insufficientData],
            algorithmVersion: "daily-score-v1"
        )

        let record = DailyScoreRecord(dayIdentifier: "2026-07-20@Asia/Shanghai", result: result)

        XCTAssertEqual(record.totalScore, 72.5)
        XCTAssertEqual(record.reasonCodes, [.lowSleepDuration, .insufficientData])
        XCTAssertEqual(record.algorithmVersion, "daily-score-v1")
    }

    private func meal(at date: Date, calories: Double) -> MealRecord {
        MealRecord(
            eatenAt: date,
            mealType: .lunch,
            foodName: "测试餐食",
            calories: calories,
            proteinGrams: 20,
            carbohydrateGrams: 50,
            fatGrams: 10,
            fiberGrams: 5,
            sugarGrams: 3,
            sodiumMilligrams: 200
        )
    }
}
