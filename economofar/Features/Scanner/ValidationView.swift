import SwiftUI

struct ValidationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionManager: SessionManager
    
    // On reçoit le service depuis le Dashboard pour lancer la sauvegarde
    @ObservedObject var ticketService: TicketService
    
    // Données reçues du Scanner / Ollama
    var image: UIImage?
    var resultText: String
    
    // Champs éditables par l'utilisateur
    @State private var merchantName: String = ""
    @State private var totalAmount: Double = 0.0
    @State private var purchaseDate: Date = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                // SECTION 1 : VISUEL
                Section(header: Text("Ticket Scanné")) {
                    if let img = image {
                        HStack {
                            Spacer()
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                                .cornerRadius(8)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                
                // SECTION 2 : FORMULAIRE
                Section(header: Text("Détails à valider")) {
                    HStack {
                        Image(systemName: "building.2").foregroundColor(.blue)
                        TextField("Enseigne (ex: Carrefour)", text: $merchantName)
                    }
                    
                    HStack {
                        Image(systemName: "eurosign.circle").foregroundColor(.blue)
                        TextField("0.00", value: $totalAmount, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Image(systemName: "calendar").foregroundColor(.blue)
                        DatePicker("Date", selection: $purchaseDate, displayedComponents: .date)
                    }
                }
                
                // SECTION 3 : DEBUG (Pour voir ce qu'Ollama a renvoyé)
                Section(header: Text("Données brutes IA")) {
                    Text(resultText)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                        .onTapGesture {
                            // Copier dans le presse-papier si besoin de debug
                            UIPasteboard.general.string = resultText
                        }
                }
                
                // SECTION 4 : ACTION
                Section {
                    Button(action: saveReceipt) {
                        if ticketService.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Confirmer et Enregistrer")
                                .bold()
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .listRowBackground(Color.green)
                }
            }
            .navigationTitle("Validation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") { dismiss() }
                }
            }
            .onAppear {
                parseRobustJSON()
            }
        }
    }
    
    // MARK: - Logique Métier
    
    func saveReceipt() {
        guard let token = sessionManager.token else { return }
        
        // Appel au backend
        ticketService.saveValidatedTicket(
            merchant: merchantName,
            amount: totalAmount,
            rawOcr: resultText,
            token: token
        )
        
        // On ferme la vue
        dismiss()
    }
    
    // Fonction robuste qui utilise des Regex pour ignorer les erreurs de JSON
    func parseRobustJSON() {
        print("🔍 [ValidationView] Parsing intelligent (Regex)...")
        
        // 1. Extraction du Marchand
        let merchantPattern = "\"merchant\"\\s*:\\s*\"([^\"]+)\""
        if let merchantRegex = try? NSRegularExpression(pattern: merchantPattern, options: []) {
            let nsString = resultText as NSString
            if let match = merchantRegex.firstMatch(in: resultText, options: [], range: NSRange(location: 0, length: nsString.length)) {
                self.merchantName = nsString.substring(with: match.range(at: 1))
            }
        }
        
        // 2. Extraction du Total (Prend le PREMIER trouvé pour éviter les doublons buggés)
        let totalPattern = "\"total\"\\s*:\\s*([0-9.]+)"
        if let totalRegex = try? NSRegularExpression(pattern: totalPattern, options: []) {
            let nsString = resultText as NSString
            if let match = totalRegex.firstMatch(in: resultText, options: [], range: NSRange(location: 0, length: nsString.length)) {
                let totalString = nsString.substring(with: match.range(at: 1))
                if let doubleValue = Double(totalString) {
                    self.totalAmount = doubleValue
                }
            }
        }
        
        // 3. Extraction de la Date (Bonus)
        let datePattern = "\"date\"\\s*:\\s*\"([^\"]+)\""
        if let dateRegex = try? NSRegularExpression(pattern: datePattern, options: []) {
            let nsString = resultText as NSString
            if let match = dateRegex.firstMatch(in: resultText, options: [], range: NSRange(location: 0, length: nsString.length)) {
                let dateString = nsString.substring(with: match.range(at: 1))
                
                // Tentative de conversion de la date string en objet Date
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoFormatter.date(from: dateString) {
                    self.purchaseDate = date
                } else {
                    // Fallback sans millisecondes
                    isoFormatter.formatOptions = [.withInternetDateTime]
                    if let date = isoFormatter.date(from: dateString) {
                        self.purchaseDate = date
                    }
                }
            }
        }
        
        // 4. Fallback standard (Si le JSON est parfait, ce qui est rare avec les IA génératives)
        if self.merchantName.isEmpty, let data = resultText.data(using: .utf8) {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                self.merchantName = json["merchant"] as? String ?? ""
            }
        }
    }
}
