/*import SwiftUI
import RealityKit
import UniformTypeIdentifiers

struct ModelViewerView: View {
    @State private var modelURL: String = ""
    @State private var loadedEntity: ModelEntity?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingFilePicker = false
    @State private var inputMode: InputMode = .url

    enum InputMode {
        case url, localFile
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Input mode selection
                Picker("Input Mode", selection: $inputMode) {
                    Text("URL").tag(InputMode.url)
                    Text("Local File").tag(InputMode.localFile)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                // Input section
                VStack(spacing: 15) {
                    if inputMode == .url {
                        urlInputSection
                    } else {
                        localFileSection
                    }

                    loadButton
                }
                .padding(.horizontal)

                // Error display
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }

                // 3D Model Display
                if isLoading {
                    ProgressView("Loading model...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    modelRenderView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("3D Model Viewer")
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.usd, .usda, .usdc, .realityFile],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }

    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model URL:")
                .font(.headline)

            TextField("Enter model URL (USDZ, Reality file)", text: $modelURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
    }

    private var localFileSection: some View {
        VStack(spacing: 10) {
            Text("Select Local Model File")
                .font(.headline)

            Button("Choose File") {
                showingFilePicker = true
            }
            .buttonStyle(BorderedProminentButtonStyle())
        }
    }

    private var loadButton: some View {
        Button("Load Model") {
            Task {
                await loadModel()
            }
        }
        .buttonStyle(BorderedProminentButtonStyle())
        .disabled(inputMode == .url && modelURL.isEmpty)
    }

    private var modelRenderView: some View {
        RealityView { content in
            // Initial setup - empty scene
            setupInitialScene(content: content)
        } update: { content in
            // Update with loaded model
            updateSceneWithModel(content: content)
        }
        .gesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    // Rotate model on drag
                    if let entity = loadedEntity {
                        let rotation = simd_quatf(
                            angle: Float(value.translation.width) * 0.01,
                            axis: [0, 1, 0]
                        )
                        entity.transform.rotation *= rotation
                    }
                }
        )
    }

    private func setupInitialScene(content: RealityViewContent) {
        // Add main directional light
        let directionalLight = DirectionalLight()
        directionalLight.light.intensity = 1000
        directionalLight.transform.rotation = simd_quatf(
            angle: -Float.pi / 4,
            axis: [1, 0, 0]
        )
        content.add(directionalLight)

        // Add fill light from opposite direction
        let fillLight = DirectionalLight()
        fillLight.light.intensity = 300
        fillLight.transform.rotation = simd_quatf(
            angle: Float.pi / 6,
            axis: [1, 0, 0]
        )
        content.add(fillLight)
    }

    private func updateSceneWithModel(content: RealityViewContent) {
        // Remove previous model
        content.entities.removeAll { entity in
            entity.components.has(ModelComponent.self)
        }

        // Add new model if available
        if let entity = loadedEntity {
            content.add(entity)
        }
    }

    private func loadModel() async {
        isLoading = true
        errorMessage = nil

        do {
            let entity: ModelEntity

            if inputMode == .url {
                entity = try await loadModelFromURL()
            } else {
                // For local files, we would use the selected file URL
                // This is handled in the file picker callback
                return
            }

            await MainActor.run {
                self.loadedEntity = entity
                self.isLoading = false
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load model: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    private func loadModelFromURL() async throws -> ModelEntity {
        guard let url = URL(string: modelURL) else {
            throw ModelLoadError.invalidURL
        }

        return try await ModelEntity(contentsOf: url)
    }

    private func loadModelFromFile(url: URL) async throws -> ModelEntity {
        return try await ModelEntity(contentsOf: url)
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            Task {
                isLoading = true
                errorMessage = nil

                do {
                    let entity = try await loadModelFromFile(url: url)
                    await MainActor.run {
                        self.loadedEntity = entity
                        self.isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to load model: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }

        case .failure(let error):
            errorMessage = "File selection failed: \(error.localizedDescription)"
        }
    }
}

enum ModelLoadError: LocalizedError {
    case invalidURL
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL format"
        case .unsupportedFormat:
            return "Unsupported model format"
        }
    }
}

// Extension to support additional file types
extension UTType {
    static let usd = UTType(filenameExtension: "usd")!
    static let usda = UTType(filenameExtension: "usda")!
    static let usdc = UTType(filenameExtension: "usdc")!
    static let realityFile = UTType(filenameExtension: "reality")!
}

#Preview {
    ModelViewerView()
}
*/
