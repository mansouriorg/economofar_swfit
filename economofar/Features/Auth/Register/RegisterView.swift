import SwiftUI

struct RegisterView: View {
    // On reçoit le service depuis LoginView
    @ObservedObject var authService: AuthService
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    
    // Pour fermer la vue (revenir en arrière)
    @Environment(\.dismiss) var dismiss
    
    // Focus pour le clavier
    @FocusState private var focusedField: Field?
    enum Field {
        case firstName, lastName, email, password
    }

    var body: some View {
        ZStack {
            // Fond dégradé (cohérent avec le Login)
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    
                    // Titre
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.blue)
                        
                        Text("Créer un compte")
                            .font(.largeTitle)
                            .bold()
                    }
                    .padding(.top, 40)
                    
                    // Formulaire
                    VStack(spacing: 20) {
                        
                        // Prénom
                        CustomTextField(icon: "person.fill", placeholder: "Prénom", text: $firstName)
                            .focused($focusedField, equals: .firstName)
                            .submitLabel(.next)
                        
                        // Nom
                        CustomTextField(icon: "person.fill", placeholder: "Nom", text: $lastName)
                            .focused($focusedField, equals: .lastName)
                            .submitLabel(.next)
                        
                        // Email
                        CustomTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                        
                        // Mot de passe
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.gray)
                            SecureField("Mot de passe", text: $password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.join)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: focusedField == .password ? .blue.opacity(0.3) : .gray.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                    
                    // Erreur
                    if !authService.errorMessage.isEmpty {
                        Text(authService.errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    // Bouton S'inscrire
                    Button(action: {
                        focusedField = nil
                        // On lance l'inscription (sans connexion auto)
                        authService.register(firstName: firstName, lastName: lastName, email: email, password: password)
                    }) {
                        if authService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("S'inscrire")
                                .bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .padding(.horizontal)
                    .disabled(authService.isLoading)
                    
                    Spacer()
                }
                .padding()
            }
        }
        .onTapGesture {
            focusedField = nil
        }
        // ✅ CHANGEMENT ICI : On écoute 'isRegistered' au lieu de 'isAuthenticated'
        .onChange(of: authService.isRegistered) { success in
            if success {
                // Si l'inscription a marché, on remet le flag à false pour la prochaine fois
                authService.isRegistered = false
                // Et on ferme la vue pour revenir au Login
                dismiss()
            }
        }
    }
}

// Un petit composant réutilisable pour éviter de copier-coller le style des champs
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
            TextField(placeholder, text: $text)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
