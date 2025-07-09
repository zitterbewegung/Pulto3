//
//  ImmersiveSpaceView.swift
//  Pulto
//
//  Created by Assistant on 12/29/2024.
//

import SwiftUI
import RealityKit

struct ImmersiveSpaceView: View {
    @EnvironmentObject var windowManager: WindowTypeManager
    @EnvironmentObject var spatialManager: SpatialWindowManager
    
    var body: some View {
        RealityView { content in
            setupImmersiveSpace(content: content)
        } update: { content in
            updateImmersiveSpace(content: content)
        }
        .gesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    handleDragGesture(value)
                }
        )
        .onAppear {
            print("🌐 ImmersiveSpace appeared")
        }
        .onDisappear {
            print("🌐 ImmersiveSpace disappeared")
        }
    }
    
    private func setupImmersiveSpace(content: RealityViewContent) {
        // Add lighting
        let directionalLight = DirectionalLight()
        directionalLight.light.intensity = 1000
        directionalLight.transform.rotation = simd_quatf(
            angle: -Float.pi / 4,
            axis: [1, 0, 0]
        )
        content.add(directionalLight)
        
        // Add ambient light
        let ambientLight = AmbientLight()
        ambientLight.light.intensity = 300
        content.add(ambientLight)
        
        // Position windows in 3D space
        positionWindowsIn3DSpace(content: content)
    }
    
    private func updateImmersiveSpace(content: RealityViewContent) {
        // Update window positions and states
        let openWindows = windowManager.getAllWindows(onlyOpen: true)
        
        for window in openWindows {
            let immersiveState = spatialManager.getImmersiveState(for: window.id)
            
            if immersiveState.isVisible {
                // Update window position and appearance in 3D space
                updateWindowInSpace(window: window, state: immersiveState, content: content)
            }
        }
    }
    
    private func positionWindowsIn3DSpace(content: RealityViewContent) {
        let openWindows = windowManager.getAllWindows(onlyOpen: true)
        
        for (index, window) in openWindows.enumerated() {
            let position = calculateWindowPosition(for: index, window: window)
            
            // Create a simple representation of the window
            let windowEntity = createWindowEntity(for: window)
            windowEntity.transform.translation = position
            
            content.add(windowEntity)
            
            // Update spatial manager state
            let transform = ImmersiveWindowState.Transform3D(
                translation: position
            )
            var state = spatialManager.getImmersiveState(for: window.id)
            state.transform = transform
            spatialManager.updateImmersiveState(for: window.id, state: state)
        }
    }
    
    private func calculateWindowPosition(for index: Int, window: NewWindowID) -> SIMD3<Float> {
        // Arrange windows in a circular pattern
        let radius: Float = 3.0
        let angleStep = 2.0 * Float.pi / Float(max(1, windowManager.getAllWindows(onlyOpen: true).count))
        let angle = angleStep * Float(index)
        
        let x = radius * cos(angle)
        let z = radius * sin(angle)
        let y = Float(window.position.y) * 0.01 // Convert to reasonable scale
        
        return SIMD3<Float>(x, y, z)
    }
    
    private func createWindowEntity(for window: NewWindowID) -> ModelEntity {
        // Create a simple plane to represent the window
        let mesh = MeshResource.generatePlane(width: 0.4, depth: 0.3)
        
        var material = SimpleMaterial()
        material.color = SimpleMaterial.Color.white
        material.metallic = 0.1
        material.roughness = 0.8
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "Window_\(window.id)"
        
        return entity
    }
    
    private func updateWindowInSpace(window: NewWindowID, state: ImmersiveWindowState, content: RealityViewContent) {
        // Find the window entity and update its transform
        if let windowEntity = content.entities.first(where: { $0.name == "Window_\(window.id)" }) {
            windowEntity.transform.translation = state.transform.translation
            windowEntity.transform.rotation = state.transform.simdRotation
            windowEntity.transform.scale = state.transform.scale
            windowEntity.isEnabled = state.isVisible
        }
    }
    
    private func handleDragGesture(_ value: EntityTargetValue<DragGesture.Value>) {
        // Handle window dragging in 3D space
        if let entity = value.entity,
           let windowIDString = entity.name?.components(separatedBy: "_").last,
           let windowID = Int(windowIDString) {
            
            let translation = value.convert(value.translation3D, from: .local, to: .scene)
            entity.transform.translation += translation
            
            // Update the spatial manager state
            let newTransform = ImmersiveWindowState.Transform3D(
                translation: entity.transform.translation
            )
            var state = spatialManager.getImmersiveState(for: windowID)
            state.transform = newTransform
            state.lastInteractionTime = Date()
            spatialManager.updateImmersiveState(for: windowID, state: state)
        }
    }
}

#Preview {
    ImmersiveSpaceView()
        .environmentObject(WindowTypeManager.shared)
        .environmentObject(SpatialWindowManager.shared)
}
