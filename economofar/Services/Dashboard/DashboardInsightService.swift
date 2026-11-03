import Foundation

final class DashboardInsightService {

    static let shared = DashboardInsightService()

    // Simulator:
    private var baseURL: String { AppConfig.baseURL + "/api" }

    // Real iPhone:
    // Replace localhost with your Mac IP, for example:
    // private let baseURL = "http://192.168.1.20:8080/api"

    private init() {}

    func fetchDashboardInsights(token: String? = nil) async throws -> DashboardInsightsResponse {
        let request = try makeRequest(
            path: "/dashboard/insights",
            method: "GET",
            token: token
        )

        return try await perform(request, responseType: DashboardInsightsResponse.self)
    }

    private func makeRequest(
        path: String,
        method: String,
        token: String?
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw DashboardInsightServiceError.invalidURL
        }

        let resolvedToken = try resolveToken(token)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(resolvedToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return request
    }

    private func resolveToken(_ token: String?) throws -> String {
        if let token,
           !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return token
        }

        if let savedToken = KeychainManager.loadToken(),
           !savedToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return savedToken
        }

        throw DashboardInsightServiceError.missingToken
    }

    private func perform<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DashboardInsightServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let backendMessage = decodeBackendError(from: data)

            throw DashboardInsightServiceError.backendError(
                statusCode: httpResponse.statusCode,
                message: backendMessage
            )
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let rawResponse = String(data: data, encoding: .utf8) ?? "No response body"

            throw DashboardInsightServiceError.decodingFailed(
                """
                \(error.localizedDescription)

                Backend response:
                \(rawResponse)
                """
            )
        }
    }

    private func decodeBackendError(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = json["message"] as? String {
                return message
            }

            if let error = json["error"] as? String {
                return error
            }

            if let detail = json["detail"] as? String {
                return detail
            }
        }

        return String(data: data, encoding: .utf8) ?? "Unknown backend error"
    }
}

enum DashboardInsightServiceError: LocalizedError {
    case invalidURL
    case missingToken
    case invalidResponse
    case backendError(statusCode: Int, message: String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL dashboard invalide."

        case .missingToken:
            return "Session expirée. Veuillez vous reconnecter."

        case .invalidResponse:
            return "Réponse serveur invalide."

        case .backendError(let statusCode, let message):
            return "Erreur serveur \(statusCode): \(message)"

        case .decodingFailed(let message):
            return "Erreur de lecture du dashboard: \(message)"
        }
    }
}
