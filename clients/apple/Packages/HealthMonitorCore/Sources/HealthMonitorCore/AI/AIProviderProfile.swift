import Foundation

public enum AIProviderKind: String, Codable, Sendable {
    case officialGateway
    case openAICompatible
    case localRules
}

public struct AIProviderProfile: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var displayName: String
    public var kind: AIProviderKind
    public var baseURL: URL?
    public var visionModel: String?
    public var textModel: String?
    public var timeoutSeconds: Int

    public init(
        id: UUID = UUID(),
        displayName: String,
        kind: AIProviderKind,
        baseURL: URL? = nil,
        visionModel: String? = nil,
        textModel: String? = nil,
        timeoutSeconds: Int = 60
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.baseURL = baseURL
        self.visionModel = visionModel
        self.textModel = textModel
        self.timeoutSeconds = timeoutSeconds
    }
}
