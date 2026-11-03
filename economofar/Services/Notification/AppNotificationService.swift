import Foundation

final class AppNotificationService {

    static let shared = AppNotificationService()

    private var baseURL: String { AppConfig.baseURL + "/api" }

    private init() {}

    func fetchPreferences() async throws -> NotificationPreferences {
        let request = try makeRequest(
            path: "/notifications/preferences",
            method: "GET"
        )

        return try await perform(request, responseType: NotificationPreferences.self)
    }

    func updatePreferences(_ body: UpdateNotificationPreferencesRequest) async throws -> NotificationPreferences {
        let request = try makeRequest(
            path: "/notifications/preferences",
            method: "PATCH",
            body: body
        )

        return try await perform(request, responseType: NotificationPreferences.self)
    }

    func fetchNotifications() async throws -> [AppNotification] {
        let request = try makeRequest(
            path: "/notifications",
            method: "GET"
        )

        return try await perform(request, responseType: [AppNotification].self)
    }

    func markNotificationAsRead(id: Int) async throws -> AppNotification {
        let request = try makeRequest(
            path: "/notifications/\(id)/read",
            method: "PATCH"
        )

        return try await perform(request, responseType: AppNotification.self)
    }

    func fetchBudget() async throws -> UserBudget? {
        let request = try makeRequest(
            path: "/budget",
            method: "GET"
        )

        return try await performOptional(request, responseType: UserBudget.self)
    }

    func updateBudget(monthlyAmount: Double, currency: String = AppFormat.currencyCode) async throws -> UserBudget {
        let request = try makeRequest(
            path: "/budget",
            method: "PUT",
            body: UpdateBudgetRequest(
                monthlyAmount: monthlyAmount,
                currency: currency
            )
        )

        return try await perform(request, responseType: UserBudget.self)
    }

    private func makeRequest(
        path: String,
        method: String
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw AppNotificationServiceError.invalidURL
        }

        guard let token = KeychainManager.loadToken(), !token.isEmpty else {
            throw AppNotificationServiceError.missingToken
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return request
    }

    private func makeRequest<T: Encodable>(
        path: String,
        method: String,
        body: T
    ) throws -> URLRequest {
        var request = try makeRequest(path: path, method: method)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func perform<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppNotificationServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown backend error"
            throw AppNotificationServiceError.backendError(statusCode: httpResponse.statusCode, message: message)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private func performOptional<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> T? {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppNotificationServiceError.invalidResponse
        }

        if httpResponse.statusCode == 204 {
            return nil
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown backend error"
            throw AppNotificationServiceError.backendError(statusCode: httpResponse.statusCode, message: message)
        }

        if data.isEmpty {
            return nil
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}

enum AppNotificationServiceError: LocalizedError {
    case invalidURL
    case missingToken
    case invalidResponse
    case backendError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalide."
        case .missingToken:
            return "Session expirée. Veuillez vous reconnecter."
        case .invalidResponse:
            return "Réponse serveur invalide."
        case .backendError(let statusCode, let message):
            return "Erreur serveur \(statusCode): \(message)"
        }
    }
}
