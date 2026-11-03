import Foundation

// MARK: - Body of POST /api/v1/tickets/manual

struct ManualTicketRequestBody: Encodable {
    let merchantName: String
    let totalAmount: Double
    let purchaseDate: String
    let category: String?
    let paymentMethod: String?
    let note: String?
}

// MARK: - Answer of POST /api/v1/tickets/manual

struct ManualTicketResult: Decodable {
    let id: String
    let merchantName: String?
    let totalAmount: Double?
    let purchaseDate: String?
    let category: String?
    let paymentMethod: String?
    let note: String?
}
