import Foundation

public enum NutritionLabelCalculationError: LocalizedError, Equatable, Sendable {
    case labelNotPresent
    case invalidConsumedWeight
    case invalidConsumedBasisCount
    case missingReferenceWeight

    public var errorDescription: String? {
        switch self {
        case .labelNotPresent:
            "没有可用的营养成分表。"
        case .invalidConsumedWeight:
            "实际摄入重量必须在 0 到 20000 克之间。"
        case .invalidConsumedBasisCount:
            "实际摄入份数或包装数必须大于 0。"
        case .missingReferenceWeight:
            "无法确定营养表对应的每份或每包装重量。"
        }
    }
}

public struct CalculatedLabelNutrition: Equatable, Sendable {
    public let energyKilocalories: Decimal?
    public let proteinGrams: Decimal?
    public let carbohydrateGrams: Decimal?
    public let fatGrams: Decimal?
    public let fiberGrams: Decimal?
    public let sugarGrams: Decimal?
    public let sodiumMilligrams: Decimal?

    public init(
        energyKilocalories: Decimal?,
        proteinGrams: Decimal?,
        carbohydrateGrams: Decimal?,
        fatGrams: Decimal?,
        fiberGrams: Decimal?,
        sugarGrams: Decimal?,
        sodiumMilligrams: Decimal?
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

public enum NutritionLabelCalculator {
    public static func calculate(
        label: RecognizedNutritionLabel,
        package: MealPackageInformation?,
        consumedWeightGrams: Decimal
    ) throws -> CalculatedLabelNutrition {
        guard label.present else {
            throw NutritionLabelCalculationError.labelNotPresent
        }
        guard consumedWeightGrams > 0, consumedWeightGrams <= 20_000 else {
            throw NutritionLabelCalculationError.invalidConsumedWeight
        }

        let referenceWeight: Decimal
        switch label.basis {
        case .per100g:
            referenceWeight = 100
        case .perServing:
            guard let servingSize = package?.servingSizeGrams, servingSize > 0 else {
                throw NutritionLabelCalculationError.missingReferenceWeight
            }
            referenceWeight = servingSize
        case .perPackage:
            guard let packageWeight = package?.drainedWeightGrams ?? package?.netWeightGrams,
                  packageWeight > 0 else {
                throw NutritionLabelCalculationError.missingReferenceWeight
            }
            referenceWeight = packageWeight
        case .unknown:
            throw NutritionLabelCalculationError.missingReferenceWeight
        }

        return calculatedNutrition(
            label: label,
            factor: consumedWeightGrams / referenceWeight
        )
    }

    public static func calculate(
        label: RecognizedNutritionLabel,
        consumedBasisCount: Decimal
    ) throws -> CalculatedLabelNutrition {
        guard label.present else {
            throw NutritionLabelCalculationError.labelNotPresent
        }
        guard consumedBasisCount > 0, consumedBasisCount <= 1_000 else {
            throw NutritionLabelCalculationError.invalidConsumedBasisCount
        }
        guard label.basis == .perServing || label.basis == .perPackage else {
            throw NutritionLabelCalculationError.missingReferenceWeight
        }
        let printedBasisCount = label.basisQuantity ?? 1
        guard printedBasisCount > 0, printedBasisCount <= 1_000 else {
            throw NutritionLabelCalculationError.invalidConsumedBasisCount
        }

        return calculatedNutrition(
            label: label,
            factor: consumedBasisCount / printedBasisCount
        )
    }

    private static func calculatedNutrition(
        label: RecognizedNutritionLabel,
        factor: Decimal
    ) -> CalculatedLabelNutrition {
        let printedEnergyKilocalories = label.energyKilocalories
            ?? label.energyKilojoules.map { $0 / Decimal(string: "4.184")! }

        return CalculatedLabelNutrition(
            energyKilocalories: scaled(printedEnergyKilocalories, by: factor),
            proteinGrams: scaled(label.proteinGrams, by: factor),
            carbohydrateGrams: scaled(label.carbohydrateGrams, by: factor),
            fatGrams: scaled(label.fatGrams, by: factor),
            fiberGrams: scaled(label.fiberGrams, by: factor),
            sugarGrams: scaled(label.sugarGrams, by: factor),
            sodiumMilligrams: scaled(label.sodiumMilligrams, by: factor)
        )
    }

    private static func scaled(_ value: Decimal?, by factor: Decimal) -> Decimal? {
        value.map { rounded($0 * factor) }
    }

    private static func rounded(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 3, .plain)
        return result
    }
}
