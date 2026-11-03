import SwiftUI
import Combine

// MARK: - Rules shared by the screen and its view model

enum ShoppingListRules {
    static let maxNameLength = 100
    static let minQuantity = 1
    static let maxQuantity = 99

    /// Same count as the server: unicode scalars.
    static func limited(_ text: String, to limit: Int) -> String {
        var scalars = String.UnicodeScalarView()

        for scalar in text.unicodeScalars {
            if scalars.count >= limit {
                break
            }

            scalars.append(scalar)
        }

        return String(scalars)
    }

    private static let smallWords: Set<String> = [
        "de", "du", "des", "la", "le", "les", "au", "aux", "un", "une", "et", "en"
    ]

    /// Same idea as the server: capitals, accents, punctuation, the ligatures, a final "s", one-letter
    /// words and small words are ignored, and the order of the words does not matter.
    static func looseKey(_ text: String) -> String {
        let folded = text
            .lowercased()
            .replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "æ", with: "ae")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)

        var words = Set<String>()
        var current = ""

        func finishWord() {
            defer { current = "" }

            guard !current.isEmpty, !smallWords.contains(current) else { return }

            if current.count == 1, let first = current.first, first.isLetter {
                return
            }

            if current.count > 3 && current.hasSuffix("s") {
                words.insert(String(current.dropLast()))
            } else {
                words.insert(current)
            }
        }

        for character in folded {
            if character.isLetter || character.isNumber {
                current.append(character)
            } else {
                finishWord()
            }
        }

        finishWord()

        return words.sorted().joined(separator: " ")
    }
}

struct ShoppingSummary {
    var remaining = 0
    var priced = 0
    var unpriced = 0
    var estimatedTotal = 0.0
    var potentialSavings = 0.0
}

enum ShoppingAction {
    case add(name: String, quantity: Int)
    case update(id: Int, quantity: Int?, checked: Bool?)
    case remove(id: Int)
    case clearChecked
}

// MARK: - View model

/// Changes are shown at once, then sent to the server one after the other.
/// Only the answer to the last change replaces the list, so a slow answer never undoes a newer tap.
/// A download that was started before a change is ignored too (see epoch).
@MainActor
final class ShoppingListViewModel: ObservableObject {
    @Published var newName = ""
    @Published private(set) var list: ShoppingList? = nil
    @Published private(set) var isLoading = false
    @Published private(set) var pendingCount = 0
    @Published var errorMessage: String? = nil

    /// Shared by every instance: changes made on a screen that was left finish before a new screen loads.
    private static var sharedTail: Task<Void, Never>? = nil

    private var epoch = 0
    private var serverSnapshot: ShoppingList? = nil
    private var nextTemporaryId = -1

    var hasLoaded: Bool {
        list != nil
    }

    var items: [ShoppingListItem] {
        list?.items ?? []
    }

    var toBuy: [ShoppingListItem] {
        items.filter { !$0.checked }
    }

    var bought: [ShoppingListItem] {
        items.filter { $0.checked }
    }

    var suggestions: [ShoppingSuggestion] {
        list?.suggestions ?? []
    }

    /// Figures of the "to buy" part, computed from what is on screen so they follow every tap at once.
    var summary: ShoppingSummary {
        var result = ShoppingSummary()

        for item in toBuy {
            result.remaining += 1

            if let unit = item.unitPrice {
                let count = Double(item.quantity)

                result.priced += 1
                result.estimatedTotal += unit * count

                if let cheaper = item.cheaperPrice, cheaper < unit {
                    result.potentialSavings += (unit - cheaper) * count
                }
            } else {
                result.unpriced += 1
            }
        }

        return result
    }

    var canAdd: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Loading

    func load(token: String?) async {
        guard let token, !token.isEmpty else { return }

        isLoading = true

        await ShoppingListViewModel.sharedTail?.value

        let startEpoch = epoch

        do {
            let result = try await ShoppingListService.shared.fetch(token: token)

            if pendingCount == 0 && epoch == startEpoch {
                list = result
                serverSnapshot = result
                errorMessage = nil
            }
        } catch {
            if let text = message(for: error) {
                errorMessage = text
            }
        }

        isLoading = false
    }

    // MARK: Changes

    func addTyped(token: String?) {
        let name = ShoppingListRules.limited(
            newName.trimmingCharacters(in: .whitespacesAndNewlines),
            to: ShoppingListRules.maxNameLength
        )

        guard !name.isEmpty, let token, !token.isEmpty else { return }

        newName = ""
        errorMessage = nil

        appendLocal(name: name)
        enqueue(.add(name: name, quantity: 1), token: token, restoreName: name)
    }

    func addSuggestion(_ suggestion: ShoppingSuggestion, token: String?) {
        guard let token, !token.isEmpty else { return }

        errorMessage = nil

        if var current = list {
            current.suggestions.removeAll { $0.id == suggestion.id }
            list = current
        }

        let name = ShoppingListRules.limited(suggestion.name, to: ShoppingListRules.maxNameLength)

        appendLocal(name: name)
        enqueue(.add(name: name, quantity: 1), token: token, restoreName: nil)
    }

    func toggle(_ item: ShoppingListItem, token: String?) {
        guard let token, !token.isEmpty else { return }

        let target = !(items.first(where: { $0.id == item.id })?.checked ?? item.checked)

        errorMessage = nil
        updateLocal(id: item.id) { $0.checked = target }

        enqueue(.update(id: item.id, quantity: nil, checked: target), token: token, restoreName: nil)
    }

    func changeQuantity(_ item: ShoppingListItem, by delta: Int, token: String?) {
        guard let token, !token.isEmpty else { return }

        let current = items.first(where: { $0.id == item.id })?.quantity ?? item.quantity
        let target = min(max(current + delta, ShoppingListRules.minQuantity), ShoppingListRules.maxQuantity)

        guard target != current else { return }

        errorMessage = nil
        updateLocal(id: item.id) { $0.quantity = target }

        enqueue(.update(id: item.id, quantity: target, checked: nil), token: token, restoreName: nil)
    }

    func remove(_ item: ShoppingListItem, token: String?) {
        guard let token, !token.isEmpty else { return }

        errorMessage = nil

        if var current = list {
            current.items.removeAll { $0.id == item.id }
            list = current
        }

        enqueue(.remove(id: item.id), token: token, restoreName: nil)
    }

    func clearChecked(token: String?) {
        guard let token, !token.isEmpty else { return }

        errorMessage = nil

        if var current = list {
            current.items.removeAll { $0.checked }
            list = current
        }

        enqueue(.clearChecked, token: token, restoreName: nil)
    }

    // MARK: Queue

    /// Shows an added item at once. A line with the same name only gets one more.
    private func appendLocal(name: String) {
        guard var current = list else { return }

        let key = ShoppingListRules.looseKey(name)

        if let index = current.items.firstIndex(where: { ShoppingListRules.looseKey($0.name) == key }) {
            if current.items[index].checked {
                current.items[index].checked = false
                current.items[index].quantity = ShoppingListRules.minQuantity
            } else {
                current.items[index].quantity = min(current.items[index].quantity + 1, ShoppingListRules.maxQuantity)
            }
        } else {
            current.items.append(
                ShoppingListItem(
                    id: nextTemporaryId,
                    name: name,
                    quantity: ShoppingListRules.minQuantity,
                    checked: false,
                    unitPrice: nil,
                    lineTotal: nil,
                    lastMerchant: nil,
                    cheaperMerchant: nil,
                    cheaperPrice: nil,
                    matchedName: nil
                )
            )

            nextTemporaryId -= 1
        }

        list = current
    }

    private func updateLocal(id: Int, _ change: (inout ShoppingListItem) -> Void) {
        guard var current = list, let index = current.items.firstIndex(where: { $0.id == id }) else { return }

        change(&current.items[index])
        list = current
    }

    private func enqueue(_ action: ShoppingAction, token: String, restoreName: String?) {
        pendingCount += 1
        epoch += 1

        let previous = ShoppingListViewModel.sharedTail

        ShoppingListViewModel.sharedTail = Task {
            await previous?.value
            await self.run(action, token: token, restoreName: restoreName)
        }
    }

    private func run(_ action: ShoppingAction, token: String, restoreName: String?) async {
        do {
            let result = try await perform(action, token: token)

            pendingCount -= 1
            epoch += 1
            serverSnapshot = result

            if pendingCount == 0 {
                list = result
            }
        } catch {
            pendingCount -= 1
            epoch += 1

            if let text = message(for: error) {
                errorMessage = text
            }

            if let restoreName, newName.isEmpty {
                newName = restoreName
            }

            if pendingCount == 0 {
                await reload(token: token)
            }
        }
    }

    /// After a failed change: ask the server for the real list, or go back to the last list it sent.
    private func reload(token: String) async {
        let startEpoch = epoch
        let result = try? await ShoppingListService.shared.fetch(token: token)

        guard pendingCount == 0, epoch == startEpoch else { return }

        if let result {
            list = result
            serverSnapshot = result
        } else if let snapshot = serverSnapshot {
            list = snapshot
        }
    }

    private func perform(_ action: ShoppingAction, token: String) async throws -> ShoppingList {
        let service = ShoppingListService.shared

        switch action {
        case .add(let name, let quantity):
            return try await service.add(name: name, quantity: quantity, token: token)
        case .update(let id, let quantity, let checked):
            return try await service.update(id: id, quantity: quantity, checked: checked, token: token)
        case .remove(let id):
            return try await service.remove(id: id, token: token)
        case .clearChecked:
            return try await service.clearChecked(token: token)
        }
    }

    /// Nil when nothing should be shown (the screen was left, or the session expired and the app logs out).
    private func message(for error: Error) -> String? {
        if Task.isCancelled {
            return nil
        }

        if let apiError = error as? APIError, case .unauthorized = apiError {
            return nil
        }

        return error.localizedDescription
    }
}

// MARK: - Screen

struct ShoppingListView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = ShoppingListViewModel()

    @State private var showClearConfirmation = false

    var body: some View {
        ZStack {
            EconomofarUI.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if let errorMessage = viewModel.errorMessage {
                        DashboardInfoBanner(
                            icon: "exclamationmark.triangle.fill",
                            message: errorMessage,
                            tint: EconomofarUI.danger,
                            background: EconomofarUI.dangerSoft
                        )
                        .padding(.horizontal, -20)
                    }

                    addCard

                    if !viewModel.suggestions.isEmpty {
                        suggestionsCard
                    }

                    if viewModel.hasLoaded {
                        if viewModel.items.isEmpty {
                            emptyState
                        } else {
                            summaryCard
                            listCard(title: nil, items: viewModel.toBuy)
                            boughtSection
                            footnote
                        }
                    } else if viewModel.errorMessage != nil && !viewModel.isLoading {
                        retryButton
                    } else {
                        ProgressView()
                            .padding(.top, 30)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                await viewModel.load(token: sessionManager.token)
            }
        }
        .navigationTitle("Liste de courses")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(token: sessionManager.token)
        }
        .confirmationDialog(
            "Retirer les articles cochés ?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Retirer", role: .destructive) {
                viewModel.clearChecked(token: sessionManager.token)
            }

            Button("Annuler", role: .cancel) {}
        }
    }

    // MARK: Add

    private var addCard: some View {
        HStack(spacing: 10) {
            TextField("Ajouter un article (lait, pain…)", text: $viewModel.newName)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .onSubmit {
                    viewModel.addTyped(token: sessionManager.token)
                }
                .onChange(of: viewModel.newName) { value in
                    let limited = ShoppingListRules.limited(value, to: ShoppingListRules.maxNameLength)

                    if limited != value {
                        viewModel.newName = limited
                    }
                }

            if viewModel.pendingCount > 0 {
                ProgressView()
            }

            Button {
                viewModel.addTyped(token: sessionManager.token)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(viewModel.canAdd ? EconomofarUI.accent : EconomofarUI.textTertiary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canAdd)
            .accessibilityLabel("Ajouter à la liste")
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
    }

    // MARK: Suggestions

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)

                Text("À racheter ?")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.suggestions) { suggestion in
                        suggestionChip(suggestion)
                    }
                }
            }

            Text("Selon le rythme de vos achats. L'horloge marque un article que vous rachetez d'habitude à cette date.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
    }

    private func suggestionChip(_ suggestion: ShoppingSuggestion) -> some View {
        Button {
            viewModel.addSuggestion(suggestion, token: sessionManager.token)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: suggestion.due ? "clock.arrow.circlepath" : "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(suggestion.due ? EconomofarUI.warning : EconomofarUI.accent)

                VStack(alignment: .leading, spacing: 1) {
                    Text(suggestion.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(daysText(suggestion.daysSinceLast))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: 220)
            .background(suggestion.due ? EconomofarUI.warningSoft : EconomofarUI.accentSoft)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText(for: suggestion))
    }

    private func accessibilityText(for suggestion: ShoppingSuggestion) -> String {
        var text = "Ajouter \(suggestion.name), \(daysText(suggestion.daysSinceLast))"

        if suggestion.due {
            text += ", à racheter"
        }

        return text
    }

    private func daysText(_ days: Int) -> String {
        if days <= 0 {
            return "acheté aujourd'hui"
        }

        if days == 1 {
            return "acheté hier"
        }

        return "acheté il y a \(days) jours"
    }

    // MARK: Summary

    private var summaryCard: some View {
        let summary = viewModel.summary
        let remaining = summary.remaining

        return VStack(alignment: .leading, spacing: 8) {
            Text("Reste à acheter")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.85))

            if remaining == 0 {
                Text("Tout est dans le panier")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            } else {
                Text("\(remaining) article\(remaining > 1 ? "s" : "")")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if summary.priced > 0 {
                    Text(priceSummary(summary))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.9))
                } else {
                    Text("Aucun prix connu pour le moment")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.9))
                }

                if summary.potentialSavings > 0.004 {
                    Text("Jusqu'à \(AppFormat.money(summary.potentialSavings)) d'économie en achetant dans les magasins les moins chers")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func priceSummary(_ summary: ShoppingSummary) -> String {
        var text = "Environ \(AppFormat.money(summary.estimatedTotal))"

        if summary.unpriced > 0 {
            text += " · \(summary.unpriced) sans prix connu"
        }

        return text
    }

    // MARK: List

    @ViewBuilder
    private var boughtSection: some View {
        let bought = viewModel.bought

        if !bought.isEmpty {
            VStack(spacing: 10) {
                listCard(title: "Dans le panier", items: bought)

                Button {
                    showClearConfirmation = true
                } label: {
                    Label("Retirer les articles cochés", systemImage: "trash")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(EconomofarUI.dangerSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func listCard(title: String?, items: [ShoppingListItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if let title {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 4)
                }

                ForEach(items) { item in
                    if item.id != items.first?.id {
                        Divider()
                            .padding(.leading, 60)
                    }

                    row(item)
                }
            }
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
    }

    private func row(_ item: ShoppingListItem) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Button {
                viewModel.toggle(item, token: sessionManager.token)
            } label: {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(item.checked ? EconomofarUI.success : EconomofarUI.textTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.checked ? "Remettre \(item.name) dans la liste" : "Marquer \(item.name) comme acheté")

            VStack(alignment: .leading, spacing: 3) {
                Text(item.checked && item.quantity > 1 ? "\(item.name) ×\(item.quantity)" : item.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(item.checked ? EconomofarUI.textTertiary : EconomofarUI.textPrimary)
                    .strikethrough(item.checked)
                    .fixedSize(horizontal: false, vertical: true)

                if !item.checked {
                    Text(priceDetail(item))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(item.unitPrice == nil ? EconomofarUI.textTertiary : EconomofarUI.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let source = sourceText(item) {
                        Text(source)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let cheaper = cheaperText(item) {
                        Text(cheaper)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.success)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    quantityControl(item)
                        .padding(.top, 2)
                }
            }
            .padding(.top, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                viewModel.remove(item, token: sessionManager.token)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retirer \(item.name)")
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .disabled(item.isPending)
        .opacity(item.isPending ? 0.6 : 1)
    }

    private func quantityControl(_ item: ShoppingListItem) -> some View {
        HStack(spacing: 4) {
            Button {
                viewModel.changeQuantity(item, by: -1, token: sessionManager.token)
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(item.quantity > ShoppingListRules.minQuantity ? EconomofarUI.accent : EconomofarUI.textTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(item.quantity <= ShoppingListRules.minQuantity)
            .accessibilityLabel("Une unité de moins pour \(item.name)")

            Text("\(item.quantity)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .frame(minWidth: 24)
                .accessibilityLabel("Quantité \(item.quantity)")

            Button {
                viewModel.changeQuantity(item, by: 1, token: sessionManager.token)
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(item.quantity < ShoppingListRules.maxQuantity ? EconomofarUI.accent : EconomofarUI.textTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(item.quantity >= ShoppingListRules.maxQuantity)
            .accessibilityLabel("Une unité de plus pour \(item.name)")
        }
    }

    private func sourceText(_ item: ShoppingListItem) -> String? {
        guard item.unitPrice != nil, let matched = item.matchedName, !matched.isEmpty else {
            return nil
        }

        if ShoppingListRules.looseKey(matched) == ShoppingListRules.looseKey(item.name) {
            return nil
        }

        return "Prix de « \(matched) »"
    }

    private func priceDetail(_ item: ShoppingListItem) -> String {
        if item.isPending {
            return "Ajout en cours…"
        }

        guard let unit = item.unitPrice, let line = item.estimatedLine else {
            return "Pas encore de prix connu"
        }

        var text: String

        if item.quantity > 1 {
            text = "\(item.quantity) × \(AppFormat.money(unit)) = \(AppFormat.money(line))"
        } else {
            text = AppFormat.money(unit)
        }

        if let merchant = item.lastMerchant, !merchant.isEmpty {
            text += " · \(merchant)"
        }

        return text
    }

    private func cheaperText(_ item: ShoppingListItem) -> String? {
        guard let merchant = item.cheaperMerchant, !merchant.isEmpty, let price = item.cheaperPrice else {
            return nil
        }

        return "Moins cher chez \(merchant) : \(AppFormat.money(price))"
    }

    // MARK: Other states

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "cart")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(EconomofarUI.accent)

            Text("Votre liste est vide")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text("Ajoutez un article ci-dessus. Les prix de vos derniers achats s'affichent tout seuls.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
    }

    private var retryButton: some View {
        Button {
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        } label: {
            Label("Réessayer", systemImage: "arrow.clockwise")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(EconomofarUI.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var footnote: some View {
        Text("Les prix viennent de vos tickets : le dernier prix payé, et le magasin le moins cher trouvé dans vos achats récents. Un prix apparaît dès que l'article a été acheté à au moins deux dates différentes.")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(EconomofarUI.textTertiary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }
}
