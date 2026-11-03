import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class BusinessExpensesViewModel: ObservableObject {
    let periodOptions = BusinessPeriodOption.all

    @Published var result: BusinessExpenses? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published private(set) var loadedPeriod: String? = nil

    /// What the business tickets are grouped by. Only changes what the page shows.
    @Published var section: BusinessSectionKind = .reports

    /// Choosing another period shows the spinner at once, before the request starts.
    @Published var period: String = "year" {
        didSet {
            if period != oldValue {
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
        let selectedPeriod = period

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await BusinessExpensesService.shared.fetch(
                token: token,
                period: selectedPeriod
            )

            if current == generation {
                result = fetched
                loadedPeriod = selectedPeriod
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

                // Figures of an earlier day must not be shown as the current ones
                if let loadedAt, !Calendar.current.isDateInToday(loadedAt) {
                    result = nil
                    loadedPeriod = nil
                    self.loadedAt = nil
                }
            }
        }

        if current == generation {
            isLoading = false
        }
    }

    /// The figures were counted on an earlier day: they are read again.
    func reloadIfNewDay(token: String?) async {
        guard let loadedAt, !Calendar.current.isDateInToday(loadedAt) else {
            return
        }

        await load(token: token)
    }

    /// The group with this key in the figures that are loaded now.
    func group(kind: BusinessSectionKind, key: String) -> BusinessGroup? {
        result?.section(kind).groups.first { $0.key == key }
    }
}

// MARK: - Screen

struct BusinessExpensesView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = BusinessExpensesViewModel()

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
                       viewModel.loadedPeriod == viewModel.period {
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
        .navigationTitle("Frais pros")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Also when coming back from a group page: the figures are read again
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }
        .onChange(of: viewModel.period) { _ in
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
        Picker("Période", selection: $viewModel.period) {
            ForEach(viewModel.periodOptions) { option in
                Text(option.title).tag(option.value)
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
    private func content(_ result: BusinessExpenses) -> some View {
        heroCard(result)

        if result.hasBusiness {
            trackCard(result)

            sectionBlock(result)

            methodBanner
        } else {
            DashboardInfoBanner(
                icon: "questionmark.circle.fill",
                message: result.hasTickets ? BusinessExpensesText.noBusinessHint : BusinessExpensesText.emptyHint,
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }
    }

    // MARK: Hero

    private func heroCard(_ result: BusinessExpenses) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Frais pros · " + BusinessExpensesText.periodText(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                Text(BusinessExpensesText.headline(result))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(BusinessExpensesText.summary(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                heroChip(title: "Tickets pros", value: "\(result.ticketCount)")
                heroChip(title: "Toutes dépenses", value: BusinessExpensesText.money(result.allAmount))
                heroChip(title: "Part des dépenses", value: BusinessExpensesText.shareText(result.share))
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

    // MARK: Follow-up

    private func trackCard(_ result: BusinessExpenses) -> some View {
        DashboardSectionCard(title: "Suivi") {
            DashboardInsightRow(
                icon: "checkmark.seal.fill",
                title: "Déductible",
                subtitle: BusinessExpensesText.tickets(result.deductibleCount),
                value: BusinessExpensesText.money(result.deductibleAmount),
                tint: EconomofarUI.success
            )

            DashboardDivider()

            DashboardInsightRow(
                icon: "arrow.uturn.backward.circle.fill",
                title: "Remboursable",
                subtitle: BusinessExpensesText.tickets(result.reimbursableCount),
                value: BusinessExpensesText.money(result.reimbursableAmount),
                tint: EconomofarUI.accent
            )

            DashboardDivider()

            DashboardInsightRow(
                icon: "percent",
                title: "TVA",
                subtitle: BusinessExpensesText.vatDetail(result),
                value: BusinessExpensesText.money(result.vatTotal),
                tint: EconomofarUI.accent
            )
        }
    }

    // MARK: Groups

    private func sectionBlock(_ result: BusinessExpenses) -> some View {
        let kind = viewModel.section
        let section = result.section(kind)

        return VStack(spacing: 8) {
            Picker("Regrouper par", selection: $viewModel.section) {
                ForEach(BusinessSectionKind.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            DashboardSectionCard(title: BusinessExpensesText.listTitle(kind, count: section.groupCount)) {
                ForEach(Array(section.groups.enumerated()), id: \.element.id) { index, group in
                    if index > 0 {
                        DashboardDivider()
                    }

                    groupRow(group, kind: kind, total: result.totalAmount)
                }

                if section.missingCount > 0 {
                    if section.groups.isEmpty == false {
                        DashboardDivider()
                    }

                    missingRow(section, kind: kind)
                }
            }

            if section.hiddenCount > 0 {
                footnote(BusinessExpensesText.hiddenNote(hidden: section.hiddenCount, shown: section.groups.count))
            }
        }
    }

    private func groupRow(_ group: BusinessGroup, kind: BusinessSectionKind, total: Double) -> some View {
        NavigationLink {
            BusinessGroupDetailView(viewModel: viewModel, kind: kind, key: group.key, title: group.name)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                DashboardIconBox(icon: kind.icon, tint: EconomofarUI.accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(2)

                    Text(BusinessExpensesText.rowDetail(group))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    shareBar(BusinessExpensesText.fraction(group.amount, of: total))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(BusinessExpensesText.money(group.amount))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(BusinessExpensesText.groupShareText(group.amount, of: total))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .padding(.top, 4)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(BusinessExpensesText.groupAccessibility(group, total: total)))
        }
        .buttonStyle(.plain)
    }

    private func missingRow(_ section: BusinessSection, kind: BusinessSectionKind) -> some View {
        NavigationLink {
            BusinessGroupDetailView(viewModel: viewModel, kind: kind, key: nil, title: kind.missingTitle)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                DashboardIconBox(icon: "exclamationmark.circle.fill", tint: EconomofarUI.warning)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(kind.missingTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(2)

                    Text(BusinessExpensesText.missingDetail(section))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(BusinessExpensesText.money(section.missingAmount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
    }

    private func shareBar(_ fraction: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(EconomofarUI.accentSoft)

                Capsule()
                    .fill(EconomofarUI.accent)
                    .frame(width: max(proxy.size.width * CGFloat(fraction), fraction > 0 ? 6 : 0))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(EconomofarUI.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    // MARK: Method

    private var methodBanner: some View {
        DashboardInfoBanner(
            icon: "info.circle.fill",
            message: BusinessExpensesText.method,
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }
}
