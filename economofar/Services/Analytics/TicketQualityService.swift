import Foundation

/// Loads the saved tickets that have a problem: unknown shop, category Autre, possible
/// duplicate, missing amount or date in the future.
final class TicketQualityService {
    static let shared = TicketQualityService()

    private init() {}

    func fetch(token: String, months: Int) async throws -> TicketQuality {
        try await APIClient.shared.get(
            "/api/analytics/quality",
            query: [URLQueryItem(name: "months", value: String(months))],
            token: token,
            as: TicketQuality.self
        )
    }
}
