import Foundation

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case invalidResponse
    case server(status: Int, message: String)
    case decoding(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Adresse du serveur invalide."
        case .unauthorized:
            return "Session expirée. Veuillez vous reconnecter."
        case .invalidResponse:
            return "Réponse du serveur invalide."
        case .server(_, let message):
            return message
        case .decoding(let details):
            return "Erreur de lecture des données : \(details)"
        case .network(let details):
            return "Connexion au serveur impossible : \(details)"
        }
    }
}

extension Notification.Name {
    /// Posted when the server answers 401 (expired / invalid token).
    /// SessionManager listens to it and logs the user out.
    static let economofarUnauthorized = Notification.Name("economofarUnauthorized")
}

// MARK: - Client

/// Small async/await HTTP client used by the newer features.
final class APIClient {
    static let shared = APIClient()

    private init() {}

    func get<T: Decodable>(
        _ path: String,
        query: [URLQueryItem] = [],
        token: String?,
        as type: T.Type = T.self
    ) async throws -> T {
        let data = try await send(method: "GET", path: path, query: query, body: nil, token: token)
        return try decode(data, as: type)
    }

    func post<B: Encodable>(
        _ path: String,
        body: B,
        token: String?
    ) async throws -> Data {
        let encoded: Data

        do {
            encoded = try JSONEncoder().encode(body)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }

        return try await send(method: "POST", path: path, query: [], body: encoded, token: token)
    }

    func delete(_ path: String, token: String?) async throws {
        _ = try await send(method: "DELETE", path: path, query: [], body: nil, token: token)
    }

    @discardableResult
    func send(
        method: String,
        path: String,
        query: [URLQueryItem],
        body: Data?,
        token: String?
    ) async throws -> Data {
        guard var components = URLComponents(string: AppConfig.baseURL + path) else {
            throw APIError.invalidURL
        }

        if !query.isEmpty {
            components.queryItems = query
            components.percentEncodedQuery = components.percentEncodedQuery?
                .replacingOccurrences(of: "+", with: "%2B")
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            await MainActor.run {
                NotificationCenter.default.post(name: .economofarUnauthorized, object: nil)
            }
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(
                status: httpResponse.statusCode,
                message: Self.errorMessage(from: data, status: httpResponse.statusCode)
            )
        }

        return data
    }

    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    /// Reads the "message" field of the backend error JSON.
    static func errorMessage(from data: Data, status: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String,
           !message.isEmpty {
            return message
        }

        switch status {
        case 400: return "Requête invalide."
        case 404: return "Élément introuvable."
        case 409: return "Cette opération est en conflit avec des données existantes."
        case 413: return "Le fichier est trop volumineux."
        case 429: return "Trop de tentatives. Réessayez dans quelques minutes."
        case 500...599: return "Erreur du serveur. Réessayez plus tard."
        default: return "Erreur inattendue (\(status))."
        }
    }
}
