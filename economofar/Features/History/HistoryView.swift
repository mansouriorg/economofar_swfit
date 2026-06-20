import SwiftUI

// MARK: - History View

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    private var totalAmount: Double {
        viewModel.filteredReceipts
            .compactMap { $0.totalAmount }
            .reduce(0, +)
    }

    private var receiptCount: Int {
        viewModel.filteredReceipts.count
    }

    private var isSearching: Bool {
        !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HistoryDesign.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerSection

                        if viewModel.filteredReceipts.isEmpty {
                            HistoryEmptyState(isSearching: isSearching)
                                .padding(.top, 28)
                        } else {
                            receiptsSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Historique")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $viewModel.searchText,
                prompt: "Rechercher un magasin ou un montant"
            )
        }
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            HistorySummaryCard(
                totalAmount: totalAmount,
                receiptCount: receiptCount
            )

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tickets enregistrés")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(HistoryDesign.textPrimary)

                    Text(subtitleText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(HistoryDesign.textSecondary)
                }

                Spacer()
            }
        }
    }

    private var subtitleText: String {
        if isSearching {
            return "\(receiptCount) résultat\(receiptCount > 1 ? "s" : "") trouvé\(receiptCount > 1 ? "s" : "")"
        } else {
            return "Consultez vos derniers tickets scannés"
        }
    }

    private var receiptsSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.filteredReceipts) { receipt in
                NavigationLink(destination: ReceiptDetailView(receipt: receipt)) {
                    HistoryReceiptRow(receipt: receipt)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Visual Identity

private enum HistoryDesign {
    static let background = color(0xF7F8FA)
    static let card = Color.white
    static let cardSoft = color(0xF1F5FB)

    static let textPrimary = color(0x111827)
    static let textSecondary = color(0x6B7280)
    static let textTertiary = color(0x9CA3AF)

    static let accent = color(0x1F5EFF)
    static let accentDark = color(0x123A8C)
    static let accentSoft = color(0xE8EFFF)

    static let border = color(0xE5E7EB)

    static let mainGradient = LinearGradient(
        colors: [
            accentDark,
            accent
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static func color(_ hex: UInt, alpha: Double = 1.0) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Summary Card

private struct HistorySummaryCard: View {
    let totalAmount: Double
    let receiptCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total historique")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(HistoryDesign.textSecondary)

                    Text(String(format: "%.2f €", totalAmount))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(HistoryDesign.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(HistoryDesign.accentSoft)
                        .frame(width: 52, height: 52)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(HistoryDesign.accent)
                }
            }

            Divider()
                .background(HistoryDesign.border)

            HStack(spacing: 10) {
                Image(systemName: "receipt")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(HistoryDesign.accent)

                Text("\(receiptCount) ticket\(receiptCount > 1 ? "s" : "")")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(HistoryDesign.textSecondary)

                Spacer()

                Text("Historique")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(HistoryDesign.textSecondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(HistoryDesign.cardSoft)
                    .clipShape(Capsule())
            }
        }
        .padding(20)
        .background(HistoryDesign.card)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(HistoryDesign.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.045), radius: 18, x: 0, y: 10)
    }
}

// MARK: - Receipt Row

private struct HistoryReceiptRow: View {
    let receipt: Receipt

    private var merchantName: String {
        let value = receipt.merchantName ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Magasin inconnu" : value
    }

    private var amount: Double {
        receipt.totalAmount ?? 0
    }

    var body: some View {
        HStack(spacing: 14) {
            iconView

            VStack(alignment: .leading, spacing: 6) {
                Text(merchantName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(HistoryDesign.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .semibold))

                    Text(receipt.date.formatted(date: .numeric, time: .omitted))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(HistoryDesign.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(String(format: "%.2f €", amount))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(HistoryDesign.textPrimary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(HistoryDesign.textTertiary)
            }
        }
        .padding(16)
        .background(HistoryDesign.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(HistoryDesign.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(HistoryDesign.accentSoft)
                .frame(width: 50, height: 50)

            Image(systemName: "cart")
                .font(.system(size: 21, weight: .semibold))
                .foregroundColor(HistoryDesign.accent)
        }
    }
}

// MARK: - Empty State

private struct HistoryEmptyState: View {
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(HistoryDesign.accentSoft)
                    .frame(width: 86, height: 86)

                Image(systemName: isSearching ? "magnifyingglass" : "receipt")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(HistoryDesign.accent)
            }

            VStack(spacing: 8) {
                Text(isSearching ? "Aucun ticket trouvé" : "Aucun historique")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(HistoryDesign.textPrimary)

                Text(isSearching ? "Essayez avec un autre magasin, une date ou un montant." : "Vos tickets scannés apparaîtront ici automatiquement.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(HistoryDesign.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 22)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
        .background(HistoryDesign.card)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(HistoryDesign.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
}
