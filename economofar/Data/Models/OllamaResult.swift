import Foundation

// MARK: - OllamaResult
struct OllamaResult: Codable {
    let merchant: String
    let date: String
    let total: Double
    let items: [OllamaItem]
}

// MARK: - OllamaItem
struct OllamaItem: Codable {
    let name: String
    let qty: Int
    let price: Double
}
