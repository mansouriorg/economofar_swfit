import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class SpendingEventTicketPickerViewModel: ObservableObject {
    @Published var candidates: SpendingEventCandidates? = nil
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var errorMessage: String? = nil
    @Published var selected: Set<String> = []

    let eventId: Int

    private var generation = 0

    init(eventId: Int) {
        self.eventId = eventId
    }

    /// prune: drops the chosen tickets that are not in the answer (after a refusal, when the state is unsure).
    func load(token: String?, query: String, prune: Bool = false) async {
        guard let token, !token.isEmpty else {
            errorMessage = "Votre session a expiré. Reconnectez-vous."
            isLoading = false
            return
        }

        generation += 1
        let current = generation

        isLoading = true

        do {
            let result = try await SpendingEventsService.shared.fetchCandidates(token: token, id: eventId, query: query)

            if current == generation {
                candidates = result
                errorMessage = nil

                if prune {
                    // A ticket that another screen took meanwhile must not stay chosen
                    let present = Set(result.tickets.map { $0.id })
                    selected = selected.intersection(present)
                }
            }
        } catch APIError.unauthorized {
            if current == generation {
                errorMessage = "Votre session a expiré. Reconnectez-vous."
            }
        } catch {
            if current == generation, !Task.isCancelled, (error as? URLError)?.code != .cancelled {
                errorMessage = error.localizedDescription
            }
        }

        if current == generation {
            isLoading = false
        }
    }

    func toggle(_ id: String) {
        if selected.contains(id) {
            selected.remove(id)
        } else if selected.count < SpendingEventsText.maxPerCall {
            selected.insert(id)
        }
    }

    var isFull: Bool {
        selected.count >= SpendingEventsText.maxPerCall
    }

    /// True when the tickets are on the event.
    func add(token: String?) async -> Bool {
        guard let token, !token.isEmpty else {
            errorMessage = "Votre session a expiré. Reconnectez-vous."
            return false
        }

        let ids = Array(selected).sorted()

        if ids.isEmpty || isSaving {
            return false
        }

        isSaving = true
        errorMessage = nil

        defer {
            isSaving = false
        }

        do {
            try await SpendingEventsService.shared.attach(token: token, id: eventId, ticketIds: ids)
            return true
        } catch APIError.unauthorized {
            errorMessage = "Votre session a expiré. Reconnectez-vous."
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

// MARK: - Screen

struct SpendingEventTicketPickerView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SpendingEventTicketPickerViewModel

    let eventName: String
    let onAdded: () -> Void

    @State private var query = ""

    init(eventId: Int, eventName: String, onAdded: @escaping () -> Void) {
        self.eventName = eventName
        self.onAdded = onAdded
        _viewModel = StateObject(wrappedValue: SpendingEventTicketPickerViewModel(eventId: eventId))
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EconomofarUI.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if let errorMessage = viewModel.errorMessage {
                            DashboardInfoBanner(
                                icon: "exclamationmark.triangle.fill",
                                message: errorMessage,
                                tint: EconomofarUI.danger,
                                background: EconomofarUI.dangerSoft
                            )
                            .padding(.horizontal, -20)
                        }

                        if let candidates = viewModel.candidates {
                            content(candidates)
                        } else if viewModel.isLoading {
                            ProgressView()
                                .padding(.top, 50)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(SpendingEventsText.pickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: SpendingEventsText.pickerSearchPrompt)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.selected.isEmpty {
                        Button("Tout décocher") {
                            viewModel.selected = []
                        }
                        .disabled(viewModel.isSaving)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                addBar
            }
            .task(id: trimmedQuery) {
                if !trimmedQuery.isEmpty || viewModel.candidates != nil {
                    do {
                        try await Task.sleep(nanoseconds: 350_000_000)
                    } catch {
                        return
                    }
                }

                await viewModel.load(token: sessionManager.token, query: String(trimmedQuery.prefix(100)))
            }
        }
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ candidates: SpendingEventCandidates) -> some View {
        Text(SpendingEventsText.pickerNote(candidates))
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(EconomofarUI.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)

        if candidates.tickets.isEmpty {
            VStack(spacing: 8) {
                Text(SpendingEventsText.pickerEmpty)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Text(SpendingEventsText.pickerEmptyHint)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            DashboardSectionCard(title: "Tickets disponibles") {
                ForEach(Array(candidates.tickets.enumerated()), id: \.element.id) { index, ticket in
                    if index > 0 {
                        DashboardDivider()
                    }

                    ticketRow(ticket)
                }
            }
        }

        if candidates.hiddenCount > 0 {
            Text(SpendingEventsText.pickerHidden(candidates.hiddenCount))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }

        if viewModel.isFull {
            Text("Vous pouvez ajouter \(SpendingEventsText.maxPerCall) tickets à la fois.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    private func ticketRow(_ ticket: SpendingEventCandidate) -> some View {
        let isSelected = viewModel.selected.contains(ticket.id)
        let isBlocked = viewModel.isFull && !isSelected

        return Button {
            viewModel.toggle(ticket.id)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? EconomofarUI.accent : EconomofarUI.textTertiary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ticket.merchant)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(2)

                    Text(SpendingEventsText.dateText(ticket.date) + " · " + ticket.category)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .lineLimit(2)

                    if ticket.inWindow {
                        Text("Dans les dates de l'événement")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(SpendingEventsText.money(ticket.amount))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
            }
            .padding(16)
            .contentShape(Rectangle())
            .opacity(isBlocked ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isBlocked || viewModel.isSaving)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(ticket.merchant), \(SpendingEventsText.dateText(ticket.date)), \(ticket.category), \(SpendingEventsText.money(ticket.amount))"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }

    // MARK: Bottom bar

    private var addBar: some View {
        let count = viewModel.selected.count

        return Button {
            Task {
                if await viewModel.add(token: sessionManager.token) {
                    onAdded()
                    dismiss()
                } else {
                    // The reason of the refusal must stay on the screen after the list is read again
                    let reason = viewModel.errorMessage
                    await viewModel.load(token: sessionManager.token, query: String(trimmedQuery.prefix(100)), prune: true)

                    if let reason {
                        viewModel.errorMessage = reason
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                }

                Text(SpendingEventsText.addButton(count))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(count == 0 ? AnyShapeStyle(EconomofarUI.textTertiary) : AnyShapeStyle(EconomofarUI.mainGradient))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(count == 0 || viewModel.isSaving)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(EconomofarUI.background)
    }
}
