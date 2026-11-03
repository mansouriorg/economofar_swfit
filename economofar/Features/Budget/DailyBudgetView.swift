import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class DailyBudgetViewModel: ObservableObject {
    @Published var budget: DailyBudget? = nil
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
            let result = try await DailyBudgetService.shared.fetch(token: token)

            if current == generation {
                budget = result
                loadedAt = Date()
            }
        } catch APIError.unauthorized {
            // The session manager logs the user out
        } catch {
            if current == generation, !Task.isCancelled, (error as? URLError)?.code != .cancelled {
                errorMessage = error.localizedDescription

                // Figures of an earlier day must not be shown as today's
                if let loadedAt, !Calendar.current.isDateInToday(loadedAt) {
                    budget = nil
                    self.loadedAt = nil
                }
            }
        }

        if current == generation {
            isLoading = false
        }
    }
}

// MARK: - Colors

extension DailyBudgetLevel {
    var tint: Color {
        switch self {
        case .good:
            return EconomofarUI.success
        case .tight:
            return EconomofarUI.warning
        case .over, .exhausted:
            return EconomofarUI.danger
        case .noBudget:
            return EconomofarUI.accent
        }
    }

    var softTint: Color {
        switch self {
        case .good:
            return EconomofarUI.successSoft
        case .tight:
            return EconomofarUI.warningSoft
        case .over, .exhausted:
            return EconomofarUI.dangerSoft
        case .noBudget:
            return EconomofarUI.accentSoft
        }
    }

    var icon: String {
        switch self {
        case .good:
            return "checkmark.circle.fill"
        case .tight:
            return "exclamationmark.circle.fill"
        case .over, .exhausted:
            return "exclamationmark.triangle.fill"
        case .noBudget:
            return "info.circle.fill"
        }
    }
}

// MARK: - Screen

struct DailyBudgetView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = DailyBudgetViewModel()

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

                    if let budget = viewModel.budget {
                        content(budget)
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
        .navigationTitle("Budget du jour")
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
    private func content(_ budget: DailyBudget) -> some View {
        heroCard(budget)

        DashboardInfoBanner(
            icon: budget.level.icon,
            message: budget.message,
            tint: budget.level.tint,
            background: budget.level.softTint
        )
        .padding(.horizontal, -20)

        detailsCard(budget)

        if budget.hasBudget {
            Text("Le budget du jour est ce qui reste de votre budget mensuel, une fois les paiements réguliers à venir mis de côté, divisé par le nombre de jours restants. Il se recalcule à chaque achat enregistré.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)
        }

        forecastLink

        addPurchaseButton
    }

    // MARK: Hero

    private func heroBackground(_ level: DailyBudgetLevel) -> LinearGradient {
        switch level {
        case .good, .noBudget:
            return EconomofarUI.mainGradient
        case .tight, .over, .exhausted:
            return LinearGradient(
                colors: [level.tint.opacity(0.85), level.tint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func heroCard(_ budget: DailyBudget) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(budget.heroLabel)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))

                Text(budget.heroValue)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(budget.heroCaption)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
            }

            if budget.hasBudget {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))

                        Capsule()
                            .fill(Color.white)
                            .frame(width: proxy.size.width * CGFloat(budget.usedFraction))
                    }
                }
                .frame(height: 6)

                HStack(spacing: 10) {
                    heroChip(title: "Dépensé aujourd'hui", value: AppFormat.money(budget.spentToday))

                    if let tomorrow = budget.tomorrowBudget {
                        heroChip(title: "Demain", value: AppFormat.money(tomorrow))
                    }

                    heroChip(title: "Jours restants", value: "\(max(budget.daysLeft, 1))")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(heroBackground(budget.level))
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

    // MARK: Details

    private func detailsCard(_ budget: DailyBudget) -> some View {
        DashboardSectionCard(title: "Détail du jour") {
            if let daily = budget.dailyBudget {
                DashboardInsightRow(
                    icon: "sun.max.fill",
                    title: "Budget du jour",
                    subtitle: budget.daysLeftText,
                    value: AppFormat.money(daily),
                    tint: EconomofarUI.accent
                )

                DashboardDivider()
            }

            DashboardInsightRow(
                icon: "cart.fill",
                title: "Dépensé aujourd'hui",
                subtitle: "Sans les paiements réguliers",
                value: AppFormat.money(budget.spentToday),
                tint: budget.hasBudget ? budget.level.tint : EconomofarUI.textSecondary
            )

            if budget.recurringToday > 0 {
                DashboardDivider()

                DashboardInsightRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Paiements réguliers du jour",
                    subtitle: "Déjà prévus, ils n'entament pas le budget du jour",
                    value: AppFormat.money(budget.recurringToday),
                    tint: EconomofarUI.warning
                )
            }

            if let tomorrow = budget.tomorrowBudget {
                DashboardDivider()

                DashboardInsightRow(
                    icon: "moon.stars.fill",
                    title: "Demain",
                    subtitle: "Selon ce que vous avez dépensé aujourd'hui",
                    value: AppFormat.money(tomorrow),
                    tint: EconomofarUI.accent
                )
            }

            if let remaining = budget.monthRemaining {
                DashboardDivider()

                DashboardInsightRow(
                    icon: "calendar",
                    title: remaining < 0 ? "Dépassement du mois" : "Reste du mois",
                    subtitle: "Paiements réguliers à venir compris",
                    value: AppFormat.money(abs(remaining)),
                    tint: remaining < 0 ? EconomofarUI.danger : EconomofarUI.success
                )
            }

            if budget.upcomingRecurring > 0 {
                DashboardDivider()

                DashboardInsightRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Paiements réguliers à venir",
                    subtitle: "Jusqu'à la fin du mois",
                    value: AppFormat.money(budget.upcomingRecurring),
                    tint: EconomofarUI.warning
                )
            }
        }
    }

    // MARK: Links

    private var forecastLink: some View {
        NavigationLink {
            SpendingForecastView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Prévision du mois")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Ce que vous aurez dépensé à la fin du mois")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var addPurchaseButton: some View {
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
