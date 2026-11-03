import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class SpendingEventsViewModel: ObservableObject {
    @Published var overview: SpendingEventsOverview? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published var showArchived = false

    private var generation = 0
    private var loadedAt: Date? = nil

    func load(token: String?) async {
        guard let token, !token.isEmpty else {
            errorMessage = "Votre session a expiré. Reconnectez-vous."
            isLoading = false
            return
        }

        generation += 1
        let current = generation

        isLoading = true
        errorMessage = nil

        do {
            let result = try await SpendingEventsService.shared.fetchOverview(token: token)

            if current == generation {
                overview = result
                loadedAt = Date()

                // Nothing is left to show in the archives, and the tabs are hidden: go back to the events
                if result.archivedCount == 0 {
                    showArchived = false
                }
            }
        } catch APIError.unauthorized {
            // The session manager logs the user out
            if current == generation {
                errorMessage = "Votre session a expiré. Reconnectez-vous."
            }
        } catch {
            if current == generation, !Task.isCancelled, (error as? URLError)?.code != .cancelled {
                errorMessage = error.localizedDescription

                // Figures of an earlier day must not be shown as the current ones
                if let loadedAt, !Calendar.current.isDateInToday(loadedAt) {
                    overview = nil
                    self.loadedAt = nil
                }
            }
        }

        if current == generation {
            isLoading = false
        }
    }

    /// The events of the chosen tab.
    var rows: [SpendingEventLine] {
        guard let overview else {
            return []
        }

        return showArchived ? overview.archivedEvents : overview.activeEvents
    }

    var canCreate: Bool {
        (overview?.events.count ?? 0) < SpendingEventsText.maxEvents
    }
}

// MARK: - Look shared by the screens of the events

enum SpendingEventStyle {
    static func tint(_ level: SpendingEventState) -> Color {
        switch level {
        case .noBudget:
            return EconomofarUI.accent
        case .ok:
            return EconomofarUI.success
        case .near:
            return EconomofarUI.warning
        case .over:
            return EconomofarUI.danger
        }
    }

    static func soft(_ level: SpendingEventState) -> Color {
        switch level {
        case .noBudget:
            return EconomofarUI.accentSoft
        case .ok:
            return EconomofarUI.successSoft
        case .near:
            return EconomofarUI.warningSoft
        case .over:
            return EconomofarUI.dangerSoft
        }
    }

    /// The part of the budget that is spent, from 0 to 1.
    static func fraction(_ line: SpendingEventLine) -> Double {
        guard let percent = line.usedPercent, percent.isFinite else {
            return 0
        }

        return min(max(percent / 100, 0), 1)
    }
}

/// A bar that fills from the left, from 0 to 1.
struct SpendingEventBar: View {
    let fraction: Double
    let tint: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(EconomofarUI.border)

                Capsule()
                    .fill(tint)
                    .frame(width: max(proxy.size.width * CGFloat(min(max(fraction, 0), 1)), fraction > 0 ? height : 0))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Screen

struct SpendingEventsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = SpendingEventsViewModel()
    @State private var showingForm = false

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

                    if let overview = viewModel.overview {
                        content(overview)
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
        .navigationTitle("Événements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!viewModel.canCreate)
                .accessibilityLabel(Text("Nouvel événement"))
            }
        }
        .sheet(isPresented: $showingForm) {
            SpendingEventFormView(event: nil) {
                reload()
            }
        }
        .task {
            await viewModel.load(token: sessionManager.token)
        }
    }

    private func reload() {
        Task {
            await viewModel.load(token: sessionManager.token)
        }
    }

    private var retryButton: some View {
        Button {
            reload()
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
    private func content(_ overview: SpendingEventsOverview) -> some View {
        heroCard(overview)

        if let alert = SpendingEventsText.alertText(overview) {
            DashboardInfoBanner(
                icon: "exclamationmark.circle.fill",
                message: alert,
                tint: overview.overBudgetCount > 0 ? EconomofarUI.danger : EconomofarUI.warning,
                background: overview.overBudgetCount > 0 ? EconomofarUI.dangerSoft : EconomofarUI.warningSoft
            )
            .padding(.horizontal, -20)
        }

        if overview.isEmpty {
            emptyCard
        } else {
            if overview.archivedCount > 0 {
                tabPicker(overview)
            }

            listCard(overview)
        }

        if !viewModel.canCreate {
            footnote("Vous avez atteint la limite de \(SpendingEventsText.maxEvents) événements. Supprimez-en un pour en créer un autre.")
        }

        DashboardInfoBanner(
            icon: "info.circle.fill",
            message: SpendingEventsText.method,
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }

    private func tabPicker(_ overview: SpendingEventsOverview) -> some View {
        Picker("Événements", selection: $viewModel.showArchived) {
            Text("En cours (\(overview.activeCount))").tag(false)
            Text("Archivés (\(overview.archivedCount))").tag(true)
        }
        .pickerStyle(.segmented)
    }

    // MARK: Hero

    private func heroCard(_ overview: SpendingEventsOverview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vos événements")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.85))
                .accessibilityAddTraits(.isHeader)

            Text(SpendingEventsText.headline(overview))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(SpendingEventsText.summary(overview))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: Empty

    private var emptyCard: some View {
        VStack(spacing: 12) {
            DashboardIconBox(icon: "calendar", tint: EconomofarUI.accent)
                .accessibilityHidden(true)

            Text(SpendingEventsText.emptyTitle)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text(SpendingEventsText.emptyHint)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showingForm = true
            } label: {
                Label("Créer un événement", systemImage: "plus")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(EconomofarUI.mainGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: List

    @ViewBuilder
    private func listCard(_ overview: SpendingEventsOverview) -> some View {
        let rows = viewModel.rows

        if rows.isEmpty {
            DashboardInfoBanner(
                icon: "tray",
                message: viewModel.showArchived ? "Aucun événement archivé." : "Tous vos événements sont archivés.",
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        } else {
            DashboardSectionCard(title: viewModel.showArchived ? SpendingEventsText.archivedTitle : "En cours de suivi") {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, line in
                    if index > 0 {
                        DashboardDivider()
                    }

                    NavigationLink {
                        SpendingEventDetailView(line: line) {
                            reload()
                        }
                    } label: {
                        lineRow(line)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func lineRow(_ line: SpendingEventLine) -> some View {
        HStack(alignment: .center, spacing: 14) {
            DashboardIconBox(
                icon: SpendingEventIcons.symbol(line.icon),
                tint: line.archived ? EconomofarUI.textSecondary : SpendingEventStyle.tint(line.level)
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(line.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(2)

                Text(SpendingEventsText.period(line))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(SpendingEventsText.timingTitle(line) + " · " + SpendingEventsText.tickets(line.ticketCount))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if line.hasBudget {
                    SpendingEventBar(
                        fraction: SpendingEventStyle.fraction(line),
                        tint: SpendingEventStyle.tint(line.level)
                    )
                    .padding(.top, 2)

                    Text(SpendingEventsText.budgetLine(line))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(SpendingEventStyle.tint(line.level))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !line.hasBudget {
                Text(SpendingEventsText.money(line.spent))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(EconomofarUI.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(16)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(SpendingEventsText.rowAccessibility(line)))
        .accessibilityAddTraits(.isButton)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(EconomofarUI.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
