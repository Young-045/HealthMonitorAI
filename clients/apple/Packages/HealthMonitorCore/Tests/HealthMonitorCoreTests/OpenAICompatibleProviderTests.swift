import Foundation
import Testing
@testable import HealthMonitorCore

@Test func providerBuildsQwenConnectionRequestWithoutLeakingKeyIntoBody() async throws {
    let response = """
    {"model":"qwen3.7-plus","choices":[{"message":{"content":"{\\"ok\\":true}"}}]}
    """.data(using: .utf8)!
    let client = RecordingHTTPClient(statusCode: 200, responseData: response)
    let profile = AIProviderProfile(
        displayName: "Qwen",
        kind: .qwen,
        baseURL: QwenRegion.chinaBeijing.baseURL,
        textModel: "qwen3.7-plus"
    )
    let provider = try QwenProvider(profile: profile, apiKey: "secret-key", httpClient: client)

    let result = try await provider.testConnection()
    let request = try #require(await client.recordedRequest())

    #expect(result.model == "qwen3.7-plus")
    #expect(request.url?.absoluteString == "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-key")
    #expect(request.httpBody?.range(of: Data("secret-key".utf8)) == nil)
    let requestBody = try #require(request.httpBody)
    let body = try #require(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
    #expect(body["model"] as? String == "qwen3.7-plus")
    #expect((body["response_format"] as? [String: String])?["type"] == "json_object")
    #expect(body["enable_thinking"] as? Bool == false)
}

@Test func qwenConnectionExplainsMissingFinalContent() async throws {
    let response = """
    {"model":"qwen3.7-plus","choices":[{"message":{"content":null,"reasoning_content":"still thinking"}}]}
    """.data(using: .utf8)!
    let profile = AIProviderProfile(
        displayName: "Qwen",
        kind: .qwen,
        baseURL: QwenRegion.chinaBeijing.baseURL,
        textModel: "qwen3.7-plus"
    )
    let provider = try QwenProvider(
        profile: profile,
        apiKey: "key",
        httpClient: RecordingHTTPClient(statusCode: 200, responseData: response)
    )

    await #expect(throws: AIProviderError.self) {
        try await provider.testConnection()
    }
}

@Test func providerMapsAuthenticationAndRateLimitErrors() async throws {
    let profile = AIProviderProfile(
        displayName: "Qwen",
        kind: .qwen,
        baseURL: QwenRegion.chinaBeijing.baseURL,
        textModel: "qwen3.7-plus"
    )
    let unauthorized = try QwenProvider(
        profile: profile,
        apiKey: "bad-key",
        httpClient: RecordingHTTPClient(statusCode: 401, responseData: Data())
    )
    let rateLimited = try QwenProvider(
        profile: profile,
        apiKey: "key",
        httpClient: RecordingHTTPClient(statusCode: 429, responseData: Data())
    )

    await #expect(throws: AIProviderError.unauthorized) {
        try await unauthorized.testConnection()
    }
    await #expect(throws: AIProviderError.rateLimited) {
        try await rateLimited.testConnection()
    }
}

@Test func providerValidatesMealAnalysisContract() async throws {
    let payload = """
    {"schemaVersion":"1.0","requestId":"meal-1","foods":[{"name":"米饭","estimatedWeightGrams":150,"weightRange":{"minimumGrams":120,"maximumGrams":180},"cookingMethod":"steamed","confidence":0.9,"uncertainties":[]}],"warnings":[]}
    """
    let escapedPayload = try JSONEncoder().encode(payload)
    let content = String(decoding: escapedPayload, as: UTF8.self)
    let response = """
    {"model":"qwen3.7-plus","choices":[{"message":{"content":\(content)}}]}
    """.data(using: .utf8)!
    let client = RecordingHTTPClient(statusCode: 200, responseData: response)
    let profile = AIProviderProfile(
        displayName: "Qwen",
        kind: .qwen,
        baseURL: QwenRegion.chinaBeijing.baseURL,
        textModel: "qwen3.7-plus"
    )
    let provider = try QwenProvider(profile: profile, apiKey: "key", httpClient: client)

    let result = try await provider.analyzeMeal(MealAnalysisRequest(
        requestId: "meal-1",
        locale: "zh-CN",
        description: "米饭 150 克",
        image: nil
    ))

    #expect(result.foods.count == 1)
    #expect(result.foods[0].name == "米饭")
    #expect(result.foods[0].estimatedWeightGrams == 150)
}

@Test func providerUsesVisionModelAndEncodesImageAsDataURL() async throws {
    let payload = """
    {"schemaVersion":"1.0","requestId":"image-1","foods":[],"warnings":[]}
    """
    let escapedPayload = try JSONEncoder().encode(payload)
    let content = String(decoding: escapedPayload, as: UTF8.self)
    let response = """
    {"model":"qwen3.7-plus","choices":[{"message":{"content":\(content)}}]}
    """.data(using: .utf8)!
    let client = RecordingHTTPClient(statusCode: 200, responseData: response)
    let profile = AIProviderProfile(
        displayName: "Qwen",
        kind: .qwen,
        baseURL: QwenRegion.chinaBeijing.baseURL,
        visionModel: "qwen3.7-plus",
        textModel: "qwen3.7-flash"
    )
    let provider = try QwenProvider(profile: profile, apiKey: "key", httpClient: client)

    _ = try await provider.analyzeMeal(MealAnalysisRequest(
        requestId: "image-1",
        locale: "zh-CN",
        description: nil,
        image: MealImage(contentType: "image/png", data: Data([0x89, 0x50, 0x4e, 0x47]))
    ))
    let request = try #require(await client.recordedRequest())
    let requestBody = try #require(request.httpBody)
    let body = try #require(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
    #expect(body["model"] as? String == "qwen3.7-plus")
    let messages = try #require(body["messages"] as? [[String: Any]])
    let userContent = try #require(messages.last?["content"] as? [[String: Any]])
    let imagePart = try #require(userContent.first)
    let imageURL = try #require(imagePart["image_url"] as? [String: String])
    #expect(imagePart["type"] as? String == "image_url")
    #expect(imageURL["url"] == "data:image/png;base64,iVBORw==")
}

@Test func providerRejectsUnsupportedImageBeforeSending() async throws {
    let client = RecordingHTTPClient(statusCode: 200, responseData: Data())
    let profile = AIProviderProfile(
        displayName: "Qwen",
        kind: .qwen,
        baseURL: QwenRegion.chinaBeijing.baseURL,
        visionModel: "qwen3.7-plus",
        textModel: "qwen3.7-plus"
    )
    let provider = try QwenProvider(profile: profile, apiKey: "key", httpClient: client)

    await #expect(throws: AIProviderError.self) {
        try await provider.analyzeMeal(MealAnalysisRequest(
            requestId: "bad-image",
            locale: "zh-CN",
            description: nil,
            image: MealImage(contentType: "image/gif", data: Data([1, 2, 3]))
        ))
    }
    #expect(await client.recordedRequest() == nil)
}

@Test func providerRejectsImageWhoseEncodedDataURLExceedsLimit() async throws {
    let client = RecordingHTTPClient(statusCode: 200, responseData: Data())
    let profile = AIProviderProfile(
        displayName: "Qwen",
        kind: .qwen,
        baseURL: QwenRegion.chinaBeijing.baseURL,
        visionModel: "qwen3.7-plus",
        textModel: "qwen3.7-plus"
    )
    let provider = try QwenProvider(profile: profile, apiKey: "key", httpClient: client)
    let oversizedImage = MealImage(
        contentType: "image/jpeg",
        data: Data(repeating: 0, count: 8 * 1_024 * 1_024)
    )

    await #expect(throws: AIProviderError.self) {
        try await provider.analyzeMeal(MealAnalysisRequest(
            requestId: "large-image",
            locale: "zh-CN",
            description: nil,
            image: oversizedImage
        ))
    }
    #expect(await client.recordedRequest() == nil)
}

@Test func requestSecurityRejectsInsecureAndCrossHostRedirects() throws {
    #expect(throws: AIProviderError.self) {
        try AIRequestSecurity.validatedChatCompletionsURL(
            baseURL: URL(string: "http://dashscope.aliyuncs.com/compatible-mode/v1")!
        )
    }
    let original = URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")!
    var crossHost = URLRequest(url: URL(string: "https://attacker.example/collect")!)
    crossHost.httpMethod = "POST"
    #expect(AIRequestSecurity.redirectedRequest(
        from: original,
        to: crossHost,
        authorization: "Bearer secret"
    ) == nil)

    var sameHost = URLRequest(url: URL(string: "https://dashscope.aliyuncs.com/new-path")!)
    sameHost.httpMethod = "POST"
    let allowed = AIRequestSecurity.redirectedRequest(
        from: original,
        to: sameHost,
        authorization: "Bearer secret"
    )
    #expect(allowed?.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
}

@Test func qwenProviderRejectsNonAlibabaHosts() throws {
    let profile = AIProviderProfile(
        displayName: "Fake Qwen",
        kind: .qwen,
        baseURL: URL(string: "https://qwen.attacker.example/v1"),
        textModel: "qwen3.7-plus"
    )

    #expect(throws: AIProviderError.self) {
        try QwenProvider(profile: profile, apiKey: "secret")
    }
}

private actor RecordingHTTPClient: AIHTTPClient {
    private let statusCode: Int
    private let responseData: Data
    private var request: URLRequest?

    init(statusCode: Int, responseData: Data) {
        self.statusCode = statusCode
        self.responseData = responseData
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        self.request = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (responseData, response)
    }

    func recordedRequest() -> URLRequest? {
        request
    }
}
