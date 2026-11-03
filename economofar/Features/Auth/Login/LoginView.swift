import SwiftUI
import UIKit

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var sessionManager: SessionManager

    @StateObject var authService = AuthService()

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false

    @FocusState private var focusedField: Field?

    enum Field {
        case email
        case password
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !authService.isLoading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LoginDesign.background
                    .ignoresSafeArea()

                LoginBackgroundDecoration()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 42)

                        VStack(spacing: 28) {
                            headerView
                            loginCard
                        }
                        .padding(.horizontal, 22)

                        Spacer(minLength: 34)

                        footerView
                            .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: UIScreen.main.bounds.height - 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onTapGesture {
                focusedField = nil
            }
        }
        .onChange(of: authService.isAuthenticated) { authenticated in
            if authenticated {
                if let token = KeychainManager.loadToken() {
                    sessionManager.setSession(token: token)
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 22) {
            LoginLogoView()

            VStack(spacing: 10) {
                Text("Economofar")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(LoginDesign.textPrimary)
                    .tracking(-0.8)

                Text("Connectez-vous pour gérer vos tickets et suivre vos dépenses.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(LoginDesign.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 18)
            }
        }
    }

    // MARK: - Login Card

    private var loginCard: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Connexion")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(LoginDesign.textPrimary)

                Text("Accédez à votre espace professionnel.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(LoginDesign.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 14) {
                LoginTextField(
                    title: "Email",
                    placeholder: "Email professionnel",
                    icon: "envelope",
                    text: $email,
                    focusedField: $focusedField,
                    field: .email,
                    keyboardType: .emailAddress,
                    submitLabel: .next
                ) {
                    focusedField = .password
                }

                LoginPasswordField(
                    title: "Mot de passe",
                    placeholder: "Votre mot de passe",
                    icon: "lock",
                    password: $password,
                    showPassword: $showPassword,
                    focusedField: $focusedField,
                    field: .password
                ) {
                    login()
                }
            }

            if !authService.errorMessage.isEmpty {
                errorView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            loginButton

            NavigationLink(destination: RegisterView(authService: authService)) {
                HStack(spacing: 4) {
                    Text("Pas de compte ?")
                        .foregroundColor(LoginDesign.textSecondary)

                    Text("Créer un compte")
                        .fontWeight(.bold)
                        .foregroundColor(LoginDesign.accent)
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .background(LoginDesign.card)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(LoginDesign.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.055), radius: 22, x: 0, y: 12)
    }

    private var errorView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(LoginDesign.danger)

            Text(authService.errorMessage)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(LoginDesign.danger)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(12)
        .background(LoginDesign.dangerSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var loginButton: some View {
        Button {
            login()
        } label: {
            HStack(spacing: 10) {
                if authService.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Se connecter")
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
                    LoginDesign.mainGradient
                } else {
                    LoginDesign.disabled
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(
                color: canSubmit ? LoginDesign.accent.opacity(0.24) : Color.clear,
                radius: 16,
                x: 0,
                y: 8
            )
        }
        .disabled(!canSubmit)
        .padding(.top, 4)
    }

    private var footerView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(LoginDesign.accent)

                Text("Connexion sécurisée")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(LoginDesign.textSecondary)
            }

            Text("Version 1.0.0")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(LoginDesign.textTertiary)
        }
    }

    // MARK: - Login Action

    private func login() {
        guard canSubmit else { return }

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        focusedField = nil

        authService.login(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
    }
}

// MARK: - Design System

private enum LoginDesign {
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

private struct LoginBackgroundDecoration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LoginDesign.accent.opacity(0.055))
                .frame(width: 280, height: 280)
                .blur(radius: 55)
                .offset(x: -150, y: -330)

            Circle()
                .fill(LoginDesign.accent.opacity(0.04))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(x: 160, y: 310)
        }
    }
}

// MARK: - Logo

private struct LoginLogoView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LoginDesign.accent.opacity(0.08))
                .frame(width: 142, height: 142)
                .blur(radius: 12)

            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LoginDesign.card)
                .frame(width: 116, height: 116)
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(LoginDesign.border, lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.07), radius: 20, x: 0, y: 10)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LoginDesign.mainGradient)
                .frame(width: 76, height: 76)
                .shadow(color: LoginDesign.accent.opacity(0.20), radius: 14, x: 0, y: 8)

            Image(systemName: "receipt")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.white)

            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 30, height: 30)
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

                Image(systemName: "eurosign")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(LoginDesign.accent)
            }
            .offset(x: 36, y: 35)
        }
    }
}

// MARK: - Text Field

private struct LoginTextField: View {
    let title: String
    let placeholder: String
    let icon: String

    @Binding var text: String
    @FocusState.Binding var focusedField: LoginView.Field?

    let field: LoginView.Field
    let keyboardType: UIKeyboardType
    let submitLabel: SubmitLabel
    let onSubmit: () -> Void

    private var isFocused: Bool {
        focusedField == field
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(LoginDesign.textSecondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isFocused ? LoginDesign.accent : LoginDesign.textTertiary)
                    .frame(width: 20)

                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(submitLabel)
                    .focused($focusedField, equals: field)
                    .onSubmit(onSubmit)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(LoginDesign.textPrimary)
            }
            .padding(15)
            .background(LoginDesign.cardSoft)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isFocused ? LoginDesign.accent : LoginDesign.border, lineWidth: 1.2)
            }
        }
    }
}

// MARK: - Password Field

private struct LoginPasswordField: View {
    let title: String
    let placeholder: String
    let icon: String

    @Binding var password: String
    @Binding var showPassword: Bool
    @FocusState.Binding var focusedField: LoginView.Field?

    let field: LoginView.Field
    let onSubmit: () -> Void

    private var isFocused: Bool {
        focusedField == field
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(LoginDesign.textSecondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isFocused ? LoginDesign.accent : LoginDesign.textTertiary)
                    .frame(width: 20)

                Group {
                    if showPassword {
                        TextField(placeholder, text: $password)
                            .focused($focusedField, equals: field)
                    } else {
                        SecureField(placeholder, text: $password)
                            .focused($focusedField, equals: field)
                    }
                }
                .submitLabel(.go)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(onSubmit)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(LoginDesign.textPrimary)

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LoginDesign.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(15)
            .background(LoginDesign.cardSoft)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isFocused ? LoginDesign.accent : LoginDesign.border, lineWidth: 1.2)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LoginView()
        .environmentObject(SessionManager())
}
