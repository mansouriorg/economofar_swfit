import SwiftUI
import Combine

// MARK: - View model

struct SmallThresholdOption: Identifiable {
    let threshold: Int
    let title: String

    var id: Int { threshold }
}

struct SmallWindowOption: Identifiable {
    let months: Int
    let title: String

    var id: Int { months }
}

@MainActor
final class SmallPurchasesViewModel: ObservableObject {
    static let thresholds = [5, 10, 20]
    static let windows = [3, 6, 12]

    let thresholdOptions: [SmallThresholdOption] = SmallPurchasesViewModel.thresholds.map {
        SmallThresholdOption(threshold: $0, title: SmallPurchasesText.thresholdBadge($0))
    }

    let windowOptions: [SmallWindowOption] = SmallPurchasesViewModel.windows.map {
        SmallWindowOption(months: $0, title: "\($0) mois")
    }

    @Published var result: SmallPurchases? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published private(set) var loadedMonths: Int? = nil
    @Published private(set) var loadedThreshold: Int? = nil

    /// Choosing another window shows the spinner at once, before the request starts.
    @Published var months: Int = 6 {
        didSet {
            if months != oldValue {
                isLoading = true
            }
        }
    }

    /// Same for the threshold.
    @Published var threshold: Int = 10 {
        didSet {
            if threshold != oldValue {
                isLoading = true
            }
        }
    }

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
        let selectedMonths = months
        let selectedThreshold = threshold

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await SmallPurchasesService.shared.fetch(
                token: token,
                months: selectedMonths,
                threshold: selectedThreshold
            )

            if current == generation {
                result = fetched
                loadedMonths = selectedMonths
                loadedThreshold = selectedThreshold
                loadedAt = Date()
            }
        } catch APIError.unauthorized {
            // The session manager logs the user out
            if current == generation {
                errorMessage = "Votre session a expiré. Reconnectez-vous."
            }
        } catch {
            if current == generation, !Task.isCancelled {
                errorMessage = error.localizedDescription

                // Figures of an earlier month must not be shown as the current ones
                if let loadedAt, !Calendar.current.isDate(loadedAt, equalTo: Date(), toGranularity: .month) {
                    result = nil
                    loadedMonths = nil
                    loadedThreshold = nil
                    self.loadedAt = nil
                }
            }
        }

        if current == generation {
            isLoading = false
        }
    }
}

// MARK: - Screen

struct SmallPurchasesView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = SmallPurchasesViewModel()

    private struct Insight {
        let icon: String
        let title: String
        let subtitle: String
        let value: String
        let tint: Color
    }

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

                    pickers

                    if let result = viewModel.result,
                       viewModel.loadedMonths == viewModel.months,
                       viewModel.loadedThreshold == viewModel.threshold {
                        content(result)
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
        .navigationTitle("Petites dépenses")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(token: sessionManager.token)
        }
        .onChange(of: viewModel.months) { _ in
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }
        .onChange(of: viewModel.threshold) { _ in
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }
    }

    // MARK: Controls

    private var pickers: some View {
        VStack(spacing: 10) {
            Picker("Seuil", selection: $viewModel.threshold) {
                ForEach(viewModel.thresholdOptions) { option in
                    Text(option.title).tag(option.threshold)
                }
            }
            .pickerStyle(.segmented)

            Picker("Période", selection: $viewModel.months) {
                ForEach(viewModel.windowOptions) { option in
                    Text(option.title).tag(option.months)
                }
            }
            .pickerStyle(.segmented)
        }
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
    private func content(_ result: SmallPurchases) -> some View {
        heroCard(result)

        if result.hasData {
            if result.hasSmall {
                monthsCard(result)

                let rows = insights(result)

                if rows.isEmpty == false {
                    insightsCard(rows)
                }

                if result.merchants.isEmpty == false {
                    groupsCard(
                        title: "Enseignes",
                        icon: "storefront.fill",
                        groups: result.merchants,
                        total: result.merchantCount,
                        singular: "enseigne",
                        plural: "enseignes"
                    )
                }

                if result.categories.isEmpty == false {
                    groupsCard(
                        title: "Catégories",
                        icon: "tag.fill",
                        groups: result.categories,
                        total: result.categoryCount,
                        singular: "catégorie",
                        plural: "catégories"
                    )
                }
            }

            methodBanner(result)
        } else {
            DashboardInfoBanner(
                icon: "info.circle.fill",
                message: "Aucun ticket enregistré sur ces mois terminés. Le mois en cours n'est pas compté.",
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }
    }

    // MARK: Hero

    private func heroCard(_ result: SmallPurchases) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Petites dépenses \(SmallPurchasesText.thresholdBadge(result.threshold)) · " + SmallPurchasesText.periodText(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .accessibilityAddTraits(.isHeader)

                Text(AppFormat.money(result.smallTotal))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(SmallPurchasesText.summary(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                heroChip(title: "Part du total", value: SmallPurchasesText.shareText(result.shareOfSpending))
                heroChip(title: "Par mois", value: result.monthlyAverage.map { AppFormat.money($0) } ?? "-")
                heroChip(title: "Par an (estimé)", value: result.yearlyEstimate.map { AppFormat.money($0) } ?? "-")
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
        .accessibilityLabel(Text(title + " : " + (value == "-" ? "non disponible" : value)))
    }

    // MARK: Months

    private func barWidth(_ value: Double, maxValue: Double, full: CGFloat) -> CGFloat {
        guard maxValue > 0, value > 0 else {
            return 0
        }

        return max(6, full * CGFloat(value / maxValue))
    }

    private func monthsCard(_ result: SmallPurchases) -> some View {
        let maxValue = result.perMonth.map { $0.total }.max() ?? 0
        let untracked = max(result.perMonth.count - result.trackedMonths, 0)

        return DashboardSectionCard(title: "Mois par mois") {
            VStack(spacing: 12) {
                ForEach(Array(result.perMonth.enumerated()), id: \.offset) { index, month in
                    monthRow(
                        key: index < result.monthKeys.count ? result.monthKeys[index] : "",
                        month: month,
                        tracked: index >= untracked,
                        maxValue: maxValue
                    )
                }
            }
            .padding(16)
        }
    }

    private func monthRow(key: String, month: SmallMonth, tracked: Bool, maxValue: Double) -> some View {
        HStack(spacing: 10) {
            Text(CategoryTrendsText.shortMonth(key))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(tracked ? EconomofarUI.textSecondary : EconomofarUI.textTertiary)
                .frame(width: 46, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(EconomofarUI.cardSoft)

                    Capsule()
                        .fill(EconomofarUI.accent)
                        .frame(width: tracked ? barWidth(month.total, maxValue: maxValue, full: proxy.size.width) : 0)
                }
            }
            .frame(height: 8)

            Text(tracked ? AppFormat.money(month.total) : "-")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(tracked ? EconomofarUI.textPrimary : EconomofarUI.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 84, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(SmallPurchasesText.monthAccessibility(key: key, month: month, tracked: tracked)))
    }

    // MARK: Insights

    private func insights(_ result: SmallPurchases) -> [Insight] {
        var rows: [Insight] = []

        if let days = result.daysPerPurchase {
            rows.append(Insight(
                icon: "clock.fill",
                title: "Fréquence",
                subtitle: SmallPurchasesText.capitalised(SmallPurchasesText.frequency(days)),
                value: SmallPurchasesText.purchases(result.smallCount),
                tint: EconomofarUI.accent
            ))
        }

        if let average = result.smallAverage {
            rows.append(Insight(
                icon: "cart.fill",
                title: "Montant moyen",
                subtitle: "Par petit achat",
                value: AppFormat.money(average),
                tint: EconomofarUI.accent
            ))
        }

        if let saving = result.yearlySavingIfQuarterFewer, saving > 0 {
            rows.append(Insight(
                icon: "leaf.fill",
                title: "Un sur quatre en moins",
                subtitle: "Économie estimée par an",
                value: AppFormat.money(saving),
                tint: EconomofarUI.success
            ))
        }

        return rows
    }

    private func insightsCard(_ rows: [Insight]) -> some View {
        DashboardSectionCard(title: "À retenir") {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    DashboardDivider()
                }

                DashboardInsightRow(
                    icon: row.icon,
                    title: row.title,
                    subtitle: row.subtitle,
                    value: row.value,
                    tint: row.tint
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(row.title), \(row.subtitle), \(row.value)"))
            }
        }
    }

    // MARK: Merchants and categories

    private func groupsCard(
        title: String,
        icon: String,
        groups: [SmallGroup],
        total: Int,
        singular: String,
        plural: String
    ) -> some View {
        DashboardSectionCard(title: title) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                if index > 0 {
                    DashboardDivider()
                }

                DashboardInsightRow(
                    icon: icon,
                    title: group.name,
                    subtitle: SmallPurchasesText.groupDetail(group),
                    value: AppFormat.money(group.total),
                    tint: EconomofarUI.warning
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(group.name), \(SmallPurchasesText.groupDetail(group)), \(AppFormat.money(group.total))"))
            }

            if total > groups.count {
                Text(SmallPurchasesText.more(total - groups.count, singular: singular, plural: plural))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
        }
    }

    // MARK: Method

    private func methodBanner(_ result: SmallPurchases) -> some View {
        let limit = SmallPurchasesText.thresholdAmount(result.threshold)

        var parts = [
            "Un petit achat est un ticket enregistré de \(limit) maximum.",
            " L'estimation annuelle prolonge votre moyenne mensuelle sur 12 mois."
        ]

        if (result.yearlySavingIfQuarterFewer ?? 0) > 0 {
            parts.append(" « Un sur quatre en moins » est le quart de cette estimation.")
        }

        parts.append(" Le mois en cours n'est pas compté : les chiffres s'arrêtent à la fin de \(CategoryTrendsText.monthYear(result.to)).")
        parts.append(" Le premier mois suivi peut être incomplet.")

        let message = parts.joined()

        return DashboardInfoBanner(
            icon: "info.circle.fill",
            message: message,
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }
}
