import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class RepurchaseViewModel: ObservableObject {
    static let periods = [3, 6, 12, 24]

    @Published var overview: RepurchaseOverview? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published var months = 12
    @Published var filter: RepurchaseFilter = .all
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
            let result = try await RepurchaseService.shared.fetch(token: token, months: asked)

            if current == generation {
                overview = result
                loadedAt = Date()

                // A filter with nothing left to show must not hide the whole list
                if filter != .all, filter.apply(result.articles).isEmpty {
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

    /// The articles that match the filter and the search, in the order of the server.
    var rows: [RepurchaseLine] {
        guard let overview else {
            return []
        }

        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return filter.apply(overview.articles).filter { line in
            text.isEmpty || line.name.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    /// The filters that have something to show, the first one always.
    var availableFilters: [RepurchaseFilter] {
        guard let overview else {
            return [.all]
        }

        return RepurchaseFilter.allCases.filter { $0 == .all || !$0.apply(overview.articles).isEmpty }
    }

    func count(_ filter: RepurchaseFilter) -> Int {
        guard let overview else {
            return 0
        }

        return filter.apply(overview.articles).count
    }
}

// MARK: - Colours of a status

enum RepurchasePalette {
    static func tint(_ level: RepurchaseStatus) -> Color {
        switch level {
        case .due:
            return EconomofarUI.warning
        case .soon:
            return EconomofarUI.accent
        case .ok:
            return EconomofarUI.success
        case .lapsed:
            return EconomofarUI.textSecondary
        }
    }

    static func softBackground(_ level: RepurchaseStatus) -> Color {
        switch level {
        case .due:
            return EconomofarUI.warningSoft
        case .soon:
            return EconomofarUI.accentSoft
        case .ok:
            return EconomofarUI.successSoft
        case .lapsed:
            return EconomofarUI.accentSoft
        }
    }
}

// MARK: - Screen

struct RepurchaseView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = RepurchaseViewModel()

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
        .navigationTitle("Achats réguliers")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.query, prompt: RepurchaseText.searchPrompt)
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
            ForEach(RepurchaseViewModel.periods, id: \.self) { months in
                Text(RepurchaseText.periodTitle(months)).tag(months)
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

    private func filterChip(_ filter: RepurchaseFilter) -> some View {
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
    private func content(_ overview: RepurchaseOverview) -> some View {
        heroCard(overview)

        if let note = RepurchaseText.irregularNote(overview) {
            footnote(note)
        }

        if overview.hasArticles {
            if viewModel.availableFilters.count > 1 {
                filterBar
            }

            rankingCard(overview)
        } else {
            DashboardInfoBanner(
                icon: "questionmark.circle.fill",
                message: RepurchaseText.emptyHint,
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }

        methodBanner
    }

    // MARK: Hero

    private func heroCard(_ overview: RepurchaseOverview) -> some View {
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Achats réguliers · " + RepurchaseText.periodTitle(overview.months))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                Text(RepurchaseText.headline(overview))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(RepurchaseText.summary(overview))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                heroChip(title: "À racheter", value: "\(overview.dueCount)")
                heroChip(title: "Bientôt", value: "\(overview.soonCount)")
                heroChip(title: "Encore achetés", value: "\(overview.activeCount)")
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
        .accessibilityLabel(Text(title + " : " + RepurchaseText.spoken(value)))
    }

    // MARK: List

    private func rankingCard(_ overview: RepurchaseOverview) -> some View {
        let rows = viewModel.rows

        return VStack(spacing: 8) {
            if rows.isEmpty {
                DashboardInfoBanner(
                    icon: "magnifyingglass",
                    message: RepurchaseText.noMatch,
                    tint: EconomofarUI.accent,
                    background: EconomofarUI.accentSoft
                )
                .padding(.horizontal, -20)
            } else {
                DashboardSectionCard(title: RepurchaseText.listTitle(count: rows.count)) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, line in
                        if index > 0 {
                            DashboardDivider()
                        }

                        NavigationLink {
                            RepurchaseDetailView(line: line, months: overview.months)
                        } label: {
                            lineRow(line)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if overview.hiddenCount > 0 {
                footnote(RepurchaseText.hiddenNote(hidden: overview.hiddenCount, shown: overview.articles.count))
            }
        }
    }

    private func lineRow(_ line: RepurchaseLine) -> some View {
        let tint = RepurchasePalette.tint(line.level)

        return HStack(alignment: .center, spacing: 14) {
            DashboardIconBox(icon: RepurchaseText.icon(line.level), tint: tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(line.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(2)

                Text(RepurchaseText.nextLine(line))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(tint)
                    .fixedSize(horizontal: false, vertical: true)

                Text(RepurchaseText.rhythmLine(line))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(RepurchaseText.lastLine(line))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(RepurchaseText.money(line.monthlyEstimate))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(line.level == .lapsed ? EconomofarUI.textTertiary : EconomofarUI.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(line.level == .lapsed ? "non compté" : "par mois")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(EconomofarUI.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(16)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(RepurchaseText.rowAccessibility(line)))
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
            message: RepurchaseText.method,
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }
}
