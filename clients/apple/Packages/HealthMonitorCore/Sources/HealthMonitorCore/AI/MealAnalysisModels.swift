import Foundation

public struct MealAnalysisRequest: Codable, Equatable, Sendable {
    public let requestId: String
    public let locale: String
    public let description: String?
    public let image: MealImage?
    public let healthSummary: MealHealthSummary?

    public init(
        requestId: String,
        locale: String,
        description: String?,
        image: MealImage?,
        healthSummary: MealHealthSummary? = nil
    ) {
        self.requestId = requestId
        self.locale = locale
        self.description = description
        self.image = image
        self.healthSummary = healthSummary
    }
}

public struct MealHealthSummary: Codable, Equatable, Sendable {
    public let steps: Int?
    public let activeEnergyKilocalories: Int?
    public let exerciseMinutes: Int?
    public let recentSleepDayMinutes: Int?

    public init(
        steps: Int?,
        activeEnergyKilocalories: Int?,
        exerciseMinutes: Int?,
        recentSleepDayMinutes: Int?
    ) {
        self.steps = steps
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.exerciseMinutes = exerciseMinutes
        self.recentSleepDayMinutes = recentSleepDayMinutes
    }
}

public struct MealImage: Codable, Equatable, Sendable {
    public let contentType: String
    public let base64: String

    public init(contentType: String, data: Data) {
        self.contentType = contentType
        self.base64 = data.base64EncodedString()
    }
}

public struct MealAnalysisResult: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let requestId: String
    public let imageType: MealImageType
    public let product: RecognizedProduct?
    public let package: MealPackageInformation?
    public let nutritionLabel: RecognizedNutritionLabel?
    public let foods: [RecognizedFood]
    public let warnings: [String]
    public let model: String
    public let processingTimeMilliseconds: Int

    public init(
        schemaVersion: String,
        requestId: String,
        imageType: MealImageType = .unknown,
        product: RecognizedProduct? = nil,
        package: MealPackageInformation? = nil,
        nutritionLabel: RecognizedNutritionLabel? = nil,
        foods: [RecognizedFood],
        warnings: [String],
        model: String,
        processingTimeMilliseconds: Int
    ) {
        self.schemaVersion = schemaVersion
        self.requestId = requestId
        self.imageType = imageType
        self.product = product
        self.package = package
        self.nutritionLabel = nutritionLabel
        self.foods = foods
        self.warnings = warnings
        self.model = model
        self.processingTimeMilliseconds = processingTimeMilliseconds
    }
}

public enum MealImageType: String, Codable, Equatable, Sendable {
    case meal
    case packagedFood
    case nutritionLabel
    case nutritionLabelWithVisibleFood
    case unknown
}

public struct RecognizedProduct: Codable, Equatable, Sendable {
    public let name: String?
    public let brand: String?
    public let barcode: String?
    public let confidence: Decimal

    public init(
        name: String?,
        brand: String?,
        barcode: String?,
        confidence: Decimal
    ) {
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.confidence = confidence
    }
}

public struct MealPackageInformation: Codable, Equatable, Sendable {
    public let netWeightGrams: Decimal?
    public let drainedWeightGrams: Decimal?
    public let servingSizeGrams: Decimal?
    public let servingsPerPackage: Decimal?
    public let confidence: Decimal

    public init(
        netWeightGrams: Decimal?,
        drainedWeightGrams: Decimal?,
        servingSizeGrams: Decimal?,
        servingsPerPackage: Decimal?,
        confidence: Decimal
    ) {
        self.netWeightGrams = netWeightGrams
        self.drainedWeightGrams = drainedWeightGrams
        self.servingSizeGrams = servingSizeGrams
        self.servingsPerPackage = servingsPerPackage
        self.confidence = confidence
    }
}

public enum NutritionLabelBasis: String, Codable, Equatable, Sendable {
    case per100g
    case perServing
    case perPackage
    case unknown
}

public struct RecognizedNutritionLabel: Codable, Equatable, Sendable {
    public let present: Bool
    public let basis: NutritionLabelBasis
    public let basisDescription: String?
    public let basisQuantity: Decimal?
    public let basisUnit: String?
    public let energyKilocalories: Decimal?
    public let energyKilojoules: Decimal?
    public let proteinGrams: Decimal?
    public let carbohydrateGrams: Decimal?
    public let fatGrams: Decimal?
    public let fiberGrams: Decimal?
    public let sugarGrams: Decimal?
    public let sodiumMilligrams: Decimal?
    public let saltEquivalentGrams: Decimal?
    public let rawText: String?
    public let unreadableFields: [String]
    public let confidence: Decimal

    public init(
        present: Bool,
        basis: NutritionLabelBasis,
        basisDescription: String? = nil,
        basisQuantity: Decimal? = nil,
        basisUnit: String? = nil,
        energyKilocalories: Decimal?,
        energyKilojoules: Decimal? = nil,
        proteinGrams: Decimal?,
        carbohydrateGrams: Decimal?,
        fatGrams: Decimal?,
        fiberGrams: Decimal?,
        sugarGrams: Decimal?,
        sodiumMilligrams: Decimal?,
        saltEquivalentGrams: Decimal? = nil,
        rawText: String?,
        unreadableFields: [String],
        confidence: Decimal
    ) {
        self.present = present
        self.basis = basis
        self.basisDescription = basisDescription
        self.basisQuantity = basisQuantity
        self.basisUnit = basisUnit
        self.energyKilocalories = energyKilocalories
        self.energyKilojoules = energyKilojoules
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.sodiumMilligrams = sodiumMilligrams
        self.saltEquivalentGrams = saltEquivalentGrams
        self.rawText = rawText
        self.unreadableFields = unreadableFields
        self.confidence = confidence
    }
}

public struct RecognizedFood: Codable, Equatable, Sendable {
    public let name: String
    public let estimatedWeightGrams: Decimal
    public let weightRange: WeightRange
    public let cookingMethod: String?
    public let confidence: Decimal
    public let uncertainties: [String]

    public init(
        name: String,
        estimatedWeightGrams: Decimal,
        weightRange: WeightRange,
        cookingMethod: String?,
        confidence: Decimal,
        uncertainties: [String]
    ) {
        self.name = name
        self.estimatedWeightGrams = estimatedWeightGrams
        self.weightRange = weightRange
        self.cookingMethod = cookingMethod
        self.confidence = confidence
        self.uncertainties = uncertainties
    }
}

public struct WeightRange: Codable, Equatable, Sendable {
    public let minimumGrams: Decimal
    public let maximumGrams: Decimal

    public init(minimumGrams: Decimal, maximumGrams: Decimal) {
        self.minimumGrams = minimumGrams
        self.maximumGrams = maximumGrams
    }
}
