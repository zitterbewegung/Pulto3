//
//  Model3DVolumetricView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import RealityKit

// MARK: - 3D Model Volumetric Window
/*
struct Model3DVolumetricView: View {
    let windowID: Int
    let modelData: Model3DData?
    @StateObject private var model = Model3DViewModel()
    @State private var rotationX: Float = 0
    @State private var rotationY: Float = 0
    @State private var scale: Float = 1.0
    @State private var wireframeMode = false
    @State private var showNormals = false
    @State private var selectedMaterial = 0
    
    var body: some View {
        GeometryReader3D { geometry in
            ZStack {
                RealityView { content, attachments in
                    // Create root entity
                    let rootEntity = Entity()
                    rootEntity.name = "Model3DRoot"
                    
                    // Add 3D model
                    if let modelData = modelData {
                        let modelEntity = await create3DModelEntity(from: modelData)
                        rootEntity.addChild(modelEntity)
                    }
                    
                    // Add lighting
                    let lightEntity = DirectionalLight()
                    lightEntity.light.intensity = 2000
                    lightEntity.position = [1, 2, 1]
                    lightEntity.look(at: [0, 0, 0], from: lightEntity.position, relativeTo: nil)
                    rootEntity.addChild(lightEntity)
                    
                    // Add ambient light
                    let ambientLight = Entity()
                    ambientLight.components.set(ImageBasedLightComponent(source: .single(.init(environmentResource: .init()))))
                    rootEntity.addChild(ambientLight)
                    
                    content.add(rootEntity)
                    model.rootEntity = rootEntity
                    
                    // Add control panel
                    if let controlPanel = attachments.entity(for: "modelControls") {
                        controlPanel.position = [0, -0.35, 0.25]
                        content.add(controlPanel)
                    }
                } update: { content, attachments in
                    // Update transformations
                    if let root = model.rootEntity {
                        let rotationQuat = simd_quatf(angle: rotationX, axis: [1, 0, 0]) *
                                          simd_quatf(angle: rotationY, axis: [0, 1, 0])
                        root.transform.rotation = rotationQuat
                        root.scale = [scale, scale, scale]
                    }
                    
                    // Update rendering mode
                    if model.needsUpdate {
                        updateRenderingMode()
                        model.needsUpdate = false
                    }
                } attachments: {
                    Attachment(id: "modelControls") {
                        VStack(spacing: 12) {
                            Text("3D Model Controls")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            // Rotation controls
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Rotate X")
                                        .foregroundColor(.white)
                                        .frame(width: 60)
                                    Slider(value: Binding(
                                        get: { Double(rotationX) },
                                        set: { rotationX = Float($0) }
                                    ), in: -Float.pi...Float.pi)
                                    .frame(width: 120)
                                }
                                
                                HStack {
                                    Text("Rotate Y")
                                        .foregroundColor(.white)
                                        .frame(width: 60)
                                    Slider(value: Binding(
                                        get: { Double(rotationY) },
                                        set: { rotationY = Float($0) }
                                    ), in: -Float.pi...Float.pi)
                                    .frame(width: 120)
                                }
                            }
                            
                            // Scale control
                            HStack {
                                Text("Scale")
                                    .foregroundColor(.white)
                                    .frame(width: 60)
                                Slider(value: $scale, in: 0.5...3.0)
                                .frame(width: 120)
                            }
                            
                            // Rendering options
                            Toggle("Wireframe", isOn: $wireframeMode)
                                .foregroundColor(.white)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                            
                            Toggle("Show Normals", isOn: $showNormals)
                                .foregroundColor(.white)
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                            
                            // Material selector
                            if let data = modelData, !data.materials.isEmpty {
                                Picker("Material", selection: $selectedMaterial) {
                                    ForEach(0..<data.materials.count, id: \.self) { index in
                                        Text(data.materials[index].name).tag(index)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .foregroundColor(.white)
                            }
                            
                            // Model info
                            if let data = modelData {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Vertices: \(data.vertices.count)")
                                    Text("Faces: \(data.faces.count)")
                                    Text("Type: \(data.modelType)")
                                }
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .onChange(of: wireframeMode) { _ in
            model.needsUpdate = true
        }
        .onChange(of: showNormals) { _ in
            model.needsUpdate = true
        }
        .onChange(of: selectedMaterial) { _ in
            model.needsUpdate = true
        }
    }
    
    @MainActor
    private func create3DModelEntity(from data: Model3DData) async -> Entity {
        let entity = Entity()
        entity.name = "3DModel"
        
        // Convert vertices to simd_float3
        let vertices = data.vertices.map { vertex in
            simd_float3(Float(vertex.x), Float(vertex.y), Float(vertex.z))
        }
        
        // Create mesh from faces
        var meshDescriptor = MeshDescriptor()
        var positions: [simd_float3] = []
        var normals: [simd_float3] = []
        var triangles: [UInt32] = []
        
        // Process faces and create triangles
        var vertexIndex: UInt32 = 0
        for face in data.faces {
            if face.vertices.count >= 3 {
                // Triangulate faces if needed
                let faceVertices = face.vertices.map { vertices[$0] }
                
                // Calculate face normal
                let v1 = faceVertices[1] - faceVertices[0]
                let v2 = faceVertices[2] - faceVertices[0]
                let normal = normalize(cross(v1, v2))
                
                // Add vertices for this face
                for i in 1..<face.vertices.count - 1 {
                    // Triangle: 0, i, i+1
                    positions.append(faceVertices[0])
                    positions.append(faceVertices[i])
                    positions.append(faceVertices[i + 1])
                    
                    normals.append(normal)
                    normals.append(normal)
                    normals.append(normal)
                    
                    triangles.append(vertexIndex)
                    triangles.append(vertexIndex + 1)
                    triangles.append(vertexIndex + 2)
                    
                    vertexIndex += 3
                }
            }
        }
        
        if !positions.isEmpty {
            meshDescriptor.positions = MeshBuffers.Positions(positions)
            meshDescriptor.normals = MeshBuffers.Normals(normals)
            meshDescriptor.primitives = .triangles(triangles)
            
            do {
                let mesh = try await MeshResource(from: meshDescriptor)
                
                // Create material
                let material: Material
                if wireframeMode {
                    var wireframeMaterial = SimpleMaterial()
                    wireframeMaterial.color = .init(tint: .white.withAlphaComponent(0.8))
                    wireframeMaterial.triangleFillMode = .lines
                    material = wireframeMaterial
                } else {
                    let selectedMat = data.materials.indices.contains(selectedMaterial) ? 
                                     data.materials[selectedMaterial] : 
                                     data.materials.first ?? Model3DData.Material3D(name: "default", color: "gray")
                    
                    var simpleMaterial = SimpleMaterial()
                    simpleMaterial.color = .init(tint: UIColor(hex: selectedMat.color) ?? .gray)
                    simpleMaterial.roughness = .init(floatLiteral: Float(selectedMat.roughness ?? 0.5))
                    simpleMaterial.metallic = .init(floatLiteral: Float(selectedMat.metallic ?? 0.1))
                    material = simpleMaterial
                }
                
                let modelEntity = ModelEntity(mesh: mesh, materials: [material])
                
                // Apply initial transformations
                modelEntity.scale = [Float(data.scale), Float(data.scale), Float(data.scale)]
                modelEntity.position = [Float(data.position.x), Float(data.position.y), Float(data.position.z)]
                
                entity.addChild(modelEntity)
                
                // Add normal visualization if enabled
                if showNormals {
                    let normalEntity = createNormalVisualization(positions: positions, normals: normals)
                    entity.addChild(normalEntity)
                }
                
            } catch {
                print("Failed to create mesh: \(error)")
            }
        }
        
        return entity
    }
    
    private func createNormalVisualization(positions: [simd_float3], normals: [simd_float3]) -> Entity {
        let entity = Entity()
        entity.name = "Normals"
        
        let normalLength: Float = 0.1
        let normalColor = UIColor.green
        
        for i in 0..<min(positions.count, normals.count) {
            let start = positions[i]
            let end = start + normals[i] * normalLength
            
            // Create line for normal
            let cylinder = MeshResource.generateCylinder(height: normalLength, radius: 0.001)
            let material = SimpleMaterial(color: normalColor, isMetallic: false)
            
            let normalEntity = ModelEntity(mesh: cylinder, materials: [material])
            normalEntity.position = (start + end) * 0.5
            
            // Orient cylinder along normal
            if simd_length(normals[i]) > 0 {
                normalEntity.look(at: end, from: start, relativeTo: nil)
            }
            
            entity.addChild(normalEntity)
        }
        
        return entity
    }
    
    private func updateRenderingMode() {
        // This would be called when wireframe or other rendering modes change
        model.needsUpdate = true
    }
}

// MARK: - View Models

class PointCloudViewModel: ObservableObject {
    @Published var rootEntity: Entity?
    @Published var boundingBox: (simd_float3, simd_float3)?
    @Published var needsUpdate = false
    @Published var colorMode: PointCloudVolumetricView.ColorMode = .intensity
    @Published var pointSize: Float = 0.005
}

class Model3DViewModel: ObservableObject {
    @Published var rootEntity: Entity?
    @Published var needsUpdate = false
}

// MARK: - Helper Extensions

extension UIColor {
    convenience init?(hex: String) {
        let r, g, b: CGFloat
        
        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])
            
            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                
                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    
                    self.init(red: r, green: g, blue: b, alpha: 1.0)
                    return
                }
            }
        }
        
        // Default color names
        switch hex.lowercased() {
        case "red": self.init(red: 1, green: 0, blue: 0, alpha: 1)
        case "green": self.init(red: 0, green: 1, blue: 0, alpha: 1)
        case "blue": self.init(red: 0, green: 0, blue: 1, alpha: 1)
        case "yellow": self.init(red: 1, green: 1, blue: 0, alpha: 1)
        case "orange": self.init(red: 1, green: 0.5, blue: 0, alpha: 1)
        case "purple": self.init(red: 0.5, green: 0, blue: 0.5, alpha: 1)
        case "cyan": self.init(red: 0, green: 1, blue: 1, alpha: 1)
        case "magenta": self.init(red: 1, green: 0, blue: 1, alpha: 1)
        case "white": self.init(red: 1, green: 1, blue: 1, alpha: 1)
        case "black": self.init(red: 0, green: 0, blue: 0, alpha: 1)
        case "gray", "grey": self.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        case "lightblue": self.init(red: 0.7, green: 0.85, blue: 1, alpha: 1)
        default: return nil
        }
    }
}
extension Model3DData {
    static func generateTestPyramid() -> Model3DData {
        let vertices = [
            Vertex3D(x: 0, y: 2, z: 0),      // apex
            Vertex3D(x: -1, y: 0, z: -1),    // base corner 1
            Vertex3D(x: 1, y: 0, z: -1),     // base corner 2
            Vertex3D(x: 1, y: 0, z: 1),      // base corner 3
            Vertex3D(x: -1, y: 0, z: 1)      // base corner 4
        ]

        let faces = [
            Face3D(vertices: [0, 1, 2], materialIndex: 0),  // front
            Face3D(vertices: [0, 2, 3], materialIndex: 0),  // right
            Face3D(vertices: [0, 3, 4], materialIndex: 0),  // back
            Face3D(vertices: [0, 4, 1], materialIndex: 0),  // left
            Face3D(vertices: [1, 2, 3, 4], materialIndex: 1) // base
        ]

        let materials = [
            Material3D(name: "pyramid_sides", color: "#FF6B6B", metallic: 0.1, roughness: 0.7),
            Material3D(name: "pyramid_base", color: "#4ECDC4", metallic: 0.0, roughness: 0.9)
        ]

        var model = Model3DData(title: "Test Pyramid", modelType: "pyramid")
        model.vertices = vertices
        model.faces = faces
        model.materials = materials

        return model
    }

    static func generateTestTorus(majorRadius: Double = 2.0, minorRadius: Double = 0.5, segments: Int = 16) -> Model3DData {
        var vertices: [Vertex3D] = []
        var faces: [Face3D] = []

        // Generate vertices
        for i in 0..<segments {
            let u = Double(i) * 2.0 * .pi / Double(segments)
            for j in 0..<segments {
                let v = Double(j) * 2.0 * .pi / Double(segments)

                let x = (majorRadius + minorRadius * cos(v)) * cos(u)
                let y = minorRadius * sin(v)
                let z = (majorRadius + minorRadius * cos(v)) * sin(u)

                vertices.append(Vertex3D(x: x, y: y, z: z))
            }
        }

        // Generate faces
        for i in 0..<segments {
            for j in 0..<segments {
                let current = i * segments + j
                let next = i * segments + (j + 1) % segments
                let currentNext = ((i + 1) % segments) * segments + j
                let nextNext = ((i + 1) % segments) * segments + (j + 1) % segments

                faces.append(Face3D(vertices: [current, next, nextNext, currentNext], materialIndex: 0))
            }
        }

        let materials = [
            Material3D(name: "torus_material", color: "#9B59B6", metallic: 0.3, roughness: 0.4)
        ]

        var model = Model3DData(title: "Test Torus", modelType: "torus")
        model.vertices = vertices
        model.faces = faces
        model.materials = materials

        return model
    }
}
*/
