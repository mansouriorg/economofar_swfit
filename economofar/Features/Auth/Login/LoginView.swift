import SwiftUI

struct LoginView: View {
    // On accède au SessionManager global
    @EnvironmentObject var sessionManager: SessionManager
    
    // ✅ On utilise le service d'authentification pour l'appel API
    @StateObject var authService = AuthService()
    
    // États locaux pour le formulaire
    @State private var email = ""
    @State private var password = ""
    
    // Focus state pour l'UX
    @FocusState private var focusedField: Field?
    enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationStack {
            // --- ÉCRAN DE CONNEXION ---
            ZStack {
                // --- ARRIÈRE-PLAN ---
                LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                // Cercles décoratifs
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .offset(x: -150, y: -300)
                
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .offset(x: 150, y: 350)
                
                VStack(spacing: 30) {
                    
                    Spacer()
                    
                    // --- HEADER (LOGO & TITRE) ---
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 100, height: 100)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            
                            Image(systemName: "receipt.store.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.blue)
                        }
                        .padding(.bottom, 10)
                        
                        Text("Economofar")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Pilotez vos achats, maîtrisez vos marges.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // --- FORMULAIRE (CARD) ---
                    VStack(spacing: 20) {
                        
                        // Champ Email
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.gray)
                            TextField("Email professionnel", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: focusedField == .email ? .blue.opacity(0.3) : .gray.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // Champ Password
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.gray)
                            SecureField("Mot de passe", text: $password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: focusedField == .password ? .blue.opacity(0.3) : .gray.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // Message d'erreur
                        if !authService.errorMessage.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(authService.errorMessage)
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 5)
                        }
                        
                        // BOUTON LOGIN
                        Button(action: {
                            print("🔘 [LoginView] Clic sur Se connecter")
                            let impactMed = UIImpactFeedbackGenerator(style: .medium)
                            impactMed.impactOccurred()
                            focusedField = nil
                            authService.login(email: email, password: password)
                        }) {
                            ZStack {
                                if authService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    HStack {
                                        Text("Se connecter")
                                            .font(.headline)
                                        Image(systemName: "arrow.right")
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.cyan]), startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .disabled(authService.isLoading)
                        .padding(.top, 10)
                        
                        // LIEN VERS REGISTER
                        NavigationLink(destination: RegisterView(authService: authService)) {
                            Text("Pas de compte ? Créer un compte")
                                .foregroundColor(.blue)
                                .padding(.top, 5)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    Text("Version 1.0.0 • Economofar Inc.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                }
                .padding()
            }
            .onTapGesture {
                focusedField = nil
            }
        }
        // ✅ CRUCIAL : On surveille le succès de l'auth pour transférer le token au SessionManager global
        .onChange(of: authService.isAuthenticated) { authenticated in
            if authenticated {
                print("🚀 [LoginView] Succès détecté via AuthService")
                // On récupère le token stocké par AuthService
                if let token = UserDefaults.standard.string(forKey: "jwt_token") {
                    print("🔑 [LoginView] Transfert du token au SessionManager...")
                    // On met à jour le sessionManager (ce qui déclenchera l'affichage du Dashboard)
                    sessionManager.setSession(token: token)
                }
            }
        }
    }
}
