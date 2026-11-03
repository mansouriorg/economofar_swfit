import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class UnusualPurchasesViewModel: ObservableObject {
    static let periods = [7, 30, 90]

    @Published var result: UnusualPurchases? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var days = 30

    private var generation = 0
    private var loadedAt: Date? = nil

    func load(token: String?) async {
        guard let token, !token.isEmpty else { return }

        generation += 1
        let current = generation

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await UnusualPurchaseService.shared.fetch(token: token, days: days)

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

struct UnusualPurchasesView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = UnusualPurchasesViewModel()

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

                    if let result = viewModel.result, result.days == viewModel.days {
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
        .navigationTitle("Achats inhabituels")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(token: sessionManager.token)
        }
        .onChange(of: viewModel.days) { _ in
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }
    }

    // MARK: Controls

    private var periodPicker: some View {
        Picker("Période", selection: $viewModel.days) {
            ForEach(UnusualPurchasesViewModel.periods, id: \.self) { days in
                Text(UnusualText.periodTitle(days)).tag(days)
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
    private func content(_ result: UnusualPurchases) -> some View {
        heroCard(result)

        if result.purchases.isEmpty {
            verdictBanner(result)
        } else {
            purchasesCard(result)
        }

        if result.examined > 0 {
            DashboardInfoBanner(
                icon: "info.circle.fill",
                message: "Un achat est signalé quand il atteint au moins 3 fois votre montant habituel dans ce commerce (ou, à défaut, dans cette catégorie) et dépasse presque tous vos achats précédents au même endroit, sur les 6 mois qui précèdent. Les achats modestes ne sont pas signalés.",
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }
    }

    private func heroCard(_ result: UnusualPurchases) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("À vérifier")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))

                Text(headline(result))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Text(result.periodText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
            }

            HStack(spacing: 10) {
                heroChip(title: "Achats", value: "\(result.examined)")
                heroChip(title: "Comparés", value: "\(result.compared)")
                heroChip(title: "Signalés", value: "\(result.flaggedCount)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func headline(_ result: UnusualPurchases) -> String {
        if result.examined == 0 {
            return "Aucun achat"
        }

        if result.compared == 0 {
            return "Pas encore de comparaison"
        }

        switch result.flaggedCount {
        case 0:
            return "Rien d'inhabituel"
        case 1:
            return "1 achat inhabituel"
        default:
            return "\(result.flaggedCount) achats inhabituels"
        }
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

    // MARK: Verdict

    @ViewBuilder
    private func verdictBanner(_ result: UnusualPurchases) -> some View {
        if result.examined == 0 {
            DashboardInfoBanner(
                icon: "info.circle.fill",
                message: "Aucun achat enregistré sur cette période.",
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        } else if result.compared == 0 {
            DashboardInfoBanner(
                icon: "clock.fill",
                message: "Pas encore assez d'historique pour comparer vos achats récents. Il faut au moins 4 achats dans le même commerce, ou 6 dans la même catégorie, sur les 6 mois précédents. Les commerces inconnus et la catégorie Autre ne servent pas de référence.",
                tint: EconomofarUI.warning,
                background: EconomofarUI.warningSoft
            )
            .padding(.horizontal, -20)
        } else {
            DashboardInfoBanner(
                icon: "checkmark.seal.fill",
                message: "Aucun achat ne sort de l'ordinaire sur cette période.",
                tint: EconomofarUI.success,
                background: EconomofarUI.successSoft
            )
            .padding(.horizontal, -20)
        }
    }

    // MARK: Purchases

    private func purchasesCard(_ result: UnusualPurchases) -> some View {
        VStack(spacing: 12) {
            DashboardSectionCard(title: "Achats à vérifier") {
                ForEach(Array(result.purchases.enumerated()), id: \.offset) { index, purchase in
                    if index > 0 {
                        DashboardDivider()
                    }

                    purchaseRow(purchase)
                }
            }

            if result.flaggedCount > result.purchases.count {
                Text("Les \(result.purchases.count) plus inhabituels sur \(result.flaggedCount).")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
        }
    }

    private func purchaseRow(_ purchase: UnusualPurchase) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(UnusualText.ratio(purchase.ratio))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.warning)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 46, height: 46)
                .background(EconomofarUI.warningSoft)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(purchase.merchant)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Text(AppFormat.money(purchase.amount))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .layoutPriority(1)
                }

                Text("\(UnusualText.capitalizedFirst(WeeklyDigestText.format(purchase.date, pattern: "EEEE d MMMM"))) · \(purchase.category)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .lineLimit(2)

                Text(UnusualText.usual(purchase))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(purchase.merchant), \(AppFormat.money(purchase.amount)), \(WeeklyDigestText.percent(purchase.ratio)) fois votre montant habituel. \(UnusualText.usual(purchase))")
    }
}
