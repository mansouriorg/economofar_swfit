import Foundation

/// Loads the category profiles of the saved tickets.
final class CategoryProfilesService {
    static let shared = CategoryProfilesService()

    private init() {}

    /// months is the length of the period (3, 12 or 24).
    func fetch(token: String, months: Int) async throws -> CategoryProfiles {
        return try await APIClient.shared.get(
            "/api/analytics/category-profiles",
            query: [
                URLQueryItem(name: "months", value: String(months))
            ],
            token: token,
            as: CategoryProfiles.self
        )
    }
}
