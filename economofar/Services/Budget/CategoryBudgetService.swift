import Foundation

/// Loads and saves the monthly limit of each spending category.
final class CategoryBudgetService {
    static let shared = CategoryBudgetService()

    private let path = "/api/budget/categories"

    private init() {}

    func fetchAll(token: String) async throws -> [CategoryBudgetItem] {
        try await APIClient.shared.get(path, token: token, as: [CategoryBudgetItem].self)
    }

    @discardableResult
    func save(category: String, monthlyAmount: Double, token: String) async throws -> CategoryBudgetItem {
        let body: Data

        do {
            body = try JSONEncoder().encode(
                SaveCategoryBudgetBody(category: category, monthlyAmount: monthlyAmount)
            )
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }

        let data = try await APIClient.shared.send(
            method: "PUT",
            path: path,
            query: [],
            body: body,
            token: token
        )

        do {
            return try JSONDecoder().decode(CategoryBudgetItem.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    func delete(id: Int, token: String) async throws {
        try await APIClient.shared.delete("\(path)/\(id)", token: token)
    }
}
