import SwiftUI

struct LoginView: View {
    // 1. On récupère le SessionManager global
    @EnvironmentObject var sessionManager: SessionManager
    
    // 2. On connecte notre ViewModel local
    @StateObject private var viewModel = LoginViewModel()
    
    // Focus state pour gérer l'animation des champs actifs
    @FocusState private var focusedField: Field?
    enum Field {
        case email, password
    }
    
    var body: some View {
        ZStack {
            // --- ARRIÈRE-PLAN ---
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            // Cercles décoratifs (pour un effet moderne)
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
                        
                        Image(systemName: "receipt.store.fill") // Icône plus "remplie"
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
                    
                    // Champ Email Customisé
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.gray)
                        TextField("Email professionnel", text: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: focusedField == .email ? .blue.opacity(0.3) : .gray.opacity(0.1), radius: 5, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedField == .email ? Color.blue : Color.clear, lineWidth: 1)
                    )
                    
                    // Champ Password Customisé
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                        SecureField("Mot de passe", text: $viewModel.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: focusedField == .password ? .blue.opacity(0.3) : .gray.opacity(0.1), radius: 5, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedField == .password ? Color.blue : Color.clear, lineWidth: 1)
                    )
                    
                    // Message d'erreur
                    if let error = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error)
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 5)
                        .transition(.opacity) // Animation d'apparition
                    }
                    
                    // --- BOUTON LOGIN ---
                    Button(action: {
                        // Petit retour haptique
                        let impactMed = UIImpactFeedbackGenerator(style: .medium)
                        impactMed.impactOccurred()
                        
                        // Action
                        viewModel.login { user in
                            if let user = user {
                                withAnimation {
                                    sessionManager.login(user: user)
                                }
                            }
                        }
                    }) {
                        ZStack {
                            if viewModel.isLoading {
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
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.cyan]), startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Footer discret
                Text("Version 1.0.0 • Catchub Inc.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
            .padding()
        }
        // Permet de fermer le clavier en touchant le fond
        .onTapGesture {
            focusedField = nil
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(SessionManager())
}
