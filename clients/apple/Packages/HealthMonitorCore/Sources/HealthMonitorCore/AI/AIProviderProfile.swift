import Foundation

public enum AIProviderKind: String, Codable, Sendable {
    case officialGateway
    case openAICompatible
    case qwen
    case localRules
}

public enum QwenRegion: String, Codable, CaseIterable, Sendable {
    case chinaBeijing
    case singapore
    case unitedStates

    public var baseURL: URL {
        switch self {
        case .chinaBeijing:
            URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1")!
        case .singapore:
            URL(string: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1")!
        case .unitedStates:
            URL(string: "https://dashscope-us.aliyuncs.com/compatible-mode/v1")!
        }
    }
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
