import Foundation
import SwiftData

enum MealType: String, CaseIterable, Identifiable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: "早餐"
        case .lunch: "午餐"
        case .dinner: "晚餐"
        case .snack: "加餐"
        }
    }

    var symbol: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snack: "takeoutbag.and.cup.and.straw.fill"
        }
    }
}

enum MealHealthKitSyncState: String, Sendable {
    case notRequested
    case synced
    case failed
}

@Model
final class MealRecord {
    @Attribute(.unique) var id: UUID
    var eatenAt: Date
    var mealTypeRawValue: String
    var foodName: String
    var note: String
    var calories: Double
    var proteinGrams: Double
    var carbohydrateGrams: Double
    var fatGrams: Double
    var fiberGrams: Double = 0
    var sugarGrams: Double = 0
    var sodiumMilligrams: Double = 0
    var nutritionAlgorithmVersion: String = "manual-v1"
    var waterMilliliters: Double = 0
    var healthKitSampleUUIDsStorage: String = ""
    var healthKitSyncStateRawValue: String = MealHealthKitSyncState.notRequested.rawValue
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \MealFoodItem.meal)
    var foodItems: [MealFoodItem] = []

    init(
        id: UUID = UUID(),
        eatenAt: Date,
        mealType: MealType,
        foodName: String,
        note: String = "",
        calories: Double,
        proteinGrams: Double,
        carbohydrateGrams: Double,
        fatGrams: Double,
        fiberGrams: Double = 0,
        sugarGrams: Double = 0,
        sodiumMilligrams: Double = 0,
        waterMilliliters: Double = 0,
        nutritionAlgorithmVersion: String = "manual-v1",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.eatenAt = eatenAt
        mealTypeRawValue = mealType.rawValue
        self.foodName = foodName
        self.note = note
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.sodiumMilligrams = sodiumMilligrams
        self.waterMilliliters = waterMilliliters
        self.nutritionAlgorithmVersion = nutritionAlgorithmVersion
        self.createdAt = createdAt
    }
}

extension MealRecord {
    var mealType: MealType {
        MealType(rawValue: mealTypeRawValue) ?? .snack
    }

    var healthKitSampleUUIDs: [UUID] {
        healthKitSampleReferences.map(\.identifier)
    }

    var healthKitSampleReferences: [HealthKitSampleReference] {
        get {
            healthKitSampleUUIDsStorage
                .split(separator: "\n")
                .compactMap { line in
                    let parts = line.split(separator: "|", maxSplits: 1).map(String.init)
                    guard parts.count == 2, let identifier = UUID(uuidString: parts[1]) else {
                        return nil
                    }
                    return HealthKitSampleReference(
                        identifier: identifier,
                        typeIdentifier: parts[0]
                    )
                }
        }
        set {
            healthKitSampleUUIDsStorage = newValue
                .map { "\($0.typeIdentifier)|\($0.identifier.uuidString)" }
                .joined(separator: "\n")
        }
    }

    var healthKitSyncState: MealHealthKitSyncState {
        get { MealHealthKitSyncState(rawValue: healthKitSyncStateRawValue) ?? .notRequested }
        set { healthKitSyncStateRawValue = newValue.rawValue }
    }

    var confirmedNutrition: ConfirmedMealNutrition {
        ConfirmedMealNutrition(
            mealIdentifier: id,
            eatenAt: eatenAt,
            energyKilocalories: calories,
            proteinGrams: proteinGrams,
            carbohydrateGrams: carbohydrateGrams,
            fatGrams: fatGrams,
            fiberGrams: fiberGrams,
            sugarGrams: sugarGrams,
            sodiumMilligrams: sodiumMilligrams,
            waterMilliliters: waterMilliliters
        )
    }
}

struct NutritionTotals: Equatable, Sendable {
    let calories: Double
    let proteinGrams: Double
    let carbohydrateGrams: Double
    let fatGrams: Double

    static let zero = NutritionTotals(
        calories: 0,
        proteinGrams: 0,
        carbohydrateGrams: 0,
        fatGrams: 0
    )

    init(meals: [MealRecord]) {
        calories = meals.reduce(0) { $0 + $1.calories }
        proteinGrams = meals.reduce(0) { $0 + $1.proteinGrams }
        carbohydrateGrams = meals.reduce(0) { $0 + $1.carbohydrateGrams }
        fatGrams = meals.reduce(0) { $0 + $1.fatGrams }
    }

    private init(
        calories: Double,
        proteinGrams: Double,
        carbohydrateGrams: Double,
        fatGrams: Double
    ) {
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
    }
}
