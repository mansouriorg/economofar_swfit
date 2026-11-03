import Foundation

final class TicketEditableService {

    static let shared = TicketEditableService()

    private var baseURL: String { AppConfig.baseURL + "/api/v1/tickets" }

    private init() {}

    // MARK: - Get Editable Ticket

    func getEditableTicket(
        ticketId: String,
        token: String
    ) async throws -> EditableTicketResponse {
        let request = try makeRequest(
            path: "/\(ticketId)/editable",
            method: "GET",
            token: token
        )

        return try await perform(
            request,
            responseType: EditableTicketResponse.self
        )
    }

    // MARK: - Update Full Editable Ticket

    func updateEditableTicket(
        ticketId: String,
        payload: EditableTicketRequest,
        token: String
    ) async throws -> EditableTicketResponse {
        var request = try makeRequest(
            path: "/\(ticketId)/editable",
            method: "PUT",
            token: token
        )

        request.httpBody = try JSONEncoder().encode(payload)

        return try await perform(
            request,
            responseType: EditableTicketResponse.self
        )
    }

    // MARK: - Add Missing Item

    func addItem(
        ticketId: String,
        item: EditableTicketItemRequest,
        token: String
    ) async throws -> EditableTicketItemResponse {
        var request = try makeRequest(
            path: "/\(ticketId)/items",
            method: "POST",
            token: token
        )

        request.httpBody = try JSONEncoder().encode(item)

        return try await perform(
            request,
            responseType: EditableTicketItemResponse.self
        )
    }

    // MARK: - Update Item

    func updateItem(
        ticketId: String,
        itemId: String,
        item: EditableTicketItemRequest,
        token: String
    ) async throws -> EditableTicketItemResponse {
        var request = try makeRequest(
            path: "/\(ticketId)/items/\(itemId)",
            method: "PUT",
            token: token
        )

        request.httpBody = try JSONEncoder().encode(item)

        return try await perform(
            request,
            responseType: EditableTicketItemResponse.self
        )
    }

    // MARK: - Delete Item

    func deleteItem(
        ticketId: String,
        itemId: String,
        token: String
    ) async throws {
        let request = try makeRequest(
            path: "/\(ticketId)/items/\(itemId)",
            method: "DELETE",
            token: token
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TicketEditableServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown backend error"
            throw TicketEditableServiceError.backendError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }
    }

    // MARK: - Change Category

    func changeCategory(
        ticketId: String,
        category: String,
        token: String
    ) async throws -> EditableTicketResponse {
        var request = try makeRequest(
            path: "/\(ticketId)/category",
            method: "PATCH",
            token: token
        )

        let body = ["category": category]
        request.httpBody = try JSONEncoder().encode(body)

        return try await perform(
            request,
            responseType: EditableTicketResponse.self
        )
    }

    // MARK: - Helpers

    private func makeRequest(
        path: String,
        method: String,
        token: String
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw TicketEditableServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return request
    }

    private func perform<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TicketEditableServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown backend error"

            throw TicketEditableServiceError.backendError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let rawResponse = String(data: data, encoding: .utf8) ?? "No response body"

            throw TicketEditableServiceError.decodingFailed(
                """
                \(error.localizedDescription)

                Backend response:
                \(rawResponse)
                """
            )
        }
    }
}

// MARK: - Error

enum TicketEditableServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case backendError(statusCode: Int, message: String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL édition ticket invalide."

        case .invalidResponse:
            return "Réponse serveur invalide."

        case .backendError(let statusCode, let message):
            return "Erreur serveur \(statusCode): \(message)"

        case .decodingFailed(let message):
            return "Erreur de lecture des données éditables: \(message)"
        }
    }
}
