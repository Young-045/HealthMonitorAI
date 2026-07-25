import Foundation
import Testing
@testable import HealthMonitorCore

@Test func routerRequiresAnExplicitActiveProvider() async throws {
    let router = AIProviderRouter()

    await #expect(throws: AIProviderRouterError.noActiveProvider) {
        try await router.testConnection()
    }
}

@Test func routerUsesOnlyTheSelectedProvider() async throws {
    let firstID = UUID()
    let secondID = UUID()
    let router = AIProviderRouter()
    await router.register(TestAIProvider(model: "first"), for: firstID)
    await router.register(TestAIProvider(model: "second"), for: secondID)

    try await router.select(profileID: secondID)
    let result = try await router.testConnection()

    #expect(result.model == "second")
    #expect(await router.selectedProfileID() == secondID)
}

@Test func routerRejectsSelectingAnUnregisteredProfile() async throws {
    let missingID = UUID()
    let router = AIProviderRouter()

    await #expect(throws: AIProviderRouterError.providerNotRegistered(missingID)) {
        try await router.select(profileID: missingID)
    }
}

private struct TestAIProvider: AIProvider {
    let model: String
    let capabilities = AICapabilities(
        supportsVision: false,
        supportsStructuredOutput: true
    )

    func analyzeMeal(_ request: MealAnalysisRequest) async throws -> MealAnalysisResult {
        MealAnalysisResult(
            schemaVersion: "1.0",
            requestId: request.requestId,
            foods: [],
            warnings: [],
            model: model,
            processingTimeMilliseconds: 1
        )
    }

    func testConnection() async throws -> ConnectionTestResult {
        ConnectionTestResult(isAvailable: true, model: model, latencyMilliseconds: 1)
    }
}
