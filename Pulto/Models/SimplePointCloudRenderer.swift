import RealityKit
import simd
import Foundation
import UIKit

// MARK: - Simple Point Cloud Rendering with Performance Optimizations

class SimplePointCloudRenderer {
    
    // MARK: - Basic Point Cloud Creation
    
    static func createPointCloud(
        points: [SIMD3<Float>],
        colors: [SIMD4<Float>] = [],
        pointSize: Float = 0.02
    ) -> Entity {
        let entity = Entity()
        
        for (index, point) in points.enumerated() {
            let pointEntity = Entity()
            
            // Create sphere mesh
            let sphereMesh = MeshResource.generateSphere(radius: pointSize)
            
            // Create material with color
            let material: SimpleMaterial
            if index < colors.count {
                let color = colors[index]
                // Create UIColor from SIMD4<Float> for visionOS compatibility
                let uiColor = UIColor(red: CGFloat(color.x), green: CGFloat(color.y), blue: CGFloat(color.z), alpha: CGFloat(color.w))
                material = SimpleMaterial(color: uiColor, isMetallic: false)
            } else {
                // Default cyan color
                material = SimpleMaterial(color: .cyan, isMetallic: false)
            }
            
            // Set up model component
            pointEntity.components[ModelComponent.self] = ModelComponent(
                mesh: sphereMesh,
                materials: [material]
            )
            
            // Position the point
            pointEntity.position = point
            
            entity.addChild(pointEntity)
        }
        
        return entity
    }
    
    // MARK: - Sample Data Generation
    
    static func generateSamplePointCloud(pointCount: Int = 1000) -> (points: [SIMD3<Float>], colors: [SIMD4<Float>]) {
        var points: [SIMD3<Float>] = []
        var colors: [SIMD4<Float>] = []
        
        for i in 0..<pointCount {
            // Generate random point in sphere
            let theta = Float.random(in: 0...(2 * Float.pi))
            let phi = Float.random(in: 0...Float.pi)
            let radius = Float.random(in: 0.1...0.5)
            
            let x = radius * sin(phi) * cos(theta)
            let y = radius * sin(phi) * sin(theta)
            let z = radius * cos(phi)
            
            points.append(SIMD3<Float>(x, y, z))
            
            // Generate bright color
            let hue = Float(i) / Float(pointCount)
            let r = abs(sin(hue * 2 * Float.pi))
            let g = abs(sin(hue * 2 * Float.pi + 2))
            let b = abs(sin(hue * 2 * Float.pi + 4))
            colors.append(SIMD4<Float>(r, g, b, 1.0))
        }
        
        return (points, colors)
    }
    
    // MARK: - Chunked Loading for Performance
    
    static func createPointCloudInChunks(
        points: [SIMD3<Float>],
        colors: [SIMD4<Float>] = [],
        chunkSize: Int = 100,
        pointSize: Float = 0.02
    ) -> Entity {
        let entity = Entity()
        
        // Process points in chunks
        for chunkStart in stride(from: 0, to: points.count, by: chunkSize) {
            let chunkEnd = min(chunkStart + chunkSize, points.count)
            let pointsChunk = Array(points[chunkStart..<chunkEnd])
            let colorsChunk = chunkStart < colors.count ? Array(colors[chunkStart..<min(chunkEnd, colors.count)]) : []
            
            let chunkEntity = createPointCloud(points: pointsChunk, colors: colorsChunk, pointSize: pointSize)
            entity.addChild(chunkEntity)
        }
        
        return entity
    }
}