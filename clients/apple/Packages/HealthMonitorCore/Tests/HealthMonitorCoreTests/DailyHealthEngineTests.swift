import Foundation
import Testing
@testable import HealthMonitorCore

private let completeTargets = DailyHealthTargets(
    energyKilocalories: 2_000,
    proteinGrams: 100,
    fiberGrams: 25,
    sugarLimitGrams: 50,
    sodiumLimitMilligrams: 2_000,
    steps: 8_000,
    exerciseMinutes: 30,
    sleepMinutes: 480
)

private let completeBaseline = PersonalRecoveryBaseline(
    restingHeartRate: 60,
    heartRateVariabilityMilliseconds: 50
)

private func aggregate(
    energy: Decimal = 2_000,
    protein: Decimal = 100,
    fiber: Decimal = 25,
    sugar: Decimal = 40,
    sodium: Decimal = 1_800,
    steps: Decimal? = 8_000,
    exercise: Decimal? = 30,
    sleep: Decimal? = 480,
    restingHeartRate: Decimal? = 60,
    hrv: Decimal? = 50,
    mealCount: Int = 3
) -> DailyHealthAggregate {
    DailyHealthAggregate(
        day: Date(timeIntervalSince1970: 1_700_000_000),
        mealCount: mealCount,
        nutrition: NutritionFacts(
            energyKilocalories: energy,
            proteinGrams: protein,
            carbohydrateGrams: 200,
            fatGrams: 60,
            fiberGrams: fiber,
            sugarGrams: sugar,
            sodiumMilligrams: sodium
        ),
        measurements: DailyHealthMeasurements(
            steps: steps,
            activeEnergyKilocalories: 500,
            exerciseMinutes: exercise,
            sleepMinutes: sleep,
            restingHeartRate: restingHeartRate,
            heartRateVariabilityMilliseconds: hrv
        )
    )
}

@Test func aggregatorSumsMealNutritionDeterministically() throws {
    let first = NutritionFacts(
        energyKilocalories: 500,
        proteinGrams: 20,
        carbohydrateGrams: 50,
        fatGrams: 10,
        fiberGrams: 5,
        sugarGrams: 3,
        sodiumMilligrams: 200
    )
    let second = NutritionFacts(
        energyKilocalories: 700,
        proteinGrams: 30,
        carbohydrateGrams: 80,
        fatGrams: 20,
        fiberGrams: 8,
        sugarGrams: 4,
        sodiumMilligrams: 300
    )
    let measurements = DailyHealthMeasurements(
        steps: 5_000,
        activeEnergyKilocalories: 300,
        exerciseMinutes: 20,
        sleepMinutes: 420,
        restingHeartRate: nil,
        heartRateVariabilityMilliseconds: nil
    )

    let result = try DailyHealthAggregator.aggregate(
        day: Date(timeIntervalSince1970: 1_700_000_000),
        mealNutrition: [first, second],
        measurements: measurements
    )

    #expect(result.mealCount == 2)
    #expect(result.nutrition.energyKilocalories == 1_200)
    #expect(result.nutrition.proteinGrams == 50)
    #expect(result.nutrition.fiberGrams == 13)
    #expect(result.measurements == measurements)
}

@Test func completeOnTargetDayScoresOneHundred() throws {
    let result = try DailyHealthEngine.score(
        aggregate: aggregate(),
        targets: completeTargets,
        recoveryBaseline: completeBaseline,
        habitConsistency: 1
    )

    #expect(result.totalScore == 100)
    #expect(result.components.energyBalance == 100)
    #expect(result.components.nutritionQuality == 100)
    #expect(result.components.activityCompletion == 100)
    #expect(result.components.sleepAndRecovery == 100)
    #expect(result.components.habitStability == 100)
    #expect(result.dataCompleteness == 100)
    #expect(result.reasonCodes.isEmpty)
    #expect(result.algorithmVersion == "daily-score-v1")
}

@Test func missingDataIsNotScoredAsZeroAndLowersCompleteness() throws {
    let partialTargets = DailyHealthTargets(
        energyKilocalories: nil,
        proteinGrams: nil,
        fiberGrams: nil,
        sugarLimitGrams: nil,
        sodiumLimitMilligrams: nil,
        steps: 8_000,
        exerciseMinutes: nil,
        sleepMinutes: nil
    )
    let result = try DailyHealthEngine.score(
        aggregate: aggregate(
            steps: 8_000,
            exercise: nil,
            sleep: nil,
            restingHeartRate: nil,
            hrv: nil,
            mealCount: 0
        ),
        targets: partialTargets,
        recoveryBaseline: PersonalRecoveryBaseline(
            restingHeartRate: nil,
            heartRateVariabilityMilliseconds: nil
        ),
        habitConsistency: nil
    )

    #expect(result.totalScore == 100)
    #expect(result.components.activityCompletion == 100)
    #expect(result.components.energyBalance == nil)
    #expect(result.dataCompleteness == 9.1)
    #expect(result.reasonCodes == [.insufficientData])
}

@Test func lowTargetsAndRecoveryProduceStableReasonCodes() throws {
    let result = try DailyHealthEngine.score(
        aggregate: aggregate(
            energy: 2_500,
            protein: 50,
            fiber: 10,
            sugar: 80,
            sodium: 3_000,
            steps: 4_000,
            exercise: 10,
            sleep: 300,
            restingHeartRate: 70,
            hrv: 35
        ),
        targets: completeTargets,
        recoveryBaseline: completeBaseline,
        habitConsistency: 0.5
    )

    #expect(result.reasonCodes == [
        .energyTargetDeviation,
        .proteinTargetMissed,
        .fiberTargetMissed,
        .sugarLimitExceeded,
        .sodiumLimitExceeded,
        .stepTargetMissed,
        .exerciseTargetMissed,
        .lowSleepDuration,
        .hrvBelowBaseline,
        .restingHeartRateAboveBaseline,
        .habitConsistencyLow
    ])
    #expect(result.dataCompleteness == 100)
    #expect(result.totalScore != nil)
}

@Test func scoreRejectsInvalidTargetsAndHabitRatio() {
    let invalidTargets = DailyHealthTargets(
        energyKilocalories: 0,
        proteinGrams: nil,
        fiberGrams: nil,
        sugarLimitGrams: nil,
        sodiumLimitMilligrams: nil,
        steps: nil,
        exerciseMinutes: nil,
        sleepMinutes: nil
    )
    #expect(throws: DailyHealthEngineError.invalidTarget("energyKilocalories")) {
        try DailyHealthEngine.score(
            aggregate: aggregate(),
            targets: invalidTargets,
            recoveryBaseline: completeBaseline,
            habitConsistency: nil
        )
    }
    #expect(throws: DailyHealthEngineError.invalidHabitConsistency) {
        try DailyHealthEngine.score(
            aggregate: aggregate(),
            targets: completeTargets,
            recoveryBaseline: completeBaseline,
            habitConsistency: Decimal(string: "1.1")
        )
    }
}
