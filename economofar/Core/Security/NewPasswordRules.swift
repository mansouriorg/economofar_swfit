import Foundation

struct NewPasswordRule: Identifiable {
    let id: String
    let text: String
    let isMet: Bool

    var spoken: String {
        isMet ? "\(text), respecté" : "\(text), pas encore respecté"
    }
}

enum NewPasswordRules {
    static let minLength = 8
    static let maxBytes = 72
    static let minLocalPart = 4

    private static let common: Set<String> = [
        "password1", "password12", "password123", "password1234", "passw0rd", "p@ssw0rd",
        "azerty123", "azerty1234", "azertyuiop1", "qwerty123", "qwerty1234", "qwerty12345",
        "motdepasse1", "motdepasse123", "abc12345", "abcd1234", "abcd12345",
        "iloveyou1", "welcome1", "welcome123", "admin123", "admin1234",
        "letmein123", "monkey123", "dragon123", "football1", "soleil123",
        "bonjour123", "bienvenue1", "changeme1"
    ]

    static func evaluate(_ password: String, email: String = "") -> [NewPasswordRule] {
        var rules = [
            NewPasswordRule(
                id: "length",
                text: "Au moins 8 caractères",
                isMet: password.count >= minLength
            ),
            NewPasswordRule(
                id: "mix",
                text: "Au moins une lettre et un chiffre",
                isMet: hasLetterAndDigit(password)
            ),
            NewPasswordRule(
                id: "common",
                text: "Pas un mot de passe trop courant",
                isMet: common.contains(password.lowercased()) == false
            ),
            NewPasswordRule(
                id: "email",
                text: "Ne contient pas votre adresse e-mail",
                isMet: containsEmail(password, email: email) == false
            )
        ]

        if password.utf8.count > maxBytes {
            rules.append(
                NewPasswordRule(
                    id: "bytes",
                    text: "72 octets au maximum (une lettre accentuée en compte 2)",
                    isMet: false
                )
            )
        }

        return rules
    }

    static func isAcceptable(_ password: String, email: String = "") -> Bool {
        evaluate(password, email: email).allSatisfy { $0.isMet }
    }

    private static func hasLetterAndDigit(_ password: String) -> Bool {
        var letter = false
        var digit = false

        for scalar in password.unicodeScalars {
            if CharacterSet.letters.contains(scalar) {
                letter = true
            } else if CharacterSet.decimalDigits.contains(scalar) {
                digit = true
            }
        }

        return letter && digit
    }

    private static func containsEmail(_ password: String, email: String) -> Bool {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if address.isEmpty {
            return false
        }

        let lower = password.lowercased()

        if lower == address {
            return true
        }

        var local = address

        if let at = address.firstIndex(of: "@") {
            local = String(address[..<at])
        }

        return local.count >= minLocalPart && lower.contains(local)
    }
}
