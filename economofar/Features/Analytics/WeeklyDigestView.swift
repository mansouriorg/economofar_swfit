import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class WeeklyDigestViewModel: ObservableObject {
    @Published var digest: WeeklyDigest? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private var generation = 0
    private var loadedAt: Date? = nil

    func load(token: String?) async {
        guard let token, !token.isEmpty else { return }

        generation += 1
        let current = generation

        isLoading = true
        errorMessage = nil

        do {
            let result = try await WeeklyDigestService.shared.fetch(token: token)

            if current == generation {
                digest = result
                loadedAt = Date()
            }
        } catch APIError.unauthorized {
            // The session manager logs the user out
        } catch {
            if current == generation, !Task.isCancelled, (error as? URLError)?.code != .cancelled {
                errorMessage = error.localizedDescription

                // Figures of an earlier day must not be shown as the current week
                if let loadedAt, !Calendar.current.isDateInToday(loadedAt) {
                    digest = nil
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

struct WeeklyDigestView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = WeeklyDigestViewModel()

    @State private var showManualEntry = false

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

                    if let digest = viewModel.digest {
                        content(digest)
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
                await viewModel.load(token: sessionManager.token)
            }
        }
        .navigationTitle("Résumé de la semaine")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(token: sessionManager.token)
        }
        .sheet(isPresented: $showManualEntry) {
            ManualTicketView(onSaved: {
                Task {
                    await viewModel.load(token: sessionManager.token)
                }
            })
            .environmentObject(sessionManager)
        }
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ digest: WeeklyDigest) -> some View {
        heroCard(digest)

        if digest.hasData {
            barsCard(digest)

            if !digest.categories.isEmpty {
                categoriesCard(digest)
            }

            highlightsCard(digest)
        } else {
            emptyCard
        }
    }

    // MARK: Colors

    private func trendTint(_ digest: WeeklyDigest) -> Color {
        switch digest.trend {
        case "up":
            return EconomofarUI.warning
        case "down":
            return EconomofarUI.success
        default:
            return EconomofarUI.accent
        }
    }

    // MARK: Hero

    private func heroCard(_ digest: WeeklyDigest) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vos 7 derniers jours")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))

                Text(AppFormat.money(digest.total))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(digest.periodText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
            }

            HStack(spacing: 10) {
                Image(systemName: digest.trendIcon)
                    .font(.system(size: 14, weight: .bold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(digest.trendTitle)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle = digest.trendSubtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .opacity(0.85)
                    }
                }

                Spacer()
            }
            .foregroundColor(.white)
            .padding(12)
            .background(Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 10) {
                heroChip(title: "Achats", value: "\(digest.ticketCount)")
                heroChip(title: "Moyenne / jour", value: AppFormat.money(digest.averagePerDay))
                heroChip(title: "Jours sans dépense", value: "\(digest.noSpendDays)")
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

    // MARK: Days

    private static let barAreaHeight: CGFloat = 96

    private func barHeight(_ day: DigestDay, maxAmount: Double) -> CGFloat {
        guard day.amount > 0, maxAmount > 0 else { return 4 }

        let fraction = min(max(day.amount / maxAmount, 0), 1)

        return max(8, Self.barAreaHeight * CGFloat(fraction))
    }

    private func barsCard(_ digest: WeeklyDigest) -> some View {
        DashboardSectionCard(title: "Jour par jour") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(digest.days) { day in
                        let isLast = day.date == digest.to

                        VStack(spacing: 6) {
                            Spacer(minLength: 0)

                            Capsule()
                                .fill(day.amount > 0 ? (isLast ? EconomofarUI.accentDark : EconomofarUI.accent) : EconomofarUI.cardSoft)
                                .frame(height: barHeight(day, maxAmount: digest.maxDayAmount))

                            Text(WeeklyDigestText.format(day.date, pattern: "EEEEE").uppercased())
                                .font(.system(size: 11, weight: isLast ? .bold : .medium, design: .rounded))
                                .foregroundColor(isLast ? EconomofarUI.textPrimary : EconomofarUI.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: Self.barAreaHeight + 36)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(WeeklyDigestText.format(day.date, pattern: "EEEE d MMMM")) : \(AppFormat.money(day.amount))")
                    }
                }

                if let busiest = digest.busiestDay {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(EconomofarUI.warning)

                        Text("Jour le plus dépensier : \(WeeklyDigestText.format(busiest.date, pattern: "EEEE d MMMM")), \(AppFormat.money(busiest.amount))")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: Categories

    private func categoriesCard(_ digest: WeeklyDigest) -> some View {
        DashboardSectionCard(title: "Par catégorie") {
            ForEach(Array(digest.categories.enumerated()), id: \.element.id) { index, category in
                if index > 0 {
                    Divider()
                        .background(EconomofarUI.border)
                        .padding(.leading, 16)
                }

                categoryRow(category, hasComparison: digest.hasComparison)
            }
        }
    }

    private func categoryRow(_ category: DigestCategory, hasComparison: Bool) -> some View {
        let fraction = min(max(category.share / 100, 0), 1)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(AppFormat.money(category.amount))
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

            HStack {
                Text("\(WeeklyDigestText.percent(category.share)) % des dépenses")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)

                Spacer()

                if hasComparison {
                    changeLabel(category)
                }
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private func changeLabel(_ category: DigestCategory) -> some View {
        if category.previousAmount <= 0 {
            Text("Nouveau")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.warning)
        } else if category.change == 0 {
            Text("Inchangé")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textTertiary)
        } else {
            Text("\(WeeklyDigestText.signedMoney(category.change)) vs semaine précédente")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(category.change > 0 ? EconomofarUI.warning : EconomofarUI.success)
        }
    }

    // MARK: Highlights

    private func highlightsCard(_ digest: WeeklyDigest) -> some View {
        DashboardSectionCard(title: "À retenir") {
            if let purchase = digest.biggestPurchase {
                DashboardInsightRow(
                    icon: "bag.fill",
                    title: "Plus gros achat",
                    subtitle: "\(purchase.merchant) · \(WeeklyDigestText.format(purchase.date, pattern: "d MMMM"))",
                    value: AppFormat.money(purchase.amount),
                    tint: EconomofarUI.accent
                )

                DashboardDivider()
            }

            if let merchant = digest.topMerchant {
                DashboardInsightRow(
                    icon: "storefront.fill",
                    title: "Commerce principal",
                    subtitle: "\(merchant.name) · \(merchant.visits) passage\(merchant.visits > 1 ? "s" : "")",
                    value: AppFormat.money(merchant.amount),
                    tint: EconomofarUI.accent
                )

                DashboardDivider()
            }

            if let change = digest.biggestChange {
                DashboardInsightRow(
                    icon: change.change > 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill",
                    title: "Plus forte variation",
                    subtitle: "\(change.name) · \(AppFormat.money(change.previousAmount)) la semaine précédente",
                    value: WeeklyDigestText.signedMoney(change.change),
                    tint: change.change > 0 ? EconomofarUI.warning : EconomofarUI.success
                )

                DashboardDivider()
            }

            DashboardInsightRow(
                icon: "leaf.fill",
                title: "Jours sans dépense",
                subtitle: digest.noSpendDays == 0 ? "Vous avez dépensé chaque jour" : "Sur les 7 derniers jours",
                value: "\(digest.noSpendDays)",
                tint: digest.noSpendDays > 0 ? EconomofarUI.success : EconomofarUI.textSecondary
            )
        }
    }

    // MARK: Empty

    private var emptyCard: some View {
        VStack(spacing: 14) {
            DashboardInfoBanner(
                icon: "info.circle.fill",
                message: "Aucun achat enregistré sur les 14 derniers jours. Ajoutez vos achats pour voir votre résumé.",
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)

            Button {
                showManualEntry = true
            } label: {
                Label("Ajouter un achat", systemImage: "square.and.pencil")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
