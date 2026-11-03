import SwiftUI
import Combine

// MARK: - View model

struct YearOption: Identifiable {
    let year: Int
    let title: String

    var id: Int { year }
}

@MainActor
final class YearReviewViewModel: ObservableObject {
    static let yearCount = 6

    let options: [YearOption]

    @Published var result: YearReview? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published private(set) var loadedYear: Int? = nil

    /// Choosing another year shows the spinner at once, before the request starts.
    @Published var year: Int {
        didSet {
            if year != oldValue {
                isLoading = true
            }
        }
    }

    private var generation = 0
    private var loadedAt: Date? = nil

    init() {
        let years = YearReviewText.yearKeys(count: YearReviewViewModel.yearCount)

        options = years.map { YearOption(year: $0, title: String($0)) }
        year = years[0]
    }

    func load(token: String?) async {
        guard let token, !token.isEmpty else {
            isLoading = false
            return
        }

        generation += 1
        let current = generation
        let selected = year

        // The year in progress is left to the server, whose clock decides what today is
        let requested: Int? = selected == options.first?.year ? nil : selected

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await YearReviewService.shared.fetch(token: token, year: requested)

            if current == generation {
                result = fetched
                loadedYear = selected
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
                    loadedYear = nil
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

struct YearReviewView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = YearReviewViewModel()

    private let barHeight: CGFloat = 110

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

                    yearPicker

                    if let result = viewModel.result, viewModel.loadedYear == viewModel.year {
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
        .navigationTitle("Bilan de l'année")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(token: sessionManager.token)
        }
        .onChange(of: viewModel.year) { _ in
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }
    }

    // MARK: Controls

    private var yearPicker: some View {
        HStack {
            Text("Année")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .accessibilityHidden(true)

            Spacer()

            Picker("Année", selection: $viewModel.year) {
                ForEach(viewModel.options) { option in
                    Text(option.title).tag(option.year)
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
    private func content(_ result: YearReview) -> some View {
        heroCard(result)

        if result.hasTickets {
            if result.tickets > 0 {
                monthsCard(result)
            }

            if result.categories.isEmpty == false {
                categoriesCard(result)
            }

            if result.merchants.isEmpty == false {
                merchantsCard(result)
            }

            if let biggest = result.biggestTicket {
                biggestCard(biggest)
            }

            methodBanner(result)
        } else {
            DashboardInfoBanner(
                icon: "info.circle.fill",
                message: "Aucun ticket enregistré en \(result.year) ni en \(result.year - 1).",
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }
    }

    // MARK: Hero

    private func heroCard(_ result: YearReview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(YearReviewText.periodText(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))

                Text(AppFormat.money(result.total))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(YearReviewText.againstText(result))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                deltaBadge(result)
                    .padding(.top, 2)

                Text(YearReviewText.summary(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                heroChip(title: "Tickets", value: "\(result.tickets)")
                heroChip(title: "Panier moyen", value: result.averageTicket.map { AppFormat.money($0) } ?? "-")
                heroChip(title: "Moy. par mois", value: result.monthlyAverage.map { AppFormat.money($0) } ?? "-")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func deltaBadge(_ result: YearReview) -> some View {
        let stable = YearReviewText.isStable(result)
        let icon = stable ? "equal" : (result.delta > 0 ? "arrow.up.right" : "arrow.down.right")

        var text = WeeklyDigestText.signedMoney(result.delta)

        if let percent = result.deltaPercent {
            text += " · " + YearReviewText.percentText(percent)
        }

        return HStack(spacing: 6) {
            Image(systemName: icon)
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
    }

    // MARK: Months

    private func barColor(_ item: YearReviewMonth, in result: YearReview) -> Color {
        if result.partial && item.month > result.monthsElapsed {
            return EconomofarUI.cardSoft
        }

        if item.month == result.busiestMonth {
            return EconomofarUI.warning
        }

        if result.partial && item.month == result.monthsElapsed {
            return EconomofarUI.accent.opacity(0.5)
        }

        return EconomofarUI.accent
    }

    private func monthBar(_ item: YearReviewMonth, in result: YearReview, maxValue: Double) -> some View {
        let future = result.partial && item.month > result.monthsElapsed
        let fraction = maxValue > 0 ? item.total / maxValue : 0
        let height = max(item.total > 0 ? 6 : 3, barHeight * CGFloat(fraction))

        return VStack(spacing: 6) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Capsule()
                    .fill(barColor(item, in: result))
                    .frame(maxWidth: 18)
                    .frame(height: height)
            }
            .frame(height: barHeight)

            Text(YearReviewText.monthInitial(item.month))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(future ? EconomofarUI.textTertiary.opacity(0.6) : EconomofarUI.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(YearReviewText.monthAccessibility(item, in: result)))
    }

    private func monthsCard(_ result: YearReview) -> some View {
        let maxValue = result.months.map { $0.total }.max() ?? 0

        return DashboardSectionCard(title: "Mois par mois") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(result.months) { item in
                        monthBar(item, in: result, maxValue: maxValue)
                    }
                }

                if let average = YearReviewText.averageText(result) {
                    Text(average)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if result.partial {
                    Text("Le mois en cours, en plus clair, n'est pas terminé : il ne compte pas dans la moyenne.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)

            if let busiest = result.busiestMonth, let item = result.month(busiest) {
                DashboardDivider()

                DashboardInsightRow(
                    icon: "flame.fill",
                    title: "Mois le plus dépensier",
                    subtitle: "\(YearReviewText.capitalized(YearReviewText.monthName(busiest))) · \(YearReviewText.ticketCount(item.tickets))",
                    value: AppFormat.money(item.total),
                    tint: EconomofarUI.warning
                )
            }

            if let quietest = result.quietestMonth, quietest != result.busiestMonth, let item = result.month(quietest) {
                DashboardDivider()

                DashboardInsightRow(
                    icon: "leaf.fill",
                    title: "Mois le plus calme",
                    subtitle: "\(YearReviewText.capitalized(YearReviewText.monthName(quietest))) · \(YearReviewText.ticketCount(item.tickets))",
                    value: AppFormat.money(item.total),
                    tint: EconomofarUI.success
                )
            }
        }
    }

    // MARK: Categories

    private func categoriesCard(_ result: YearReview) -> some View {
        DashboardSectionCard(title: "Par catégorie") {
            ForEach(Array(result.categories.enumerated()), id: \.offset) { index, category in
                if index > 0 {
                    Divider()
                        .background(EconomofarUI.border)
                        .padding(.leading, 16)
                }

                categoryRow(category)
            }
        }
    }

    private func categoryRow(_ category: YearReviewCategory) -> some View {
        let merged = category.name == YearReviewText.mergedName
        let fraction = min(max(category.share / 100, 0), 1)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(category.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                Text(AppFormat.money(category.total))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: 10) {
                barTrack(fraction: fraction, tint: merged ? EconomofarUI.textTertiary.opacity(0.6) : EconomofarUI.accent)

                Text(YearReviewText.shareText(category.share))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .frame(minWidth: 48, alignment: .trailing)
                    .lineLimit(1)
            }
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

    // MARK: Shops

    private func merchantsCard(_ result: YearReview) -> some View {
        DashboardSectionCard(title: "Où vous dépensez le plus") {
            ForEach(Array(result.merchants.enumerated()), id: \.offset) { index, merchant in
                if index > 0 {
                    DashboardDivider()
                }

                DashboardInsightRow(
                    icon: "\(min(index + 1, 9)).circle.fill",
                    title: merchant.name,
                    subtitle: YearReviewText.ticketCount(merchant.tickets),
                    value: AppFormat.money(merchant.total),
                    tint: EconomofarUI.accent
                )
            }

            if result.merchantCount > result.merchants.count {
                Text(YearReviewText.moreShops(result.merchantCount - result.merchants.count))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
        }
    }

    // MARK: Biggest ticket

    private func biggestCard(_ ticket: YearReviewTicket) -> some View {
        DashboardSectionCard(title: "Plus gros ticket") {
            if let id = ticket.id {
                NavigationLink {
                    ReceiptDetailView(receiptId: id)
                } label: {
                    biggestRow(ticket, tappable: true)
                }
                .buttonStyle(.plain)
            } else {
                biggestRow(ticket, tappable: false)
            }
        }
    }

    private func biggestRow(_ ticket: YearReviewTicket, tappable: Bool) -> some View {
        let dateText = WeeklyDigestText.format(ticket.date, pattern: "d MMM yyyy")

        return HStack(spacing: 14) {
            DashboardIconBox(icon: "star.circle.fill", tint: EconomofarUI.warning)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(ticket.merchant)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Text(AppFormat.money(ticket.amount))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.warning)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Text("\(ticket.category) · \(dateText)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .lineLimit(2)
            }

            if tappable {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    // MARK: Method

    private func methodBanner(_ result: YearReview) -> some View {
        let last = result.year - 1

        let message = result.partial
            ? "L'année en cours est comparée à la même période de \(last) : \(AppFormat.money(result.previousTotal)), pour une comparaison juste. \(last) entière : \(AppFormat.money(result.previousFullTotal)). Seuls les tickets enregistrés sont comptés."
            : "Les deux années sont comparées en entier. Seuls les tickets enregistrés sont comptés ; une catégorie vide compte comme « Autre » et les commerces inconnus ne sont pas classés."

        return DashboardInfoBanner(
            icon: "info.circle.fill",
            message: message,
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }
}
