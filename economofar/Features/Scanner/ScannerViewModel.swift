import Foundation
import VisionKit
import SwiftUI
import Combine // <-- On n'oublie pas Combine cette fois !

@MainActor
class ScannerViewModel: ObservableObject {
    // Le texte brut détecté par la caméra
    @Published var recognizedText: String = ""
    
    // Si on est en train de scanner ou si on a fini
    @Published var isScanning: Bool = true
    
    // Les articles extraits (pour la suite)
    @Published var extractedItems: [String] = []
    
    // Gérer les erreurs (ex: caméra non disponible)
    @Published var errorMessage: String?
    
    // Cette fonction sera appelée à chaque fois que la caméra voit du nouveau texte
    func handleScannedText(_ text: String) {
        self.recognizedText = text
    }
    
    // Appelée quand l'utilisateur clique sur "Valider ce ticket"
    func validateScan() {
        self.isScanning = false
        // ICI: C'est là qu'on appellera plus tard Gemini pour analyser 'recognizedText'
        print("Texte final capturé : \(recognizedText)")
    }
}
