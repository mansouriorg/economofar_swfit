import SwiftUI
import UIKit

struct EditProfileView: View {

    @EnvironmentObject var sessionManager: SessionManager

    @StateObject private var viewModel = UserProfileViewModel()

    @FocusState private var focusedField: Field?

    private enum Field {
        case firstName
        case lastName
        case email
        case companyName
    }

    var body: some View {
        ZStack {
            ProfileDesign.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header

                    if viewModel.isLoading {
                        loadingCard
                    }

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

                    profileForm
                    preferencesForm
                    passwordNavigationCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Mon profil")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadProfile()
        }
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
                    .fill(ProfileDesign.accentSoft)
                    .frame(width: 78, height: 78)

                Image(systemName: "person.crop.circle")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(ProfileDesign.accent)
            }

            VStack(spacing: 8) {
                Text("Modifier mes informations")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundColor(ProfileDesign.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Mettez à jour vos informations personnelles et vos préférences.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(ProfileDesign.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var loadingCard: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(ProfileDesign.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text("Chargement du profil")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(ProfileDesign.textPrimary)

                Text("Récupération de vos informations.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(ProfileDesign.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(ProfileDesign.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ProfileDesign.border, lineWidth: 1)
        }
    }

    private var profileForm: some View {
        ProfileSectionCard(title: "Informations personnelles") {
            VStack(spacing: 14) {
                profileTextField(
                    title: "Prénom",
                    placeholder: "Votre prénom",
                    text: $viewModel.firstName,
                    icon: "person",
                    field: .firstName
                )

                profileTextField(
                    title: "Nom",
                    placeholder: "Votre nom",
                    text: $viewModel.lastName,
                    icon: "person.text.rectangle",
                    field: .lastName
                )

                profileTextField(
                    title: "Email",
                    placeholder: "email@exemple.com",
                    text: $viewModel.email,
                    icon: "envelope",
                    keyboardType: .emailAddress,
                    autocapitalization: .never,
                    field: .email
                )

                profileTextField(
                    title: "Entreprise",
                    placeholder: "Nom de votre société",
                    text: $viewModel.companyName,
                    icon: "building.2",
                    field: .companyName
                )

                saveButton
            }
            .padding(16)
        }
    }

    private var preferencesForm: some View {
        ProfileSectionCard(title: "Préférences") {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ProfileIconBox(icon: "eurosign.circle", tint: ProfileDesign.success)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Devise préférée")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(ProfileDesign.textPrimary)

                        Text("Utilisée pour vos budgets et rapports")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(ProfileDesign.textSecondary)
                    }

                    Spacer()

                    Picker("Devise", selection: $viewModel.preferredCurrency) {
                        ForEach(PreferredCurrency.allCases) { currency in
                            Text(currency.title).tag(currency.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(ProfileDesign.accent)
                }
                .padding(16)

                ProfileDivider()

                HStack(spacing: 14) {
                    ProfileIconBox(icon: "globe", tint: ProfileDesign.accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Langue")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(ProfileDesign.textPrimary)

                        Text("Langue préférée de l’application")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(ProfileDesign.textSecondary)
                    }

                    Spacer()

                    Picker("Langue", selection: $viewModel.language) {
                        ForEach(PreferredLanguage.allCases) { language in
                            Text(language.title).tag(language.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(ProfileDesign.accent)
                }
                .padding(16)
            }
        }
    }

    private var passwordNavigationCard: some View {
        ProfileSectionCard(title: "Sécurité") {
            NavigationLink {
                ChangePasswordView()
            } label: {
                HStack(spacing: 14) {
                    ProfileIconBox(icon: "lock.rotation", tint: ProfileDesign.danger)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Modifier le mot de passe")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(ProfileDesign.textPrimary)

                        Text("Changer le mot de passe de connexion")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(ProfileDesign.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ProfileDesign.textTertiary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)
        }
    }

    private var saveButton: some View {
        Button {
            focusedField = nil

            Task {
                await viewModel.saveProfile()
            }
        } label: {
            HStack(spacing: 10) {
                if viewModel.isSavingProfile {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(viewModel.isSavingProfile ? "Enregistrement..." : "Enregistrer les modifications")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ProfileDesign.accent)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: ProfileDesign.accent.opacity(0.18), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSavingProfile)
    }

    private func profileTextField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        icon: String,
        keyboardType: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization = .words,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(ProfileDesign.textSecondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ProfileDesign.accent)
                    .frame(width: 20)

                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: field)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(ProfileDesign.textPrimary)
            }
            .padding(14)
            .background(ProfileDesign.cardSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        focusedField == field ? ProfileDesign.accent : ProfileDesign.border,
                        lineWidth: 1
                    )
            }
        }
    }
}

// MARK: - Shared Profile Components

struct ProfileSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(ProfileDesign.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content
            }
            .background(ProfileDesign.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(ProfileDesign.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
        }
    }
}

struct ProfileIconBox: View {
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

struct ProfileDivider: View {
    var body: some View {
        Divider()
            .background(ProfileDesign.border)
            .padding(.leading, 76)
    }
}

struct ProfileBanner: View {
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
    }
}

enum ProfileDesign {
    static let background = color(0xF7F8FA)
    static let card = Color.white
    static let cardSoft = color(0xF1F5FB)

    static let textPrimary = color(0x111827)
    static let textSecondary = color(0x6B7280)
    static let textTertiary = color(0x9CA3AF)

    static let accent = color(0x1F5EFF)
    static let accentSoft = color(0xE8EFFF)

    static let success = color(0x0F8554)
    static let successSoft = color(0xE8F8EF)

    static let danger = color(0xDC2626)
    static let dangerSoft = color(0xFEE2E2)

    static let border = color(0xE5E7EB)

    private static func color(_ hex: UInt, alpha: Double = 1.0) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(SessionManager())
    }
}
