import SwiftUI
import Combine

// MARK: - View model

struct WarrantyOverviewWindowOption: Identifiable {
    let days: Int
    let title: String

    var id: Int { days }
}

enum WarrantyOverviewState {
    case soon
    case active
    case expired
}

@MainActor
final class WarrantyOverviewViewModel: ObservableObject {
    static let windows = [30, 60, 90]

    let windowOptions: [WarrantyOverviewWindowOption] = WarrantyOverviewViewModel.windows.map {
        WarrantyOverviewWindowOption(days: $0, title: "\($0) jours")
    }

    @Published var result: WarrantyOverview? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published private(set) var loadedSoonDays: Int? = nil

    /// Choosing another period shows the spinner at once, before the request starts.
    @Published var soonDays: Int = 30 {
        didSet {
            if soonDays != oldValue {
                isLoading = true

                // An answer for the period left behind must not be taken for the new one
                generation += 1
            }
        }
    }

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
        let selectedDays = soonDays

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await WarrantyOverviewService.shared.fetch(
                token: token,
                soonDays: selectedDays
            )

            if current == generation {
                result = fetched
                loadedSoonDays = selectedDays
                loadedAt = Date()
            }
        } catch APIError.unauthorized {
            // The session manager logs the user out
            if current == generation {
                errorMessage = "Votre session a expiré. Reconnectez-vous."
            }
        } catch {
            if current == generation, !Task.isCancelled {
                errorMessage = error.localizedDescription

                // Countdowns of an earlier day must not be shown as the current ones
                if let loadedAt, !Calendar.current.isDateInToday(loadedAt) {
                    result = nil
                    loadedSoonDays = nil
                    self.loadedAt = nil
                }
            }
        }

        if current == generation {
            isLoading = false
        }
    }

    /// The countdowns were counted on an earlier day: they are read again.
    func reloadIfNewDay(token: String?) async {
        guard let loadedAt, !Calendar.current.isDateInToday(loadedAt) else {
            return
        }

        await load(token: token)
    }
}

// MARK: - Screen

struct WarrantyOverviewView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = WarrantyOverviewViewModel()

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

                    picker

                    if let result = viewModel.result,
                       viewModel.loadedSoonDays == viewModel.soonDays {
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
        .navigationTitle("Suivi des garanties")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Also when coming back from a ticket: its warranty date may have been changed there
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }
        .onChange(of: viewModel.soonDays) { _ in
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task {
                    await viewModel.reloadIfNewDay(token: sessionManager.token)
                }
            }
        }
    }

    // MARK: Controls

    private var picker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Bientôt expirées", selection: $viewModel.soonDays) {
                ForEach(viewModel.windowOptions) { option in
                    Text(option.title).tag(option.days)
                }
            }
            .pickerStyle(.segmented)

            Text(WarrantyOverviewText.soonCaption(viewModel.soonDays))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
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
    private func content(_ result: WarrantyOverview) -> some View {
        heroCard(result)

        if result.hasAny {
            section(
                title: WarrantyOverviewText.soonTitle(result.soonCount),
                items: result.soon,
                total: result.soonCount,
                state: .soon
            )

            section(
                title: WarrantyOverviewText.activeTitle(result.activeCount),
                items: result.active,
                total: result.activeCount,
                state: .active
            )

            section(
                title: WarrantyOverviewText.expiredTitle(result.expiredCount),
                items: result.expired,
                total: result.expiredCount,
                state: .expired
            )

            if result.olderCount > 0 {
                Text(WarrantyOverviewText.olderNote(result.olderCount))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        } else {
            DashboardInfoBanner(
                icon: "questionmark.circle.fill",
                message: WarrantyOverviewText.emptyHint,
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }

        methodBanner
    }

    // MARK: Hero

    private func heroCard(_ result: WarrantyOverview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Suivi des garanties")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .accessibilityAddTraits(.isHeader)

                Text(WarrantyOverviewText.headline(result))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(WarrantyOverviewText.summary(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                heroChip(title: "En cours", value: "\(result.coveredCount)")
                heroChip(title: "Montant couvert", value: AppFormat.money(result.protectedAmount))
                heroChip(title: "Bientôt", value: "\(result.soonCount)")
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title + " : " + value))
    }

    // MARK: Warranties

    @ViewBuilder
    private func section(title: String, items: [WarrantyOverviewItem], total: Int, state: WarrantyOverviewState) -> some View {
        if items.isEmpty == false {
            VStack(spacing: 8) {
                DashboardSectionCard(title: title) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            DashboardDivider()
                        }

                        row(item, state: state)
                    }
                }

                if total > items.count {
                    Text(WarrantyOverviewText.partialNote(shown: items.count, total: total))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    private func color(for item: WarrantyOverviewItem, state: WarrantyOverviewState) -> Color {
        switch state {
        case .soon:
            return item.daysLeft <= 7 ? EconomofarUI.danger : EconomofarUI.warning
        case .active:
            return EconomofarUI.success
        case .expired:
            return EconomofarUI.textTertiary
        }
    }

    private func icon(for state: WarrantyOverviewState) -> String {
        switch state {
        case .soon:
            return "exclamationmark.shield.fill"
        case .active:
            return "checkmark.shield.fill"
        case .expired:
            return "shield.slash.fill"
        }
    }

    private func row(_ item: WarrantyOverviewItem, state: WarrantyOverviewState) -> some View {
        let rowColor = color(for: item, state: state)

        return NavigationLink {
            ReceiptDetailView(receiptId: item.id)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                DashboardIconBox(icon: icon(for: state), tint: rowColor)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.merchant)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)
                            .lineLimit(2)

                        Spacer(minLength: 8)

                        if item.amount > 0 {
                            Text(AppFormat.money(item.amount))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(EconomofarUI.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .layoutPriority(1)
                        }
                    }

                    if let note = item.note, note.isEmpty == false {
                        Text(note)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                            .lineLimit(2)
                    }

                    if let purchase = WarrantyOverviewText.purchaseLine(item) {
                        Text(purchase)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                    }

                    Text(WarrantyOverviewText.endLine(item))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(state == .expired ? EconomofarUI.textSecondary : rowColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .padding(.top, 4)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
    }

    // MARK: Method

    private var methodBanner: some View {
        DashboardInfoBanner(
            icon: "info.circle.fill",
            message: "Les dates viennent du champ « Garantie » du détail de chaque ticket (AAAA-MM-JJ). Le montant couvert est le total des tickets dont la garantie n'est pas terminée. Seuls les tickets enregistrés des 10 dernières années sont examinés. Touchez une garantie pour ouvrir son ticket.",
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }
}
