import Foundation

public struct MealAnalysisRequest: Codable, Equatable, Sendable {
    public let requestId: String
    public let locale: String
    public let description: String?
    public let image: MealImage?

    public init(requestId: String, locale: String, description: String?, image: MealImage?) {
        self.requestId = requestId
        self.locale = locale
        self.description = description
        self.image = image
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
    public let foods: [RecognizedFood]
    public let warnings: [String]
    public let model: String
    public let processingTimeMilliseconds: Int

    public init(
        schemaVersion: String,
        requestId: String,
        foods: [RecognizedFood],
        warnings: [String],
        model: String,
        processingTimeMilliseconds: Int
    ) {
        self.schemaVersion = schemaVersion
        self.requestId = requestId
        self.foods = foods
        self.warnings = warnings
        self.model = model
        self.processingTimeMilliseconds = processingTimeMilliseconds
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
