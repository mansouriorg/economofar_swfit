import Foundation

/// Loads the business expenses of a period.
final class BusinessExpensesService {
    static let shared = BusinessExpensesService()

    private init() {}

    /// period is "month", "quarter", "year" or "previous-year".
    func fetch(token: String, period: String) async throws -> BusinessExpenses {
        return try await APIClient.shared.get(
            "/api/analytics/business-expenses",
            query: [
                URLQueryItem(name: "period", value: period)
            ],
            token: token,
            as: BusinessExpenses.self
        )
    }
}
