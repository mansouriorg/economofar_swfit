import SwiftUI
import PhotosUI

// MARK: - Dashboard View
struct DashboardView: View {
    @EnvironmentObject var sessionManager: SessionManager
    
    // ✅ Injection du TicketService
    @StateObject private var ticketService = TicketService()
    
    // --- ÉTATS ---
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var analysisResult: String = ""
    @State private var showResultSheet = false
    @State private var showScanner = false
    @State private var isPhotosPickerPresented = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                // Content Layer
                VStack(spacing: 20) {
                    headerView          // Extracted Subview 1
                    historyListView     // Extracted Subview 2
                }
                
                // Floating Button Layer
                floatingActionButton    // Extracted Subview 3
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Déconnexion") { sessionManager.logout() }
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            // Photos Picker Handler
            .photosPicker(isPresented: $isPhotosPickerPresented, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { newItem in
                handlePhotoSelection(newItem)
            }
            // Analysis Result Handler
            .onChange(of: ticketService.lastScanResult) { newResult in
                print("🟣 DASHBOARD: .onChange(lastScanResult) triggered")
                if let result = newResult {
                    print("🟣 DASHBOARD: Result received! Length: \(result.count) characters")
                    print("🟣 DASHBOARD: Raw Content Preview: \(result.prefix(100))...")
                    self.analysisResult = result
                    self.showResultSheet = true
                } else {
                    print("🔴 DASHBOARD: Result is nil")
                }
            }
            // Sheets & Covers
            .sheet(isPresented: $showResultSheet) {
                ResultView(ticketService: ticketService, image: selectedImage, resultText: analysisResult, isPresented: $showResultSheet)
            }
            // Scanner Handler
            .fullScreenCover(isPresented: $showScanner) {
                ScannerView(isPresented: $showScanner) { capturedImage in
                    print("📸 SCANNER: Image captured")
                    self.selectedImage = capturedImage
                    self.showScanner = false
                    
                    // Trigger upload
                    if let token = sessionManager.token {
                        print("🚀 SCANNER: Starting upload...")
                        ticketService.uploadTicket(image: capturedImage, token: token)
                    }
                }
            }
        }
        .onAppear {
            ticketService.onUnauthorized = { sessionManager.logout() }
            if let token = sessionManager.token { ticketService.fetchTickets(token: token) }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Bonjour,").font(.subheadline).foregroundColor(.gray)
                    Text(sessionManager.currentUser?.firstName ?? "Utilisateur")
                        .font(.title2).fontWeight(.bold)
                }
                Spacer()
                Circle().fill(Color.blue.opacity(0.1)).frame(width: 40, height: 40)
                    .overlay(Text(String(sessionManager.currentUser?.firstName.prefix(1) ?? "U")).fontWeight(.bold).foregroundColor(.blue))
            }
            
            // Carte Total
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Scanné").font(.caption).foregroundColor(.white.opacity(0.8))
                    Text(calculateTotal()).font(.system(size: 30, weight: .bold, design: .rounded)).foregroundColor(.white)
                }
                Spacer()
                Image(systemName: "chart.bar.fill").foregroundColor(.white.opacity(0.8)).font(.title)
            }
            .padding()
            .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.cyan]), startPoint: .leading, endPoint: .trailing))
            .cornerRadius(20)
            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal).padding(.top)
    }
    
    private var historyListView: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Historique récent").font(.headline)
                Spacer()
                if ticketService.isLoading { ProgressView() }
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 15) {
                    ForEach(ticketService.tickets) { ticket in
                        TicketRow(ticket: ticket)
                    }
                    if ticketService.tickets.isEmpty && !ticketService.isLoading {
                        VStack(spacing: 10) {
                            Image(systemName: "doc.text.magnifyingglass").font(.largeTitle).foregroundColor(.gray)
                            Text("Aucun ticket scanné").foregroundColor(.gray)
                        }.padding(.top, 40)
                    }
                    if let error = ticketService.errorMessage {
                        Text(error).font(.caption).foregroundColor(.red).padding()
                    }
                }
                .padding(.horizontal).padding(.bottom, 80)
            }
            .refreshable {
                if let token = sessionManager.token { ticketService.fetchTickets(token: token) }
            }
        }
    }
    
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            Menu {
                Button(action: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showScanner = true }
                }) { Label("Appareil Photo", systemImage: "camera") }
                
                Button(action: { isPhotosPickerPresented = true }) {
                    Label("Galerie Photos", systemImage: "photo.on.rectangle")
                }
            } label: {
                HStack {
                    if ticketService.isLoading {
                        ProgressView().tint(.white).padding(.trailing, 5)
                        Text("Analyse...").fontWeight(.bold)
                    } else {
                        Image(systemName: "camera.viewfinder").font(.title2)
                        Text("Scanner").fontWeight(.bold)
                    }
                }
                .foregroundColor(.white).padding(.vertical, 15).padding(.horizontal, 25)
                .background(Color.black).cornerRadius(30)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .disabled(ticketService.isLoading).padding(.bottom, 20)
        }
    }
    
    // MARK: - Logic Helpers
    
    func calculateTotal() -> String {
        let total = ticketService.tickets.compactMap { $0.totalAmount ?? 0.0 }.reduce(0, +)
        return String(format: "%.2f €", total)
    }
    
    func handlePhotoSelection(_ newItem: PhotosPickerItem?) {
        Task {
            if let data = try? await newItem?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                await MainActor.run {
                    print("🖼️ GALLERY: Image selected")
                    self.selectedImage = image
                    if let token = sessionManager.token {
                        print("🚀 GALLERY: Starting upload...")
                        ticketService.uploadTicket(image: image, token: token)
                    }
                }
            }
        }
    }
}

// MARK: - Ticket Row (Liste)
struct TicketRow: View {
    let ticket: Ticket
    
    var dateString: String {
        guard let dateStr = ticket.purchaseDate else { return "Date inconnue" }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            return displayFormatter.string(from: date)
        }
        
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return dateStr
    }
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.blue).padding(10)
                .background(Color.blue.opacity(0.1)).cornerRadius(10)
            
            VStack(alignment: .leading) {
                Text(ticket.merchantName ?? "Magasin Inconnu").fontWeight(.semibold)
                Text(dateString).font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Text(String(format: "%.2f €", ticket.totalAmount ?? 0.0)).fontWeight(.bold)
        }
        .padding()
        .background(Color.white).cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Result View (Écran de Validation)
struct ResultView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @ObservedObject var ticketService: TicketService
    
    var image: UIImage?
    var resultText: String
    @Binding var isPresented: Bool
    
    // Champs éditables
    @State private var merchantName: String = ""
    @State private var totalAmount: Double = 0.0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .frame(height: 200).cornerRadius(12)
                            .padding(.top)
                    }
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Vérifiez les données").font(.headline)
                        
                        // Champ Nom
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Enseigne").font(.caption).foregroundColor(.gray)
                            TextField("Nom du magasin", text: $merchantName)
                                .padding().background(Color.gray.opacity(0.1)).cornerRadius(8)
                        }
                        
                        // Champ Montant
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Total (€)").font(.caption).foregroundColor(.gray)
                            TextField("0.00", value: $totalAmount, format: .number)
                                .keyboardType(.decimalPad)
                                .padding().background(Color.gray.opacity(0.1)).cornerRadius(8)
                        }
                        
                        Divider().padding(.vertical)
                        
                        // Zone de debug pour voir ce que l'IA a renvoyé
                        Text("Données brutes (Debug)")
                            .font(.caption2).foregroundColor(.gray)
                        Text(resultText).font(.system(size: 8, design: .monospaced))
                            .lineLimit(4).foregroundColor(.gray)
                    }.padding()
                    
                    Button(action: {
                        if let token = sessionManager.token {
                            print("💾 SAVING: Merchant: \(merchantName), Total: \(totalAmount)")
                            ticketService.saveValidatedTicket(
                                merchant: merchantName,
                                amount: totalAmount,
                                rawOcr: resultText,
                                token: token
                            )
                            isPresented = false
                        }
                    }) {
                        if ticketService.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Confirmer et Enregistrer")
                                .bold().foregroundColor(.white).frame(maxWidth: .infinity)
                                .padding().background(Color.green).cornerRadius(12)
                        }
                    }.disabled(ticketService.isLoading).padding(.horizontal)
                }
            }
            .navigationTitle("Validation")
            .toolbar { Button("Annuler") { isPresented = false } }
            // ✅ Trigger parsing on appearance AND when text changes
            .onAppear {
                print("👀 RESULT VIEW: onAppear triggered")
                parseRobustJSON()
            }
            .onChange(of: resultText) { newValue in
                print("🔄 RESULT VIEW: resultText changed. New length: \(newValue.count)")
                parseRobustJSON()
            }
        }
    }
    
    // ✅ IMPROVED PARSING FUNCTION WITH LOGS
    func parseRobustJSON() {
        print("----- 🕵️ STARTING PARSING -----")
        print("📥 Raw Input: \(resultText)")
        
        let cleanedText = cleanJSON(resultText)
        print("🧹 Cleaned Input: \(cleanedText)")
        
        var foundMerchant = false
        var foundTotal = false
        
        // 1. First Attempt: Standard JSON Decoder (if pure JSON)
        print("🔹 Attempting JSON Serialization...")
        if let data = cleanedText.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            print("✅ JSON Serialization SUCCESS. Content: \(json)")
            
            if let merchant = json["merchant"] as? String {
                self.merchantName = merchant
                foundMerchant = true
                print("✅ Merchant found via JSON: \(merchant)")
            }
            if let total = json["total"] as? Double {
                self.totalAmount = total
                foundTotal = true
                print("✅ Total found via JSON: \(total)")
            } else if let totalString = json["total"] as? String, let totalDouble = Double(totalString) {
                self.totalAmount = totalDouble
                foundTotal = true
                print("✅ Total found via JSON (converted from string): \(totalDouble)")
            }
        } else {
            print("⚠️ JSON Serialization FAILED")
        }
        
        // 2. Second Attempt: Robust Regex (if JSON failed or was partial)
        if !foundMerchant || self.merchantName.isEmpty {
            print("🔹 Attempting Merchant Regex...")
            // Case insensitive search for "merchant": "..."
            let merchantPattern = "(?i)\"merchant\"\\s*:\\s*\"([^\"]+)\""
            if let merchantRegex = try? NSRegularExpression(pattern: merchantPattern, options: []) {
                let nsString = cleanedText as NSString
                if let match = merchantRegex.firstMatch(in: cleanedText, options: [], range: NSRange(location: 0, length: nsString.length)) {
                    self.merchantName = nsString.substring(with: match.range(at: 1))
                    print("✅ Merchant found via Regex: \(self.merchantName)")
                } else {
                    print("❌ Merchant Regex found no match")
                }
            }
        }
        
        if !foundTotal || self.totalAmount == 0.0 {
            print("🔹 Attempting Total Regex...")
            // Case insensitive search for "total": 123.45
            let totalPattern = "(?i)\"total\"\\s*:\\s*([0-9.]+)"
            if let totalRegex = try? NSRegularExpression(pattern: totalPattern, options: []) {
                let nsString = cleanedText as NSString
                if let match = totalRegex.firstMatch(in: cleanedText, options: [], range: NSRange(location: 0, length: nsString.length)) {
                    let totalString = nsString.substring(with: match.range(at: 1))
                    if let doubleValue = Double(totalString) {
                        self.totalAmount = doubleValue
                        print("✅ Total found via Regex: \(self.totalAmount)")
                    }
                } else {
                    print("❌ Total Regex found no match")
                }
            }
        }
        
        print("----- 🏁 PARSING FINISHED -----")
        print("Final State -> Merchant: '\(self.merchantName)', Total: \(self.totalAmount)")
    }
    
    // ✅ Helper to remove markdown (```json ... ```)
    func cleanJSON(_ text: String) -> String {
        var clean = text.replacingOccurrences(of: "```json", with: "")
        clean = clean.replacingOccurrences(of: "```", with: "")
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
