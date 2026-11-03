import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class HealthScoreViewModel: ObservableObject {
    @Published var report: HealthScoreReport? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    func load(token: String?) async {
        guard let token, !token.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            report = try await HealthScoreService.shared.fetch(token: token)
        } catch APIError.unauthorized {
            // The session manager logs the user out
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}

// MARK: - Look

private enum HealthStyle {
    static func label(_ level: HealthLevel) -> String {
        switch level {
        case .excellent: return "Excellente"
        case .good: return "Bonne"
        case .watch: return "À surveiller"
        case .fragile: return "Fragile"
        case .unknown: return "Pas encore de score"
        }
    }

    static func color(_ level: HealthLevel) -> Color {
        switch level {
        case .excellent: return EconomofarUI.success
        case .good: return EconomofarUI.accent
        case .watch: return EconomofarUI.warning
        case .fragile: return EconomofarUI.danger
        case .unknown: return EconomofarUI.textTertiary
        }
    }

    static func softColor(_ level: HealthLevel) -> Color {
        switch level {
        case .excellent: return EconomofarUI.successSoft
        case .good: return EconomofarUI.accentSoft
        case .watch: return EconomofarUI.warningSoft
        case .fragile: return EconomofarUI.dangerSoft
        case .unknown: return EconomofarUI.cardSoft
        }
    }

    static func level(forScore score: Int?) -> HealthLevel {
        guard let score else { return .unknown }

        if score >= 80 { return .excellent }
        if score >= 60 { return .good }
        if score >= 40 { return .watch }
        return .fragile
    }

    static func icon(forKey key: String) -> String {
        switch key {
        case "savings": return "dollarsign.circle.fill"
        case "budget": return "chart.pie.fill"
        case "categories": return "square.grid.2x2.fill"
        case "goals": return "flag.fill"
        case "recurring": return "arrow.triangle.2.circlepath"
        default: return "circle.fill"
        }
    }
}

private extension View {
    func healthCard(radius: CGFloat = 22) -> some View {
        self
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }
}

// MARK: - Screen

struct HealthScoreView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = HealthScoreViewModel()

    var body: some View {
        ZStack {
            EconomofarUI.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    introText

                    if let errorMessage = viewModel.errorMessage {
                        DashboardInfoBanner(
                            icon: "exclamationmark.triangle.fill",
                            message: errorMessage,
                            tint: EconomofarUI.danger,
                            background: EconomofarUI.dangerSoft
                        )
                        .padding(.horizontal, -20)
                    }

                    if let report = viewModel.report {
                        gaugeCard(report)

                        if !report.tips.isEmpty {
                            tipsCard(report.tips)
                        }

                        componentsSection(report.components)

                        footnote
                    } else if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 50)
                    } else if viewModel.errorMessage != nil {
                        Button {
                            Task {
                                await viewModel.load(token: sessionManager.token)
                            }
                        } label: {
                            Text("Réessayer")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(EconomofarUI.accent)
                                .clipShape(Capsule())
                        }
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
        .navigationTitle("Santé financière")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(token: sessionManager.token)
        }
    }

    // MARK: Pieces

    private var introText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Votre note sur 100")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text("Elle réunit votre taux d'épargne, votre budget, vos limites par catégorie, vos objectifs d'épargne et le poids de vos paiements réguliers.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func gaugeCard(_ report: HealthScoreReport) -> some View {
        let level = report.levelValue
        let tint = HealthStyle.color(level)

        return VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(EconomofarUI.cardSoft, lineWidth: 16)

                Circle()
                    .trim(from: 0, to: CGFloat(report.fraction))
                    .stroke(tint, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: report.fraction)

                VStack(spacing: 2) {
                    Text(report.score.map { String($0) } ?? "–")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(report.score == nil ? EconomofarUI.textTertiary : EconomofarUI.textPrimary)

                    Text("sur 100")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }
            }
            .frame(width: 190, height: 190)
            .padding(.top, 6)

            Text(HealthStyle.label(level))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(HealthStyle.softColor(level))
                .clipShape(Capsule())

            Text(gaugeMessage(report))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .healthCard()
    }

    private func gaugeMessage(_ report: HealthScoreReport) -> String {
        let total = max(report.components.count, 1)

        if report.score != nil {
            let plural = report.availableComponents > 1 ? "s" : ""
            return "Calculée sur \(report.availableComponents) critère\(plural) sur \(total)."
        }

        return "Il faut au moins 2 critères pour calculer votre note. Les critères grisés se débloquent au fur et à mesure."
    }

    private func tipsCard(_ tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pour progresser")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EconomofarUI.warning)
                        .frame(width: 24, height: 24)

                    Text(tip)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .healthCard()
    }

    private func componentsSection(_ components: [HealthComponent]) -> some View {
        let counted = components.filter { $0.score != nil }
        let totalWeight = counted.reduce(0) { $0 + $1.weight }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Le détail")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            ForEach(components) { component in
                componentRow(component, share: share(of: component, totalWeight: totalWeight, countedParts: counted.count))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Part of the final note that this criterion stands for (the weights are rescaled
    /// when some criteria cannot be computed yet). Nil when there is no note.
    private func share(of component: HealthComponent, totalWeight: Int, countedParts: Int) -> Int? {
        guard component.score != nil, countedParts >= 2, totalWeight > 0 else { return nil }

        return Int((Double(component.weight) / Double(totalWeight) * 100).rounded())
    }

    @ViewBuilder
    private func componentRow(_ component: HealthComponent, share: Int?) -> some View {
        switch component.key {
        case "savings":
            NavigationLink {
                IncomeView()
            } label: {
                HealthComponentCard(component: component, linked: true, share: share)
            }
            .buttonStyle(.plain)
        case "categories":
            NavigationLink {
                CategoryBudgetsView()
            } label: {
                HealthComponentCard(component: component, linked: true, share: share)
            }
            .buttonStyle(.plain)
        case "goals":
            NavigationLink {
                SavingsGoalsView()
            } label: {
                HealthComponentCard(component: component, linked: true, share: share)
            }
            .buttonStyle(.plain)
        case "recurring":
            NavigationLink {
                RecurringExpensesView()
            } label: {
                HealthComponentCard(component: component, linked: true, share: share)
            }
            .buttonStyle(.plain)
        default:
            HealthComponentCard(component: component, linked: false, share: share)
        }
    }

    private var footnote: some View {
        Text("Seuls les tickets validés sont comptés. La note se met à jour à chaque ouverture de cet écran.")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(EconomofarUI.textTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - One criterion

private struct HealthComponentCard: View {
    let component: HealthComponent
    let linked: Bool
    let share: Int?

    private var level: HealthLevel {
        HealthStyle.level(forScore: component.score)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: HealthStyle.icon(forKey: component.key))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(HealthStyle.color(level))
                    .frame(width: 40, height: 40)
                    .background(HealthStyle.softColor(level))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(component.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    if let share {
                        Text("\(share) % de la note")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.textTertiary)
                    }
                }

                Spacer()

                if let score = component.score {
                    Text("\(score)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(HealthStyle.color(level))
                } else {
                    Text("En attente")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textTertiary)
                }

                if linked {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(EconomofarUI.textTertiary)
                }
            }

            if let score = component.score {
                HealthBar(fraction: Double(score) / 100, tint: HealthStyle.color(level))
            }

            if !component.detail.isEmpty {
                Text(component.detail)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .healthCard()
        .opacity(component.score == nil ? 0.75 : 1)
    }
}

private struct HealthBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        let safe = fraction.isFinite ? min(max(fraction, 0), 1) : 0

        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(EconomofarUI.cardSoft)

                Capsule()
                    .fill(tint)
                    .frame(width: max(safe > 0 ? 6 : 0, proxy.size.width * CGFloat(safe)))
            }
        }
        .frame(height: 8)
    }
}
