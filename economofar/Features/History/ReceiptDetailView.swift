import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt
    
    // Pour fermer la vue si besoin
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // --- EN-TÊTE TICKET ---
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                        .padding(.top, 20)
                    
                    Text(receipt.merchantName ?? "Commerçant Inconnu")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // CORRECTION ICI : .short -> .shortened
                    Text(receipt.date.formatted(date: .long, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
                
                // --- MONTANT TOTAL ---
                VStack {
                    Text("Total Payé")
                        .font(.caption)
                        .textCase(.uppercase)
                        .foregroundColor(.gray)
                    
                    Text(String(format: "%.2f €", receipt.totalAmount ?? 0.0))
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(15)
                
                // --- DÉTAILS / PHOTO ---
                VStack(alignment: .leading, spacing: 15) {
                    Text("Preuve d'achat")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // Zone pour afficher la photo du ticket
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                    .foregroundColor(.gray)
                            )
                        
                        VStack {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                            Text("Voir l'image originale")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // --- ACTIONS ---
                HStack(spacing: 15) {
                    Button(action: {
                        // Action de partage
                    }) {
                        Label("Partager", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        // Action de suppression
                    }) {
                        Label("Supprimer", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(10)
                    }
                }
                .padding()
                
            }
            .padding(.top)
        }
        .navigationTitle("Détail du ticket")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ReceiptDetailView(receipt: Receipt(
        merchantName: "METRO Cash & Carry",
        totalAmount: 145.50,
        items: []
    ))
}
