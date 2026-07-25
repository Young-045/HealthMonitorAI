import Foundation
@preconcurrency import HealthKit

struct TodayActivitySummary: Equatable, Sendable {
    let steps: Int?
    let activeEnergyKilocalories: Int?
    let restingEnergyKilocalories: Int?
    let exerciseMinutes: Int?
    let unavailableMetrics: Set<HealthMetric>

    static let empty = TodayActivitySummary(
        steps: nil,
        activeEnergyKilocalories: nil,
        restingEnergyKilocalories: nil,
        exerciseMinutes: nil,
        unavailableMetrics: []
    )

    var isPartiallyAvailable: Bool {
        !unavailableMetrics.isEmpty && unavailableMetrics.count < 4
    }

    var isUnavailable: Bool {
        unavailableMetrics.count == 4
    }
}

struct HealthOverview: Equatable, Sendable {
    let heightCentimeters: Double?
    let weightKilograms: Double?
    let bodyFatPercentage: Double?
    let workoutCount: Int?
    let workoutMinutes: Int?
    let workoutEnergyKilocalories: Int?
    let sleepMinutes: Int?
    let restingHeartRate: Int?
    let heartRateVariabilityMilliseconds: Int?

    static let empty = HealthOverview(
        heightCentimeters: nil,
        weightKilograms: nil,
        bodyFatPercentage: nil,
        workoutCount: nil,
        workoutMinutes: nil,
        workoutEnergyKilocalories: nil,
        sleepMinutes: nil,
        restingHeartRate: nil,
        heartRateVariabilityMilliseconds: nil
    )
}

struct HealthActivitySyncResult: Equatable, Sendable {
    let addedCount: Int
    let deletedCount: Int
    let failedMetrics: Set<HealthMetric>

    static let empty = HealthActivitySyncResult(
        addedCount: 0,
        deletedCount: 0,
        failedMetrics: []
    )
}

enum HealthMetric: String, CaseIterable, Hashable, Sendable {
    case steps
    case activeEnergy
    case restingEnergy
    case exerciseMinutes
    case height
    case bodyMass
    case bodyFat
    case workouts
    case sleep
    case restingHeartRate
    case heartRateVariability

    var displayName: String {
        switch self {
        case .steps: "步数"
        case .activeEnergy: "活动能量"
        case .restingEnergy: "静息能量"
        case .exerciseMinutes: "锻炼时间"
        case .height: "身高"
        case .bodyMass: "体重"
        case .bodyFat: "体脂率"
        case .workouts: "训练"
        case .sleep: "睡眠"
        case .restingHeartRate: "静息心率"
        case .heartRateVariability: "HRV"
        }
    }
}

enum HealthAuthorizationRequestStatus: Equatable, Sendable {
    case shouldRequest
    case unnecessary
    case unknown
}

enum HealthKitClientError: LocalizedError {
    case unavailable
    case dataTypeUnavailable(String)
    case authorizationStatusUnknown

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "此设备不支持 Apple 健康数据。"
        case .dataTypeUnavailable(let identifier):
            "系统缺少健康数据类型：\(identifier)"
        case .authorizationStatusUnknown:
            "暂时无法确认 Apple 健康授权状态，请稍后重试。"
        }
    }
}

protocol HealthKitClientProtocol: Sendable {
    var isAvailable: Bool { get }
    func authorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus
    func requestReadAuthorization() async throws
    func syncHealthChanges() async throws -> HealthActivitySyncResult
    func startObservingHealthChanges(
        handler: @escaping @Sendable () async -> Void
    ) throws
    func fetchTodayActivity() async throws -> TodayActivitySummary
    func fetchHealthOverview() async throws -> HealthOverview
}

final class HealthKitClient: HealthKitClientProtocol, @unchecked Sendable {
    private let store = HKHealthStore()
    private let anchorStore: any HealthKitAnchorStoring
    private let observerLock = NSLock()
    private var observerQueries: [HKObserverQuery] = []

    init(anchorStore: any HealthKitAnchorStoring = HealthKitAnchorStore()) {
        self.anchorStore = anchorStore
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func authorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus {
        guard isAvailable else {
            throw HealthKitClientError.unavailable
        }

        let status = try await store.statusForAuthorizationRequest(
            toShare: Set(try HealthKitNutritionWriter.writeTypes()),
            read: readTypes()
        )
        switch status {
        case .shouldRequest:
            return .shouldRequest
        case .unnecessary:
            return .unnecessary
        case .unknown:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    func requestReadAuthorization() async throws {
        guard isAvailable else {
            throw HealthKitClientError.unavailable
        }

        let types = try readTypes()
        try await store.requestAuthorization(
            toShare: Set(try HealthKitNutritionWriter.writeTypes()),
            read: types
        )
    }

    func syncHealthChanges() async throws -> HealthActivitySyncResult {
        guard isAvailable else {
            throw HealthKitClientError.unavailable
        }

        var changes: [HealthMetricChangeResult] = []
        for (metric, type) in try healthTypes() {
            changes.append(await syncMetric(metric, type: type))
        }

        return HealthActivitySyncResult(
            addedCount: changes.reduce(0) { $0 + $1.addedCount },
            deletedCount: changes.reduce(0) { $0 + $1.deletedCount },
            failedMetrics: Set(changes.compactMap { $0.failed ? $0.metric : nil })
        )
    }

    func startObservingHealthChanges(
        handler: @escaping @Sendable () async -> Void
    ) throws {
        guard isAvailable else {
            throw HealthKitClientError.unavailable
        }

        observerLock.lock()
        defer { observerLock.unlock() }
        guard observerQueries.isEmpty else { return }

        let types = try healthTypes().map(\.1)
        let queries = types.map { type in
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, _ in
                let completionBox = ObserverCompletion(completion)
                Task {
                    await handler()
                    completionBox.call()
                }
            }
            store.execute(query)
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
            return query
        }
        observerQueries = queries
    }

    func fetchTodayActivity() async throws -> TodayActivitySummary {
        guard isAvailable else {
            throw HealthKitClientError.unavailable
        }

        let calendar = Calendar.autoupdatingCurrent
        let start = calendar.startOfDay(for: Date())
        let end = Date()

        async let steps = metricValue(
            metric: .steps,
            identifier: .stepCount,
            unit: .count(),
            from: start,
            to: end
        )
        async let energy = metricValue(
            metric: .activeEnergy,
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            from: start,
            to: end
        )
        async let exercise = metricValue(
            metric: .exerciseMinutes,
            identifier: .appleExerciseTime,
            unit: .minute(),
            from: start,
            to: end
        )
        async let restingEnergy = metricValue(
            metric: .restingEnergy,
            identifier: .basalEnergyBurned,
            unit: .kilocalorie(),
            from: start,
            to: end
        )

        let readings = await [steps, energy, restingEnergy, exercise]
        let values = Dictionary(uniqueKeysWithValues: readings.map { ($0.metric, $0.value) })
        let unavailableMetrics = Set(readings.compactMap { reading in
            reading.value == nil ? reading.metric : nil
        })

        return TodayActivitySummary(
            steps: values[.steps] ?? nil,
            activeEnergyKilocalories: values[.activeEnergy] ?? nil,
            restingEnergyKilocalories: values[.restingEnergy] ?? nil,
            exerciseMinutes: values[.exerciseMinutes] ?? nil,
            unavailableMetrics: unavailableMetrics
        )
    }

    func fetchHealthOverview() async throws -> HealthOverview {
        guard isAvailable else {
            throw HealthKitClientError.unavailable
        }

        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let sleepWindow = SleepDayWindowCalculator.window(containing: now, calendar: calendar)

        async let height = latestQuantity(.height, unit: .meterUnit(with: .centi))
        async let weight = latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo))
        async let bodyFat = latestQuantity(.bodyFatPercentage, unit: .percent())
        async let restingHeartRate = latestQuantity(
            .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
        async let hrv = latestQuantity(
            .heartRateVariabilitySDNN,
            unit: .secondUnit(with: .milli)
        )
        async let workouts = workoutSummary(from: today, to: now)
        async let sleep = sleepDuration(from: sleepWindow.start, to: sleepWindow.end)

        let values = await (
            optional(height),
            optional(weight),
            optional(bodyFat),
            optional(restingHeartRate),
            optional(hrv),
            optional(workouts),
            optional(sleep)
        )
        return HealthOverview(
            heightCentimeters: values.0,
            weightKilograms: values.1,
            bodyFatPercentage: values.2.map { $0 * 100 },
            workoutCount: values.5?.count,
            workoutMinutes: values.5.map { Int($0.durationMinutes.rounded()) },
            workoutEnergyKilocalories: values.5.map { Int($0.energyKilocalories.rounded()) },
            sleepMinutes: values.6.map { Int(($0 / 60).rounded()) },
            restingHeartRate: values.3.map { Int($0.rounded()) },
            heartRateVariabilityMilliseconds: values.4.map { Int($0.rounded()) }
        )
    }

    private func metricValue(
        metric: HealthMetric,
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> ActivityMetricReading {
        do {
            let value = try await cumulativeValue(
                identifier: identifier,
                unit: unit,
                from: start,
                to: end
            )
            return ActivityMetricReading(metric: metric, value: Int(value.rounded()))
        } catch {
            return ActivityMetricReading(metric: metric, value: nil)
        }
    }

    private func syncMetric(
        _ metric: HealthMetric,
        type: HKSampleType
    ) async -> HealthMetricChangeResult {
        do {
            let storedState = try anchorStore.state(for: metric)
            let startDate = storedState?.startDate
                ?? Calendar.autoupdatingCurrent.date(byAdding: .day, value: -28, to: Date())
                ?? Date()
            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: nil,
                options: .strictStartDate
            )
            let result = try await anchoredChanges(
                type: type,
                predicate: predicate,
                anchor: storedState?.anchor
            )
            try anchorStore.save(
                StoredHealthQueryState(anchor: result.anchor, startDate: startDate),
                for: metric
            )
            return HealthMetricChangeResult(
                metric: metric,
                addedCount: result.addedCount,
                deletedCount: result.deletedCount,
                failed: false
            )
        } catch {
            return HealthMetricChangeResult(
                metric: metric,
                addedCount: 0,
                deletedCount: 0,
                failed: true
            )
        }
    }

    private func anchoredChanges(
        type: HKSampleType,
        predicate: NSPredicate,
        anchor: HKQueryAnchor?
    ) async throws -> AnchoredChangeResult {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: type,
                predicate: predicate,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, deletedObjects, newAnchor, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: AnchoredChangeResult(
                    addedCount: samples?.count ?? 0,
                    deletedCount: deletedObjects?.count ?? 0,
                    anchor: newAnchor
                ))
            }
            store.execute(query)
        }
    }

    private func readTypes() throws -> Set<HKObjectType> {
        Set(try healthTypes().map(\.1))
    }

    private func healthTypes() throws -> [(HealthMetric, HKSampleType)] {
        let quantityIdentifiers: [(HealthMetric, HKQuantityTypeIdentifier)] = [
            (.steps, .stepCount),
            (.activeEnergy, .activeEnergyBurned),
            (.restingEnergy, .basalEnergyBurned),
            (.exerciseMinutes, .appleExerciseTime),
            (.height, .height),
            (.bodyMass, .bodyMass),
            (.bodyFat, .bodyFatPercentage),
            (.restingHeartRate, .restingHeartRate),
            (.heartRateVariability, .heartRateVariabilitySDNN)
        ]
        var types = try quantityIdentifiers.map { metric, identifier in
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
                throw HealthKitClientError.dataTypeUnavailable(identifier.rawValue)
            }
            return (metric, type as HKSampleType)
        }
        guard let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitClientError.dataTypeUnavailable(HKCategoryTypeIdentifier.sleepAnalysis.rawValue)
        }
        types.append((.sleep, sleep))
        types.append((.workouts, HKObjectType.workoutType()))
        return types
    }

    private func optional<T: Sendable>(_ result: Result<T, Error>) -> T? {
        try? result.get()
    }

    private func latestQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> Result<Double, Error> {
        do {
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
                throw HealthKitClientError.dataTypeUnavailable(identifier.rawValue)
            }
            let value: Double? = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: nil,
                    limit: 1,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let sample = samples?.first as? HKQuantitySample
                    continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
                }
                store.execute(query)
            }
            guard let value else { throw HealthDataMissingError.noSamples }
            return .success(value)
        } catch {
            return .failure(error)
        }
    }

    private func workoutSummary(from start: Date, to end: Date) async -> Result<WorkoutSummary, Error> {
        do {
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let summary: WorkoutSummary = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: HKObjectType.workoutType(),
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let workouts = samples as? [HKWorkout] ?? []
                    continuation.resume(returning: WorkoutSummary(
                        count: workouts.count,
                        durationMinutes: workouts.reduce(0) { $0 + $1.duration / 60 },
                        energyKilocalories: workouts.reduce(0) {
                            $0 + ($1.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
                        }
                    ))
                }
                store.execute(query)
            }
            return .success(summary)
        } catch {
            return .failure(error)
        }
    }

    private func sleepDuration(from start: Date, to end: Date) async -> Result<TimeInterval, Error> {
        do {
            guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
                throw HealthKitClientError.dataTypeUnavailable(HKCategoryTypeIdentifier.sleepAnalysis.rawValue)
            }
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let intervals: [DateInterval] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let sleeping = (samples as? [HKCategorySample] ?? []).filter {
                        SleepDurationCalculator.isAsleepValue($0.value)
                    }
                    continuation.resume(returning: sleeping.map {
                        DateInterval(start: max($0.startDate, start), end: min($0.endDate, end))
                    })
                }
                store.execute(query)
            }
            return .success(SleepDurationCalculator.mergedDuration(intervals))
        } catch {
            return .failure(error)
        }
    }

    private func cumulativeValue(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async throws -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitClientError.dataTypeUnavailable(identifier.rawValue)
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}

private struct ActivityMetricReading: Sendable {
    let metric: HealthMetric
    let value: Int?
}

private struct HealthMetricChangeResult: Sendable {
    let metric: HealthMetric
    let addedCount: Int
    let deletedCount: Int
    let failed: Bool
}

private struct AnchoredChangeResult: @unchecked Sendable {
    let addedCount: Int
    let deletedCount: Int
    let anchor: HKQueryAnchor?
}

private struct WorkoutSummary: Sendable {
    let count: Int
    let durationMinutes: Double
    let energyKilocalories: Double
}

private enum HealthDataMissingError: Error {
    case noSamples
}

enum SleepDurationCalculator {
    static func isAsleepValue(_ value: Int) -> Bool {
        [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ].contains(value)
    }

    static func mergedDuration(_ intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return 0 }
        var total: TimeInterval = 0

        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                total += current.duration
                current = interval
            }
        }
        return total + current.duration
    }
}

enum SleepDayWindowCalculator {
    static func window(containing now: Date, calendar: Calendar) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        let todayNoon = calendar.date(byAdding: .hour, value: 12, to: today) ?? today
        let start = calendar.date(byAdding: .day, value: -1, to: todayNoon) ?? today
        let end = now < todayNoon ? now : todayNoon
        return DateInterval(start: start, end: end)
    }
}

private final class ObserverCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var completion: (() -> Void)?

    init(_ completion: @escaping () -> Void) {
        self.completion = completion
    }

    func call() {
        lock.lock()
        let completion = completion
        self.completion = nil
        lock.unlock()
        completion?()
    }
}
