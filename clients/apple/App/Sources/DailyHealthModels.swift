import Foundation
import HealthMonitorCore
import SwiftData

@Model
final class DailyHealthSummaryRecord {
    @Attribute(.unique) var dayIdentifier: String
    var dayStart: Date
    var timeZoneIdentifier: String
    var mealCount: Int
    var energyKilocalories: Double
    var proteinGrams: Double
    var carbohydrateGrams: Double
    var fatGrams: Double
    var fiberGrams: Double
    var sugarGrams: Double
    var sodiumMilligrams: Double
    var steps: Double?
    var activeEnergyKilocalories: Double?
    var exerciseMinutes: Double?
    var sleepMinutes: Double?
    var restingHeartRate: Double?
    var heartRateVariabilityMilliseconds: Double?
    var updatedAt: Date

    init(
        dayIdentifier: String,
        dayStart: Date,
        timeZoneIdentifier: String,
        aggregate: DailyHealthAggregate,
        updatedAt: Date = Date()
    ) {
        self.dayIdentifier = dayIdentifier
        self.dayStart = dayStart
        self.timeZoneIdentifier = timeZoneIdentifier
        mealCount = aggregate.mealCount
        energyKilocalories = aggregate.nutrition.energyKilocalories.doubleValue
        proteinGrams = aggregate.nutrition.proteinGrams.doubleValue
        carbohydrateGrams = aggregate.nutrition.carbohydrateGrams.doubleValue
        fatGrams = aggregate.nutrition.fatGrams.doubleValue
        fiberGrams = aggregate.nutrition.fiberGrams.doubleValue
        sugarGrams = aggregate.nutrition.sugarGrams.doubleValue
        sodiumMilligrams = aggregate.nutrition.sodiumMilligrams.doubleValue
        steps = aggregate.measurements.steps?.doubleValue
        activeEnergyKilocalories = aggregate.measurements.activeEnergyKilocalories?.doubleValue
        exerciseMinutes = aggregate.measurements.exerciseMinutes?.doubleValue
        sleepMinutes = aggregate.measurements.sleepMinutes?.doubleValue
        restingHeartRate = aggregate.measurements.restingHeartRate?.doubleValue
        heartRateVariabilityMilliseconds = aggregate.measurements
            .heartRateVariabilityMilliseconds?.doubleValue
        self.updatedAt = updatedAt
    }
}

@Model
final class DailyScoreRecord {
    @Attribute(.unique) var dayIdentifier: String
    var totalScore: Double?
    var energyBalanceScore: Double?
    var nutritionQualityScore: Double?
    var activityCompletionScore: Double?
    var sleepAndRecoveryScore: Double?
    var habitStabilityScore: Double?
    var dataCompleteness: Double
    var reasonCodesStorage: String
    var algorithmVersion: String
    var calculatedAt: Date

    init(
        dayIdentifier: String,
        result: DailyScoreResult,
        calculatedAt: Date = Date()
    ) {
        self.dayIdentifier = dayIdentifier
        totalScore = result.totalScore?.doubleValue
        energyBalanceScore = result.components.energyBalance?.doubleValue
        nutritionQualityScore = result.components.nutritionQuality?.doubleValue
        activityCompletionScore = result.components.activityCompletion?.doubleValue
        sleepAndRecoveryScore = result.components.sleepAndRecovery?.doubleValue
        habitStabilityScore = result.components.habitStability?.doubleValue
        dataCompleteness = result.dataCompleteness.doubleValue
        reasonCodesStorage = result.reasonCodes.map(\.rawValue).joined(separator: "\n")
        algorithmVersion = result.algorithmVersion
        self.calculatedAt = calculatedAt
    }

    var reasonCodes: [DailyScoreReasonCode] {
        reasonCodesStorage
            .split(separator: "\n")
            .compactMap { DailyScoreReasonCode(rawValue: String($0)) }
    }
}

enum DailyHealthCalculator {
    static func aggregate(
        day: Date,
        meals: [MealRecord],
        activity: TodayActivitySummary,
        overview: HealthOverview,
        calendar: Calendar = .autoupdatingCurrent
    ) throws -> DailyHealthAggregate {
        let dayMeals = meals.filter { calendar.isDate($0.eatenAt, inSameDayAs: day) }
        let nutrition = try dayMeals.map { meal in
            let values = [
                meal.calories, meal.proteinGrams, meal.carbohydrateGrams, meal.fatGrams,
                meal.fiberGrams, meal.sugarGrams, meal.sodiumMilligrams
            ]
            guard values.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
                throw DailyHealthEngineError.invalidMeasurement("mealNutrition")
            }
            return NutritionFacts(
                energyKilocalories: decimal(meal.calories),
                proteinGrams: decimal(meal.proteinGrams),
                carbohydrateGrams: decimal(meal.carbohydrateGrams),
                fatGrams: decimal(meal.fatGrams),
                fiberGrams: decimal(meal.fiberGrams),
                sugarGrams: decimal(meal.sugarGrams),
                sodiumMilligrams: decimal(meal.sodiumMilligrams)
            )
        }
        let measurements = DailyHealthMeasurements(
            steps: decimal(activity.steps),
            activeEnergyKilocalories: decimal(activity.activeEnergyKilocalories),
            exerciseMinutes: decimal(activity.exerciseMinutes),
            sleepMinutes: decimal(overview.sleepMinutes),
            restingHeartRate: decimal(overview.restingHeartRate),
            heartRateVariabilityMilliseconds: decimal(
                overview.heartRateVariabilityMilliseconds
            )
        )
        return try DailyHealthAggregator.aggregate(
            day: calendar.startOfDay(for: day),
            mealNutrition: nutrition,
            measurements: measurements
        )
    }

    static func dayIdentifier(
        for day: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return String(
            format: "%04d-%02d-%02d@%@",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            calendar.timeZone.identifier
        )
    }

    private static func decimal(_ value: Double) -> Decimal {
        Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) ?? .nan
    }

    private static func decimal(_ value: Int?) -> Decimal? {
        value.map { Decimal($0) }
    }
}

private extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
