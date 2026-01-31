import Foundation
import Combine

class HistoryViewModel: ObservableObject {
    @Published var allReceipts: [Receipt] = []
    @Published var searchText: String = ""
    
    // Cette propriété calcule dynamiquement la liste filtrée
    var filteredReceipts: [Receipt] {
        if searchText.isEmpty {
            return allReceipts.sorted(by: { $0.date > $1.date }) // Du plus récent au plus vieux
        } else {
            return allReceipts.filter { receipt in
                let merchant = receipt.merchantName?.lowercased() ?? ""
                let amount = String(receipt.totalAmount ?? 0.0)
                return merchant.contains(searchText.lowercased()) || amount.contains(searchText)
            }.sorted(by: { $0.date > $1.date })
        }
    }
    
    init() {
        loadData()
    }
    
    func loadData() {
        // Simulation de beaucoup de données pour tester le scroll et la recherche
        self.allReceipts = [
            Receipt(merchantName: "Metro", totalAmount: 145.50, items: []),
            Receipt(merchantName: "Promocash", totalAmount: 89.20, items: []),
            Receipt(merchantName: "Boulangerie Centrale", totalAmount: 12.00, items: []),
            Receipt(merchantName: "Boucherie du Coin", totalAmount: 254.00, items: []),
            Receipt(merchantName: "IKEA Business", totalAmount: 65.99, items: []),
            Receipt(merchantName: "Station Service", totalAmount: 80.00, items: []),
            Receipt(merchantName: "Metro", totalAmount: 34.50, items: [])
        ]
    }
}
