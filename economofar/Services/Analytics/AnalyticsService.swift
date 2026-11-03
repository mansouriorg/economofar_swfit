import Foundation

/// Loads the spending analytics computed by the backend.
final class AnalyticsService {
    static let shared = AnalyticsService()

    private init() {}

    func fetchSummary(months: Int, token: String) async throws -> AnalyticsSummary {
        try await APIClient.shared.get(
            Endpoint.analyticsSummary,
            query: [URLQueryItem(name: "months", value: String(months))],
            token: token,
            as: AnalyticsSummary.self
        )
    }
}
