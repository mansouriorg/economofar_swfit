import Foundation

struct ShoppingListItem: Decodable, Identifiable, Equatable {
    let id: Int
    let name: String
    var quantity: Int
    var checked: Bool
    let unitPrice: Double?
    let lineTotal: Double?
    let lastMerchant: String?
    let cheaperMerchant: String?
    let cheaperPrice: Double?
    let matchedName: String?

    /// True for a line added on screen that the server has not confirmed yet (its number is negative).
    var isPending: Bool {
        id < 0
    }

    /// Price of the line with the quantity shown on screen (it follows the + and - buttons at once).
    var estimatedLine: Double? {
        guard let unitPrice else { return nil }
        return unitPrice * Double(quantity)
    }
}

struct ShoppingSuggestion: Decodable, Identifiable, Equatable {
    let name: String
    let purchaseCount: Int
    let intervalDays: Int
    let daysSinceLast: Int
    let due: Bool
    let lastPrice: Double?
    let lastMerchant: String?

    var id: String {
        name
    }
}

struct ShoppingList: Decodable, Equatable {
    var items: [ShoppingListItem]
    var suggestions: [ShoppingSuggestion]
    let estimatedTotal: Double
    let potentialSavings: Double
    let pricedCount: Int
    let unpricedCount: Int
    let checkedCount: Int
    let totalCount: Int
}

struct ShoppingAddBody: Encodable {
    let name: String
    let quantity: Int
}

struct ShoppingUpdateBody: Encodable {
    let quantity: Int?
    let checked: Bool?
}
