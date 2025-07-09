//
//  ModelViewerView.swift
//  Pulto
//
//  Created by Joshua Herman on 6/17/25.
//  Copyright 2025 Apple. All rights reserved.
//

import SwiftUI
import RealityKit
import UniformTypeIdentifiers

struct ModelViewerView: View {
    let windowID: Int
    let model3DData: Model3DData?
    
    @State private var modelURL: String = ""
    @State private var loadedEntity: ModelEntity?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingFilePicker = false
    @State private var isDefaultModelLoaded = false
    
    enum InputMode {
        case url, localFile
    }
    
    init(windowID: Int, model3DData: Model3DData? = nil) {
        self.windowID = windowID
        self.model3DData = model3DData
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Window info
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "cube.transparent.fill")
                        .foregroundColor(.blue)
                    Text("3D Model Viewer - Window #\(windowID)")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                if let model3DData = model3DData {
                    Text("Model: \(model3DData.title)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Load a 3D model to view")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // Model info display
            if let model3DData = model3DData {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model Information:")
                        .font(.headline)
                    Text("Title: \(model3DData.title)")
                    Text("Type: \(model3DData.modelType)")
                    Text("Vertices: \(model3DData.vertices.count)")
                    Text("Faces: \(model3DData.faces.count)")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // URL Input section
            VStack(alignment: .leading, spacing: 8) {
                Text("Load New Model:")
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
            // Load model data if available, otherwise load default
            if let model3DData = model3DData {
                loadModel3DData(model3DData)
            } else if loadedEntity == nil {
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
    
    private func loadModel3DData(_ model3DData: Model3DData) {
        // Convert Model3DData to RealityKit entity
        Task {
            await generateEntityFromModel3DData(model3DData)
        }
    }
    
    private func generateEntityFromModel3DData(_ model3DData: Model3DData) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Create a simple mesh from the model data
            let entity = try await createModelEntityFromData(model3DData)
            
            await MainActor.run {
                self.loadedEntity = entity
                self.isLoading = false
                self.isDefaultModelLoaded = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create model: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func createModelEntityFromData(_ model3DData: Model3DData) async throws -> ModelEntity {
        // Implementation not provided
        throw NSError(domain: "ModelViewerError", code: 3, userInfo: [NSLocalizedDescriptionKey: "createModelEntityFromData implementation missing"])
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
            throw NSError(domain: "ModelViewerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL format"])
        }
        
        return try await ModelEntity(contentsOf: url)
    }
}

enum ModelLoadError: LocalizedError {
    case invalidURL
    case unsupportedFormat
    case defaultModelNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL format"
        case .unsupportedFormat:
            return "Unsupported model format"
        case .defaultModelNotFound:
            return "Default Pluto_1_2374.usdz model not found in bundle"
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
    ModelViewerView(windowID: 1)
}