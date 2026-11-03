import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class RepurchaseDetailViewModel: ObservableObject {
    @Published var detail: RepurchaseDetail? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil

    private var generation = 0
    private var loadedAt: Date? = nil

    func load(token: String?, key: String, months: Int) async {
        guard let token, !token.isEmpty else {
            errorMessage = "Votre session a expiré. Reconnectez-vous."
            isLoading = false
            return
        }

        generation += 1
        let current = generation

        isLoading = true
        errorMessage = nil

        do {
            let result = try await RepurchaseService.shared.fetchDetail(token: token, key: key, months: months)

            if current == generation {
                detail = result
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

// MARK: - Small chart

/// One column for each delay between two purchases, the oldest on the left, and a thin line at the usual delay.
private struct RepurchaseDelayChart: View {
    let intervals: [Int]
    let cycleDays: Int
    let spoken: String

    private let chartHeight: CGFloat = 96

    var body: some View {
        let peak = Double(max(intervals.max() ?? 0, cycleDays, 1))

        return ZStack(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: intervals.count > 14 ? 3 : 6) {
                ForEach(Array(intervals.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(isNear(value) ? EconomofarUI.accent : EconomofarUI.warning)
                        .frame(height: height(Double(value), peak: peak))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: chartHeight, alignment: .bottom)

            Rectangle()
                .fill(EconomofarUI.textTertiary)
                .frame(height: 1)
                .offset(y: -height(Double(cycleDays), peak: peak))
        }
        .frame(height: chartHeight, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spoken))
    }

    /// A delay is near the usual one when it is off by half of it at most.
    private func isNear(_ value: Int) -> Bool {
        2 * abs(value - cycleDays) <= cycleDays
    }

    private func height(_ value: Double, peak: Double) -> CGFloat {
        guard peak > 0, value.isFinite, value > 0 else {
            return 2
        }

        return max(CGFloat(value / peak) * chartHeight, 3)
    }
}

// MARK: - Screen

struct RepurchaseDetailView: View {
    let line: RepurchaseLine
    let months: Int

    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = RepurchaseDetailViewModel()

    init(line: RepurchaseLine, months: Int) {
        self.line = line
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
                    } else {
                        retryButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .refreshable {
                await viewModel.load(token: sessionManager.token, key: line.key, months: months)
            }
        }
        .navigationTitle(line.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(token: sessionManager.token, key: line.key, months: months)
        }
    }

    private var retryButton: some View {
        Button {
            Task {
                await viewModel.load(token: sessionManager.token, key: line.key, months: months)
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
    private func content(_ detail: RepurchaseDetail) -> some View {
        heroCard(detail)

        DashboardInfoBanner(
            icon: RepurchaseText.icon(detail.article.level),
            message: RepurchaseText.statusBanner(detail.article),
            tint: RepurchasePalette.tint(detail.article.level),
            background: RepurchasePalette.softBackground(detail.article.level)
        )
        .padding(.horizontal, -20)

        figuresCard(detail.article)

        if !detail.intervals.isEmpty {
            delaysCard(detail)
        }

        if !detail.purchases.isEmpty {
            purchasesCard(detail)
        }

        if !detail.shops.isEmpty {
            shopsCard(detail)
        }

        DashboardInfoBanner(
            icon: "info.circle.fill",
            message: RepurchaseText.detailMethod,
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }

    // MARK: Hero

    private func heroCard(_ detail: RepurchaseDetail) -> some View {
        let article = detail.article

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(article.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(RepurchaseText.statusTitle(article.level))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(1)

                Text(RepurchaseText.detailHeadline(article))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)

                Text(RepurchaseText.detailSummary(article, months: detail.months))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                heroChip(title: "Rythme", value: "\(article.cycleDays)\u{00A0}j", spoken: RepurchaseText.days(article.cycleDays))
                heroChip(title: "Par achat", value: RepurchaseText.money(article.averageSpend), spoken: RepurchaseText.money(article.averageSpend))
                heroChip(title: "Par mois", value: RepurchaseText.money(article.monthlyEstimate), spoken: RepurchaseText.money(article.monthlyEstimate))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func heroChip(title: String, value: String, spoken: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .opacity(0.85)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title + " : " + spoken))
    }

    // MARK: Figures

    private func figuresCard(_ article: RepurchaseLine) -> some View {
        var rows: [(String, String)] = [
            ("Dernier achat", RepurchaseText.dateText(article.lastDate))
        ]

        if article.level != .lapsed {
            rows.append((RepurchaseText.nextDateTitle(article), RepurchaseText.dateText(article.nextDate)))
        }

        rows.append(("Premier achat", RepurchaseText.dateText(article.firstDate)))
        rows.append(("Délai entre deux achats", RepurchaseText.spreadText(article)))
        rows.append(("Quantité achetée", "\(article.totalQuantity) (\(RepurchaseText.quantityText(article.averageQuantity)) par achat)"))
        rows.append(("Dépensé sur la période", RepurchaseText.money(article.spent)))

        if let shop = article.usualShop, !shop.isEmpty {
            rows.append(("Achat habituel chez", shop))
        }

        return DashboardSectionCard(title: RepurchaseText.figuresTitle) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    DashboardDivider()
                }

                plainRow(title: row.0, value: row.1)
            }
        }
    }

    private func plainRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    // MARK: Delays

    private func delaysCard(_ detail: RepurchaseDetail) -> some View {
        let article = detail.article
        let spoken = RepurchaseText.intervalsAccessibility(detail.intervals, cycleDays: article.cycleDays)

        return VStack(spacing: 8) {
            DashboardSectionCard(title: RepurchaseText.intervalsTitle) {
                VStack(alignment: .leading, spacing: 10) {
                    RepurchaseDelayChart(intervals: detail.intervals, cycleDays: article.cycleDays, spoken: spoken)

                    Text(RepurchaseText.intervalsCaption(article))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)
                }
                .padding(16)
            }

            if detail.hiddenIntervalCount > 0 {
                footnote(RepurchaseText.hiddenIntervalsNote(detail))
            }
        }
    }

    // MARK: Purchases

    private func purchasesCard(_ detail: RepurchaseDetail) -> some View {
        VStack(spacing: 8) {
            DashboardSectionCard(title: RepurchaseText.purchasesTitle) {
                ForEach(Array(detail.purchases.enumerated()), id: \.offset) { index, purchase in
                    if index > 0 {
                        DashboardDivider()
                    }

                    purchaseRow(purchase)
                }
            }

            if detail.hiddenPurchaseCount > 0 {
                footnote(RepurchaseText.hiddenPurchasesNote(detail))
            }
        }
    }

    private func purchaseRow(_ purchase: RepurchasePurchase) -> some View {
        let subtitle: String = purchase.shop.isEmpty ? "Quantité : \(purchase.quantity)" : "Quantité : \(purchase.quantity) · \(purchase.shop)"

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(RepurchaseText.dateText(purchase.date))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(RepurchaseText.money(purchase.amount))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    // MARK: Shops

    private func shopsCard(_ detail: RepurchaseDetail) -> some View {
        DashboardSectionCard(title: RepurchaseText.shopsTitle) {
            ForEach(Array(detail.shops.enumerated()), id: \.offset) { index, shop in
                if index > 0 {
                    DashboardDivider()
                }

                shopRow(shop)
            }
        }
    }

    private func shopRow(_ shop: RepurchaseShop) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(shop.name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(RepurchaseText.shopLine(shop))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .lineLimit(1)
                .layoutPriority(1)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(EconomofarUI.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
