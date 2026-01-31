import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    
    // Quelques états pour simuler des réglages
    @State private var notificationsEnabled = true
    @State private var faceIDEnabled = false
    
    var body: some View {
        NavigationStack {
            List {
                // --- SECTION PROFIL ---
                Section {
                    HStack(spacing: 15) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 60, height: 60)
                            
                            Text(String(sessionManager.currentUser?.firstName.prefix(1) ?? "U"))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        // Infos User
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(sessionManager.currentUser?.firstName ?? "Utilisateur") \(sessionManager.currentUser?.lastName ?? "")")
                                .font(.headline)
                            
                            Text(sessionManager.currentUser?.email ?? "email@exemple.com")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text(sessionManager.currentUser?.role == .admin ? "Administrateur" : "Staff")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // --- SECTION GÉNÉRAL ---
                Section(header: Text("Général")) {
                    Toggle(isOn: $notificationsEnabled) {
                        Label {
                            Text("Notifications")
                        } icon: {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Toggle(isOn: $faceIDEnabled) {
                        Label {
                            Text("Verrouillage FaceID")
                        } icon: {
                            Image(systemName: "faceid")
                                .foregroundColor(.green)
                        }
                    }
                    
                    NavigationLink {
                        Text("Page d'aide") // Placeholder
                    } label: {
                        Label {
                            Text("Aide & Support")
                        } icon: {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // --- SECTION DÉCONNEXION ---
                Section {
                    Button(action: {
                        sessionManager.logout()
                    }) {
                        Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                } footer: {
                    HStack {
                        Spacer()
                        Text("Economofar v1.0.0")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Paramètres")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SessionManager())
}
