import SwiftUI
import PhotosUI

// MARK: - Local Model for Scanned Items
struct ParsedItem: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var qty: Int
    var price: Double
}

// MARK: - Dashboard View
struct DashboardView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var ticketService = TicketService()
    
    // --- STATES ---
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    
    // Data holding
    @State private var analysisResult: String = ""
    
    // UI Flags
    @State private var showResultSheet = false
    @State private var showScanner = false
    @State private var isPhotosPickerPresented = false
    
    // ✅ NEW STATE: Tracks if a scan is finished and waiting for the user
    @State private var isScanReady = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                // Content Layer
                VStack(spacing: 20) {
                    headerView
                    historyListView
                }
                
                // Floating Button Layer
                floatingActionButton
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Déconnexion") { sessionManager.logout() }
                        .font(.caption).foregroundColor(.red)
                }
            }
            // Photos Picker Handler
            .photosPicker(isPresented: $isPhotosPickerPresented, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { newItem in
                handlePhotoSelection(newItem)
            }
            // ✅ UPDATED LOGIC: Don't open sheet automatically. Just notify.
            .onChange(of: ticketService.lastScanResult) { newResult in
                if let result = newResult {
                    Task { @MainActor in
                        print("🟣 DASHBOARD: Scan finished. Waiting for user action.")
                        self.analysisResult = result
                        
                        // We animate the appearance of the "Ready" button
                        withAnimation(.spring()) {
                            self.isScanReady = true
                        }
                    }
                }
            }
            // Sheet Gatekeeper
            .sheet(isPresented: $showResultSheet, onDismiss: {
                // Reset the ready state when sheet closes
                if ticketService.lastScanResult == nil {
                    isScanReady = false
                }
            }) {
                if !analysisResult.isEmpty {
                    ResultView(
                        ticketService: ticketService,
                        image: selectedImage,
                        resultText: analysisResult,
                        isPresented: $showResultSheet
                    )
                } else {
                    ProgressView("Chargement des données...")
                        .presentationDetents([.medium])
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                ScannerView(isPresented: $showScanner) { capturedImage in
                    print("📸 SCANNER: Image captured")
                    self.selectedImage = capturedImage
                    self.showScanner = false
                    
                    if let token = sessionManager.token {
                        // Background upload
                        Task {
                            ticketService.uploadTicket(image: capturedImage, token: token)
                        }
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
    
    // ✅ UPDATED FLOATING BUTTON SECTION
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            // 🟢 1. The "Scan Ready" Notification Button
            if isScanReady {
                Button(action: {
                    self.showResultSheet = true
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Analyse terminée ! Voir le ticket")
                            .fontWeight(.bold)
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(30)
                    .shadow(radius: 5)
                }
                .transition(.scale.combined(with: .opacity)) // Animation pop-in
                .padding(.bottom, 10)
            }
            
            // ⚫️ 2. The Main Action Button
            Menu {
                Button(action: {
                    Task { @MainActor in self.showScanner = true }
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
                    self.selectedImage = image
                    if let token = sessionManager.token { ticketService.uploadTicket(image: image, token: token) }
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
    @State private var purchaseDate: String = ""
    @State private var parsedItems: [ParsedItem] = []
    
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
                        
                        // Champ Date
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Date").font(.caption).foregroundColor(.gray)
                            TextField("Date (YYYY-MM-DD)", text: $purchaseDate)
                                .padding().background(Color.gray.opacity(0.1)).cornerRadius(8)
                        }
                        
                        // Champ Montant
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Total (€)").font(.caption).foregroundColor(.gray)
                            TextField("0.00", value: $totalAmount, format: .number)
                                .keyboardType(.decimalPad)
                                .padding().background(Color.gray.opacity(0.1)).cornerRadius(8)
                        }
                        
                        // Liste des articles
                        if !parsedItems.isEmpty {
                            Divider().padding(.vertical)
                            Text("Articles détectés").font(.headline)
                            
                            ForEach($parsedItems) { $item in
                                HStack {
                                    TextField("Nom", text: $item.name)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("x\(item.qty)").font(.caption).foregroundColor(.gray)
                                    TextField("Prix", value: $item.price, format: .number)
                                        .frame(width: 60)
                                        .multilineTextAlignment(.trailing)
                                        .keyboardType(.decimalPad)
                                }
                                .padding(8)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        
                        Divider().padding(.vertical)
                        
                        // Zone de debug pour voir ce que l'IA a renvoyé
                        DisclosureGroup("Données brutes (Debug)") {
                            Text(resultText).font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }.padding()
                    
                    Button(action: {
                        if let token = sessionManager.token {
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
            .onAppear {
                parseRobustJSON()
            }
        }
    }
    
    // ✅ ROBUST PARSING LOGIC (Updated for Items & Date)
    func parseRobustJSON() {
        print("🔍 STARTING ROBUST PARSING")
        
        let cleanedText = resultText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. EXTRACT MERCHANT
        let merchantPattern = #""merchant"\s*:\s*"([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: merchantPattern, options: .caseInsensitive) {
            let nsString = cleanedText as NSString
            if let match = regex.firstMatch(in: cleanedText, options: [], range: NSRange(location: 0, length: nsString.length)) {
                self.merchantName = nsString.substring(with: match.range(at: 1))
            }
        }
        
        // 2. EXTRACT DATE
        let datePattern = #""date"\s*:\s*"([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: datePattern, options: .caseInsensitive) {
            let nsString = cleanedText as NSString
            if let match = regex.firstMatch(in: cleanedText, options: [], range: NSRange(location: 0, length: nsString.length)) {
                self.purchaseDate = nsString.substring(with: match.range(at: 1))
            }
        }
        
        // 3. EXTRACT TOTAL (First number found)
        let totalPattern = #""total"\s*:\s*([0-9]+(?:\.[0-9]+)?)"#
        if let regex = try? NSRegularExpression(pattern: totalPattern, options: .caseInsensitive) {
            let nsString = cleanedText as NSString
            if let match = regex.firstMatch(in: cleanedText, options: [], range: NSRange(location: 0, length: nsString.length)) {
                let totalString = nsString.substring(with: match.range(at: 1))
                if let val = Double(totalString) {
                    self.totalAmount = val
                }
            }
        }
        
        // 4. EXTRACT ITEMS (Fallback to JSON Decoder for complex arrays)
        if let data = cleanedText.data(using: .utf8) {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = json["items"] as? [[String: Any]] {
                
                self.parsedItems = items.compactMap { dict in
                    let name = dict["name"] as? String ?? "Article Inconnu"
                    let qty = dict["qty"] as? Int ?? 1
                    // Handle price which might be Int or Double in JSON
                    var price = 0.0
                    if let pDouble = dict["price"] as? Double { price = pDouble }
                    else if let pInt = dict["price"] as? Int { price = Double(pInt) }
                    
                    return ParsedItem(name: name, qty: qty, price: price)
                }
            }
        }
        
        // 5. Fallback if JSON Decoder failed entirely for top-level fields
        if self.merchantName.isEmpty && self.totalAmount == 0 {
            if let data = cleanedText.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                self.merchantName = json["merchant"] as? String ?? ""
                if let t = json["total"] as? Double { self.totalAmount = t }
            }
        }
    }
}
