import Foundation

/// Loads the validated tickets of one month, used to fill the spending calendar.
final class SpendingCalendarService {
    static let shared = SpendingCalendarService()

    private init() {}

    /// month: yyyy-MM. The server only returns the tickets that were saved.
    func fetch(month: String, token: String) async throws -> [TicketHistoryReceipt] {
        var filter = TicketHistoryFilter()
        filter.month = month
        filter.sortBy = .oldestFirst

        return try await APIClient.shared.get(
            "/api/v1/tickets/history/search",
            query: filter.queryItems,
            token: token,
            as: [TicketHistoryReceipt].self
        )
    }
}
