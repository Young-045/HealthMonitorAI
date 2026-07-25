import Foundation

public enum AIProviderRouterError: Error, Equatable, Sendable {
    case noActiveProvider
    case providerNotRegistered(UUID)
}

public actor AIProviderRouter {
    private var providers: [UUID: any AIProvider] = [:]
    private var activeProfileID: UUID?

    public init(activeProfileID: UUID? = nil) {
        self.activeProfileID = activeProfileID
    }

    public func register(_ provider: any AIProvider, for profileID: UUID) {
        providers[profileID] = provider
    }

    public func unregister(profileID: UUID) {
        providers[profileID] = nil
        if activeProfileID == profileID {
            activeProfileID = nil
        }
    }

    public func select(profileID: UUID?) throws {
        if let profileID, providers[profileID] == nil {
            throw AIProviderRouterError.providerNotRegistered(profileID)
        }
        activeProfileID = profileID
    }

    public func selectedProfileID() -> UUID? {
        activeProfileID
    }

    public func capabilities() throws -> AICapabilities {
        try activeProvider().capabilities
    }

    public func analyzeMeal(_ request: MealAnalysisRequest) async throws -> MealAnalysisResult {
        try await activeProvider().analyzeMeal(request)
    }

    public func testConnection() async throws -> ConnectionTestResult {
        try await activeProvider().testConnection()
    }

    private func activeProvider() throws -> any AIProvider {
        guard let activeProfileID else {
            throw AIProviderRouterError.noActiveProvider
        }
        guard let provider = providers[activeProfileID] else {
            throw AIProviderRouterError.providerNotRegistered(activeProfileID)
        }
        return provider
    }
}
