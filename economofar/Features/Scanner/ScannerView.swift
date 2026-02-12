import SwiftUI
import UIKit

// ✅ On utilise UIViewControllerRepresentable pour accéder à la caméra native iOS
struct ScannerView: UIViewControllerRepresentable {
    
    // Pour fermer la vue
    @Binding var isPresented: Bool
    
    // Callback pour renvoyer l'image capturée au Dashboard
    var onImageCaptured: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        
        // Si c'est un iPhone réel -> Caméra
        // Si c'est le simulateur -> Galerie Photo (pour tester)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
        } else {
            print("⚠️ Caméra indisponible (Simulateur ?), ouverture de la galerie.")
            picker.sourceType = .photoLibrary
        }
        
        // Désactiver l'édition pour avoir l'image brute
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Rien à mettre à jour dynamiquement ici
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    // Le Coordinateur gère les événements de la caméra (photo prise, annulation)
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ScannerView
        
        init(parent: ScannerView) {
            self.parent = parent
        }
        
        // Appelé quand l'utilisateur a pris une photo
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            
            if let image = info[.originalImage] as? UIImage {
                print("📸 Photo capturée avec succès !")
                // On renvoie l'image au parent (DashboardView)
                parent.onImageCaptured(image)
            } else {
                print("❌ Erreur: Aucune image trouvée")
            }
            
            // On ferme la caméra
            parent.isPresented = false
        }
        
        // Appelé si l'utilisateur annule
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}
