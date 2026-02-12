import Foundation

struct Ticket: Identifiable, Codable {
    let id: UUID
    let merchantName: String?
    let totalAmount: Double?
    let purchaseDate: String? // Le backend envoie une String (ex: "2023-04-19T15:16:08Z")
    let category: String?
    let imageUrl: String?
    let rawOcrText: String?
    
    // ✅ PROPRIÉTÉ CALCULÉE : Convertit automatiquement la String en Date
    var date: Date {
        guard let dateString = purchaseDate else { return Date() }
        
        let formatter = ISO8601DateFormatter()
        // On accepte les formats avec ou sans millisecondes pour être robuste
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Tentative de fallback sans les millisecondes
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString) ?? Date()
    }
}
