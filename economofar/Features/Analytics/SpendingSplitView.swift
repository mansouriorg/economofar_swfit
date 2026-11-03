import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class SpendingSplitViewModel: ObservableObject {
    @Published var overview: SpendingSplitOverview? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published private(set) var isSaving = false

    /// The month the bar at the top shows and the months next to it, kept while a month is loading
    /// so that the buttons never act on a month that has been left behind.
    @Published private(set) var barMonth: String? = nil
    @Published private(set) var barPrevious: String? = nil
    @Published private(set) var barNext: String? = nil

    /// The month that is asked for, nil for the current month.
    private var requestedMonth: String? = nil
    private var generation = 0
    private var loadedAt: Date? = nil

    /// The last figures that were read, with the month that was asked for to get them: when another
    /// month can not be read, the screen goes back to them and the arrows work again.
    private var lastGood: SpendingSplitOverview? = nil
    private var lastGoodRequested: String? = nil

    func load(token: String?) async {
        guard let token, !token.isEmpty else {
            errorMessage = "Votre session a expiré. Reconnectez-vous."
            isLoading = false
            return
        }

        generation += 1
        let current = generation
        let month = requestedMonth

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await SpendingSplitService.shared.fetch(token: token, month: month)

            if current == generation {
                overview = fetched
                barMonth = fetched.month
                barPrevious = fetched.previousMonth
                barNext = fetched.nextMonth
                loadedAt = Date()
                lastGood = fetched
                lastGoodRequested = month
            }
        } catch APIError.unauthorized {
            // The session manager logs the user out
            if current == generation {
                errorMessage = "Votre session a expiré. Reconnectez-vous."
            }
        } catch {
            if current == generation, !Task.isCancelled {
                errorMessage = error.localizedDescription

                // Figures of an earlier day must not be shown as the current ones
                if let loadedAt, !Calendar.current.isDateInToday(loadedAt) {
                    overview = nil
                    lastGood = nil
                    self.loadedAt = nil
                } else if overview == nil, let lastGood {
                    overview = lastGood
                    requestedMonth = lastGoodRequested
                    barMonth = lastGood.month
                    barPrevious = lastGood.previousMonth
                    barNext = lastGood.nextMonth
                }
            }
        }

        if current == generation {
            isLoading = false
        }
    }

    /// The figures were counted on an earlier day: they are read again.
    func reloadIfNewDay(token: String?) async {
        guard let loadedAt, !Calendar.current.isDateInToday(loadedAt) else {
            return
        }

        await load(token: token)
    }

    /// Chooses another month; the caller reads the figures again.
    func show(month: String) {
        guard month != requestedMonth else {
            return
        }

        requestedMonth = month
        overview = nil
        barMonth = month
        barPrevious = nil
        barNext = nil
        isLoading = true

        // An answer for the month left behind must not be taken for the new one
        generation += 1
    }

    /// Puts a category in a group ("NEED", "WANT", "EXCLUDED") or gives it back to the proposed one
    /// ("DEFAULT"), then reads the figures again.
    func assign(key: String, group: String, token: String?) async {
        guard !isSaving else {
            return
        }

        guard let token, !token.isEmpty else {
            errorMessage = "Votre session a expiré. Reconnectez-vous."
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            try await SpendingSplitService.shared.setGroup(token: token, category: key, group: group)
        } catch APIError.unauthorized {
            // The session manager logs the user out
            errorMessage = "Votre session a expiré. Reconnectez-vous."
            isSaving = false
            return
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return
        }

        isSaving = false

        await load(token: token)

        // The choice is kept even when the figures could not be read again
        if errorMessage != nil {
            errorMessage = SpendingSplitText.savedButNotRefreshed
        }
    }
}

// MARK: - Screen

struct SpendingSplitView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = SpendingSplitViewModel()

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

                    monthBar

                    if let overview = viewModel.overview {
                        content(overview)
                    } else if viewModel.isLoading {
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
        .navigationTitle("Besoins, envies, épargne")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Also when coming back from a ticket: the figures are read again
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task {
                    await viewModel.reloadIfNewDay(token: sessionManager.token)
                }
            }
        }
    }

    // MARK: Controls

    private var monthBar: some View {
        HStack(spacing: 12) {
            monthButton(icon: "chevron.left", label: "Mois précédent", target: viewModel.barPrevious)

            Text(viewModel.barMonth.map { SpendingSplitText.monthTitle($0) } ?? "Ce mois-ci")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            monthButton(icon: "chevron.right", label: "Mois suivant", target: viewModel.barNext)
        }
    }

    private func monthButton(icon: String, label: String, target: String?) -> some View {
        Button {
            if let target {
                viewModel.show(month: target)

                Task {
                    await viewModel.load(token: sessionManager.token)
                }
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(EconomofarUI.accent)
                .frame(width: 40, height: 40)
                .background(EconomofarUI.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(target == nil)
        .opacity(target == nil ? 0.35 : 1)
        .accessibilityLabel(Text(label))
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

    // MARK: Content

    @ViewBuilder
    private func content(_ overview: SpendingSplitOverview) -> some View {
        heroCard(overview)

        if overview.currentMonth && overview.hasIncome {
            DashboardInfoBanner(
                icon: "clock.fill",
                message: SpendingSplitText.currentMonthHint,
                tint: EconomofarUI.warning,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }

        if overview.hasTickets {
            slicesCard(overview)

            if overview.hasUnsortedSpending {
                DashboardInfoBanner(
                    icon: "questionmark.circle.fill",
                    message: SpendingSplitText.unsortedHint(count: overview.classifiableUnsortedCount),
                    tint: EconomofarUI.accent,
                    background: EconomofarUI.accentSoft
                )
                .padding(.horizontal, -20)
            }

            categoriesCard(overview)
        } else {
            DashboardInfoBanner(
                icon: "questionmark.circle.fill",
                message: SpendingSplitText.emptyMonthHint,
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }

        methodBanner
    }

    // MARK: Hero

    private func heroCard(_ overview: SpendingSplitOverview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Règle 50/30/20 · " + SpendingSplitText.monthTitle(overview.month))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                Text(SpendingSplitText.headline(overview))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(SpendingSplitText.summary(overview))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                if let share = SpendingSplitText.savedShare(overview) {
                    Text(share)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                heroChip(title: "Revenus", value: overview.hasIncome ? SpendingSplitText.money(overview.income) : "-")
                heroChip(title: "Dépenses comptées", value: SpendingSplitText.money(overview.spent))
                heroChip(title: overview.ticketCount < 2 ? "Ticket" : "Tickets", value: "\(overview.ticketCount)")
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

    // MARK: Slices

    private func groupTint(_ group: SpendingSplitGroup) -> Color {
        switch group {
        case .need:
            return EconomofarUI.accent
        case .want:
            return EconomofarUI.warning
        case .savings:
            return EconomofarUI.success
        case .unsorted, .excluded:
            return EconomofarUI.textTertiary
        }
    }

    private func levelTint(_ slice: SpendingSplitSlice) -> Color {
        switch slice.level {
        case .over, .under:
            return EconomofarUI.danger
        case .ok, .neutral:
            return groupTint(slice.group)
        }
    }

    private func slicesCard(_ overview: SpendingSplitOverview) -> some View {
        VStack(spacing: 8) {
            DashboardSectionCard(title: "Votre mois en trois parts") {
                ForEach(Array(overview.groups.enumerated()), id: \.element.id) { index, slice in
                    if index > 0 {
                        DashboardDivider()
                    }

                    sliceRow(slice, hasIncome: overview.hasIncome)
                }
            }

            if overview.excludedCategoryCount > 0 {
                footnote(SpendingSplitText.excludedLine(amount: overview.excluded, count: overview.excludedCategoryCount))
            }
        }
    }

    private func sliceRow(_ slice: SpendingSplitSlice, hasIncome: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            DashboardIconBox(icon: SpendingSplitText.icon(slice.group), tint: groupTint(slice.group))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(SpendingSplitText.title(slice.group))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(2)

                Text(SpendingSplitText.detail(slice, hasIncome: hasIncome))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let standing = SpendingSplitText.standing(slice) {
                    Text(standing)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(slice.level == .ok ? EconomofarUI.textSecondary : levelTint(slice))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if slice.targetAmount != nil {
                    progressBar(SpendingSplitText.fraction(amount: slice.amount, target: slice.targetAmount), tint: levelTint(slice))
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(slice.amount.map { SpendingSplitText.money($0) } ?? "-")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(slice.level == .ok || slice.level == .neutral ? EconomofarUI.textPrimary : levelTint(slice))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(SpendingSplitText.rowAccessibility(slice, hasIncome: hasIncome)))
    }

    private func progressBar(_ fraction: Double, tint: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.16))

                Capsule()
                    .fill(tint)
                    .frame(width: max(proxy.size.width * CGFloat(fraction), fraction > 0 ? 6 : 0))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    // MARK: Categories

    private func categoriesCard(_ overview: SpendingSplitOverview) -> some View {
        VStack(spacing: 8) {
            DashboardSectionCard(title: SpendingSplitText.categoriesTitle + " · \(overview.categoryCount)") {
                ForEach(Array(overview.categories.enumerated()), id: \.element.id) { index, category in
                    if index > 0 {
                        DashboardDivider()
                    }

                    categoryRow(category)
                }
            }

            if overview.hiddenCategoryCount > 0 {
                footnote(SpendingSplitText.hiddenNote(hidden: overview.hiddenCategoryCount, shown: overview.categories.count))
            }

            footnote(SpendingSplitText.chooseHint)
        }
    }

    private func categoryRow(_ category: SpendingSplitCategory) -> some View {
        HStack(alignment: .center, spacing: 14) {
            DashboardIconBox(icon: SpendingSplitText.icon(category.currentGroup), tint: groupTint(category.currentGroup))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(2)

                Text(SpendingSplitText.categoryDetail(category))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !category.editable {
                    Text(category.key.isEmpty ? SpendingSplitText.noCategoryHint : SpendingSplitText.longNameHint)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(SpendingSplitText.money(category.amount))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)

            if category.editable {
                categoryMenu(category)
            }
        }
        .padding(16)
        .accessibilityElement(children: .contain)
    }

    private func categoryMenu(_ category: SpendingSplitCategory) -> some View {
        Menu {
            choiceButton(category, group: .need, code: "NEED", icon: "house.fill")
            choiceButton(category, group: .want, code: "WANT", icon: "gift.fill")
            choiceButton(category, group: .excluded, code: "EXCLUDED", icon: "minus.circle.fill")

            if category.custom {
                Button {
                    Task {
                        await viewModel.assign(key: category.key, group: "DEFAULT", token: sessionManager.token)
                    }
                } label: {
                    Label("Rétablir le classement proposé", systemImage: "arrow.uturn.backward")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(EconomofarUI.accent)
                .frame(width: 36, height: 36)
        }
        .disabled(viewModel.isSaving)
        .accessibilityLabel(Text("Changer le groupe de \(category.name)"))
    }

    private func choiceButton(_ category: SpendingSplitCategory, group: SpendingSplitGroup, code: String, icon: String) -> some View {
        Button {
            Task {
                await viewModel.assign(key: category.key, group: code, token: sessionManager.token)
            }
        } label: {
            Label(
                SpendingSplitText.choiceTitle(group),
                systemImage: category.currentGroup == group ? "checkmark" : icon
            )
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(EconomofarUI.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    // MARK: Method

    private var methodBanner: some View {
        DashboardInfoBanner(
            icon: "info.circle.fill",
            message: SpendingSplitText.method,
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }
}
