import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class HomeHighlightsViewModel: ObservableObject {
    @Published var health: HealthScoreReport? = nil
    @Published var cashFlow: CashFlowReport? = nil
    @Published var goals: [SavingsGoal]? = nil
    @Published var nextPayment: RecurringExpense? = nil
    @Published var dailyBudget: DailyBudget? = nil
    private var dailyBudgetLoadedAt: Date? = nil
    @Published var hasLoaded = false
    @Published var isLoading = false

    private var lastLoad: Date? = nil
    private var loadStartedAt: Date? = nil
    private var pendingReload = false

    private static let minimumDelay: TimeInterval = 5
    private static let duplicateWindow: TimeInterval = 2
    private static let paymentMinInterval = 20
    private static let paymentMaxDays = 45

    var hasContent: Bool {
        health != nil || cashFlow != nil || goals != nil || nextPayment != nil || dailyBudget != nil
    }

    /// Never throws: a block whose data cannot be downloaded keeps what it had.
    /// A forced load asked while an older load is running is played again right after it.
    func load(token: String?, force: Bool) async {
        guard let token, !token.isEmpty else { return }

        if isLoading {
            if force, let started = loadStartedAt, Date().timeIntervalSince(started) > Self.duplicateWindow {
                pendingReload = true
            }

            return
        }

        let delay = force ? Self.duplicateWindow : Self.minimumDelay

        if let lastLoad, Date().timeIntervalSince(lastLoad) < delay {
            return
        }

        isLoading = true
        loadStartedAt = Date()

        async let loadedHealth = try? HealthScoreService.shared.fetch(token: token)
        async let loadedCash = try? IncomeService.shared.fetchCashFlow(months: 1, token: token)
        async let loadedGoals = try? SavingsGoalService.shared.fetchAll(token: token)
        async let loadedRecurring = try? RecurringExpenseService.shared.fetch(token: token)
        async let loadedDaily = try? DailyBudgetService.shared.fetch(token: token)

        let newHealth = await loadedHealth
        let newCash = await loadedCash
        let newGoals = await loadedGoals
        let newRecurring = await loadedRecurring
        let newDaily = await loadedDaily

        if Task.isCancelled {
            pendingReload = false
            isLoading = false
            return
        }

        var gotSomething = false

        if let newHealth {
            health = newHealth
            gotSomething = true
        }

        if let newCash {
            cashFlow = newCash
            gotSomething = true
        }

        if let newGoals {
            goals = newGoals
            gotSomething = true
        }

        if let newRecurring {
            nextPayment = Self.pickNextPayment(newRecurring.items)
            gotSomething = true
        }

        if let newDaily {
            dailyBudget = newDaily
            dailyBudgetLoadedAt = Date()
            gotSomething = true
        } else if let loadedAt = dailyBudgetLoadedAt, !Calendar.current.isDateInToday(loadedAt) {
            dailyBudget = nil
            dailyBudgetLoadedAt = nil
        }

        if gotSomething {
            lastLoad = Date()
        }

        hasLoaded = true
        isLoading = false

        if pendingReload {
            pendingReload = false
            lastLoad = nil
            await load(token: token, force: true)
        }
    }

    private static func pickNextPayment(_ items: [RecurringExpense]) -> RecurringExpense? {
        items
            .filter {
                $0.intervalDays >= paymentMinInterval
                    && $0.daysUntilNext >= 0
                    && $0.daysUntilNext <= paymentMaxDays
            }
            .min { $0.daysUntilNext < $1.daysUntilNext }
    }
}

// MARK: - Section

private enum HighlightKind: Hashable {
    case health
    case cash
    case goals
    case payment
    case daily
}

/// "Votre bilan": the health score, the month so far, the closest savings goal and the next
/// regular payment. It reloads each time the dashboard finishes loading its own data.
struct HomeHighlightsSection: View {
    let isDashboardLoading: Bool

    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = HomeHighlightsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.hasContent {
                content
            } else if viewModel.hasLoaded && !viewModel.isLoading {
                retryCard
            } else {
                loadingCard
            }
        }
        .onAppear {
            Task {
                await viewModel.load(token: sessionManager.token, force: false)
            }
        }
        .onChange(of: isDashboardLoading) { busy in
            if !busy {
                Task {
                    await viewModel.load(token: sessionManager.token, force: true)
                }
            }
        }
    }

    // MARK: States

    private var loadingCard: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(EconomofarUI.accent)

            Text("Chargement de votre bilan")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            Spacer()
        }
        .padding(16)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
        .padding(.horizontal, 20)
    }

    private var retryCard: some View {
        Button {
            Task {
                await viewModel.load(token: sessionManager.token, force: true)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(EconomofarUI.accent)

                Text("Bilan indisponible, touchez pour réessayer")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)

                Spacer()
            }
            .padding(16)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: Content

    private var kinds: [HighlightKind] {
        var result: [HighlightKind] = []

        if viewModel.dailyBudget != nil { result.append(.daily) }
        if viewModel.health != nil { result.append(.health) }
        if viewModel.cashFlow != nil { result.append(.cash) }
        if viewModel.goals != nil { result.append(.goals) }
        if viewModel.nextPayment != nil { result.append(.payment) }

        return result
    }

    private var content: some View {
        DashboardSectionCard(title: "Votre bilan") {
            ForEach(Array(kinds.enumerated()), id: \.element) { index, kind in
                if index > 0 {
                    DashboardDivider()
                }

                row(for: kind)
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func row(for kind: HighlightKind) -> some View {
        switch kind {
        case .health:
            if let report = viewModel.health {
                healthRow(report)
            }
        case .cash:
            if let report = viewModel.cashFlow {
                cashRow(report)
            }
        case .goals:
            if let goals = viewModel.goals {
                goalsRow(goals)
            }
        case .payment:
            if let payment = viewModel.nextPayment {
                paymentRow(payment)
            }
        case .daily:
            if let budget = viewModel.dailyBudget {
                dailyRow(budget)
            }
        }
    }

    // MARK: Rows

    private func healthRow(_ report: HealthScoreReport) -> some View {
        let subtitle: String
        let value: String
        var level = report.levelValue

        if let score = report.score {
            if level == .unknown {
                level = levelFromScore(score)
            }

            let plural = report.availableComponents > 1 ? "s" : ""
            subtitle = "\(healthLabel(level)) · calculée sur \(report.availableComponents) critère\(plural)"
            value = "\(score)/100"
        } else {
            subtitle = "Complétez 2 critères pour obtenir votre note"
            value = "–"
        }

        return NavigationLink {
            HealthScoreView()
        } label: {
            DashboardInsightRow(
                icon: "waveform.path.ecg",
                title: "Santé financière",
                subtitle: subtitle,
                value: value,
                tint: healthTint(level)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func cashRow(_ report: CashFlowReport) -> some View {
        NavigationLink {
            IncomeView()
        } label: {
            Group {
                if report.hasIncome, let month = report.currentMonth {
                    DashboardInsightRow(
                        icon: "chart.bar.fill",
                        title: "Ce mois-ci",
                        subtitle: "Revenus \(AppFormat.money(month.income)) · Dépensé \(AppFormat.money(month.expenses))",
                        value: AppFormat.money(month.net),
                        tint: month.net >= 0 ? EconomofarUI.success : EconomofarUI.danger
                    )
                } else {
                    DashboardInsightRow(
                        icon: "chart.bar.fill",
                        title: "Revenus et bilan",
                        subtitle: "Ajoutez votre salaire pour voir ce qu'il vous reste",
                        value: "Ajouter",
                        tint: EconomofarUI.accent
                    )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func goalsRow(_ goals: [SavingsGoal]) -> some View {
        let open = goals.filter { !$0.isCompleted }
        let featured = featuredGoal(open)

        return NavigationLink {
            SavingsGoalsView()
        } label: {
            VStack(spacing: 0) {
                if let goal = featured {
                    DashboardInsightRow(
                        icon: SavingsGoalIcons.symbol(for: goal.icon),
                        title: goal.name,
                        subtitle: goalSubtitle(goal),
                        value: "\(Int(goal.percent.isFinite ? goal.percent.rounded() : 0)) %",
                        tint: EconomofarUI.accent
                    )

                    HomeHighlightBar(fraction: goal.progressFraction, tint: EconomofarUI.accent)
                        .padding(.leading, 76)
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                        .padding(.top, -6)
                } else if goals.isEmpty {
                    DashboardInsightRow(
                        icon: "flag.fill",
                        title: "Objectifs d'épargne",
                        subtitle: "Créez un projet et suivez le rythme à tenir",
                        value: "Créer",
                        tint: EconomofarUI.accent
                    )
                } else {
                    DashboardInsightRow(
                        icon: "flag.fill",
                        title: "Objectifs d'épargne",
                        subtitle: "Tous vos objectifs sont atteints",
                        value: "Bravo",
                        tint: EconomofarUI.success
                    )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func paymentRow(_ payment: RecurringExpense) -> some View {
        NavigationLink {
            RecurringExpensesView()
        } label: {
            DashboardInsightRow(
                icon: "arrow.triangle.2.circlepath",
                title: "Prochain paiement régulier",
                subtitle: "\(payment.merchantName) · \(whenText(payment.daysUntilNext))",
                value: AppFormat.money(payment.typicalAmount),
                tint: EconomofarUI.warning
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dailyRow(_ budget: DailyBudget) -> some View {
        NavigationLink {
            DailyBudgetView()
        } label: {
            VStack(spacing: 0) {
                DashboardInsightRow(
                    icon: "sun.max.fill",
                    title: "Budget du jour",
                    subtitle: budget.rowSubtitle,
                    value: budget.rowValue,
                    tint: budget.level.tint
                )

                if budget.hasBudget {
                    HomeHighlightBar(fraction: budget.usedFraction, tint: budget.level.tint)
                        .padding(.leading, 76)
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                        .padding(.top, -6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Text helpers

    /// The goal whose deadline is the closest in the future, otherwise the most advanced one.
    private func featuredGoal(_ open: [SavingsGoal]) -> SavingsGoal? {
        let upcoming = open
            .filter { ($0.daysLeft ?? -1) >= 0 }
            .sorted { ($0.daysLeft ?? 0) < ($1.daysLeft ?? 0) }

        if let first = upcoming.first {
            return first
        }

        return open.max { $0.percent < $1.percent }
    }

    private func goalSubtitle(_ goal: SavingsGoal) -> String {
        let remaining = "Il reste \(AppFormat.money(goal.remainingAmount))"

        guard let days = goal.daysLeft else {
            return remaining
        }

        if days < 0 {
            return "Échéance dépassée · \(remaining.lowercasedFirst())"
        }

        if days == 0 {
            return "\(remaining) · échéance aujourd'hui"
        }

        return "\(remaining) · échéance dans \(days) jour\(days > 1 ? "s" : "")"
    }

    private func whenText(_ days: Int) -> String {
        if days <= 0 { return "aujourd'hui" }
        if days == 1 { return "demain" }
        return "dans \(days) jours"
    }

    private func levelFromScore(_ score: Int) -> HealthLevel {
        if score >= 80 { return .excellent }
        if score >= 60 { return .good }
        if score >= 40 { return .watch }
        return .fragile
    }

    private func healthLabel(_ level: HealthLevel) -> String {
        switch level {
        case .excellent: return "Excellente"
        case .good: return "Bonne"
        case .watch: return "À surveiller"
        case .fragile: return "Fragile"
        case .unknown: return "Pas encore de score"
        }
    }

    private func healthTint(_ level: HealthLevel) -> Color {
        switch level {
        case .excellent: return EconomofarUI.success
        case .good: return EconomofarUI.accent
        case .watch: return EconomofarUI.warning
        case .fragile: return EconomofarUI.danger
        case .unknown: return EconomofarUI.textTertiary
        }
    }
}

private extension String {
    func lowercasedFirst() -> String {
        guard let first = first else { return self }
        return first.lowercased() + String(dropFirst())
    }
}

private struct HomeHighlightBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        let safe = fraction.isFinite ? min(max(fraction, 0), 1) : 0

        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(EconomofarUI.cardSoft)

                Capsule()
                    .fill(tint)
                    .frame(width: max(safe > 0 ? 6 : 0, proxy.size.width * CGFloat(safe)))
            }
        }
        .frame(height: 8)
    }
}
