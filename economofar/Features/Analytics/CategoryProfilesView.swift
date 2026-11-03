import SwiftUI
import Combine

// MARK: - View model

struct CategoryWindowOption: Identifiable {
    let months: Int
    let title: String

    var id: Int { months }
}

@MainActor
final class CategoryProfilesViewModel: ObservableObject {
    static let windows = [3, 12, 24]

    let windowOptions: [CategoryWindowOption] = CategoryProfilesViewModel.windows.map {
        CategoryWindowOption(months: $0, title: "\($0) mois")
    }

    @Published var result: CategoryProfiles? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published private(set) var loadedMonths: Int? = nil

    /// Choosing another period shows the spinner at once, before the request starts.
    @Published var months: Int = 12 {
        didSet {
            if months != oldValue {
                isLoading = true

                // An answer for the period left behind must not be taken for the new one
                generation += 1
            }
        }
    }

    private var generation = 0
    private var loadedAt: Date? = nil

    func load(token: String?) async {
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
            let fetched = try await CategoryProfilesService.shared.fetch(
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

                // Figures of an earlier day must not be shown as the current ones
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

    /// The figures were counted on an earlier day: they are read again.
    func reloadIfNewDay(token: String?) async {
        guard let loadedAt, !Calendar.current.isDateInToday(loadedAt) else {
            return
        }

        await load(token: token)
    }

    /// The category with this key in the figures that are loaded now.
    func profile(key: String) -> CategoryProfile? {
        result?.categories.first { $0.key == key }
    }
}

// MARK: - Screen

struct CategoryProfilesView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = CategoryProfilesViewModel()

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

                    picker

                    if let result = viewModel.result,
                       viewModel.loadedMonths == viewModel.months {
                        content(result)
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
        .navigationTitle("Mes catégories")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Also when coming back from a category page: the figures are read again
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        }
        .onChange(of: viewModel.months) { _ in
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

    private var picker: some View {
        Picker("Période", selection: $viewModel.months) {
            ForEach(viewModel.windowOptions) { option in
                Text(option.title).tag(option.months)
            }
        }
        .pickerStyle(.segmented)
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
    private func content(_ result: CategoryProfiles) -> some View {
        heroCard(result)

        if result.hasTickets {
            categoryList(result)

            methodBanner
        } else {
            DashboardInfoBanner(
                icon: "questionmark.circle.fill",
                message: CategoryProfilesText.emptyHint,
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }
    }

    // MARK: Hero

    private func heroCard(_ result: CategoryProfiles) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Mes catégories · " + CategoryProfilesText.periodText(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                Text(CategoryProfilesText.headline(result))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(CategoryProfilesText.summary(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                heroChip(title: "Catégories", value: "\(result.categoryCount)")
                heroChip(title: "Dépenses", value: AppFormat.money(result.totalAmount))
                heroChip(title: "Tickets", value: "\(result.ticketCount)")
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

    // MARK: Categories

    private func categoryList(_ result: CategoryProfiles) -> some View {
        VStack(spacing: 8) {
            DashboardSectionCard(title: CategoryProfilesText.listTitle(shown: result.categories.count)) {
                ForEach(Array(result.categories.enumerated()), id: \.element.id) { index, profile in
                    if index > 0 {
                        DashboardDivider()
                    }

                    row(profile)
                }
            }

            if result.hiddenCount > 0 {
                Text(CategoryProfilesText.hiddenNote(hidden: result.hiddenCount, shown: result.categories.count))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func row(_ profile: CategoryProfile) -> some View {
        NavigationLink {
            CategoryProfileDetailView(viewModel: viewModel, key: profile.key, title: profile.category)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                DashboardIconBox(icon: "square.grid.2x2.fill", tint: EconomofarUI.accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.category)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(2)

                    Text(CategoryProfilesText.rowDetail(profile))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    shareBar(CategoryProfilesText.shareFraction(profile.share))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(AppFormat.money(profile.total))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(CategoryProfilesText.shareText(profile.share))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
                    .padding(.top, 4)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
    }

    private func shareBar(_ fraction: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(EconomofarUI.accentSoft)

                Capsule()
                    .fill(EconomofarUI.accent)
                    .frame(width: max(proxy.size.width * CGFloat(fraction), fraction > 0 ? 6 : 0))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    // MARK: Method

    private var methodBanner: some View {
        DashboardInfoBanner(
            icon: "info.circle.fill",
            message: "Une catégorie écrite de plusieurs façons (majuscules, accents, ponctuation) est regroupée. Les tickets sans catégorie sont dans « Autre ». Touchez une catégorie pour voir ses enseignes, son rythme et ses derniers tickets.",
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }
}
