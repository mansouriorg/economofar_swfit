import Foundation

/// Sends a ticket typed by hand to the server.
final class ManualTicketService {
    static let shared = ManualTicketService()

    private init() {}

    /// The ticket is saved as soon as the server answers with a success code,
    /// so an answer that cannot be read is not reported as a failure.
    @discardableResult
    func create(_ body: ManualTicketRequestBody, token: String) async throws -> ManualTicketResult? {
        let data = try await APIClient.shared.post(
            "/api/v1/tickets/manual",
            body: body,
            token: token
        )

        return try? JSONDecoder().decode(ManualTicketResult.self, from: data)
    }
}
