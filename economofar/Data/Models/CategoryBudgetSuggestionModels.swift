import Foundation

// MARK: - API response of GET /api/budget/categories/suggestions

struct CategoryBudgetSuggestion: Decodable, Identifiable, Equatable {
    let category: String
    let averageSpent: Double
    let suggestedAmount: Double
    let monthsUsed: Int

    var id: String {
        category.lowercased()
    }
}

struct CategoryBudgetSuggestions: Decodable, Equatable {
    let basedOnMonths: Int
    let suggestions: [CategoryBudgetSuggestion]
}
