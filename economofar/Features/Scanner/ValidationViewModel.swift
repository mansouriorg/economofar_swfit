import Foundation
import Combine

class ValidationViewModel: ObservableObject {
    // Les champs éditables par l'utilisateur
    @Published var merchantName: String = ""
    @Published var totalAmount: String = ""
    @Published var date: Date = Date()
    
    // Le texte brut original (pour référence ou debug)
    let rawText: String
    
    init(rawText: String) {
        self.rawText = rawText
        self.parseRawText()
    }
    
    // Une petite "IA" (Regex) pour deviner les infos sans Gemini pour l'instant
    private func parseRawText() {
        // 1. Essayer de trouver un prix (ex: 12.50 ou 12,50)
        if let price = findMaxPrice(in: rawText) {
            self.totalAmount = String(format: "%.2f", price)
        }
        
        // 2. Essayer de trouver une date (ex: 12/10/2023)
        // (On fera ça plus tard pour ne pas compliquer le code maintenant)
        
        // 3. Deviner le marchand (souvent la première ligne)
        let lines = rawText.components(separatedBy: "\n")
        if let firstLine = lines.first {
            self.merchantName = firstLine
        }
    }
    
    // Fonction utilitaire pour trouver le plus grand chiffre (souvent le Total)
    private func findMaxPrice(in text: String) -> Double? {
        // Regex pour trouver des nombres comme 10.99 ou 10,99
        let pattern = #"\d+[.,]\d{2}"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = text as NSString
        let results = regex?.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        let foundNumbers = results?.compactMap { result -> Double? in
            let match = nsString.substring(with: result.range)
            // Remplacer virgule par point pour la conversion
            let cleanMatch = match.replacingOccurrences(of: ",", with: ".")
            return Double(cleanMatch)
        }
        
        // On suppose que le chiffre le plus élevé est le TOTAL
        return foundNumbers?.max()
    }
    
    // Créer l'objet final Receipt
    func createReceipt() -> Receipt {
        return Receipt(
            merchantName: merchantName,
            totalAmount: Double(totalAmount.replacingOccurrences(of: ",", with: ".")) ?? 0.0,
            items: [], // On gérera les articles plus tard avec Gemini
            imageUrl: nil
        )
    }
}
