import SwiftUI
import VisionKit

struct ScannerView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = ScannerViewModel()
    
    // Pour fermer la vue (retour au Dashboard)
    @Environment(\.dismiss) var dismiss
    
    // ✅ NOUVEAU : État pour déclencher la navigation vers l'écran de validation
    @State private var showValidation = false
    
    var body: some View {
        ZStack {
            // 1. La Caméra (Le pont UIKit)
            if DataScannerViewController.isSupported {
                DataScannerRepresentable(
                    recognizedText: $viewModel.recognizedText,
                    isScanning: $viewModel.isScanning
                )
                .ignoresSafeArea()
            } else {
                Text("Votre appareil ne supporte pas le scan de texte.")
                    .foregroundColor(.red)
            }
            
            // 2. L'Interface par-dessus la caméra
            VStack {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("Pointez vers le ticket")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 15)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                    Spacer()
                    // Bouton invisible pour équilibrer le header
                    Image(systemName: "xmark.circle.fill").hidden()
                }
                .padding()
                
                Spacer()
                
                // Zone de texte détecté (Preview)
                if !viewModel.recognizedText.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Texte détecté :")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(viewModel.recognizedText)
                            .font(.body)
                            .lineLimit(3) // On affiche juste 3 lignes max
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(15)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    
                    // Bouton Valider
                    Button(action: {
                        viewModel.validateScan()
                        // ✅ Au lieu de fermer, on ouvre l'écran de validation
                        showValidation = true
                    }) {
                        Text("Valider la capture")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .onAppear {
            // Vérification simple au démarrage
            if !DataScannerViewController.isSupported {
                viewModel.errorMessage = "Appareil non compatible"
            }
        }
        // ✅ NAVIGATION : Vers l'écran de validation
        .navigationDestination(isPresented: $showValidation) {
            ValidationView(scannedText: viewModel.recognizedText)
        }
    }
}

// --- LE PONT UIKIT (C'est la partie magique) ---
struct DataScannerRepresentable: UIViewControllerRepresentable {
    @Binding var recognizedText: String
    @Binding var isScanning: Bool
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        // On configure le scanner pour chercher du TEXTE
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isScanning {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    // Le Coordinateur écoute les événements de la caméra
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: DataScannerRepresentable
        
        init(parent: DataScannerRepresentable) {
            self.parent = parent
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            // Si l'utilisateur tape sur un texte à l'écran
            if case let .text(text) = item {
                parent.recognizedText = text.transcript
            }
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Quand du nouveau texte est détecté
            if let item = addedItems.first, case let .text(text) = item {
                // On met à jour le texte seulement s'il est assez long (pour éviter le bruit)
                if text.transcript.count > 5 {
                    parent.recognizedText = text.transcript
                }
            }
        }
    }
}
