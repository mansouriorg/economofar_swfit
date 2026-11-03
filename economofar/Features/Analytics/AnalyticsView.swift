import SwiftUI
import Combine
import Charts

// MARK: - View model

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var summary: AnalyticsSummary? = nil
    @Published var months: Int = 6
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    func load(token: String?) async {
        guard let token, !token.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            summary = try await AnalyticsService.shared.fetchSummary(months: months, token: token)
        } catch APIError.unauthorized {
            // The session manager logs the user out
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - View

struct AnalyticsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = AnalyticsViewModel()

    private struct Period: Identifiable {
        let label: String
        let months: Int

        var id: Int { months }
    }

    private let periods: [Period] = [
        Period(label: "1 mois", months: 1),
        Period(label: "3 mois", months: 3),
        Period(label: "6 mois", months: 6),
        Period(label: "12 mois", months: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                EconomofarUI.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        periodPicker

                        analysisLinks

                        if let errorMessage = viewModel.errorMessage {
                            DashboardInfoBanner(
                                icon: "exclamationmark.triangle.fill",
                                message: errorMessage,
                                tint: EconomofarUI.danger,
                                background: EconomofarUI.dangerSoft
                            )
                            .padding(.horizontal, -20)
                        }

                        if let summary = viewModel.summary {
                            if summary.ticketCount == 0 {
                                emptyState
                            } else {
                                summaryCards(summary)
                                monthlyChartCard(summary)
                                categoriesCard(summary)
                                namedListCard(
                                    title: "Top commerçants",
                                    icon: "storefront",
                                    items: summary.topMerchants
                                )
                                namedListCard(
                                    title: "Moyens de paiement",
                                    icon: "creditcard",
                                    items: summary.paymentMethods
                                )
                            }
                        } else if viewModel.isLoading {
                            ProgressView()
                                .padding(.top, 60)
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
            .navigationTitle("Analyses")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.load(token: sessionManager.token)
            }
            .onChange(of: viewModel.months) { _ in
                Task {
                    await viewModel.load(token: sessionManager.token)
                }
            }
        }
    }

    // MARK: Links

    private var analysisLinks: some View {
        VStack(spacing: 18) {
            weeklyLink

            compareLink

            yearLink

            merchantsLink

            unusualLink

            rhythmLink

            forecastLink

            moreLinks
        }
    }

    // MARK: Unusual purchases

    private var unusualLink: some View {
        NavigationLink {
            UnusualPurchasesView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Achats inhabituels")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Les achats bien au-dessus de vos habitudes")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: More links

    private var moreLinks: some View {
        VStack(spacing: 18) {
            smallLink

            trendsLink

            calendarLink

            recurringLink

            priceTrackerLink

            shoppingLink

            qualityLink

            suggestionsLink

            extraLinks
        }
    }

    // MARK: Ticket quality

    private var qualityLink: some View {
        NavigationLink {
            TicketQualityView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "checklist")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Tickets à vérifier")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Doublons, commerces inconnus, montants ou dates à corriger")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Month against month

    private var compareLink: some View {
        NavigationLink {
            MonthCompareView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Mois contre mois")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Ce mois comparé au précédent, jour par jour")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Year review

    private var yearLink: some View {
        NavigationLink {
            YearReviewView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Bilan de l'année")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Mois, catégories et commerces de l'année")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Category trends

    private var trendsLink: some View {
        NavigationLink {
            CategoryTrendsView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Tendances par catégorie")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Comment chaque catégorie évolue de mois en mois")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Extra links

    private var extraLinks: some View {
        VStack(spacing: 18) {
            warrantyLink

            categoryProfilesLink

            businessExpensesLink

            paymentUsageLink

            repurchaseLink

            shopsLink

            eventsLink

            itemPricesLink

            spendingSplitLink

            budgetTrackingLink
        }
    }

    // MARK: Budget tracking

    private var budgetTrackingLink: some View {
        NavigationLink {
            BudgetTrackingView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "target")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Suivi des budgets")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Où vous en êtes dans chaque budget, jour après jour")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Needs, wants, savings

    private var spendingSplitLink: some View {
        NavigationLink {
            SpendingSplitView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Besoins, envies, épargne")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Votre mois selon la règle 50/30/20")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Item prices

    private var itemPricesLink: some View {
        NavigationLink {
            ItemPricesView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Prix de vos articles")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Ce qui a monté, ce qui a baissé, où c'est moins cher")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Events

    private var eventsLink: some View {
        NavigationLink {
            SpendingEventsView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Événements")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Un voyage, des travaux, un mariage : ce que ça coûte")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Shops

    private var shopsLink: some View {
        NavigationLink {
            ShopsView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Mes enseignes")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Où vous dépensez, ce qui est nouveau, ce que vous délaissez")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Regular purchases

    private var repurchaseLink: some View {
        NavigationLink {
            RepurchaseView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "cart.badge.plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Achats réguliers")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Ce que vous rachetez, à quel rythme, et quand y penser")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Payment methods

    private var paymentUsageLink: some View {
        NavigationLink {
            PaymentUsageView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Moyens de paiement")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Carte, espèces, virement, mois par mois")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Business expenses

    private var businessExpensesLink: some View {
        NavigationLink {
            BusinessExpensesView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Frais pros")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("TVA, déductible, projets et clients")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Category profiles

    private var categoryProfilesLink: some View {
        NavigationLink {
            CategoryProfilesView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Mes catégories")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Où va votre argent, catégorie par catégorie")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Warranties

    private var warrantyLink: some View {
        NavigationLink {
            WarrantyOverviewView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Suivi des garanties")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Ce qui expire bientôt, ce qui est couvert")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Suggested categories

    private var suggestionsLink: some View {
        NavigationLink {
            CategorySuggestionsView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Catégories suggérées")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Classez d'un geste les tickets sans catégorie")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Small purchases

    private var smallLink: some View {
        NavigationLink {
            SmallPurchasesView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Petites dépenses")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Ce que coûtent vos petits achats du quotidien")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Spending rhythm

    private var rhythmLink: some View {
        NavigationLink {
            SpendingRhythmView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Rythme des dépenses")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Vos jours forts et vos jours sans achat")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Recurring expenses

    private var recurringLink: some View {
        NavigationLink {
            RecurringExpensesView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Dépenses récurrentes")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Abonnements et achats réguliers détectés")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Price tracker

    private var priceTrackerLink: some View {
        NavigationLink {
            PriceTrackerView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Suivi des prix")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Hausses et baisses du prix de vos articles")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Merchants

    private var merchantsLink: some View {
        NavigationLink {
            MerchantsView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Mes commerces")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Où part votre argent, commerce par commerce")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Weekly digest

    private var weeklyLink: some View {
        NavigationLink {
            WeeklyDigestView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Résumé de la semaine")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Vos 7 derniers jours comparés aux 7 d'avant")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Month forecast

    private var forecastLink: some View {
        NavigationLink {
            SpendingForecastView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Prévision du mois")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Ce que vous aurez dépensé à la fin du mois")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Shopping list

    private var shoppingLink: some View {
        NavigationLink {
            ShoppingListView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "cart")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Liste de courses")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Avec les prix de vos derniers achats")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Spending calendar

    private var calendarLink: some View {
        NavigationLink {
            SpendingCalendarView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(EconomofarUI.accent)
                    .frame(width: 42, height: 42)
                    .background(EconomofarUI.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Calendrier des dépenses")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Ce que vous avez dépensé, jour par jour")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EconomofarUI.textTertiary)
            }
            .padding(14)
            .background(EconomofarUI.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EconomofarUI.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Period picker

    private var periodPicker: some View {
        Picker("Période", selection: $viewModel.months) {
            ForEach(periods) { period in
                Text(period.label).tag(period.months)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: Summary cards

    private func summaryCards(_ summary: AnalyticsSummary) -> some View {
        HStack(spacing: 12) {
            statCard(
                title: "Dépensé",
                value: AppFormat.money(summary.totalSpent),
                icon: AppFormat.currencyIconFilled,
                tint: EconomofarUI.accent
            )

            statCard(
                title: "Tickets",
                value: "\(summary.ticketCount)",
                icon: "doc.text.fill",
                tint: EconomofarUI.success
            )

            statCard(
                title: "Panier moyen",
                value: AppFormat.money(summary.averageTicket),
                icon: "cart.fill",
                tint: EconomofarUI.warning
            )
        }
    }

    private func statCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
    }

    // MARK: Monthly chart

    private func monthlyChartCard(_ summary: AnalyticsSummary) -> some View {
        cardContainer(title: "Dépenses par mois", icon: "chart.bar.fill") {
            Chart(summary.monthly) { point in
                BarMark(
                    x: .value("Mois", point.shortLabel),
                    y: .value("Total", point.total)
                )
                .foregroundStyle(EconomofarUI.accent)
            }
            .frame(height: 190)
        }
    }

    // MARK: Categories

    private func categoriesCard(_ summary: AnalyticsSummary) -> some View {
        cardContainer(title: "Par catégorie", icon: "tag.fill") {
            VStack(spacing: 14) {
                ForEach(summary.categories) { category in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(category.name)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(EconomofarUI.textPrimary)

                            Spacer()

                            Text(AppFormat.money(category.total))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(EconomofarUI.textPrimary)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(EconomofarUI.cardSoft)

                                Capsule()
                                    .fill(EconomofarUI.mainGradient)
                                    .frame(width: max(6, proxy.size.width * CGFloat(min(category.percentage, 100) / 100)))
                            }
                        }
                        .frame(height: 8)

                        Text("\(category.count) ticket\(category.count > 1 ? "s" : "") · \(String(format: "%.1f", category.percentage)) %")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: Named lists

    private func namedListCard(title: String, icon: String, items: [AnalyticsNamedTotal]) -> some View {
        cardContainer(title: title, icon: icon) {
            VStack(spacing: 12) {
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(EconomofarUI.textPrimary)
                                .lineLimit(1)

                            Text("\(item.count) ticket\(item.count > 1 ? "s" : "")")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(EconomofarUI.textSecondary)
                        }

                        Spacer()

                        Text(AppFormat.money(item.total))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: Shared pieces

    private func cardContainer<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(EconomofarUI.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(EconomofarUI.accent)

            Text("Pas encore de données")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text("Scannez et validez des tickets pour voir vos dépenses par catégorie, par mois et par commerçant.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 50)
        .padding(.horizontal, 12)
    }
}
