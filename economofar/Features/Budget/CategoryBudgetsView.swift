import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class CategoryBudgetsViewModel: ObservableObject {
    @Published var items: [CategoryBudgetItem] = []
    @Published var isLoading = false
    @Published var hasLoaded = false
    @Published var errorMessage: String? = nil

    var usedCategories: Set<String> {
        Set(items.map { $0.category.lowercased() })
    }

    var availableCategories: [String] {
        EconomofarCategories.all.filter { !usedCategories.contains($0.lowercased()) }
    }

    var exceededCount: Int {
        items.filter { $0.exceeded }.count
    }

    func load(token: String?) async {
        guard let token, !token.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            items = try await CategoryBudgetService.shared.fetchAll(token: token)
            hasLoaded = true
        } catch APIError.unauthorized {
            // The session manager logs the user out
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Returns an error message, or nil when everything went fine.
    func save(category: String, amount: Double, token: String?) async -> String? {
        guard let token, !token.isEmpty else { return nil }

        do {
            try await CategoryBudgetService.shared.save(
                category: category,
                monthlyAmount: amount,
                token: token
            )
        } catch APIError.unauthorized {
            return nil
        } catch {
            return error.localizedDescription
        }

        await load(token: token)
        return nil
    }

    /// Returns an error message, or nil when everything went fine.
    func delete(id: Int, token: String?) async -> String? {
        guard let token, !token.isEmpty else { return nil }

        do {
            try await CategoryBudgetService.shared.delete(id: id, token: token)
        } catch APIError.unauthorized {
            return nil
        } catch {
            return error.localizedDescription
        }

        await load(token: token)
        return nil
    }
}

// MARK: - Sheet target

struct CategoryBudgetEditorTarget: Identifiable {
    let id = UUID()
    let budgetId: Int?
    let category: String?
    let amount: Double?

    var isEditing: Bool {
        budgetId != nil
    }
}

// MARK: - Screen

struct CategoryBudgetsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = CategoryBudgetsViewModel()
    @State private var editorTarget: CategoryBudgetEditorTarget? = nil
    @State private var showSuggestions = false

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
                        ForEach(viewModel.items) { item in
                            budgetCard(item)
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
        .navigationTitle("Budgets par catégorie")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editorTarget = CategoryBudgetEditorTarget(budgetId: nil, category: nil, amount: nil)
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!viewModel.hasLoaded || viewModel.availableCategories.isEmpty)
            }
        }
        .task {
            await viewModel.load(token: sessionManager.token)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSuggestions = true
                } label: {
                    Image(systemName: "sparkles")
                }
                .disabled(!viewModel.hasLoaded)
            }
        }
        .sheet(isPresented: $showSuggestions, onDismiss: {
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }) {
            CategoryBudgetSuggestionsView()
                .environmentObject(sessionManager)
        }
        .sheet(item: $editorTarget) { target in
            CategoryBudgetEditor(
                target: target,
                availableCategories: viewModel.availableCategories,
                onSave: { category, amount in
                    await viewModel.save(category: category, amount: amount, token: sessionManager.token)
                },
                onDelete: deleteAction(for: target)
            )
        }
    }

    private func deleteAction(for target: CategoryBudgetEditorTarget) -> (() async -> String?)? {
        guard let budgetId = target.budgetId else { return nil }

        return {
            await viewModel.delete(id: budgetId, token: sessionManager.token)
        }
    }

    // MARK: Pieces

    private var introText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Un plafond par catégorie")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text("Fixez une limite mensuelle pour chaque catégorie. Vous recevez une alerte dès qu'elle est dépassée. Seuls les tickets validés du mois en cours sont comptés.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            if viewModel.exceededCount > 0 {
                Text("\(viewModel.exceededCount) budget\(viewModel.exceededCount > 1 ? "s" : "") dépassé\(viewModel.exceededCount > 1 ? "s" : "") ce mois-ci")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.danger)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tint(for item: CategoryBudgetItem) -> Color {
        if item.exceeded {
            return EconomofarUI.danger
        }

        if item.percentUsed >= 80 {
            return EconomofarUI.warning
        }

        return EconomofarUI.success
    }

    private func budgetCard(_ item: CategoryBudgetItem) -> some View {
        let color = tint(for: item)
        let fraction = CGFloat(min(max(item.percentUsed, 0), 100) / 100)

        return Button {
            editorTarget = CategoryBudgetEditorTarget(
                budgetId: item.id,
                category: item.category,
                amount: item.monthlyAmount
            )
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(item.category)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Spacer()

                    Text(String(format: "%.0f %%", item.percentUsed))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(EconomofarUI.cardSoft)

                        Capsule()
                            .fill(color)
                            .frame(width: max(fraction > 0 ? 6 : 0, proxy.size.width * fraction))
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("\(AppFormat.money(item.spent)) sur \(AppFormat.money(item.monthlyAmount))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)

                    Spacer()

                    if item.exceeded {
                        Text("Dépassé de \(AppFormat.money(abs(item.remaining)))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(EconomofarUI.danger)
                    } else {
                        Text("Reste \(AppFormat.money(item.remaining))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(color)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(item.exceeded ? EconomofarUI.danger.opacity(0.35) : EconomofarUI.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(EconomofarUI.accent)

            Text("Aucun budget par catégorie")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text("Appuyez sur + pour fixer, par exemple, 300 pour l'alimentation ou 80 pour les loisirs. Ou touchez l'icône en forme d'étincelles pour obtenir des suggestions basées sur vos dépenses passées.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
        .padding(.horizontal, 12)
    }
}

// MARK: - Editor sheet

struct CategoryBudgetEditor: View {
    @Environment(\.dismiss) private var dismiss

    let target: CategoryBudgetEditorTarget
    let availableCategories: [String]
    let onSave: (String, Double) async -> String?
    let onDelete: (() async -> String?)?

    @State private var category: String
    @State private var amountText: String
    @State private var isWorking = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String? = nil

    init(
        target: CategoryBudgetEditorTarget,
        availableCategories: [String],
        onSave: @escaping (String, Double) async -> String?,
        onDelete: (() async -> String?)?
    ) {
        self.target = target
        self.availableCategories = availableCategories
        self.onSave = onSave
        self.onDelete = onDelete

        _category = State(initialValue: target.category ?? availableCategories.first ?? "")
        _amountText = State(initialValue: Self.editableText(target.amount))
    }

    private static func editableText(_ value: Double?) -> String {
        guard let value, value > 0, value < 1_000_000_000 else { return "" }

        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.2f", value)
    }

    private var parsedAmount: Double? {
        let cleaned = amountText
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")

        guard let value = Double(cleaned), value > 0, value < 1_000_000_000 else {
            return nil
        }

        return value
    }

    private var canSave: Bool {
        parsedAmount != nil && !category.isEmpty && !isWorking
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EconomofarUI.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        categoryField
                        amountField

                        if let errorMessage {
                            DashboardInfoBanner(
                                icon: "exclamationmark.triangle.fill",
                                message: errorMessage,
                                tint: EconomofarUI.danger,
                                background: EconomofarUI.dangerSoft
                            )
                            .padding(.horizontal, -20)
                        }

                        if onDelete != nil {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Supprimer ce budget", systemImage: "trash")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(EconomofarUI.danger)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(EconomofarUI.dangerSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .disabled(isWorking)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(target.isEditing ? "Modifier le budget" : "Nouveau budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .disabled(isWorking)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await save()
                        }
                    } label: {
                        if isWorking {
                            ProgressView()
                        } else {
                            Text("Enregistrer")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .confirmationDialog(
                "Supprimer le budget de \(category) ?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive) {
                    Task {
                        await remove()
                    }
                }

                Button("Annuler", role: .cancel) {}
            }
            .onChange(of: availableCategories) { newValue in
                guard !target.isEditing, !newValue.contains(category) else { return }
                category = newValue.first ?? category
            }
            .interactiveDismissDisabled(isWorking)
        }
    }

    // MARK: Fields

    private var categoryField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Catégorie", systemImage: "tag")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            if target.isEditing || availableCategories.count <= 1 {
                fieldBox {
                    Text(category.isEmpty ? "Aucune catégorie disponible" : category)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                fieldBox {
                    Picker("Catégorie", selection: $category) {
                        ForEach(availableCategories, id: \.self) { name in
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
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Plafond mensuel", systemImage: AppFormat.currencyIcon)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            fieldBox {
                HStack(spacing: 10) {
                    TextField("Ex: 300", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text(AppFormat.currencyCode)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }
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

    private func save() async {
        guard let amount = parsedAmount, !category.isEmpty else { return }

        isWorking = true
        errorMessage = nil

        let result = await onSave(category, amount)

        isWorking = false

        if let result {
            errorMessage = result
        } else {
            dismiss()
        }
    }

    private func remove() async {
        guard let onDelete else { return }

        isWorking = true
        errorMessage = nil

        let result = await onDelete()

        isWorking = false

        if let result {
            errorMessage = result
        } else {
            dismiss()
        }
    }
}
