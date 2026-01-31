import SwiftUI

struct ValidationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionManager: SessionManager // Pour sauvegarder plus tard
    
    // On reçoit le texte brut du Scanner
    let scannedText: String
    
    // Notre ViewModel local
    @StateObject private var viewModel: ValidationViewModel
    
    // Nécessaire pour initialiser le ViewModel avec des données externes
    init(scannedText: String) {
        self.scannedText = scannedText
        _viewModel = StateObject(wrappedValue: ValidationViewModel(rawText: scannedText))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Détails du ticket")) {
                    // Champ Marchand
                    HStack {
                        Image(systemName: "building.2")
                            .foregroundColor(.gray)
                        TextField("Nom du magasin", text: $viewModel.merchantName)
                    }
                    
                    // Champ Montant
                    HStack {
                        Image(systemName: "eurosign.circle")
                            .foregroundColor(.gray)
                        TextField("Montant total", text: $viewModel.totalAmount)
                            .keyboardType(.decimalPad)
                    }
                    
                    // Champ Date
                    DatePicker(selection: $viewModel.date, displayedComponents: .date) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.gray)
                            Text("Date d'achat")
                        }
                    }
                }
                
                Section(header: Text("Texte détecté (Debug)")) {
                    Text(viewModel.rawText)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(5)
                }
                
                Section {
                    Button(action: {
                        saveReceipt()
                    }) {
                        Text("Confirmer et Enregistrer")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Vérification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    func saveReceipt() {
        let newReceipt = viewModel.createReceipt()
        print("Ticket sauvegardé : \(newReceipt)")
        // ICI : Plus tard, on ajoutera ce ticket au SessionManager ou on l'enverra au serveur
        
        // On ferme tout pour revenir au Dashboard
        // Astuce : En SwiftUI pur, revenir à la racine demande un peu de gestion d'état,
        // pour l'instant on ferme juste cette vue.
        dismiss()
    }
}

#Preview {
    ValidationView(scannedText: "METRO FRANCE\nTOTAL : 145,50 EUR\nMERCI")
        .environmentObject(SessionManager())
}
