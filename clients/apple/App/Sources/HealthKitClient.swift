import Foundation
@preconcurrency import HealthKit

struct TodayActivitySummary: Equatable, Sendable {
    let steps: Int
    let activeEnergyKilocalories: Int
    let exerciseMinutes: Int

    static let empty = TodayActivitySummary(
        steps: 0,
        activeEnergyKilocalories: 0,
        exerciseMinutes: 0
    )
}

enum HealthKitClientError: LocalizedError {
    case unavailable
    case dataTypeUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "此设备不支持 Apple 健康数据。"
        case .dataTypeUnavailable(let identifier):
            "系统缺少健康数据类型：\(identifier)"
        }
    }
}

final class HealthKitClient: @unchecked Sendable {
    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestReadAuthorization() async throws {
        guard isAvailable else {
            throw HealthKitClientError.unavailable
        }

        let types = try readTypes()
        try await store.requestAuthorization(toShare: [], read: types)
    }

    func fetchTodayActivity() async throws -> TodayActivitySummary {
        guard isAvailable else {
            throw HealthKitClientError.unavailable
        }

        let calendar = Calendar.autoupdatingCurrent
        let start = calendar.startOfDay(for: Date())
        let end = Date()

        async let steps = cumulativeValue(
            identifier: .stepCount,
            unit: .count(),
            from: start,
            to: end
        )
        async let energy = cumulativeValue(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            from: start,
            to: end
        )
        async let exercise = cumulativeValue(
            identifier: .appleExerciseTime,
            unit: .minute(),
            from: start,
            to: end
        )

        let (stepValue, energyValue, exerciseValue) = try await (steps, energy, exercise)
        return TodayActivitySummary(
            steps: Int(stepValue.rounded()),
            activeEnergyKilocalories: Int(energyValue.rounded()),
            exerciseMinutes: Int(exerciseValue.rounded())
        )
    }

    private func readTypes() throws -> Set<HKObjectType> {
        let identifiers: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .activeEnergyBurned,
            .appleExerciseTime
        ]

        return try Set(identifiers.map { identifier in
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
                throw HealthKitClientError.dataTypeUnavailable(identifier.rawValue)
            }
            return type
        })
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
