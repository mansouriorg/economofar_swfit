import SwiftUI

// MARK: - Sheet target

struct SavingsContributionTarget: Identifiable {
    let id = UUID()
    let isWithdrawal: Bool
}

// MARK: - Screen

struct SavingsGoalDetailView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SavingsGoalsViewModel
    let goalId: Int

    @State private var editorTarget: SavingsGoalEditorTarget? = nil
    @State private var contributionTarget: SavingsContributionTarget? = nil
    @State private var contributionToRemove: SavingsContribution? = nil
    @State private var showRemoveConfirmation = false
    @State private var actionError: String? = nil

    private var goal: SavingsGoal? {
        viewModel.goal(id: goalId)
    }

    var body: some View {
        ZStack {
            EconomofarUI.background
                .ignoresSafeArea()

            if let goal {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        headerCard(goal)

                        actionButtons(goal)
                        planCard(goal)
                        contributionsCard(goal)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(goal?.name ?? "Objectif")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Modifier") {
                    if let goal {
                        editorTarget = SavingsGoalEditorTarget(goal: goal)
                    }
                }
                .disabled(goal == nil)
            }
        }
        .sheet(
            item: $editorTarget,
            onDismiss: {
                if goal == nil && viewModel.hasLoaded {
                    dismiss()
                }
            }
        ) { target in
            SavingsGoalEditor(
                target: target,
                onSave: { name, amount, deadline, icon in
                    await viewModel.save(
                        id: goalId,
                        name: name,
                        target: amount,
                        deadline: deadline,
                        icon: icon,
                        token: sessionManager.token
                    )
                },
                onDelete: {
                    await viewModel.delete(id: goalId, token: sessionManager.token)
                }
            )
        }
        .sheet(item: $contributionTarget) { target in
            SavingsContributionSheet(
                goalName: goal?.name ?? "",
                isWithdrawal: target.isWithdrawal,
                maxWithdrawal: goal?.savedAmount ?? 0,
                onSave: { amount, date, note in
                    await viewModel.contribute(
                        goalId: goalId,
                        amount: amount,
                        date: date,
                        note: note,
                        token: sessionManager.token
                    )
                }
            )
        }
        .confirmationDialog(
            "Supprimer ce versement ?",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let item = contributionToRemove {
                    Task {
                        await removeContribution(item)
                    }
                }
            }

            Button("Annuler", role: .cancel) {
                contributionToRemove = nil
            }
        }
        .alert(
            "Opération impossible",
            isPresented: Binding(
                get: { actionError != nil },
                set: { shown in
                    if !shown {
                        actionError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
        .onChange(of: goal == nil) { isGone in
            if isGone && viewModel.hasLoaded && editorTarget == nil {
                dismiss()
            }
        }
    }

    // MARK: Pieces

    private func headerCard(_ goal: SavingsGoal) -> some View {
        let color = SavingsGoalStyle.tint(for: goal)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                SavingsIconBadge(symbol: SavingsGoalIcons.symbol(for: goal.icon), tint: color, size: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text(SavingsGoalStyle.statusText(for: goal))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(color)
                }

                Spacer()
            }

            Text(AppFormat.money(goal.savedAmount))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            SavingsProgressBar(fraction: goal.progressFraction, tint: color, height: 12)

            HStack {
                Text("sur \(AppFormat.money(goal.targetAmount))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)

                Spacer()

                Text("\(Int(goal.percent.isFinite ? goal.percent.rounded(.down) : 0)) %")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }

            if let deadlineText = SavingsGoalStyle.deadlineText(for: goal) {
                Label(deadlineText, systemImage: "calendar")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .savingsCard()
    }

    private func actionButtons(_ goal: SavingsGoal) -> some View {
        HStack(spacing: 12) {
            Button {
                actionError = nil
                contributionTarget = SavingsContributionTarget(isWithdrawal: false)
            } label: {
                Label("Ajouter", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(EconomofarUI.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                actionError = nil
                contributionTarget = SavingsContributionTarget(isWithdrawal: true)
            } label: {
                Label("Retirer", systemImage: "minus.circle.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(goal.savedAmount <= 0)
            .opacity(goal.savedAmount <= 0 ? 0.5 : 1)
        }
    }

    private func planCard(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Plan d'épargne")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            if goal.isCompleted {
                adviceBox(
                    icon: "checkmark.seal.fill",
                    text: "Bravo, l'objectif est atteint. Vous pouvez le modifier pour viser plus haut.",
                    tint: EconomofarUI.success,
                    background: EconomofarUI.successSoft
                )
            } else {
                infoRow(icon: "flag.fill", title: "Reste à épargner", value: AppFormat.money(goal.remainingAmount))

                if let needed = goal.monthlyNeeded {
                    infoRow(
                        icon: "calendar.badge.clock",
                        title: "À mettre de côté par mois",
                        value: AppFormat.money(needed)
                    )
                }

                if let pace = goal.monthlyPace {
                    infoRow(icon: "speedometer", title: "Votre rythme actuel", value: "\(AppFormat.money(pace)) / mois")
                }

                if let projected = SavingsDates.display(goal.projectedDate) {
                    infoRow(icon: "clock", title: "Date estimée", value: projected)
                }

                if let tip = advice(for: goal) {
                    adviceBox(
                        icon: tip.icon,
                        text: tip.text,
                        tint: tip.tint,
                        background: tip.background
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .savingsCard()
    }

    private struct Advice {
        let icon: String
        let text: String
        let tint: Color
        let background: Color
    }

    private func advice(for goal: SavingsGoal) -> Advice? {
        switch goal.state {
        case .behind:
            if let needed = goal.monthlyNeeded {
                return Advice(
                    icon: "exclamationmark.triangle.fill",
                    text: "À ce rythme, l'objectif ne sera pas atteint à temps. Mettez environ \(AppFormat.money(needed)) de côté chaque mois pour tenir l'échéance.",
                    tint: EconomofarUI.warning,
                    background: EconomofarUI.warningSoft
                )
            }

            return nil
        case .overdue:
            return Advice(
                icon: "clock.badge.exclamationmark",
                text: "La date limite est dépassée. Modifiez l'objectif pour fixer une nouvelle échéance.",
                tint: EconomofarUI.danger,
                background: EconomofarUI.dangerSoft
            )
        case .onTrack:
            return Advice(
                icon: "hand.thumbsup.fill",
                text: "Vous êtes dans les temps. Gardez ce rythme pour atteindre l'objectif à la date prévue.",
                tint: EconomofarUI.success,
                background: EconomofarUI.successSoft
            )
        case .notStarted:
            return Advice(
                icon: "lightbulb.fill",
                text: "Ajoutez un premier versement pour suivre votre progression et estimer la date d'arrivée.",
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
        case .noDeadline:
            return Advice(
                icon: "lightbulb.fill",
                text: "Fixer une date limite permet de savoir combien mettre de côté chaque mois.",
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
        case .completed, .unknown:
            return nil
        }
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(EconomofarUI.accent)
                .frame(width: 22)

            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
        }
    }

    private func adviceBox(icon: String, text: String, tint: Color, background: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(tint)

            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func contributionsCard(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Historique")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            if goal.contributions.isEmpty {
                Text("Aucun versement pour le moment.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
            } else {
                ForEach(goal.contributions) { item in
                    contributionRow(item)
                }

                if goal.contributionCount > goal.contributions.count {
                    Text("\(goal.contributions.count) derniers versements affichés sur \(goal.contributionCount).")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .savingsCard()
    }

    private func contributionRow(_ item: SavingsContribution) -> some View {
        let isDeposit = item.amount >= 0
        let sign = isDeposit ? "+" : "-"
        let tint = isDeposit ? EconomofarUI.success : EconomofarUI.warning
        let dateText = SavingsDates.display(item.date) ?? item.date

        return HStack(spacing: 12) {
            Image(systemName: isDeposit ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(isDeposit ? "Versement" : "Retrait")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Text(dateText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)

                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textTertiary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text("\(sign)\(AppFormat.money(abs(item.amount)))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(tint)

            Menu {
                Button(role: .destructive) {
                    contributionToRemove = item
                    showRemoveConfirmation = true
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .frame(width: 30, height: 30)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Actions

    private func removeContribution(_ item: SavingsContribution) async {
        actionError = nil

        let result = await viewModel.removeContribution(
            goalId: goalId,
            contributionId: item.id,
            token: sessionManager.token
        )

        contributionToRemove = nil

        if let result {
            actionError = result
        }
    }
}

// MARK: - Card look

private extension View {
    func savingsCard() -> some View {
        self
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }
}

// MARK: - Contribution sheet

struct SavingsContributionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let goalName: String
    let isWithdrawal: Bool
    let maxWithdrawal: Double
    let onSave: (Double, String?, String?) async -> String?

    @State private var amountText = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var isWorking = false
    @State private var errorMessage: String? = nil

    private var parsedAmount: Double? {
        guard let value = SavingsInput.amount(from: amountText) else {
            return nil
        }

        if isWithdrawal && value > maxWithdrawal + 0.005 {
            return nil
        }

        return value
    }

    private var canSave: Bool {
        parsedAmount != nil && !isWorking
    }

    private var dateRange: ClosedRange<Date> {
        let now = Date()
        let oldest = SavingsDates.addMonths(-12 * 9, to: now)

        return oldest...now
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EconomofarUI.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(goalName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)

                        amountField
                        dateField
                        noteField

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
            .navigationTitle(isWithdrawal ? "Retirer de l'argent" : "Ajouter de l'argent")
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
                            Text("Valider")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: note) { newValue in
                let limited = SavingsInput.limited(newValue, to: 200)

                if limited != newValue {
                    note = limited
                }
            }
            .interactiveDismissDisabled(isWorking)
        }
    }

    // MARK: Fields

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Montant", systemImage: AppFormat.currencyIcon)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            fieldBox {
                HStack(spacing: 10) {
                    TextField("Ex: 50", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text(AppFormat.currencyCode)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }
            }

            if isWithdrawal {
                Text("Maximum retirable : \(AppFormat.money(maxWithdrawal))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Date", systemImage: "calendar")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            fieldBox {
                DatePicker(
                    "Date",
                    selection: $date,
                    in: dateRange,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .environment(\.locale, AppFormat.locale)
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Note (facultatif)", systemImage: "text.alignleft")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            fieldBox {
                TextField("Ex: Prime de fin d'année", text: $note)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
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
        guard let amount = parsedAmount else { return }

        isWorking = true
        errorMessage = nil

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let dateText: String? = Calendar.current.isDateInToday(date) ? nil : SavingsDates.iso(date)
        let signed = isWithdrawal ? -amount : amount

        let result = await onSave(signed, dateText, trimmedNote.isEmpty ? nil : trimmedNote)

        isWorking = false

        if let result {
            errorMessage = result
        } else {
            dismiss()
        }
    }
}
