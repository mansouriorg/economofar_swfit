import Foundation

/// Follows the budgets of the categories against the saved tickets of a month. The budgets are the
/// ones stored for the account: the server reads them, nothing is sent but the month.
final class BudgetTrackingService {
    static let shared = BudgetTrackingService()

    private init() {}

    /// month is "2026-10", or nil for the current month.
    func fetch(token: String, month: String?) async throws -> BudgetTrackingOverview {
        var query: [URLQueryItem] = []

        if let month {
            query.append(URLQueryItem(name: "month", value: month))
        }

        return try await APIClient.shared.get(
            "/api/analytics/budget-tracking",
            query: query,
            token: token,
            as: BudgetTrackingOverview.self
        )
    }
}
