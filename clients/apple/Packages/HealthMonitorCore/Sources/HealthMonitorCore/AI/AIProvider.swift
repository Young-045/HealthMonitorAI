import Foundation

public protocol AIProvider: Sendable {
    var capabilities: AICapabilities { get }

    func analyzeMeal(_ request: MealAnalysisRequest) async throws -> MealAnalysisResult
    func testConnection() async throws -> ConnectionTestResult
}

public struct AICapabilities: Codable, Equatable, Sendable {
    public let supportsVision: Bool
    public let supportsStructuredOutput: Bool

    public init(supportsVision: Bool, supportsStructuredOutput: Bool) {
        self.supportsVision = supportsVision
        self.supportsStructuredOutput = supportsStructuredOutput
    }
}

public struct ConnectionTestResult: Codable, Equatable, Sendable {
    public let isAvailable: Bool
    public let model: String
    public let latencyMilliseconds: Int

    public init(isAvailable: Bool, model: String, latencyMilliseconds: Int) {
        self.isAvailable = isAvailable
        self.model = model
        self.latencyMilliseconds = latencyMilliseconds
    }
}
