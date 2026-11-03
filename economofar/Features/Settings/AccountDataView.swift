import SwiftUI

/// Account & data screen: permanent account deletion (App Store requirement for apps with accounts).
struct AccountDataView: View {
    @EnvironmentObject var sessionManager: SessionManager

    @State private var password = ""
    @State private var isDeleting = false
    @State private var errorMessage: String? = nil
    @State private var showConfirmation = false

    var body: some View {
        ZStack {
            EconomofarUI.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Supprimer mon compte")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)

                        Text("Cette action est définitive. Votre compte, vos tickets, les photos associées, votre budget et vos notifications seront supprimés du serveur. Pensez à exporter votre historique avant (onglet Historique).")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Mot de passe", systemImage: "lock")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.textSecondary)

                        SecureField("Confirmez avec votre mot de passe", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(EconomofarUI.textPrimary)
                            .padding()
                            .background(EconomofarUI.cardSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(EconomofarUI.border, lineWidth: 1)
                            }
                    }

                    if let errorMessage {
                        DashboardInfoBanner(
                            icon: "exclamationmark.triangle.fill",
                            message: errorMessage,
                            tint: EconomofarUI.danger,
                            background: EconomofarUI.dangerSoft
                        )
                    }

                    Button {
                        showConfirmation = true
                    } label: {
                        HStack(spacing: 10) {
                            if isDeleting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "trash.fill")
                            }

                            Text(isDeleting ? "Suppression..." : "Supprimer définitivement")
                        }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(EconomofarUI.danger)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(password.isEmpty || isDeleting)
                    .opacity(password.isEmpty ? 0.5 : 1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("Compte et données")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Supprimer définitivement votre compte ?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer mon compte", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }

            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Cette action ne peut pas être annulée.")
        }
    }

    private func deleteAccount() async {
        guard let token = sessionManager.token else { return }

        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        do {
            _ = try await APIClient.shared.post(
                Endpoint.deleteAccount,
                body: ["password": password],
                token: token
            )

            sessionManager.logout()
        } catch APIError.unauthorized {
            // Session already expired: the session manager logs out
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
