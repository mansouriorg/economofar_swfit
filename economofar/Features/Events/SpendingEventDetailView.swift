import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class SpendingEventDetailViewModel: ObservableObject {
    @Published var detail: SpendingEventDetail? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published var actionMessage: String? = nil
    @Published var isWorking = false

    let eventId: Int

    private var generation = 0
    private var loadedAt: Date? = nil

    init(eventId: Int) {
        self.eventId = eventId
    }

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
            let result = try await SpendingEventsService.shared.fetchDetail(token: token, id: eventId)

            if current == generation {
                detail = result
                loadedAt = Date()
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
                    detail = nil
                    self.loadedAt = nil
                }
            }
        }

        if current == generation {
            isLoading = false
        }
    }

    /// Runs one change on the server. True when it went through.
    private func perform(token: String?, _ work: (String) async throws -> Void) async -> Bool {
        guard let token, !token.isEmpty else {
            actionMessage = "Votre session a expiré. Reconnectez-vous."
            return false
        }

        if isWorking {
            return false
        }

        isWorking = true
        actionMessage = nil

        defer {
            isWorking = false
        }

        do {
            try await work(token)
            return true
        } catch APIError.unauthorized {
            actionMessage = "Votre session a expiré. Reconnectez-vous."
            return false
        } catch {
            actionMessage = error.localizedDescription
            return false
        }
    }

    /// Archives the event or brings it back. The other fields are sent as they are.
    func setArchived(_ archived: Bool, token: String?) async -> Bool {
        guard let event = detail?.event else {
            return false
        }

        let body = SpendingEventBody(
            name: event.name,
            icon: event.icon,
            budget: event.budget,
            startDate: event.startDate,
            endDate: event.endDate,
            archived: archived
        )

        let id = eventId
        let done = await perform(token: token) { token in
            try await SpendingEventsService.shared.update(token: token, id: id, body: body)
        }

        if done {
            await load(token: token)
        }

        return done
    }

    func remove(ticket: SpendingEventTicket, token: String?) async -> Bool {
        let id = eventId
        let done = await perform(token: token) { token in
            try await SpendingEventsService.shared.detach(token: token, id: id, ticketId: ticket.id)
        }

        if done {
            await load(token: token)
        }

        return done
    }

    func delete(token: String?) async -> Bool {
        let id = eventId

        return await perform(token: token) { token in
            try await SpendingEventsService.shared.delete(token: token, id: id)
        }
    }
}

// MARK: - Screen

struct SpendingEventDetailView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SpendingEventDetailViewModel

    let line: SpendingEventLine
    let onChange: () -> Void

    @State private var showingEdit = false
    @State private var showingPicker = false
    @State private var confirmingDelete = false
    @State private var ticketToRemove: SpendingEventTicket? = nil

    init(line: SpendingEventLine, onChange: @escaping () -> Void) {
        self.line = line
        self.onChange = onChange
        _viewModel = StateObject(wrappedValue: SpendingEventDetailViewModel(eventId: line.id))
    }

    /// The event as the server holds it now, or as the list had it until the answer comes.
    private var current: SpendingEventLine {
        viewModel.detail?.event ?? line
    }

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

                    if let actionMessage = viewModel.actionMessage {
                        DashboardInfoBanner(
                            icon: "exclamationmark.triangle.fill",
                            message: actionMessage,
                            tint: EconomofarUI.danger,
                            background: EconomofarUI.dangerSoft
                        )
                        .padding(.horizontal, -20)
                    }

                    if let detail = viewModel.detail {
                        content(detail)
                    } else if viewModel.isLoading {
                        heroCard(line)

                        ProgressView()
                            .padding(.top, 30)
                    } else {
                        heroCard(line)

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
            .confirmationDialog(
                "Retirer ce ticket de l'événement ?",
                isPresented: Binding(
                    get: { ticketToRemove != nil },
                    set: { shown in
                        if !shown {
                            ticketToRemove = nil
                        }
                    }
                ),
                titleVisibility: .visible,
                presenting: ticketToRemove
            ) { ticket in
                Button("Retirer", role: .destructive) {
                    Task {
                        if await viewModel.remove(ticket: ticket, token: sessionManager.token) {
                            onChange()
                        }
                    }
                }

                Button("Annuler", role: .cancel) {}
            } message: { ticket in
                Text("Le ticket de \(ticket.merchant) n'est pas supprimé : il redevient libre.")
            }
        }
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEdit = true
                    } label: {
                        Label("Modifier", systemImage: "pencil")
                    }

                    Button {
                        toggleArchive()
                    } label: {
                        Label(
                            current.archived ? "Sortir des archives" : "Archiver",
                            systemImage: current.archived ? "tray.and.arrow.up" : "archivebox"
                        )
                    }

                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Supprimer l'événement", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(viewModel.isWorking)
                .accessibilityLabel(Text("Actions de l'événement"))
            }
        }
        .sheet(isPresented: $showingEdit) {
            SpendingEventFormView(event: current) {
                reload()
            }
        }
        .sheet(isPresented: $showingPicker) {
            SpendingEventTicketPickerView(eventId: current.id, eventName: current.name) {
                reload()
            }
        }
        .confirmationDialog(
            "Supprimer cet événement ?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Supprimer l'événement", role: .destructive) {
                Task {
                    if await viewModel.delete(token: sessionManager.token) {
                        onChange()
                        dismiss()
                    }
                }
            }

            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Ses tickets ne sont pas supprimés : ils redeviennent libres.")
        }
        .task {
            await viewModel.load(token: sessionManager.token)
        }
    }

    private func reload() {
        Task {
            await viewModel.load(token: sessionManager.token)
            onChange()
        }
    }

    private func toggleArchive() {
        Task {
            if await viewModel.setArchived(!current.archived, token: sessionManager.token) {
                onChange()
            }
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
    private func content(_ detail: SpendingEventDetail) -> some View {
        heroCard(detail.event)

        if detail.event.hasBudget {
            budgetCard(detail.event)
        }

        addTicketsButton

        if detail.tickets.isEmpty {
            emptyCard
        } else {
            if !detail.categories.isEmpty {
                categoriesCard(detail)
            }

            if !detail.merchants.isEmpty {
                merchantsCard(detail)
            }

            if detail.days.count > 1 {
                daysCard(detail)
            }

            ticketsCard(detail)
        }
    }

    // MARK: Hero

    private func heroCard(_ event: SpendingEventLine) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: SpendingEventIcons.symbol(event.icon))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .accessibilityAddTraits(.isHeader)

                    Text(SpendingEventsText.period(event))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.85))

                    Text(SpendingEventsText.timingTitle(event) + (event.archived ? " · Archivé" : ""))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.85))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(SpendingEventsText.money(event.spent))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(SpendingEventsText.heroSubtitle(event))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                heroChip(title: "Tickets", value: "\(event.ticketCount)")
                heroChip(title: "Jours d'achats", value: "\(event.purchaseDays)")
                heroChip(
                    title: "Par jour",
                    value: event.averagePerDay.map { SpendingEventsText.money($0) } ?? "-"
                )
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

    // MARK: Budget

    private func budgetCard(_ event: SpendingEventLine) -> some View {
        let tint = SpendingEventStyle.tint(event.level)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(SpendingEventsText.stateTitle(event) ?? "Budget")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(tint)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text(SpendingEventsText.percentText(event.usedPercent))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(tint)
            }

            SpendingEventBar(fraction: SpendingEventStyle.fraction(event), tint: tint, height: 10)

            Text(SpendingEventsText.budgetLine(event))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            if let remaining = SpendingEventsText.remainingText(event) {
                budgetNote(remaining)
            }

            if let allowance = SpendingEventsText.allowanceText(event) {
                budgetNote(allowance)
            }

            if let pace = SpendingEventsText.paceText(event) {
                Text(pace)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(event.projectedOver ? EconomofarUI.danger : EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(SpendingEventStyle.soft(event.level))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func budgetNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundColor(EconomofarUI.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Tickets to add

    private var addTicketsButton: some View {
        Button {
            showingPicker = true
        } label: {
            Label(SpendingEventsText.pickerTitle, systemImage: "plus.circle.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(EconomofarUI.mainGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isWorking)
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            DashboardIconBox(icon: "doc.text.magnifyingglass", tint: EconomofarUI.accent)
                .accessibilityHidden(true)

            Text(SpendingEventsText.noTicketsTitle)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text(SpendingEventsText.noTicketsHint)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Categories

    private func categoriesCard(_ detail: SpendingEventDetail) -> some View {
        let biggest = detail.categories.map { $0.spent }.max() ?? 0

        return VStack(spacing: 8) {
            DashboardSectionCard(title: SpendingEventsText.categoriesTitle) {
                ForEach(Array(detail.categories.enumerated()), id: \.element.id) { index, category in
                    if index > 0 {
                        DashboardDivider()
                    }

                    barRow(
                        title: category.name,
                        detail: SpendingEventsText.tickets(category.ticketCount),
                        value: SpendingEventsText.money(category.spent),
                        badge: category.sharePercent.map { SpendingEventsText.percentText($0) },
                        fraction: biggest > 0 ? category.spent / biggest : 0
                    )
                }
            }

            if detail.hiddenCategoryCount > 0 {
                footnote(SpendingEventsText.hiddenCategoriesNote(detail))
            }
        }
    }

    // MARK: Shops

    private func merchantsCard(_ detail: SpendingEventDetail) -> some View {
        let biggest = detail.merchants.map { $0.spent }.max() ?? 0

        return VStack(spacing: 8) {
            DashboardSectionCard(title: SpendingEventsText.merchantsTitle) {
                ForEach(Array(detail.merchants.enumerated()), id: \.element.id) { index, merchant in
                    if index > 0 {
                        DashboardDivider()
                    }

                    barRow(
                        title: merchant.name,
                        detail: SpendingEventsText.tickets(merchant.ticketCount),
                        value: SpendingEventsText.money(merchant.spent),
                        badge: nil,
                        fraction: biggest > 0 ? merchant.spent / biggest : 0
                    )
                }
            }

            if detail.hiddenMerchantCount > 0 {
                footnote(SpendingEventsText.hiddenMerchantsNote(detail))
            }
        }
    }

    // MARK: Days

    private func daysCard(_ detail: SpendingEventDetail) -> some View {
        let biggest = detail.days.map { $0.spent }.max() ?? 0

        return VStack(spacing: 8) {
            DashboardSectionCard(title: SpendingEventsText.daysTitle) {
                ForEach(Array(detail.days.enumerated()), id: \.element.id) { index, day in
                    if index > 0 {
                        DashboardDivider()
                    }

                    barRow(
                        title: SpendingEventsText.dateText(day.date),
                        detail: SpendingEventsText.tickets(day.ticketCount),
                        value: SpendingEventsText.money(day.spent),
                        badge: nil,
                        fraction: biggest > 0 ? day.spent / biggest : 0
                    )
                }
            }

            if detail.hiddenDayCount > 0 {
                footnote(SpendingEventsText.hiddenDaysNote(detail))
            }
        }
    }

    private func barRow(title: String, detail: String, value: String, badge: String?, fraction: Double) -> some View {
        let subtitle: String = badge == nil ? detail : detail + " · " + (badge ?? "")
        let spoken: String = [title, value, subtitle].joined(separator: ", ")

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
            }

            SpendingEventBar(fraction: fraction, tint: EconomofarUI.accent, height: 6)
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spoken))
    }

    // MARK: Tickets

    private func ticketsCard(_ detail: SpendingEventDetail) -> some View {
        VStack(spacing: 8) {
            DashboardSectionCard(title: SpendingEventsText.ticketsTitle) {
                ForEach(Array(detail.tickets.enumerated()), id: \.element.id) { index, ticket in
                    if index > 0 {
                        DashboardDivider()
                    }

                    ticketRow(ticket)
                }
            }

            if detail.hiddenTicketCount > 0 {
                footnote(SpendingEventsText.hiddenTicketsNote(detail))
            }
        }
    }

    private func ticketRow(_ ticket: SpendingEventTicket) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(ticket.merchant)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(2)

                Text(SpendingEventsText.dateText(ticket.date) + " · " + ticket.category)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(SpendingEventsText.money(ticket.amount))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)

            Menu {
                Button(role: .destructive) {
                    ticketToRemove = ticket
                } label: {
                    Label("Retirer de l'événement", systemImage: "minus.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.isWorking)
            .accessibilityLabel(Text("Actions du ticket de \(ticket.merchant)"))
        }
        .padding(16)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(EconomofarUI.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
