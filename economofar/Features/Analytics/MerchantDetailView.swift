import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class MerchantDetailViewModel: ObservableObject {
    @Published var detail: MerchantDetail? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private var generation = 0
    private var loadedAt: Date? = nil

    func load(token: String?, name: String, months: Int) async {
        guard let token, !token.isEmpty else { return }

        generation += 1
        let current = generation

        isLoading = true
        errorMessage = nil

        do {
            let result = try await MerchantInsightsService.shared.detail(token: token, name: name, months: months)

            if current == generation {
                detail = result
                loadedAt = Date()
            }
        } catch APIError.unauthorized {
            // The session manager logs the user out
        } catch {
            if current == generation, !Task.isCancelled, (error as? URLError)?.code != .cancelled {
                errorMessage = error.localizedDescription

                // Figures of an earlier day must not be shown as the current ones
                if let loadedAt, !Calendar.current.isDateInToday(loadedAt) {
                    detail = nil
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

struct MerchantDetailView: View {
    let name: String
    let months: Int

    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = MerchantDetailViewModel()

    init(name: String, months: Int) {
        self.name = name
        self.months = months
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

                    if let detail = viewModel.detail {
                        content(detail)
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
                await viewModel.load(token: sessionManager.token, name: name, months: months)
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(token: sessionManager.token, name: name, months: months)
        }
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ detail: MerchantDetail) -> some View {
        heroCard(detail)
        monthCard(detail)
        habitsCard(detail)
        monthsCard(detail)

        if !detail.categories.isEmpty {
            categoriesCard(detail)
        }

        if !detail.items.isEmpty {
            itemsCard(detail)
        }

        recentCard(detail)
    }

    // MARK: Hero

    private func heroCard(_ detail: MerchantDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(1)

                Text(AppFormat.money(detail.total))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("\(WeeklyDigestText.percent(detail.share)) % de vos dépenses · \(detail.periodText)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                heroChip(title: "Passages", value: "\(detail.tickets)")
                heroChip(title: "Panier moyen", value: AppFormat.money(detail.averageTicket))
                heroChip(title: "Dernier passage", value: MerchantText.shortLastVisit(daysAgo: detail.daysSinceLastVisit))
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

    // MARK: This month

    private func monthCard(_ detail: MerchantDetail) -> some View {
        DashboardSectionCard(title: "Ce mois-ci") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppFormat.money(detail.monthToDate))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text("depuis le 1er du mois")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(AppFormat.money(detail.previousSamePeriod))
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text("mêmes jours du mois dernier")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                    }
                }

                comparisonLabel(detail)
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func comparisonLabel(_ detail: MerchantDetail) -> some View {
        if let change = detail.changePercent {
            let isUp = change > 0
            let isSame = change == 0

            HStack(spacing: 6) {
                Image(systemName: isSame ? "equal.circle.fill" : (isUp ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill"))
                    .font(.system(size: 14, weight: .bold))

                Text(isSame ? "Stable par rapport au mois dernier" : "\(isUp ? "+" : "")\(WeeklyDigestText.percent(change)) % par rapport au mois dernier")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundColor(isSame ? EconomofarUI.textSecondary : (isUp ? EconomofarUI.warning : EconomofarUI.success))
        } else if detail.monthToDate > 0 {
            Text("Rien aux mêmes jours du mois dernier")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.warning)
        } else {
            Text("Aucun achat ce mois-ci")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textTertiary)
        }
    }

    // MARK: Habits

    private func habitsCard(_ detail: MerchantDetail) -> some View {
        DashboardSectionCard(title: "Vos habitudes") {
            if let frequency = detail.frequencyText {
                DashboardInsightRow(
                    icon: "clock.arrow.circlepath",
                    title: "Fréquence",
                    subtitle: frequency,
                    value: "",
                    tint: EconomofarUI.accent
                )

                DashboardDivider()
            }

            if let weekday = detail.weekdayText {
                DashboardInsightRow(
                    icon: "calendar",
                    title: "Jour habituel",
                    subtitle: "La plupart de vos passages ont lieu le \(weekday)",
                    value: "",
                    tint: EconomofarUI.accent
                )

                DashboardDivider()
            }

            DashboardInsightRow(
                icon: "bag.fill",
                title: "Plus gros ticket",
                subtitle: "\(WeeklyDigestText.format(detail.biggest.date, pattern: "d MMMM yyyy")) · \(detail.biggest.category)",
                value: AppFormat.money(detail.biggest.amount),
                tint: EconomofarUI.accent
            )

            DashboardDivider()

            DashboardInsightRow(
                icon: "flag.fill",
                title: "Premier passage sur la période",
                subtitle: WeeklyDigestText.format(detail.firstVisit, pattern: "d MMMM yyyy"),
                value: "",
                tint: EconomofarUI.textSecondary
            )
        }
    }

    // MARK: Months

    private static let barAreaHeight: CGFloat = 90

    private func barHeight(_ month: MerchantMonth, maxAmount: Double) -> CGFloat {
        guard month.total > 0, maxAmount > 0 else { return 4 }

        let fraction = min(max(month.total / maxAmount, 0), 1)

        return max(8, Self.barAreaHeight * CGFloat(fraction))
    }

    private func monthsCard(_ detail: MerchantDetail) -> some View {
        DashboardSectionCard(title: "Mois par mois") {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(detail.months) { month in
                    let isLast = month.id == detail.months.last?.id

                    VStack(spacing: 6) {
                        Spacer(minLength: 0)

                        Capsule()
                            .fill(month.total > 0 ? (isLast ? EconomofarUI.accentDark : EconomofarUI.accent) : EconomofarUI.cardSoft)
                            .frame(maxWidth: 28)
                            .frame(height: barHeight(month, maxAmount: detail.maxMonthTotal))

                        Text(MerchantText.monthLetter(month.month))
                            .font(.system(size: 10, weight: isLast ? .bold : .medium, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundColor(isLast ? EconomofarUI.textPrimary : EconomofarUI.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.barAreaHeight + 30)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(MerchantText.monthName(month.month)) : \(AppFormat.money(month.total))")
                }
            }
            .padding(16)
        }
    }

    // MARK: Categories

    private func categoriesCard(_ detail: MerchantDetail) -> some View {
        DashboardSectionCard(title: "Par catégorie") {
            ForEach(Array(detail.categories.enumerated()), id: \.element.id) { index, category in
                if index > 0 {
                    Divider()
                        .background(EconomofarUI.border)
                        .padding(.leading, 16)
                }

                categoryRow(category)
            }
        }
    }

    private func categoryRow(_ category: MerchantCategory) -> some View {
        let fraction = min(max(category.share / 100, 0), 1)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(AppFormat.money(category.total))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
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
            .frame(height: 8)

            Text("\(WeeklyDigestText.percent(category.share)) % des dépenses dans ce commerce")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
        }
        .padding(16)
    }

    // MARK: Items

    private func itemsCard(_ detail: MerchantDetail) -> some View {
        DashboardSectionCard(title: "Articles les plus achetés") {
            ForEach(Array(detail.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    DashboardDivider()
                }

                DashboardInsightRow(
                    icon: "cart.fill",
                    title: item.name,
                    subtitle: "\(item.quantity) acheté\(item.quantity > 1 ? "s" : "")",
                    value: AppFormat.money(item.total),
                    tint: EconomofarUI.accent
                )
            }
        }
    }

    // MARK: Recent

    private func recentCard(_ detail: MerchantDetail) -> some View {
        DashboardSectionCard(title: "Derniers passages") {
            ForEach(Array(detail.recent.enumerated()), id: \.offset) { index, purchase in
                if index > 0 {
                    DashboardDivider()
                }

                DashboardInsightRow(
                    icon: "doc.text.fill",
                    title: MerchantText.capitalizedFirst(WeeklyDigestText.format(purchase.date, pattern: "EEEE d MMMM")),
                    subtitle: purchase.category,
                    value: AppFormat.money(purchase.amount),
                    tint: EconomofarUI.accent
                )
            }
        }
    }
}
