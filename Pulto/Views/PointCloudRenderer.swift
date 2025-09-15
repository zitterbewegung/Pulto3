import SwiftUI
import simd
import Foundation

#if canImport(RealityKit) && os(visionOS)
import RealityKit
#else
import SceneKit
#endif

public struct LegacyPointCloudRendererView: View {
    @State private var points: [SIMD3<Float>] = []

    // MARK: - Initializers

    /// Initialize with points directly
    public init(points: [SIMD3<Float>]) {
        _points = State(initialValue: points)
    }

    /// Initialize with a file URL pointing to a supported point cloud file
    public init(fileURL: URL) {
        let loadedPoints = LegacyPointCloudRendererView.parsePointCloud(fileURL: fileURL)
        _points = State(initialValue: loadedPoints)
    }

    // MARK: - Body

    public var body: some View {
        if points.isEmpty {
            Text("No points to display")
        } else {
            #if canImport(RealityKit) && os(visionOS)
            RealityKitPointCloudView(points: downsample(points, maxCount: 5_000))
                .edgesIgnoringSafeArea(.all)
            #else
            SceneKitPointCloudView(points: downsample(points, maxCount: 5_000))
                .edgesIgnoringSafeArea(.all)
            #endif
        }
    }

    // MARK: - Helpers

    private func downsample(_ points: [SIMD3<Float>], maxCount: Int) -> [SIMD3<Float>] {
        guard points.count > maxCount else { return points }
        let step = points.count / maxCount
        return stride(from: 0, to: points.count, by: step).map { points[$0] }
    }

    /// Parses a point cloud file of supported format to an array of SIMD3<Float>
    /// Supported formats: xyz, pts, ply (ASCII), pcd (ASCII Data)
    public static func parsePointCloud(fileURL: URL) -> [SIMD3<Float>] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }
        let ext = fileURL.pathExtension.lowercased()
        switch ext {
        case "xyz", "pts":
            return parseXYZorPTS(content: content)
        case "ply":
            return parsePLY(content: content)
        case "pcd":
            return parsePCD(content: content)
        default:
            return []
        }
    }

    private static func parseXYZorPTS(content: String) -> [SIMD3<Float>] {
        var points = [SIMD3<Float>]()
        for line in content.components(separatedBy: .newlines) {
            let comps = line.split(whereSeparator: { $0.isWhitespace })
            if comps.count >= 3,
               let x = Float(comps[0]),
               let y = Float(comps[1]),
               let z = Float(comps[2]) {
                points.append(SIMD3<Float>(x, y, z))
            }
        }
        return points
    }

    private static func parsePLY(content: String) -> [SIMD3<Float>] {
        // Simple ASCII PLY parser for vertex positions only
        var points = [SIMD3<Float>]()

        let lines = content.components(separatedBy: .newlines)
        var headerEnded = false
        var vertexCount = 0
        var vertexRead = 0
        var headerLineIndex = 0

        for (i, line) in lines.enumerated() {
            if line.lowercased().starts(with: "element vertex") {
                let comps = line.split(separator: " ")
                if comps.count == 3, let count = Int(comps[2]) {
                    vertexCount = count
                }
            }
            if line.lowercased() == "end_header" {
                headerLineIndex = i
                headerEnded = true
                break
            }
        }

        guard headerEnded else { return [] }

        for line in lines[(headerLineIndex+1)...] {
            if vertexRead >= vertexCount { break }
            let comps = line.split(whereSeparator: { $0.isWhitespace })
            if comps.count >= 3,
               let x = Float(comps[0]),
               let y = Float(comps[1]),
               let z = Float(comps[2]) {
                points.append(SIMD3<Float>(x, y, z))
                vertexRead += 1
            }
        }

        return points
    }

    private static func parsePCD(content: String) -> [SIMD3<Float>] {
        // Only ASCII Data PCD supported here
        var points = [SIMD3<Float>]()
        let lines = content.components(separatedBy: .newlines)

        var headerEnded = false
        var dataStartIndex = 0
        var width = 0
        var height = 1

        for (i, line) in lines.enumerated() {
            let lline = line.trimmingCharacters(in: .whitespaces)
            if lline.lowercased().starts(with: "width") {
                let comps = lline.split(separator: " ")
                if comps.count == 2, let w = Int(comps[1]) {
                    width = w
                }
            }
            if lline.lowercased().starts(with: "height") {
                let comps = lline.split(separator: " ")
                if comps.count == 2, let h = Int(comps[1]) {
                    height = h
                }
            }
            if lline.lowercased() == "data ascii" {
                headerEnded = true
                dataStartIndex = i + 1
                break
            }
        }

        guard headerEnded else { return [] }

        for line in lines[dataStartIndex...] {
            let comps = line.split(whereSeparator: { $0.isWhitespace })
            if comps.count >= 3,
               let x = Float(comps[0]),
               let y = Float(comps[1]),
               let z = Float(comps[2]) {
                points.append(SIMD3<Float>(x, y, z))
            }
        }

        return points
    }
}

#if canImport(RealityKit) && os(visionOS)

private struct RealityKitPointCloudView: View {
    let points: [SIMD3<Float>]

    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: .zero)
            for point in points {
                let sphere = ModelEntity(
                    mesh: .generateSphere(radius: 0.002),
                    materials: [SimpleMaterial(color: .white, isMetallic: false)]
                )
                sphere.position = point
                anchor.addChild(sphere)
            }
            content.add(anchor)
        }
    }
}

#else

private struct SceneKitPointCloudView: UIViewRepresentable {
    let points: [SIMD3<Float>]

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView(frame: .zero)

        let scene = SCNScene()
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = UIColor.black

        let geometry = makePointCloudGeometry(points: points)

        let node = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(node)

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 0.5)
        scene.rootNode.addChildNode(cameraNode)

        // Light
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(0, 10, 10)
        scene.rootNode.addChildNode(lightNode)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // No dynamic update needed for now
    }

    private func makePointCloudGeometry(points: [SIMD3<Float>]) -> SCNGeometry {
        var vertexData = [Float]()
        for p in points {
            vertexData.append(contentsOf: [p.x, p.y, p.z])
        }

        let vertexSource = SCNGeometrySource(data: Data(bytes: vertexData, count: vertexData.count * MemoryLayout<Float>.size),
                                             semantic: .vertex,
                                             vectorCount: points.count,
                                             usesFloatComponents: true,
                                             componentsPerVector: 3,
                                             bytesPerComponent: MemoryLayout<Float>.size,
                                             dataOffset: 0,
                                             dataStride: MemoryLayout<Float>.size * 3)

        var indices = [Int32]()
        for i in 0..<points.count {
            indices.append(Int32(i))
        }

        let indicesData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)

        let element = SCNGeometryElement(data: indicesData,
                                         primitiveType: .point,
                                         primitiveCount: points.count,
                                         bytesPerIndex: MemoryLayout<Int32>.size)

        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
        geometry.firstMaterial = SCNMaterial()
        geometry.firstMaterial?.diffuse.contents = UIColor.white
        geometry.firstMaterial?.lightingModel = .constant
        geometry.firstMaterial?.isLitPerPixel = false
        geometry.firstMaterial?.readsFromDepthBuffer = false
        geometry.firstMaterial?.writesToDepthBuffer = true
        geometry.firstMaterial?.pointSize = 3.0
        geometry.firstMaterial?.lightingModel = .constant
        geometry.firstMaterial?.fillMode = .fill

        return geometry
    }
}

#endif


// MARK: - Previews
#Preview("Sample Point Cloud") {
    // Generate a small random sphere of points for preview
    let count = 2_000
    let points: [SIMD3<Float>] = (0..<count).map { _ in
        let theta = Float.random(in: 0..<(2 * .pi))
        let phi = acos(Float.random(in: -1...1))
        let r: Float = 0.2
        let x = r * sin(phi) * cos(theta)
        let y = r * sin(phi) * sin(theta)
        let z = r * cos(phi)
        return SIMD3<Float>(x, y, z)
    }
    return LegacyPointCloudRendererView(points: points)
        .frame(width: 600, height: 400)
}

#Preview("Empty State") {
    LegacyPointCloudRendererView(points: [])
        .frame(width: 400, height: 300)
}

