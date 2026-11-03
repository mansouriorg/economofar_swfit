import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class PaymentUsageViewModel: ObservableObject {
    let monthsOptions = PaymentUsageMonthsOption.all

    @Published var result: PaymentUsage? = nil
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published private(set) var loadedMonths: Int? = nil

    /// Choosing another length shows the spinner at once, before the request starts.
    @Published var months: Int = 12 {
        didSet {
            if months != oldValue {
                isLoading = true

                // An answer for the length left behind must not be taken for the new one
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
            let fetched = try await PaymentUsageService.shared.fetch(
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

    /// The payment method with this key in the figures that are loaded now.
    func method(key: String) -> PaymentUsageMethod? {
        result?.methods.first { $0.key == key }
    }
}

// MARK: - Screen

struct PaymentUsageView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = PaymentUsageViewModel()

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
        .navigationTitle("Moyens de paiement")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Also when coming back from a method page: the figures are read again
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
            ForEach(viewModel.monthsOptions) { option in
                Text(option.title).tag(option.value)
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
    private func content(_ result: PaymentUsage) -> some View {
        heroCard(result)

        if result.hasTickets {
            if result.methods.isEmpty {
                DashboardInfoBanner(
                    icon: "questionmark.circle.fill",
                    message: PaymentUsageText.noMethodHint,
                    tint: EconomofarUI.accent,
                    background: EconomofarUI.accentSoft
                )
                .padding(.horizontal, -20)
            }

            methodsCard(result)

            methodBanner
        } else {
            DashboardInfoBanner(
                icon: "questionmark.circle.fill",
                message: PaymentUsageText.emptyHint,
                tint: EconomofarUI.accent,
                background: EconomofarUI.accentSoft
            )
            .padding(.horizontal, -20)
        }
    }

    // MARK: Hero

    private func heroCard(_ result: PaymentUsage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Moyens de paiement · " + PaymentUsageText.periodText(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                Text(PaymentUsageText.headline(result))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(PaymentUsageText.summary(result))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 10) {
                heroChip(title: "Tickets", value: "\(result.ticketCount)")
                heroChip(title: result.methodCount < 2 ? "Moyen utilisé" : "Moyens utilisés", value: "\(result.methodCount)")
                heroChip(title: "Plus gros total", value: PaymentUsageText.mainMethodText(result))
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

    // MARK: Methods

    private func methodsCard(_ result: PaymentUsage) -> some View {
        VStack(spacing: 8) {
            DashboardSectionCard(title: PaymentUsageText.listTitle(count: result.methodCount)) {
                ForEach(Array(result.methods.enumerated()), id: \.element.id) { index, method in
                    if index > 0 {
                        DashboardDivider()
                    }

                    methodRow(method)
                }

                if result.unspecifiedCount > 0 {
                    if result.methods.isEmpty == false {
                        DashboardDivider()
                    }

                    unspecifiedRow(result)
                }
            }

            if result.hiddenCount > 0 {
                footnote(PaymentUsageText.hiddenNote(hidden: result.hiddenCount, shown: result.methods.count))
            }
        }
    }

    private func methodRow(_ method: PaymentUsageMethod) -> some View {
        NavigationLink {
            PaymentUsageDetailView(viewModel: viewModel, key: method.key, title: method.name)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                DashboardIconBox(icon: PaymentUsageText.icon(forKey: method.key), tint: EconomofarUI.accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(method.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(2)

                    Text(PaymentUsageText.rowDetail(method))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    shareBar(PaymentUsageText.fraction(method.share))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(PaymentUsageText.money(method.amount))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(PaymentUsageText.shareText(method.share))
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(PaymentUsageText.rowAccessibility(method)))
        }
        .buttonStyle(.plain)
    }

    private func unspecifiedRow(_ result: PaymentUsage) -> some View {
        NavigationLink {
            PaymentUsageDetailView(viewModel: viewModel, key: nil, title: PaymentUsageText.unspecifiedTitle)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                DashboardIconBox(icon: "exclamationmark.circle.fill", tint: EconomofarUI.warning)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(PaymentUsageText.unspecifiedTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(2)

                    Text(PaymentUsageText.unspecifiedDetail(count: result.unspecifiedCount))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(PaymentUsageText.money(result.unspecifiedAmount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
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
            message: PaymentUsageText.method,
            tint: EconomofarUI.accent,
            background: EconomofarUI.accentSoft
        )
        .padding(.horizontal, -20)
    }
}
