// Fichier: economofar/Data/Models/AuthModels.swift
import Foundation

// Ce qu'on envoie pour s'inscrire
struct RegisterRequest: Codable {
    let firstName: String
    let lastName: String
    let email: String
    let password: String
}

// Ce qu'on envoie pour se connecter
struct LoginRequest: Codable {
    let email: String
    let password: String
}

// Ce que le serveur répond (Le Token JWT)
struct AuthResponse: Codable {
    let token: String
}
