import SwiftUI
import UniformTypeIdentifiers

struct USDZLoaderView: View {
    @State private var showFileImporter = false
    @State private var modelURL: URL? // The URL for Model3D to load from (non-scoped temp URL)
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            if let url = modelURL {
                Model3D(url: url) { model in
                    model
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView("Loading Model...")
                }
            } else {
                Text("No model loaded")
                    .foregroundColor(.gray)
            }

            if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            }

            Button("Import USDZ Model") {
                showFileImporter = true
            }
            .padding()
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.usdz],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedURL = try result.get().first else { return }
                
                // Start security-scoped access
                guard selectedURL.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "AccessError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not access the file."])
                }
                defer { selectedURL.stopAccessingSecurityScopedResource() }
                
                // Read the file data while scoped
                let data = try Data(contentsOf: selectedURL)
                
                // Create a temporary file in the app's sandbox (no scope needed)
                let tempDirectory = FileManager.default.temporaryDirectory
                let tempURL = tempDirectory.appendingPathComponent(selectedURL.lastPathComponent)
                
                // Write the data to the temp URL
                try data.write(to: tempURL)
                
                // Set the temp URL for Model3D to load
                modelURL = tempURL
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}