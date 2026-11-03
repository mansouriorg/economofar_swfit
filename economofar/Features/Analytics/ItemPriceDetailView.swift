import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class ItemPriceDetailViewModel: ObservableObject {
    @Published var detail: ItemPriceDetail? = nil
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
            let result = try await ItemPricesService.shared.fetchDetail(token: token, key: key, months: months)

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

// MARK: - Price curve

/// The unit price of the days an article was bought, the oldest on the left.
private struct ItemPriceCurve: View {
    let points: [ItemPricePoint]
    let tint: Color

    private let padding: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let coordinates = positions(in: size)

            ZStack {
                Path { path in
                    for (index, point) in coordinates.enumerated() {
                        if index == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                if points.count <= 30 {
                    ForEach(Array(coordinates.enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(tint)
                            .frame(width: 7, height: 7)
                            .position(point)
                    }
                }
            }
        }
        .frame(height: 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(summary))
    }

    private func positions(in size: CGSize) -> [CGPoint] {
        let prices = points.map { $0.price.isFinite ? $0.price : 0 }

        guard let low = prices.min(), let high = prices.max() else {
            return []
        }

        let span = max(high - low, 0.01)
        let width = max(size.width - 2 * padding, 1)
        let height = max(size.height - 2 * padding, 1)

        return prices.enumerated().map { index, price in
            let x = prices.count > 1 ? padding + width * CGFloat(index) / CGFloat(prices.count - 1) : size.width / 2
            let ratio = high - low < 0.005 ? 0.5 : (price - low) / span
            let y = padding + height * CGFloat(1 - ratio)

            return CGPoint(x: x, y: y)
        }
    }

    private var summary: String {
        guard let first = points.first, let last = points.last else {
            return "Pas de prix"
        }

        let prices = points.map { $0.price }
        let low = prices.min() ?? first.price
        let high = prices.max() ?? first.price

        return "Courbe du prix : \(ItemPricesText.money(first.price)) le \(ItemPricesText.dateText(first.date)), \(ItemPricesText.money(last.price)) le \(ItemPricesText.dateText(last.date)), de \(ItemPricesText.money(low)) au plus bas à \(ItemPricesText.money(high)) au plus haut."
    }
}

// MARK: - Screen

struct ItemPriceDetailView: View {
    let line: ItemPriceLine
    let months: Int

    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = ItemPriceDetailViewModel()

    init(line: ItemPriceLine, months: Int) {
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
    private func content(_ detail: ItemPriceDetail) -> some View {
        heroCard(detail.item)

        if detail.points.count > 1 {
            curveCard(detail)
        }

        if let saving = ItemPricesText.savingText(detail.item) {
            DashboardInfoBanner(
                icon: "leaf.fill",
                message: saving,
                tint: EconomofarUI.success,
                background: EconomofarUI.successSoft
            )
            .padding(.horizontal, -20)
        }

        if !detail.merchants.isEmpty {
            shopsCard(detail)
        }

        pointsCard(detail)

        DashboardInfoBanner(
            icon: "info.circle.fill",
            message: ItemPricesText.detailMethod,
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }

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

    // MARK: Hero

    private func heroCard(_ item: ItemPriceLine) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.hasTrend ? "Dernier prix" : "Prix moyen")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)

                Text(ItemPricesText.detailHeadline(item))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(ItemPricesText.detailSummary(item))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                heroChip(title: "Prix moyen", value: ItemPricesText.averageText(item))
                heroChip(title: "Le plus bas", value: ItemPricesText.money(item.lowestPrice))
                heroChip(title: "Le plus haut", value: ItemPricesText.money(item.highestPrice))
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

    // MARK: Curve

    private func curveCard(_ detail: ItemPriceDetail) -> some View {
        DashboardSectionCard(title: ItemPricesText.historyTitle) {
            VStack(spacing: 8) {
                ItemPriceCurve(points: detail.points, tint: tint(detail.item.level))

                HStack {
                    if let first = detail.points.first {
                        Text(ItemPricesText.dateText(first.date))
                    }

                    Spacer()

                    if let last = detail.points.last {
                        Text(ItemPricesText.dateText(last.date))
                    }
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textTertiary)
                .accessibilityHidden(true)
            }
            .padding(16)
        }
    }

    // MARK: Shops

    private func shopsCard(_ detail: ItemPriceDetail) -> some View {
        let cheapest = detail.merchants.first?.averagePrice

        return VStack(spacing: 8) {
            DashboardSectionCard(title: ItemPricesText.shopsTitle + " · \(detail.merchantTotal)") {
                ForEach(Array(detail.merchants.enumerated()), id: \.element.id) { index, shop in
                    if index > 0 {
                        DashboardDivider()
                    }

                    shopRow(shop, cheapestPrice: cheapest)
                }
            }

            if detail.hiddenShopCount > 0 {
                footnote(ItemPricesText.hiddenShopsNote(hidden: detail.hiddenShopCount, shown: detail.merchants.count))
            }
        }
    }

    private func shopRow(_ shop: ItemPriceShop, cheapestPrice: Double?) -> some View {
        HStack(alignment: .center, spacing: 14) {
            DashboardIconBox(
                icon: shop.cheapest ? "checkmark.seal.fill" : "storefront.fill",
                tint: shop.cheapest ? EconomofarUI.success : EconomofarUI.accent
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(shop.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(2)

                Text(ItemPricesText.shopDetail(shop, cheapestPrice: cheapestPrice))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if shop.cheapest {
                    Text("Le moins cher")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.success)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(ItemPricesText.money(shop.averagePrice))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    // MARK: Days

    private func pointsCard(_ detail: ItemPriceDetail) -> some View {
        VStack(spacing: 8) {
            DashboardSectionCard(title: ItemPricesText.pointsTitle) {
                ForEach(Array(detail.points.reversed().enumerated()), id: \.element.id) { index, point in
                    if index > 0 {
                        DashboardDivider()
                    }

                    pointRow(point)
                }
            }

            if detail.hiddenPointCount > 0 {
                footnote(ItemPricesText.hiddenPointsNote(hidden: detail.hiddenPointCount, shown: detail.points.count))
            }
        }
    }

    private func pointRow(_ point: ItemPricePoint) -> some View {
        HStack(alignment: .center, spacing: 14) {
            DashboardIconBox(icon: "calendar", tint: EconomofarUI.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(ItemPricesText.dateText(point.date))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Text(ItemPricesText.pointShop(point) + " · " + ItemPricesText.quantityText(point.quantity))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(ItemPricesText.money(point.price))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
