import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class BudgetTrackingViewModel: ObservableObject {
    @Published var overview: BudgetTrackingOverview? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil

    /// The month the bar at the top shows and the months next to it, kept while a month is loading
    /// so that the buttons never act on a month that has been left behind.
    @Published private(set) var barMonth: String? = nil
    @Published private(set) var barPrevious: String? = nil
    @Published private(set) var barNext: String? = nil

    /// The month that is asked for, nil for the current month.
    private var requestedMonth: String? = nil
    private var generation = 0
    private var loadedAt: Date? = nil

    /// The last figures that were read, with the month that was asked for to get them: when another
    /// month can not be read, the screen goes back to them and the arrows work again.
    private var lastGood: BudgetTrackingOverview? = nil
    private var lastGoodRequested: String? = nil

    func load(token: String?) async {
        guard let token, !token.isEmpty else {
            errorMessage = "Votre session a expiré. Reconnectez-vous."
            isLoading = false
            return
        }

        generation += 1
        let current = generation
        let month = requestedMonth

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await BudgetTrackingService.shared.fetch(token: token, month: month)

            if current == generation {
                overview = fetched
                barMonth = fetched.month
                barPrevious = fetched.previousMonth
                barNext = fetched.nextMonth
                loadedAt = Date()
                lastGood = fetched
                lastGoodRequested = month
            }
        } catch APIError.unauthorized {
            // The session manager logs the user out
            if current == generation {
                errorMessage = "Votre session a expiré. Reconnectez-vous."
            }
        } catch {
            if current == generation, !Task.isCancelled {
                errorMessage = error.localizedDescription

                // Figures of an earlier day must not be shown as the current ones
                if let loadedAt, !Calendar.current.isDateInToday(loadedAt) {
                    overview = nil
                    lastGood = nil
                    self.loadedAt = nil
                } else if overview == nil, let lastGood {
                    overview = lastGood
                    requestedMonth = lastGoodRequested
                    barMonth = lastGood.month
                    barPrevious = lastGood.previousMonth
                    barNext = lastGood.nextMonth
                }
            }
        }

        if current == generation {
            isLoading = false
        }
    }

    /// The figures were counted on an earlier day: they are read again.
    func reloadIfNewDay(token: String?) async {
        guard let loadedAt, !Calendar.current.isDateInToday(loadedAt) else {
            return
        }

        await load(token: token)
    }

    /// Chooses another month; the caller reads the figures again.
    func show(month: String) {
        guard month != requestedMonth else {
            return
        }

        requestedMonth = month
        overview = nil
        barMonth = month
        barPrevious = nil
        barNext = nil
        isLoading = true

        // An answer for the month left behind must not be taken for the new one
        generation += 1
    }

    /// The budget with this key in the figures that are loaded now.
    func line(key: String) -> BudgetTrackingLine? {
        overview?.budgets.first { $0.key == key }
    }
}

// MARK: - Screen

struct BudgetTrackingView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = BudgetTrackingViewModel()

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

                    monthBar

                    if let overview = viewModel.overview {
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
        .navigationTitle("Suivi des budgets")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Also when coming back from a budget page or from the budgets screen: the figures are
            // read again
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task {
                    await viewModel.reloadIfNewDay(token: sessionManager.token)
                }
            }
        }
    }

    // MARK: Controls

    private var monthBar: some View {
        HStack(spacing: 12) {
            monthButton(icon: "chevron.left", label: "Mois précédent", target: viewModel.barPrevious)

            Text(viewModel.barMonth.map { BudgetTrackingText.monthTitle($0) } ?? "Ce mois-ci")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            monthButton(icon: "chevron.right", label: "Mois suivant", target: viewModel.barNext)
        }
    }

    private func monthButton(icon: String, label: String, target: String?) -> some View {
        Button {
            if let target {
                viewModel.show(month: target)

                Task {
                    await viewModel.load(token: sessionManager.token)
                }
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(EconomofarUI.accent)
                .frame(width: 40, height: 40)
                .background(EconomofarUI.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(target == nil)
        .opacity(target == nil ? 0.35 : 1)
        .accessibilityLabel(Text(label))
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
    private func content(_ overview: BudgetTrackingOverview) -> some View {
        heroCard(overview)

        if overview.hasBudgets {
            budgetsCard(overview)
        } else {
            DashboardInfoBanner(
                icon: "lightbulb.fill",
                message: BudgetTrackingText.noBudgetHint,
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }

        if overview.otherCount > 0 {
            othersCard(overview)
        }

        if !overview.hasTickets {
            DashboardInfoBanner(
                icon: "questionmark.circle.fill",
                message: BudgetTrackingText.emptyMonthHint,
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }

        manageCard

        methodBanner
    }

    // MARK: Hero

    private func heroCard(_ overview: BudgetTrackingOverview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Budgets · " + BudgetTrackingText.monthTitle(overview.month))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                Text(BudgetTrackingText.headline(overview))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(BudgetTrackingText.summary(overview))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            if overview.hasBudgets {
                heroBar(BudgetTrackingText.fraction(spent: overview.budgetSpent, budget: overview.budgetTotal))
            }

            Text(BudgetTrackingText.monthProgress(overview))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                if overview.hasBudgets {
                    heroChip(title: "Dans le budget", value: "\(overview.calmCount)")
                    heroChip(title: "À surveiller", value: "\(overview.warningCount)")
                    heroChip(title: overview.overCount < 2 ? "Dépassé" : "Dépassés", value: "\(overview.overCount)")
                } else {
                    heroChip(title: overview.ticketCount < 2 ? "Ticket" : "Tickets", value: "\(overview.ticketCount)")
                    heroChip(title: overview.otherCount < 2 ? "Catégorie" : "Catégories", value: "\(overview.otherCount)")
                    heroChip(title: "Dépenses", value: BudgetTrackingText.money(overview.monthSpent))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func heroBar(_ fraction: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.25))

                Capsule()
                    .fill(Color.white)
                    .frame(width: max(proxy.size.width * CGFloat(fraction), fraction > 0 ? 6 : 0))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
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

    // MARK: Budgets

    private func budgetsCard(_ overview: BudgetTrackingOverview) -> some View {
        DashboardSectionCard(title: BudgetTrackingText.listTitle(count: overview.budgets.count)) {
            ForEach(Array(overview.budgets.enumerated()), id: \.element.id) { index, line in
                if index > 0 {
                    DashboardDivider()
                }

                budgetRow(line)
            }
        }
    }

    private func levelTint(_ level: BudgetTrackingLevel) -> Color {
        switch level {
        case .ok:
            return EconomofarUI.success
        case .warning:
            return EconomofarUI.warning
        case .over:
            return EconomofarUI.danger
        }
    }

    private func budgetRow(_ line: BudgetTrackingLine) -> some View {
        NavigationLink {
            BudgetTrackingDetailView(viewModel: viewModel, key: line.key, title: line.name)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                DashboardIconBox(icon: BudgetTrackingText.icon(line.level), tint: levelTint(line.level))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(line.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(2)

                    Text(BudgetTrackingText.spentText(line))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(BudgetTrackingText.remainingText(line))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(line.level == .ok ? EconomofarUI.textSecondary : levelTint(line.level))
                        .fixedSize(horizontal: false, vertical: true)

                    progressBar(BudgetTrackingText.fraction(spent: line.spent, budget: line.budget), tint: levelTint(line.level))
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(BudgetTrackingText.percentText(line.percentUsed))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(line.level == .ok ? EconomofarUI.textPrimary : levelTint(line.level))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .padding(.top, 4)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(BudgetTrackingText.rowAccessibility(line)))
        }
        .buttonStyle(.plain)
    }

    private func progressBar(_ fraction: Double, tint: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.16))

                Capsule()
                    .fill(tint)
                    .frame(width: max(proxy.size.width * CGFloat(fraction), fraction > 0 ? 6 : 0))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    // MARK: Categories without budget

    private func othersCard(_ overview: BudgetTrackingOverview) -> some View {
        VStack(spacing: 8) {
            DashboardSectionCard(title: BudgetTrackingText.othersTitle(count: overview.otherCount)) {
                ForEach(Array(overview.others.enumerated()), id: \.element.id) { index, other in
                    if index > 0 {
                        DashboardDivider()
                    }

                    otherRow(other)
                }
            }

            if overview.hiddenOtherCount > 0 {
                footnote(BudgetTrackingText.hiddenNote(hidden: overview.hiddenOtherCount, shown: overview.others.count))
            }

            footnote(BudgetTrackingText.othersNote)
        }
    }

    private func otherRow(_ other: BudgetTrackingOther) -> some View {
        HStack(alignment: .center, spacing: 14) {
            DashboardIconBox(icon: other.hasNoCategory ? "questionmark.circle.fill" : "tag.fill", tint: EconomofarUI.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(other.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(2)

                Text(BudgetTrackingText.otherDetail(other))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(BudgetTrackingText.money(other.amount))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(other.name), \(BudgetTrackingText.money(other.amount)), \(BudgetTrackingText.tickets(other.ticketCount))"))
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(EconomofarUI.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    // MARK: Budgets screen

    private var manageCard: some View {
        DashboardSectionCard(title: "Vos budgets") {
            NavigationLink {
                CategoryBudgetsView()
            } label: {
                HStack(spacing: 14) {
                    DashboardIconBox(icon: "slider.horizontal.3", tint: EconomofarUI.accent)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(BudgetTrackingText.manageTitle)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)

                        Text(BudgetTrackingText.manageSubtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(EconomofarUI.textTertiary)
                        .accessibilityHidden(true)
                }
                .padding(16)
                .contentShape(Rectangle())
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Method

    private var methodBanner: some View {
        DashboardInfoBanner(
            icon: "info.circle.fill",
            message: BudgetTrackingText.method,
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }
}
