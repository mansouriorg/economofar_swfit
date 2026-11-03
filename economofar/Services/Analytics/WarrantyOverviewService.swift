import Foundation

/// Loads the warranties of the saved tickets.
final class WarrantyOverviewService {
    static let shared = WarrantyOverviewService()

    private init() {}

    /// soonDays is how far ahead a warranty counts as ending soon (30, 60 or 90).
    func fetch(token: String, soonDays: Int) async throws -> WarrantyOverview {
        return try await APIClient.shared.get(
            "/api/analytics/warranties",
            query: [
                URLQueryItem(name: "soonDays", value: String(soonDays))
            ],
            token: token,
            as: WarrantyOverview.self
        )
    }
}
