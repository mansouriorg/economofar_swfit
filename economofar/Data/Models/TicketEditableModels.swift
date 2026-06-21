import Foundation

// MARK: - Editable Item Request

struct EditableTicketItemRequest: Codable, Hashable {
    var name: String
    var quantity: Int
    var unitPrice: Double?
    var totalPrice: Double?
    var category: String?

    enum CodingKeys: String, CodingKey {
        case name
        case quantity
        case unitPrice
        case totalPrice
        case category
    }
}

// MARK: - Editable Full Ticket Request

struct EditableTicketRequest: Codable {
    var merchantName: String?
    var purchaseDate: String?
    var totalAmount: Double?
    var category: String?
    var rawOcrText: String?
    var items: [EditableTicketItemRequest]?
}

// MARK: - Editable Item Response

struct EditableTicketItemResponse: Codable, Identifiable, Hashable {
    let id: UUID?
    let name: String?
    let quantity: Int?
    let unitPrice: Double?
    let totalPrice: Double?
    let category: String?

    var safeId: String {
        id?.uuidString ?? UUID().uuidString
    }

    var displayName: String {
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Article"
        }

        return name
    }

    var displayQuantity: Int {
        quantity ?? 1
    }

    var displayTotalPrice: Double {
        totalPrice ?? unitPrice ?? 0.0
    }
}

// MARK: - Editable Ticket Response

struct EditableTicketResponse: Codable {
    let id: UUID?
    let merchantName: String?
    let totalAmount: Double?
    let purchaseDate: String?
    let category: String?
    let imageUrl: String?
    let rawOcrText: String?
    let scanStatus: TicketScanStatus?
    let items: [EditableTicketItemResponse]?

    var ticketIdString: String? {
        id?.uuidString
    }
}

// MARK: - Local Editable Item For UI

struct EditableTicketItemDraft: Identifiable, Hashable {
    let id: UUID
    var backendId: UUID?
    var name: String
    var quantity: Int
    var unitPrice: Double?
    var totalPrice: Double
    var category: String

    init(
        id: UUID = UUID(),
        backendId: UUID? = nil,
        name: String = "",
        quantity: Int = 1,
        unitPrice: Double? = nil,
        totalPrice: Double = 0.0,
        category: String = "Alimentation"
    ) {
        self.id = id
        self.backendId = backendId
        self.name = name
        self.quantity = max(quantity, 1)
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.category = category
    }

    var request: EditableTicketItemRequest {
        EditableTicketItemRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Article" : name,
            quantity: max(quantity, 1),
            unitPrice: unitPrice,
            totalPrice: totalPrice,
            category: category
        )
    }

    static func fromResponse(_ response: EditableTicketItemResponse) -> EditableTicketItemDraft {
        EditableTicketItemDraft(
            backendId: response.id,
            name: response.displayName,
            quantity: response.displayQuantity,
            unitPrice: response.unitPrice,
            totalPrice: response.displayTotalPrice,
            category: response.category ?? "Alimentation"
        )
    }
}
