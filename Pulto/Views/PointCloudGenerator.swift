import SwiftUI
import RealityKit

// MARK: - Point Cloud Data Generator
struct PointCloudGenerator {
    static func generateSpherePointCloud(radius: Float = 1.0, pointCount: Int = 1000) -> ([SIMD3<Float>], [SIMD4<Float>]) {
        var points: [SIMD3<Float>] = []
        var colors: [SIMD4<Float>] = []
        
        for _ in 0..<pointCount {
            // Generate random point on sphere surface
            let theta = Float.random(in: 0...(2 * Float.pi))
            let phi = Float.random(in: 0...Float.pi)
            
            let x = radius * sin(phi) * cos(theta)
            let y = radius * sin(phi) * sin(theta)
            let z = radius * cos(phi)
            
            points.append(SIMD3<Float>(x, y, z))
            
            // Color based on position (creates a gradient effect)
            let r = (x + radius) / (2 * radius)
            let g = (y + radius) / (2 * radius)
            let b = (z + radius) / (2 * radius)
            colors.append(SIMD4<Float>(r, g, b, 1.0))
        }
        
        return (points, colors)
    }
    
    static func generateCubePointCloud(size: Float = 2.0, pointCount: Int = 800) -> ([SIMD3<Float>], [SIMD4<Float>]) {
        var points: [SIMD3<Float>] = []
        var colors: [SIMD4<Float>] = []
        
        let halfSize = size / 2
        
        for _ in 0..<pointCount {
            let x = Float.random(in: -halfSize...halfSize)
            let y = Float.random(in: -halfSize...halfSize)
            let z = Float.random(in: -halfSize...halfSize)
            
            points.append(SIMD3<Float>(x, y, z))
            
            // Rainbow colors based on position
            let r = abs(x) / halfSize
            let g = abs(y) / halfSize
            let b = abs(z) / halfSize
            colors.append(SIMD4<Float>(r, g, b, 1.0))
        }
        
        return (points, colors)
    }
    
    static func generateHelixPointCloud(radius: Float = 1.0, height: Float = 3.0, pointCount: Int = 500) -> ([SIMD3<Float>], [SIMD4<Float>]) {
        var points: [SIMD3<Float>] = []
        var colors: [SIMD4<Float>] = []
        
        for i in 0..<pointCount {
            let t = Float(i) / Float(pointCount) * 4 * Float.pi
            let y = (Float(i) / Float(pointCount)) * height - height / 2
            
            let x = radius * cos(t)
            let z = radius * sin(t)
            
            points.append(SIMD3<Float>(x, y, z))
            
            // Color changes along the helix
            let hue = Float(i) / Float(pointCount)
            colors.append(SIMD4<Float>(hue, 1.0 - hue, 0.5, 1.0))
        }
        
        return (points, colors)
    }
}

// MARK: - Point Cloud Entity Creator
extension Entity {
    static func createPointCloud(points: [SIMD3<Float>], colors: [SIMD4<Float>]? = nil, pointSize: Float = 0.01) -> Entity {
        let entity = Entity()
        
        // Create individual sphere entities for each point (more reliable for visualization)
        for (index, point) in points.enumerated() {
            let sphereEntity = Entity()
            
            // Create a small sphere mesh for each point
            let sphereMesh = MeshResource.generateSphere(radius: pointSize)
            
            // Set color for this point
            var material = UnlitMaterial()
            if let colors = colors, index < colors.count {
                let color = colors[index]
                material.color = .init(tint: UIColor(red: CGFloat(color.x), 
                                                   green: CGFloat(color.y), 
                                                   blue: CGFloat(color.z), 
                                                   alpha: CGFloat(color.w)))
            } else {
                material.color = .init(tint: .white)
            }
            
            sphereEntity.components.set(ModelComponent(mesh: sphereMesh, materials: [material]))
            sphereEntity.position = point
            
            entity.addChild(sphereEntity)
        }
        
        return entity
    }
}

// MARK: - Point Cloud View
struct PointCloudView: View {
    let points: [SIMD3<Float>]
    let colors: [SIMD4<Float>]
    let title: String
    
    @State private var rotationAngle: Float = 0
    
    var body: some View {
        VStack {
            Text(title)
                .font(.title)
                .padding()
            
            RealityView { content in
                // Create the point cloud entity
                let pointCloudEntity = Entity.createPointCloud(points: points, colors: colors)
                
                // Add some ambient lighting
                let lightEntity = Entity()
                lightEntity.components.set(DirectionalLightComponent(
                    color: .white,
                    intensity: 1000
                ))
                lightEntity.look(at: [0, 0, 0], from: [1, 1, 1], relativeTo: nil)
                
                content.add(pointCloudEntity)
                content.add(lightEntity)
                
                // Store reference for rotation
                content.entities.first?.name = "pointCloud"
            } update: { content in
                // Rotate the point cloud
                if let pointCloud = content.entities.first(where: { $0.name == "pointCloud" }) {
                    pointCloud.transform.rotation = simd_quatf(angle: rotationAngle, axis: [0, 1, 0])
                }
            }
            .onAppear {
                startRotation()
            }
            
            HStack {
                Button("Reset Rotation") {
                    rotationAngle = 0
                }
                .padding()
                
                Button("Rotate") {
                    rotationAngle += Float.pi / 4
                }
                .padding()
            }
        }
    }
    
    private func startRotation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            rotationAngle += 0.02
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var selectedPointCloud: PointCloudType?
    
    enum PointCloudType: String, CaseIterable {
        case sphere = "Sphere"
        case cube = "Cube"
        case helix = "Helix"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Point Cloud Viewer")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Text("Select a point cloud to visualize:")
                    .font(.headline)
                
                ForEach(PointCloudType.allCases, id: \.self) { type in
                    Button(action: {
                        selectedPointCloud = type
                    }) {
                        HStack {
                            Image(systemName: iconForType(type))
                            Text(type.rawValue)
                                .font(.title2)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .sheet(item: Binding<PointCloudType?>(
            get: { selectedPointCloud },
            set: { selectedPointCloud = $0 }
        )) { type in
            pointCloudView(for: type)
        }
    }
    
    private func iconForType(_ type: PointCloudType) -> String {
        switch type {
        case .sphere: return "circle.fill"
        case .cube: return "square.fill"
        case .helix: return "tornado"
        }
    }
    
    @ViewBuilder
    private func pointCloudView(for type: PointCloudType) -> some View {
        let (points, colors) = generatePointCloudData(for: type)
        PointCloudView(points: points, colors: colors, title: "\(type.rawValue) Point Cloud")
    }
    
    private func generatePointCloudData(for type: PointCloudType) -> ([SIMD3<Float>], [SIMD4<Float>]) {
        switch type {
        case .sphere:
            return PointCloudGenerator.generateSpherePointCloud()
        case .cube:
            return PointCloudGenerator.generateCubePointCloud()
        case .helix:
            return PointCloudGenerator.generateHelixPointCloud()
        }
    }
}

// MARK: - App Entry Point
@main
struct PointCloudTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}