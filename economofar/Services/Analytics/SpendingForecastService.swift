import Foundation

/// Loads the estimate of the spending at the end of the month.
final class SpendingForecastService {
    static let shared = SpendingForecastService()

    private init() {}

    func fetch(token: String) async throws -> SpendingForecast {
        try await APIClient.shared.get(
            "/api/analytics/forecast",
            token: token,
            as: SpendingForecast.self
        )
    }
}
