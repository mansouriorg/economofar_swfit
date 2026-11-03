import Foundation

/// Loads the category limits that the backend proposes from the past months.
final class CategoryBudgetSuggestionService {
    static let shared = CategoryBudgetSuggestionService()

    private init() {}

    func fetch(token: String) async throws -> CategoryBudgetSuggestions {
        try await APIClient.shared.get(
            "/api/budget/categories/suggestions",
            token: token,
            as: CategoryBudgetSuggestions.self
        )
    }
}
