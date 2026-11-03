import Foundation

/// Loads what can still be spent today.
final class DailyBudgetService {
    static let shared = DailyBudgetService()

    private init() {}

    func fetch(token: String) async throws -> DailyBudget {
        try await APIClient.shared.get(
            "/api/analytics/daily-budget",
            token: token,
            as: DailyBudget.self
        )
    }
}
