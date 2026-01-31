import Foundation
import Combine // <--- INDISPENSABLE pour ObservableObject et @Published

class DashboardViewModel: ObservableObject {
    // Liste des tickets récents (On simule des données pour le design)
    @Published var recentReceipts: [Receipt] = []
    
    init() {
        fetchRecentReceipts()
    }
    
    func fetchRecentReceipts() {
        // Simulation de données venant du serveur
        let mockData = [
            Receipt(merchantName: "Metro", totalAmount: 145.50, items: []),
            Receipt(merchantName: "Promocash", totalAmount: 89.20, items: []),
            Receipt(merchantName: "Boulangerie Centrale", totalAmount: 12.00, items: [])
        ]
        self.recentReceipts = mockData
    }
}
