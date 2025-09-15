//
//  PointCloudVolumetricView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import RealityKit

#if canImport(MetalKit)
import MetalKit
#endif

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
    
    @State private var progressiveLoading: Bool = true
    @State private var lodQuality: LODQuality = .medium
    @State private var maxPointsPerBatch: Int = 5000
    @State private var displayedPointCount: Int = 0

    @State private var useInstancedRenderer: Bool = true
    
    enum ColorMode: String, CaseIterable {
        case intensity = "Intensity"
        case height = "Height"
        case uniform = "Uniform"
        case rainbow = "Rainbow"
    }
    
    enum LODQuality: String, CaseIterable {
        case low, medium, high, ultra

        var subsampleStep: Int {
            switch self {
            case .low: return 8
            case .medium: return 4
            case .high: return 2
            case .ultra: return 1
            }
        }
    }
    
    var body: some View {
        GeometryReader3D { geometry in
            ZStack {
                if useInstancedRenderer, let data = pointCloudData {
#if canImport(MetalKit)
    // High-performance instanced Metal renderer path (renderer file must be in target)
    // If InstancedPointCloudView is not yet linked in this target, use a placeholder to avoid build errors.
    // Replace `Color.clear` with `InstancedPointCloudView(points: data.points, pointSize: model.pointSize)` when available.
    Color.clear
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            Text(data.title)
                .font(.headline)
                .padding(8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding()
        }
#else
    // Fallback if MetalKit is unavailable
    Text("Instanced renderer unavailable on this platform")
        .font(.headline)
        .padding()
#endif
                } else {
                    // Fallback RealityKit path (existing content)
                    RealityView { content, attachments in
                        let rootEntity = Entity()
                        rootEntity.name = "PointCloudRoot"

                        if let pointCloudData = pointCloudData {
                            let pointCloudEntity = await createPointCloudEntity(from: pointCloudData)
                            rootEntity.addChild(pointCloudEntity)
                        }
                        content.add(rootEntity)
                        model.rootEntity = rootEntity

                        if let controlPanel = attachments.entity(for: "controls") {
                            controlPanel.position = [0, -0.3, 0.2]
                            content.add(controlPanel)
                        }
                    } update: { content, attachments in
                        if let root = model.rootEntity {
                            root.transform.rotation = simd_quatf(angle: rotationAngle, axis: [0, 1, 0])
                            root.scale = [scale, scale, scale]
                        }
                        if model.needsUpdate {
                            Task { @MainActor in
                                if let data = pointCloudData, let root = model.rootEntity {
                                    root.children.filter { $0.name.hasPrefix("PointCloud") || $0.name.hasPrefix("Batch_") }
                                        .forEach { $0.removeFromParent() }
                                    let newPointCloud = await createPointCloudEntity(from: data)
                                    root.addChild(newPointCloud)
                                }
                                model.needsUpdate = false
                            }
                        }
                    } attachments: {
                        Attachment(id: "controls") {
                            EmptyView()
                        }
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
            model.colorMode = newValue
            model.needsUpdate = true
        }
        .onChange(of: pointSize) { _, newValue in
            model.pointSize = newValue
            model.needsUpdate = true
        }
        // Control panel update to include new toggle
        .background(
            VStack {
                Spacer()
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
                    
                    // LOD Quality
                    Picker("LOD", selection: $lodQuality) {
                        ForEach(LODQuality.allCases, id: \.self) { q in
                            Text(q.rawValue.capitalized).tag(q)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 200)
                    .onChange(of: lodQuality) { _, _ in
                        model.needsUpdate = true
                    }
                    
                    // Progressive Loading toggle
                    Toggle("Progressive", isOn: $progressiveLoading)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .frame(width: 200)
                        .onChange(of: progressiveLoading) { _, _ in
                            model.needsUpdate = true
                        }

                    // Instanced Renderer toggle
                    Toggle("Instanced Renderer", isOn: $useInstancedRenderer)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .frame(width: 200)
                    
                    // Displayed points indicator
                    if displayedPointCount > 0 {
                        Text("Shown: \(displayedPointCount) / \(pointCloudData?.totalPoints ?? 0)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
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
                .padding()
            }
        )
    }
    
    @MainActor
    private func createPointCloudEntity(from data: PointCloudData) async -> Entity {
        let entity = Entity()
        entity.name = "PointCloud"

        // Prepare positions and colors with LOD subsampling
        let step = max(1, lodQuality.subsampleStep)
        let sourcePoints = data.points
        let sampledCount = (sourcePoints.count + step - 1) / step
        var positions: [simd_float3] = []
        positions.reserveCapacity(sampledCount)
        var colors: [simd_float4] = []
        colors.reserveCapacity(sampledCount)

        // Precompute min/max for height mode once
        let minY = sourcePoints.map { $0.y }.min() ?? 0
        let maxY = sourcePoints.map { $0.y }.max() ?? 1
        let yRange = max(0.0001, maxY - minY)

        for idx in stride(from: 0, to: sourcePoints.count, by: step) {
            let p = sourcePoints[idx]
            positions.append([Float(p.x), Float(p.y), Float(p.z)])

            // Determine color based on mode
            let color: simd_float4
            switch model.colorMode {
            case .intensity:
                let intensity = Float(p.intensity ?? 0.5)
                color = [intensity, intensity * 0.8, 1.0 - intensity, 1.0]
            case .height:
                let normalizedHeight = Float((p.y - minY) / yRange)
                color = [normalizedHeight, 0.5, 1.0 - normalizedHeight, 1.0]
            case .uniform:
                color = [0.3, 0.6, 1.0, 1.0]
            case .rainbow:
                let hue = Float((p.x + p.y + p.z).truncatingRemainder(dividingBy: 1.0))
                color = hsvToRgb(h: hue, s: 0.8, v: 1.0)
            }
            colors.append(color)
        }

        // Reset displayed count
        displayedPointCount = 0

        // Progressive batching
        let batchSize = max(1000, min(maxPointsPerBatch, positions.count))
        let totalBatches = Int(ceil(Double(positions.count) / Double(batchSize)))

        for batchIndex in 0..<totalBatches {
            let start = batchIndex * batchSize
            let end = min(start + batchSize, positions.count)
            if start >= end { break }

            let batchEntity = Entity()
            batchEntity.name = "Batch_\(batchIndex)"

            // Create spheres for this batch (shared mesh to reduce allocations)
            let sphereMesh = MeshResource.generateSphere(radius: model.pointSize)

            for i in start..<end {
                let material = SimpleMaterial(
                    color: UIColor(
                        red: CGFloat(colors[i].x),
                        green: CGFloat(colors[i].y),
                        blue: CGFloat(colors[i].z),
                        alpha: 1.0
                    ),
                    roughness: 0.5,
                    isMetallic: false
                )
                let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [material])
                sphereEntity.position = positions[i]
                batchEntity.addChild(sphereEntity)
            }

            entity.addChild(batchEntity)
            displayedPointCount = end

            if progressiveLoading && batchIndex < totalBatches - 1 {
                // Yield to allow UI to update progressively
                try? await Task.sleep(nanoseconds: 15_000_000) // ~15ms between batches
            }
        }

        // Calculate and store bounding box once for the sampled set
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

