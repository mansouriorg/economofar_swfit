import SwiftUI
import Combine

// MARK: - View model

struct TrendWindowOption: Identifiable {
    let months: Int
    let title: String

    var id: Int { months }
}

@MainActor
final class CategoryTrendsViewModel: ObservableObject {
    static let windows = [3, 6, 12]

    let options: [TrendWindowOption] = CategoryTrendsViewModel.windows.map {
        TrendWindowOption(months: $0, title: "\($0) mois")
    }

    @Published var result: CategoryTrends? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published private(set) var loadedMonths: Int? = nil

    /// Choosing another window shows the spinner at once, before the request starts.
    @Published var months: Int = 6 {
        didSet {
            if months != oldValue {
                isLoading = true
            }
        }
    }

    private var generation = 0
    private var loadedAt: Date? = nil

    func load(token: String?) async {
        guard let token, !token.isEmpty else {
            isLoading = false
            return
        }

        generation += 1
        let current = generation
        let selected = months

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await CategoryTrendsService.shared.fetch(token: token, months: selected)

            if current == generation {
                result = fetched
                loadedMonths = selected
                loadedAt = Date()
            }
        } catch APIError.unauthorized {
            // The session manager logs the user out
        } catch {
            if current == generation, !Task.isCancelled {
                errorMessage = error.localizedDescription

                // Figures of an earlier month must not be shown as the current ones
                if let loadedAt, !Calendar.current.isDate(loadedAt, equalTo: Date(), toGranularity: .month) {
                    result = nil
                    loadedMonths = nil
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

struct CategoryTrendsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = CategoryTrendsViewModel()

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

                    windowPicker

                    if let result = viewModel.result, viewModel.loadedMonths == viewModel.months {
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
        .navigationTitle("Tendances")
        .navigationBarTitleDisplayMode(.inline)
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

    private var windowPicker: some View {
        Picker("Période", selection: $viewModel.months) {
            ForEach(viewModel.options) { option in
                Text(option.title).tag(option.months)
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
    private func content(_ result: CategoryTrends) -> some View {
        heroCard(result)

        if result.hasData {
            if highlightedCategories(result).isEmpty == false {
                highlightsCard(result)
            }

            categoriesCard(result)

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

    /// The server keeps the biggest categories and adds one last line for all the others.
    private func hasMergedRow(_ result: CategoryTrends) -> Bool {
        result.categoryCount > result.categories.count
    }

    private func realCategories(_ result: CategoryTrends) -> [CategoryTrend] {
        hasMergedRow(result) ? Array(result.categories.dropLast()) : result.categories
    }

    /// With merged categories only the biggest ones are counted: the number is a minimum.
    private func countText(_ count: Int, in result: CategoryTrends) -> String {
        hasMergedRow(result) ? "\(count)+" : "\(count)"
    }

    private func risingCount(_ result: CategoryTrends) -> String {
        countText(realCategories(result).filter { $0.trend == "UP" || $0.trend == "NEW" }.count, in: result)
    }

    private func fallingCount(_ result: CategoryTrends) -> String {
        countText(realCategories(result).filter { $0.trend == "DOWN" || $0.trend == "GONE" }.count, in: result)
    }

    private func heroCard(_ result: CategoryTrends) -> some View {
        let overall = result.overall
        let compared = result.compareMonths >= 1

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Période · " + CategoryTrendsText.periodText(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))

                Text(overall.monthlyAverage.map { AppFormat.money($0) } ?? "-")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("dépensés par mois en moyenne")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))

                if overall.trend != "NONE" {
                    heroBadge(overall)
                        .padding(.top, 2)
                }

                Text(CategoryTrendsText.summary(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            if result.hasData {
                overallBars(result)
            }

            HStack(spacing: 10) {
                heroChip(title: "Mois suivis", value: "\(result.trackedMonths)")
                heroChip(title: "En hausse", value: compared ? risingCount(result) : "-")
                heroChip(title: "En baisse", value: compared ? fallingCount(result) : "-")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func heroBadge(_ overall: CategoryTrend) -> some View {
        var text = CategoryTrendsText.overallTitle(overall.trend)

        if overall.trend == "UP" || overall.trend == "DOWN", let percent = overall.changePercent {
            text += " · " + CategoryTrendsText.percentText(percent)
        }

        return HStack(spacing: 6) {
            Image(systemName: CategoryTrendsText.icon(overall.trend))
                .font(.system(size: 12, weight: .bold))
                .accessibilityHidden(true)

            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.18))
        .clipShape(Capsule())
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
        .accessibilityElement(children: .combine)
    }

    // MARK: Bars

    private func barHeight(_ value: Double, maxValue: Double, full: CGFloat) -> CGFloat {
        guard maxValue > 0, value > 0 else {
            return 3
        }

        return max(5, full * CGFloat(value / maxValue))
    }

    private func overallBars(_ result: CategoryTrends) -> some View {
        let values = result.overall.totals
        let maxValue = values.max() ?? 0

        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                Capsule()
                    .fill(Color.white.opacity(overallOpacity(
                        CategoryTrendsText.role(
                            index: index,
                            count: values.count,
                            trackedMonths: result.trackedMonths,
                            compareMonths: result.compareMonths
                        )
                    )))
                    .frame(maxWidth: 24)
                    .frame(height: barHeight(value, maxValue: maxValue, full: 46))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 46, alignment: .bottom)
        .accessibilityHidden(true)
    }

    private func overallOpacity(_ role: TrendBarRole) -> Double {
        switch role {
        case .untracked:
            return 0.15
        case .earlier:
            return 0.55
        case .recent:
            return 0.95
        case .other:
            return 0.35
        }
    }

    private func trendTint(_ trend: String) -> Color {
        switch trend {
        case "UP", "NEW":
            return EconomofarUI.warning
        case "DOWN", "GONE":
            return EconomofarUI.success
        case "STABLE":
            return EconomofarUI.accent
        default:
            return EconomofarUI.textTertiary
        }
    }

    private func barColor(_ role: TrendBarRole, tint: Color) -> Color {
        switch role {
        case .untracked:
            return EconomofarUI.cardSoft
        case .earlier:
            return tint.opacity(0.45)
        case .recent:
            return tint
        case .other:
            return EconomofarUI.textTertiary.opacity(0.35)
        }
    }

    // MARK: Highlights

    private func rise(_ category: CategoryTrend) -> Double {
        (category.recentAverage ?? 0) - (category.earlierAverage ?? 0)
    }

    private func biggestRise(_ result: CategoryTrends) -> CategoryTrend? {
        realCategories(result)
            .filter { ($0.trend == "UP" || $0.trend == "NEW") && rise($0) > 0 }
            .max { rise($0) < rise($1) }
    }

    private func biggestDrop(_ result: CategoryTrends) -> CategoryTrend? {
        realCategories(result)
            .filter { ($0.trend == "DOWN" || $0.trend == "GONE") && rise($0) < 0 }
            .min { rise($0) < rise($1) }
    }

    private func highlightedCategories(_ result: CategoryTrends) -> [CategoryTrend] {
        [biggestRise(result), biggestDrop(result)].compactMap { $0 }
    }

    private func highlightsCard(_ result: CategoryTrends) -> some View {
        let up = biggestRise(result)
        let down = biggestDrop(result)

        return DashboardSectionCard(title: "À retenir") {
            if let up {
                DashboardInsightRow(
                    icon: "arrow.up.right.circle.fill",
                    title: "Plus forte hausse",
                    subtitle: "\(up.name) · par mois",
                    value: WeeklyDigestText.signedMoney(rise(up)),
                    tint: EconomofarUI.warning
                )
            }

            if up != nil, down != nil {
                DashboardDivider()
            }

            if let down {
                DashboardInsightRow(
                    icon: "arrow.down.right.circle.fill",
                    title: "Plus forte baisse",
                    subtitle: "\(down.name) · par mois",
                    value: WeeklyDigestText.signedMoney(rise(down)),
                    tint: EconomofarUI.success
                )
            }
        }
    }

    // MARK: Categories

    private func categoriesCard(_ result: CategoryTrends) -> some View {
        DashboardSectionCard(title: "Par catégorie") {
            ForEach(Array(result.categories.enumerated()), id: \.offset) { index, category in
                if index > 0 {
                    Divider()
                        .background(EconomofarUI.border)
                        .padding(.leading, 16)
                }

                categoryRow(
                    category,
                    in: result,
                    merged: hasMergedRow(result) && index == result.categories.count - 1
                )
            }
        }
    }

    private func categoryRow(_ category: CategoryTrend, in result: CategoryTrends, merged: Bool) -> some View {
        let tint = trendTint(category.trend)
        let values = category.totals
        let maxValue = values.max() ?? 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(category.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                trendBadge(category, tint: tint, merged: merged)
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    Capsule()
                        .fill(barColor(
                            CategoryTrendsText.role(
                                index: index,
                                count: values.count,
                                trackedMonths: result.trackedMonths,
                                compareMonths: result.compareMonths
                            ),
                            tint: tint
                        ))
                        .frame(maxWidth: 24)
                        .frame(height: barHeight(value, maxValue: maxValue, full: 40))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 40, alignment: .bottom)

            Text(CategoryTrendsText.rowDetail(category, monthKeys: result.monthKeys))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(CategoryTrendsText.rowAccessibility(category, monthKeys: result.monthKeys)))
    }

    private func trendBadge(_ category: CategoryTrend, tint: Color, merged: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: CategoryTrendsText.icon(category.trend))
                .font(.system(size: 10, weight: .bold))

            Text(CategoryTrendsText.badgeText(category, merged: merged))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundColor(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: Method

    private func methodBanner(_ result: CategoryTrends) -> some View {
        let count = result.compareMonths

        let comparison: String

        if count >= 2 {
            comparison = "La tendance compare les \(count) derniers mois aux \(count) mois précédents (barres foncées et claires)."
        } else if count == 1 {
            comparison = "La tendance compare le dernier mois au mois précédent."
        } else {
            comparison = "Les tendances apparaissent à partir de 2 mois terminés avec des tickets."
        }

        var parts = [
            comparison,
            " Une variation est signalée à partir de 15 % et de 5 € par mois, sinon la catégorie est stable."
        ]

        if count >= 1 {
            parts.append(" « Nouvelle » : rien sur les mois précédents ; « Disparue » : rien sur les derniers.")
        }

        parts.append(" Le premier mois suivi peut être incomplet.")
        parts.append(" Le mois en cours n'est pas compté (jusqu'à \(CategoryTrendsText.monthYear(result.to))).")
        parts.append(" Seuls les tickets enregistrés sont comptés ; une catégorie vide compte comme « Autre ».")

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
