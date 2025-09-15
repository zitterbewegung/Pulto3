import SwiftUI
import RealityKit

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// A reusable 3D point cloud renderer with pinch (zoom), rotate, and drag gestures.
/// - On visionOS, uses RealityView in a volumetric space.
/// - On iOS/macOS, uses RealityKit's ARView as a simple 3D container.
public struct PointCloudRendererView: View {
    private let points: [SIMD3<Float>]
    private let pointRadius: Float

    // Gesture states
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Angle = .zero // around Y axis
    @State private var translation: CGSize = .zero

    public init(points: [SIMD3<Float>]? = nil, pointRadius: Float = 0.003) {
        self.points = points ?? PointCloudRendererView.generateDemoPoints(count: 2000)
        self.pointRadius = pointRadius
    }

    public var body: some View {
        GeometryReader { geo in
            RendererContainer(points: points, pointRadius: pointRadius, scale: scale, rotation: rotation, translation: translation)
                .gesture(dragGesture)
                .gesture(rotationGesture)
                .gesture(pinchGesture)
                .background(Color.clear)
        }
    }

    // MARK: - Gestures

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(0.1, min(10.0, value))
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { angle in
                rotation = angle
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                translation = value.translation
            }
    }

    // MARK: - Demo point generator

    /// Generate a simple random point cloud shaped roughly like a sphere.
    static func generateDemoPoints(count: Int) -> [SIMD3<Float>] {
        var pts: [SIMD3<Float>] = []
        pts.reserveCapacity(count)
        for _ in 0..<count {
            // random point within unit sphere
            var p: SIMD3<Float>
            repeat {
                p = SIMD3<Float>(Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: -1...1))
            } while length(p) > 1
            pts.append(p)
        }
        return pts
    }
}

// MARK: - Cross-platform container

fileprivate struct RendererContainer: View {
    let points: [SIMD3<Float>]
    let pointRadius: Float
    let scale: CGFloat
    let rotation: Angle
    let translation: CGSize

    var body: some View {
        #if os(visionOS)
        VisionOSRealityView(points: points, pointRadius: pointRadius, scale: scale, rotation: rotation, translation: translation)
        #elseif os(macOS)
        ARViewContainer_macOS(points: points, pointRadius: pointRadius, scale: scale, rotation: rotation, translation: translation)
        #else
        ARViewContainer(points: points, pointRadius: pointRadius, scale: scale, rotation: rotation, translation: translation)
        #endif
    }
}

// MARK: - visionOS RealityView implementation

#if os(visionOS)
import RealityKit

fileprivate struct VisionOSRealityView: View {
    let points: [SIMD3<Float>]
    let pointRadius: Float
    let scale: CGFloat
    let rotation: Angle
    let translation: CGSize

    @State private var scene: PointCloudScene = PointCloudScene()

    var body: some View {
        RealityView { content in
            // Setup once
            if scene.root.parent == nil {
                scene.build(points: points, pointRadius: pointRadius)
                content.add(scene.root)
            }
        } update: { _ in
            scene.applyControls(scale: Float(scale), rotationRadians: Float(rotation.radians), translation: translation)
        }
    }
}
#endif

// MARK: - iOS/macOS ARView container

#if os(iOS)
fileprivate struct ARViewContainer: UIViewRepresentable {
    let points: [SIMD3<Float>]
    let pointRadius: Float
    let scale: CGFloat
    let rotation: Angle
    let translation: CGSize

    class Coordinator {
        let scene = PointCloudScene()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        // No AR tracking needed; use a simple non-AR scene
        view.environment.background = .color(.black)

        context.coordinator.scene.build(points: points, pointRadius: pointRadius)
        view.scene.anchors.append(context.coordinator.scene.root)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.scene.applyControls(scale: Float(scale), rotationRadians: Float(rotation.radians), translation: translation)
    }
}
#endif

#if os(macOS)
fileprivate struct ARViewContainer_macOS: NSViewRepresentable {
    let points: [SIMD3<Float>]
    let pointRadius: Float
    let scale: CGFloat
    let rotation: Angle
    let translation: CGSize

    class Coordinator {
        let scene = PointCloudScene()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let arView = ARView(frame: .zero)
        arView.environment.background = .color(.black)
        arView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(arView)
        NSLayoutConstraint.activate([
            arView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            arView.topAnchor.constraint(equalTo: container.topAnchor),
            arView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        context.coordinator.scene.build(points: points, pointRadius: pointRadius)
        arView.scene.anchors.append(context.coordinator.scene.root)
        container.setValue(arView, forKey: "arView")
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let arView = nsView.value(forKey: "arView") as? ARView {
            context.coordinator.scene.applyControls(scale: Float(scale), rotationRadians: Float(rotation.radians), translation: translation)
        }
    }
}
#endif

// MARK: - Shared RealityKit scene builder

fileprivate final class PointCloudScene {
    let root = AnchorEntity(world: .zero)
    private let container = Entity()

    // Cached mesh for point instances
    private var pointMesh: MeshResource?
    private var pointMaterial: SimpleMaterial = SimpleMaterial(color: .white, isMetallic: false)

    // Keep a reference to the model entity used for instancing (fallback: many children)
    private var pointEntities: [Entity] = []

    func build(points: [SIMD3<Float>], pointRadius: Float) {
        root.addChild(container)
        pointMesh = try? MeshResource.generateSphere(radius: pointRadius)
        pointMaterial = SimpleMaterial(color: .white, roughness: 0.4, isMetallic: false)

        // Center the cloud by subtracting mean
        let centroid = points.reduce(SIMD3<Float>(repeating: 0), +) / Float(max(points.count, 1))
        let centered = points.map { $0 - centroid }

        // Add each point as a very small sphere entity.
        // Note: For very large clouds, consider batching/instancing techniques.
        for p in centered {
            let model = ModelEntity(mesh: pointMesh ?? MeshResource.generateSphere(radius: pointRadius), materials: [pointMaterial])
            model.position = p
            pointEntities.append(model)
            container.addChild(model)
        }

        // Add a soft directional light to improve depth perception
        let lightEntity = Entity()
        var light = DirectionalLightComponent()
        light.intensity = 2000
        lightEntity.components.set(light)
        // Aim the light slightly downward toward -Z
        lightEntity.orientation = simd_quatf(angle: .pi / 6, axis: [1, 0, 0])
        root.addChild(lightEntity)
    }

    func applyControls(scale: Float, rotationRadians: Float, translation: CGSize) {
        // Apply uniform scale
        container.transform.scale = SIMD3<Float>(repeating: max(0.01, min(100.0, scale)))

        // Rotate around Y axis
        container.transform.rotation = simd_quatf(angle: rotationRadians, axis: [0, 1, 0])

        // Translate in X/Y plane; map points to meters (tune factor)
        let factor: Float = 0.002
        container.transform.translation.x = Float(translation.width) * factor
        container.transform.translation.y = Float(-translation.height) * factor
    }
}

// MARK: - Preview

#Preview("Point Cloud Renderer") {
    PointCloudRendererView()
        .frame(width: 600, height: 400)
        .background(.black)
}

