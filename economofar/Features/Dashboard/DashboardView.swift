import SwiftUI
import PhotosUI // ✅ NÉCESSAIRE POUR LA GALERIE

struct DashboardView: View {
    @EnvironmentObject var sessionManager: SessionManager
    
    // Si tu n'as pas encore créé ce ViewModel, tu peux le commenter pour l'instant
    // @StateObject private var viewModel = DashboardViewModel()
    
    // Pour l'exemple, j'utilise une liste vide si le viewModel n'existe pas
    // Assure-toi que ton modèle Receipt existe bien dans tes dossiers
    @State var recentReceipts: [Receipt] = []
    
    // --- ÉTATS POUR L'UPLOAD IMAGE & IA ---
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isAnalyzing = false
    @State private var analysisResult: String = ""
    @State private var showResultSheet = false // Pour afficher le résultat
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Couleur de fond gris très clair
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    
                    // --- HEADER / RÉSUMÉ ---
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Bonjour,")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text(sessionManager.currentUser?.firstName ?? "Chef")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            Spacer()
                            // Avatar ou initiales
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 40, height: 40)
                                .overlay(Text("C").fontWeight(.bold).foregroundColor(.blue))
                        }
                        
                        // Carte "Dépenses du mois"
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Dépenses Octobre")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                Text("2 450,00 €")
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.title)
                        }
                        .padding()
                        .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.cyan]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(20)
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // --- LISTE RÉCENTE ---
                    VStack(alignment: .leading) {
                        Text("Tickets récents")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView {
                            VStack(spacing: 15) {
                                // J'utilise la variable locale ou ton viewModel ici
                                ForEach(recentReceipts) { receipt in
                                    ReceiptRow(receipt: receipt)
                                }
                                
                                // Un message vide si pas de tickets
                                if recentReceipts.isEmpty {
                                    Text("Aucun ticket récent")
                                        .foregroundColor(.gray)
                                        .padding(.top, 20)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 80) // Espace pour le bouton flottant
                        }
                    }
                }
                
                // --- BOUTON FLOTTANT (SCANNER / GALERIE) ---
                VStack {
                    Spacer()
                    
                    // ✅ MODIFICATION : Le bouton devient un PhotosPicker
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack {
                            if isAnalyzing {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 5)
                                Text("Analyse en cours...")
                                    .fontWeight(.bold)
                            } else {
                                Image(systemName: "camera.viewfinder")
                                    .font(.title2)
                                Text("Scanner / Galerie")
                                    .fontWeight(.bold)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 15)
                        .padding(.horizontal, 25)
                        .background(Color.black) // Noir pour contraster fort
                        .cornerRadius(30)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .disabled(isAnalyzing) // On empêche de cliquer si ça charge
                    .padding(.bottom, 20)
                    // ✅ ACTION QUAND L'IMAGE EST CHOISIE
                    .onChange(of: selectedPhotoItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                self.selectedImage = image
                                // On lance l'analyse vers Java + Ollama
                                analyzeReceipt(image: image)
                            }
                        }
                    }
                }
            }
            // Bouton de déconnexion dans la barre de navigation
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Déconnexion") {
                        sessionManager.logout()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            // ✅ FENÊTRE DE RÉSULTAT (SHEET)
            .sheet(isPresented: $showResultSheet) {
                ResultView(image: selectedImage, resultText: analysisResult, isPresented: $showResultSheet)
            }
        }
    }
    
    // --- FONCTION DE LIEN AVEC JAVA ---
    func analyzeReceipt(image: UIImage) {
        isAnalyzing = true
        
        Task {
            do {
                // Appel au ImageService (Backend Java)
                let response = try await ImageService.uploadImage(image: image)
                
                // Succès !
                self.analysisResult = response.analysis
                self.showResultSheet = true // On ouvre la fenêtre de résultat
                
            } catch {
                print("Erreur UI: \(error)")
                self.analysisResult = "Erreur : Impossible de joindre le serveur.\n(Vérifie que Java et Ollama tournent !)"
                self.showResultSheet = true
            }
            isAnalyzing = false
        }
    }
}

// --- VUE POUR AFFICHER LE RÉSULTAT (MODALE) ---
struct ResultView: View {
    var image: UIImage?
    var resultText: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 250)
                            .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Résultat de l'IA (Ollama) :")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        Text(resultText)
                            .font(.system(.body, design: .monospaced)) // Police style code
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding()
                }
            }
            .navigationTitle("Analyse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Fermer") {
                    isPresented = false
                }
            }
        }
    }
}

// --- COMPOSANT ROW ---
// Si tu as aussi une erreur "Redeclaration of ReceiptRow", supprime aussi ce bloc ci-dessous.
struct ReceiptRow: View {
    let receipt: Receipt
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
                .padding(10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading) {
                // Assure-toi que ton modèle Receipt a bien ces champs (merchantName, date)
                Text(receipt.merchantName ?? "Inconnu")
                    .fontWeight(.semibold)
                Text(receipt.date.formatted(date: .numeric, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(String(format: "%.2f €", receipt.totalAmount ?? 0))
                .fontWeight(.bold)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
