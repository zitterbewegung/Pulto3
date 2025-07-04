import SwiftUI
import RealityKit
import UniformTypeIdentifiers

struct VolumetricWindow: View {
    @State private var modelURL: String = ""
    @State private var loadedEntity: ModelEntity?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isDefaultModelLoaded = false

    var body: some View {
        VStack(spacing: 20) {
            // Default model info
            if isDefaultModelLoaded {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "cube.transparent.fill")
                            .foregroundColor(.blue)
                        Text("Default Model: Pluto_1_2374.usdz")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    Text("Drag to rotate • Enter URL below to load different models")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // Removed Input mode selection, input section now only handles URL input
            VStack(alignment: .leading, spacing: 8) {
                Text("Model URL:")
                    .font(.headline)

                TextField("Enter model URL (USDZ, Reality file)", text: $modelURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal)

            // Load buttons
            HStack(spacing: 12) {
                Button("Load Model") {
                    Task {
                        await loadModel()
                    }
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .disabled(modelURL.isEmpty)
                
                Button("Reset to Default") {
                    Task {
                        await loadDefaultModel()
                    }
                }
                .buttonStyle(BorderedButtonStyle())
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
        .onAppear {
            // Load default model when view appears
            if loadedEntity == nil {
                Task {
                    await loadDefaultModel()
                }
            }
        }
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

    private func loadDefaultModel() async {
        isLoading = true
        errorMessage = nil
        isDefaultModelLoaded = false
        
        do {
            guard let url = Bundle.main.url(forResource: "Pluto_1_2374", withExtension: "usdz") else {
                throw NSError(domain: "ModelViewerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Default Pluto_1_2374.usdz model not found in bundle"])
            }
            
            let entity = try await ModelEntity(contentsOf: url)
            
            await MainActor.run {
                self.loadedEntity = entity
                self.isLoading = false
                self.isDefaultModelLoaded = true
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load default model: \(error.localizedDescription)"
                self.isLoading = false
                self.isDefaultModelLoaded = false
            }
        }
    }

    private func loadModel() async {
        isLoading = true
        errorMessage = nil
        isDefaultModelLoaded = false

        do {
            let entity = try await loadModelFromURL()

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
}

#Preview {
    VolumetricWindow()
}