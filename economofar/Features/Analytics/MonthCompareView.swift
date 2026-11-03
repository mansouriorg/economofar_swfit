import SwiftUI
import Combine

// MARK: - View model

struct MonthOption: Identifiable {
    let key: String
    let title: String

    var id: String { key }
}

@MainActor
final class MonthCompareViewModel: ObservableObject {
    static let monthCount = 12

    let options: [MonthOption]

    @Published var result: MonthCompare? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published private(set) var loadedMonth: String? = nil

    /// Choosing another month shows the spinner at once, before the request starts.
    @Published var month: String {
        didSet {
            if month != oldValue {
                isLoading = true
            }
        }
    }

    private var generation = 0
    private var loadedAt: Date? = nil

    init() {
        let keys = MonthCompareText.monthKeys(count: MonthCompareViewModel.monthCount)

        options = keys.map { MonthOption(key: $0, title: MonthCompareText.monthTitle($0)) }
        month = keys[0]
    }

    func load(token: String?) async {
        guard let token, !token.isEmpty else {
            isLoading = false
            return
        }

        generation += 1
        let current = generation
        let selected = month

        // The month in progress is left to the server, whose clock decides what today is
        let requested: String? = selected == options.first?.key ? nil : selected

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await MonthCompareService.shared.fetch(token: token, month: requested)

            if current == generation {
                result = fetched
                loadedMonth = selected
                loadedAt = Date()
            }
        } catch APIError.unauthorized {
            // The session manager logs the user out
        } catch {
            if current == generation, !Task.isCancelled {
                errorMessage = error.localizedDescription

                // Figures of an earlier day must not be shown as the current ones
                if let loadedAt, !Calendar.current.isDateInToday(loadedAt) {
                    result = nil
                    loadedMonth = nil
                    self.loadedAt = nil
                }
            }
        }

        if current == generation {
            isLoading = false
        }
    }
}

// MARK: - Curve

private struct CurveShape: Shape {
    let values: [Double]
    let maxValue: Double
    let slots: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()

        guard !values.isEmpty, maxValue > 0, slots > 1 else {
            return path
        }

        for (index, value) in values.enumerated() {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(slots - 1)
            let y = rect.maxY - rect.height * CGFloat(value / maxValue)
            let point = CGPoint(x: x, y: y)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}

// MARK: - Screen

struct MonthCompareView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = MonthCompareViewModel()

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

                    monthPicker

                    if let result = viewModel.result, viewModel.loadedMonth == viewModel.month {
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
        .navigationTitle("Mois contre mois")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(token: sessionManager.token)
        }
        .onChange(of: viewModel.month) { _ in
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }
    }

    // MARK: Controls

    private var monthPicker: some View {
        HStack {
            Text("Mois")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            Spacer()

            Picker("Mois", selection: $viewModel.month) {
                ForEach(viewModel.options) { option in
                    Text(option.title).tag(option.key)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(EconomofarUI.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
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
    private func content(_ result: MonthCompare) -> some View {
        heroCard(result)

        if result.hasTickets {
            curveCard(result)

            if highlightedCategories(result).isEmpty == false {
                highlightsCard(result)
            }

            if result.categories.isEmpty == false {
                categoriesCard(result)
            }

            methodBanner(result)
        } else {
            DashboardInfoBanner(
                icon: "info.circle.fill",
                message: result.partial ? "Aucun ticket enregistré sur ces deux périodes." : "Aucun ticket enregistré sur ces deux mois.",
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }
    }

    // MARK: Hero

    private func heroCard(_ result: MonthCompare) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(MonthCompareText.periodText(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))

                Text(AppFormat.money(result.currentTotal))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(MonthCompareText.againstText(result))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                deltaBadge(result)
                    .padding(.top, 2)

                Text(MonthCompareText.summary(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                heroChip(title: "Tickets", value: "\(result.currentTickets)")
                heroChip(title: "Panier moyen", value: result.currentAverage.map { AppFormat.money($0) } ?? "-")
                heroChip(
                    title: result.partial ? "Mois préc. entier" : "Tickets mois préc.",
                    value: result.partial ? AppFormat.money(result.previousFullTotal) : "\(result.previousTickets)"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func deltaBadge(_ result: MonthCompare) -> some View {
        let stable = MonthCompareText.isStable(result)
        let icon = stable ? "equal" : (result.delta > 0 ? "arrow.up.right" : "arrow.down.right")

        var text = WeeklyDigestText.signedMoney(result.delta)

        if let percent = result.deltaPercent {
            text += " · " + MonthCompareText.percentText(percent)
        }

        return HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))

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
    }

    // MARK: Curve

    private func curveCard(_ result: MonthCompare) -> some View {
        let currentValues = result.points.compactMap { $0.current }
        let previousValues = result.points.compactMap { $0.previous }
        let maxValue = max(currentValues.max() ?? 0, previousValues.max() ?? 0)
        let slots = result.points.count

        return DashboardSectionCard(title: "Cumul jour par jour") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    legendItem(
                        color: EconomofarUI.accent,
                        title: MonthCompareText.capitalized(MonthCompareText.monthName(result.month)),
                        dashed: false
                    )

                    legendItem(
                        color: EconomofarUI.textTertiary,
                        title: MonthCompareText.capitalized(MonthCompareText.monthName(result.previousMonth)) + (result.partial ? " (entier)" : ""),
                        dashed: true
                    )

                    Spacer()

                    Text("Jusqu'à \(AppFormat.money(maxValue))")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textTertiary)
                        .lineLimit(1)
                }

                if maxValue > 0 {
                    GeometryReader { proxy in
                        ZStack(alignment: .bottom) {
                            Rectangle()
                                .fill(EconomofarUI.border)
                                .frame(height: 1)

                            CurveShape(values: previousValues, maxValue: maxValue, slots: slots)
                                .stroke(
                                    EconomofarUI.textTertiary,
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [5, 4])
                                )

                            CurveShape(values: currentValues, maxValue: maxValue, slots: slots)
                                .stroke(
                                    EconomofarUI.accent,
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                                )

                            if let last = currentValues.last, slots > 1 {
                                Circle()
                                    .fill(EconomofarUI.accent)
                                    .frame(width: 10, height: 10)
                                    .position(
                                        x: proxy.size.width * CGFloat(currentValues.count - 1) / CGFloat(slots - 1),
                                        y: proxy.size.height * CGFloat(1 - last / maxValue)
                                    )
                            }
                        }
                    }
                    .frame(height: 150)

                    HStack {
                        Text("1")

                        Spacer()

                        Text("\(slots)")
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
                } else {
                    Text("Aucune dépense sur ces deux mois.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }
            }
            .padding(16)
        }
    }

    private func legendItem(color: Color, title: String, dashed: Bool) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(color)
                .frame(width: dashed ? 12 : 16, height: dashed ? 3 : 4)
                .opacity(dashed ? 0.7 : 1)

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .lineLimit(1)
        }
    }

    // MARK: Highlights

    private func realCategories(_ result: MonthCompare) -> [MonthCompareCategory] {
        result.categories.filter { $0.name != MonthCompareText.mergedName }
    }

    private func biggestRise(_ result: MonthCompare) -> MonthCompareCategory? {
        realCategories(result)
            .filter { $0.delta > 0 }
            .max { $0.delta < $1.delta }
    }

    private func biggestDrop(_ result: MonthCompare) -> MonthCompareCategory? {
        realCategories(result)
            .filter { $0.delta < 0 }
            .min { $0.delta < $1.delta }
    }

    private func highlightedCategories(_ result: MonthCompare) -> [MonthCompareCategory] {
        [biggestRise(result), biggestDrop(result)].compactMap { $0 }
    }

    private func highlightsCard(_ result: MonthCompare) -> some View {
        let rise = biggestRise(result)
        let drop = biggestDrop(result)

        return DashboardSectionCard(title: "À retenir") {
            if let rise {
                DashboardInsightRow(
                    icon: "arrow.up.right.circle.fill",
                    title: "\(rise.name) augmente le plus",
                    subtitle: "\(AppFormat.money(rise.previous)) puis \(AppFormat.money(rise.current))",
                    value: WeeklyDigestText.signedMoney(rise.delta),
                    tint: EconomofarUI.warning
                )
            }

            if rise != nil, drop != nil {
                DashboardDivider()
            }

            if let drop {
                DashboardInsightRow(
                    icon: "arrow.down.right.circle.fill",
                    title: "\(drop.name) baisse le plus",
                    subtitle: "\(AppFormat.money(drop.previous)) puis \(AppFormat.money(drop.current))",
                    value: WeeklyDigestText.signedMoney(drop.delta),
                    tint: EconomofarUI.success
                )
            }
        }
    }

    // MARK: Categories

    private func categoryTint(_ category: MonthCompareCategory) -> Color {
        if category.delta > 0.005 {
            return EconomofarUI.warning
        }

        if category.delta < -0.005 {
            return EconomofarUI.success
        }

        return EconomofarUI.textSecondary
    }

    private func categoriesCard(_ result: MonthCompare) -> some View {
        let maxValue = result.categories
            .map { max($0.current, $0.previous) }
            .max() ?? 0

        let currentName = MonthCompareText.capitalized(MonthCompareText.monthName(result.month))
        let previousName = MonthCompareText.capitalized(MonthCompareText.monthName(result.previousMonth))

        return DashboardSectionCard(title: "Par catégorie") {
            ForEach(Array(result.categories.enumerated()), id: \.offset) { index, category in
                if index > 0 {
                    Divider()
                        .background(EconomofarUI.border)
                        .padding(.leading, 16)
                }

                categoryRow(category, currentName: currentName, previousName: previousName, maxValue: maxValue)
            }
        }
    }

    private func categoryRow(_ category: MonthCompareCategory, currentName: String, previousName: String, maxValue: Double) -> some View {
        let tint = categoryTint(category)
        let currentFraction = maxValue > 0 ? category.current / maxValue : 0
        let previousFraction = maxValue > 0 ? category.previous / maxValue : 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(category.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(WeeklyDigestText.signedMoney(category.delta))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(MonthCompareText.categoryPercent(category))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(tint)
                        .lineLimit(1)
                }
            }

            barTrack(fraction: currentFraction, tint: EconomofarUI.accent)

            barTrack(fraction: previousFraction, tint: EconomofarUI.textTertiary.opacity(0.6))

            Text("\(currentName) \(AppFormat.money(category.current)) · \(previousName) \(AppFormat.money(category.previous))")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func barTrack(fraction: Double, tint: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(EconomofarUI.cardSoft)

                Capsule()
                    .fill(tint)
                    .frame(width: max(fraction > 0 ? 6 : 0, proxy.size.width * CGFloat(fraction)))
            }
        }
        .frame(height: 7)
    }

    // MARK: Method

    private func methodBanner(_ result: MonthCompare) -> some View {
        let name = MonthCompareText.monthName(result.previousMonth)
        let capitalized = MonthCompareText.capitalized(name)
        let ofName = MonthCompareText.ofMonth(name)

        let window = result.previousDays <= 1
            ? "seul le 1er jour \(ofName) est pris en compte"
            : "seuls les \(result.previousDays) premiers jours \(ofName) sont pris en compte"

        let message = result.partial
            ? "Le mois en cours est comparé jour pour jour : \(window), pour une comparaison juste. \(capitalized) entier : \(AppFormat.money(result.previousFullTotal)). Seuls les tickets enregistrés sont comptés."
            : "Les deux mois sont comparés en entier. Seuls les tickets enregistrés sont comptés ; une catégorie vide compte comme « Autre »."

        return DashboardInfoBanner(
            icon: "info.circle.fill",
            message: message,
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }
}
