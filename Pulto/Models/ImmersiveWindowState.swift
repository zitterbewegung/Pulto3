//
//  ImmersiveWindowState.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//


//
//  Supporting Components for Volumetric Model Integration
//  Add these extensions and components to your project
//
/*
import SwiftUI
import RealityKit
import Foundation

// MARK: - Model3DData Extensions
extension Model3DData {
    // Generate procedural models
    static func generateCylinder(radius: Float, height: Float, segments: Int) -> Model3DData {
        var vertices: [Vertex3D] = []
        var faces: [Face3D] = []
        
        // Generate cylinder vertices (simplified)
        for i in 0...segments {
            let angle = Float(i) * 2.0 * .pi / Float(segments)
            let x = radius * cos(angle)
            let z = radius * sin(angle)
            
            // Bottom vertex
            vertices.append(Vertex3D(x: Double(x), y: 0, z: Double(z)))
            // Top vertex
            vertices.append(Vertex3D(x: Double(x), y: Double(height), z: Double(z)))
        }
        
        // Generate faces (simplified)
        for i in 0..<segments {
            let current = i * 2
            let next = ((i + 1) % segments) * 2
            
            // Side face
            faces.append(Face3D(vertices: [current, current + 1, next + 1, next], materialIndex: 0))
        }
        
        let materials = [
            Material3D(name: "cylinder", color: "green", metallic: 0.3, roughness: 0.2, transparency: 0.0)
        ]
        
        return Model3DData(
            title: "Generated Cylinder",
            modelType: "procedural",
            vertices: vertices,
            faces: faces,
            materials: materials
        )
    }
    
    static func generateTorus(majorRadius: Float, minorRadius: Float, segments: Int) -> Model3DData {
        var vertices: [Vertex3D] = []
        var faces: [Face3D] = []
        
        // Generate torus vertices (simplified)
        for i in 0..<segments {
            let u = Float(i) * 2.0 * .pi / Float(segments)
            for j in 0..<segments {
                let v = Float(j) * 2.0 * .pi / Float(segments)
                
                let x = (majorRadius + minorRadius * cos(v)) * cos(u)
                let y = minorRadius * sin(v)
                let z = (majorRadius + minorRadius * cos(v)) * sin(u)
                
                vertices.append(Vertex3D(x: Double(x), y: Double(y), z: Double(z)))
            }
        }
        
        // Generate faces (simplified)
        for i in 0..<segments {
            for j in 0..<segments {
                let current = i * segments + j
                let next = ((i + 1) % segments) * segments + j
                let currentNext = i * segments + ((j + 1) % segments)
                let nextNext = ((i + 1) % segments) * segments + ((j + 1) % segments)
                
                faces.append(Face3D(vertices: [current, next, nextNext, currentNext], materialIndex: 0))
            }
        }
        
        let materials = [
            Material3D(name: "torus", color: "purple", metallic: 0.4, roughness: 0.1, transparency: 0.0)
        ]
        
        return Model3DData(
            title: "Generated Torus",
            modelType: "procedural",
            vertices: vertices,
            faces: faces,
            materials: materials
        )
    }
    
    // Python code generation
    func toPythonCode() -> String {
        return """
        # 3D Model: \(title)
        # Type: \(modelType)
        # Generated from VisionOS Pulto
        
        import numpy as np
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d import Axes3D
        from mpl_toolkits.mplot3d.art3d import Poly3DCollection
        import plotly.graph_objects as go
        
        # Model data
        model_title = "\(title)"
        model_type = "\(modelType)"
        
        # Vertices
        vertices = np.array([
        \(vertices.map { "    [\($0.x), \($0.y), \($0.z)]" }.joined(separator: ",\n"))
        ])
        
        # Faces
        faces = [
        \(faces.map { "    \($0.vertices)" }.joined(separator: ",\n"))
        ]
        
        # Create 3D visualization
        fig = plt.figure(figsize=(12, 9))
        ax = fig.add_subplot(111, projection='3d')
        
        # Plot vertices
        if len(vertices) > 0:
            ax.scatter(vertices[:, 0], vertices[:, 1], vertices[:, 2], 
                      c='blue', s=20, alpha=0.6)
        
        # Plot faces if available
        if len(faces) > 0:
            for face in faces:
                if len(face) >= 3:
                    face_vertices = vertices[face[:3]]  # Take first 3 vertices for triangle
                    triangle = [[face_vertices[0], face_vertices[1], face_vertices[2]]]
                    ax.add_collection3d(Poly3DCollection(triangle, alpha=0.7, facecolor='cyan', edgecolor='black'))
        
        ax.set_xlabel('X')
        ax.set_ylabel('Y')
        ax.set_zlabel('Z')
        ax.set_title(f'3D Model: {model_title}')
        
        # Set equal aspect ratio
        max_range = np.array([vertices[:, 0].max()-vertices[:, 0].min(),
                             vertices[:, 1].max()-vertices[:, 1].min(),
                             vertices[:, 2].max()-vertices[:, 2].min()]).max() / 2.0
        mid_x = (vertices[:, 0].max()+vertices[:, 0].min()) * 0.5
        mid_y = (vertices[:, 1].max()+vertices[:, 1].min()) * 0.5
        mid_z = (vertices[:, 2].max()+vertices[:, 2].min()) * 0.5
        ax.set_xlim(mid_x - max_range, mid_x + max_range)
        ax.set_ylim(mid_y - max_range, mid_y + max_range)
        ax.set_zlim(mid_z - max_range, mid_z + max_range)
        
        plt.show()
        
        # Interactive Plotly visualization
        fig_plotly = go.Figure()
        
        # Add vertices
        fig_plotly.add_trace(go.Scatter3d(
            x=vertices[:, 0], y=vertices[:, 1], z=vertices[:, 2],
            mode='markers',
            marker=dict(size=3, color='blue'),
            name='Vertices'
        ))
        
        # Add faces (simplified)
        for i, face in enumerate(faces):
            if len(face) >= 3:
                face_vertices = vertices[face[:3]]
                fig_plotly.add_trace(go.Mesh3d(
                    x=face_vertices[:, 0], y=face_vertices[:, 1], z=face_vertices[:, 2],
                    opacity=0.7,
                    name=f'Face {i}'
                ))
        
        fig_plotly.update_layout(
            title=f'Interactive 3D Model: {model_title}',
            scene=dict(
                xaxis_title='X',
                yaxis_title='Y',
                zaxis_title='Z',
                aspectmode='cube'
            )
        )
        
        fig_plotly.show()
        
        print(f"Model '{model_title}' - Type: {model_type}")
        print(f"Vertices: {len(vertices)}, Faces: {len(faces)}")
        """
    }
}

// MARK: - WindowTypeManager Extensions
extension WindowTypeManager {
    func generateNewWindowID() -> Int {
        let currentMaxID = windows.keys.max() ?? 0
        return currentMaxID + 1
    }
    
    func updateWindowModel3DData(_ id: Int, model3DData: Model3DData) {
        windows[id]?.state.model3DData = model3DData
        windows[id]?.state.lastModified = Date()
        
        // Auto-set template to custom if not already set
        if let window = windows[id], window.windowType == .model3d && window.state.exportTemplate == .plain {
            windows[id]?.state.exportTemplate = .custom
        }
    }
    
    func getWindowModel3DData(for id: Int) -> Model3DData? {
        return windows[id]?.state.model3DData
    }
    
    func getWindowSafely(for id: Int) -> NewWindowID? {
        return windows[id]
    }
}

// MARK: - ImmersiveWindowState for spatial management
struct ImmersiveWindowState {
    var isVisible: Bool = false
    var transform: Transform3D = Transform3D()
    var lastInteractionTime: Date = Date()
    var scale: Float = 1.0
    var opacity: Float = 1.0
    
    struct Transform3D {
        var translation: SIMD3<Float> = [0, 0, -1]
        var rotation: SIMD4<Float> = [0, 0, 0, 1] // quaternion
        var scale: SIMD3<Float> = [1, 1, 1]
        
        var simdRotation: simd_quatf {
            return simd_quatf(ix: rotation.x, iy: rotation.y, iz: rotation.z, r: rotation.w)
        }
    }
}

// MARK: - SpatialWindowManager Extension
extension SpatialWindowManager {
    func getImmersiveState(for windowID: Int) -> ImmersiveWindowState {
        return ImmersiveWindowState()
    }
    
    func updateImmersiveState(for windowID: Int, state: ImmersiveWindowState) {
        // Store the state - implementation depends on your SpatialWindowManager
    }
}

*/
