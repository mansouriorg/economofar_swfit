import SwiftUI

struct ChangePasswordView: View {

    @EnvironmentObject var sessionManager: SessionManager

    @StateObject private var viewModel = UserProfileViewModel()

    @State private var showCurrentPassword = false
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case current
        case new
        case confirm
    }

    var body: some View {
        ZStack {
            ProfileDesign.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header

                    if let errorMessage = viewModel.errorMessage {
                        ProfileBanner(
                            icon: "exclamationmark.triangle.fill",
                            message: errorMessage,
                            tint: ProfileDesign.danger,
                            background: ProfileDesign.dangerSoft
                        )
                    }

                    if let successMessage = viewModel.successMessage {
                        ProfileBanner(
                            icon: "checkmark.circle.fill",
                            message: successMessage,
                            tint: ProfileDesign.success,
                            background: ProfileDesign.successSoft
                        )
                    }

                    passwordForm
                    passwordRulesCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Mot de passe")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: viewModel.shouldLogout) { shouldLogout in
            guard shouldLogout else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                sessionManager.logout()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(ProfileDesign.dangerSoft)
                    .frame(width: 78, height: 78)

                Image(systemName: "lock.rotation")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(ProfileDesign.danger)
            }

            VStack(spacing: 8) {
                Text("Changer le mot de passe")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundColor(ProfileDesign.textPrimary)

                Text("Après modification, vous devrez vous reconnecter.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(ProfileDesign.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var passwordForm: some View {
        ProfileSectionCard(title: "Sécurité") {
            VStack(spacing: 14) {
                passwordField(
                    title: "Mot de passe actuel",
                    placeholder: "Saisissez votre mot de passe actuel",
                    text: $viewModel.currentPassword,
                    isVisible: $showCurrentPassword,
                    field: .current
                )

                passwordField(
                    title: "Nouveau mot de passe",
                    placeholder: "Minimum 8 caractères",
                    text: $viewModel.newPassword,
                    isVisible: $showNewPassword,
                    field: .new
                )

                passwordField(
                    title: "Confirmer le mot de passe",
                    placeholder: "Répétez le nouveau mot de passe",
                    text: $viewModel.confirmPassword,
                    isVisible: $showConfirmPassword,
                    field: .confirm
                )

                Button {
                    focusedField = nil

                    Task {
                        await viewModel.savePassword()
                    }
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isSavingPassword {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }

                        Text(viewModel.isSavingPassword ? "Modification..." : "Modifier le mot de passe")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ProfileDesign.danger)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: ProfileDesign.danger.opacity(0.16), radius: 12, x: 0, y: 7)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSavingPassword)
            }
            .padding(16)
        }
    }

    private var passwordRulesCard: some View {
        ProfileSectionCard(title: "Conseils") {
            VStack(alignment: .leading, spacing: 10) {
                ruleRow("Utilisez au moins 8 caractères.")
                ruleRow("Évitez d’utiliser votre ancien mot de passe.")
                ruleRow("Après changement, une reconnexion sera demandée.")
            }
            .padding(16)
        }
    }

    private func passwordField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(ProfileDesign.textSecondary)

            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ProfileDesign.danger)
                    .frame(width: 20)

                Group {
                    if isVisible.wrappedValue {
                        TextField(placeholder, text: text)
                    } else {
                        SecureField(placeholder, text: text)
                    }
                }
                .focused($focusedField, equals: field)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(ProfileDesign.textPrimary)

                Button {
                    isVisible.wrappedValue.toggle()
                } label: {
                    Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ProfileDesign.textTertiary)
                }
            }
            .padding(14)
            .background(ProfileDesign.cardSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        focusedField == field ? ProfileDesign.danger : ProfileDesign.border,
                        lineWidth: 1
                    )
            }
        }
    }

    private func ruleRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ProfileDesign.success)

            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(ProfileDesign.textSecondary)
                .lineSpacing(3)

            Spacer()
        }
    }
}
