import Foundation

/// Loads and edits the savings goals and their contributions.
final class SavingsGoalService {
    static let shared = SavingsGoalService()

    private let path = "/api/savings-goals"

    private init() {}

    func fetchAll(token: String) async throws -> [SavingsGoal] {
        try await APIClient.shared.get(path, token: token, as: [SavingsGoal].self)
    }

    func create(_ body: SavingsGoalBody, token: String) async throws -> SavingsGoal {
        let data = try await APIClient.shared.post(path, body: body, token: token)
        return try decodeGoal(data)
    }

    func update(id: Int, body: SavingsGoalBody, token: String) async throws -> SavingsGoal {
        let data = try await sendBody(method: "PUT", path: "\(path)/\(id)", body: body, token: token)
        return try decodeGoal(data)
    }

    func delete(id: Int, token: String) async throws {
        try await APIClient.shared.delete("\(path)/\(id)", token: token)
    }

    func addContribution(goalId: Int, body: SavingsContributionBody, token: String) async throws -> SavingsGoal {
        let data = try await APIClient.shared.post("\(path)/\(goalId)/contributions", body: body, token: token)
        return try decodeGoal(data)
    }

    func deleteContribution(goalId: Int, contributionId: Int, token: String) async throws -> SavingsGoal {
        let data = try await APIClient.shared.send(
            method: "DELETE",
            path: "\(path)/\(goalId)/contributions/\(contributionId)",
            query: [],
            body: nil,
            token: token
        )

        return try decodeGoal(data)
    }

    private func sendBody<B: Encodable>(method: String, path: String, body: B, token: String) async throws -> Data {
        let encoded: Data

        do {
            encoded = try JSONEncoder().encode(body)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }

        return try await APIClient.shared.send(
            method: method,
            path: path,
            query: [],
            body: encoded,
            token: token
        )
    }

    private func decodeGoal(_ data: Data) throws -> SavingsGoal {
        do {
            return try JSONDecoder().decode(SavingsGoal.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }
}
