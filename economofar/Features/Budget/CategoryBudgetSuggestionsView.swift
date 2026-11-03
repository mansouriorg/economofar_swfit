import SwiftUI
import Combine

// MARK: - View model

@MainActor
final class CategoryBudgetSuggestionsViewModel: ObservableObject {
    @Published var basedOnMonths = 0
    @Published var suggestions: [CategoryBudgetSuggestion] = []
    @Published var applied: Set<String> = []
    @Published var isLoading = false
    @Published var hasLoaded = false
    @Published var isApplying = false
    @Published var errorMessage: String? = nil

    var pending: [CategoryBudgetSuggestion] {
        suggestions.filter { !applied.contains($0.id) }
    }

    func load(token: String?) async {
        guard let token, !token.isEmpty, !isApplying else { return }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await CategoryBudgetSuggestionService.shared.fetch(token: token)

            basedOnMonths = result.basedOnMonths
            suggestions = result.suggestions
            applied = []
            hasLoaded = true
        } catch APIError.unauthorized {
            // The session manager logs the user out
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func apply(_ suggestion: CategoryBudgetSuggestion, token: String?) async {
        guard let token, !token.isEmpty, !isApplying, !isLoading else { return }

        isApplying = true
        errorMessage = nil

        do {
            try await CategoryBudgetService.shared.save(
                category: suggestion.category,
                monthlyAmount: suggestion.suggestedAmount,
                token: token
            )

            applied.insert(suggestion.id)
        } catch APIError.unauthorized {
            // The session manager logs the user out
        } catch {
            errorMessage = error.localizedDescription
        }

        isApplying = false
    }

    /// A limit that the server refuses does not stop the others; a network problem does.
    func applyAll(token: String?) async {
        guard let token, !token.isEmpty, !isApplying, !isLoading else { return }

        isApplying = true
        errorMessage = nil

        var refused = 0
        var firstMessage: String? = nil

        for suggestion in pending {
            do {
                try await CategoryBudgetService.shared.save(
                    category: suggestion.category,
                    monthlyAmount: suggestion.suggestedAmount,
                    token: token
                )

                applied.insert(suggestion.id)
            } catch APIError.unauthorized {
                break
            } catch APIError.server(_, let message) {
                refused += 1

                if firstMessage == nil {
                    firstMessage = message
                }
            } catch {
                refused += 1
                firstMessage = error.localizedDescription
                break
            }
        }

        if refused > 0 {
            let plural = refused > 1 ? "s" : ""
            errorMessage = "\(refused) limite\(plural) n'\(refused > 1 ? "ont" : "a") pas pu être ajoutée\(plural). \(firstMessage ?? "")"
        }

        isApplying = false
    }
}

// MARK: - Screen

struct CategoryBudgetSuggestionsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CategoryBudgetSuggestionsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                EconomofarUI.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        introText

                        if viewModel.suggestions.isEmpty {
                            if viewModel.hasLoaded {
                                emptyState
                            } else if viewModel.isLoading {
                                ProgressView()
                                    .padding(.top, 50)
                            } else {
                                retryButton
                            }
                        } else {
                            ForEach(viewModel.suggestions) { suggestion in
                                suggestionCard(suggestion)
                            }

                            footerButton
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
            .navigationTitle("Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .disabled(viewModel.isApplying)
                }
            }
            .task {
                await viewModel.load(token: sessionManager.token)
            }
            .alert("Une erreur est survenue", isPresented: errorBinding) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(viewModel.isApplying)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { shown in
                if !shown {
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    private var retryButton: some View {
        Button {
            Task {
                await viewModel.load(token: sessionManager.token)
            }
        } label: {
            Text("Réessayer")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(EconomofarUI.accent)
                .clipShape(Capsule())
        }
        .padding(.top, 30)
    }

    // MARK: Pieces

    private var introText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Des limites à partir de vos dépenses")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text("Calculées sur la moyenne de vos derniers mois complets (3 au maximum), avec 10 % de marge. Vous pourrez modifier chaque montant ensuite.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func suggestionCard(_ suggestion: CategoryBudgetSuggestion) -> some View {
        let isApplied = viewModel.applied.contains(suggestion.id)

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.category)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.textPrimary)

                Text("Vous dépensez en moyenne \(AppFormat.money(suggestion.averageSpent)) par mois")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(EconomofarUI.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Utilisée \(suggestion.monthsUsed) mois sur \(viewModel.basedOnMonths)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.textTertiary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                Text(AppFormat.money(suggestion.suggestedAmount))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(EconomofarUI.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if isApplied {
                    Label("Ajoutée", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.success)
                } else {
                    Button {
                        Task {
                            await viewModel.apply(suggestion, token: sessionManager.token)
                        }
                    } label: {
                        Text("Appliquer")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(EconomofarUI.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isApplying)
                    .opacity(viewModel.isApplying ? 0.6 : 1)
                }
            }
        }
        .padding(16)
        .background(EconomofarUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isApplied ? EconomofarUI.success.opacity(0.35) : EconomofarUI.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }

    @ViewBuilder
    private var footerButton: some View {
        if viewModel.isApplying {
            ProgressView()
                .padding(.top, 8)
        } else if viewModel.pending.count > 1 {
            Button {
                Task {
                    await viewModel.applyAll(token: sessionManager.token)
                }
            } label: {
                Text("Tout appliquer (\(viewModel.pending.count))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(EconomofarUI.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isApplying)
            .opacity(viewModel.isApplying ? 0.6 : 1)
        } else if viewModel.pending.isEmpty {
            VStack(spacing: 10) {
                Text("Les limites sont ajoutées. Touchez une carte du budget pour ajuster son montant.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(EconomofarUI.success)
                    .multilineTextAlignment(.center)

                Button("Terminé") {
                    dismiss()
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .padding(.top, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(EconomofarUI.accent)

            Text(viewModel.basedOnMonths == 0 ? "Pas encore assez de données" : "Rien à suggérer")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(EconomofarUI.textPrimary)

            Text(emptyMessage)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(EconomofarUI.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
        .padding(.horizontal, 12)
    }

    private var emptyMessage: String {
        if viewModel.basedOnMonths == 0 {
            return "Les suggestions s'appuient sur vos tickets validés des 3 derniers mois complets. Revenez après un mois de scans."
        }

        return "Toutes vos catégories ont déjà une limite, ou leurs dépenses sont trop faibles pour en proposer une."
    }
}
