//
//  ThreeDModelViewerView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/12/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import RealityKit

struct ThreeDModelViewerView: View {
    let modelURL: URL
    @State private var rootEntity = Entity()
    @State private var currentModelEntity: ModelEntity?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // Main 3D scene
            RealityView { content in
                content.add(rootEntity)
            }
            
            // Loading overlay
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading \(modelURL.lastPathComponent)...")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .padding(24)
                .background(.regularMaterial)
                .cornerRadius(16)
            }
            
            // Error overlay
            if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                    Text("Failed to Load Model")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .background(.regularMaterial)
                .cornerRadius(16)
            }
        }
        .onAppear {
            Task {
                await setupScene()
            }
        }
        .gesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    guard let modelEntity = currentModelEntity else { return }
                    
                    // Rotate model based on drag
                    let translationMagnitude = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)
                    let rotationAmount = Float(translationMagnitude) * 0.01
                    let rotationAxis = simd_normalize(simd_float3(
                        Float(value.translation.height),
                        Float(value.translation.width),
                        0
                    ))
                    
                    let rotation = simd_quatf(angle: rotationAmount, axis: rotationAxis)
                    modelEntity.transform.rotation = rotation * modelEntity.transform.rotation
                }
        )
    }
    
    @MainActor
    private func setupScene() async {
        isLoading = true
        errorMessage = nil
        
        // Clear any existing content
        rootEntity.children.removeAll()
        currentModelEntity = nil
        
        // Add lighting
        addLighting()
        
        do {
            // Load the model
            let modelEntity = try await ModelEntity(contentsOf: modelURL)
            
            // Auto-scale to reasonable size
            let bounds = modelEntity.visualBounds(relativeTo: nil)
            let maxDimension = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
            
            if maxDimension > 0 {
                let targetSize: Float = 0.4 // 40cm max dimension
                let scale = targetSize / maxDimension
                modelEntity.scale = .one * scale
            }
            
            // Enable interaction
            modelEntity.generateCollisionShapes(recursive: true)
            modelEntity.components.set(InputTargetComponent())
            modelEntity.components.set(HoverEffectComponent())
            
            rootEntity.addChild(modelEntity)
            currentModelEntity = modelEntity
            
            // Add info label
            addInfoLabel(modelURL.deletingPathExtension().lastPathComponent)
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func addLighting() {
        // Ambient light
        let ambientLight = PointLightComponent(color: .white, intensity: 500)
        let ambientEntity = Entity()
        ambientEntity.components.set(ambientLight)
        ambientEntity.position = [0, 2, 0]
        rootEntity.addChild(ambientEntity)

        // Directional light
        let directionalLight = DirectionalLightComponent(color: .white, intensity: 1000)
        let directionalEntity = Entity()
        directionalEntity.components.set(directionalLight)
        directionalEntity.look(at: [0, 0, 0], from: [3, 3, 3], upVector: [0, 1, 0], relativeTo: nil)
        rootEntity.addChild(directionalEntity)
    }
    
    private func addInfoLabel(_ title: String) {
        let entity = Entity()
        entity.components.set(BillboardComponent())
        entity.position.y = -0.3

        if let titleMesh = try? MeshResource.generateText(
            title,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.06, weight: .bold)
        ) {
            let material = SimpleMaterial(color: .systemBlue, isMetallic: false)
            let textEntity = ModelEntity(mesh: titleMesh, materials: [material])
            entity.addChild(textEntity)
        }

        rootEntity.addChild(entity)
    }
}

#Preview {
    // Note: This preview won't work without an actual USDZ file
    if let url = Bundle.main.url(forResource: "Pluto_1_2374", withExtension: "usdz") {
        ThreeDModelViewerView(modelURL: url)
    } else {
        Text("No preview model available")
    }
}