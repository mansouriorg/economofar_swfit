import Foundation

/// Loads and edits the incomes, and loads the monthly cash-flow.
final class IncomeService {
    static let shared = IncomeService()

    private let path = "/api/incomes"

    private init() {}

    func fetchAll(token: String) async throws -> [IncomeItem] {
        try await APIClient.shared.get(path, token: token, as: [IncomeItem].self)
    }

    func fetchCashFlow(months: Int, token: String) async throws -> CashFlowReport {
        try await APIClient.shared.get(
            "/api/cashflow",
            query: [URLQueryItem(name: "months", value: String(months))],
            token: token,
            as: CashFlowReport.self
        )
    }

    @discardableResult
    func create(_ body: IncomeBody, token: String) async throws -> IncomeItem {
        let data = try await APIClient.shared.post(path, body: body, token: token)
        return try decodeIncome(data)
    }

    @discardableResult
    func update(id: Int, body: IncomeBody, token: String) async throws -> IncomeItem {
        let encoded: Data

        do {
            encoded = try JSONEncoder().encode(body)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }

        let data = try await APIClient.shared.send(
            method: "PUT",
            path: "\(path)/\(id)",
            query: [],
            body: encoded,
            token: token
        )

        return try decodeIncome(data)
    }

    func delete(id: Int, token: String) async throws {
        try await APIClient.shared.delete("\(path)/\(id)", token: token)
    }

    private func decodeIncome(_ data: Data) throws -> IncomeItem {
        do {
            return try JSONDecoder().decode(IncomeItem.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }
}
