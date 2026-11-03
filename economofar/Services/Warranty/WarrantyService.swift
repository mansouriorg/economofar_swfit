import Foundation

/// Loads and edits the warranties of the saved receipts.
final class WarrantyService {
    static let shared = WarrantyService()

    private let path = "/api/warranties"

    private init() {}

    func fetchAll(token: String) async throws -> [Warranty] {
        try await APIClient.shared.get(path, token: token, as: [Warranty].self)
    }

    func fetchCandidates(token: String) async throws -> [WarrantyCandidate] {
        try await APIClient.shared.get("\(path)/candidates", token: token, as: [WarrantyCandidate].self)
    }

    @discardableResult
    func setWarranty(ticketId: String, months: Int, token: String) async throws -> Warranty {
        let body: Data

        do {
            body = try JSONEncoder().encode(SetWarrantyBody(months: months))
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }

        let data = try await APIClient.shared.send(
            method: "PUT",
            path: "\(path)/\(ticketId)",
            query: [],
            body: body,
            token: token
        )

        do {
            return try JSONDecoder().decode(Warranty.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    func clearWarranty(ticketId: String, token: String) async throws {
        try await APIClient.shared.delete("\(path)/\(ticketId)", token: token)
    }
}
