import Foundation

/// Loads what the small purchases of the last finished months came to.
final class SmallPurchasesService {
    static let shared = SmallPurchasesService()

    private init() {}

    /// months is the length of the window (3, 6 or 12), threshold the biggest amount of a small purchase in euros.
    func fetch(token: String, months: Int, threshold: Int) async throws -> SmallPurchases {
        return try await APIClient.shared.get(
            "/api/analytics/small-purchases",
            query: [
                URLQueryItem(name: "months", value: String(months)),
                URLQueryItem(name: "threshold", value: String(threshold))
            ],
            token: token,
            as: SmallPurchases.self
        )
    }
}
