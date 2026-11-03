import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class ShopsViewModel: ObservableObject {
    static let periods = [3, 6, 12, 24]

    @Published var overview: ShopsOverview? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published var months = 12
    @Published var filter: ShopFilter = .all
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
            let result = try await ShopsService.shared.fetch(token: token, months: asked)

            if current == generation {
                overview = result
                loadedAt = Date()

                // A filter with nothing left to show must not hide the whole list
                if filter != .all, filter.apply(result.shops).isEmpty {
                    filter = .all
                }
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

    /// The shops that match the filter and the search, in the order that goes with the filter.
    var rows: [ShopLine] {
        guard let overview else {
            return []
        }

        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return filter.apply(overview.shops).filter { line in
            text.isEmpty || line.name.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    /// The filters that have something to show, the first one always.
    var availableFilters: [ShopFilter] {
        guard let overview else {
            return [.all]
        }

        return ShopFilter.allCases.filter { $0 == .all || !$0.apply(overview.shops).isEmpty }
    }

    func count(_ filter: ShopFilter) -> Int {
        guard let overview else {
            return 0
        }

        return filter.apply(overview.shops).count
    }
}

// MARK: - Screen

struct ShopsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = ShopsViewModel()

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
        .navigationTitle("Mes enseignes")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.query, prompt: ShopsText.searchPrompt)
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
            ForEach(ShopsViewModel.periods, id: \.self) { months in
                Text(ShopsText.periodTitle(months)).tag(months)
            }
        }
        .pickerStyle(.segmented)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.availableFilters) { filter in
                    filterChip(filter)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
    }

    private func filterChip(_ filter: ShopFilter) -> some View {
        let selected = viewModel.filter == filter
        let title = filter == .all ? filter.title : filter.title + " · \(viewModel.count(filter))"

        return Button {
            viewModel.filter = filter
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(selected ? Color.white : EconomofarUI.accent)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(selected ? EconomofarUI.accent : EconomofarUI.accentSoft)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(selected ? .isSelected : [])
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
    private func content(_ overview: ShopsOverview) -> some View {
        heroCard(overview)

        if let note = ShopsText.unknownNote(overview) {
            footnote(note)
        }

        if overview.hasShops {
            if !overview.hasBaseline {
                DashboardInfoBanner(
                    icon: "clock.fill",
                    message: ShopsText.noBaselineNote,
                    tint: EconomofarUI.accent,
                    background: EconomofarUI.accentSoft
                )
                .padding(.horizontal, -20)
            }

            if overview.months < 7 {
                footnote(ShopsText.fadingPeriodNote)
            }

            if viewModel.availableFilters.count > 1 {
                filterBar
            }

            rankingCard(overview)
        } else {
            DashboardInfoBanner(
                icon: "questionmark.circle.fill",
                message: overview.hasTickets ? ShopsText.emptyHint : ShopsText.noTicketsHint + " " + ShopsText.emptyHint,
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }

        methodBanner
    }

    // MARK: Hero

    private func heroCard(_ overview: ShopsOverview) -> some View {
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Vos dépenses · " + ShopsText.periodTitle(overview.months))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                Text(ShopsText.headline(overview))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(ShopsText.summary(overview))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                heroChip(title: "Enseignes", value: "\(overview.shopCount)")
                heroChip(title: "Nouvelles", value: ShopsText.newValue(overview))
                heroChip(title: "Délaissées", value: ShopsText.fadingValue(overview))
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
        .accessibilityLabel(Text(title + " : " + ShopsText.spoken(value)))
    }

    // MARK: List

    private func tint(_ level: ShopStatus) -> Color {
        switch level {
        case .new:
            return EconomofarUI.accent
        case .fading:
            return EconomofarUI.warning
        case .up:
            return EconomofarUI.danger
        case .down:
            return EconomofarUI.success
        case .steady:
            return EconomofarUI.textSecondary
        }
    }

    private func rankingCard(_ overview: ShopsOverview) -> some View {
        let rows = viewModel.rows

        return VStack(spacing: 8) {
            if rows.isEmpty {
                DashboardInfoBanner(
                    icon: "magnifyingglass",
                    message: ShopsText.noMatch,
                    tint: EconomofarUI.accent,
                    background: EconomofarUI.accentSoft
                )
                .padding(.horizontal, -20)
            } else {
                DashboardSectionCard(title: ShopsText.listTitle(count: rows.count)) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, line in
                        if index > 0 {
                            DashboardDivider()
                        }

                        NavigationLink {
                            ShopDetailView(line: line, months: overview.months)
                        } label: {
                            lineRow(line)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if overview.hiddenCount > 0 {
                footnote(ShopsText.hiddenNote(hidden: overview.hiddenCount, shown: overview.shops.count))
            }
        }
    }

    private func lineRow(_ line: ShopLine) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                DashboardIconBox(icon: ShopsText.icon(line.level), tint: tint(line.level))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(line.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(2)

                    Text(ShopsText.basketLine(line))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(ShopsText.lastVisitLine(line))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(ShopsText.money(line.spent))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if let share = line.sharePercent {
                        Text(ShopsText.percentText(share))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .accessibilityHidden(true)
            }

            if let status = ShopsText.statusLine(line) {
                Text(status)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(tint(line.level))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(ShopsText.rowAccessibility(line)))
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
            message: ShopsText.method,
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }
}
