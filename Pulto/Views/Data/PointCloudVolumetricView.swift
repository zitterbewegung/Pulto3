//
//  PointCloudVolumetricView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/9/25.
//  Copyright 2025 Apple. All rights reserved.
//

//
//  VolumetricWindows.swift
//  UnderstandingVisionos
//
//  Volumetric windows for 3D Model and Point Cloud visualization
//

import SwiftUI
import RealityKit

// MARK: - Point Cloud Volumetric Window

struct PointCloudVolumetricView: View {
    let windowID: Int
    let pointCloudData: PointCloudData?
    @StateObject private var model = PointCloudViewModel()
    @State private var rotationAngle: Float = 0
    @State private var scale: Float = 1.0
    @State private var showBoundingBox = false
    @State private var pointSize: Float = 0.005
    @State private var colorMode: ColorMode = .intensity
    
    enum ColorMode: String, CaseIterable {
        case intensity = "Intensity"
        case height = "Height"
        case uniform = "Uniform"
        case rainbow = "Rainbow"
    }
    
    var body: some View {
        GeometryReader3D { geometry in
            ZStack {
                // Main RealityView for point cloud
                RealityView { content, attachments in
                    // Create root entity
                    let rootEntity = Entity()
                    rootEntity.name = "PointCloudRoot"
                    
                    // Add point cloud
                    if let pointCloudData = pointCloudData {
                        let pointCloudEntity = await createPointCloudEntity(from: pointCloudData)
                        rootEntity.addChild(pointCloudEntity)
                    }
                    
                    // Add lighting
                    //let lightEntity = DirectionalLight()
                    //lightEntity.light.intensity = 1000
                    //lightEntity.light.isRealWorldProxy = true
                    //lightEntity.position = [0, 2, 0]
                    //lightEntity.look(at: [0, 0, 0], from: lightEntity.position, relativeTo: nil)
                    //rootEntity.addChild(lightEntity)

                    // Add ambient light
                    let ambientLight = Entity()
                    //ambientLight.components.set(ImageBasedLightComponent(source: .single(.init(environmentResource: .init()))))
                    rootEntity.addChild(ambientLight)
                    
                    content.add(rootEntity)
                    model.rootEntity = rootEntity
                    
                    // Add control panel attachment
                    if let controlPanel = attachments.entity(for: "controls") {
                        controlPanel.position = [0, -0.3, 0.2]
                        content.add(controlPanel)
                    }
                } update: { content, attachments in
                    // Update rotation
                    if let root = model.rootEntity {
                        root.transform.rotation = simd_quatf(angle: rotationAngle, axis: [0, 1, 0])
                        root.scale = [scale, scale, scale]
                    }
                    
                    // Update point cloud if color mode changed
                    if model.needsUpdate {
                        Task {
                            if let pointCloudData = pointCloudData,
                               let root = model.rootEntity,
                               let oldPointCloud = root.children.first(where: { $0.name == "PointCloud" }) {
                                oldPointCloud.removeFromParent()
                                let newPointCloud = await createPointCloudEntity(from: pointCloudData)
                                root.addChild(newPointCloud)
                            }
                            model.needsUpdate = false
                        }
                    }
                } attachments: {
                    // Control panel attachment
                    Attachment(id: "controls") {
                        VStack(spacing: 12) {
                            Text("Point Cloud Controls")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            // Rotation control
                            HStack {
                                Text("Rotation")
                                    .foregroundColor(.white)
                                Slider(value: Binding(
                                    get: { Double(rotationAngle) },
                                    set: { rotationAngle = Float($0) }
                                ), in: 0...2 * .pi)
                                .frame(width: 150)
                            }
                            
                            // Scale control
                            HStack {
                                Text("Scale")
                                    .foregroundColor(.white)
                                Slider(value: $scale, in: 0.5...2.0)
                                .frame(width: 150)
                            }
                            
                            // Point size control
                            HStack {
                                Text("Point Size")
                                    .foregroundColor(.white)
                                Slider(value: $pointSize, in: 0.002...0.02)
                                .frame(width: 150)
                            }
                            
                            // Color mode picker
                            Picker("Color Mode", selection: $colorMode) {
                                ForEach(ColorMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 200)
                            
                            // Stats
                            if let data = pointCloudData {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Points: \(data.totalPoints)")
                                    Text("Type: \(data.demoType)")
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
                
                // Bounding box visualization
                if showBoundingBox {
                    RealityView { content in
                        if let bbox = model.boundingBox {
                            let boxEntity = createBoundingBoxEntity(bbox)
                            content.add(boxEntity)
                        }
                    }
                }
            }
        }
        .onAppear {
            model.colorMode = colorMode
        }
        .onChange(of: colorMode) { _, newValue in
            Task { @MainActor in
                model.colorMode = newValue
                model.needsUpdate = true
            }
        }
        .onChange(of: pointSize) { _, newValue in
            Task { @MainActor in
                model.pointSize = newValue
                model.needsUpdate = true
            }
        }
    }
    
    @MainActor
    private func createPointCloudEntity(from data: PointCloudData) async -> Entity {
        let entity = Entity()
        entity.name = "PointCloud"
        
        // Create mesh descriptor for points
        var meshDescriptor = MeshDescriptor()
        var positions: [simd_float3] = []
        var colors: [simd_float4] = []
        
        // Convert points to positions and colors
        for point in data.points {
            positions.append([Float(point.x), Float(point.y), Float(point.z)])
            
            // Determine color based on mode
            let color: simd_float4
            switch model.colorMode {
            case .intensity:
                let intensity = Float(point.intensity ?? 0.5)
                color = [intensity, intensity * 0.8, 1.0 - intensity, 1.0]
            case .height:
                let normalizedHeight = Float((point.y - data.points.map { $0.y }.min()!) / 
                                           (data.points.map { $0.y }.max()! - data.points.map { $0.y }.min()!))
                color = [normalizedHeight, 0.5, 1.0 - normalizedHeight, 1.0]
            case .uniform:
                color = [0.3, 0.6, 1.0, 1.0]
            case .rainbow:
                let hue = Float(point.x + point.y + point.z).truncatingRemainder(dividingBy: 1.0)
                color = hsvToRgb(h: hue, s: 0.8, v: 1.0)
            }
            colors.append(color)
        }
        
        meshDescriptor.positions = MeshBuffers.Positions(positions)
        
        // Create spheres for each point
        for i in 0..<positions.count {
            let sphereMesh = MeshResource.generateSphere(radius: model.pointSize)
            let material = SimpleMaterial(color: UIColor(red: CGFloat(colors[i].x),
                                                        green: CGFloat(colors[i].y),
                                                        blue: CGFloat(colors[i].z),
                                                        alpha: 1.0),
                                        roughness: 0.5,
                                        isMetallic: false)
            
            let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [material])
            sphereEntity.position = positions[i]
            entity.addChild(sphereEntity)
        }
        
        // Calculate and store bounding box
        if !positions.isEmpty {
            let minPoint = positions.reduce(positions[0]) { simd_min($0, $1) }
            let maxPoint = positions.reduce(positions[0]) { simd_max($0, $1) }
            model.boundingBox = (minPoint, maxPoint)
        }
        
        return entity
    }
    
    private func createBoundingBoxEntity(_ bbox: (simd_float3, simd_float3)) -> Entity {
        let entity = Entity()
        let size = bbox.1 - bbox.0
        let center = (bbox.0 + bbox.1) * 0.5
        
        let boxMesh = MeshResource.generateBox(size: size, cornerRadius: 0)
        let material = SimpleMaterial(color: .white.withAlphaComponent(0.1),
                                    roughness: 0.5,
                                    isMetallic: false)
        
        let boxEntity = ModelEntity(mesh: boxMesh, materials: [material])
        boxEntity.position = center
        entity.addChild(boxEntity)
        
        // Add wireframe edges
        let edgeMaterial = SimpleMaterial(color: .cyan, isMetallic: false)
        let edgeThickness: Float = 0.002
        
        // Create edge lines
        let edges: [(simd_float3, simd_float3)] = [
            // Bottom edges
            ([bbox.0.x, bbox.0.y, bbox.0.z], [bbox.1.x, bbox.0.y, bbox.0.z]),
            ([bbox.1.x, bbox.0.y, bbox.0.z], [bbox.1.x, bbox.0.y, bbox.1.z]),
            ([bbox.1.x, bbox.0.y, bbox.1.z], [bbox.0.x, bbox.0.y, bbox.1.z]),
            ([bbox.0.x, bbox.0.y, bbox.1.z], [bbox.0.x, bbox.0.y, bbox.0.z]),
            // Top edges
            ([bbox.0.x, bbox.1.y, bbox.0.z], [bbox.1.x, bbox.1.y, bbox.0.z]),
            ([bbox.1.x, bbox.1.y, bbox.0.z], [bbox.1.x, bbox.1.y, bbox.1.z]),
            ([bbox.1.x, bbox.1.y, bbox.1.z], [bbox.0.x, bbox.1.y, bbox.1.z]),
            ([bbox.0.x, bbox.1.y, bbox.1.z], [bbox.0.x, bbox.1.y, bbox.0.z]),
            // Vertical edges
            ([bbox.0.x, bbox.0.y, bbox.0.z], [bbox.0.x, bbox.1.y, bbox.0.z]),
            ([bbox.1.x, bbox.0.y, bbox.0.z], [bbox.1.x, bbox.1.y, bbox.0.z]),
            ([bbox.1.x, bbox.0.y, bbox.1.z], [bbox.1.x, bbox.1.y, bbox.1.z]),
            ([bbox.0.x, bbox.0.y, bbox.1.z], [bbox.0.x, bbox.1.y, bbox.1.z])
        ]
        
        for (start, end) in edges {
            let direction = end - start
            let length = simd_length(direction)
            let midpoint = (start + end) * 0.5
            
            let cylinder = MeshResource.generateCylinder(height: length, radius: edgeThickness)
            let edgeEntity = ModelEntity(mesh: cylinder, materials: [edgeMaterial])
            edgeEntity.position = midpoint
            
            // Orient cylinder along the edge
            if length > 0 {
                let normalizedDir = normalize(direction)
                let up = simd_float3(0, 1, 0)
                if abs(dot(normalizedDir, up)) < 0.999 {
                    edgeEntity.look(at: midpoint + normalizedDir, from: midpoint, relativeTo: nil)
                }
            }
            
            entity.addChild(edgeEntity)
        }
        
        return entity
    }
    
    private func hsvToRgb(h: Float, s: Float, v: Float) -> simd_float4 {
        let c = v * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        
        let rgb: simd_float3
        if h < 1.0/6.0 {
            rgb = [c, x, 0]
        } else if h < 2.0/6.0 {
            rgb = [x, c, 0]
        } else if h < 3.0/6.0 {
            rgb = [0, c, x]
        } else if h < 4.0/6.0 {
            rgb = [0, x, c]
        } else if h < 5.0/6.0 {
            rgb = [x, 0, c]
        } else {
            rgb = [c, 0, x]
        }
        
        return simd_float4(rgb + m, 1.0)
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
        case "teal": self.init(red: 0, green: 0.5, blue: 0.5, alpha: 1)
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