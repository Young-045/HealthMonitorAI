import Foundation

public struct DailyHealthMeasurements: Codable, Equatable, Sendable {
    public let steps: Decimal?
    public let activeEnergyKilocalories: Decimal?
    public let exerciseMinutes: Decimal?
    public let sleepMinutes: Decimal?
    public let restingHeartRate: Decimal?
    public let heartRateVariabilityMilliseconds: Decimal?

    public init(
        steps: Decimal?,
        activeEnergyKilocalories: Decimal?,
        exerciseMinutes: Decimal?,
        sleepMinutes: Decimal?,
        restingHeartRate: Decimal?,
        heartRateVariabilityMilliseconds: Decimal?
    ) {
        self.steps = steps
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.exerciseMinutes = exerciseMinutes
        self.sleepMinutes = sleepMinutes
        self.restingHeartRate = restingHeartRate
        self.heartRateVariabilityMilliseconds = heartRateVariabilityMilliseconds
    }
}

public struct DailyHealthAggregate: Codable, Equatable, Sendable {
    public let day: Date
    public let mealCount: Int
    public let nutrition: NutritionFacts
    public let measurements: DailyHealthMeasurements

    public init(
        day: Date,
        mealCount: Int,
        nutrition: NutritionFacts,
        measurements: DailyHealthMeasurements
    ) {
        self.day = day
        self.mealCount = mealCount
        self.nutrition = nutrition
        self.measurements = measurements
    }
}

public struct DailyHealthTargets: Codable, Equatable, Sendable {
    public let energyKilocalories: Decimal?
    public let proteinGrams: Decimal?
    public let fiberGrams: Decimal?
    public let sugarLimitGrams: Decimal?
    public let sodiumLimitMilligrams: Decimal?
    public let steps: Decimal?
    public let exerciseMinutes: Decimal?
    public let sleepMinutes: Decimal?

    public init(
        energyKilocalories: Decimal?,
        proteinGrams: Decimal?,
        fiberGrams: Decimal?,
        sugarLimitGrams: Decimal?,
        sodiumLimitMilligrams: Decimal?,
        steps: Decimal?,
        exerciseMinutes: Decimal?,
        sleepMinutes: Decimal?
    ) {
        self.energyKilocalories = energyKilocalories
        self.proteinGrams = proteinGrams
        self.fiberGrams = fiberGrams
        self.sugarLimitGrams = sugarLimitGrams
        self.sodiumLimitMilligrams = sodiumLimitMilligrams
        self.steps = steps
        self.exerciseMinutes = exerciseMinutes
        self.sleepMinutes = sleepMinutes
    }
}

public struct PersonalRecoveryBaseline: Codable, Equatable, Sendable {
    public let restingHeartRate: Decimal?
    public let heartRateVariabilityMilliseconds: Decimal?

    public init(
        restingHeartRate: Decimal?,
        heartRateVariabilityMilliseconds: Decimal?
    ) {
        self.restingHeartRate = restingHeartRate
        self.heartRateVariabilityMilliseconds = heartRateVariabilityMilliseconds
    }
}

public struct DailyScoreComponents: Codable, Equatable, Sendable {
    public let energyBalance: Decimal?
    public let nutritionQuality: Decimal?
    public let activityCompletion: Decimal?
    public let sleepAndRecovery: Decimal?
    public let habitStability: Decimal?

    public init(
        energyBalance: Decimal?,
        nutritionQuality: Decimal?,
        activityCompletion: Decimal?,
        sleepAndRecovery: Decimal?,
        habitStability: Decimal?
    ) {
        self.energyBalance = energyBalance
        self.nutritionQuality = nutritionQuality
        self.activityCompletion = activityCompletion
        self.sleepAndRecovery = sleepAndRecovery
        self.habitStability = habitStability
    }
}

public enum DailyScoreReasonCode: String, Codable, CaseIterable, Sendable {
    case energyTargetDeviation = "ENERGY_TARGET_DEVIATION"
    case proteinTargetMissed = "PROTEIN_TARGET_MISSED"
    case fiberTargetMissed = "FIBER_TARGET_MISSED"
    case sugarLimitExceeded = "SUGAR_LIMIT_EXCEEDED"
    case sodiumLimitExceeded = "SODIUM_LIMIT_EXCEEDED"
    case stepTargetMissed = "STEP_TARGET_MISSED"
    case exerciseTargetMissed = "EXERCISE_TARGET_MISSED"
    case lowSleepDuration = "LOW_SLEEP_DURATION"
    case hrvBelowBaseline = "HRV_BELOW_BASELINE"
    case restingHeartRateAboveBaseline = "RESTING_HEART_RATE_ABOVE_BASELINE"
    case habitConsistencyLow = "HABIT_CONSISTENCY_LOW"
    case insufficientData = "INSUFFICIENT_DATA"
}

public struct DailyScoreResult: Codable, Equatable, Sendable {
    public let totalScore: Decimal?
    public let components: DailyScoreComponents
    public let dataCompleteness: Decimal
    public let reasonCodes: [DailyScoreReasonCode]
    public let algorithmVersion: String

    public init(
        totalScore: Decimal?,
        components: DailyScoreComponents,
        dataCompleteness: Decimal,
        reasonCodes: [DailyScoreReasonCode],
        algorithmVersion: String
    ) {
        self.totalScore = totalScore
        self.components = components
        self.dataCompleteness = dataCompleteness
        self.reasonCodes = reasonCodes
        self.algorithmVersion = algorithmVersion
    }
}

public enum DailyHealthEngineError: Error, Equatable, Sendable {
    case invalidMeasurement(String)
    case invalidTarget(String)
    case invalidBaseline(String)
    case invalidHabitConsistency
}

public enum DailyHealthAggregator {
    public static func aggregate(
        day: Date,
        mealNutrition: [NutritionFacts],
        measurements: DailyHealthMeasurements
    ) throws -> DailyHealthAggregate {
        for facts in mealNutrition where !DailyHealthEngine.validNutrition(facts) {
            throw DailyHealthEngineError.invalidMeasurement("nutrition")
        }
        try DailyHealthEngine.validateMeasurements(measurements)

        let total = mealNutrition.reduce(.zero, DailyHealthEngine.addNutrition)
        return DailyHealthAggregate(
            day: day,
            mealCount: mealNutrition.count,
            nutrition: total,
            measurements: measurements
        )
    }
}

public enum DailyHealthEngine {
    public static let algorithmVersion = "daily-score-v1"
    private static let expectedSignalCount = Decimal(11)

    public static func score(
        aggregate: DailyHealthAggregate,
        targets: DailyHealthTargets,
        recoveryBaseline: PersonalRecoveryBaseline,
        habitConsistency: Decimal?
    ) throws -> DailyScoreResult {
        try validateMeasurements(aggregate.measurements)
        try validateTargets(targets)
        try validateBaseline(recoveryBaseline)
        if let habitConsistency,
           (!isValid(habitConsistency) || habitConsistency > 1) {
            throw DailyHealthEngineError.invalidHabitConsistency
        }

        var reasons: [DailyScoreReasonCode] = []
        var availableSignals = 0

        let energy = pairedScore(
            value: aggregate.mealCount > 0 ? aggregate.nutrition.energyKilocalories : nil,
            target: targets.energyKilocalories
        ) { value, target in
            let deviation = abs(value - target) / target
            if deviation > Decimal(string: "0.10")! {
                reasons.append(.energyTargetDeviation)
            }
            return clamp(100 - deviation * 200)
        }
        availableSignals += energy == nil ? 0 : 1

        let nutritionSignals: [Decimal?] = [
            adequacyScore(
                value: aggregate.mealCount > 0 ? aggregate.nutrition.proteinGrams : nil,
                target: targets.proteinGrams,
                missedReason: .proteinTargetMissed,
                reasons: &reasons
            ),
            adequacyScore(
                value: aggregate.mealCount > 0 ? aggregate.nutrition.fiberGrams : nil,
                target: targets.fiberGrams,
                missedReason: .fiberTargetMissed,
                reasons: &reasons
            ),
            limitScore(
                value: aggregate.mealCount > 0 ? aggregate.nutrition.sugarGrams : nil,
                limit: targets.sugarLimitGrams,
                exceededReason: .sugarLimitExceeded,
                reasons: &reasons
            ),
            limitScore(
                value: aggregate.mealCount > 0 ? aggregate.nutrition.sodiumMilligrams : nil,
                limit: targets.sodiumLimitMilligrams,
                exceededReason: .sodiumLimitExceeded,
                reasons: &reasons
            )
        ]
        availableSignals += nutritionSignals.compactMap { $0 }.count
        let nutrition = average(nutritionSignals)

        let activitySignals: [Decimal?] = [
            adequacyScore(
                value: aggregate.measurements.steps,
                target: targets.steps,
                missedReason: .stepTargetMissed,
                reasons: &reasons
            ),
            adequacyScore(
                value: aggregate.measurements.exerciseMinutes,
                target: targets.exerciseMinutes,
                missedReason: .exerciseTargetMissed,
                reasons: &reasons
            )
        ]
        availableSignals += activitySignals.compactMap { $0 }.count
        let activity = average(activitySignals)

        let sleep = adequacyScore(
            value: aggregate.measurements.sleepMinutes,
            target: targets.sleepMinutes,
            missedReason: .lowSleepDuration,
            reasons: &reasons
        )
        let hrv = pairedScore(
            value: aggregate.measurements.heartRateVariabilityMilliseconds,
            target: recoveryBaseline.heartRateVariabilityMilliseconds
        ) { value, baseline in
            let ratio = value / baseline
            if ratio < Decimal(string: "0.85")! { reasons.append(.hrvBelowBaseline) }
            return clamp(ratio * 100)
        }
        let restingHeartRate = pairedScore(
            value: aggregate.measurements.restingHeartRate,
            target: recoveryBaseline.restingHeartRate
        ) { value, baseline in
            let excess = max(0, (value - baseline) / baseline)
            if excess > Decimal(string: "0.10")! {
                reasons.append(.restingHeartRateAboveBaseline)
            }
            return clamp(100 - excess * 200)
        }
        let recoverySignals = [sleep, hrv, restingHeartRate]
        availableSignals += recoverySignals.compactMap { $0 }.count
        let recovery = average(recoverySignals)

        let habit = habitConsistency.map { value in
            if value < Decimal(string: "0.70")! { reasons.append(.habitConsistencyLow) }
            return clamp(value * 100)
        }
        availableSignals += habit == nil ? 0 : 1

        let components = DailyScoreComponents(
            energyBalance: rounded(energy),
            nutritionQuality: rounded(nutrition),
            activityCompletion: rounded(activity),
            sleepAndRecovery: rounded(recovery),
            habitStability: rounded(habit)
        )
        let weighted: [(Decimal?, Decimal)] = [
            (energy, 25),
            (nutrition, 25),
            (activity, 20),
            (recovery, 20),
            (habit, 10)
        ]
        let availableWeighted = weighted.compactMap { score, weight in
            score.map { ($0, weight) }
        }
        let weightTotal = availableWeighted.reduce(Decimal.zero) { $0 + $1.1 }
        let total = weightTotal > 0
            ? availableWeighted.reduce(Decimal.zero) { $0 + $1.0 * $1.1 } / weightTotal
            : nil
        let completeness = Decimal(availableSignals) / expectedSignalCount * 100
        if completeness < 70 { reasons.append(.insufficientData) }

        return DailyScoreResult(
            totalScore: rounded(total),
            components: components,
            dataCompleteness: round(completeness, scale: 1),
            reasonCodes: DailyScoreReasonCode.allCases.filter(reasons.contains),
            algorithmVersion: algorithmVersion
        )
    }

    static func validateMeasurements(_ values: DailyHealthMeasurements) throws {
        let fields: [(String, Decimal?)] = [
            ("steps", values.steps),
            ("activeEnergyKilocalories", values.activeEnergyKilocalories),
            ("exerciseMinutes", values.exerciseMinutes),
            ("sleepMinutes", values.sleepMinutes),
            ("restingHeartRate", values.restingHeartRate),
            ("heartRateVariabilityMilliseconds", values.heartRateVariabilityMilliseconds)
        ]
        if let invalid = fields.first(where: { value in
            value.1.map { !isValid($0) } ?? false
        }) {
            throw DailyHealthEngineError.invalidMeasurement(invalid.0)
        }
    }

    static func validNutrition(_ facts: NutritionFacts) -> Bool {
        [
            facts.energyKilocalories, facts.proteinGrams, facts.carbohydrateGrams,
            facts.fatGrams, facts.fiberGrams, facts.sugarGrams, facts.sodiumMilligrams
        ].allSatisfy(isValid)
    }

    static func addNutrition(_ lhs: NutritionFacts, _ rhs: NutritionFacts) -> NutritionFacts {
        NutritionFacts(
            energyKilocalories: lhs.energyKilocalories + rhs.energyKilocalories,
            proteinGrams: lhs.proteinGrams + rhs.proteinGrams,
            carbohydrateGrams: lhs.carbohydrateGrams + rhs.carbohydrateGrams,
            fatGrams: lhs.fatGrams + rhs.fatGrams,
            fiberGrams: lhs.fiberGrams + rhs.fiberGrams,
            sugarGrams: lhs.sugarGrams + rhs.sugarGrams,
            sodiumMilligrams: lhs.sodiumMilligrams + rhs.sodiumMilligrams
        )
    }

    private static func validateTargets(_ targets: DailyHealthTargets) throws {
        let fields: [(String, Decimal?)] = [
            ("energyKilocalories", targets.energyKilocalories),
            ("proteinGrams", targets.proteinGrams),
            ("fiberGrams", targets.fiberGrams),
            ("sugarLimitGrams", targets.sugarLimitGrams),
            ("sodiumLimitMilligrams", targets.sodiumLimitMilligrams),
            ("steps", targets.steps),
            ("exerciseMinutes", targets.exerciseMinutes),
            ("sleepMinutes", targets.sleepMinutes)
        ]
        if let invalid = fields.first(where: { value in
            value.1.map { !isValid($0) || $0 == 0 } ?? false
        }) {
            throw DailyHealthEngineError.invalidTarget(invalid.0)
        }
    }

    private static func validateBaseline(_ baseline: PersonalRecoveryBaseline) throws {
        let fields: [(String, Decimal?)] = [
            ("restingHeartRate", baseline.restingHeartRate),
            ("heartRateVariabilityMilliseconds", baseline.heartRateVariabilityMilliseconds)
        ]
        if let invalid = fields.first(where: { value in
            value.1.map { !isValid($0) || $0 == 0 } ?? false
        }) {
            throw DailyHealthEngineError.invalidBaseline(invalid.0)
        }
    }

    private static func adequacyScore(
        value: Decimal?,
        target: Decimal?,
        missedReason: DailyScoreReasonCode,
        reasons: inout [DailyScoreReasonCode]
    ) -> Decimal? {
        pairedScore(value: value, target: target) { value, target in
            let ratio = value / target
            if ratio < Decimal(string: "0.80")! { reasons.append(missedReason) }
            return clamp(ratio * 100)
        }
    }

    private static func limitScore(
        value: Decimal?,
        limit: Decimal?,
        exceededReason: DailyScoreReasonCode,
        reasons: inout [DailyScoreReasonCode]
    ) -> Decimal? {
        pairedScore(value: value, target: limit) { value, limit in
            guard value > limit else { return 100 }
            reasons.append(exceededReason)
            return clamp(100 - ((value / limit) - 1) * 100)
        }
    }

    private static func pairedScore(
        value: Decimal?,
        target: Decimal?,
        calculate: (Decimal, Decimal) -> Decimal
    ) -> Decimal? {
        guard let value, let target else { return nil }
        return calculate(value, target)
    }

    private static func average(_ values: [Decimal?]) -> Decimal? {
        let available = values.compactMap { $0 }
        guard !available.isEmpty else { return nil }
        return available.reduce(0, +) / Decimal(available.count)
    }

    private static func clamp(_ value: Decimal) -> Decimal {
        min(100, max(0, value))
    }

    private static func isValid(_ value: Decimal) -> Bool {
        !value.isNaN && value >= 0
    }

    private static func rounded(_ value: Decimal?) -> Decimal? {
        value.map { round($0, scale: 1) }
    }

    private static func round(_ value: Decimal, scale: Int) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }
}
