import SwiftUI
import PhotosUI

struct DashboardView: View {
    @EnvironmentObject var sessionManager: SessionManager
    
    // ✅ 1. Inject the TicketService
    @StateObject private var ticketService = TicketService()
    
    // --- STATE FOR IMAGE UPLOAD & AI ---
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isAnalyzing = false
    @State private var analysisResult: String = ""
    @State private var showResultSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Light gray background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    
                    // --- HEADER / SUMMARY ---
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
                            // Avatar
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 40, height: 40)
                                .overlay(Text(String(sessionManager.currentUser?.firstName.prefix(1) ?? "U")).fontWeight(.bold).foregroundColor(.blue))
                        }
                        
                        // "Expenses" Card
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Scanné")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                // Dynamic total calculation
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
                    
                    // --- TICKET LIST (Connected to Backend) ---
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
                                // ✅ 2. Display tickets from Service
                                ForEach(ticketService.tickets) { ticket in
                                    TicketRow(ticket: ticket)
                                }
                                
                                if ticketService.tickets.isEmpty && !ticketService.isLoading {
                                    VStack(spacing: 10) {
                                        Image(systemName: "doc.text.magnifyingglass")
                                            .font(.largeTitle)
                                            .foregroundColor(.gray)
                                        Text("Aucun ticket scanné pour le moment")
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.top, 40)
                                }
                                
                                // Display errors if any
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
                            if let token = sessionManager.token {
                                ticketService.fetchTickets(token: token)
                            }
                        }
                    }
                }
                
                // --- FLOATING BUTTON (SCANNER) ---
                VStack {
                    Spacer()
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack {
                            if isAnalyzing {
                                ProgressView().tint(.white).padding(.trailing, 5)
                                Text("Analyse...")
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
                    .disabled(isAnalyzing)
                    .padding(.bottom, 20)
                    .onChange(of: selectedPhotoItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                self.selectedImage = image
                                analyzeReceipt(image: image)
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Déconnexion") {
                        sessionManager.logout()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            .sheet(isPresented: $showResultSheet) {
                ResultView(image: selectedImage, resultText: analysisResult, isPresented: $showResultSheet)
                    .onDisappear {
                        if let token = sessionManager.token {
                            ticketService.fetchTickets(token: token)
                        }
                    }
            }
        }
        // ✅ 3. Auto-load on view appear
        .onAppear {
            if ticketService.tickets.isEmpty {
                if let token = sessionManager.token {
                    ticketService.fetchTickets(token: token)
                }
            }
        }
    }
    
    func calculateTotal() -> String {
        let total = ticketService.tickets.reduce(0) { $0 + ($1.totalAmount ?? 0) }
        return String(format: "%.2f €", total)
    }
    
    // --- SCANNER FUNCTION (Placeholder for now) ---
    func analyzeReceipt(image: UIImage) {
        isAnalyzing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isAnalyzing = false
            self.analysisResult = "Scan terminé ! (Logique d'envoi à faire dans le prochain step)"
            self.showResultSheet = true
        }
    }
}

// ✅ THESE WERE MISSING - PASTE THESE AT THE BOTTOM OF THE FILE

// --- TICKET ROW VIEW ---
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
                    .foregroundColor(.primary)
                
                Text(ticket.date.formatted(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(String(format: "%.2f €", ticket.totalAmount ?? 0))
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// --- RESULT VIEW ---
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
                        Text("Résultat :").font(.headline)
                        Text(resultText)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }.padding()
                }
            }
            .navigationTitle("Analyse")
            .toolbar {
                Button("Fermer") { isPresented = false }
            }
        }
    }
}
