//
//  ImmersiveWorkspaceView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//
import SwiftUI
import RealityKit

struct ImmersiveWorkspaceView: View {
    @EnvironmentObject var windowTypeManager: WindowTypeManager
    
    var body: some View {
        RealityView { content in
            // Create an immersive environment for working with multiple windows
            let rootEntity = Entity()
            
            // Add environment lighting
            let lightEntity = DirectionalLight()
            lightEntity.light.intensity = 3000
            lightEntity.position = [0, 5, 0]
            lightEntity.look(at: [0, 0, 0], from: lightEntity.position, relativeTo: nil)
            rootEntity.addChild(lightEntity)
            
            // Add floor grid
            let floorEntity = createFloorGrid()
            rootEntity.addChild(floorEntity)
            
            content.add(rootEntity)
        }
    }
    
    private func createFloorGrid() -> Entity {
        let entity = Entity()
        let gridSize: Float = 10.0
        let gridSpacing: Float = 1.0
        let lineThickness: Float = 0.01
        
        let material = SimpleMaterial(color: .white.withAlphaComponent(0.3), isMetallic: false)
        
        // Create grid lines
        for i in -Int(gridSize)...Int(gridSize) {
            // X-direction lines
            let xLine = MeshResource.generateBox(
                size: [gridSize * 2, lineThickness, lineThickness],
                cornerRadius: 0
            )
            let xEntity = ModelEntity(mesh: xLine, materials: [material])
            xEntity.position = [0, 0, Float(i) * gridSpacing]
            entity.addChild(xEntity)
            
            // Z-direction lines
            let zLine = MeshResource.generateBox(
                size: [lineThickness, lineThickness, gridSize * 2],
                cornerRadius: 0
            )
            let zEntity = ModelEntity(mesh: zLine, materials: [material])
            zEntity.position = [Float(i) * gridSpacing, 0, 0]
            entity.addChild(zEntity)
        }
        
        entity.position.y = -1.5
        return entity
    }
}
