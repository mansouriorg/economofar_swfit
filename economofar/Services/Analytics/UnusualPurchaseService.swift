import Foundation

/// Loads the purchases that are far above what the user usually spends.
final class UnusualPurchaseService {
    static let shared = UnusualPurchaseService()

    private init() {}

    func fetch(token: String, days: Int) async throws -> UnusualPurchases {
        try await APIClient.shared.get(
            "/api/analytics/unusual",
            query: [URLQueryItem(name: "days", value: String(days))],
            token: token,
            as: UnusualPurchases.self
        )
    }
}
