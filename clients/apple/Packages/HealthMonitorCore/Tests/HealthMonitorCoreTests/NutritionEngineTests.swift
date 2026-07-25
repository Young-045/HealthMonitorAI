import Foundation
import Testing
@testable import HealthMonitorCore

private let riceFacts = NutritionFacts(
    energyKilocalories: 116,
    proteinGrams: 2.6,
    carbohydrateGrams: 25.9,
    fatGrams: 0.3,
    fiberGrams: 0.3,
    sugarGrams: 0.1,
    sodiumMilligrams: 1
)

@Test func nutritionUsesPer100GramProfileAndConfirmedWeight() throws {
    let result = try NutritionEngine.calculate(portions: [NutritionPortionInput(
        lineIdentifier: "rice-1",
        foodIdentifier: "food.rice.cooked",
        foodName: "熟米饭",
        weightGrams: 150,
        nutrientsPer100Grams: riceFacts,
        sourceDataVersion: "2026.1"
    )])

    #expect(result.algorithmVersion == "nutrition-decimal-v1")
    #expect(result.total.energyKilocalories == 174)
    #expect(result.total.proteinGrams == 3.9)
    #expect(result.total.carbohydrateGrams == 38.85)
    #expect(result.total.sodiumMilligrams == 1.5)
}

@Test func totalRoundsOnlyAfterAddingRawLines() throws {
    let facts = NutritionFacts(
        energyKilocalories: 100,
        proteinGrams: 1,
        carbohydrateGrams: 0,
        fatGrams: 0,
        fiberGrams: 0,
        sugarGrams: 0,
        sodiumMilligrams: 0
    )
    let portions = (1...3).map { index in
        NutritionPortionInput(
            lineIdentifier: "line-\(index)",
            foodIdentifier: nil,
            foodName: "测试食物",
            weightGrams: 33.333,
            nutrientsPer100Grams: facts,
            sourceDataVersion: "test"
        )
    }

    let result = try NutritionEngine.calculate(portions: portions)

    #expect(result.lines.allSatisfy { $0.nutrients.energyKilocalories == 33.3 })
    #expect(result.total.energyKilocalories == 100)
    #expect(result.total.proteinGrams == 1)
}

@Test func nutritionTotalIsIndependentOfInputOrder() throws {
    let first = NutritionPortionInput(
        lineIdentifier: "first",
        foodIdentifier: nil,
        foodName: "A",
        weightGrams: 123.45,
        nutrientsPer100Grams: riceFacts,
        sourceDataVersion: "1"
    )
    let second = NutritionPortionInput(
        lineIdentifier: "second",
        foodIdentifier: nil,
        foodName: "B",
        weightGrams: 67.89,
        nutrientsPer100Grams: riceFacts,
        sourceDataVersion: "1"
    )

    let forward = try NutritionEngine.calculate(portions: [first, second])
    let reverse = try NutritionEngine.calculate(portions: [second, first])

    #expect(forward.total == reverse.total)
}

@Test func nutritionRejectsInvalidWeightAndNutrients() {
    let invalidWeight = NutritionPortionInput(
        lineIdentifier: "bad-weight",
        foodIdentifier: nil,
        foodName: "A",
        weightGrams: 0,
        nutrientsPer100Grams: riceFacts,
        sourceDataVersion: "1"
    )
    #expect(throws: NutritionCalculationError.invalidWeight(lineIdentifier: "bad-weight")) {
        try NutritionEngine.calculate(portions: [invalidWeight])
    }

    let invalidFacts = NutritionFacts(
        energyKilocalories: -1,
        proteinGrams: 0,
        carbohydrateGrams: 0,
        fatGrams: 0,
        fiberGrams: 0,
        sugarGrams: 0,
        sodiumMilligrams: 0
    )
    let invalidNutrients = NutritionPortionInput(
        lineIdentifier: "bad-facts",
        foodIdentifier: nil,
        foodName: "B",
        weightGrams: 100,
        nutrientsPer100Grams: invalidFacts,
        sourceDataVersion: "1"
    )
    #expect(throws: NutritionCalculationError.invalidNutrients(lineIdentifier: "bad-facts")) {
        try NutritionEngine.calculate(portions: [invalidNutrients])
    }
}
