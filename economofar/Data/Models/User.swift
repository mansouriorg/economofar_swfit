import Foundation

enum UserRole: String, Codable {
    case admin // Le patron (accès complet)
    case staff // L'employé (scan uniquement)
}

struct User: Identifiable, Codable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let role: UserRole
    
    // Un petit helper pour afficher le nom complet
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
}
