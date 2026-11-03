import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class PriceTrackerViewModel: ObservableObject {
    @Published var items: [PriceTrend] = []
    @Published var risingCount: Int = 0
    @Published var fallingCount: Int = 0
    @Published var stableCount: Int = 0
    @Published var isLoading = false
    @Published var hasLoaded = false
    @Published var errorMessage: String? = nil

    func load(token: String?) async {
        guard let token, !token.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await PriceTrackerService.shared.fetch(token: token)
            items = response.items
            risingCount = response.risingCount
            fallingCount = response.fallingCount
            stableCount = response.stableCount
            hasLoaded = true
        } catch APIError.unauthorized {
            // The session manager logs the user out
        } catch {
            if !Task.isCancelled && (error as? URLError)?.code != .cancelled {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}

// MARK: - Filter

enum PriceFilter: String, CaseIterable, Identifiable {
    case all
    case rising
    case falling

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Tous"
        case .rising:
            return "Hausses"
        case .falling:
            return "Baisses"
        }
    }
}

// MARK: - Screen

struct PriceTrackerView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = PriceTrackerViewModel()
    @State private var filter: PriceFilter = .all
    @State private var searchText = ""
    @State private var expandedID: String? = nil

    private var visibleItems: [PriceTrend] {
        var list = viewModel.items

        switch filter {
        case .all:
            break
        case .rising:
            list = list.filter { $0.isUp }.sorted { $0.changePercent > $1.changePercent }
        case .falling:
            list = list.filter { $0.isDown }.sorted { $0.changePercent < $1.changePercent }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            list = list.filter {
                $0.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }

        return list
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

                    if viewModel.items.isEmpty {
                        if viewModel.hasLoaded {
                            emptyState
                        } else if viewModel.isLoading {
                            ProgressView()
                                .padding(.top, 50)
                        }
                    } else {
                        summaryCard

                        filterPicker

                        if visibleItems.isEmpty {
                            noResultText
                        } else {
                            ForEach(visibleItems) { item in
                                trendCard(item)
                            }
                        }

                        Text("Prix unitaires relevés sur les articles de vos tickets des 12 derniers mois. Une variation de moins de 3 % est considérée comme stable.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
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
        .navigationTitle("Suivi des prix")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Rechercher un article")
        .task {
            await viewModel.load(token: sessionManager.token)
        }
    }

    // MARK: Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Articles suivis")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))

                Text("\(viewModel.items.count)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            HStack(spacing: 10) {
                summaryChip(icon: "arrow.up.right", count: viewModel.risingCount, label: "en hausse")
                summaryChip(icon: "arrow.down.right", count: viewModel.fallingCount, label: "en baisse")
                summaryChip(icon: "equal", count: viewModel.stableCount, label: "stables")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func summaryChip(icon: String, count: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))

                Text("\(count)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .opacity(0.85)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var filterPicker: some View {
        Picker("Filtre", selection: $filter) {
            ForEach(PriceFilter.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: Cards

    private func trendColor(_ item: PriceTrend) -> Color {
        if item.isUp {
            return EconomofarUI.danger
        }

        if item.isDown {
            return EconomofarUI.success
        }

        return EconomofarUI.textSecondary
    }

    private func trendSoftColor(_ item: PriceTrend) -> Color {
        if item.isUp {
            return EconomofarUI.dangerSoft
        }

        if item.isDown {
            return EconomofarUI.successSoft
        }

        return EconomofarUI.cardSoft
    }

    private func trendCard(_ item: PriceTrend) -> some View {
        let isExpanded = expandedID == item.id

        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedID = isExpanded ? nil : item.id
                }
            } label: {
                cardHeader(item)
            }
            .buttonStyle(.plain)

            if isExpanded {
                cardDetails(item)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }

    private func cardHeader(_ item: PriceTrend) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(item.subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 5) {
                    Text(AppFormat.money(item.lastPrice))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    changeBadge(item)
                }
            }

            if item.sparklineValues.count >= 2 {
                PriceSparkline(values: item.sparklineValues, color: trendColor(item))
                    .frame(height: 36)
            }

            if let merchant = item.cheaperMerchant, let price = item.cheaperPrice {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12, weight: .semibold))

                    Text("Moins cher chez \(merchant) : \(AppFormat.money(price))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.leading)
                }
                .foregroundColor(EconomofarUI.success)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(EconomofarUI.successSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .contentShape(Rectangle())
    }

    private func changeBadge(_ item: PriceTrend) -> some View {
        HStack(spacing: 3) {
            if !(item.trend == "stable") {
                Image(systemName: item.isUp ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
            }

            Text(item.changeText)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundColor(trendColor(item))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(trendSoftColor(item))
        .clipShape(Capsule())
    }

    private func cardDetails(_ item: PriceTrend) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(EconomofarUI.border)
                .frame(height: 1)

            HStack(spacing: 10) {
                statBox(title: "Plus bas", value: item.minPrice)
                statBox(title: "Moyen", value: item.averagePrice)
                statBox(title: "Plus haut", value: item.maxPrice)
            }

            Text("Achat précédent : \(AppFormat.money(item.previousPrice))  ·  \(item.periodText)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            VStack(spacing: 0) {
                ForEach(Array(item.history.reversed())) { point in
                    HStack(spacing: 8) {
                        Text(point.dateText)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)

                        Spacer()

                        if let merchant = point.merchantName, !merchant.isEmpty {
                            Text(merchant)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(EconomofarUI.textTertiary)
                                .lineLimit(1)
                        }

                        Text(AppFormat.money(point.price))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func statBox(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            Text(AppFormat.money(value))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(EconomofarUI.cardSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Empty states

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(EconomofarUI.accent)

            Text("Pas encore de prix à suivre")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text("Dès qu'un même article aura été acheté à deux dates différentes, son évolution de prix apparaîtra ici. Gardez les lignes d'articles lorsque vous validez un ticket.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
        .padding(.horizontal, 12)
    }

    private var noResultText: some View {
        Text("Aucun article ne correspond.")
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(EconomofarUI.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 30)
    }
}

// MARK: - Sparkline

struct PriceSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let points = makePoints(in: proxy.size)

            ZStack {
                Path { path in
                    guard let first = points.first else { return }

                    path.move(to: first)

                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                if let last = points.last {
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .position(last)
                }
            }
        }
    }

    private func makePoints(in size: CGSize) -> [CGPoint] {
        guard values.count >= 2 else { return [] }

        let low = values.min() ?? 0
        let high = values.max() ?? 0
        let span = high - low
        let inset: CGFloat = 4
        let width = max(size.width - inset * 2, 1)
        let height = max(size.height - inset * 2, 1)

        return values.enumerated().map { index, value in
            let x = inset + width * CGFloat(index) / CGFloat(values.count - 1)
            let ratio: CGFloat = span > 0 ? CGFloat((value - low) / span) : 0.5
            let y = inset + height * (1 - ratio)

            return CGPoint(x: x, y: y)
        }
    }
}
