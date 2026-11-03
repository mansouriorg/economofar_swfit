import Foundation

// MARK: - API response of GET /api/budget/categories

struct CategoryBudgetItem: Codable, Identifiable, Equatable {
    let id: Int
    let category: String
    let monthlyAmount: Double
    let spent: Double
    let remaining: Double
    let percentUsed: Double
    let exceeded: Bool
}

// MARK: - Body of PUT /api/budget/categories

struct SaveCategoryBudgetBody: Encodable {
    let category: String
    let monthlyAmount: Double
}
