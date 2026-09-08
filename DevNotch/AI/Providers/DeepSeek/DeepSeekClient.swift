import Foundation

enum DeepSeekAPIError: LocalizedError, Equatable, Sendable {
    case unauthorized
    case insufficientBalance
    case rateLimited
    case serverUnavailable(statusCode: Int)
    case httpError(statusCode: Int, message: String)
    case invalidResponse
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Invalid or expired DeepSeek API key (401)"
        case .insufficientBalance:
            return "Insufficient account balance (402)"
        case .rateLimited:
            return "Too many requests (429)"
        case .serverUnavailable(let code):
            return "DeepSeek server unavailable (\(code))"
        case .httpError(let code, let msg):
            return "DeepSeek HTTP \(code): \(msg)"
        case .invalidResponse:
            return "Invalid response received from DeepSeek"
        case .networkError(let msg):
            return "Network connection failed: \(msg)"
        }
    }
}

/// Native URLSession-backed client for DeepSeek official API.
final class DeepSeekClient: Sendable {
    private let session: URLSession
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.deepseek.com")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    /// Fetches the user account balance from `GET /user/balance`.
    func fetchBalance(apiKey: String) async throws -> DeepSeekBalanceResponse {
        let endpoint = baseURL.appendingPathComponent("user/balance")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8.0

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DeepSeekAPIError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw DeepSeekAPIError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            do {
                return try JSONDecoder().decode(DeepSeekBalanceResponse.self, from: data)
            } catch {
                throw DeepSeekAPIError.invalidResponse
            }
        case 401:
            throw DeepSeekAPIError.unauthorized
        case 402:
            throw DeepSeekAPIError.insufficientBalance
        case 429:
            throw DeepSeekAPIError.rateLimited
        case 500...599:
            throw DeepSeekAPIError.serverUnavailable(statusCode: http.statusCode)
        default:
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw DeepSeekAPIError.httpError(statusCode: http.statusCode, message: msg)
        }
    }
}
