import Foundation
import SwiftUI
import Combine
import LocalAuthentication

/// Face ID / Touch ID / passcode lock.
///
/// The lock is enabled from Settings > Sécurité > "Verrouillage Face ID".
/// It engages when the app goes to the background and at cold start.
/// If the device has no passcode / biometrics, the app is never locked (no lock-out).
@MainActor
final class AppLockManager: ObservableObject {
    @Published var isLocked: Bool
    @Published var errorMessage: String? = nil

    private var isAuthenticating = false

    init() {
        // Cold start: if the lock is enabled, start locked
        isLocked = UserDefaults.standard.bool(forKey: AppStorageKeys.faceIDLock)
    }

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: AppStorageKeys.faceIDLock)
    }

    /// Call when the app goes to the background.
    func lockIfNeeded() {
        if isEnabled {
            isLocked = true
        }
    }

    /// Asks Face ID / Touch ID / passcode to unlock the app.
    func unlock() async {
        guard isLocked, !isAuthenticating else { return }

        guard isEnabled else {
            isLocked = false
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        var policyError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            // No passcode set on the device: do not lock the user out of the app
            isLocked = false
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Déverrouiller Economofar"
            )

            if success {
                errorMessage = nil
                isLocked = false
            }
        } catch {
            errorMessage = "Authentification annulée ou échouée."
        }
    }
}

// MARK: - Lock screen

struct LockScreenView: View {
    @ObservedObject var manager: AppLockManager

    var body: some View {
        ZStack {
            EconomofarUI.background
                .ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(EconomofarUI.accentSoft)
                        .frame(width: 96, height: 96)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundColor(EconomofarUI.accent)
                }

                VStack(spacing: 8) {
                    Text("Economofar est verrouillé")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(EconomofarUI.textPrimary)

                    Text("Utilisez Face ID, Touch ID ou votre code pour continuer.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(EconomofarUI.textSecondary)
                        .multilineTextAlignment(.center)
                }

                if let message = manager.errorMessage {
                    Text(message)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(EconomofarUI.danger)
                }

                Button {
                    Task {
                        await manager.unlock()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                        Text("Déverrouiller")
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 28)
                    .background(EconomofarUI.mainGradient)
                    .clipShape(Capsule())
                }
            }
            .padding(32)
        }
        .task {
            await manager.unlock()
        }
    }
}
