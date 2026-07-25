import Foundation

public protocol AIHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public final class SecureURLSessionAIHTTPClient: AIHTTPClient, @unchecked Sendable {
    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(
            configuration: configuration,
            delegate: SecureAIRedirectDelegate(),
            delegateQueue: nil
        )
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse
        }
        return (data, httpResponse)
    }
}

public struct OpenAICompatibleProvider: AIProvider {
    public let capabilities: AICapabilities

    private let endpoint: URL
    private let textModel: String
    private let visionModel: String?
    private let apiKey: String
    private let timeoutSeconds: Int
    private let enableThinking: Bool?
    private let httpClient: any AIHTTPClient

    public init(
        profile: AIProviderProfile,
        apiKey: String,
        capabilities: AICapabilities = AICapabilities(
            supportsVision: false,
            supportsStructuredOutput: true
        ),
        enableThinking: Bool? = nil,
        httpClient: any AIHTTPClient = SecureURLSessionAIHTTPClient()
    ) throws {
        guard let baseURL = profile.baseURL else {
            throw AIProviderError.invalidConfiguration("请填写 API Base URL。")
        }
        let textModel = profile.textModel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !textModel.isEmpty else {
            throw AIProviderError.invalidConfiguration("请填写文字模型。")
        }
        let configuredVisionModel = profile.visionModel?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let visionModel = configuredVisionModel?.isEmpty == false ? configuredVisionModel : nil
        let apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }
        guard (5...300).contains(profile.timeoutSeconds) else {
            throw AIProviderError.invalidConfiguration("超时时间必须在 5 到 300 秒之间。")
        }

        self.endpoint = try AIRequestSecurity.validatedChatCompletionsURL(baseURL: baseURL)
        self.textModel = textModel
        self.visionModel = visionModel
        self.apiKey = apiKey
        self.timeoutSeconds = profile.timeoutSeconds
        self.capabilities = capabilities
        self.enableThinking = enableThinking
        self.httpClient = httpClient
    }

    public func analyzeMeal(_ request: MealAnalysisRequest) async throws -> MealAnalysisResult {
        let startedAt = ContinuousClock.now
        let prompt = Self.mealPrompt(for: request)
        let userContent: MessageContent
        let selectedModel: String
        if let image = request.image {
            guard capabilities.supportsVision, let visionModel else {
                throw AIProviderError.imageNotSupported
            }
            let dataURL = try Self.validatedDataURL(for: image)
            userContent = .multimodal([
                .imageURL(dataURL),
                .text(prompt)
            ])
            selectedModel = visionModel
        } else {
            userContent = .text(prompt)
            selectedModel = textModel
        }
        let response = try await perform(messages: [
            ChatMessage(role: "system", content: .text(Self.mealSystemPrompt)),
            ChatMessage(role: "user", content: userContent)
        ], model: selectedModel)
        guard let content = response.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty,
              let data = content.data(using: .utf8) else {
            throw AIProviderError.contractViolation("模型未返回最终餐食内容。")
        }

        let payload: MealAnalysisPayload
        do {
            payload = try JSONDecoder().decode(MealAnalysisPayload.self, from: data)
        } catch {
            throw AIProviderError.invalidResponse
        }
        try Self.validate(payload, requestID: request.requestId)

        return MealAnalysisResult(
            schemaVersion: payload.schemaVersion,
            requestId: payload.requestId,
            foods: payload.foods,
            warnings: payload.warnings,
            model: response.model,
            processingTimeMilliseconds: Self.milliseconds(since: startedAt)
        )
    }

    public func testConnection() async throws -> ConnectionTestResult {
        let startedAt = ContinuousClock.now
        let response = try await perform(messages: [
            ChatMessage(
                role: "system",
                content: .text("Return JSON only. Reply with exactly {\"ok\":true}.")
            ),
            ChatMessage(role: "user", content: .text("Connection test. Output JSON."))
        ], model: textModel, maxCompletionTokens: 256)
        guard let content = response.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty,
              let data = content.data(using: .utf8),
              let object = try? JSONDecoder().decode(ConnectionPayload.self, from: data),
              object.ok else {
            throw AIProviderError.contractViolation(
                "连接已建立，但模型没有返回预期 JSON；请确认模型支持非思考模式和结构化输出。"
            )
        }

        return ConnectionTestResult(
            isAvailable: true,
            model: response.model,
            latencyMilliseconds: Self.milliseconds(since: startedAt)
        )
    }

    public func testVisionConnection(image: MealImage) async throws -> ConnectionTestResult {
        guard capabilities.supportsVision, let visionModel else {
            throw AIProviderError.imageNotSupported
        }
        let startedAt = ContinuousClock.now
        let dataURL = try Self.validatedDataURL(for: image)
        let response = try await perform(messages: [
            ChatMessage(
                role: "system",
                content: .text("Inspect the image and return JSON only. Reply with exactly {\"ok\":true}.")
            ),
            ChatMessage(role: "user", content: .multimodal([
                .imageURL(dataURL),
                .text("Vision connection test. Output JSON.")
            ]))
        ], model: visionModel, maxCompletionTokens: 256)
        guard let content = response.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              let data = content.data(using: .utf8),
              let object = try? JSONDecoder().decode(ConnectionPayload.self, from: data),
              object.ok else {
            throw AIProviderError.contractViolation("视觉模型没有返回预期 JSON。")
        }
        return ConnectionTestResult(
            isAvailable: true,
            model: response.model,
            latencyMilliseconds: Self.milliseconds(since: startedAt)
        )
    }

    private func perform(
        messages: [ChatMessage],
        model: String,
        maxCompletionTokens: Int = 1_500
    ) async throws -> ChatCompletionResponse {
        let body = ChatCompletionRequest(
            model: model,
            messages: messages,
            responseFormat: ResponseFormat(type: "json_object"),
            temperature: 0.1,
            maxCompletionTokens: maxCompletionTokens,
            enableThinking: enableThinking
        )
        var request = URLRequest(url: endpoint, timeoutInterval: TimeInterval(timeoutSeconds))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await httpClient.data(for: request)
        } catch let error as AIProviderError {
            throw error
        } catch let error as URLError {
            throw AIProviderError.transport(error.localizedDescription)
        } catch {
            throw AIProviderError.transport(error.localizedDescription)
        }

        guard (200...299).contains(response.statusCode) else {
            throw Self.httpError(status: response.statusCode, data: data)
        }
        guard let decoded = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data),
              !decoded.choices.isEmpty else {
            throw AIProviderError.invalidResponse
        }
        return decoded
    }

    private static func httpError(status: Int, data: Data) -> AIProviderError {
        switch status {
        case 401: return .unauthorized
        case 403: return .forbidden
        case 429: return .rateLimited
        case 500...599: return .serviceUnavailable
        default:
            let code = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error.code
            return .httpStatus(status, code: code)
        }
    }

    private static func validate(_ payload: MealAnalysisPayload, requestID: String) throws {
        guard payload.schemaVersion == "1.0" else {
            throw AIProviderError.contractViolation("不支持的 schemaVersion。")
        }
        guard payload.requestId == requestID else {
            throw AIProviderError.contractViolation("requestId 不匹配。")
        }
        guard payload.foods.count <= 30 else {
            throw AIProviderError.contractViolation("食物条目过多。")
        }
        for food in payload.foods {
            guard !food.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  food.name.count <= 100 else {
                throw AIProviderError.contractViolation("食物名称无效。")
            }
            guard food.estimatedWeightGrams >= 0,
                  food.weightRange.minimumGrams >= 0,
                  food.weightRange.maximumGrams >= food.weightRange.minimumGrams,
                  food.estimatedWeightGrams <= 20_000,
                  food.weightRange.maximumGrams <= 20_000 else {
                throw AIProviderError.contractViolation("重量范围无效。")
            }
            guard food.confidence >= 0, food.confidence <= 1 else {
                throw AIProviderError.contractViolation("置信度超出范围。")
            }
            guard food.uncertainties.count <= 20,
                  food.uncertainties.allSatisfy({ $0.count <= 200 }) else {
                throw AIProviderError.contractViolation("不确定项过多或过长。")
            }
        }
    }

    private static func validatedDataURL(for image: MealImage) throws -> String {
        let allowedContentTypes = ["image/jpeg", "image/png", "image/webp"]
        guard allowedContentTypes.contains(image.contentType.lowercased()) else {
            throw AIProviderError.contractViolation("图片必须是 JPEG、PNG 或 WebP。")
        }
        guard let data = Data(base64Encoded: image.base64), !data.isEmpty else {
            throw AIProviderError.contractViolation("图片 Base64 数据无效。")
        }
        let dataURL = "data:\(image.contentType.lowercased());base64,\(image.base64)"
        guard dataURL.utf8.count < 10 * 1_024 * 1_024 else {
            throw AIProviderError.contractViolation("图片 Base64 编码后必须小于 10 MB。")
        }
        return dataURL
    }

    private static func mealPrompt(for request: MealAnalysisRequest) -> String {
        let description = request.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let healthSummary = request.healthSummary.map(Self.healthSummaryText) ?? "Not shared"
        return """
        Locale: \(request.locale)
        Request ID: \(request.requestId)
        User description: \(description?.isEmpty == false ? description! : "Not provided")
        Optional user-authorized aggregate health summary: \(healthSummary)
        Output JSON only. Do not provide calories or nutrient values.
        """
    }

    private static func healthSummaryText(_ summary: MealHealthSummary) -> String {
        let fields: [String] = [
            summary.steps.map { "steps=\($0)" },
            summary.activeEnergyKilocalories.map { "activeEnergyKilocalories=\($0)" },
            summary.exerciseMinutes.map { "exerciseMinutes=\($0)" },
            summary.recentSleepDayMinutes.map { "recentSleepDayMinutes=\($0)" }
        ].compactMap { $0 }
        return fields.isEmpty ? "No available values" : fields.joined(separator: ", ")
    }

    private static let mealSystemPrompt = """
    Identify foods from the user's meal description. Output JSON only with schemaVersion "1.0", requestId, foods, and warnings. Each food must contain name, estimatedWeightGrams, weightRange with minimumGrams and maximumGrams, optional cookingMethod, confidence from 0 to 1, and uncertainties. Do not calculate calories or nutrients.
    """

    private static func milliseconds(since start: ContinuousClock.Instant) -> Int {
        let duration = start.duration(to: .now)
        return Int(duration.components.seconds * 1_000)
            + Int(duration.components.attoseconds / 1_000_000_000_000_000)
    }
}

public struct QwenProvider: AIProvider {
    public let capabilities: AICapabilities
    private let provider: OpenAICompatibleProvider

    public init(
        profile: AIProviderProfile,
        apiKey: String,
        httpClient: any AIHTTPClient = SecureURLSessionAIHTTPClient()
    ) throws {
        guard let baseURL = profile.baseURL else {
            throw AIProviderError.invalidConfiguration("请填写 API Base URL。")
        }
        try AIRequestSecurity.validateQwenBaseURL(baseURL)
        let visionModel = profile.visionModel?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let capabilities = AICapabilities(
            supportsVision: visionModel?.isEmpty == false,
            supportsStructuredOutput: true
        )
        self.capabilities = capabilities
        provider = try OpenAICompatibleProvider(
            profile: profile,
            apiKey: apiKey,
            capabilities: capabilities,
            enableThinking: false,
            httpClient: httpClient
        )
    }

    public func analyzeMeal(_ request: MealAnalysisRequest) async throws -> MealAnalysisResult {
        try await provider.analyzeMeal(request)
    }

    public func testConnection() async throws -> ConnectionTestResult {
        try await provider.testConnection()
    }

    public func testVisionConnection(image: MealImage) async throws -> ConnectionTestResult {
        try await provider.testVisionConnection(image: image)
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let responseFormat: ResponseFormat
    let temperature: Double
    let maxCompletionTokens: Int
    let enableThinking: Bool?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case responseFormat = "response_format"
        case maxCompletionTokens = "max_completion_tokens"
        case enableThinking = "enable_thinking"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encode(responseFormat, forKey: .responseFormat)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(maxCompletionTokens, forKey: .maxCompletionTokens)
        try container.encodeIfPresent(enableThinking, forKey: .enableThinking)
    }
}

private struct ChatMessage: Encodable {
    let role: String
    let content: MessageContent
}

private enum MessageContent: Encodable {
    case text(String)
    case multimodal([ContentPart])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .multimodal(let parts): try container.encode(parts)
        }
    }
}

private struct ContentPart: Encodable {
    let type: String
    let text: String?
    let imageURL: ImageURL?

    static func text(_ value: String) -> ContentPart {
        ContentPart(type: "text", text: value, imageURL: nil)
    }

    static func imageURL(_ value: String) -> ContentPart {
        ContentPart(type: "image_url", text: nil, imageURL: ImageURL(url: value))
    }

    enum CodingKeys: String, CodingKey {
        case type, text
        case imageURL = "image_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
    }

    struct ImageURL: Encodable {
        let url: String
    }
}

private struct ResponseFormat: Encodable {
    let type: String
}

private struct ChatCompletionResponse: Decodable {
    let model: String
    let choices: [Choice]

    struct Choice: Decodable {
        let message: AssistantMessage
    }

    struct AssistantMessage: Decodable {
        let content: String?
        let reasoningContent: String?

        enum CodingKeys: String, CodingKey {
            case content
            case reasoningContent = "reasoning_content"
        }
    }
}

private struct MealAnalysisPayload: Decodable {
    let schemaVersion: String
    let requestId: String
    let foods: [RecognizedFood]
    let warnings: [String]
}

private struct ConnectionPayload: Decodable {
    let ok: Bool
}

private struct ErrorEnvelope: Decodable {
    let error: ErrorBody

    struct ErrorBody: Decodable {
        let code: String?
    }
}
