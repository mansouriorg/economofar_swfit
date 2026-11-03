import Foundation

final class UserProfileService {

    static let shared = UserProfileService()

    private var baseURL: String { AppConfig.baseURL + "/api" }

    private init() {}

    func fetchProfile() async throws -> UserProfileResponse {
        let request = try makeRequest(
            path: "/profile",
            method: "GET"
        )

        return try await perform(request, responseType: UserProfileResponse.self)
    }

    func updateProfile(_ body: UpdateUserProfileRequest) async throws -> UserProfileResponse {
        let request = try makeRequest(
            path: "/profile",
            method: "PUT",
            body: body
        )

        return try await perform(request, responseType: UserProfileResponse.self)
    }

    func updatePassword(_ body: UpdatePasswordRequest) async throws -> PasswordUpdateResponse {
        let request = try makeRequest(
            path: "/profile/password",
            method: "PUT",
            body: body
        )

        return try await perform(request, responseType: PasswordUpdateResponse.self)
    }

    private func makeRequest(
        path: String,
        method: String
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw UserProfileServiceError.invalidURL
        }

        guard let token = KeychainManager.loadToken(), !token.isEmpty else {
            throw UserProfileServiceError.missingToken
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
            throw UserProfileServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let backendMessage = String(data: data, encoding: .utf8) ?? "Unknown backend error"
            throw UserProfileServiceError.backendError(
                statusCode: httpResponse.statusCode,
                message: backendMessage
            )
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum UserProfileServiceError: LocalizedError {
    case invalidURL
    case missingToken
    case invalidResponse
    case backendError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL profil invalide."
        case .missingToken:
            return "Session expirée. Veuillez vous reconnecter."
        case .invalidResponse:
            return "Réponse serveur invalide."
        case .backendError(let statusCode, let message):
            return "Erreur serveur \(statusCode): \(message)"
        }
    }
}
