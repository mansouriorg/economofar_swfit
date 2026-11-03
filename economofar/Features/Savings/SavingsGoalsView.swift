import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class SavingsGoalsViewModel: ObservableObject {
    @Published var goals: [SavingsGoal] = []
    @Published var isLoading = false
    @Published var hasLoaded = false
    @Published var errorMessage: String? = nil

    static let maxGoals = 30

    var totalSaved: Double {
        goals.reduce(0) { $0 + $1.savedAmount }
    }

    var totalTarget: Double {
        goals.reduce(0) { $0 + $1.targetAmount }
    }

    var overallFraction: Double {
        guard totalTarget > 0 else { return 0 }

        let counted = goals.reduce(0) { $0 + min($1.savedAmount, $1.targetAmount) }
        return min(max(counted / totalTarget, 0), 1)
    }

    var completedCount: Int {
        goals.filter { $0.isCompleted }.count
    }

    var canAddGoal: Bool {
        hasLoaded && goals.count < Self.maxGoals
    }

    func goal(id: Int) -> SavingsGoal? {
        goals.first { $0.id == id }
    }

    func load(token: String?) async {
        guard let token, !token.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            goals = try await SavingsGoalService.shared.fetchAll(token: token)
            hasLoaded = true
        } catch APIError.unauthorized {
            // The session manager logs the user out
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Returns an error message, or nil when everything went fine.
    func save(
        id: Int?,
        name: String,
        target: Double,
        deadline: String?,
        icon: String?,
        token: String?
    ) async -> String? {
        guard let token, !token.isEmpty else { return nil }

        let body = SavingsGoalBody(name: name, targetAmount: target, deadline: deadline, icon: icon)

        do {
            let goal: SavingsGoal

            if let id {
                goal = try await SavingsGoalService.shared.update(id: id, body: body, token: token)
            } else {
                goal = try await SavingsGoalService.shared.create(body, token: token)
            }

            replace(goal)
        } catch APIError.unauthorized {
            return nil
        } catch {
            return error.localizedDescription
        }

        return nil
    }

    /// Returns an error message, or nil when everything went fine.
    func delete(id: Int, token: String?) async -> String? {
        guard let token, !token.isEmpty else { return nil }

        do {
            try await SavingsGoalService.shared.delete(id: id, token: token)
        } catch APIError.unauthorized {
            return nil
        } catch {
            return error.localizedDescription
        }

        goals.removeAll { $0.id == id }
        return nil
    }

    /// Returns an error message, or nil when everything went fine.
    func contribute(
        goalId: Int,
        amount: Double,
        date: String?,
        note: String?,
        token: String?
    ) async -> String? {
        guard let token, !token.isEmpty else { return nil }

        let body = SavingsContributionBody(amount: amount, date: date, note: note)

        do {
            let goal = try await SavingsGoalService.shared.addContribution(goalId: goalId, body: body, token: token)
            replace(goal)
        } catch APIError.unauthorized {
            return nil
        } catch {
            return error.localizedDescription
        }

        return nil
    }

    /// Returns an error message, or nil when everything went fine.
    func removeContribution(goalId: Int, contributionId: Int, token: String?) async -> String? {
        guard let token, !token.isEmpty else { return nil }

        do {
            let goal = try await SavingsGoalService.shared.deleteContribution(
                goalId: goalId,
                contributionId: contributionId,
                token: token
            )
            replace(goal)
        } catch APIError.unauthorized {
            return nil
        } catch {
            return error.localizedDescription
        }

        return nil
    }

    private func replace(_ goal: SavingsGoal) {
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
        } else {
            goals.append(goal)
        }
    }
}

// MARK: - Shared look

enum SavingsGoalStyle {
    static func tint(for goal: SavingsGoal) -> Color {
        switch goal.state {
        case .completed, .onTrack:
            return EconomofarUI.success
        case .overdue:
            return EconomofarUI.danger
        case .behind:
            return EconomofarUI.warning
        case .noDeadline:
            return EconomofarUI.accent
        case .notStarted, .unknown:
            return EconomofarUI.textSecondary
        }
    }

    static func statusText(for goal: SavingsGoal) -> String {
        switch goal.state {
        case .completed:
            return "Objectif atteint"
        case .overdue:
            let days = abs(goal.daysLeft ?? 0)
            return "Échéance dépassée de \(days) \(plural(days, "jour", "jours"))"
        case .notStarted:
            return "Pas encore commencé"
        case .noDeadline:
            return "Sans date limite"
        case .onTrack:
            return "Dans les temps"
        case .behind:
            return "En retard sur le plan"
        case .unknown:
            return ""
        }
    }

    static func deadlineText(for goal: SavingsGoal) -> String? {
        guard let shown = SavingsDates.display(goal.deadline) else { return nil }

        guard !goal.isCompleted, let left = goal.daysLeft else {
            return "Échéance le \(shown)"
        }

        if left > 0 {
            return "Échéance le \(shown) · \(left) \(plural(left, "jour restant", "jours restants"))"
        }

        if left == 0 {
            return "Échéance aujourd'hui"
        }

        return "Échéance le \(shown)"
    }

    static func plural(_ count: Int, _ singular: String, _ many: String) -> String {
        count > 1 ? many : singular
    }
}

struct SavingsProgressBar: View {
    let fraction: Double
    let tint: Color
    var height: CGFloat = 10

    var body: some View {
        let safe = fraction.isFinite ? min(max(fraction, 0), 1) : 0

        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(EconomofarUI.cardSoft)

                Capsule()
                    .fill(tint)
                    .frame(width: max(safe > 0 ? 6 : 0, proxy.size.width * CGFloat(safe)))
            }
        }
        .frame(height: height)
    }
}

struct SavingsIconBadge: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundColor(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.12))
            .clipShape(Circle())
    }
}

// MARK: - Sheet target

struct SavingsGoalEditorTarget: Identifiable {
    let id = UUID()
    let goal: SavingsGoal?

    var isEditing: Bool {
        goal != nil
    }
}

// MARK: - Screen

struct SavingsGoalsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = SavingsGoalsViewModel()
    @State private var editorTarget: SavingsGoalEditorTarget? = nil

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

                    if viewModel.goals.isEmpty {
                        if viewModel.hasLoaded {
                            emptyState
                        } else if viewModel.isLoading {
                            ProgressView()
                                .padding(.top, 50)
                        }
                    } else {
                        summaryCard

                        ForEach(viewModel.goals) { goal in
                            goalCard(goal)
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
        .navigationTitle("Objectifs d'épargne")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editorTarget = SavingsGoalEditorTarget(goal: nil)
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!viewModel.canAddGoal)
            }
        }
        .task {
            await viewModel.load(token: sessionManager.token)
        }
        .sheet(item: $editorTarget) { target in
            SavingsGoalEditor(
                target: target,
                onSave: { name, amount, deadline, icon in
                    await viewModel.save(
                        id: target.goal?.id,
                        name: name,
                        target: amount,
                        deadline: deadline,
                        icon: icon,
                        token: sessionManager.token
                    )
                },
                onDelete: nil
            )
        }
    }

    // MARK: Pieces

    private var introText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vos projets")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text("Fixez un montant à atteindre, ajoutez vos versements et suivez le rythme nécessaire pour finir à temps.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total épargné")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            Text(AppFormat.money(viewModel.totalSaved))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            SavingsProgressBar(fraction: viewModel.overallFraction, tint: EconomofarUI.accent)

            HStack {
                Text("sur \(AppFormat.money(viewModel.totalTarget))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)

                Spacer()

                Text("\(viewModel.completedCount) sur \(viewModel.goals.count) atteint\(viewModel.completedCount > 1 ? "s" : "")")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }

    private func goalCard(_ goal: SavingsGoal) -> some View {
        let color = SavingsGoalStyle.tint(for: goal)

        return NavigationLink {
            SavingsGoalDetailView(viewModel: viewModel, goalId: goal.id)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    SavingsIconBadge(symbol: SavingsGoalIcons.symbol(for: goal.icon), tint: color)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(goal.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)
                            .lineLimit(1)

                        Text(SavingsGoalStyle.statusText(for: goal))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(color)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text("\(Int(goal.percent.isFinite ? goal.percent.rounded(.down) : 0)) %")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                }

                SavingsProgressBar(fraction: goal.progressFraction, tint: color)

                HStack {
                    Text("\(AppFormat.money(goal.savedAmount)) sur \(AppFormat.money(goal.targetAmount))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)

                    Spacer()

                    if goal.isCompleted {
                        Text("Atteint")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(color)
                    } else {
                        Text("Reste \(AppFormat.money(goal.remainingAmount))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(color)
                    }
                }

                if let deadlineText = SavingsGoalStyle.deadlineText(for: goal) {
                    Label(deadlineText, systemImage: "calendar")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(goal.state == .overdue ? EconomofarUI.danger.opacity(0.35) : EconomofarUI.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(EconomofarUI.accent)

            Text("Aucun objectif d'épargne")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text("Appuyez sur + pour créer un projet : un voyage, un achat, un fonds d'urgence...")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
        .padding(.horizontal, 12)
    }
}

// MARK: - Goal editor sheet

struct SavingsGoalEditor: View {
    @Environment(\.dismiss) private var dismiss

    let target: SavingsGoalEditorTarget
    let onSave: (String, Double, String?, String?) async -> String?
    let onDelete: (() async -> String?)?

    @State private var name: String
    @State private var amountText: String
    @State private var iconKey: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var isWorking = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String? = nil

    init(
        target: SavingsGoalEditorTarget,
        onSave: @escaping (String, Double, String?, String?) async -> String?,
        onDelete: (() async -> String?)?
    ) {
        self.target = target
        self.onSave = onSave
        self.onDelete = onDelete

        let existingDeadline = target.goal?.deadline.flatMap { SavingsDates.parse($0) }

        _name = State(initialValue: target.goal?.name ?? "")
        _amountText = State(initialValue: Self.editableText(target.goal?.targetAmount))
        _iconKey = State(initialValue: target.goal?.icon ?? SavingsGoalIcons.defaultKey)
        _hasDeadline = State(initialValue: existingDeadline != nil)
        _deadline = State(initialValue: existingDeadline ?? SavingsDates.addMonths(6, to: Date()))
    }

    private static func editableText(_ value: Double?) -> String {
        guard let value, value > 0, value < 1_000_000_000 else { return "" }

        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.2f", value)
    }

    private var parsedAmount: Double? {
        SavingsInput.amount(from: amountText)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        parsedAmount != nil && !trimmedName.isEmpty && !isWorking
    }

    private var deadlineRange: ClosedRange<Date> {
        let tomorrow = SavingsDates.addDays(1, to: Calendar.current.startOfDay(for: Date()))
        let existing = target.goal?.deadline.flatMap { SavingsDates.parse($0) }
        let lower = min(tomorrow, existing ?? tomorrow)
        let upper = max(SavingsDates.addMonths(12 * 49, to: Date()), lower)

        return lower...upper
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EconomofarUI.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        nameField
                        amountField
                        iconPicker
                        deadlineField

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
                                Label("Supprimer cet objectif", systemImage: "trash")
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
            .navigationTitle(target.isEditing ? "Modifier l'objectif" : "Nouvel objectif")
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
                "Supprimer l'objectif et tous ses versements ?",
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
            .onChange(of: name) { newValue in
                let limited = SavingsInput.limited(newValue, to: 100)

                if limited != newValue {
                    name = limited
                }
            }
            .interactiveDismissDisabled(isWorking)
        }
    }

    // MARK: Fields

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Nom du projet", systemImage: "pencil")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            fieldBox {
                TextField("Ex: Voyage au Japon", text: $name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
            }
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Montant à atteindre", systemImage: AppFormat.currencyIcon)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            fieldBox {
                HStack(spacing: 10) {
                    TextField("Ex: 1500", text: $amountText)
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

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Icône", systemImage: "square.grid.2x2")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(SavingsGoalIcons.all) { icon in
                    iconChip(icon)
                }
            }
        }
    }

    private func iconChip(_ icon: SavingsGoalIcon) -> some View {
        let selected = icon.key == iconKey

        return Button {
            iconKey = icon.key
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon.symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(selected ? Color.white : EconomofarUI.accent)

                Text(icon.label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(selected ? Color.white : EconomofarUI.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected ? EconomofarUI.accent : EconomofarUI.cardSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? EconomofarUI.accent : EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var deadlineField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Date limite", systemImage: "calendar")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            fieldBox {
                VStack(spacing: 12) {
                    Toggle(isOn: $hasDeadline) {
                        Text("Fixer une date limite")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)
                    }
                    .tint(EconomofarUI.accent)

                    if hasDeadline {
                        DatePicker(
                            "Date limite",
                            selection: $deadline,
                            in: deadlineRange,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .environment(\.locale, AppFormat.locale)
                    }
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
        guard let amount = parsedAmount, !trimmedName.isEmpty else { return }

        isWorking = true
        errorMessage = nil

        let result = await onSave(
            trimmedName,
            amount,
            hasDeadline ? SavingsDates.iso(deadline) : nil,
            iconKey
        )

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
