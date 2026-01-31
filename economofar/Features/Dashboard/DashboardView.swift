import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = DashboardViewModel()
    
    // Pour la navigation vers le Scanner
    @State private var showScanner = false
    
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
                                ForEach(viewModel.recentReceipts) { receipt in
                                    // ✅ MISE À JOUR : Navigation vers le détail
                                    NavigationLink(destination: ReceiptDetailView(receipt: receipt)) {
                                        ReceiptRow(receipt: receipt)
                                            // Important : Force la couleur noire (sinon le lien devient bleu)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 80) // Espace pour le bouton flottant
                        }
                    }
                }
                
                // --- BOUTON FLOTTANT (SCANNER) ---
                VStack {
                    Spacer()
                    Button(action: {
                        showScanner = true
                    }) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                                .font(.title2)
                            Text("Scanner un ticket")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 15)
                        .padding(.horizontal, 25)
                        .background(Color.black) // Noir pour contraster fort
                        .cornerRadius(30)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.bottom, 20)
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
            // Navigation vers le Scanner
            .navigationDestination(isPresented: $showScanner) {
                ScannerView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}

// Une petite vue pour afficher une ligne de ticket (Sub-view)
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

#Preview {
    DashboardView()
        .environmentObject(SessionManager())
}
