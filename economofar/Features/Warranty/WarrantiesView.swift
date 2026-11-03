import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class WarrantiesViewModel: ObservableObject {
    @Published var items: [Warranty] = []
    @Published var isLoading = false
    @Published var hasLoaded = false
    @Published var errorMessage: String? = nil

    var expiring: [Warranty] {
        items.filter { $0.status == "expiring" }
    }

    var active: [Warranty] {
        items.filter { $0.status == "active" }
    }

    var expired: [Warranty] {
        items.filter { $0.status == "expired" }
    }

    func load(token: String?) async {
        guard let token, !token.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            items = try await WarrantyService.shared.fetchAll(token: token)
            hasLoaded = true
            await WarrantyReminders.sync(items)
        } catch APIError.unauthorized {
            // The session manager logs the user out
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Returns an error message, or nil when everything went fine.
    func add(ticketId: String, months: Int, token: String?) async -> String? {
        guard let token, !token.isEmpty else { return nil }

        do {
            try await WarrantyService.shared.setWarranty(ticketId: ticketId, months: months, token: token)
        } catch APIError.unauthorized {
            return nil
        } catch {
            return error.localizedDescription
        }

        await load(token: token)
        return nil
    }

    func remove(ticketId: String, token: String?) async {
        guard let token, !token.isEmpty else { return }

        do {
            try await WarrantyService.shared.clearWarranty(ticketId: ticketId, token: token)
        } catch APIError.unauthorized {
            return
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        await load(token: token)
    }
}

// MARK: - Screen

struct WarrantiesView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = WarrantiesViewModel()

    @State private var showEditor = false
    @State private var warrantyToRemove: Warranty? = nil

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

                    if viewModel.items.isEmpty {
                        if viewModel.hasLoaded {
                            emptyState
                        } else if viewModel.isLoading {
                            ProgressView()
                                .padding(.top, 50)
                        }
                    } else {
                        section(title: "Bientôt terminées", items: viewModel.expiring)
                        section(title: "En cours", items: viewModel.active)
                        section(title: "Terminées", items: viewModel.expired)
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
        .navigationTitle("Garanties")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await viewModel.load(token: sessionManager.token)
        }
        .sheet(isPresented: $showEditor) {
            WarrantyEditor(
                token: sessionManager.token,
                onSave: { ticketId, months in
                    await viewModel.add(ticketId: ticketId, months: months, token: sessionManager.token)
                }
            )
        }
        .confirmationDialog(
            "Supprimer cette garantie ?",
            isPresented: Binding(
                get: { warrantyToRemove != nil },
                set: { newValue in
                    if !newValue {
                        warrantyToRemove = nil
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: warrantyToRemove
        ) { warranty in
            Button("Supprimer", role: .destructive) {
                Task {
                    await viewModel.remove(ticketId: warranty.ticketId, token: sessionManager.token)
                }
            }

            Button("Annuler", role: .cancel) { }
        } message: { _ in
            Text("Le ticket reste dans votre historique, seule la date de garantie est retirée.")
        }
    }

    // MARK: Pieces

    private var introText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ne ratez plus une fin de garantie")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text("Ajoutez la garantie d'un achat : l'iPhone vous prévient 30 jours puis 7 jours avant la fin. La date peut aussi se modifier dans le détail du ticket.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func section(title: String, items: [Warranty]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)

                ForEach(items) { item in
                    warrantyCard(item)
                }
            }
        }
    }

    private func tint(for warranty: Warranty) -> Color {
        switch warranty.status {
        case "expired":
            return EconomofarUI.danger
        case "expiring":
            return EconomofarUI.warning
        default:
            return EconomofarUI.success
        }
    }

    private func warrantyCard(_ warranty: Warranty) -> some View {
        let color = tint(for: warranty)

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(warranty.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)

                if let note = warranty.note {
                    Text(note)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .lineLimit(2)
                }

                if let purchase = warranty.purchaseDateText {
                    Text("Acheté le \(purchase)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textTertiary)
                }

                Text("Fin de garantie : \(warranty.endDateText)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                Text(warranty.remainingText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())

                Button {
                    warrantyToRemove = warranty
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EconomofarUI.textTertiary)
                }
                .buttonStyle(.plain)
            }
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
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(EconomofarUI.accent)

            Text("Aucune garantie suivie")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text("Appuyez sur + pour choisir un achat (téléphone, électroménager...) et indiquer la durée de sa garantie.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
        .padding(.horizontal, 12)
    }
}

// MARK: - Editor sheet

struct WarrantyEditor: View {
    @Environment(\.dismiss) private var dismiss

    let token: String?
    let onSave: (String, Int) async -> String?

    @State private var candidates: [WarrantyCandidate] = []
    @State private var selectedTicketId = ""
    @State private var months = 24
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private let durations = [3, 6, 12, 24, 36, 48, 60, 120]

    init(token: String?, onSave: @escaping (String, Int) async -> String?) {
        self.token = token
        self.onSave = onSave
    }

    private var selectedCandidate: WarrantyCandidate? {
        candidates.first { $0.ticketId == selectedTicketId }
    }

    private var endDatePreview: String? {
        guard let candidate = selectedCandidate,
              let purchase = WarrantyDates.parse(candidate.purchaseDate),
              let end = WarrantyDates.addMonths(months, to: purchase) else {
            return nil
        }

        return WarrantyDates.display(end)
    }

    private func durationLabel(_ value: Int) -> String {
        if value % 12 == 0 {
            let years = value / 12
            return years == 1 ? "1 an" : "\(years) ans"
        }

        return "\(value) mois"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EconomofarUI.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else if candidates.isEmpty {
                            Text("Aucun achat récent sans garantie. Enregistrez d'abord un ticket, ou modifiez la date de garantie dans le détail d'un ticket.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(EconomofarUI.textSecondary)
                        } else {
                            purchaseField
                            durationField
                        }

                        if let errorMessage {
                            DashboardInfoBanner(
                                icon: "exclamationmark.triangle.fill",
                                message: errorMessage,
                                tint: EconomofarUI.danger,
                                background: EconomofarUI.dangerSoft
                            )
                            .padding(.horizontal, -20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Nouvelle garantie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await save()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Enregistrer")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(selectedTicketId.isEmpty || isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
            .task {
                await loadCandidates()
            }
        }
    }

    // MARK: Fields

    private var purchaseField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Achat", systemImage: "bag")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            fieldBox {
                Picker("Achat", selection: $selectedTicketId) {
                    ForEach(candidates) { candidate in
                        Text(candidate.label).tag(candidate.ticketId)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(EconomofarUI.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var durationField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Durée de la garantie", systemImage: "calendar.badge.checkmark")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            fieldBox {
                Picker("Durée", selection: $months) {
                    ForEach(durations, id: \.self) { value in
                        Text(durationLabel(value)).tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(EconomofarUI.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let endDatePreview {
                Text("Fin de garantie : \(endDatePreview)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.accent)
            }
        }
    }

    private func fieldBox<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(EconomofarUI.cardSoft)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
    }

    // MARK: Actions

    private func loadCandidates() async {
        guard let token, !token.isEmpty else {
            isLoading = false
            return
        }

        do {
            candidates = try await WarrantyService.shared.fetchCandidates(token: token)
            selectedTicketId = candidates.first?.ticketId ?? ""
        } catch APIError.unauthorized {
            // The session manager logs the user out
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func save() async {
        guard !selectedTicketId.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        let result = await onSave(selectedTicketId, months)

        isSaving = false

        if let result {
            errorMessage = result
        } else {
            dismiss()
        }
    }
}
