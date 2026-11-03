import Foundation

/// Loads the subscriptions and regular purchases detected by the backend.
final class RecurringExpenseService {
    static let shared = RecurringExpenseService()

    private init() {}

    func fetch(token: String) async throws -> RecurringExpensesResponse {
        try await APIClient.shared.get(
            "/api/analytics/recurring",
            token: token,
            as: RecurringExpensesResponse.self
        )
    }
}
