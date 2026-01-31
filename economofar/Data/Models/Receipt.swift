import Foundation

struct Receipt: Identifiable, Codable {
    let id: UUID
    let date: Date
    let merchantName: String?
    let totalAmount: Double?
    let currency: String = "EUR"
    let items: [ReceiptItem]
    let imageUrl: String? // URL locale ou distante de la photo
    
    // Utile pour l'initialisation rapide
    init(id: UUID = UUID(), date: Date = Date(), merchantName: String? = nil, totalAmount: Double? = nil, items: [ReceiptItem] = [], imageUrl: String? = nil) {
        self.id = id
        self.date = date
        self.merchantName = merchantName
        self.totalAmount = totalAmount
        self.items = items
        self.imageUrl = imageUrl
    }
}

struct ReceiptItem: Identifiable, Codable {
    let id: UUID
    let description: String
    let quantity: Int
    let price: Double
}
