import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class SpendingRhythmViewModel: ObservableObject {
    static let periods = [4, 8, 13, 26]

    @Published var result: SpendingRhythm? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var weeks = 13

    private var generation = 0
    private var loadedAt: Date? = nil

    func load(token: String?) async {
        guard let token, !token.isEmpty else { return }

        generation += 1
        let current = generation

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await SpendingRhythmService.shared.fetch(token: token, weeks: weeks)

            if current == generation {
                result = fetched
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

struct SpendingRhythmView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = SpendingRhythmViewModel()

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

                    if let result = viewModel.result, result.weeks == viewModel.weeks {
                        content(result)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 50)
                    } else if viewModel.errorMessage != nil {
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
        .navigationTitle("Rythme des dépenses")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(token: sessionManager.token)
        }
        .onChange(of: viewModel.weeks) { _ in
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }
    }

    // MARK: Controls

    private var periodPicker: some View {
        Picker("Période", selection: $viewModel.weeks) {
            ForEach(SpendingRhythmViewModel.periods, id: \.self) { weeks in
                Text(RhythmText.periodTitle(weeks)).tag(weeks)
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
    private func content(_ result: SpendingRhythm) -> some View {
        heroCard(result)

        if result.hasData {
            profileSection(result)

            streakCard(result)

            biggestDayCard(result)

            methodBanner(result)
        } else {
            DashboardInfoBanner(
                icon: "info.circle.fill",
                message: "Aucun achat enregistré sur cette période.",
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }
    }

    @ViewBuilder
    private func profileSection(_ result: SpendingRhythm) -> some View {
        if result.enoughHistory {
            weekdaysCard(result)

            weekendCard(result)

            monthPartsCard(result)
        } else {
            DashboardInfoBanner(
                icon: "clock.fill",
                message: "Pas encore assez d'historique pour comparer les jours : il faut au moins 14 jours depuis votre premier achat enregistré.",
                tint: EconomofarUI.warning,
                background: EconomofarUI.warningSoft
            )
            .padding(.horizontal, -20)
        }
    }

    // MARK: Hero

    private func heroCard(_ result: SpendingRhythm) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Votre rythme")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))

                Text(headline(result))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Text(result.periodText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
            }

            HStack(spacing: 10) {
                heroChip(title: "Dépensé", value: AppFormat.money(result.total))
                heroChip(title: "Par jour", value: AppFormat.money(result.dailyAverage))
                heroChip(title: "Jours sans achat", value: "\(result.noPurchaseDays)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func headline(_ result: SpendingRhythm) -> String {
        guard result.hasData else {
            return "Aucun achat"
        }

        guard result.enoughHistory else {
            return "Pas encore de comparaison"
        }

        if let busiest = result.busiestDay, result.peakRatio >= RhythmText.pronouncedPeak {
            return "Le \(RhythmText.weekday(busiest)) est votre jour fort"
        }

        return "Des dépenses bien réparties"
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

    // MARK: Days of the week

    private func weekdaysCard(_ result: SpendingRhythm) -> some View {
        let maxAverage = result.maxWeekdayAverage
        let strong = result.peakRatio >= RhythmText.pronouncedPeak

        return DashboardSectionCard(title: "Par jour de la semaine") {
            Text("Montant moyen dépensé chaque jour de la semaine, jours sans achat compris.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            ForEach(Array(result.weekdays.enumerated()), id: \.element.id) { index, weekday in
                if index > 0 {
                    Divider()
                        .background(EconomofarUI.border)
                        .padding(.leading, 16)
                }

                weekdayRow(
                    weekday,
                    maxAverage: maxAverage,
                    highlight: strong && weekday.dayOfWeek == result.busiestDay
                )
            }
        }
    }

    private func weekdayRow(_ weekday: WeekdayRhythm, maxAverage: Double, highlight: Bool) -> some View {
        let fraction = maxAverage > 0 ? min(max(weekday.average / maxAverage, 0), 1) : 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(RhythmText.capitalized(RhythmText.weekday(weekday.dayOfWeek)))
                    .font(.system(size: 15, weight: highlight ? .bold : .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Spacer()

                Text(AppFormat.money(weekday.average))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(highlight ? EconomofarUI.warning : EconomofarUI.textPrimary)
            }

            barTrack(fraction: fraction, tint: highlight ? EconomofarUI.warning : EconomofarUI.accent)

            Text("\(WeeklyDigestText.percent(weekday.share)) % des dépenses · \(RhythmText.visits(weekday))")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(RhythmText.capitalized(RhythmText.weekday(weekday.dayOfWeek))) : \(AppFormat.money(weekday.average)) en moyenne, \(WeeklyDigestText.percent(weekday.share)) % des dépenses, \(RhythmText.visits(weekday))")
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
        .frame(height: 8)
    }

    // MARK: Week and weekend

    private func weekendCard(_ result: SpendingRhythm) -> some View {
        let weekendIsHigher = result.weekendDailyAverage > result.weekdayDailyAverage
        let weekdayIsHigher = result.weekdayDailyAverage > result.weekendDailyAverage

        return DashboardSectionCard(title: "Semaine et week-end") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    metricTile(
                        title: "En semaine, par jour",
                        value: AppFormat.money(result.weekdayDailyAverage),
                        tint: weekdayIsHigher ? EconomofarUI.warning : EconomofarUI.accent
                    )

                    metricTile(
                        title: "Le week-end, par jour",
                        value: AppFormat.money(result.weekendDailyAverage),
                        tint: weekendIsHigher ? EconomofarUI.warning : EconomofarUI.accent
                    )
                }

                Text("Le week-end représente \(WeeklyDigestText.percent(result.weekendShare)) % de vos dépenses (2 jours sur 7).")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
    }

    private func metricTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(EconomofarUI.cardSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Parts of the month

    private func monthPartsCard(_ result: SpendingRhythm) -> some View {
        let maxAverage = result.maxPartAverage

        return DashboardSectionCard(title: "Dans le mois") {
            ForEach(Array(result.monthParts.filter { $0.days > 0 }.enumerated()), id: \.element.id) { index, part in
                if index > 0 {
                    Divider()
                        .background(EconomofarUI.border)
                        .padding(.leading, 16)
                }

                monthPartRow(part, maxAverage: maxAverage)
            }
        }
    }

    private func monthPartRow(_ part: MonthPartRhythm, maxAverage: Double) -> some View {
        let fraction = maxAverage > 0 ? min(max(part.dailyAverage / maxAverage, 0), 1) : 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(RhythmText.partTitle(part.key))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Spacer()

                Text("\(AppFormat.money(part.dailyAverage)) par jour")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            barTrack(fraction: fraction, tint: EconomofarUI.accent)

            Text("\(RhythmText.partRange(part.key)) · \(WeeklyDigestText.percent(part.share)) % des dépenses")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(RhythmText.partTitle(part.key)) : \(AppFormat.money(part.dailyAverage)) par jour, \(WeeklyDigestText.percent(part.share)) % des dépenses")
    }

    // MARK: Days without purchase

    private func streakCard(_ result: SpendingRhythm) -> some View {
        DashboardSectionCard(title: "Jours sans achat") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    metricTile(
                        title: "Série en cours (aujourd'hui compris)",
                        value: RhythmText.dayCount(result.currentStreak),
                        tint: result.currentStreak > 0 ? EconomofarUI.success : EconomofarUI.textPrimary
                    )

                    metricTile(
                        title: "Record de la période",
                        value: RhythmText.dayCount(result.longestStreak),
                        tint: EconomofarUI.accent
                    )
                }

                Text("\(RhythmText.dayCount(result.noPurchaseDays)) sans achat enregistré, sur \(RhythmText.dayCount(result.trackedDays)) de suivi. Seuls les tickets enregistrés dans l'application sont comptés.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
    }

    // MARK: Biggest day

    @ViewBuilder
    private func biggestDayCard(_ result: SpendingRhythm) -> some View {
        if let date = result.biggestDayDate, let amount = result.biggestDayAmount {
            DashboardSectionCard(title: "Jour le plus cher") {
                DashboardInsightRow(
                    icon: "flame.fill",
                    title: RhythmText.capitalized(WeeklyDigestText.format(date, pattern: "EEEE d MMMM yyyy")),
                    subtitle: "Tous les achats de ce jour",
                    value: AppFormat.money(amount),
                    tint: EconomofarUI.warning
                )
            }
        }
    }

    // MARK: Method

    private func methodBanner(_ result: SpendingRhythm) -> some View {
        DashboardInfoBanner(
            icon: "info.circle.fill",
            message: methodText(result),
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }

    private func methodText(_ result: SpendingRhythm) -> String {
        let base = "Les moyennes comptent chaque jour, y compris ceux sans achat."

        if result.startsLater {
            return "\(base) Les chiffres partent de votre premier achat enregistré, le \(WeeklyDigestText.format(result.trackedFrom ?? result.from, pattern: "d MMMM yyyy"))."
        }

        return base
    }
}
