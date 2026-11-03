import Foundation

/// Loads the financial health score.
final class HealthScoreService {
    static let shared = HealthScoreService()

    private init() {}

    func fetch(token: String) async throws -> HealthScoreReport {
        try await APIClient.shared.get("/api/health-score", token: token, as: HealthScoreReport.self)
    }
}
