import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class SpendingForecastViewModel: ObservableObject {
    @Published var forecast: SpendingForecast? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    func load(token: String?) async {
        guard let token, !token.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            forecast = try await SpendingForecastService.shared.fetch(token: token)
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

// MARK: - Screen

struct SpendingForecastView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = SpendingForecastViewModel()

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

                    if let forecast = viewModel.forecast {
                        content(forecast)
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
        .navigationTitle("Prévision du mois")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(token: sessionManager.token)
        }
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ forecast: SpendingForecast) -> some View {
        heroCard(forecast)

        budgetSection(forecast)

        if forecast.previousMonthTotal != nil {
            comparisonCard(forecast)
        }

        if !forecast.upcoming.isEmpty {
            upcomingCard(forecast)
        }

        Text(forecast.confidenceText)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(EconomofarUI.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    // MARK: Hero

    private func heroCard(_ forecast: SpendingForecast) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Prévision pour fin \(forecast.monthName)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))

                Text(AppFormat.money(forecast.projectedTotal))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if forecast.daysRemaining > 0 {
                    Text(forecast.rangeText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.85))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))

                        Capsule()
                            .fill(Color.white)
                            .frame(width: proxy.size.width * CGFloat(forecast.monthProgress))
                    }
                }
                .frame(height: 6)

                Text("Jour \(forecast.dayOfMonth) sur \(forecast.daysInMonth)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
            }

            HStack(spacing: 10) {
                heroChip(title: "Déjà dépensé", value: AppFormat.money(forecast.spentSoFar))
                heroChip(title: "Paiements à venir", value: AppFormat.money(forecast.upcomingRecurring))
                heroChip(title: "Rythme / jour", value: AppFormat.money(forecast.dailyPace))
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

    // MARK: Budget

    private func statusColor(_ forecast: SpendingForecast) -> Color {
        switch forecast.budgetStatus {
        case "onTrack":
            return EconomofarUI.success
        case "atRisk":
            return EconomofarUI.warning
        case "projectedOver", "exceeded":
            return EconomofarUI.danger
        default:
            return EconomofarUI.textSecondary
        }
    }

    private func statusSoftColor(_ forecast: SpendingForecast) -> Color {
        switch forecast.budgetStatus {
        case "onTrack":
            return EconomofarUI.successSoft
        case "atRisk":
            return EconomofarUI.warningSoft
        case "projectedOver", "exceeded":
            return EconomofarUI.dangerSoft
        default:
            return EconomofarUI.cardSoft
        }
    }

    @ViewBuilder
    private func budgetSection(_ forecast: SpendingForecast) -> some View {
        if let budget = forecast.monthlyBudget {
            budgetCard(forecast, budget: budget)
        } else {
            noBudgetCard
        }
    }

    private func budgetCard(_ forecast: SpendingForecast, budget: Double) -> some View {
        let tint = statusColor(forecast)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Budget du mois")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)

                    Text(AppFormat.money(budget))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                }

                Spacer()

                Text(forecast.budgetStatusTitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusSoftColor(forecast))
                    .clipShape(Capsule())
            }

            ForecastBudgetBar(
                spent: forecast.spentSoFar,
                projected: forecast.projectedTotal,
                budget: budget,
                tint: tint
            )

            HStack(spacing: 14) {
                legendDot(color: tint, text: "Dépensé")
                legendDot(color: tint.opacity(0.3), text: "Prévu")
                legendDot(color: EconomofarUI.textPrimary, text: "Budget")
            }

            if let message = forecast.budgetMessage {
                Text(message)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let allowance = forecast.dailyAllowance {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 13, weight: .semibold))

                    if allowance > 0 {
                        Text("Pour rester dans le budget : \(AppFormat.money(allowance)) par jour au maximum.")
                    } else {
                        Text("Il ne reste plus de marge pour les jours à venir.")
                    }
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(allowance > 0 ? EconomofarUI.accent : EconomofarUI.warning)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(allowance > 0 ? EconomofarUI.accentSoft : EconomofarUI.warningSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
        }
    }

    private var noBudgetCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(EconomofarUI.accent)

            Text("Définissez un budget mensuel dans les réglages pour savoir si vous allez le respecter.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
    }

    // MARK: Comparison

    private func comparisonCard(_ forecast: SpendingForecast) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Mois dernier")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)

                Text(AppFormat.money(forecast.previousMonthTotal ?? 0))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
            }

            Spacer()

            if let change = forecast.changeVersusPreviousText {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Prévision actuelle")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)

                    Text(change)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                }
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
    }

    // MARK: Upcoming payments

    private func upcomingCard(_ forecast: SpendingForecast) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paiements réguliers attendus")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            ForEach(Array(forecast.upcoming.enumerated()), id: \.offset) { entry in
                HStack(spacing: 10) {
                    Text(entry.element.dateText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.accent)
                        .frame(width: 58, alignment: .leading)

                    Text(entry.element.merchantName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(AppFormat.money(entry.element.amount))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                }
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
    }
}

// MARK: - Budget bar

struct ForecastBudgetBar: View {
    let spent: Double
    let projected: Double
    let budget: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let scale = max(budget, projected, spent, 1) * 1.05
            let width = proxy.size.width
            let spentWidth = width * CGFloat(min(spent / scale, 1))
            let projectedWidth = width * CGFloat(min(projected / scale, 1))
            let budgetX = width * CGFloat(min(budget / scale, 1))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(EconomofarUI.cardSoft)
                    .frame(height: 12)

                Capsule()
                    .fill(tint.opacity(0.3))
                    .frame(width: projectedWidth, height: 12)

                Capsule()
                    .fill(tint)
                    .frame(width: spentWidth, height: 12)

                Rectangle()
                    .fill(EconomofarUI.textPrimary)
                    .frame(width: 2, height: 18)
                    .offset(x: max(budgetX - 1, 0))
            }
        }
        .frame(height: 18)
    }
}
