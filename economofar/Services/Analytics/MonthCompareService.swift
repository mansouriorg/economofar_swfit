import Foundation

/// Loads a month compared with the month before it: total, tickets, change per category and the
/// two cumulative curves.
final class MonthCompareService {
    static let shared = MonthCompareService()

    private init() {}

    /// month is "2026-10"; nil asks for the month in progress.
    func fetch(token: String, month: String?) async throws -> MonthCompare {
        var query: [URLQueryItem] = []

        if let month {
            query.append(URLQueryItem(name: "month", value: month))
        }

        return try await APIClient.shared.get(
            "/api/analytics/compare",
            query: query,
            token: token,
            as: MonthCompare.self
        )
    }
}
