import Foundation

/// Talks to /api/shopping-list. Every call answers with the whole list.
final class ShoppingListService {
    static let shared = ShoppingListService()

    private let path = "/api/shopping-list"

    private init() {}

    func fetch(token: String) async throws -> ShoppingList {
        try await APIClient.shared.get(path, token: token, as: ShoppingList.self)
    }

    func add(name: String, quantity: Int, token: String) async throws -> ShoppingList {
        let data = try await APIClient.shared.post(
            path,
            body: ShoppingAddBody(name: name, quantity: quantity),
            token: token
        )

        return try decode(data)
    }

    func update(id: Int, quantity: Int?, checked: Bool?, token: String) async throws -> ShoppingList {
        let body: Data

        do {
            body = try JSONEncoder().encode(ShoppingUpdateBody(quantity: quantity, checked: checked))
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }

        let data = try await APIClient.shared.send(
            method: "PATCH",
            path: "\(path)/\(id)",
            query: [],
            body: body,
            token: token
        )

        return try decode(data)
    }

    func remove(id: Int, token: String) async throws -> ShoppingList {
        let data = try await APIClient.shared.send(
            method: "DELETE",
            path: "\(path)/\(id)",
            query: [],
            body: nil,
            token: token
        )

        return try decode(data)
    }

    func clearChecked(token: String) async throws -> ShoppingList {
        let data = try await APIClient.shared.send(
            method: "DELETE",
            path: "\(path)/checked",
            query: [],
            body: nil,
            token: token
        )

        return try decode(data)
    }

    private func decode(_ data: Data) throws -> ShoppingList {
        do {
            return try JSONDecoder().decode(ShoppingList.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }
}
