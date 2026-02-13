import SwiftUI
import PhotosUI

// MARK: - 1. Models
struct ParsedItem: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var qty: Int
    var price: Double
}

// MARK: - 2. Dashboard View
struct DashboardView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var ticketService = TicketService()
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var analysisResult: String = ""
    @State private var showResultSheet = false
    @State private var showScanner = false
    @State private var isPhotosPickerPresented = false
    @State private var isScanReady = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    headerView
                    historyListView
                }
                
                floatingActionButton
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Déconnexion") { sessionManager.logout() }
                        .font(.caption).foregroundColor(.red)
                }
            }
            .photosPicker(isPresented: $isPhotosPickerPresented, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { newItem in handlePhotoSelection(newItem) }
            .onChange(of: ticketService.lastScanResult) { newResult in
                if let result = newResult {
                    Task { @MainActor in
                        self.analysisResult = result
                        withAnimation(.spring()) { self.isScanReady = true }
                    }
                }
            }
            .sheet(isPresented: $showResultSheet, onDismiss: {
                if ticketService.lastScanResult == nil { isScanReady = false }
            }) {
                if !analysisResult.isEmpty {
                    ResultView(ticketService: ticketService, image: selectedImage, resultText: analysisResult, isPresented: $showResultSheet)
                } else {
                    ProgressView("Chargement...").presentationDetents([.medium])
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                ScannerView(isPresented: $showScanner) { capturedImage in
                    self.selectedImage = capturedImage
                    self.showScanner = false
                    if let token = sessionManager.token {
                        Task { ticketService.uploadTicket(image: capturedImage, token: token) }
                    }
                }
            }
        }
        .onAppear {
            ticketService.onUnauthorized = { sessionManager.logout() }
            if let token = sessionManager.token { ticketService.fetchTickets(token: token) }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Bonjour,").font(.subheadline).foregroundColor(.gray)
                    Text(sessionManager.currentUser?.firstName ?? "Utilisateur").font(.title2).fontWeight(.bold)
                }
                Spacer()
                Circle().fill(Color.blue.opacity(0.1)).frame(width: 40, height: 40)
                    .overlay(Text(String(sessionManager.currentUser?.firstName.prefix(1) ?? "U")).fontWeight(.bold).foregroundColor(.blue))
            }
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Scanné").font(.caption).foregroundColor(.white.opacity(0.8))
                    Text(calculateTotal()).font(.system(size: 30, weight: .bold, design: .rounded)).foregroundColor(.white)
                }
                Spacer()
                Image(systemName: "chart.bar.fill").foregroundColor(.white.opacity(0.8)).font(.title)
            }
            .padding().background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.cyan]), startPoint: .leading, endPoint: .trailing)).cornerRadius(20).shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
        }.padding(.horizontal).padding(.top)
    }
    
    private var historyListView: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Historique récent").font(.headline)
                Spacer()
                if ticketService.isLoading { ProgressView() }
            }.padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 15) {
                    ForEach(ticketService.tickets) { ticket in
                        NavigationLink(destination: TicketDetailView(ticket: ticket)) {
                            TicketRow(ticket: ticket)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    if ticketService.tickets.isEmpty && !ticketService.isLoading {
                        VStack(spacing: 10) {
                            Image(systemName: "doc.text.magnifyingglass").font(.largeTitle).foregroundColor(.gray)
                            Text("Aucun ticket scanné").foregroundColor(.gray)
                        }.padding(.top, 40)
                    }
                }.padding(.horizontal).padding(.bottom, 80)
            }.refreshable {
                if let token = sessionManager.token { ticketService.fetchTickets(token: token) }
            }
        }
    }
    
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            if isScanReady {
                Button(action: { self.showResultSheet = true }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Analyse terminée ! Voir le ticket").fontWeight(.bold)
                    }.padding().background(Color.green).foregroundColor(.white).cornerRadius(30).shadow(radius: 5)
                }.transition(.scale.combined(with: .opacity)).padding(.bottom, 10)
            }
            Menu {
                Button(action: { Task { @MainActor in self.showScanner = true } }) { Label("Appareil Photo", systemImage: "camera") }
                Button(action: { isPhotosPickerPresented = true }) { Label("Galerie Photos", systemImage: "photo.on.rectangle") }
            } label: {
                HStack {
                    if ticketService.isLoading { ProgressView().tint(.white); Text("Analyse...") }
                    else { Image(systemName: "camera.viewfinder"); Text("Scanner") }
                }.foregroundColor(.white).padding(.vertical, 15).padding(.horizontal, 25).background(Color.black).cornerRadius(30)
            }.disabled(ticketService.isLoading).padding(.bottom, 20)
        }
    }
    
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

// MARK: - 3. Ticket Row
struct TicketRow: View {
    let ticket: Ticket
    var dateString: String {
        guard let dateStr = ticket.purchaseDate else { return "Date inconnue" }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: dateStr) { let df = DateFormatter(); df.dateStyle = .short; return df.string(from: d) }
        return dateStr
    }
    var body: some View {
        HStack {
            Image(systemName: "doc.text").foregroundColor(.blue).padding(10).background(Color.blue.opacity(0.1)).cornerRadius(10)
            VStack(alignment: .leading) {
                Text(ticket.merchantName ?? "Magasin Inconnu").fontWeight(.semibold)
                Text(dateString).font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Text(String(format: "%.2f €", ticket.totalAmount ?? 0.0)).fontWeight(.bold)
        }.padding().background(Color.white).cornerRadius(15).shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - 4. Result View
struct ResultView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @ObservedObject var ticketService: TicketService
    var image: UIImage?
    var resultText: String
    @Binding var isPresented: Bool
    
    @State private var merchantName: String = ""
    @State private var totalAmount: Double = 0.0
    @State private var purchaseDate: String = ""
    @State private var parsedItems: [ParsedItem] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let img = image {
                        Image(uiImage: img).resizable().scaledToFit().frame(height: 200).cornerRadius(12).padding(.top)
                    }
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Vérifiez les données").font(.headline)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Enseigne").font(.caption).foregroundColor(.gray)
                            TextField("Nom", text: $merchantName).padding().background(Color.gray.opacity(0.1)).cornerRadius(8)
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Date").font(.caption).foregroundColor(.gray)
                            TextField("YYYY-MM-DD", text: $purchaseDate).padding().background(Color.gray.opacity(0.1)).cornerRadius(8)
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Total").font(.caption).foregroundColor(.gray)
                            TextField("0.00", value: $totalAmount, format: .number).keyboardType(.decimalPad).padding().background(Color.gray.opacity(0.1)).cornerRadius(8)
                        }
                        
                        // ✅ FIXED: Used item instead of $item because this is a standard array iteration
                        if !parsedItems.isEmpty {
                            Divider().padding(.vertical)
                            Text("Articles détectés").font(.headline)
                            ForEach(parsedItems) { item in
                                HStack {
                                    Text(item.name).font(.subheadline)
                                    Spacer()
                                    Text("x\(item.qty)").font(.caption).foregroundColor(.gray)
                                    Text(String(format: "%.2f €", item.price)).fontWeight(.bold)
                                }.padding(8).background(Color.gray.opacity(0.05)).cornerRadius(8)
                            }
                        }
                    }.padding()
                    
                    Button(action: {
                        if let token = sessionManager.token {
                            ticketService.saveValidatedTicket(merchant: merchantName, amount: totalAmount, rawOcr: resultText, token: token)
                            isPresented = false
                        }
                    }) {
                        if ticketService.isLoading { ProgressView().tint(.white) }
                        else { Text("Confirmer").bold().foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.green).cornerRadius(12) }
                    }.disabled(ticketService.isLoading).padding(.horizontal)
                }
            }
            .navigationTitle("Validation")
            .toolbar { Button("Annuler") { isPresented = false } }
            .onAppear { parseRobustJSON() }
        }
    }
    
    func parseRobustJSON() {
        let cleanedText = resultText.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let regex = try? NSRegularExpression(pattern: #""merchant"\s*:\s*"([^"]+)""#, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleanedText, range: NSRange(location: 0, length: cleanedText.count)) {
            self.merchantName = (cleanedText as NSString).substring(with: match.range(at: 1))
        }
        if let regex = try? NSRegularExpression(pattern: #""date"\s*:\s*"([^"]+)""#, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleanedText, range: NSRange(location: 0, length: cleanedText.count)) {
            self.purchaseDate = (cleanedText as NSString).substring(with: match.range(at: 1))
        }
        if let regex = try? NSRegularExpression(pattern: #""total"\s*:\s*([0-9]+(?:\.[0-9]+)?)"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleanedText, range: NSRange(location: 0, length: cleanedText.count)) {
            if let val = Double((cleanedText as NSString).substring(with: match.range(at: 1))) { self.totalAmount = val }
        }
        
        if let data = cleanedText.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let items = json["items"] as? [[String: Any]] {
            self.parsedItems = items.compactMap { dict in
                let name = dict["name"] as? String ?? "Article"
                let qty = dict["qty"] as? Int ?? 1
                var price = 0.0
                if let p = dict["price"] as? Double { price = p } else if let p = dict["price"] as? Int { price = Double(p) }
                return ParsedItem(name: name, qty: qty, price: price)
            }
        }
    }
}

// MARK: - 5. Ticket Detail View
struct TicketDetailView: View {
    let ticket: Ticket
    @State private var parsedItems: [ParsedItem] = []
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "storefront.fill").foregroundColor(.blue)
                        Text(ticket.merchantName ?? "Inconnu").font(.title2).bold()
                    }
                    HStack {
                        Image(systemName: "calendar").foregroundColor(.gray)
                        Text(formatDate(ticket.purchaseDate)).foregroundColor(.secondary)
                    }
                    Divider()
                    HStack {
                        Text("Total Payé").fontWeight(.medium)
                        Spacer()
                        Text(String(format: "%.2f €", ticket.totalAmount ?? 0.0)).font(.title3).bold().foregroundColor(.blue)
                    }
                }.padding(.vertical, 5)
            } header: { Text("Détails") }
            
            if !parsedItems.isEmpty {
                Section(header: Text("Articles")) {
                    ForEach(parsedItems) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            if item.qty > 1 { Text("x\(item.qty)").font(.caption).foregroundColor(.gray) }
                            Text(String(format: "%.2f €", item.price)).fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .navigationTitle("Ticket")
        .onAppear { parseSavedJSON() }
    }
    
    func formatDate(_ dateString: String?) -> String {
        guard let s = dateString, let d = ISO8601DateFormatter().date(from: s) else { return "Date inconnue" }
        let df = DateFormatter(); df.dateStyle = .medium; return df.string(from: d)
    }
    
    func parseSavedJSON() {
        guard let jsonString = ticket.rawOcrText, !jsonString.isEmpty else { return }
        let cleaned = jsonString.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else { return }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let items = json["items"] as? [[String: Any]] {
            self.parsedItems = items.compactMap { dict in
                let name = dict["name"] as? String ?? "Article"
                let qty = dict["qty"] as? Int ?? 1
                var price = 0.0
                if let p = dict["price"] as? Double { price = p } else if let p = dict["price"] as? Int { price = Double(p) }
                return ParsedItem(name: name, qty: qty, price: price)
            }
        }
    }
}
