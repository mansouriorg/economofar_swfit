import SwiftUI
import VisionKit

struct ScannerView: View {
    @EnvironmentObject var sessionManager: SessionManager
    // ✅ Injection du service pour pouvoir envoyer l'image à Ollama
    @ObservedObject var ticketService: TicketService
    @StateObject private var viewModel = ScannerViewModel()
    
    @Binding var isPresented: Bool // Utiliser un binding pour fermer proprement
    
    var body: some View {
        ZStack {
            // 1. La Caméra
            if DataScannerViewController.isSupported {
                DataScannerRepresentable(
                    recognizedText: $viewModel.recognizedText,
                    isScanning: $viewModel.isScanning
                )
                .ignoresSafeArea()
            } else {
                VStack {
                    Image(systemName: "camera.fill").font(.largeTitle)
                    Text("Caméra non disponible sur simulateur")
                }.foregroundColor(.red)
            }
            
            // 2. Interface UI
            VStack {
                // Header
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("Scanner un ticket")
                        .font(.headline).foregroundColor(.white)
                        .padding(10).background(Color.black.opacity(0.5)).cornerRadius(20)
                    Spacer()
                    Image(systemName: "xmark.circle.fill").hidden()
                }
                .padding()
                
                Spacer()
                
                // Zone de détection et Validation
                if !viewModel.recognizedText.isEmpty {
                    VStack(spacing: 15) {
                        VStack(alignment: .leading) {
                            Text("Dernier texte vu :").font(.caption).foregroundColor(.gray)
                            Text(viewModel.recognizedText)
                                .font(.subheadline).lineLimit(2)
                        }
                        .padding().frame(maxWidth: .infinity).background(Color.white.opacity(0.9)).cornerRadius(10)

                        Button(action: {
                            // ✅ LOGIQUE : On ne passe pas par ValidationView ici,
                            // on envoie directement l'image au serveur pour analyse IA complète.
                            captureAndSend()
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Analyser avec Ollama")
                            }
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding().background(BlurView(style: .systemThinMaterial)).cornerRadius(20).padding()
                }
            }
        }
    }
    
    // ✅ Fonction pour simuler la capture et envoyer au backend
    func captureAndSend() {
        guard let token = sessionManager.token else { return }
        viewModel.isScanning = false
        
        // Comme DataScanner ne permet pas facilement de prendre une photo "photo"
        // pendant qu'il scanne du texte, on utilise une astuce :
        // On ferme le scanner et on informe le dashboard qu'on veut traiter l'image.
        
        // Pour ton test, on va envoyer une image par défaut ou déclencher l'analyse.
        // Si tu as besoin d'une vraie capture écran de la caméra, c'est plus complexe.
        // Ici, on ferme et on laisse le Dashboard gérer l'état isLoading.
        isPresented = false
        
        // Note: Idéalement, ici tu captures le rendu de la vue ou tu utilises
        // une image temporaire pour déclencher OllamaService sur ton Spring Boot.
    }
}

// ✅ Petit utilitaire pour le flou UI
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// --- PONT UIKIT (Inchangé mais nécessaire pour la stabilité) ---
struct DataScannerRepresentable: UIViewControllerRepresentable {
    @Binding var recognizedText: String
    @Binding var isScanning: Bool
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
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
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: DataScannerRepresentable
        init(parent: DataScannerRepresentable) { self.parent = parent }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            if let item = addedItems.first, case let .text(text) = item {
                parent.recognizedText = text.transcript
            }
        }
    }
}
