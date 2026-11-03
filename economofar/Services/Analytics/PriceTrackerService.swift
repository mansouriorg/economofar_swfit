import Foundation

/// Loads the price evolution of the items found on the saved tickets.
final class PriceTrackerService {
    static let shared = PriceTrackerService()

    private init() {}

    func fetch(token: String) async throws -> PriceTrackerResponse {
        try await APIClient.shared.get(
            "/api/analytics/prices",
            token: token,
            as: PriceTrackerResponse.self
        )
    }
}
