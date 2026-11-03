import Foundation

/// Loads how the spending of each category moved over the last finished months.
final class CategoryTrendsService {
    static let shared = CategoryTrendsService()

    private init() {}

    /// months is the length of the window: 3, 6 or 12.
    func fetch(token: String, months: Int) async throws -> CategoryTrends {
        return try await APIClient.shared.get(
            "/api/analytics/category-trends",
            query: [URLQueryItem(name: "months", value: String(months))],
            token: token,
            as: CategoryTrends.self
        )
    }
}
