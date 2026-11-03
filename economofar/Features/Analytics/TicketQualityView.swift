import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class TicketQualityViewModel: ObservableObject {
    static let periods = [3, 6, 12, 24]

    @Published var result: TicketQuality? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published var months = 12

    private var generation = 0
    private var loadedAt: Date? = nil

    func load(token: String?) async {
        guard let token, !token.isEmpty else {
            isLoading = false
            return
        }

        generation += 1
        let current = generation

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await TicketQualityService.shared.fetch(token: token, months: months)

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

struct TicketQualityView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = TicketQualityViewModel()

    @State private var filter: String? = nil

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

                    if let result = viewModel.result, result.months == viewModel.months {
                        content(result)
                    } else if showsSpinner {
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
        .navigationTitle("Tickets à vérifier")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(token: sessionManager.token)
        }
        .onChange(of: viewModel.months) { _ in
            filter = nil

            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }
    }

    // MARK: Controls

    private var periodPicker: some View {
        Picker("Période", selection: $viewModel.months) {
            ForEach(TicketQualityViewModel.periods, id: \.self) { months in
                Text(QualityText.periodTitle(months)).tag(months)
            }
        }
        .pickerStyle(.segmented)
    }

    private var showsSpinner: Bool {
        if viewModel.isLoading {
            return true
        }

        return viewModel.errorMessage == nil && viewModel.result != nil
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
    private func content(_ result: TicketQuality) -> some View {
        heroCard(result)

        if result.examined == 0 {
            DashboardInfoBanner(
                icon: "info.circle.fill",
                message: "Aucun ticket enregistré sur cette période.",
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        } else if result.flaggedCount == 0 {
            DashboardInfoBanner(
                icon: "checkmark.seal.fill",
                message: "Tout est en ordre : aucun ticket à vérifier sur cette période.",
                tint: EconomofarUI.success,
                background: EconomofarUI.successSoft
            )
            .padding(.horizontal, -20)
        } else {
            filterSection(result)

            ticketsSection(result)

            methodBanner
        }
    }

    // MARK: Hero

    private func heroCard(_ result: TicketQuality) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Qualité des tickets")
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
                heroChip(title: "Tickets", value: "\(result.examined)")
                heroChip(title: "À vérifier", value: "\(result.flaggedCount)")
                heroChip(title: "En ordre", value: "\(result.okCount)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func headline(_ result: TicketQuality) -> String {
        if result.examined == 0 {
            return "Aucun ticket"
        }

        if result.flaggedCount == 0 {
            return "Tout est en ordre"
        }

        return "\(QualityText.ticketCount(result.flaggedCount)) à vérifier"
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

    // MARK: Filter

    private func activeFilter(_ result: TicketQuality) -> String? {
        guard let filter else { return nil }

        return typeCount(result, filter) > 0 ? filter : nil
    }

    private func typeCount(_ result: TicketQuality, _ type: String) -> Int {
        result.counts.first(where: { $0.type == type })?.count ?? 0
    }

    private func filterSection(_ result: TicketQuality) -> some View {
        let selected = activeFilter(result)

        return VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "Tous", count: result.flaggedCount, isSelected: selected == nil) {
                        filter = nil
                    }

                    ForEach(result.counts.filter { $0.count > 0 }) { item in
                        filterChip(
                            title: QualityText.title(item.type),
                            count: item.count,
                            isSelected: selected == item.type
                        ) {
                            filter = item.type
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)

            if let selected {
                Text(QualityText.explanation(selected))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func filterChip(title: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("\(title) · \(count)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? Color.white : EconomofarUI.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isSelected ? EconomofarUI.accent : EconomofarUI.card)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? EconomofarUI.accent : EconomofarUI.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Tickets

    private func visibleTickets(_ result: TicketQuality) -> [QualityTicket] {
        guard let selected = activeFilter(result) else { return result.tickets }

        return result.tickets.filter { $0.issues.contains(selected) }
    }

    @ViewBuilder
    private func ticketsSection(_ result: TicketQuality) -> some View {
        let visible = visibleTickets(result)

        if visible.isEmpty {
            DashboardInfoBanner(
                icon: "info.circle.fill",
                message: result.flaggedCount > result.tickets.count
                    ? "Parmi les \(result.tickets.count) tickets les plus récents listés, aucun n'a ce problème. Les plus anciens ne sont pas listés."
                    : "Aucun ticket n'a ce problème.",
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        } else {
            VStack(spacing: 12) {
                DashboardSectionCard(title: QualityText.ticketCount(visible.count)) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, ticket in
                        if index > 0 {
                            Divider()
                                .background(EconomofarUI.border)
                                .padding(.leading, 76)
                        }

                        ticketRow(ticket)
                    }
                }

                if result.flaggedCount > result.tickets.count {
                    Text(truncationNote(result, shown: visible.count))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textTertiary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func truncationNote(_ result: TicketQuality, shown: Int) -> String {
        if let selected = activeFilter(result) {
            return "Les plus récents seulement : \(shown) sur \(typeCount(result, selected))."
        }

        return "Les \(result.tickets.count) plus récents sur \(result.flaggedCount)."
    }

    private func tint(for type: String) -> Color {
        switch type {
        case "MISSING_AMOUNT", "FUTURE_DATE":
            return EconomofarUI.danger
        case "DUPLICATE":
            return EconomofarUI.warning
        default:
            return EconomofarUI.accent
        }
    }

    private func ticketRow(_ ticket: QualityTicket) -> some View {
        let first = ticket.issues.first ?? ""
        let issuesText = ticket.issues.map { QualityText.title($0) }.joined(separator: " · ")
        let amountText = ticket.amount.map { AppFormat.money($0) } ?? "Montant manquant"
        let noAmount = (ticket.amount ?? 0) <= 0
        let dateText = WeeklyDigestText.format(ticket.date, pattern: "d MMM yyyy")

        return NavigationLink {
            ReceiptDetailView(receiptId: ticket.id)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                DashboardIconBox(icon: QualityText.icon(first), tint: tint(for: first))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(ticket.merchant)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)
                            .lineLimit(2)

                        Spacer(minLength: 8)

                        Text(amountText)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(noAmount ? EconomofarUI.danger : EconomofarUI.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .layoutPriority(1)
                    }

                    Text("\(dateText) · \(ticket.category)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .lineLimit(2)

                    Text(issuesText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(tint(for: first))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .padding(.top, 4)
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
            message: "Touchez un ticket pour le corriger ou le supprimer. Un doublon possible n'est pas forcément une erreur : deux achats identiques le même jour dans le même commerce peuvent être réels. Seuls les tickets enregistrés de la période choisie sont examinés.",
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }
}
