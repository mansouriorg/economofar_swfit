import Foundation

final class DashboardInsightService {

    static let shared = DashboardInsightService()

    private let baseURL = "http://localhost:8080/api"

    private init() {}

    func fetchDashboardInsights() async throws -> DashboardInsightsResponse {
        let request = try makeRequest(
            path: "/dashboard/insights",
            method: "GET"
        )

        return try await perform(request, responseType: DashboardInsightsResponse.self)
    }

    private func makeRequest(
        path: String,
        method: String
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw DashboardInsightServiceError.invalidURL
        }

        guard let token = UserDefaults.standard.string(forKey: "jwt_token"), !token.isEmpty else {
            throw DashboardInsightServiceError.missingToken
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return request
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
            let backendMessage = String(data: data, encoding: .utf8) ?? "Unknown backend error"
            throw DashboardInsightServiceError.backendError(
                statusCode: httpResponse.statusCode,
                message: backendMessage
            )
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw DashboardInsightServiceError.decodingFailed(error.localizedDescription)
        }
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
            return "Erreur de lecture des données dashboard: \(message)"
        }
    }
}
