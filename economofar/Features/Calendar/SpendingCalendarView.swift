import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class SpendingCalendarViewModel: ObservableObject {
    @Published var month = SpendingCalendarMonth.containing(Date())
    @Published var selectedKey: String? = nil
    @Published private(set) var days: [String: SpendingCalendarDay] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var loadedMonth: SpendingCalendarMonth? = nil
    @Published private(set) var errorMessage: String? = nil

    let calendar = SpendingCalendarMath.makeCalendar()

    private var generation = 0

    var currentMonth: SpendingCalendarMonth {
        SpendingCalendarMonth.containing(Date())
    }

    /// False while the figures on screen still belong to another month, or when the month could not be loaded.
    var dataIsReady: Bool {
        loadedMonth == month
    }

    var isCurrentMonth: Bool {
        month == currentMonth
    }

    var canGoForward: Bool {
        month.index < currentMonth.index
    }

    var todayKey: String {
        SpendingCalendarMath.todayKey(calendar: calendar)
    }

    var summary: SpendingCalendarSummary {
        SpendingCalendarMath.summary(of: days)
    }

    var maxDayTotal: Double {
        days.values.map { $0.total }.max() ?? 0
    }

    var selectedDay: SpendingCalendarDay? {
        guard let selectedKey else { return nil }
        return days[selectedKey]
    }

    func goTo(_ target: SpendingCalendarMonth) {
        guard target != month, target.index <= currentMonth.index else { return }

        month = target
        days = [:]
        selectedKey = nil
        errorMessage = nil
    }

    /// A future day can only be opened when the server returned tickets for it.
    func select(_ key: String) {
        guard key <= todayKey || days[key] != nil else { return }
        selectedKey = key
    }

    func load(token: String?) async {
        guard let token, !token.isEmpty else { return }

        generation += 1

        let current = generation
        let target = month

        isLoading = true
        errorMessage = nil

        let result: Result<[TicketHistoryReceipt], Error>

        do {
            result = .success(try await SpendingCalendarService.shared.fetch(month: target.key, token: token))
        } catch {
            result = .failure(error)
        }

        guard current == generation, target == month else { return }

        isLoading = false

        switch result {
        case .success(let receipts):
            days = SpendingCalendarMath.aggregate(receipts, in: target)
            loadedMonth = target

            if let key = selectedKey, !key.hasPrefix(target.key + "-") {
                selectedKey = nil
            }

            if selectedKey == nil, target == currentMonth {
                selectedKey = todayKey
            }

        case .failure(let error):
            if Task.isCancelled {
                return
            }

            if let apiError = error as? APIError, case .unauthorized = apiError {
                return
            }

            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Screen

struct SpendingCalendarView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = SpendingCalendarViewModel()

    @State private var showManualEntry = false
    @State private var manualEntryDate: Date? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        ZStack {
            EconomofarUI.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    monthHeader

                    if let errorMessage = viewModel.errorMessage {
                        DashboardInfoBanner(
                            icon: "exclamationmark.triangle.fill",
                            message: errorMessage,
                            tint: EconomofarUI.danger,
                            background: EconomofarUI.dangerSoft
                        )
                        .padding(.horizontal, -20)
                    }

                    summaryCard
                    gridCard
                    detailCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .refreshable {
                await viewModel.load(token: sessionManager.token)
            }
        }
        .navigationTitle("Calendrier")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: viewModel.month) {
            await viewModel.load(token: sessionManager.token)
        }
        .sheet(isPresented: $showManualEntry) {
            ManualTicketView(
                onSaved: {
                    Task {
                        await viewModel.load(token: sessionManager.token)
                    }
                },
                initialDate: manualEntryDate
            )
            .environmentObject(sessionManager)
        }
    }

    // MARK: Month header

    private var monthHeader: some View {
        HStack(spacing: 12) {
            arrowButton(icon: "chevron.left", label: "Mois précédent", enabled: true) {
                viewModel.goTo(viewModel.month.adding(months: -1))
            }

            Spacer()

            VStack(spacing: 4) {
                Text(viewModel.month.title(locale: AppFormat.locale))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                if !viewModel.isCurrentMonth {
                    Button("Revenir à aujourd'hui") {
                        viewModel.goTo(viewModel.currentMonth)
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.accent)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
            }

            Spacer()

            arrowButton(icon: "chevron.right", label: "Mois suivant", enabled: viewModel.canGoForward) {
                viewModel.goTo(viewModel.month.adding(months: 1))
            }
        }
    }

    private func arrowButton(icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(enabled ? EconomofarUI.accent : EconomofarUI.textTertiary)
                .frame(width: 40, height: 40)
                .background(EconomofarUI.card)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(EconomofarUI.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    // MARK: Summary

    private var summaryCard: some View {
        let summary = viewModel.summary

        return VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                metric(title: "Dépensé", value: summaryText(AppFormat.money(summary.total)))
                metric(title: "Tickets", value: summaryText(String(summary.ticketCount)))
                metric(title: "Jours actifs", value: summaryText(String(summary.activeDays)))
            }

            if let top = summary.topDay {
                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(EconomofarUI.warning)

                    Text("Jour le plus cher : \(SpendingCalendarMath.longTitle(forKey: top.key, locale: AppFormat.locale)), \(AppFormat.money(top.total))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
    }

    private func summaryText(_ value: String) -> String {
        if viewModel.dataIsReady {
            return value
        }

        return viewModel.isLoading ? "…" : "—"
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Grid

    private var gridCard: some View {
        let cells = SpendingCalendarMath.cells(for: viewModel.month, calendar: viewModel.calendar)
        let symbols = SpendingCalendarMath.weekdaySymbols(calendar: viewModel.calendar)
        let monthTitle = viewModel.month.title(locale: AppFormat.locale)
        let todayKey = viewModel.todayKey
        let maxTotal = viewModel.maxDayTotal

        return VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(symbols.enumerated()), id: \.offset) { entry in
                    Text(entry.element)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(cells) { cell in
                    dayCell(cell, monthTitle: monthTitle, todayKey: todayKey, maxTotal: maxTotal)
                }
            }

            HStack {
                Text("Montants en \(AppFormat.currencyCode). Plus la case est foncée, plus la dépense est élevée.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            if viewModel.isLoading {
                ProgressView()
            }
        }
        .padding(14)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func dayCell(
        _ cell: SpendingCalendarCell,
        monthTitle: String,
        todayKey: String,
        maxTotal: Double
    ) -> some View {
        if let day = cell.day, let key = cell.key {
            dayButton(day: day, key: key, monthTitle: monthTitle, todayKey: todayKey, maxTotal: maxTotal)
        } else {
            Color.clear
                .frame(height: 52)
        }
    }

    private func dayButton(
        day: Int,
        key: String,
        monthTitle: String,
        todayKey: String,
        maxTotal: Double
    ) -> some View {
        let entry = viewModel.days[key]
        let total = entry?.total ?? 0
        let ticketCount = entry?.tickets.count ?? 0
        let hasTickets = ticketCount > 0
        let intensity = SpendingCalendarMath.intensity(total: total, maxTotal: maxTotal)
        let isSelected = viewModel.selectedKey == key
        let isToday = key == todayKey
        let isFuture = key > todayKey

        return Button {
            viewModel.select(key)
        } label: {
            VStack(spacing: 3) {
                Text(String(day))
                    .font(.system(size: 13, weight: isToday ? .heavy : .semibold, design: .rounded))
                    .foregroundColor(isToday ? EconomofarUI.accentDark : EconomofarUI.textPrimary)

                Text(SpendingCalendarMath.compactAmount(total))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .opacity(hasTickets ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(hasTickets ? EconomofarUI.accent.opacity(0.10 + 0.35 * intensity) : EconomofarUI.cardSoft)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? EconomofarUI.accent : Color.clear, lineWidth: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isFuture && !hasTickets ? 0.35 : 1)
        .disabled(isFuture && !hasTickets)
        .accessibilityLabel(
            hasTickets
                ? "\(day) \(monthTitle), \(AppFormat.money(total)), \(ticketCount) ticket\(ticketCount > 1 ? "s" : "")"
                : "\(day) \(monthTitle), aucune dépense"
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Day details

    @ViewBuilder
    private var detailCard: some View {
        if let key = viewModel.selectedKey {
            let day = viewModel.selectedDay
            let tickets = day?.tickets ?? []

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(SpendingCalendarMath.longTitle(forKey: key, locale: AppFormat.locale))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Spacer()

                    Text(AppFormat.money(day?.total ?? 0))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                }

                if !viewModel.dataIsReady {
                    Text(viewModel.isLoading ? "Chargement…" : "Les dépenses de ce mois n'ont pas pu être chargées.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                } else if tickets.isEmpty {
                    Text("Aucune dépense enregistrée ce jour-là.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(tickets) { ticket in
                            ticketRow(ticket)

                            if ticket.id != tickets.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                if key <= viewModel.todayKey {
                    Button {
                        manualEntryDate = SpendingCalendarMath.date(forKey: key)
                        showManualEntry = true
                    } label: {
                        Label("Ajouter un achat ce jour-là", systemImage: "square.and.pencil")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(EconomofarUI.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(EconomofarUI.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        } else {
            Text("Touchez un jour pour voir ses tickets.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
    }

    private func ticketRow(_ ticket: TicketHistoryReceipt) -> some View {
        NavigationLink {
            ReceiptDetailView(receiptId: ticket.id)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ticket.displayMerchant)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(1)

                    Text("\(ticket.displayCategory) · \(ticket.displayPaymentMethod)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(ticket.displayAmount)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
