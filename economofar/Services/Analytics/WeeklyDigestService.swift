import Foundation

/// Loads the summary of the last 7 days.
final class WeeklyDigestService {
    static let shared = WeeklyDigestService()

    private init() {}

    func fetch(token: String) async throws -> WeeklyDigest {
        try await APIClient.shared.get(
            "/api/analytics/weekly-digest",
            token: token,
            as: WeeklyDigest.self
        )
    }
}
