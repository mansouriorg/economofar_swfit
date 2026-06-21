import SwiftUI

// MARK: - Advanced History View

struct AdvancedHistoryView: View {
    @EnvironmentObject var sessionManager: SessionManager

    @State private var filter = TicketHistoryFilter()
    @State private var viewMode: TicketHistoryViewMode = .grouped

    @State private var receipts: [TicketHistoryReceipt] = []
    @State private var groups: [TicketHistoryGroup] = []

    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showFilters = false

    private let service = TicketHistoryService.shared

    private var hasResults: Bool {
        switch viewMode {
        case .list:
            return !receipts.isEmpty
        case .grouped:
            return !groups.isEmpty
        }
    }

    var body: some View {
        ZStack {
            EconomofarUI.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection

                if let errorMessage {
                    DashboardInfoBanner(
                        icon: "exclamationmark.triangle.fill",
                        message: errorMessage,
                        tint: EconomofarUI.danger,
                        background: EconomofarUI.dangerSoft
                    )
                    .padding(.top, 12)
                }

                if isLoading && !hasResults {
                    loadingView
                } else if !hasResults {
                    emptyHistoryView
                } else {
                    resultsView
                }
            }
        }
        .navigationTitle("Historique")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(EconomofarUI.accent)

                        if filter.hasActiveFilters {
                            Circle()
                                .fill(EconomofarUI.danger)
                                .frame(width: 8, height: 8)
                                .offset(x: 3, y: -3)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            HistoryFiltersSheet(
                filter: $filter,
                viewMode: $viewMode,
                onApply: {
                    showFilters = false
                    Task {
                        await loadHistory()
                    }
                },
                onReset: {
                    filter = TicketHistoryFilter()
                    viewMode = .grouped
                    showFilters = false

                    Task {
                        await loadHistory()
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task {
            await loadHistory()
        }
        .refreshable {
            await loadHistory()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Historique avancé")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)

                        Text("Filtrez, triez et regroupez vos reçus.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                    }

                    Spacer()

                    if isLoading {
                        ProgressView()
                            .tint(EconomofarUI.accent)
                    }
                }

                Picker("Mode", selection: $viewMode) {
                    ForEach(TicketHistoryViewMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewMode) { _ in
                    Task {
                        await loadHistory()
                    }
                }
            }
            .padding(18)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }

            quickSearchBar
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var quickSearchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(EconomofarUI.textSecondary)

            TextField("Rechercher un marchand...", text: $filter.merchant)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .submitLabel(.search)
                .onSubmit {
                    Task {
                        await loadHistory()
                    }
                }

            if !filter.merchant.isEmpty {
                Button {
                    filter.merchant = ""
                    Task {
                        await loadHistory()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(EconomofarUI.textTertiary)
                }
            }
        }
        .padding(15)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                summaryCard

                switch viewMode {
                case .list:
                    ForEach(receipts) { receipt in
                        HistoryReceiptRow(receipt: receipt)
                    }

                case .grouped:
                    ForEach(groups) { group in
                        HistoryGroupCard(group: group)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var summaryCard: some View {
        let count = viewMode == .list
        ? receipts.count
        : groups.reduce(0) { $0 + ($1.ticketCount ?? $1.safeTickets.count) }

        let total = viewMode == .list
        ? receipts.reduce(0.0) { $0 + ($1.totalAmount ?? 0.0) }
        : groups.reduce(0.0) { $0 + ($1.totalAmount ?? 0.0) }

        return HStack(spacing: 14) {
            DashboardIconBox(
                icon: viewMode == .list ? "list.bullet.rectangle" : filter.groupBy.icon,
                tint: EconomofarUI.accent
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("\(count) ticket\(count > 1 ? "s" : "")")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Text(viewMode == .list ? "Résultat de recherche" : filter.groupBy.title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
            }

            Spacer()

            Text(String(format: "%.2f €", total))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.accent)
        }
        .padding(16)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 18) {
            Spacer()

            ProgressView()
                .tint(EconomofarUI.accent)
                .scaleEffect(1.2)

            Text("Chargement de l’historique...")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyHistoryView: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(EconomofarUI.accentSoft)
                    .frame(width: 86, height: 86)

                Image(systemName: "receipt")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
            }

            VStack(spacing: 8) {
                Text("Aucun résultat")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Text("Essayez de modifier vos filtres ou de scanner un nouveau ticket.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
            }

            if filter.hasActiveFilters {
                Button {
                    filter = TicketHistoryFilter()
                    Task {
                        await loadHistory()
                    }
                } label: {
                    Text("Réinitialiser les filtres")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 18)
                        .background(EconomofarUI.accent)
                        .clipShape(Capsule())
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loading

    private func loadHistory() async {
        guard let token = sessionManager.token else {
            errorMessage = "Session expirée. Veuillez vous reconnecter."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            switch viewMode {
            case .list:
                receipts = try await service.searchHistory(
                    filter: filter,
                    token: token
                )

            case .grouped:
                groups = try await service.groupedHistory(
                    filter: filter,
                    token: token
                )
            }

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Filters Sheet

struct HistoryFiltersSheet: View {
    @Binding var filter: TicketHistoryFilter
    @Binding var viewMode: TicketHistoryViewMode

    let onApply: () -> Void
    let onReset: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                EconomofarUI.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        sectionCard(title: "Affichage") {
                            VStack(spacing: 14) {
                                Picker("Mode", selection: $viewMode) {
                                    ForEach(TicketHistoryViewMode.allCases) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Picker("Regrouper", selection: $filter.groupBy) {
                                    ForEach(TicketHistoryGroupOption.allCases) { option in
                                        Label(option.title, systemImage: option.icon).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                .disabled(viewMode != .grouped)
                                .opacity(viewMode == .grouped ? 1 : 0.45)

                                Picker("Trier", selection: $filter.sortBy) {
                                    ForEach(TicketHistorySortOption.allCases) { option in
                                        Label(option.title, systemImage: option.icon).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }

                        sectionCard(title: "Dates") {
                            VStack(spacing: 14) {
                                HistoryTextField(
                                    title: "Date début",
                                    placeholder: "YYYY-MM-DD",
                                    icon: "calendar",
                                    text: $filter.fromDate
                                )

                                HistoryTextField(
                                    title: "Date fin",
                                    placeholder: "YYYY-MM-DD",
                                    icon: "calendar.badge.clock",
                                    text: $filter.toDate
                                )

                                HistoryTextField(
                                    title: "Mois",
                                    placeholder: "YYYY-MM",
                                    icon: "calendar.circle",
                                    text: $filter.month
                                )
                            }
                        }

                        sectionCard(title: "Recherche") {
                            VStack(spacing: 14) {
                                HistoryTextField(
                                    title: "Marchand",
                                    placeholder: "Carrefour, Monoprix...",
                                    icon: "storefront",
                                    text: $filter.merchant
                                )

                                HStack(spacing: 12) {
                                    HistoryTextField(
                                        title: "Montant min",
                                        placeholder: "0",
                                        icon: "arrow.down",
                                        text: $filter.minAmount,
                                        keyboardType: .decimalPad
                                    )

                                    HistoryTextField(
                                        title: "Montant max",
                                        placeholder: "100",
                                        icon: "arrow.up",
                                        text: $filter.maxAmount,
                                        keyboardType: .decimalPad
                                    )
                                }
                            }
                        }

                        sectionCard(title: "Catégories") {
                            VStack(spacing: 14) {
                                pickerRow(
                                    title: "Catégorie",
                                    icon: "tag",
                                    selection: $filter.category,
                                    values: ["Tous"] + EconomofarCategories.all.filter { $0 != "Tous" }
                                )

                                pickerRow(
                                    title: "Paiement",
                                    icon: "creditcard",
                                    selection: $filter.paymentMethod,
                                    values: TicketPaymentMethodOptions.all
                                )

                                scanStatusPicker
                            }
                        }

                        HStack(spacing: 12) {
                            Button {
                                onReset()
                            } label: {
                                Text("Réinitialiser")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(EconomofarUI.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .background(EconomofarUI.accentSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }

                            Button {
                                onApply()
                            } label: {
                                Text("Appliquer")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .background(EconomofarUI.mainGradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Filtres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        onApply()
                    }
                }
            }
        }
    }

    private var scanStatusPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Statut du scan", systemImage: "checklist")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            Picker("Statut", selection: $filter.scanStatus) {
                ForEach(TicketScanStatusOptions.all, id: \.self) { status in
                    Text(TicketScanStatusOptions.displayTitle(status)).tag(status)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(EconomofarUI.cardSoft)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 4)

            VStack(spacing: 14) {
                content()
            }
            .padding(16)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
    }

    private func pickerRow(
        title: String,
        icon: String,
        selection: Binding<String>,
        values: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { value in
                    Text(value).tag(value)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(EconomofarUI.cardSoft)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
    }
}

// MARK: - History Text Field

struct HistoryTextField: View {
    let title: String
    let placeholder: String
    let icon: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .textInputAutocapitalization(.never)
                .padding()
                .background(EconomofarUI.cardSoft)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(EconomofarUI.border, lineWidth: 1)
                }
        }
    }
}

// MARK: - Receipt Row

struct HistoryReceiptRow: View {
    let receipt: TicketHistoryReceipt

    private var statusTint: Color {
        switch receipt.scanStatus {
        case .saved:
            return EconomofarUI.success
        case .failed:
            return EconomofarUI.danger
        case .needsReview, .ocrCompleted:
            return EconomofarUI.warning
        case .uploading, .analyzing:
            return EconomofarUI.accent
        case .idle, .none:
            return EconomofarUI.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(EconomofarUI.accentSoft)
                    .frame(width: 50, height: 50)

                Image(systemName: "receipt")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(receipt.displayMerchant)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Label(receipt.displayDate, systemImage: "calendar")
                    Text("•")
                    Text(receipt.displayCategory)
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .lineLimit(1)

                HStack(spacing: 6) {
                    Text(receipt.displayPaymentMethod)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(EconomofarUI.cardSoft)
                        .clipShape(Capsule())

                    if let status = receipt.scanStatus {
                        Text(status.title)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(statusTint)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(statusTint.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            Text(receipt.displayAmount)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .lineLimit(1)
        }
        .padding(16)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }
}

// MARK: - Group Card

struct HistoryGroupCard: View {
    let group: TicketHistoryGroup
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    DashboardIconBox(
                        icon: "folder",
                        tint: EconomofarUI.accent
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.displayTitle)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)

                        Text(group.displayCount)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 5) {
                        Text(group.displayTotal)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(EconomofarUI.accent)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(EconomofarUI.textTertiary)
                    }
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 10) {
                    ForEach(group.safeTickets) { receipt in
                        HistoryReceiptRow(receipt: receipt)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AdvancedHistoryView()
            .environmentObject(SessionManager())
    }
}
