import Foundation
import Testing
@testable import HealthMonitorCore

@Test func nutritionLabelCalculatorScalesPer100GramValues() throws {
    let result = try NutritionLabelCalculator.calculate(
        label: label(basis: .per100g),
        package: MealPackageInformation(
            netWeightGrams: 120,
            drainedWeightGrams: nil,
            servingSizeGrams: nil,
            servingsPerPackage: nil,
            confidence: 0.95
        ),
        consumedWeightGrams: 60
    )

    #expect(result.energyKilocalories == 66)
    #expect(result.proteinGrams == Decimal(string: "14.1"))
    #expect(result.carbohydrateGrams == Decimal(string: "0.72"))
    #expect(result.fatGrams == Decimal(string: "1.08"))
}

@Test func nutritionLabelCalculatorUsesServingWeight() throws {
    let result = try NutritionLabelCalculator.calculate(
        label: label(basis: .perServing),
        package: MealPackageInformation(
            netWeightGrams: 120,
            drainedWeightGrams: nil,
            servingSizeGrams: 60,
            servingsPerPackage: 2,
            confidence: 0.95
        ),
        consumedWeightGrams: 120
    )

    #expect(result.energyKilocalories == 220)
    #expect(result.proteinGrams == 47)
}

@Test func nutritionLabelCalculatorDoesNotTreatPackageWeightAsConsumedWeight() {
    #expect(throws: NutritionLabelCalculationError.invalidConsumedWeight) {
        try NutritionLabelCalculator.calculate(
            label: label(basis: .perPackage),
            package: MealPackageInformation(
                netWeightGrams: 120,
                drainedWeightGrams: nil,
                servingSizeGrams: nil,
                servingsPerPackage: nil,
                confidence: 0.95
            ),
            consumedWeightGrams: 0
        )
    }
}

@Test func nutritionLabelCalculatorScalesJapanesePerPackageBasisByPackageCount() throws {
    let label = RecognizedNutritionLabel(
        present: true,
        basis: .perPackage,
        basisDescription: "1包装当たり",
        basisQuantity: 1,
        basisUnit: "包装",
        energyKilocalories: 240,
        proteinGrams: 12,
        carbohydrateGrams: 30,
        fatGrams: 8,
        fiberGrams: nil,
        sugarGrams: nil,
        sodiumMilligrams: 500,
        rawText: "栄養成分表示 1包装当たり",
        unreadableFields: [],
        confidence: 0.97
    )

    let result = try NutritionLabelCalculator.calculate(
        label: label,
        consumedBasisCount: Decimal(string: "0.5")!
    )

    #expect(result.energyKilocalories == 120)
    #expect(result.proteinGrams == 6)
    #expect(result.carbohydrateGrams == 15)
    #expect(result.fatGrams == 4)
}

private func label(basis: NutritionLabelBasis) -> RecognizedNutritionLabel {
    RecognizedNutritionLabel(
        present: true,
        basis: basis,
        energyKilocalories: 110,
        proteinGrams: Decimal(string: "23.5"),
        carbohydrateGrams: Decimal(string: "1.2"),
        fatGrams: Decimal(string: "1.8"),
        fiberGrams: nil,
        sugarGrams: nil,
        sodiumMilligrams: 380,
        rawText: nil,
        unreadableFields: [],
        confidence: 0.95
    )
}
