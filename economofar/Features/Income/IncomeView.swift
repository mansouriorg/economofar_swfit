import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class IncomeViewModel: ObservableObject {
    @Published var incomes: [IncomeItem] = []
    @Published var report: CashFlowReport? = nil
    @Published var isLoading = false
    @Published var hasLoaded = false
    @Published var errorMessage: String? = nil

    static let maxIncomes = 50
    static let chartMonths = 6

    var canAddIncome: Bool {
        hasLoaded && incomes.count < Self.maxIncomes
    }

    func load(token: String?) async {
        guard let token, !token.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let months = Self.chartMonths

            async let loadedIncomes = IncomeService.shared.fetchAll(token: token)
            async let loadedReport = IncomeService.shared.fetchCashFlow(months: months, token: token)

            let (newIncomes, newReport) = try await (loadedIncomes, loadedReport)

            incomes = newIncomes
            report = newReport
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
        amount: Double,
        date: String,
        recurring: Bool,
        endDate: String?,
        token: String?
    ) async -> String? {
        guard let token, !token.isEmpty else { return nil }

        let body = IncomeBody(name: name, amount: amount, date: date, recurring: recurring, endDate: endDate)

        do {
            let saved: IncomeItem

            if let id {
                saved = try await IncomeService.shared.update(id: id, body: body, token: token)
            } else {
                saved = try await IncomeService.shared.create(body, token: token)
            }

            if let index = incomes.firstIndex(where: { $0.id == saved.id }) {
                incomes[index] = saved
            } else {
                incomes.insert(saved, at: 0)
            }
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
            try await IncomeService.shared.delete(id: id, token: token)
        } catch APIError.unauthorized {
            return nil
        } catch {
            return error.localizedDescription
        }

        incomes.removeAll { $0.id == id }

        await load(token: token)
        return nil
    }
}

// MARK: - Sheet target

struct IncomeEditorTarget: Identifiable {
    let id = UUID()
    let income: IncomeItem?

    var isEditing: Bool {
        income != nil
    }
}

// MARK: - Screen

struct IncomeView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = IncomeViewModel()
    @State private var editorTarget: IncomeEditorTarget? = nil

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

                    if viewModel.hasLoaded {
                        if let report = viewModel.report {
                            currentMonthCard(report)

                            if report.hasIncome || report.months.contains(where: { $0.expenses > 0 }) {
                                chartCard(report)
                            }

                            if report.completedMonths > 0 {
                                averagesCard(report)
                            }
                        }

                        incomesSection
                    } else if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 50)
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
        .navigationTitle("Revenus et bilan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editorTarget = IncomeEditorTarget(income: nil)
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!viewModel.canAddIncome)
            }
        }
        .task {
            await viewModel.load(token: sessionManager.token)
        }
        .sheet(item: $editorTarget) { target in
            IncomeEditor(
                target: target,
                onSave: { name, amount, date, recurring, endDate in
                    await viewModel.save(
                        id: target.income?.id,
                        name: name,
                        amount: amount,
                        date: date,
                        recurring: recurring,
                        endDate: endDate,
                        token: sessionManager.token
                    )
                },
                onDelete: deleteAction(for: target)
            )
        }
    }

    private func deleteAction(for target: IncomeEditorTarget) -> (() async -> String?)? {
        guard let incomeId = target.income?.id else { return nil }

        return {
            await viewModel.delete(id: incomeId, token: sessionManager.token)
        }
    }

    // MARK: Pieces

    private var introText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ce qui entre, ce qui sort")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text("Déclarez votre salaire et vos autres revenus pour voir, mois par mois, ce qu'il vous reste après vos dépenses. Seuls les tickets validés sont comptés.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func netColor(_ value: Double) -> Color {
        value >= 0 ? EconomofarUI.success : EconomofarUI.danger
    }

    private func currentMonthCard(_ report: CashFlowReport) -> some View {
        let month = report.currentMonth

        return VStack(alignment: .leading, spacing: 14) {
            Text("Ce mois-ci")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            if let month {
                HStack(alignment: .top, spacing: 12) {
                    figure(title: "Revenus du mois", value: month.income, color: EconomofarUI.accent)
                    figure(title: "Dépensé à ce jour", value: month.expenses, color: EconomofarUI.warning)
                    figure(title: "Reste", value: month.net, color: netColor(month.net))
                }

                if month.income > 0 {
                    SpentShareBar(
                        fraction: min(max(month.expenses / month.income, 0), 1),
                        tint: month.net >= 0 ? EconomofarUI.success : EconomofarUI.danger
                    )

                    Text(monthMessage(month))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(netColor(month.net))
                } else {
                    Text(report.hasIncome
                        ? "Aucun revenu n'est compté ce mois-ci. Vérifiez les dates de début et de fin de vos revenus."
                        : "Aucun revenu déclaré. Ajoutez votre salaire ci-dessous pour voir ce qu'il vous reste.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .incomeCard()
    }

    private func monthMessage(_ month: CashFlowMonth) -> String {
        if month.net >= 0 {
            let rate = Int((month.savingsRate ?? 0).rounded())
            return "Pour l'instant, vous gardez \(rate) % de vos revenus."
        }

        return "Vous avez déjà dépensé \(AppFormat.money(abs(month.net))) de plus que vos revenus du mois."
    }

    private func figure(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            Text(AppFormat.money(value))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chartCard(_ report: CashFlowReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(report.months.count) derniers mois")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Spacer()

                legendDot(color: EconomofarUI.accent, label: "Revenus")
                legendDot(color: EconomofarUI.warning, label: "Dépenses")
            }

            CashFlowChart(months: report.months)

            Text("Le mois en cours n'est pas terminé : ses dépenses sont partielles.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .incomeCard()
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
        }
    }

    private func averagesCard(_ report: CashFlowReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Moyenne par mois")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            averageRow(title: "Revenus", value: AppFormat.money(report.averageIncome), color: EconomofarUI.textPrimary)
            averageRow(title: "Dépenses", value: AppFormat.money(report.averageExpenses), color: EconomofarUI.textPrimary)
            averageRow(title: "Solde", value: AppFormat.money(report.averageNet), color: netColor(report.averageNet))

            if let rate = report.averageSavingsRate {
                averageRow(
                    title: "Part des revenus gardée",
                    value: "\(Int(rate.rounded())) %",
                    color: netColor(rate)
                )
            }

            Text("Calculée sur \(report.completedMonths) mois terminé\(report.completedMonths > 1 ? "s" : "").")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .incomeCard()
    }

    private func averageRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }

    private var incomesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mes revenus")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            if viewModel.incomes.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.incomes) { income in
                    incomeCard(income)
                }

                Text("Un revenu est compté en entier dans son mois de début, et dans son mois de fin s'il en a un.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func incomeCard(_ income: IncomeItem) -> some View {
        Button {
            editorTarget = IncomeEditorTarget(income: income)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: income.recurring ? "arrow.triangle.2.circlepath" : "arrow.down.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(income.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(1)

                    Text(detailText(income))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .lineLimit(2)

                    Text(income.countsThisMonth ? "Compté ce mois-ci" : "Pas compté ce mois-ci")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(income.countsThisMonth ? EconomofarUI.success : EconomofarUI.textTertiary)
                }

                Spacer()

                Text(AppFormat.money(income.amount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .incomeCard(radius: 20)
        }
        .buttonStyle(.plain)
    }

    private func detailText(_ income: IncomeItem) -> String {
        let start = IncomeDates.display(income.date) ?? income.date

        if !income.recurring {
            return "Ponctuel · \(start)"
        }

        if let end = IncomeDates.display(income.endDate) {
            return "Chaque mois · du \(start) au \(end)"
        }

        return "Chaque mois · depuis le \(start)"
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundColor(EconomofarUI.accent)

            Text("Aucun revenu déclaré")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text("Appuyez sur + pour ajouter votre salaire. Il sera compté chaque mois automatiquement.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.horizontal, 12)
    }
}

// MARK: - Card look

private extension View {
    func incomeCard(radius: CGFloat = 22) -> some View {
        self
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }
}

// MARK: - Pieces

/// Share of the income that is already spent.
private struct SpentShareBar: View {
    let fraction: Double
    let tint: Color

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
        .frame(height: 10)
    }
}

/// Income and expenses side by side for each month.
private struct CashFlowChart: View {
    let months: [CashFlowMonth]

    private let chartHeight: CGFloat = 110

    private var maxValue: Double {
        let largest = months.map { max($0.income, $0.expenses) }.max() ?? 0
        return largest > 0 ? largest : 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(months) { month in
                VStack(spacing: 6) {
                    HStack(alignment: .bottom, spacing: 3) {
                        bar(value: month.income, color: EconomofarUI.accent)
                        bar(value: month.expenses, color: EconomofarUI.warning)
                    }
                    .frame(height: chartHeight, alignment: .bottom)

                    Text(IncomeDates.monthLabel(month.month))
                        .font(.system(size: 10, weight: month.current ? .bold : .medium, design: .rounded))
                        .foregroundColor(month.current ? EconomofarUI.textPrimary : EconomofarUI.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func bar(value: Double, color: Color) -> some View {
        let height: CGFloat = value > 0
            ? max(4, CGFloat(value / maxValue) * chartHeight)
            : 2

        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color.opacity(value > 0 ? 1 : 0.25))
            .frame(width: 10, height: height)
    }
}

// MARK: - Editor sheet

struct IncomeEditor: View {
    @Environment(\.dismiss) private var dismiss

    let target: IncomeEditorTarget
    let onSave: (String, Double, String, Bool, String?) async -> String?
    let onDelete: (() async -> String?)?

    @State private var name: String
    @State private var amountText: String
    @State private var recurring: Bool
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var isWorking = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String? = nil

    init(
        target: IncomeEditorTarget,
        onSave: @escaping (String, Double, String, Bool, String?) async -> String?,
        onDelete: (() async -> String?)?
    ) {
        self.target = target
        self.onSave = onSave
        self.onDelete = onDelete

        let existingStart = target.income.flatMap { IncomeDates.parse($0.date) }
        let existingEnd = target.income?.endDate.flatMap { IncomeDates.parse($0) }
        let start = existingStart ?? Date()

        _name = State(initialValue: target.income?.name ?? "")
        _amountText = State(initialValue: Self.editableText(target.income?.amount))
        _recurring = State(initialValue: target.income?.recurring ?? true)
        _startDate = State(initialValue: start)
        _hasEndDate = State(initialValue: existingEnd != nil)
        _endDate = State(initialValue: existingEnd ?? IncomeDates.addYears(1, to: max(start, Date())))
    }

    private static func editableText(_ value: Double?) -> String {
        guard let value, value > 0, value < 1_000_000_000 else { return "" }

        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.2f", value)
    }

    private var parsedAmount: Double? {
        IncomeInput.amount(from: amountText)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        parsedAmount != nil && !trimmedName.isEmpty && !isWorking
    }

    private var startLabel: String {
        recurring ? "À partir du" : "Date"
    }

    private var startRange: ClosedRange<Date> {
        let now = Date()
        let existing = target.income.flatMap { IncomeDates.parse($0.date) }
        let lower = min(IncomeDates.addYears(-19, to: now), existing ?? now)
        let upper = max(IncomeDates.addYears(1, to: now), existing ?? now)

        return lower...upper
    }

    private var endRange: ClosedRange<Date> {
        let existing = target.income?.endDate.flatMap { IncomeDates.parse($0) }
        let upper = max(IncomeDates.addYears(45, to: Date()), startDate, existing ?? startDate)
        return startDate...upper
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
                        recurringField
                        dateField

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
                                Label("Supprimer ce revenu", systemImage: "trash")
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
            .navigationTitle(target.isEditing ? "Modifier le revenu" : "Nouveau revenu")
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
                "Supprimer ce revenu ?",
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
                let limited = IncomeInput.limited(newValue, to: 60)

                if limited != newValue {
                    name = limited
                }
            }
            .onChange(of: startDate) { newValue in
                if endDate < newValue {
                    endDate = newValue
                }
            }
            .interactiveDismissDisabled(isWorking)
        }
    }

    // MARK: Fields

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Nom", systemImage: "pencil")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            fieldBox {
                TextField("Ex: Salaire", text: $name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
            }
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Montant", systemImage: AppFormat.currencyIcon)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            fieldBox {
                HStack(spacing: 10) {
                    TextField("Ex: 2000", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text(AppFormat.currencyCode)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }
            }

            if parsedAmount == nil && !amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Montant invalide. Utilisez des chiffres avec une virgule ou un point, par exemple 1500,50.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.danger)
            }
        }
    }

    private var recurringField: some View {
        fieldBox {
            Toggle(isOn: $recurring) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Revenu mensuel")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text(recurring ? "Compté chaque mois, par exemple un salaire" : "Compté une seule fois, le mois de sa date")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }
            }
            .tint(EconomofarUI.accent)
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(startLabel, systemImage: "calendar")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            fieldBox {
                VStack(spacing: 12) {
                    DatePicker(
                        startLabel,
                        selection: $startDate,
                        in: startRange,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .environment(\.locale, AppFormat.locale)

                    if recurring {
                        Toggle(isOn: $hasEndDate) {
                            Text("Fixer une date de fin")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(EconomofarUI.textPrimary)
                        }
                        .tint(EconomofarUI.accent)

                        if hasEndDate {
                            DatePicker(
                                "Jusqu'au",
                                selection: $endDate,
                                in: endRange,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .environment(\.locale, AppFormat.locale)
                        }

                        Text("Le mois de début et le mois de fin sont comptés en entier.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
            IncomeDates.iso(startDate),
            recurring,
            recurring && hasEndDate ? IncomeDates.iso(endDate) : nil
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
