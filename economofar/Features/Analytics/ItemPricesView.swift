import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class ItemPricesViewModel: ObservableObject {
    static let periods = [3, 6, 12, 24]

    @Published var overview: ItemPricesOverview? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published var months = 12
    @Published var filter: ItemPriceFilter = .all
    @Published var query = ""

    private var generation = 0
    private var loadedAt: Date? = nil

    func load(token: String?) async {
        guard let token, !token.isEmpty else {
            errorMessage = "Votre session a expiré. Reconnectez-vous."
            isLoading = false
            return
        }

        generation += 1
        let current = generation
        let asked = months

        isLoading = true
        errorMessage = nil

        do {
            let result = try await ItemPricesService.shared.fetch(token: token, months: asked)

            if current == generation {
                overview = result
                loadedAt = Date()
            }
        } catch APIError.unauthorized {
            // The session manager logs the user out
            if current == generation {
                errorMessage = "Votre session a expiré. Reconnectez-vous."
            }
        } catch {
            if current == generation, !Task.isCancelled, (error as? URLError)?.code != .cancelled {
                errorMessage = error.localizedDescription

                // Figures of an earlier day must not be shown as the current ones
                if let loadedAt, !Calendar.current.isDateInToday(loadedAt) {
                    overview = nil
                    self.loadedAt = nil
                }
            }
        }

        if current == generation {
            isLoading = false
        }
    }

    /// The articles that match the filter and the search, in the order that goes with the filter.
    var rows: [ItemPriceLine] {
        guard let overview else {
            return []
        }

        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return filter.apply(overview.items).filter { line in
            text.isEmpty || line.name.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}

// MARK: - Screen

struct ItemPricesView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = ItemPricesViewModel()

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

                    if let overview = viewModel.overview, overview.months == viewModel.months {
                        content(overview)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 50)
                    } else {
                        retryButton
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
        .navigationTitle("Prix de vos articles")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.query, prompt: ItemPricesText.searchPrompt)
        .task {
            await viewModel.load(token: sessionManager.token)
        }
        .onChange(of: viewModel.months) { _ in
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }
    }

    // MARK: Controls

    private var periodPicker: some View {
        Picker("Période", selection: $viewModel.months) {
            ForEach(ItemPricesViewModel.periods, id: \.self) { months in
                Text(ItemPricesText.periodTitle(months)).tag(months)
            }
        }
        .pickerStyle(.segmented)
    }

    private var filterPicker: some View {
        Picker("Filtre", selection: $viewModel.filter) {
            ForEach(ItemPriceFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    private var retryButton: some View {
        Button {
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        } label: {
            Label("Réessayer", systemImage: "arrow.clockwise")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(EconomofarUI.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ overview: ItemPricesOverview) -> some View {
        heroCard(overview)

        if overview.hasItems {
            filterPicker

            rankingCard(overview)
        } else {
            DashboardInfoBanner(
                icon: "questionmark.circle.fill",
                message: overview.hasTickets ? ItemPricesText.emptyHint : ItemPricesText.noTicketsHint + " " + ItemPricesText.emptyHint,
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }

        methodBanner
    }

    // MARK: Hero

    private func heroCard(_ overview: ItemPricesOverview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Prix de vos articles · " + ItemPricesText.periodTitle(overview.months))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                Text(ItemPricesText.headline(overview))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)

                Text(ItemPricesText.summary(overview))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                if overview.basketChangePercent != nil {
                    Text(ItemPricesText.basketNote)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                heroChip(title: "En hausse", value: "\(overview.risingCount)")
                heroChip(title: "En baisse", value: "\(overview.fallingCount)")
                heroChip(
                    title: "Économie possible",
                    value: overview.savingItemCount > 0 ? ItemPricesText.money(overview.potentialSaving) : "-"
                )
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title + " : " + value))
    }

    // MARK: List

    private func tint(_ level: ItemPriceTrend) -> Color {
        switch level {
        case .rising:
            return EconomofarUI.danger
        case .falling:
            return EconomofarUI.success
        case .steady:
            return EconomofarUI.textSecondary
        case .compareOnly:
            return EconomofarUI.accent
        }
    }

    private func rankingCard(_ overview: ItemPricesOverview) -> some View {
        let rows = viewModel.rows

        return VStack(spacing: 8) {
            if rows.isEmpty {
                DashboardInfoBanner(
                    icon: "magnifyingglass",
                    message: ItemPricesText.noMatch,
                    tint: EconomofarUI.accent,
                    background: EconomofarUI.accentSoft
                )
                .padding(.horizontal, -20)
            } else {
                DashboardSectionCard(title: ItemPricesText.listTitle(count: rows.count)) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, line in
                        if index > 0 {
                            DashboardDivider()
                        }

                        NavigationLink {
                            ItemPriceDetailView(line: line, months: overview.months)
                        } label: {
                            lineRow(line)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if overview.hiddenCount > 0 {
                footnote(ItemPricesText.hiddenNote(hidden: overview.hiddenCount, shown: overview.items.count))
            }
        }
    }

    private func lineRow(_ line: ItemPriceLine) -> some View {
        HStack(alignment: .center, spacing: 14) {
            DashboardIconBox(icon: ItemPricesText.icon(line.level), tint: tint(line.level))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(line.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(2)

                Text(ItemPricesText.priceLine(line))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(ItemPricesText.activityLine(line))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if let shop = ItemPricesText.shopLine(line) {
                    Text(shop)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(ItemPricesText.badge(line))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(tint(line.level))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(EconomofarUI.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(16)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(ItemPricesText.rowAccessibility(line)))
        .accessibilityAddTraits(.isButton)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(EconomofarUI.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    // MARK: Method

    private var methodBanner: some View {
        DashboardInfoBanner(
            icon: "info.circle.fill",
            message: ItemPricesText.method,
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }
}
