import SwiftUI

/// Creates an event, or changes the one it is given.
struct SpendingEventFormView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss

    let event: SpendingEventLine?
    let onSaved: () -> Void

    @State private var name: String
    @State private var icon: String
    @State private var budgetText: String
    @State private var hasStart: Bool
    @State private var start: Date
    @State private var hasEnd: Bool
    @State private var end: Date
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    init(event: SpendingEventLine?, onSaved: @escaping () -> Void) {
        self.event = event
        self.onSaved = onSaved

        let startDate = SpendingEventDates.date(event?.startDate)
        let endDate = SpendingEventDates.date(event?.endDate)

        _name = State(initialValue: event?.name ?? "")
        _icon = State(initialValue: SpendingEventIcons.symbol(event?.icon ?? SpendingEventIcons.defaultSymbol))
        _budgetText = State(initialValue: SpendingEventsText.budgetFieldText(event?.budget))
        _hasStart = State(initialValue: startDate != nil)
        _start = State(initialValue: startDate ?? Date())
        _hasEnd = State(initialValue: endDate != nil)
        _end = State(initialValue: endDate ?? startDate ?? Date())
    }

    private var isEditing: Bool {
        event != nil
    }

    private var problem: String? {
        SpendingEventsText.problem(
            name: name,
            budgetText: budgetText,
            start: hasStart ? start : nil,
            end: hasStart && hasEnd ? end : nil
        )
    }

    private var canSave: Bool {
        problem == nil && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection

                iconSection

                budgetSection

                datesSection

                if let message = errorMessage ?? visibleProblem {
                    Section {
                        Text(message)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifier l'événement" : "Nouvel événement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Enregistrer") {
                            save()
                        }
                        .disabled(!canSave)
                    }
                }
            }
            .environment(\.locale, AppFormat.locale)
        }
    }

    /// An empty name is not an error until the person has typed something.
    private var visibleProblem: String? {
        guard let problem else {
            return nil
        }

        return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : problem
    }

    // MARK: Sections

    private var nameSection: some View {
        Section {
            TextField("Nom (voyage, travaux, mariage...)", text: $name)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
        } header: {
            Text("Nom")
        } footer: {
            Text("\(name.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count)/\(SpendingEventsText.nameLimit)")
        }
    }

    private var iconSection: some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(SpendingEventIcons.all) { choice in
                    Button {
                        icon = choice.symbol
                    } label: {
                        Image(systemName: choice.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(icon == choice.symbol ? .white : EconomofarUI.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(icon == choice.symbol ? EconomofarUI.accent : EconomofarUI.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(choice.title))
                    .accessibilityAddTraits(icon == choice.symbol ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Icône")
        }
    }

    private var budgetSection: some View {
        Section {
            HStack {
                TextField("Sans budget", text: $budgetText)
                    .keyboardType(.decimalPad)

                Text("€")
                    .foregroundColor(EconomofarUI.textSecondary)
            }
        } header: {
            Text("Budget (facultatif)")
        } footer: {
            Text("Avec un budget, l'écran de l'événement montre ce qu'il reste à dépenser et vous prévient à partir de 80 %.")
        }
    }

    private var datesSection: some View {
        Section {
            Toggle("Date de début", isOn: $hasStart.animation())

            if hasStart {
                DatePicker("Début", selection: $start, displayedComponents: .date)
                    .onChange(of: start) { value in
                        if end < value {
                            end = value
                        }
                    }

                Toggle("Date de fin", isOn: $hasEnd.animation())

                if hasEnd {
                    DatePicker("Fin", selection: $end, in: start..., displayedComponents: .date)
                }
            }
        } header: {
            Text("Dates (facultatif)")
        } footer: {
            Text("Avec des dates, l'événement affiche les jours restants, la dépense possible par jour et le total à ce rythme. Elles servent aussi à proposer en premier les tickets de la période.")
        }
    }

    // MARK: Save

    private func save() {
        guard canSave else {
            return
        }

        let budgetInput = budgetText.trimmingCharacters(in: .whitespacesAndNewlines)
        let startText = hasStart ? SpendingEventDates.text(start) : nil
        let endText = hasStart && hasEnd ? SpendingEventDates.text(end) : nil

        let body = SpendingEventBody(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon,
            budget: budgetInput.isEmpty ? nil : SpendingEventsText.parseBudget(budgetInput),
            startDate: startText,
            endDate: endText,
            archived: nil
        )

        guard let token = sessionManager.token, !token.isEmpty else {
            errorMessage = "Votre session a expiré. Reconnectez-vous."
            return
        }

        isSaving = true
        errorMessage = nil

        let id = event?.id

        Task {
            do {
                if let id {
                    try await SpendingEventsService.shared.update(token: token, id: id, body: body)
                } else {
                    try await SpendingEventsService.shared.create(token: token, body: body)
                }

                isSaving = false
                onSaved()
                dismiss()
            } catch APIError.unauthorized {
                isSaving = false
                errorMessage = "Votre session a expiré. Reconnectez-vous."
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
