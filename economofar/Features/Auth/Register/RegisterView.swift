import SwiftUI
import UIKit

// MARK: - Register View

struct RegisterView: View {
    @ObservedObject var authService: AuthService

    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false

    @FocusState private var focusedField: Field?

    enum Field {
        case firstName
        case lastName
        case email
        case password
    }

    private var canSubmit: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !authService.isLoading
    }

    var body: some View {
        ZStack {
            RegisterDesign.background
                .ignoresSafeArea()

            RegisterBackgroundDecoration()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: 28) {
                        headerView
                        registerCard
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 28)

                    footerView
                        .padding(.top, 28)
                        .padding(.bottom, 28)
                }
            }
        }
        .navigationTitle("Inscription")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
            focusedField = nil
        }
        .onChange(of: authService.isRegistered) { success in
            if success {
                authService.isRegistered = false
                dismiss()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 22) {
            RegisterLogoView()

            VStack(spacing: 10) {
                Text("Créer un compte")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(RegisterDesign.textPrimary)
                    .tracking(-0.6)

                Text("Renseignez vos informations pour accéder à Economofar.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(RegisterDesign.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 18)
            }
        }
    }

    // MARK: - Register Card

    private var registerCard: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Informations du compte")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundColor(RegisterDesign.textPrimary)

                Text("Ces informations permettront de créer votre profil utilisateur.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(RegisterDesign.textSecondary)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 14) {
                inputField(
                    title: "Prénom",
                    placeholder: "Votre prénom",
                    icon: "person",
                    text: $firstName,
                    field: .firstName,
                    keyboardType: .default,
                    submitLabel: .next
                ) {
                    focusedField = .lastName
                }

                inputField(
                    title: "Nom",
                    placeholder: "Votre nom",
                    icon: "person",
                    text: $lastName,
                    field: .lastName,
                    keyboardType: .default,
                    submitLabel: .next
                ) {
                    focusedField = .email
                }

                inputField(
                    title: "Email",
                    placeholder: "Email professionnel",
                    icon: "envelope",
                    text: $email,
                    field: .email,
                    keyboardType: .emailAddress,
                    submitLabel: .next
                ) {
                    focusedField = .password
                }

                passwordField
            }

            if !authService.errorMessage.isEmpty {
                errorView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            registerButton

            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Text("Déjà un compte ?")
                        .foregroundColor(RegisterDesign.textSecondary)

                    Text("Se connecter")
                        .fontWeight(.bold)
                        .foregroundColor(RegisterDesign.accent)
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .background(RegisterDesign.card)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(RegisterDesign.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.055), radius: 22, x: 0, y: 12)
    }

    // MARK: - Input Field

    private func inputField(
        title: String,
        placeholder: String,
        icon: String,
        text: Binding<String>,
        field: Field,
        keyboardType: UIKeyboardType,
        submitLabel: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(RegisterDesign.textSecondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(focusedField == field ? RegisterDesign.accent : RegisterDesign.textTertiary)
                    .frame(width: 20)

                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(field == .email ? .never : .words)
                    .autocorrectionDisabled(field == .email)
                    .submitLabel(submitLabel)
                    .focused($focusedField, equals: field)
                    .onSubmit(onSubmit)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(RegisterDesign.textPrimary)
            }
            .padding(15)
            .background(RegisterDesign.cardSoft)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        focusedField == field ? RegisterDesign.accent : RegisterDesign.border,
                        lineWidth: 1.2
                    )
            }
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mot de passe")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(RegisterDesign.textSecondary)

            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(focusedField == .password ? RegisterDesign.accent : RegisterDesign.textTertiary)
                    .frame(width: 20)

                Group {
                    if showPassword {
                        TextField("Votre mot de passe", text: $password)
                            .focused($focusedField, equals: .password)
                    } else {
                        SecureField("Votre mot de passe", text: $password)
                            .focused($focusedField, equals: .password)
                    }
                }
                .submitLabel(.join)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit {
                    register()
                }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(RegisterDesign.textPrimary)

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(RegisterDesign.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(15)
            .background(RegisterDesign.cardSoft)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        focusedField == .password ? RegisterDesign.accent : RegisterDesign.border,
                        lineWidth: 1.2
                    )
            }
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(RegisterDesign.danger)

            Text(authService.errorMessage)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(RegisterDesign.danger)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(12)
        .background(RegisterDesign.dangerSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Register Button

    private var registerButton: some View {
        Button {
            register()
        } label: {
            HStack(spacing: 10) {
                if authService.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Créer mon compte")
                        .font(.system(size: 16, weight: .bold, design: .rounded))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                if canSubmit {
                    RegisterDesign.mainGradient
                } else {
                    RegisterDesign.disabled
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(
                color: canSubmit ? RegisterDesign.accent.opacity(0.24) : Color.clear,
                radius: 16,
                x: 0,
                y: 8
            )
        }
        .disabled(!canSubmit)
        .padding(.top, 4)
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(RegisterDesign.accent)

                Text("Inscription sécurisée")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(RegisterDesign.textSecondary)
            }

            Text("Economofar • Version 1.0.0")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(RegisterDesign.textTertiary)
        }
    }

    // MARK: - Register Action

    private func register() {
        guard canSubmit else { return }

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        focusedField = nil

        authService.register(
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
    }
}

// MARK: - Design System

private enum RegisterDesign {
    static let background = color(0xF7F8FA)
    static let card = Color.white
    static let cardSoft = color(0xF1F5FB)

    static let textPrimary = color(0x111827)
    static let textSecondary = color(0x6B7280)
    static let textTertiary = color(0x9CA3AF)

    static let accent = color(0x1F5EFF)
    static let accentDark = color(0x123A8C)
    static let accentSoft = color(0xE8EFFF)

    static let danger = color(0xDC2626)
    static let dangerSoft = color(0xFEE2E2)

    static let border = color(0xE5E7EB)
    static let disabled = color(0xCBD5E1)

    static let mainGradient = LinearGradient(
        colors: [
            accentDark,
            accent
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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

// MARK: - Background Decoration

private struct RegisterBackgroundDecoration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RegisterDesign.accent.opacity(0.055))
                .frame(width: 280, height: 280)
                .blur(radius: 55)
                .offset(x: -150, y: -330)

            Circle()
                .fill(RegisterDesign.accent.opacity(0.04))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(x: 160, y: 310)
        }
    }
}

// MARK: - Logo

private struct RegisterLogoView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RegisterDesign.accent.opacity(0.08))
                .frame(width: 132, height: 132)
                .blur(radius: 12)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(RegisterDesign.card)
                .frame(width: 108, height: 108)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(RegisterDesign.border, lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.07), radius: 20, x: 0, y: 10)

            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(RegisterDesign.mainGradient)
                .frame(width: 72, height: 72)
                .shadow(color: RegisterDesign.accent.opacity(0.20), radius: 14, x: 0, y: 8)

            Image(systemName: "person.badge.plus")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RegisterView(authService: AuthService())
    }
}
