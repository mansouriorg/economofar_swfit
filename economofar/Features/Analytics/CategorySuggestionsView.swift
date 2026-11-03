import SwiftUI
import Combine

// MARK: - View model

struct SuggestionWindowOption: Identifiable {
    let months: Int
    let title: String

    var id: Int { months }
}

/// What the user is asked to confirm.
struct PendingSuggestionApply {
    let groups: [CategorySuggestionGroup]
}

@MainActor
final class CategorySuggestionsViewModel: ObservableObject {
    static let windows = [3, 12, 24]

    let windowOptions: [SuggestionWindowOption] = CategorySuggestionsViewModel.windows.map {
        SuggestionWindowOption(months: $0, title: "\($0) mois")
    }

    @Published var result: CategorySuggestions? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published var noticeMessage: String? = nil
    @Published var noticeIsPositive = true
    @Published private(set) var loadedMonths: Int? = nil
    @Published private(set) var isApplying = false
    @Published private(set) var progressText: String? = nil

    /// Choosing another period shows the spinner at once, before the request starts.
    @Published var months: Int = 12 {
        didSet {
            if months != oldValue {
                isLoading = true
                noticeMessage = nil
            }
        }
    }

    private var generation = 0
    private var loadedAt: Date? = nil

    func load(token: String?) async {
        // The tickets are being changed: the list is read again when that is done
        guard isApplying == false else {
            return
        }

        guard let token, !token.isEmpty else {
            errorMessage = "Votre session a expiré. Reconnectez-vous."
            isLoading = false
            return
        }

        generation += 1
        let current = generation
        let selectedMonths = months

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await CategorySuggestionsService.shared.fetch(
                token: token,
                months: selectedMonths
            )

            if current == generation {
                result = fetched
                loadedMonths = selectedMonths
                loadedAt = Date()
            }
        } catch APIError.unauthorized {
            // The session manager logs the user out
            if current == generation {
                errorMessage = "Votre session a expiré. Reconnectez-vous."
            }
        } catch {
            if current == generation, !Task.isCancelled {
                errorMessage = error.localizedDescription

                // Suggestions of an earlier day must not be offered as the current ones
                if let loadedAt, !Calendar.current.isDateInToday(loadedAt) {
                    result = nil
                    loadedMonths = nil
                    self.loadedAt = nil
                }
            }
        }

        if current == generation {
            isLoading = false
        }
    }

    /// Gives each ticket of the groups the category suggested for its merchant, one call after the other.
    func apply(_ groups: [CategorySuggestionGroup], token: String?) async {
        guard isApplying == false, groups.isEmpty == false else {
            return
        }

        guard let token, !token.isEmpty else {
            errorMessage = "Votre session a expiré. Reconnectez-vous."
            return
        }

        // A list still being loaded would bring back suggestions that are out of date
        generation += 1

        isApplying = true
        noticeMessage = nil
        errorMessage = nil

        let total = groups.reduce(0) { $0 + $1.ticketIds.count }
        var applied = 0
        var failed = 0
        var misses = 0
        var expired = false
        var stopped = false

        progressText = "0 sur \(total) tickets"

        outer: for group in groups {
            for ticketId in group.ticketIds {
                do {
                    try await CategorySuggestionsService.shared.apply(
                        ticketId: ticketId,
                        category: group.category,
                        token: token
                    )

                    applied += 1
                    misses = 0
                } catch {
                    if CategorySuggestionsService.isSessionExpired(error) {
                        expired = true
                        break outer
                    }

                    if CategorySuggestionsService.isAppliedDespiteError(error) {
                        applied += 1
                        misses = 0
                    } else {
                        failed += 1
                        misses += 1
                    }

                    // The server is not answering: no need to try every ticket
                    if misses >= 5 {
                        stopped = true
                        break outer
                    }
                }

                progressText = "\(applied + failed) sur \(total) tickets"
            }
        }

        isApplying = false
        progressText = nil

        // What was suggested is out of date now
        result = nil
        loadedMonths = nil

        if applied > 0 || failed > 0 || stopped {
            noticeMessage = CategorySuggestionsText.appliedMessage(applied: applied, failed: failed, stopped: stopped)
            noticeIsPositive = failed == 0 && stopped == false && expired == false && applied > 0
        }

        if expired {
            errorMessage = "Votre session a expiré. Reconnectez-vous."
            isLoading = false
            return
        }

        await load(token: token)
    }
}

// MARK: - Screen

struct CategorySuggestionsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = CategorySuggestionsViewModel()
    @State private var pending: PendingSuggestionApply? = nil

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

                    if let notice = viewModel.noticeMessage {
                        DashboardInfoBanner(
                            icon: viewModel.noticeIsPositive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                            message: notice,
                            tint: viewModel.noticeIsPositive ? EconomofarUI.success : EconomofarUI.warning,
                            background: (viewModel.noticeIsPositive ? EconomofarUI.success : EconomofarUI.warning).opacity(0.12)
                        )
                        .padding(.horizontal, -20)
                    }

                    picker

                    if viewModel.isApplying {
                        applyingCard
                    }

                    if let result = viewModel.result,
                       viewModel.loadedMonths == viewModel.months {
                        content(result)
                    } else if viewModel.isLoading || viewModel.isApplying {
                        ProgressView()
                            .padding(.top, 50)
                    } else {
                        retryButton
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
        .navigationTitle("Catégories suggérées")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(token: sessionManager.token)
        }
        .onChange(of: viewModel.months) { _ in
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }
        .confirmationDialog(
            pending.map { CategorySuggestionsText.confirmTitle($0.groups) } ?? "",
            isPresented: Binding(
                get: { pending != nil },
                set: { isShown in
                    if isShown == false {
                        pending = nil
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: pending
        ) { item in
            Button("Classer") {
                Task {
                    await viewModel.apply(item.groups, token: sessionManager.token)
                }
            }

            Button("Annuler", role: .cancel) {}
        } message: { item in
            Text(CategorySuggestionsText.confirmMessage(item.groups))
        }
    }

    // MARK: Controls

    private var picker: some View {
        Picker("Période", selection: $viewModel.months) {
            ForEach(viewModel.windowOptions) { option in
                Text(option.title).tag(option.months)
            }
        }
        .pickerStyle(.segmented)
        .disabled(viewModel.isApplying)
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
                .padding(.vertical, 14)
                .background(EconomofarUI.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var applyingCard: some View {
        HStack(spacing: 12) {
            ProgressView()

            VStack(alignment: .leading, spacing: 2) {
                Text("Classement en cours")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Text(viewModel.progressText ?? "")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Classement en cours, \(viewModel.progressText ?? "")"))
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ result: CategorySuggestions) -> some View {
        heroCard(result)

        if result.hasUncategorized {
            if result.groups.isEmpty {
                DashboardInfoBanner(
                    icon: "questionmark.circle.fill",
                    message: "Aucune suggestion fiable : il faut au moins 2 tickets déjà classés pour une même enseigne, dont 75\u{00A0}% dans la même catégorie.",
                    tint: EconomofarUI.accent,
                    background: EconomofarUI.accentSoft
                )
                .padding(.horizontal, -20)
            } else {
                if result.groups.count > 1 {
                    applyAllButton(result)
                }

                ForEach(Array(result.groups.enumerated()), id: \.offset) { _, group in
                    groupCard(group)
                }

                if result.hiddenGroupCount > 0 {
                    Text(CategorySuggestionsText.more(result.hiddenGroupCount))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                methodBanner
            }
        }
    }

    // MARK: Hero

    private func heroCard(_ result: CategorySuggestions) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Catégories suggérées · " + CategorySuggestionsText.periodText(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                Text(CategorySuggestionsText.headline(result))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(CategorySuggestionsText.summary(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                heroChip(title: "Sans catégorie", value: "\(result.uncategorizedCount)")
                heroChip(title: "Montant", value: AppFormat.money(result.uncategorizedAmount))
                heroChip(title: "Sans suggestion", value: "\(result.unresolvedCount)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.mainGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func heroChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .opacity(0.85)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title + " : " + value))
    }

    // MARK: Groups

    private func applyAllButton(_ result: CategorySuggestions) -> some View {
        Button {
            pending = PendingSuggestionApply(groups: result.groups)
        } label: {
            Label("Tout classer (\(CategorySuggestionsText.tickets(result.fixableTicketCount)))", systemImage: "wand.and.stars")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(EconomofarUI.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isApplying)
        .opacity(viewModel.isApplying ? 0.5 : 1)
    }

    private func groupCard(_ group: CategorySuggestionGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    DashboardIconBox(icon: "storefront.fill", tint: EconomofarUI.accent)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.merchant)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)
                            .lineLimit(2)

                        Text(CategorySuggestionsText.groupDetail(group))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                    }

                    Spacer()
                }

                HStack(spacing: 6) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))

                    Image(systemName: "tag.fill")
                        .font(.system(size: 11, weight: .bold))

                    Text(group.category)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundColor(EconomofarUI.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(EconomofarUI.accentSoft)
                .clipShape(Capsule())

                Text(CategorySuggestionsText.reason(group))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if group.isPartial {
                    Text(CategorySuggestionsText.partialNote(group))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(group.merchant), \(CategorySuggestionsText.groupDetail(group)), catégorie suggérée : \(group.category). \(CategorySuggestionsText.reason(group))" + (group.isPartial ? " " + CategorySuggestionsText.partialNote(group) : "")))

            Button {
                pending = PendingSuggestionApply(groups: [group])
            } label: {
                Text(CategorySuggestionsText.applyLabel(group))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isApplying)
            .opacity(viewModel.isApplying ? 0.5 : 1)
            .accessibilityLabel(Text("\(CategorySuggestionsText.applyLabel(group)) de \(group.merchant) en \(group.category)"))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
    }

    // MARK: Method

    private var methodBanner: some View {
        DashboardInfoBanner(
            icon: "info.circle.fill",
            message: "Une suggestion apparaît quand une enseigne a au moins 2 tickets déjà classés et qu'au moins 75\u{00A0}% d'entre eux sont dans la même catégorie. Seuls vos tickets déjà classés des 24 derniers mois sont utilisés. Rien n'est modifié sans votre confirmation, et vous pouvez corriger chaque ticket ensuite.",
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }
}
