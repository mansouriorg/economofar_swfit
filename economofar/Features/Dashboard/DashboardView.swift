import SwiftUI
import PhotosUI
import UIKit

// MARK: - 1. Models

struct ParsedItem: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var qty: Int
    var price: Double
}

// MARK: - 2. Visual Identity

enum EconomofarUI {
    static let background = Color(.sRGB, red: 0.968, green: 0.972, blue: 0.980, opacity: 1)
    static let card = Color.white
    static let cardSoft = Color(.sRGB, red: 0.945, green: 0.956, blue: 0.976, opacity: 1)

    static let textPrimary = Color(.sRGB, red: 0.067, green: 0.094, blue: 0.153, opacity: 1)
    static let textSecondary = Color(.sRGB, red: 0.420, green: 0.447, blue: 0.502, opacity: 1)
    static let textTertiary = Color(.sRGB, red: 0.612, green: 0.639, blue: 0.686, opacity: 1)

    static let accent = Color(.sRGB, red: 0.122, green: 0.369, blue: 1.000, opacity: 1)
    static let accentDark = Color(.sRGB, red: 0.071, green: 0.227, blue: 0.549, opacity: 1)
    static let accentSoft = Color(.sRGB, red: 0.910, green: 0.937, blue: 1.000, opacity: 1)

    static let success = Color(.sRGB, red: 0.059, green: 0.522, blue: 0.329, opacity: 1)
    static let successSoft = Color(.sRGB, red: 0.902, green: 0.976, blue: 0.941, opacity: 1)

    static let warning = Color(.sRGB, red: 0.718, green: 0.475, blue: 0.122, opacity: 1)
    static let warningSoft = Color(.sRGB, red: 1.000, green: 0.969, blue: 0.902, opacity: 1)

    static let danger = Color(.sRGB, red: 0.863, green: 0.149, blue: 0.149, opacity: 1)
    static let dangerSoft = Color(.sRGB, red: 0.996, green: 0.898, blue: 0.898, opacity: 1)

    static let border = Color(.sRGB, red: 0.894, green: 0.910, blue: 0.941, opacity: 1)

    static let mainGradient = LinearGradient(
        colors: [accentDark, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - 3. Dashboard View

struct DashboardView: View {
    @EnvironmentObject var sessionManager: SessionManager

    @StateObject private var ticketService = TicketService()
    @StateObject private var dashboardViewModel = DashboardViewModel()

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var analysisResult: String = ""
    @State private var showResultSheet = false
    @State private var showScanner = false
    @State private var isPhotosPickerPresented = false
    @State private var isScanReady = false

    private var firstName: String {
        sessionManager.currentUser?.firstName ?? "Utilisateur"
    }

    private var avatarLetter: String {
        String(firstName.prefix(1)).uppercased()
    }

    private var fallbackTotalScannedAmount: Double {
        ticketService.tickets.compactMap { $0.totalAmount }.reduce(0, +)
    }

    private var fallbackAverageBasket: Double {
        guard !ticketService.tickets.isEmpty else { return 0 }
        return fallbackTotalScannedAmount / Double(ticketService.tickets.count)
    }

    private var displayedTotalScannedAmount: String {
        if dashboardViewModel.insights != nil {
            return dashboardViewModel.totalScannedAmountText
        }

        return formatCurrency(fallbackTotalScannedAmount)
    }

    private var displayedTicketCount: String {
        if dashboardViewModel.insights != nil {
            return dashboardViewModel.ticketCountText
        }

        return "\(ticketService.tickets.count)"
    }

    private var displayedAverageBasket: String {
        if dashboardViewModel.insights != nil {
            return dashboardViewModel.averageBasketText
        }

        return formatCurrency(fallbackAverageBasket)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        headerView

                        if dashboardViewModel.isLoading && dashboardViewModel.insights == nil {
                            dashboardLoadingCard
                        }

                        if let errorMessage = dashboardViewModel.errorMessage {
                            DashboardInfoBanner(
                                icon: "exclamationmark.triangle.fill",
                                message: errorMessage,
                                tint: EconomofarUI.danger,
                                background: EconomofarUI.dangerSoft
                            )
                        }

                        spendingAnalyticsSection
                        merchantAnalyticsSection
                        historyListView
                    }
                    .padding(.bottom, 145)
                }
                .refreshable {
                    await refreshAllData()
                }

                floatingActionButton
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        sessionManager.logout()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 12, weight: .semibold))

                            Text("Déconnexion")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.red.opacity(0.85))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .photosPicker(
                isPresented: $isPhotosPickerPresented,
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem) { newItem in
                handlePhotoSelection(newItem)
            }
            .onChange(of: ticketService.lastScanResult) { newResult in
                guard let result = newResult else { return }

                Task { @MainActor in
                    analysisResult = result

                    withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                        isScanReady = true
                    }
                }
            }
            .sheet(isPresented: $showResultSheet, onDismiss: {
                if ticketService.lastScanResult == nil {
                    isScanReady = false
                }
            }) {
                if !analysisResult.isEmpty {
                    ResultView(
                        ticketService: ticketService,
                        image: selectedImage,
                        resultText: analysisResult,
                        isPresented: $showResultSheet,
                        onSaved: {
                            refreshAfterTicketSave()
                        }
                    )
                    .environmentObject(sessionManager)
                } else {
                    LoadingSheetView()
                        .presentationDetents([.medium])
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                ScannerView(isPresented: $showScanner) { capturedImage in
                    selectedImage = capturedImage
                    showScanner = false

                    if let token = sessionManager.token {
                        Task {
                            ticketService.uploadTicket(image: capturedImage, token: token)
                        }
                    }
                }
            }
        }
        .task {
            await dashboardViewModel.loadDashboard()
        }
        .onAppear {
            ticketService.onUnauthorized = {
                sessionManager.logout()
            }

            if let token = sessionManager.token {
                ticketService.fetchTickets(token: token)
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Bonjour,")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)

                    Text(firstName)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                AvatarView(letter: avatarLetter)
            }

            MonthlyOverviewCard(
                amount: dashboardViewModel.totalSpentThisMonthText,
                comparisonText: dashboardViewModel.monthlyComparisonText,
                comparisonIsPositive: dashboardViewModel.monthlyComparisonIsPositive,
                isComparisonAvailable: dashboardViewModel.insights?.monthlyComparisonPercentage != nil
            )

            HStack(spacing: 12) {
                MiniStatCard(
                    title: "Total scanné",
                    value: displayedTotalScannedAmount,
                    icon: "creditcard",
                    tint: EconomofarUI.accent
                )

                MiniStatCard(
                    title: "Tickets",
                    value: displayedTicketCount,
                    icon: "receipt",
                    tint: EconomofarUI.success
                )
            }

            HStack(spacing: 12) {
                MiniStatCard(
                    title: "Panier moyen",
                    value: displayedAverageBasket,
                    icon: "cart",
                    tint: EconomofarUI.warning
                )

                MiniStatCard(
                    title: "Cette semaine",
                    value: dashboardViewModel.totalSpentThisWeekText,
                    icon: "calendar.badge.clock",
                    tint: EconomofarUI.accentDark
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private var dashboardLoadingCard: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(EconomofarUI.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text("Chargement du dashboard")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Text("Calcul des statistiques en cours.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
        .padding(.horizontal, 20)
    }

    private var spendingAnalyticsSection: some View {
        DashboardSectionCard(title: "Analyse des dépenses") {
            VStack(spacing: 0) {
                DashboardInsightRow(
                    icon: "calendar",
                    title: "Total ce mois-ci",
                    subtitle: "Dépenses du mois en cours",
                    value: dashboardViewModel.totalSpentThisMonthText,
                    tint: EconomofarUI.accent
                )

                DashboardDivider()

                DashboardInsightRow(
                    icon: "calendar.badge.minus",
                    title: "Mois dernier",
                    subtitle: "Total dépensé le mois précédent",
                    value: dashboardViewModel.totalSpentLastMonthText,
                    tint: EconomofarUI.textSecondary
                )

                DashboardDivider()

                DashboardInsightRow(
                    icon: dashboardViewModel.monthlyComparisonIsPositive ? "arrow.up.right" : "arrow.down.right",
                    title: "Comparaison",
                    subtitle: "Évolution par rapport au mois dernier",
                    value: dashboardViewModel.monthlyComparisonText,
                    tint: dashboardViewModel.monthlyComparisonIsPositive ? EconomofarUI.danger : EconomofarUI.success
                )

                DashboardDivider()

                DashboardInsightRow(
                    icon: "chart.bar",
                    title: "Moyenne par ticket",
                    subtitle: "Montant moyen de vos achats",
                    value: dashboardViewModel.averageTicketAmountText,
                    tint: EconomofarUI.warning
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private var merchantAnalyticsSection: some View {
        DashboardSectionCard(title: "Commerçants") {
            VStack(spacing: 0) {
                DashboardInsightRow(
                    icon: "storefront",
                    title: "Commerçant le plus fréquent",
                    subtitle: "Celui qui apparaît le plus souvent",
                    value: dashboardViewModel.mostFrequentMerchantText,
                    tint: EconomofarUI.accent
                )

                DashboardDivider()

                DashboardInsightRow(
                    icon: "crown",
                    title: "Ticket le plus élevé",
                    subtitle: "Votre plus grosse dépense enregistrée",
                    value: dashboardViewModel.highestReceiptText,
                    tint: EconomofarUI.warning
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private var historyListView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Historique")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Vos derniers tickets enregistrés")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                if ticketService.isLoading {
                    ProgressView()
                        .tint(EconomofarUI.accent)
                        .scaleEffect(0.9)
                }
            }
            .padding(.horizontal, 20)

            LazyVStack(spacing: 12) {
                if ticketService.tickets.isEmpty && !ticketService.isLoading {
                    EmptyTicketsView()
                        .padding(.top, 4)
                } else {
                    ForEach(ticketService.tickets) { ticket in
                        NavigationLink(destination: TicketDetailView(ticket: ticket)) {
                            TicketRow(ticket: ticket)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var floatingActionButton: some View {
        VStack(spacing: 12) {
            Spacer()

            if isScanReady {
                Button {
                    showResultSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 17, weight: .semibold))

                        Text("Analyse terminée")
                            .font(.system(size: 14, weight: .bold, design: .rounded))

                        Spacer(minLength: 8)

                        Text("Voir")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .background(EconomofarUI.success)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: EconomofarUI.success.opacity(0.22), radius: 16, x: 0, y: 8)
                    .padding(.horizontal, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Menu {
                Button {
                    Task { @MainActor in
                        showScanner = true
                    }
                } label: {
                    Label("Appareil photo", systemImage: "camera")
                }

                Button {
                    isPhotosPickerPresented = true
                } label: {
                    Label("Galerie photos", systemImage: "photo.on.rectangle")
                }
            } label: {
                HStack(spacing: 12) {
                    if ticketService.isLoading {
                        ProgressView()
                            .tint(.white)

                        Text("Analyse en cours")
                            .fontWeight(.bold)
                    } else {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 18, weight: .semibold))

                        Text("Scanner un ticket")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(.white)
                .padding(.vertical, 17)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .background(EconomofarUI.mainGradient)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: EconomofarUI.accent.opacity(0.22), radius: 18, x: 0, y: 10)
                .padding(.horizontal, 20)
            }
            .disabled(ticketService.isLoading)
            .padding(.bottom, 18)
        }
    }

    private func refreshAllData() async {
        await dashboardViewModel.refresh()

        if let token = sessionManager.token {
            ticketService.fetchTickets(token: token)
        }
    }

    private func refreshAfterTicketSave() {
        if let token = sessionManager.token {
            ticketService.fetchTickets(token: token)
        }

        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await dashboardViewModel.loadDashboard()
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f €", amount)
    }

    private func handlePhotoSelection(_ newItem: PhotosPickerItem?) {
        Task {
            guard
                let data = try? await newItem?.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                return
            }

            await MainActor.run {
                selectedImage = image

                if let token = sessionManager.token {
                    ticketService.uploadTicket(image: image, token: token)
                }
            }
        }
    }
}

// MARK: - 4. Background

struct DashboardBackground: View {
    var body: some View {
        ZStack {
            EconomofarUI.background
                .ignoresSafeArea()

            Circle()
                .fill(EconomofarUI.accent.opacity(0.055))
                .frame(width: 260, height: 260)
                .blur(radius: 55)
                .offset(x: -150, y: -310)

            Circle()
                .fill(EconomofarUI.accent.opacity(0.035))
                .frame(width: 230, height: 230)
                .blur(radius: 55)
                .offset(x: 160, y: 250)
        }
    }
}

// MARK: - 5. Avatar

struct AvatarView: View {
    let letter: String

    var body: some View {
        ZStack {
            Circle()
                .fill(EconomofarUI.card)
                .frame(width: 52, height: 52)
                .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 8)

            Circle()
                .stroke(EconomofarUI.border, lineWidth: 1)
                .frame(width: 52, height: 52)

            Text(letter)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.accent)
        }
    }
}

// MARK: - 6. Monthly Overview Card

struct MonthlyOverviewCard: View {
    let amount: String
    let comparisonText: String
    let comparisonIsPositive: Bool
    let isComparisonAvailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ce mois-ci")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)

                    Text(amount)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(EconomofarUI.accentSoft)
                        .frame(width: 52, height: 52)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(EconomofarUI.accent)
                }
            }

            Divider()
                .background(EconomofarUI.border)

            HStack(spacing: 10) {
                Image(
                    systemName: isComparisonAvailable
                    ? (comparisonIsPositive ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    : "minus.circle.fill"
                )
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(
                    isComparisonAvailable
                    ? (comparisonIsPositive ? EconomofarUI.danger : EconomofarUI.success)
                    : EconomofarUI.textTertiary
                )

                Text(comparisonText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .lineLimit(2)

                Spacer()
            }
        }
        .padding(20)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.055), radius: 22, x: 0, y: 12)
    }
}

// MARK: - 7. Total Overview Card

struct TotalOverviewCard: View {
    let amount: String
    let ticketCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total scanné")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)

                    Text(amount)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(EconomofarUI.accentSoft)
                        .frame(width: 52, height: 52)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(EconomofarUI.accent)
                }
            }

            Divider()
                .background(EconomofarUI.border)

            HStack(spacing: 10) {
                Image(systemName: ticketCount == 0 ? "plus.circle.fill" : "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ticketCount == 0 ? EconomofarUI.accent : EconomofarUI.success)

                Text(ticketCount == 0 ? "Scannez votre premier ticket" : "Vos dépenses sont à jour")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)

                Spacer()

                Text("\(ticketCount) ticket\(ticketCount > 1 ? "s" : "")")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(EconomofarUI.cardSoft)
                    .clipShape(Capsule())
            }
        }
        .padding(20)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.055), radius: 22, x: 0, y: 12)
    }
}

// MARK: - 8. Mini Stat Card

struct MiniStatCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.10))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)

                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }
}

// MARK: - 9. Dashboard Analytics Components

struct DashboardSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content
            }
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
        }
    }
}

struct DashboardInsightRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            DashboardIconBox(icon: icon, tint: tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(tint)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .padding(16)
    }
}

struct DashboardIconBox: View {
    let icon: String
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(tint.opacity(0.11))
                .frame(width: 46, height: 46)

            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tint)
        }
    }
}

struct DashboardDivider: View {
    var body: some View {
        Divider()
            .background(EconomofarUI.border)
            .padding(.leading, 76)
    }
}

struct DashboardInfoBanner: View {
    let icon: String
    let message: String
    let tint: Color
    let background: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)

            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(tint)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(14)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 10. Empty State

struct EmptyTicketsView: View {
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(EconomofarUI.accentSoft)
                    .frame(width: 82, height: 82)

                Image(systemName: "receipt")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
            }

            VStack(spacing: 7) {
                Text("Aucun ticket scanné")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Text("Ajoutez votre premier ticket pour commencer à suivre vos dépenses simplement.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 18)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }
}

// MARK: - 11. Ticket Row

struct TicketRow: View {
    let ticket: Ticket

    private var merchantName: String {
        ticket.merchantName?.isEmpty == false ? ticket.merchantName! : "Magasin inconnu"
    }

    private var totalAmount: Double {
        ticket.totalAmount ?? 0.0
    }

    private var dateString: String {
        TicketDateHelper.shortDate(from: ticket.purchaseDate)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(EconomofarUI.accentSoft)
                    .frame(width: 50, height: 50)

                Image(systemName: "receipt")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(merchantName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.caption2)

                    Text(dateString)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(EconomofarUI.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(String(format: "%.2f €", totalAmount))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
        }
        .padding(16)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }
}

// MARK: - 12. Result View

struct ResultView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @ObservedObject var ticketService: TicketService

    var image: UIImage?
    var resultText: String
    @Binding var isPresented: Bool
    var onSaved: (() -> Void)? = nil

    @State private var merchantName: String = ""
    @State private var totalAmount: Double = 0.0
    @State private var purchaseDate: String = ""
    @State private var parsedItems: [ParsedItem] = []

    var body: some View {
        NavigationStack {
            ZStack {
                EconomofarUI.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        imagePreview
                        validationCard
                        detectedItemsCard
                        confirmButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Validation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        isPresented = false
                    }
                    .foregroundColor(EconomofarUI.textSecondary)
                }
            }
            .onAppear {
                parseRobustJSON()
            }
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let img = image {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 210)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.48),
                        Color.clear
                    ],
                    startPoint: .bottom,
                    endPoint: .center
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Analyse terminée")
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.black.opacity(0.28))
                .clipShape(Capsule())
                .padding(14)
            }
            .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 8)
        }
    }

    private var validationCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Vérifiez les données")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Text("Corrigez les informations avant l’enregistrement.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
            }

            StyledTextField(
                title: "Enseigne",
                placeholder: "Nom du magasin",
                icon: "storefront",
                text: $merchantName
            )

            StyledTextField(
                title: "Date",
                placeholder: "YYYY-MM-DD",
                icon: "calendar",
                text: $purchaseDate
            )

            VStack(alignment: .leading, spacing: 8) {
                Label("Total", systemImage: "eurosign.circle")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)

                TextField("0.00", value: $totalAmount, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)
                    .padding()
                    .background(EconomofarUI.cardSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(EconomofarUI.border, lineWidth: 1)
                    }
            }
        }
        .padding(18)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }

    @ViewBuilder
    private var detectedItemsCard: some View {
        if !parsedItems.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Articles détectés")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)

                        Text("\(parsedItems.count) article\(parsedItems.count > 1 ? "s" : "")")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(EconomofarUI.accent)
                }

                VStack(spacing: 10) {
                    ForEach(parsedItems) { item in
                        ParsedItemRow(item: item)
                    }
                }
            }
            .padding(18)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
        }
    }

    private var confirmButton: some View {
        Button {
            if let token = sessionManager.token {
                ticketService.saveValidatedTicket(
                    merchant: merchantName,
                    amount: totalAmount,
                    rawOcr: resultText,
                    token: token
                )

                onSaved?()
                isPresented = false
            }
        } label: {
            HStack(spacing: 10) {
                if ticketService.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Confirmer le ticket")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(EconomofarUI.mainGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: EconomofarUI.accent.opacity(0.22), radius: 16, x: 0, y: 8)
        }
        .disabled(ticketService.isLoading)
    }

    func parseRobustJSON() {
        let cleanedText = resultText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let regex = try? NSRegularExpression(
            pattern: #""merchant"\s*:\s*"([^"]+)""#,
            options: .caseInsensitive
        ),
           let match = regex.firstMatch(
            in: cleanedText,
            range: NSRange(location: 0, length: cleanedText.count)
           ) {
            merchantName = (cleanedText as NSString).substring(with: match.range(at: 1))
        }

        if let regex = try? NSRegularExpression(
            pattern: #""date"\s*:\s*"([^"]+)""#,
            options: .caseInsensitive
        ),
           let match = regex.firstMatch(
            in: cleanedText,
            range: NSRange(location: 0, length: cleanedText.count)
           ) {
            purchaseDate = (cleanedText as NSString).substring(with: match.range(at: 1))
        }

        if let regex = try? NSRegularExpression(
            pattern: #""total"\s*:\s*([0-9]+(?:\.[0-9]+)?)"#,
            options: .caseInsensitive
        ),
           let match = regex.firstMatch(
            in: cleanedText,
            range: NSRange(location: 0, length: cleanedText.count)
           ) {
            let value = (cleanedText as NSString).substring(with: match.range(at: 1))
            totalAmount = Double(value) ?? 0.0
        }

        guard
            let data = cleanedText.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = json["items"] as? [[String: Any]]
        else {
            return
        }

        parsedItems = items.compactMap { dict in
            let name = dict["name"] as? String ?? "Article"

            let qty: Int
            if let value = dict["qty"] as? Int {
                qty = value
            } else if let value = dict["qty"] as? Double {
                qty = Int(value)
            } else if let value = dict["qty"] as? String {
                qty = Int(value) ?? 1
            } else {
                qty = 1
            }

            let price: Double
            if let value = dict["price"] as? Double {
                price = value
            } else if let value = dict["price"] as? Int {
                price = Double(value)
            } else if let value = dict["price"] as? String {
                price = Double(value.replacingOccurrences(of: ",", with: ".")) ?? 0.0
            } else {
                price = 0.0
            }

            return ParsedItem(name: name, qty: qty, price: price)
        }
    }
}

// MARK: - 13. Styled Text Field

struct StyledTextField: View {
    let title: String
    let placeholder: String
    let icon: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)

            TextField(placeholder, text: $text)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .padding()
                .background(EconomofarUI.cardSoft)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(EconomofarUI.border, lineWidth: 1)
                }
        }
    }
}

// MARK: - 14. Parsed Item Row

struct ParsedItemRow: View {
    let item: ParsedItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(EconomofarUI.accentSoft)
                    .frame(width: 38, height: 38)

                Image(systemName: "bag")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
            }

            Text(item.name)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .lineLimit(2)

            Spacer()

            if item.qty > 1 {
                Text("x\(item.qty)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(EconomofarUI.card)
                    .clipShape(Capsule())
            }

            Text(String(format: "%.2f €", item.price))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
        }
        .padding(12)
        .background(EconomofarUI.cardSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - 15. Loading Sheet View

struct LoadingSheetView: View {
    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .tint(EconomofarUI.accent)
                .scaleEffect(1.2)

            VStack(spacing: 6) {
                Text("Chargement...")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Text("Préparation du résultat d’analyse.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EconomofarUI.background)
    }
}

// MARK: - 16. Ticket Detail View

struct TicketDetailView: View {
    let ticket: Ticket
    @State private var parsedItems: [ParsedItem] = []

    private var merchantName: String {
        ticket.merchantName?.isEmpty == false ? ticket.merchantName! : "Magasin inconnu"
    }

    private var totalAmount: Double {
        ticket.totalAmount ?? 0.0
    }

    var body: some View {
        ZStack {
            EconomofarUI.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    ticketSummaryCard

                    if !parsedItems.isEmpty {
                        itemsSection
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Ticket")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            parseSavedJSON()
        }
    }

    private var ticketSummaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(EconomofarUI.accentSoft)
                        .frame(width: 56, height: 56)

                    Image(systemName: "storefront")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(EconomofarUI.accent)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(merchantName)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                        .lineLimit(1)

                    Text(TicketDateHelper.mediumDate(from: ticket.purchaseDate))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()
            }

            Divider()

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Total payé")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)

                    Text(String(format: "%.2f €", totalAmount))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)
                }

                Spacer()

                Image(systemName: "creditcard")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
            }
        }
        .padding(20)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.045), radius: 16, x: 0, y: 8)
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Articles")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("\(parsedItems.count) article\(parsedItems.count > 1 ? "s" : "")")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(parsedItems) { item in
                    ParsedItemRow(item: item)
                }
            }
        }
        .padding(18)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }

    func parseSavedJSON() {
        guard let jsonString = ticket.rawOcrText, !jsonString.isEmpty else {
            return
        }

        let cleaned = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let data = cleaned.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = json["items"] as? [[String: Any]]
        else {
            return
        }

        parsedItems = items.compactMap { dict in
            let name = dict["name"] as? String ?? "Article"

            let qty: Int
            if let value = dict["qty"] as? Int {
                qty = value
            } else if let value = dict["qty"] as? Double {
                qty = Int(value)
            } else if let value = dict["qty"] as? String {
                qty = Int(value) ?? 1
            } else {
                qty = 1
            }

            let price: Double
            if let value = dict["price"] as? Double {
                price = value
            } else if let value = dict["price"] as? Int {
                price = Double(value)
            } else if let value = dict["price"] as? String {
                price = Double(value.replacingOccurrences(of: ",", with: ".")) ?? 0.0
            } else {
                price = 0.0
            }

            return ParsedItem(name: name, qty: qty, price: price)
        }
    }
}

// MARK: - 17. Date Helper

enum TicketDateHelper {
    static func shortDate(from dateString: String?) -> String {
        guard let date = parseDate(dateString) else {
            return dateString ?? "Date inconnue"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    static func mediumDate(from dateString: String?) -> String {
        guard let date = parseDate(dateString) else {
            return dateString ?? "Date inconnue"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString, !dateString.isEmpty else {
            return nil
        }

        let formatterWithFraction = ISO8601DateFormatter()
        formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatterWithFraction.date(from: dateString) {
            return date
        }

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]

        if let date = standardFormatter.date(from: dateString) {
            return date
        }

        let localDateTimeFormatter = DateFormatter()
        localDateTimeFormatter.locale = Locale(identifier: "en_US_POSIX")
        localDateTimeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        if let date = localDateTimeFormatter.date(from: dateString) {
            return date
        }

        let localDateFormatter = DateFormatter()
        localDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        localDateFormatter.dateFormat = "yyyy-MM-dd"

        if let date = localDateFormatter.date(from: dateString) {
            return date
        }

        return nil
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environmentObject(SessionManager())
}
