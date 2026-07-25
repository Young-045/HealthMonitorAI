import Foundation
@preconcurrency import HealthKit

struct ConfirmedMealNutrition: Equatable, Sendable {
    let mealIdentifier: UUID
    let eatenAt: Date
    let energyKilocalories: Double
    let proteinGrams: Double
    let carbohydrateGrams: Double
    let fatGrams: Double
    let fiberGrams: Double
    let sugarGrams: Double
    let sodiumMilligrams: Double
    let waterMilliliters: Double
}

struct HealthKitSampleReference: Equatable, Hashable, Sendable {
    let identifier: UUID
    let typeIdentifier: String
}

enum HealthKitNutritionWriterError: LocalizedError {
    case unavailable
    case authorizationDenied
    case invalidNutrition

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "此设备不支持写入 Apple 健康。"
        case .authorizationDenied:
            "没有 Apple 健康营养写入权限，请在系统设置中允许后重试。"
        case .invalidNutrition:
            "餐食包含无效营养数据，未写入 Apple 健康。"
        }
    }
}

protocol HealthKitNutritionWriting: Sendable {
    func saveConfirmedMeal(_ meal: ConfirmedMealNutrition) async throws -> [HealthKitSampleReference]
    func deleteSamples(with references: Set<HealthKitSampleReference>) async throws
}

final class HealthKitNutritionWriter: HealthKitNutritionWriting, @unchecked Sendable {
    private let store: HKHealthStore

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    func saveConfirmedMeal(_ meal: ConfirmedMealNutrition) async throws -> [HealthKitSampleReference] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitNutritionWriterError.unavailable
        }
        let values = [
            meal.energyKilocalories, meal.proteinGrams, meal.carbohydrateGrams,
            meal.fatGrams, meal.fiberGrams, meal.sugarGrams,
            meal.sodiumMilligrams, meal.waterMilliliters
        ]
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw HealthKitNutritionWriterError.invalidNutrition
        }

        let writeTypes = try Self.writeTypes()
        try await store.requestAuthorization(toShare: Set(writeTypes), read: [])
        let descriptors = try sampleDescriptors(for: meal).filter { $0.value > 0 }
        for descriptor in descriptors where store.authorizationStatus(for: descriptor.type) != .sharingAuthorized {
            throw HealthKitNutritionWriterError.authorizationDenied
        }
        let metadata: [String: Any] = [
            HKMetadataKeyExternalUUID: meal.mealIdentifier.uuidString,
            HKMetadataKeyWasUserEntered: true
        ]
        let samples = descriptors.map { descriptor in
            HKQuantitySample(
                type: descriptor.type,
                quantity: HKQuantity(unit: descriptor.unit, doubleValue: descriptor.value),
                start: meal.eatenAt,
                end: meal.eatenAt,
                metadata: metadata
            )
        }
        guard !samples.isEmpty else { return [] }
        try await store.save(samples)
        return zip(samples, descriptors).map { sample, descriptor in
            HealthKitSampleReference(
                identifier: sample.uuid,
                typeIdentifier: descriptor.type.identifier
            )
        }
    }

    func deleteSamples(with references: Set<HealthKitSampleReference>) async throws {
        guard !references.isEmpty else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitNutritionWriterError.unavailable
        }

        let grouped = Dictionary(grouping: references, by: \.typeIdentifier)
        for (rawIdentifier, typeReferences) in grouped {
            let identifier = HKQuantityTypeIdentifier(rawValue: rawIdentifier)
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
                throw HealthKitClientError.dataTypeUnavailable(rawIdentifier)
            }
            let predicate = HKQuery.predicateForObjects(
                with: Set(typeReferences.map(\.identifier))
            )
            try await deleteObjects(of: type, predicate: predicate)
        }
    }

    static func writeTypes() throws -> Set<HKQuantityType> {
        let identifiers: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal,
            .dietaryFiber,
            .dietarySugar,
            .dietarySodium,
            .dietaryWater
        ]
        return try Set(identifiers.map { identifier in
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
                throw HealthKitClientError.dataTypeUnavailable(identifier.rawValue)
            }
            return type
        })
    }

    private func sampleDescriptors(for meal: ConfirmedMealNutrition) throws -> [NutritionSampleDescriptor] {
        let values: [(HKQuantityTypeIdentifier, HKUnit, Double)] = [
            (.dietaryEnergyConsumed, .kilocalorie(), meal.energyKilocalories),
            (.dietaryProtein, .gram(), meal.proteinGrams),
            (.dietaryCarbohydrates, .gram(), meal.carbohydrateGrams),
            (.dietaryFatTotal, .gram(), meal.fatGrams),
            (.dietaryFiber, .gram(), meal.fiberGrams),
            (.dietarySugar, .gram(), meal.sugarGrams),
            (.dietarySodium, .gramUnit(with: .milli), meal.sodiumMilligrams),
            (.dietaryWater, .literUnit(with: .milli), meal.waterMilliliters)
        ]
        return try values.map { identifier, unit, value in
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
                throw HealthKitClientError.dataTypeUnavailable(identifier.rawValue)
            }
            return NutritionSampleDescriptor(type: type, unit: unit, value: value)
        }
    }

    private func deleteObjects(
        of type: HKObjectType,
        predicate: NSPredicate
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.deleteObjects(of: type, predicate: predicate) { success, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitNutritionWriterError.authorizationDenied)
                }
            }
        }
    }
}

private struct NutritionSampleDescriptor {
    let type: HKQuantityType
    let unit: HKUnit
    let value: Double
}

@MainActor
enum MealHealthKitSyncCoordinator {
    static func sync(
        _ meal: MealRecord,
        using writer: any HealthKitNutritionWriting
    ) async throws {
        let references = try await writer.saveConfirmedMeal(meal.confirmedNutrition)
        meal.healthKitSampleReferences = references
        meal.healthKitSyncState = .synced
    }

    static func deleteHealthSamples(
        for meal: MealRecord,
        using writer: any HealthKitNutritionWriting
    ) async throws {
        try await writer.deleteSamples(with: Set(meal.healthKitSampleReferences))
        meal.healthKitSampleReferences = []
    }
}
