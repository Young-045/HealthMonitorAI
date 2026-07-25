import Foundation

public enum AIProviderError: Error, Equatable, Sendable {
    case invalidConfiguration(String)
    case missingAPIKey
    case transport(String)
    case unauthorized
    case forbidden
    case rateLimited
    case serviceUnavailable
    case imageNotSupported
    case httpStatus(Int, code: String?)
    case invalidResponse
    case contractViolation(String)
}

extension AIProviderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message): message
        case .missingAPIKey: "请先保存 Qwen API Key。"
        case .transport(let message): "网络请求失败：\(message)"
        case .unauthorized: "API Key 无效，或 API Key 与区域、Base URL 不匹配。"
        case .forbidden: "当前账号、Workspace 或 API Key 没有调用该模型的权限。"
        case .rateLimited: "Qwen 请求过于频繁或额度受限，请稍后再试。"
        case .serviceUnavailable: "Qwen 服务暂时不可用，请稍后再试。"
        case .imageNotSupported: "当前版本尚未启用图片识别，请先使用文字描述餐食。"
        case .httpStatus(let status, let code):
            if let code { "Qwen 请求失败（HTTP \(status)，错误码 \(code)）。" }
            else { "Qwen 请求失败（HTTP \(status)）。" }
        case .invalidResponse: "Qwen 返回了无法解析的响应。"
        case .contractViolation(let message): "Qwen 返回内容不符合餐食识别契约：\(message)"
        }
    }
}
