import SwiftUI
import RealityKit
import simd

public struct PointCloud {
    public struct Point {
        public let position: SIMD3<Float>
        public let intensity: Float?
        public init(position: SIMD3<Float>, intensity: Float? = nil) {
            self.position = position
            self.intensity = intensity
        }
    }
    public let points: [Point]
    public init(points: [Point]) {
        self.points = points
    }
}

public struct PointCloudRendererView: View {
    public let pointCloud: PointCloud

    public init(pointCloud: PointCloud) {
        self.pointCloud = pointCloud
    }

    public var body: some View {
        RealityView { content in
            // Root entity for all points
            let root = Entity()
            content.scene.addAnchor(root)

            let maxPoints = 50_000
            let pointsToRender = pointCloud.points.count > maxPoints
                ? downsample(points: pointCloud.points, maxCount: maxPoints)
                : pointCloud.points

            // Sphere radius
            let sphereRadius: Float = 0.003

            // Create a single sphere mesh to share
            let sphereMesh = MeshResource.generateSphere(radius: sphereRadius)

            // Create shared materials palette (8 buckets) for intensity
            let materials = (0..<8).map { bucketIndex -> SimpleMaterial in
                let intensity = Float(bucketIndex) / 7.0
                let color = colorFromIntensity(intensity)
                return SimpleMaterial(color: color, isMetallic: false)
            }

            for point in pointsToRender {
                let bucketIndex = Int(clamp((point.intensity ?? 1.0) * 7, 0, 7))
                let material = materials[bucketIndex]

                let model = ModelEntity(mesh: sphereMesh, materials: [material])
                model.position = point.position
                root.addChild(model)
            }
        }
        .ornament(.bottomLeading) {
            Text("Points: \(pointCloud.points.count)")
                .font(.footnote.monospacedDigit())
                .padding(6)
                .background(Color.black.opacity(0.4))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

fileprivate func downsample(points: [PointCloud.Point], maxCount: Int) -> [PointCloud.Point] {
    // Simple uniform downsampling by stride
    guard points.count > maxCount else { return points }
    let stride = points.count / maxCount
    return stride > 0 ? points.enumerated().compactMap { idx, p in
        idx % stride == 0 ? p : nil
    } : points
}

fileprivate func clamp<T: Comparable>(_ value: T, _ minValue: T, _ maxValue: T) -> T {
    if value < minValue { return minValue }
    if value > maxValue { return maxValue }
    return value
}

fileprivate func colorFromIntensity(_ intensity: Float) -> UIColor {
    // Map intensity (0...1) to grayscale UIColor
    let v = CGFloat(clamp(intensity, 0, 1))
    return UIColor(white: v, alpha: 1)
}

#Preview("PointCloudRendererView") {
    // Generate a small deterministic point cloud (approx 1k points)
    var points: [PointCloud.Point] = []
    let steps = 10
    let range: ClosedRange<Float> = -0.1...0.1
    let values = (0...steps).map { i -> Float in
        let t = Float(i) / Float(steps)
        return range.lowerBound + t * (range.upperBound - range.lowerBound)
    }
    for x in values {
        for y in values {
            for z in values {
                // Intensity based on normalized distance from center
                let d = sqrt(x*x + y*y + z*z)
                let maxD = sqrt(3) * 0.1
                let intensity = max(0, 1 - (d / maxD))
                points.append(PointCloud.Point(position: SIMD3<Float>(x, y, z), intensity: intensity))
            }
        }
    }
    let cloud = PointCloud(points: points)
    return PointCloudRendererView(pointCloud: cloud)
        .frame(height: 300)
        .padding()
}
