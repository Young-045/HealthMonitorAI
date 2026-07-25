import Foundation

public struct NutritionFacts: Codable, Equatable, Sendable {
    public let energyKilocalories: Decimal
    public let proteinGrams: Decimal
    public let carbohydrateGrams: Decimal
    public let fatGrams: Decimal
    public let fiberGrams: Decimal
    public let sugarGrams: Decimal
    public let sodiumMilligrams: Decimal

    public static let zero = NutritionFacts(
        energyKilocalories: 0,
        proteinGrams: 0,
        carbohydrateGrams: 0,
        fatGrams: 0,
        fiberGrams: 0,
        sugarGrams: 0,
        sodiumMilligrams: 0
    )

    public init(
        energyKilocalories: Decimal,
        proteinGrams: Decimal,
        carbohydrateGrams: Decimal,
        fatGrams: Decimal,
        fiberGrams: Decimal,
        sugarGrams: Decimal,
        sodiumMilligrams: Decimal
    ) {
        self.energyKilocalories = energyKilocalories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.sodiumMilligrams = sodiumMilligrams
    }
}

public struct NutritionPortionInput: Codable, Equatable, Sendable {
    public let lineIdentifier: String
    public let foodIdentifier: String?
    public let foodName: String
    public let weightGrams: Decimal
    public let nutrientsPer100Grams: NutritionFacts
    public let sourceDataVersion: String

    public init(
        lineIdentifier: String,
        foodIdentifier: String?,
        foodName: String,
        weightGrams: Decimal,
        nutrientsPer100Grams: NutritionFacts,
        sourceDataVersion: String
    ) {
        self.lineIdentifier = lineIdentifier
        self.foodIdentifier = foodIdentifier
        self.foodName = foodName
        self.weightGrams = weightGrams
        self.nutrientsPer100Grams = nutrientsPer100Grams
        self.sourceDataVersion = sourceDataVersion
    }
}

public struct NutritionLineResult: Codable, Equatable, Sendable {
    public let lineIdentifier: String
    public let weightGrams: Decimal
    public let nutrients: NutritionFacts
}

public struct NutritionCalculationResult: Codable, Equatable, Sendable {
    public let algorithmVersion: String
    public let lines: [NutritionLineResult]
    public let total: NutritionFacts
}

public enum NutritionCalculationError: Error, Equatable, Sendable {
    case invalidWeight(lineIdentifier: String)
    case invalidNutrients(lineIdentifier: String)
}

public enum NutritionEngine {
    public static let algorithmVersion = "nutrition-decimal-v1"

    public static func calculate(
        portions: [NutritionPortionInput]
    ) throws -> NutritionCalculationResult {
        var rawTotal = NutritionFacts.zero
        var lineResults: [NutritionLineResult] = []
        lineResults.reserveCapacity(portions.count)

        for portion in portions {
            guard isValid(portion.weightGrams), portion.weightGrams > 0 else {
                throw NutritionCalculationError.invalidWeight(
                    lineIdentifier: portion.lineIdentifier
                )
            }
            guard isValid(portion.nutrientsPer100Grams) else {
                throw NutritionCalculationError.invalidNutrients(
                    lineIdentifier: portion.lineIdentifier
                )
            }

            let factor = portion.weightGrams / 100
            let rawLine = scale(portion.nutrientsPer100Grams, by: factor)
            rawTotal = add(rawTotal, rawLine)
            lineResults.append(NutritionLineResult(
                lineIdentifier: portion.lineIdentifier,
                weightGrams: round(portion.weightGrams, scale: 1),
                nutrients: rounded(rawLine)
            ))
        }

        return NutritionCalculationResult(
            algorithmVersion: algorithmVersion,
            lines: lineResults,
            total: rounded(rawTotal)
        )
    }

    private static func isValid(_ facts: NutritionFacts) -> Bool {
        [
            facts.energyKilocalories,
            facts.proteinGrams,
            facts.carbohydrateGrams,
            facts.fatGrams,
            facts.fiberGrams,
            facts.sugarGrams,
            facts.sodiumMilligrams
        ].allSatisfy(isValid)
    }

    private static func isValid(_ value: Decimal) -> Bool {
        !value.isNaN && value >= 0
    }

    private static func scale(_ facts: NutritionFacts, by factor: Decimal) -> NutritionFacts {
        NutritionFacts(
            energyKilocalories: facts.energyKilocalories * factor,
            proteinGrams: facts.proteinGrams * factor,
            carbohydrateGrams: facts.carbohydrateGrams * factor,
            fatGrams: facts.fatGrams * factor,
            fiberGrams: facts.fiberGrams * factor,
            sugarGrams: facts.sugarGrams * factor,
            sodiumMilligrams: facts.sodiumMilligrams * factor
        )
    }

    private static func add(_ lhs: NutritionFacts, _ rhs: NutritionFacts) -> NutritionFacts {
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

    private static func rounded(_ facts: NutritionFacts) -> NutritionFacts {
        NutritionFacts(
            energyKilocalories: round(facts.energyKilocalories, scale: 1),
            proteinGrams: round(facts.proteinGrams, scale: 2),
            carbohydrateGrams: round(facts.carbohydrateGrams, scale: 2),
            fatGrams: round(facts.fatGrams, scale: 2),
            fiberGrams: round(facts.fiberGrams, scale: 2),
            sugarGrams: round(facts.sugarGrams, scale: 2),
            sodiumMilligrams: round(facts.sodiumMilligrams, scale: 1)
        )
    }

    private static func round(_ value: Decimal, scale: Int) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }
}
