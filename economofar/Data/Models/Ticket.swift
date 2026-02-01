import Foundation

struct Ticket: Identifiable, Codable {
    let id: UUID
    let merchantName: String?
    let totalAmount: Double?
    let purchaseDate: String? // The backend sends a date string
    let category: String?
    let imageUrl: String?
    let rawOcrText: String?
    
    // Helper to convert the backend date string to a usable Date object
    var date: Date {
        let formatter = ISO8601DateFormatter()
        // Adjust options if your backend sends fractional seconds
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: purchaseDate ?? "") ?? Date()
    }
}
