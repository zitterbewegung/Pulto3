//
//  VolumetricModelView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//


//
//  VolumetricModelView.swift
//  Pulto
//
//  Created by Joshua Herman on 6/18/25.
//  Copyright 2025 Apple. All rights reserved.
//

import SwiftUI
import RealityKit

struct VolumetricModelView: View {
    let windowID: Int
    @ObservedObject var windowManager: WindowTypeManager
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    @State private var modelEntity: ModelEntity?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showControls = true
    @State private var modelScale: Float = 1.0
    @State private var modelRotation: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0])
    @State private var modelPosition: SIMD3<Float> = [0, 0, -1]
    @State private var animationSpeed: Float = 1.0
    @State private var isAnimating = false

    var window: NewWindowID? {
        windowManager.getWindow(for: windowID)
    }

    var body: some View {
        ZStack {
            // Main 3D content
            RealityView { content in
                setupImmersiveScene(content: content)
            } update: { content in
                updateModelInScene(content: content)
            }
            /*.gesture(
                DragGesture()
                    .targetedToAnyEntity()
                    .onChanged { value in
                        handleModelDrag(value)
                    }
            )
            .gesture(
                MagnificationGesture()
                    .targetedToAnyEntity()
                    .onChanged { value in
                        handleModelScale(value)
                    }
            )*/

            // Control panel overlay
            if showControls {
                VStack {
                    Spacer()

                    HStack {
                        Spacer()
                        controlPanel
                    }
                }
                .padding()
            }
        }
        .onAppear {
            loadModel()
        }
        .onChange(of: windowID) { newID in
            loadModel()
        }
        .task {
            // Auto-hide controls after 5 seconds
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
        .onTapGesture {
            // Toggle controls on tap
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls.toggle()
            }
        }
    }

    // MARK: - Control Panel
    private var controlPanel: some View {
        VStack(spacing: 16) {
            // Model info
            if let window = window {
                VStack(alignment: .leading, spacing: 8) {
                    Text("3D Model - Window #\(windowID)")
                        .font(.headline)
                        .foregroundStyle(.white)

                    if let model3D = window.state.model3DData {
                        Text(model3D.title)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }

            Divider()
                .background(.white.opacity(0.3))

            // Transform controls
            VStack(spacing: 12) {
                HStack {
                    Text("Scale")
                        .font(.caption)
                        .foregroundStyle(.white)

                    Spacer()

                    Text("\(modelScale, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Slider(value: $modelScale, in: 0.1...5.0) {
                    Text("Scale")
                } onEditingChanged: { _ in
                    updateModelTransform()
                }
                .tint(.blue)

                HStack {
                    Text("Animation Speed")
                        .font(.caption)
                        .foregroundStyle(.white)

                    Spacer()

                    Text("\(animationSpeed, specifier: "%.1f")x")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Slider(value: $animationSpeed, in: 0.0...3.0) {
                    Text("Animation Speed")
                } onEditingChanged: { _ in
                    updateAnimationSpeed()
                }
                .tint(.blue)
            }

            Divider()
                .background(.white.opacity(0.3))

            // Action buttons
            VStack(spacing: 8) {
                Button(action: toggleAnimation) {
                    HStack {
                        Image(systemName: isAnimating ? "pause.fill" : "play.fill")
                        Text(isAnimating ? "Pause" : "Play")
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: resetModelTransform) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reset")
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: exportModel) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: exitVolumetric) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Exit")
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 10)
    }

    // MARK: - Scene Setup
    private func setupImmersiveScene(content: RealityViewContent) {
        // Create ambient lighting
        //let ambientLight = AmbientLightComponent(color: .white, intensity: 0.3)
        //let ambientEntity = Entity()
        //ambientEntity.components.set(ambientLight)
        //content.add(ambientEntity)

        // Create directional light
        let directionalLight = DirectionalLight()
        directionalLight.light.intensity = 2000
        //directionalLight.light.isRealWorldProxy = true
        directionalLight.transform.rotation = simd_quatf(
            angle: -Float.pi / 4,
            axis: [1, 0, 0]
        )
        content.add(directionalLight)

        // Create secondary light for better visibility
        let fillLight = DirectionalLight()
        fillLight.light.intensity = 800
        fillLight.light.color = .init(red: 0.8, green: 0.9, blue: 1.0, alpha: 1.0)
        fillLight.transform.rotation = simd_quatf(
            angle: Float.pi / 6,
            axis: [-1, 0, 0]
        )
        content.add(fillLight)

        // Add ground plane for reference
        let groundPlane = ModelEntity(mesh: .generatePlane(width: 10, depth: 10))
        groundPlane.model?.materials = [UnlitMaterial(color: .white.withAlphaComponent(0.1))]
        groundPlane.position = [0, -2, 0]
        content.add(groundPlane)
    }

    private func updateModelInScene(content: RealityViewContent) {
        // Remove existing model entities
        content.entities.removeAll { entity in
            entity.components.has(ModelComponent.self) && entity.name == "mainModel"
        }

        // Add updated model
        if let entity = modelEntity {
            entity.name = "mainModel"
            entity.transform.scale = SIMD3<Float>(repeating: modelScale)
            entity.transform.rotation = modelRotation
            entity.transform.translation = modelPosition
            content.add(entity)
        }
    }

    // MARK: - Model Loading
    private func loadModel() {
        isLoading = true
        errorMessage = nil

        guard let window = window,
              let model3D = window.state.model3DData else {
            errorMessage = "No model data available"
            isLoading = false
            return
        }

        Task {
            do {
                let entity = try await createModelEntity(from: model3D)

                await MainActor.run {
                    self.modelEntity = entity
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func createModelEntity(from model3D: Model3DData) async throws -> ModelEntity {
        // Create entity based on model type
        switch model3D.modelType {
        case "sphere":
            return createSphereEntity(from: model3D)
        case "cube":
            return createCubeEntity(from: model3D)
        case "cylinder":
            return createCylinderEntity(from: model3D)
        case "torus":
            return createTorusEntity(from: model3D)
        case "imported":
            return try await createImportedEntity(from: model3D)
        default:
            return createDefaultEntity(from: model3D)
        }
    }

    private func createSphereEntity(from model3D: Model3DData) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: 1.0)
        let material = SimpleMaterial(color: .blue, isMetallic: false)
        return ModelEntity(mesh: mesh, materials: [material])
    }

    private func createCubeEntity(from model3D: Model3DData) -> ModelEntity {
        let mesh = MeshResource.generateBox(size: 1.0)
        let material = SimpleMaterial(color: .orange, isMetallic: false)
        return ModelEntity(mesh: mesh, materials: [material])
    }

    private func createCylinderEntity(from model3D: Model3DData) -> ModelEntity {
        let mesh = MeshResource.generateCylinder(height: 2.0, radius: 0.5)
        let material = SimpleMaterial(color: .green, isMetallic: false)
        return ModelEntity(mesh: mesh, materials: [material])
    }

    private func createTorusEntity(from model3D: Model3DData) -> ModelEntity {
        // RealityKit doesn't have a built-in torus, so create a simple placeholder
        let mesh = MeshResource.generateSphere(radius: 0.8)
        let material = SimpleMaterial(color: .purple, isMetallic: false)
        return ModelEntity(mesh: mesh, materials: [material])
    }

    private func createImportedEntity(from model3D: Model3DData) async throws -> ModelEntity {
        // Try to load from imported file data
        // This would need actual file loading implementation
        let mesh = MeshResource.generateSphere(radius: 1.0)
        let material = SimpleMaterial(color: .red, isMetallic: true)
        return ModelEntity(mesh: mesh, materials: [material])
    }

    private func createDefaultEntity(from model3D: Model3DData) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: 1.0)
        let material = SimpleMaterial(color: .gray, isMetallic: false)
        return ModelEntity(mesh: mesh, materials: [material])
    }

    // MARK: - Gesture Handlers
    private func handleModelDrag(_ value: DragGesture.Value) {
        guard let entity = modelEntity else { return }

        // Convert 2D drag to 3D rotation
        let rotationX = Float(value.translation.height) * 0.01
        let rotationY = Float(value.translation.width) * 0.01

        let deltaRotation = simd_quatf(angle: rotationX, axis: [1, 0, 0]) *
                           simd_quatf(angle: rotationY, axis: [0, 1, 0])

        modelRotation = modelRotation * deltaRotation
        updateModelTransform()
    }

    private func handleModelScale(_ value: MagnificationGesture.Value) {
        modelScale = Float(value)
        updateModelTransform()
    }

    private func updateModelTransform() {
        guard let entity = modelEntity else { return }

        entity.transform.scale = SIMD3<Float>(repeating: modelScale)
        entity.transform.rotation = modelRotation
        entity.transform.translation = modelPosition
    }

    // MARK: - Actions
    private func toggleAnimation() {
        isAnimating.toggle()

        if isAnimating {
            startRotationAnimation()
        } else {
            stopRotationAnimation()
        }
    }

    private func startRotationAnimation() {
        guard let entity = modelEntity else { return }

        let rotationAnimation = FromToByAnimation<Transform>(
            from: entity.transform,
            to: Transform(
                scale: entity.transform.scale,
                rotation: entity.transform.rotation * simd_quatf(angle: Float.pi * 2, axis: [0, 1, 0]),
                translation: entity.transform.translation
            ),
            duration: 4.0 / Double(animationSpeed),
            timing: .linear,
            bindTarget: .transform
        )

        let animationResource = try! AnimationResource.generate(with: rotationAnimation)
        entity.playAnimation(animationResource, transitionDuration: 0.3, startsPaused: false)
    }

    private func stopRotationAnimation() {
        guard let entity = modelEntity else { return }
        entity.stopAllAnimations()
    }

    private func updateAnimationSpeed() {
        if isAnimating {
            stopRotationAnimation()
            startRotationAnimation()
        }
    }

    private func resetModelTransform() {
        modelScale = 1.0
        modelRotation = simd_quatf(angle: 0, axis: [0, 1, 0])
        modelPosition = [0, 0, -1]
        updateModelTransform()
    }

    private func exportModel() {
        // Export the current model state
        guard let window = window,
              let model3D = window.state.model3DData else { return }

        // Update the model data with current transform
        let updatedModel3D = Model3DData(
            title: model3D.title,
            modelType: model3D.modelType,
            //vertices: model3D.vertices,
            //faces: model3D.faces,
            //materials: model3D.materials
        )

        // Capture the wrapped manager and call the helper
        let manager = windowManager
        manager.updateWindowModel3DData(windowID, model3DData: updatedModel3D)

        // Export to Jupyter notebook
        let jupyterCode = generateJupyterCode(for: updatedModel3D)
        windowManager.updateWindowContent(windowID, content: jupyterCode)
        manager.updateWindowContent(windowID, content: jupyterCode)
    }

    private func generateJupyterCode(for model3D: Model3DData) -> String {
        return """
        # 3D Model - \(model3D.title)
        # Generated from VisionOS Volumetric Window #\(windowID)
        
        import numpy as np
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d import Axes3D
        import plotly.graph_objects as go
        
        # Model configuration
        model_type = "\(model3D.modelType)"
        model_title = "\(model3D.title)"
        
        # Transform data
        scale = \(modelScale)
        rotation = [\(modelRotation.vector.x), \(modelRotation.vector.y), \(modelRotation.vector.z), \(modelRotation.vector.w)]
        position = [\(modelPosition.x), \(modelPosition.y), \(modelPosition.z)]
        
        # Generate model data based on type
        if model_type == "sphere":
            # Generate sphere vertices
            u = np.linspace(0, 2 * np.pi, 50)
            v = np.linspace(0, np.pi, 50)
            x = np.outer(np.cos(u), np.sin(v)) * scale
            y = np.outer(np.sin(u), np.sin(v)) * scale
            z = np.outer(np.ones(np.size(u)), np.cos(v)) * scale
            
            # Plot with matplotlib
            fig = plt.figure(figsize=(10, 8))
            ax = fig.add_subplot(111, projection='3d')
            ax.plot_surface(x, y, z, alpha=0.7, cmap='viridis')
            ax.set_title(f"3D Model: {model_title}")
            ax.set_xlabel('X')
            ax.set_ylabel('Y')
            ax.set_zlabel('Z')
            plt.show()
            
            # Interactive plot with Plotly
            fig_plotly = go.Figure(data=[go.Surface(z=z, x=x, y=y)])
            fig_plotly.update_layout(title=f"Interactive 3D Model: {model_title}")
            fig_plotly.show()
            
        elif model_type == "cube":
            # Generate cube vertices
            vertices = np.array([
                [-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1],
                [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]
            ]) * scale
            
            # Plot cube
            fig = plt.figure(figsize=(10, 8))
            ax = fig.add_subplot(111, projection='3d')
            ax.scatter(vertices[:, 0], vertices[:, 1], vertices[:, 2], s=100)
            ax.set_title(f"3D Model: {model_title}")
            ax.set_xlabel('X')
            ax.set_ylabel('Y')
            ax.set_zlabel('Z')
            plt.show()
        
        print(f"Model '{model_title}' exported from VisionOS Volumetric Window #{windowID}")
        print(f"Scale: {scale}, Position: {position}")
        """
    }

    private func exitVolumetric() {
        Task {
            await dismissImmersiveSpace()

            // Optionally open the regular window view
            await MainActor.run {
                openWindow(value: windowID)
            }
        }
    }
}

// MARK: - Extensions
extension simd_quatf {
    var vector: SIMD4<Float> {
        return SIMD4<Float>(self.imag.x, self.imag.y, self.imag.z, self.real)
    }
}

#Preview {
    VolumetricModelView(
        windowID: 1,
        windowManager: WindowTypeManager.shared
    )
}
