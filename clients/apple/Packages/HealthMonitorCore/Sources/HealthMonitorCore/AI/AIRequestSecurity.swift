import Foundation

public enum AIRequestSecurity {
    public static func validatedChatCompletionsURL(baseURL: URL) throws -> URL {
        guard baseURL.scheme?.lowercased() == "https",
              let host = baseURL.host,
              !host.isEmpty,
              baseURL.user == nil,
              baseURL.password == nil else {
            throw AIProviderError.invalidConfiguration(
                "API 地址必须是无用户名和密码的 HTTPS URL。"
            )
        }

        return baseURL
            .appendingPathComponent("chat")
            .appendingPathComponent("completions")
    }

    public static func validateQwenBaseURL(_ baseURL: URL) throws {
        _ = try validatedChatCompletionsURL(baseURL: baseURL)
        guard let host = baseURL.host?.lowercased(),
              host.hasSuffix(".aliyuncs.com") else {
            throw AIProviderError.invalidConfiguration(
                "Qwen API 地址必须使用阿里云 aliyuncs.com 域名。"
            )
        }
    }

    public static func redirectedRequest(
        from originalURL: URL,
        to proposedRequest: URLRequest,
        authorization: String?
    ) -> URLRequest? {
        guard let targetURL = proposedRequest.url,
              originalURL.scheme?.lowercased() == "https",
              targetURL.scheme?.lowercased() == "https",
              originalURL.host?.lowercased() == targetURL.host?.lowercased(),
              effectivePort(originalURL) == effectivePort(targetURL) else {
            return nil
        }

        var request = proposedRequest
        if let authorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private static func effectivePort(_ url: URL) -> Int {
        url.port ?? 443
    }
}

final class SecureAIRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let originalURL = task.originalRequest?.url else {
            completionHandler(nil)
            return
        }
        completionHandler(AIRequestSecurity.redirectedRequest(
            from: originalURL,
            to: request,
            authorization: task.originalRequest?.value(forHTTPHeaderField: "Authorization")
        ))
    }
}
