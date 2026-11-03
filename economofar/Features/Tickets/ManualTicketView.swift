import SwiftUI
import Combine

// MARK: - Limits shared by the form and the view model

enum ManualTicketRules {
    static let maxMerchantLength = 100
    static let maxNoteLength = 500
    static let maxAmount = 1_000_000.0

    static let earliestDate: Date = {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2000, month: 1, day: 1))
            ?? Date(timeIntervalSince1970: 0)
    }()

    /// The server counts characters as Unicode code points, so the limit is applied to scalars.
    static func limited(_ text: String, to maxLength: Int) -> String {
        guard text.unicodeScalars.count > maxLength else { return text }

        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: text.unicodeScalars.prefix(maxLength))

        return String(scalars)
    }
}

// MARK: - View model

@MainActor
final class ManualTicketViewModel: ObservableObject {
    @Published var merchantName = ""
    @Published var amountText = ""
    @Published var date = Date()
    @Published var category = "Alimentation"
    @Published var paymentMethod = "Espèces"
    @Published var note = ""
    @Published var isSaving = false
    @Published var errorMessage: String? = nil
    @Published var duplicateMessage: String? = nil

    @Published private var suggestion: MerchantSuggestion? = nil
    @Published private var suggestionFor = ""

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: Cleaned values

    var cleanName: String {
        merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanNote: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var parsedAmount: Double? {
        let cleaned = amountText
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")

        guard let value = Double(cleaned), value.isFinite, value > 0, value <= ManualTicketRules.maxAmount else {
            return nil
        }

        let rounded = (value * 100).rounded() / 100

        return rounded > 0 ? rounded : nil
    }

    var amountLooksWrong: Bool {
        !amountText.trimmingCharacters(in: .whitespaces).isEmpty && parsedAmount == nil
    }

    var canSave: Bool {
        !cleanName.isEmpty && parsedAmount != nil && !isSaving
    }

    var categories: [String] {
        var list = EconomofarCategories.all

        if !list.contains(category) {
            list.append(category)
        }

        return list
    }

    var paymentMethods: [String] {
        var list = EconomofarPaymentMethods.all

        if !list.contains(paymentMethod) {
            list.append(paymentMethod)
        }

        return list
    }

    // MARK: Habits of the user for this shop

    var suggestionSummary: String? {
        guard let suggestion, suggestionFor == cleanName else { return nil }

        let parts = [suggestion.category, suggestion.paymentMethod]
            .compactMap { Self.clean($0) }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func refreshSuggestion(token: String?) async {
        let name = cleanName

        guard name.count >= 2, let token, !token.isEmpty else {
            suggestion = nil
            return
        }

        try? await Task.sleep(nanoseconds: 600_000_000)

        guard !Task.isCancelled else { return }

        let found = await MerchantSuggestionService.shared.fetch(merchant: name, token: token)

        guard !Task.isCancelled else { return }

        suggestion = found
        suggestionFor = name
    }

    func applySuggestion() {
        guard let suggestion, suggestionFor == cleanName else { return }

        if let value = Self.clean(suggestion.category) {
            category = EconomofarCategories.all.first(where: {
                $0.caseInsensitiveCompare(value) == .orderedSame
            }) ?? value
        }

        if let value = Self.clean(suggestion.paymentMethod) {
            paymentMethod = EconomofarPaymentMethods.all.first(where: {
                $0.caseInsensitiveCompare(value) == .orderedSame
            }) ?? value
        }

        self.suggestion = nil
    }

    private static func clean(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }

    // MARK: Saving

    /// Returns true only when the server confirmed the ticket.
    /// When an identical ticket exists, `duplicateMessage` is filled and nothing is saved.
    func save(token: String?, ignoreDuplicate: Bool) async -> Bool {
        guard !isSaving, let token, !token.isEmpty, let amount = parsedAmount else { return false }

        let name = cleanName

        guard !name.isEmpty else { return false }

        let category = self.category
        let paymentMethod = self.paymentMethod
        let note = cleanNote
        let day = Self.dayFormatter.string(from: date)

        isSaving = true
        errorMessage = nil
        duplicateMessage = nil

        if !ignoreDuplicate {
            let checker = TicketService()

            if let message = await checker.findDuplicate(
                merchant: name,
                amount: amount,
                purchaseDate: day,
                token: token
            ) {
                duplicateMessage = message
                isSaving = false
                return false
            }
        }

        let body = ManualTicketRequestBody(
            merchantName: name,
            totalAmount: amount,
            purchaseDate: day,
            category: category,
            paymentMethod: paymentMethod,
            note: note
        )

        do {
            _ = try await ManualTicketService.shared.create(body, token: token)
            isSaving = false
            return true
        } catch APIError.unauthorized {
            isSaving = false
            return false
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }
}

// MARK: - Screen

struct ManualTicketView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ManualTicketViewModel()

    var onSaved: () -> Void = {}
    var initialDate: Date? = nil

    @State private var didApplyInitialDate = false

    private static let errorAnchor = "manualTicketError"

    var body: some View {
        NavigationStack {
            ZStack {
                EconomofarUI.background
                    .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            introText

                            if let errorMessage = viewModel.errorMessage {
                                DashboardInfoBanner(
                                    icon: "exclamationmark.triangle.fill",
                                    message: errorMessage,
                                    tint: EconomofarUI.danger,
                                    background: EconomofarUI.dangerSoft
                                )
                                .padding(.horizontal, -20)
                                .id(Self.errorAnchor)
                            }

                            merchantField
                            amountField
                            dateField
                            categoryField
                            paymentField
                            noteField
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                        .disabled(viewModel.isSaving)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: viewModel.errorMessage) { newValue in
                        guard newValue != nil else { return }

                        withAnimation {
                            proxy.scrollTo(Self.errorAnchor, anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle("Saisie manuelle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await save(ignoreDuplicate: false)
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Enregistrer")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .confirmationDialog(
                "Ticket peut-être déjà enregistré",
                isPresented: Binding(
                    get: { viewModel.duplicateMessage != nil },
                    set: { newValue in
                        if !newValue {
                            viewModel.duplicateMessage = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Enregistrer quand même") {
                    Task {
                        await save(ignoreDuplicate: true)
                    }
                }

                Button("Annuler", role: .cancel) {}
            } message: {
                Text(viewModel.duplicateMessage ?? "")
            }
            .task(id: viewModel.merchantName) {
                await viewModel.refreshSuggestion(token: sessionManager.token)
            }
            .interactiveDismissDisabled(viewModel.isSaving)
            .onAppear {
                applyInitialDate()
            }
        }
    }

    private func save(ignoreDuplicate: Bool) async {
        let saved = await viewModel.save(token: sessionManager.token, ignoreDuplicate: ignoreDuplicate)

        if saved {
            onSaved()
            dismiss()
        }
    }

    private func applyInitialDate() {
        guard !didApplyInitialDate, let initialDate else { return }

        didApplyInitialDate = true
        viewModel.date = min(max(initialDate, ManualTicketRules.earliestDate), Date())
    }

    // MARK: Pieces

    private var introText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ajouter un achat à la main")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text("Pour un paiement en espèces ou un ticket illisible. L'achat compte dans vos budgets, vos analyses et votre historique, comme un ticket scanné.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var merchantField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Commerçant", icon: "building.2")

            fieldBox {
                TextField("Ex : Boulangerie du coin", text: $viewModel.merchantName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .onChange(of: viewModel.merchantName) { newValue in
                        let limited = ManualTicketRules.limited(newValue, to: ManualTicketRules.maxMerchantLength)

                        if limited != newValue {
                            viewModel.merchantName = limited
                        }
                    }
            }

            if let summary = viewModel.suggestionSummary {
                suggestionRow(summary)
            }
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Montant", icon: AppFormat.currencyIcon)

            fieldBox {
                HStack(spacing: 10) {
                    TextField("Ex : 12,50", text: $viewModel.amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text(AppFormat.currencyCode)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }
            }

            if viewModel.amountLooksWrong {
                Text("Entrez un montant supérieur à 0 (1 000 000 maximum).")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.danger)
            }
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Date de l'achat", icon: "calendar")

            fieldBox {
                DatePicker(
                    "Date de l'achat",
                    selection: $viewModel.date,
                    in: ManualTicketRules.earliestDate...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .environment(\.locale, AppFormat.locale)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var categoryField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Catégorie", icon: "tag")

            fieldBox {
                Picker("Catégorie", selection: $viewModel.category) {
                    ForEach(viewModel.categories, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(EconomofarUI.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var paymentField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Moyen de paiement", icon: "creditcard")

            fieldBox {
                Picker("Moyen de paiement", selection: $viewModel.paymentMethod) {
                    ForEach(viewModel.paymentMethods, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(EconomofarUI.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Note (facultatif)", icon: "note.text")

            fieldBox {
                TextField("Ex : cadeau d'anniversaire", text: $viewModel.note, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .onChange(of: viewModel.note) { newValue in
                        let limited = ManualTicketRules.limited(newValue, to: ManualTicketRules.maxNoteLength)

                        if limited != newValue {
                            viewModel.note = limited
                        }
                    }
            }
        }
    }

    private func suggestionRow(_ summary: String) -> some View {
        Button {
            viewModel.applySuggestion()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("D'habitude : \(summary)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Touchez pour appliquer")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()
            }
            .padding(12)
            .background(EconomofarUI.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func fieldLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(EconomofarUI.textSecondary)
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
}
