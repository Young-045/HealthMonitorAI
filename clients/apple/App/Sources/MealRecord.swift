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
    var createdAt: Date

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
        self.createdAt = createdAt
    }
}

extension MealRecord {
    var mealType: MealType {
        MealType(rawValue: mealTypeRawValue) ?? .snack
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
