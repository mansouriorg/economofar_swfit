import Foundation

final class TicketScanStatusService {

    static let shared = TicketScanStatusService()

    private var baseURL: String { AppConfig.baseURL + "/api/v1/tickets" }

    private init() {}

    func fetchScanStatus(
        ticketId: String,
        token: String
    ) async throws -> TicketScanStatusResponse {
        let request = try makeRequest(
            path: "/\(ticketId)/scan-status",
            method: "GET",
            token: token
        )

        return try await perform(request, responseType: TicketScanStatusResponse.self)
    }

    func fetchActiveScan(
        token: String
    ) async throws -> TicketScanStatusResponse? {
        let request = try makeRequest(
            path: "/active-scan",
            method: "GET",
            token: token
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TicketScanStatusServiceError.invalidResponse
        }

        if httpResponse.statusCode == 204 {
            return nil
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown backend error"
            throw TicketScanStatusServiceError.backendError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        return try JSONDecoder().decode(TicketScanStatusResponse.self, from: data)
    }

    private func makeRequest(
        path: String,
        method: String,
        token: String
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw TicketScanStatusServiceError.invalidURL
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
            throw TicketScanStatusServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown backend error"
            throw TicketScanStatusServiceError.backendError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let rawResponse = String(data: data, encoding: .utf8) ?? "No response body"
            throw TicketScanStatusServiceError.decodingFailed(
                "\(error.localizedDescription)\n\nBackend response:\n\(rawResponse)"
            )
        }
    }
}

enum TicketScanStatusServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case backendError(statusCode: Int, message: String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL scan status invalide."
        case .invalidResponse:
            return "Réponse serveur invalide."
        case .backendError(let statusCode, let message):
            return "Erreur serveur \(statusCode): \(message)"
        case .decodingFailed(let message):
            return "Erreur de lecture du statut: \(message)"
        }
    }
}
