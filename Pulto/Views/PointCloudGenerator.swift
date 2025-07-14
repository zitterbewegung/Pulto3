/*
import SwiftUI
import RealityKit

// MARK: - Point Cloud Data Generator
struct PointCloudGenerator {
    static func generateSpherePointCloud(radius: Float = 0.5, pointCount: Int = 200) -> ([SIMD3<Float>], [SIMD4<Float>]) {
        var points: [SIMD3<Float>] = []
        var colors: [SIMD4<Float>] = []

        for i in 0..<pointCount {
            // Generate random point on sphere surface
            let theta = Float.random(in: 0...(2 * Float.pi))
            let phi = Float.random(in: 0...Float.pi)

            let x = radius * sin(phi) * cos(theta)
            let y = radius * sin(phi) * sin(theta)
            let z = radius * cos(phi)

            points.append(SIMD3<Float>(x, y, z))

            // Bright colors for visibility
            let hue = Float(i) / Float(pointCount)
            let r = abs(sin(hue * 2 * Float.pi))
            let g = abs(sin(hue * 2 * Float.pi + 2))
            let b = abs(sin(hue * 2 * Float.pi + 4))
            colors.append(SIMD4<Float>(r, g, b, 1.0))
        }

        return (points, colors)
    }

    static func generateCubePointCloud(size: Float = 1.0, pointCount: Int = 150) -> ([SIMD3<Float>], [SIMD4<Float>]) {
        var points: [SIMD3<Float>] = []
        var colors: [SIMD4<Float>] = []

        let halfSize = size / 2

        for i in 0..<pointCount {
            let x = Float.random(in: -halfSize...halfSize)
            let y = Float.random(in: -halfSize...halfSize)
            let z = Float.random(in: -halfSize...halfSize)

            points.append(SIMD3<Float>(x, y, z))

            // Bright rainbow colors
            let hue = Float(i) / Float(pointCount)
            colors.append(SIMD4<Float>(
                abs(sin(hue * 6)),
                abs(cos(hue * 6)),
                abs(sin(hue * 6 + Float.pi)),
                1.0
            ))
        }

        return (points, colors)
    }

    static func generateHelixPointCloud(radius: Float = 0.3, height: Float = 1.0, pointCount: Int = 100) -> ([SIMD3<Float>], [SIMD4<Float>]) {
        var points: [SIMD3<Float>] = []
        var colors: [SIMD4<Float>] = []

        for i in 0..<pointCount {
            let t = Float(i) / Float(pointCount) * 6 * Float.pi
            let y = (Float(i) / Float(pointCount)) * height - height / 2

            let x = radius * cos(t)
            let z = radius * sin(t)

            points.append(SIMD3<Float>(x, y, z))

            // Color transition along the helix
            let progress = Float(i) / Float(pointCount)
            colors.append(SIMD4<Float>(
                1.0 - progress,  // Red to black
                progress,        // Black to green
                abs(sin(progress * 4 * Float.pi)), // Oscillating blue
                1.0
            ))
        }

        return (points, colors)
    }
}

// MARK: - Point Cloud Entity Creator
extension Entity {
    static func createPointCloud(points: [SIMD3<Float>], colors: [SIMD4<Float>]? = nil, pointSize: Float = 0.02) -> Entity {
        let entity = Entity()

        // Create individual sphere entities for each point with larger, more visible size
        for (index, point) in points.enumerated() {
            let sphereEntity = Entity()

            // Create a larger sphere mesh for each point
            let sphereMesh = MeshResource.generateSphere(radius: pointSize)

            // Set color for this point with higher intensity
            var material = UnlitMaterial()
            if let colors = colors, index < colors.count {
                let color = colors[index]
                material.color = .init(tint: UIColor(red: CGFloat(color.x),
                                                   green: CGFloat(color.y),
                                                   blue: CGFloat(color.z),
                                                   alpha: 1.0))
            } else {
                material.color = .init(tint: .cyan)
            }

            // Make sure the material is bright enough to see
            material.blending = .transparent(opacity: 1.0)

            sphereEntity.components.set(ModelComponent(mesh: sphereMesh, materials: [material]))
            sphereEntity.position = point

            entity.addChild(sphereEntity)
        }

        return entity
    }

    // Alternative method using instanced rendering for better performance
    static func createInstancedPointCloud(points: [SIMD3<Float>], colors: [SIMD4<Float>]? = nil, pointSize: Float = 0.025) -> Entity {
        let entity = Entity()

        // Create a single sphere mesh to instance
        let sphereMesh = MeshResource.generateSphere(radius: pointSize)
        var material = UnlitMaterial(color: .cyan)
        material.blending = .transparent(opacity: 0.8)

        // Create instances for better performance with large point counts
        for (index, point) in points.enumerated() {
            let instanceEntity = Entity()

            if let colors = colors, index < colors.count {
                let color = colors[index]
                var instanceMaterial = UnlitMaterial()
                instanceMaterial.color = .init(tint: UIColor(red: CGFloat(color.x),
                                                           green: CGFloat(color.y),
                                                           blue: CGFloat(color.z),
                                                           alpha: 1.0))
                instanceMaterial.blending = .transparent(opacity: 0.9)
                instanceEntity.components.set(ModelComponent(mesh: sphereMesh, materials: [instanceMaterial]))
            } else {
                instanceEntity.components.set(ModelComponent(mesh: sphereMesh, materials: [material]))
            }

            instanceEntity.position = point
            entity.addChild(instanceEntity)
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
    @State private var pointCloudEntity: Entity?

    var body: some View {
        VStack {
            Text(title)
                .font(.title)
                .padding()

            Text("Points: \(points.count)")
                .font(.caption)
                .foregroundColor(.secondary)

            RealityView { content in
                // Create the point cloud entity with larger, more visible points
                let pointCloud = Entity.createInstancedPointCloud(points: points, colors: colors, pointSize: 0.03)
                pointCloud.name = "pointCloud"

                // Position the point cloud in front of the user
                pointCloud.position = [0, 0, -2]

                // Add lighting to make points more visible
                //let ambientLight = Entity()
                //var ambientLightComponent = AmbientLightComponent()
                //ambientLightComponent.color = .white
                //ambientLightComponent.intensity = 1000
                //ambientLight.components.set(ambientLightComponent)

                let directionalLight = Entity()
                var directionalLightComponent = DirectionalLightComponent()
                directionalLightComponent.color = .white
                directionalLightComponent.intensity = 2000
                directionalLight.components.set(directionalLightComponent)
                directionalLight.look(at: [0, 0, -2], from: [1, 1, 0], relativeTo: nil)

                content.add(pointCloud)
                //content.add(ambientLight)
                content.add(directionalLight)

                pointCloudEntity = pointCloud
            } update: { content in
                // Apply rotation
                pointCloudEntity?.transform.rotation = simd_quatf(angle: rotationAngle, axis: [0, 1, 0])
            }
            .frame(height: 400)
            .onAppear {
                print("Point cloud view appeared with \(points.count) points")
                startRotation()
            }

            HStack {
                Button("Reset") {
                    rotationAngle = 0
                }
                .padding()

                Button("Rotate 45°") {
                    rotationAngle += Float.pi / 4
                }
                .padding()

                Button("Stop/Start") {
                    // Toggle rotation - you could implement this with a timer state
                }
                .padding()
            }
        }
        .padding()
    }

    private func startRotation() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            rotationAngle += 0.01
        }
    }
}

// MARK: - Main Content View (Use this in your existing app)
struct PointCloudContentView: View {
    @State private var selectedPointCloud: PointCloudType?

    enum PointCloudType: String, CaseIterable, Identifiable {
        case sphere = "Sphere"
        case cube = "Cube"
        case helix = "Helix"

        var id: String { self.rawValue }
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
        .sheet(item: $selectedPointCloud) { type in
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

// MARK: - Preview (for development)
#Preview {
    PointCloudContentView()
}
*/
