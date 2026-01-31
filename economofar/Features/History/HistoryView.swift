import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.filteredReceipts) { receipt in
                    // On réutilise votre lien vers le détail !
                    NavigationLink(destination: ReceiptDetailView(receipt: receipt)) {
                        HStack {
                            // Icône
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "cart.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            // Infos principales
                            VStack(alignment: .leading, spacing: 4) {
                                Text(receipt.merchantName ?? "Inconnu")
                                    .fontWeight(.medium)
                                Text(receipt.date.formatted(date: .numeric, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            // Montant
                            Text(String(format: "%.2f €", receipt.totalAmount ?? 0))
                                .fontWeight(.bold)
                                .foregroundColor(Color.primary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(PlainListStyle()) // Style plus épuré
            .navigationTitle("Historique")
            .searchable(text: $viewModel.searchText, prompt: "Rechercher (ex: Metro, 145...)")
            .overlay(
                Group {
                    if viewModel.filteredReceipts.isEmpty {
                        ContentUnavailableView(
                            "Aucun ticket trouvé",
                            systemImage: "magnifyingglass",
                            description: Text("Essayez une autre recherche.")
                        )
                    }
                }
            )
        }
    }
}

#Preview {
    HistoryView()
}
