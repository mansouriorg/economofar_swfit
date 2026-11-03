import Foundation

/// The events of the person. Every change is a POST and the answer is not read: the screens fetch the
/// event again afterwards, so what they show is always what the server holds.
final class SpendingEventsService {
    static let shared = SpendingEventsService()

    private init() {}

    private let path = "/api/events"

    func fetchOverview(token: String) async throws -> SpendingEventsOverview {
        try await APIClient.shared.get(path, token: token, as: SpendingEventsOverview.self)
    }

    func fetchDetail(token: String, id: Int) async throws -> SpendingEventDetail {
        try await APIClient.shared.get("\(path)/\(id)", token: token, as: SpendingEventDetail.self)
    }

    /// query is the beginning of a shop name, empty for the latest tickets.
    func fetchCandidates(token: String, id: Int, query: String) async throws -> SpendingEventCandidates {
        try await APIClient.shared.get(
            "\(path)/\(id)/candidates",
            query: [URLQueryItem(name: "query", value: query)],
            token: token,
            as: SpendingEventCandidates.self
        )
    }

    func create(token: String, body: SpendingEventBody) async throws {
        _ = try await APIClient.shared.post(path, body: body, token: token)
    }

    func update(token: String, id: Int, body: SpendingEventBody) async throws {
        _ = try await APIClient.shared.post("\(path)/\(id)/update", body: body, token: token)
    }

    /// The tickets of the event stay on the account, they are just free again.
    func delete(token: String, id: Int) async throws {
        _ = try await APIClient.shared.post("\(path)/\(id)/delete", body: SpendingEventNoBody(), token: token)
    }

    /// 50 tickets at most per call.
    func attach(token: String, id: Int, ticketIds: [String]) async throws {
        _ = try await APIClient.shared.post(
            "\(path)/\(id)/tickets",
            body: SpendingEventTicketsBody(ticketIds: ticketIds),
            token: token
        )
    }

    func detach(token: String, id: Int, ticketId: String) async throws {
        _ = try await APIClient.shared.post(
            "\(path)/\(id)/tickets/remove",
            body: SpendingEventTicketRemoveBody(ticketId: ticketId),
            token: token
        )
    }
}
