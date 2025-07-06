import SwiftUI
import RealityKit

struct PointCloudTestView: View {
    @State private var pointCloudEntity: Entity?
    @State private var isGenerating = false
    @State private var pointCount = 1000
    @State private var useOptimizedRenderer = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Point Cloud Renderer Test")
                .font(.title)
                .padding()
            
            HStack {
                Text("Points: \(pointCount)")
                Slider(value: Binding(
                    get: { Double(pointCount) },
                    set: { pointCount = Int($0) }
                ), in: 100...5000, step: 100)
            }
            .padding()
            
            Toggle("Use Optimized Renderer", isOn: $useOptimizedRenderer)
                .padding()
            
            HStack(spacing: 20) {
                Button("Generate Simple Point Cloud") {
                    generateSimplePointCloud()
                }
                .disabled(isGenerating)
                
                Button("Generate Colored Point Cloud") {
                    generateColoredPointCloud()
                }
                .disabled(isGenerating)
                
                Button("Clear") {
                    clearPointCloud()
                }
            }
            .padding()
            
            if isGenerating {
                ProgressView("Generating point cloud...")
                    .padding()
            }
            
            RealityView { content in
                // Initial setup
            } update: { content in
                // Update with new point cloud
                content.entities.removeAll()
                if let entity = pointCloudEntity {
                    content.add(entity)
                }
            }
            .frame(height: 400)
        }
        .padding()
    }
    
    private func generateSimplePointCloud() {
        isGenerating = true
        
        Task {
            let (points, colors) = SimplePointCloudRenderer.generateSamplePointCloud(pointCount: pointCount)
            
            let entity: Entity
            if useOptimizedRenderer {
                entity = OptimizedPointCloudRenderer.createOptimizedPointCloud(
                    points: points,
                    colors: colors,
                    userPosition: [0, 0, 2]
                )
            } else {
                entity = SimplePointCloudRenderer.createPointCloud(
                    points: points,
                    colors: colors,
                    pointSize: 0.01
                )
            }
            
            await MainActor.run {
                self.pointCloudEntity = entity
                self.isGenerating = false
            }
        }
    }
    
    private func generateColoredPointCloud() {
        isGenerating = true
        
        Task {
            // Generate a more interesting dataset - spiral pattern
            var points: [SIMD3<Float>] = []
            var colors: [SIMD4<Float>] = []
            
            for i in 0..<pointCount {
                let t = Float(i) / Float(pointCount) * 4 * Float.pi
                let r = t * 0.1
                
                let x = r * cos(t)
                let y = Float(i) / Float(pointCount) - 0.5
                let z = r * sin(t)
                
                points.append(SIMD3<Float>(x, y, z))
                
                // Rainbow colors based on height
                let hue = (Float(i) / Float(pointCount))
                let color = HSVtoRGB(h: hue, s: 1.0, v: 1.0)
                colors.append(SIMD4<Float>(color.r, color.g, color.b, 1.0))
            }
            
            let entity: Entity
            if useOptimizedRenderer {
                entity = OptimizedPointCloudRenderer.createOptimizedPointCloud(
                    points: points,
                    colors: colors,
                    userPosition: [0, 0, 2]
                )
            } else {
                entity = SimplePointCloudRenderer.createPointCloud(
                    points: points,
                    colors: colors,
                    pointSize: 0.015
                )
            }
            
            await MainActor.run {
                self.pointCloudEntity = entity
                self.isGenerating = false
            }
        }
    }
    
    private func clearPointCloud() {
        pointCloudEntity = nil
    }
    
    private func HSVtoRGB(h: Float, s: Float, v: Float) -> (r: Float, g: Float, b: Float) {
        let c = v * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        
        let (r, g, b): (Float, Float, Float)
        
        switch h * 6 {
        case 0..<1: (r, g, b) = (c, x, 0)
        case 1..<2: (r, g, b) = (x, c, 0)
        case 2..<3: (r, g, b) = (0, c, x)
        case 3..<4: (r, g, b) = (0, x, c)
        case 4..<5: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        
        return (r + m, g + m, b + m)
    }
}