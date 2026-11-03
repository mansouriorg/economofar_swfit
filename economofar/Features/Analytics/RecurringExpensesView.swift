import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class RecurringExpensesViewModel: ObservableObject {
    @Published var items: [RecurringExpense] = []
    @Published var monthlyTotal: Double = 0
    @Published var isLoading = false
    @Published var hasLoaded = false
    @Published var errorMessage: String? = nil

    func load(token: String?) async {
        guard let token, !token.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await RecurringExpenseService.shared.fetch(token: token)
            items = response.items
            monthlyTotal = response.monthlyTotal
            hasLoaded = true
        } catch APIError.unauthorized {
            // The session manager logs the user out
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Screen

struct RecurringExpensesView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = RecurringExpensesViewModel()

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
                        totalCard

                        ForEach(viewModel.items) { item in
                            expenseCard(item)
                        }

                        Text("Détecté automatiquement à partir de vos tickets des 12 derniers mois : même enseigne, montant proche et rythme régulier.")
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
        .navigationTitle("Dépenses récurrentes")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(token: sessionManager.token)
        }
    }

    // MARK: Pieces

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Total mensuel estimé")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.85))

            Text(AppFormat.money(viewModel.monthlyTotal))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("\(viewModel.items.count) dépense\(viewModel.items.count > 1 ? "s" : "") récurrente\(viewModel.items.count > 1 ? "s" : "")")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func expenseCard(_ item: RecurringExpense) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.merchantName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(1)

                    Text(item.subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(AppFormat.money(item.typicalAmount))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    if item.frequency != "monthly" {
                        Text("≈ \(AppFormat.money(item.monthlyEstimate)) / mois")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: item.daysUntilNext < 0 ? "exclamationmark.circle.fill" : "calendar")
                    .font(.system(size: 13, weight: .semibold))

                Text(item.nextText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Spacer()

                Text("\(item.occurrences)×")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .foregroundColor(item.daysUntilNext < 0 ? EconomofarUI.warning : EconomofarUI.accent)
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(EconomofarUI.accent)

            Text("Aucune dépense récurrente")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text("Dès que vous aurez enregistré au moins 3 tickets réguliers de la même enseigne (abonnement, salle de sport, loyer...), ils apparaîtront ici avec la date du prochain paiement.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
        .padding(.horizontal, 12)
    }
}
