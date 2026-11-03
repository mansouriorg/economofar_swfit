import Foundation
import UIKit

final class SupportService {

    static let shared = SupportService()

    private var baseURL: String { AppConfig.baseURL + "/api" }

    private init() {}

    func fetchFaqs(category: String? = nil) async throws -> [FaqItem] {
        var path = "/support/faqs"

        if let category, !category.isEmpty {
            let encodedCategory = category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category
            path += "?category=\(encodedCategory)"
        }

        let request = try makeRequest(path: path, method: "GET", requiresAuth: false)
        return try await perform(request, responseType: [FaqItem].self)
    }

    func fetchSupportConfig() async throws -> SupportConfig {
        let request = try makeRequest(path: "/support/config", method: "GET", requiresAuth: false)
        return try await perform(request, responseType: SupportConfig.self)
    }

    func fetchAppStatus() async throws -> AppStatus {
        let request = try makeRequest(path: "/support/status", method: "GET", requiresAuth: false)
        return try await perform(request, responseType: AppStatus.self)
    }

    func submitContactSupport(
        subject: String,
        message: String,
        contactEmail: String?
    ) async throws -> SupportRequestResponse {
        let body = SubmitSupportRequest(
            subject: subject,
            message: message,
            appVersion: appVersion,
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            contactEmail: contactEmail
        )

        let request = try makeRequest(
            path: "/support/contact",
            method: "POST",
            body: body,
            requiresAuth: true
        )

        return try await perform(request, responseType: SupportRequestResponse.self)
    }

    func reportBug(
        subject: String,
        message: String,
        contactEmail: String?
    ) async throws -> SupportRequestResponse {
        let body = SubmitSupportRequest(
            subject: subject,
            message: message,
            appVersion: appVersion,
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            contactEmail: contactEmail
        )

        let request = try makeRequest(
            path: "/support/bug-report",
            method: "POST",
            body: body,
            requiresAuth: true
        )

        return try await perform(request, responseType: SupportRequestResponse.self)
    }

    func fetchMySupportRequests() async throws -> [SupportRequestResponse] {
        let request = try makeRequest(
            path: "/support/my-requests",
            method: "GET",
            requiresAuth: true
        )

        return try await perform(request, responseType: [SupportRequestResponse].self)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private func makeRequest(
        path: String,
        method: String,
        requiresAuth: Bool
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw SupportServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if requiresAuth {
            guard let token = KeychainManager.loadToken(), !token.isEmpty else {
                throw SupportServiceError.missingToken
            }

            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let token = KeychainManager.loadToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func makeRequest<T: Encodable>(
        path: String,
        method: String,
        body: T,
        requiresAuth: Bool
    ) throws -> URLRequest {
        var request = try makeRequest(path: path, method: method, requiresAuth: requiresAuth)
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
            throw SupportServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let backendMessage = String(data: data, encoding: .utf8) ?? "Unknown backend error"
            throw SupportServiceError.backendError(
                statusCode: httpResponse.statusCode,
                message: backendMessage
            )
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}

enum SupportServiceError: LocalizedError {
    case invalidURL
    case missingToken
    case invalidResponse
    case backendError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL support invalide."
        case .missingToken:
            return "Session expirée. Veuillez vous reconnecter."
        case .invalidResponse:
            return "Réponse serveur invalide."
        case .backendError(let statusCode, let message):
            return "Erreur serveur \(statusCode): \(message)"
        }
    }
}
