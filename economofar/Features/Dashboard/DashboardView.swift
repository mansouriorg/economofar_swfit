import SwiftUI
import PhotosUI

struct DashboardView: View {
    @EnvironmentObject var sessionManager: SessionManager
    
    // ✅ Injection du TicketService
    @StateObject private var ticketService = TicketService()
    
    // --- ÉTATS POUR L'UPLOAD ET L'IA ---
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var analysisResult: String = ""
    @State private var showResultSheet = false
    
    // ✅ États pour la navigation et les sélecteurs
    @State private var showScanner = false
    @State private var isPhotosPickerPresented = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Fond de l'application
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
                                Text(sessionManager.currentUser?.firstName ?? "Utilisateur")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            Spacer()
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(sessionManager.currentUser?.firstName.prefix(1) ?? "U"))
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                )
                        }
                        
                        // Carte "Total Scanné"
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Scanné")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                Text(calculateTotal())
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
                    
                    // --- LISTE DES TICKETS (HISTORIQUE) ---
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Historique récent")
                                .font(.headline)
                            Spacer()
                            if ticketService.isLoading {
                                ProgressView()
                            }
                        }
                        .padding(.horizontal)
                        
                        ScrollView {
                            VStack(spacing: 15) {
                                ForEach(ticketService.tickets) { ticket in
                                    TicketRow(ticket: ticket)
                                }
                                
                                if ticketService.tickets.isEmpty && !ticketService.isLoading {
                                    VStack(spacing: 10) {
                                        Image(systemName: "doc.text.magnifyingglass")
                                            .font(.largeTitle)
                                            .foregroundColor(.gray)
                                        Text("Aucun ticket scanné")
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.top, 40)
                                }
                                
                                if let error = ticketService.errorMessage {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding()
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 80)
                        }
                        .refreshable {
                            print("🔄 [Dashboard] Refresh manuel de l'historique")
                            if let token = sessionManager.token {
                                ticketService.fetchTickets(token: token)
                            }
                        }
                    }
                }
                
                // --- BOUTON FLOTTANT (SCANNER) ---
                VStack {
                    Spacer()
                    
                    Menu {
                        Button(action: {
                            print("📸 [Dashboard] Clic: Ouvrir Scanner")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showScanner = true
                            }
                        }) {
                            Label("Appareil Photo", systemImage: "camera")
                        }
                        
                        Button(action: {
                            print("🖼️ [Dashboard] Clic: Ouvrir Galerie")
                            isPhotosPickerPresented = true
                        }) {
                            Label("Galerie Photos", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        HStack {
                            if ticketService.isLoading {
                                ProgressView().tint(.white).padding(.trailing, 5)
                                Text("Analyse Ollama...")
                                    .fontWeight(.bold)
                            } else {
                                Image(systemName: "camera.viewfinder")
                                    .font(.title2)
                                Text("Scanner un ticket")
                                    .fontWeight(.bold)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 15)
                        .padding(.horizontal, 25)
                        .background(Color.black)
                        .cornerRadius(30)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .disabled(ticketService.isLoading)
                    .padding(.bottom, 20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Déconnexion") {
                        print("🚪 [Dashboard] Clic: Déconnexion")
                        sessionManager.logout()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            // ✅ PhotosPicker détaché pour éviter l'erreur de hiérarchie
            .photosPicker(isPresented: $isPhotosPickerPresented, selection: $selectedPhotoItem, matching: .images)
            
            // ✅ Logique de sélection de photo
            .onChange(of: selectedPhotoItem) { newItem in
                print("📂 [Dashboard] Photo sélectionnée dans le picker")
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        if let image = UIImage(data: data) {
                            await MainActor.run {
                                print("🖼️ [Dashboard] Image chargée, lancement de l'analyse...")
                                self.selectedImage = image
                                analyzeReceipt(image: image)
                            }
                        }
                    } else {
                        print("❌ [Dashboard] Échec du chargement des données de l'image")
                    }
                }
            }
            
            // ✅ Réception du résultat Ollama
            .onChange(of: ticketService.lastScanResult) { newResult in
                if let result = newResult {
                    print("✨ [Dashboard] Résultat Ollama reçu, affichage de la Sheet")
                    self.analysisResult = result
                    self.showResultSheet = true
                }
            }
            
            .sheet(isPresented: $showResultSheet) {
                ResultView(image: selectedImage, resultText: analysisResult, isPresented: $showResultSheet)
            }
            
            .fullScreenCover(isPresented: $showScanner) {
                ScannerView(ticketService: ticketService, isPresented: $showScanner)
            }
        }
        .onAppear {
            print("🏠 [Dashboard] Apparition de la vue")
            
            // ✅ CRUCIAL : On lie le service au SessionManager pour gérer les erreurs 403
            ticketService.onUnauthorized = {
                print("🚨 [Dashboard] Signal de déconnexion reçu du service !")
                sessionManager.logout()
            }
            
            if let token = sessionManager.token {
                print("🔑 [Dashboard] Token trouvé: \(token.prefix(10))...")
                ticketService.fetchTickets(token: token)
            } else {
                print("⚠️ [Dashboard] Aucun token trouvé dans sessionManager")
            }
        }
    }
    
    func calculateTotal() -> String {
        let total = ticketService.tickets.compactMap { $0.totalAmount }.reduce(0, +)
        return String(format: "%.2f €", total)
    }
    
    func analyzeReceipt(image: UIImage) {
        guard let token = sessionManager.token else {
            print("❌ [Dashboard] Analyse impossible: Pas de token")
            return
        }
        print("📤 [Dashboard] Envoi de l'image au TicketService...")
        ticketService.uploadTicket(image: image, token: token)
    }
}

// --- VUE D'UNE LIGNE DE TICKET ---
struct TicketRow: View {
    let ticket: Ticket
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
                .padding(10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading) {
                Text(ticket.merchantName ?? "Magasin Inconnu")
                    .fontWeight(.semibold)
                
                Text(ticket.date.formatted(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(String(format: "%.2f €", ticket.totalAmount ?? 0))
                .fontWeight(.bold)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// --- VUE DE RÉSULTAT DU SCAN ---
struct ResultView: View {
    var image: UIImage?
    var resultText: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
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
                        Text("Analyse IA (Ollama) :").font(.headline)
                        Text(resultText)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }.padding()
                }
            }
            .navigationTitle("Résultat du Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { isPresented = false }
                }
            }
        }
    }
}
