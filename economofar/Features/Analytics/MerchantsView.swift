import SwiftUI
import Combine

// MARK: - Sorting

enum MerchantSort: String, CaseIterable, Identifiable {
    case amount
    case visits
    case recent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .amount:
            return "Montant"
        case .visits:
            return "Passages"
        case .recent:
            return "Récents"
        }
    }
}

// MARK: - View model

@MainActor
final class MerchantsViewModel: ObservableObject {
    static let periods = [3, 6, 12, 24]

    @Published var list: MerchantList? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var months = 12
    @Published var sort: MerchantSort = .amount
    @Published var query = ""

    private var generation = 0
    private var loadedAt: Date? = nil

    func load(token: String?) async {
        guard let token, !token.isEmpty else { return }

        generation += 1
        let current = generation

        isLoading = true
        errorMessage = nil

        do {
            let result = try await MerchantInsightsService.shared.list(token: token, months: months)

            if current == generation {
                list = result
                loadedAt = Date()
            }
        } catch APIError.unauthorized {
            // The session manager logs the user out
        } catch {
            if current == generation, !Task.isCancelled, (error as? URLError)?.code != .cancelled {
                errorMessage = error.localizedDescription

                // Figures of an earlier day must not be shown as the current ones
                if let loadedAt, !Calendar.current.isDateInToday(loadedAt) {
                    list = nil
                    self.loadedAt = nil
                }
            }
        }

        if current == generation {
            isLoading = false
        }
    }

    /// The shops that match the search, in the order chosen by the user.
    var rows: [MerchantSummary] {
        guard let list else { return [] }

        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let matching = list.merchants.filter { merchant in
            text.isEmpty || merchant.name.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }

        switch sort {
        case .amount:
            return matching
        case .visits:
            return matching.sorted { first, second in
                if first.tickets != second.tickets {
                    return first.tickets > second.tickets
                }

                return first.total > second.total
            }
        case .recent:
            return matching.sorted { first, second in
                if first.daysSinceLastVisit != second.daysSinceLastVisit {
                    return first.daysSinceLastVisit < second.daysSinceLastVisit
                }

                return first.total > second.total
            }
        }
    }
}

// MARK: - Screen

struct MerchantsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = MerchantsViewModel()

    @State private var showManualEntry = false

    var body: some View {
        ZStack {
            EconomofarUI.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if let errorMessage = viewModel.errorMessage {
                        DashboardInfoBanner(
                            icon: "exclamationmark.triangle.fill",
                            message: errorMessage,
                            tint: EconomofarUI.danger,
                            background: EconomofarUI.dangerSoft
                        )
                        .padding(.horizontal, -20)
                    }

                    periodPicker

                    if let list = viewModel.list, list.months == viewModel.months {
                        content(list)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 50)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .refreshable {
                await viewModel.load(token: sessionManager.token)
            }
        }
        .navigationTitle("Mes commerces")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.query, prompt: "Rechercher un commerce")
        .task {
            await viewModel.load(token: sessionManager.token)
        }
        .onChange(of: viewModel.months) { _ in
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }
        .sheet(isPresented: $showManualEntry) {
            ManualTicketView(onSaved: {
                Task {
                    await viewModel.load(token: sessionManager.token)
                }
            })
            .environmentObject(sessionManager)
        }
    }

    // MARK: Controls

    private var periodPicker: some View {
        Picker("Période", selection: $viewModel.months) {
            ForEach(MerchantsViewModel.periods, id: \.self) { months in
                Text(periodTitle(months)).tag(months)
            }
        }
        .pickerStyle(.segmented)
    }

    private func periodTitle(_ months: Int) -> String {
        switch months {
        case 12:
            return "1 an"
        case 24:
            return "2 ans"
        default:
            return "\(months) mois"
        }
    }

    private var sortPicker: some View {
        Picker("Tri", selection: $viewModel.sort) {
            ForEach(MerchantSort.allCases) { sort in
                Text(sort.title).tag(sort)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ list: MerchantList) -> some View {
        heroCard(list)

        if list.isEmpty {
            emptyCard
        } else {
            sortPicker

            rankingCard(list)
        }
    }

    private func heroCard(_ list: MerchantList) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Où part votre argent")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))

                Text(AppFormat.money(list.total))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("\(WeeklyDigestText.format(list.from, pattern: "MMM yyyy")) - \(WeeklyDigestText.format(list.to, pattern: "MMM yyyy"))")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
            }

            HStack(spacing: 10) {
                heroChip(title: "Commerces", value: "\(list.merchantCount)")
                heroChip(title: "Tickets", value: "\(list.tickets)")

                if let first = list.merchants.first {
                    heroChip(title: "Numéro 1", value: first.name)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func heroChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .opacity(0.85)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Ranking

    private func rankingCard(_ list: MerchantList) -> some View {
        let rows = viewModel.rows

        return VStack(spacing: 12) {
            DashboardSectionCard(title: "Classement") {
                if rows.isEmpty {
                    Text(list.isTruncated
                         ? "Aucun commerce ne correspond à votre recherche parmi les \(list.merchants.count) plus gros."
                         : "Aucun commerce ne correspond à votre recherche.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }

                ForEach(Array(rows.enumerated()), id: \.element.id) { index, merchant in
                    if index > 0 {
                        DashboardDivider()
                    }

                    NavigationLink {
                        MerchantDetailView(name: merchant.name, months: list.months)
                    } label: {
                        merchantRow(merchant)
                    }
                    .buttonStyle(.plain)
                }
            }

            if list.isTruncated {
                Text("Les \(list.merchants.count) plus gros commerces sur \(list.merchantCount).")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
        }
    }

    private func merchantRow(_ merchant: MerchantSummary) -> some View {
        let fraction = min(max(merchant.share / 100, 0), 1)

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(EconomofarUI.accent.opacity(0.11))
                    .frame(width: 46, height: 46)

                Text(String(merchant.name.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(merchant.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(AppFormat.money(merchant.total))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(EconomofarUI.cardSoft)

                        Capsule()
                            .fill(EconomofarUI.accent)
                            .frame(width: max(fraction > 0 ? 6 : 0, proxy.size.width * CGFloat(fraction)))
                    }
                }
                .frame(height: 6)

                Text("\(merchant.subtitle) · \(MerchantText.lastVisit(daysAgo: merchant.daysSinceLastVisit))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .lineLimit(2)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(EconomofarUI.textTertiary)
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    // MARK: Empty

    private var emptyCard: some View {
        VStack(spacing: 14) {
            DashboardInfoBanner(
                icon: "info.circle.fill",
                message: "Aucun achat enregistré sur cette période. Ajoutez vos achats pour voir où va votre argent.",
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)

            Button {
                showManualEntry = true
            } label: {
                Label("Ajouter un achat", systemImage: "square.and.pencil")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
