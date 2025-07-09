//
//  PointCloudDemo.swift
//  Pulto
//
//  Created by Assistant on 12/29/2024.
//

import Foundation

// MARK: - Legacy Compatibility

/// Provides compatibility with existing PointCloudDemo calls
struct PointCloudDemo {
    static func generateSpherePointCloudData(radius: Double = 10.0, points: Int = 1000) -> PointCloudData {
        var cloudPoints: [PointCloudData.PointData] = []
        
        for i in 0..<points {
            let theta = Double.random(in: 0...(2 * Double.pi))
            let phi = Double.random(in: 0...Double.pi)
            
            let x = radius * sin(phi) * cos(theta)
            let y = radius * sin(phi) * sin(theta)
            let z = radius * cos(phi)
            
            let intensity = (z + radius) / (2 * radius)
            
            let point = PointCloudData.PointData(
                x: x,
                y: y,
                z: z,
                intensity: intensity
            )
            cloudPoints.append(point)
        }
        
        var pointCloud = PointCloudData(
            title: "Demo Sphere Point Cloud",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "Demo Sphere",
            parameters: [
                "radius": radius,
                "points": Double(points)
            ]
        )
        
        pointCloud.points = cloudPoints
        pointCloud.totalPoints = cloudPoints.count
        
        return pointCloud
    }
    
    static func generateTorusPointCloudData(majorRadius: Double = 10.0, minorRadius: Double = 3.0, points: Int = 2000) -> PointCloudData {
        var cloudPoints: [PointCloudData.PointData] = []
        
        for i in 0..<points {
            let u = Double.random(in: 0...(2 * Double.pi))
            let v = Double.random(in: 0...(2 * Double.pi))
            
            let x = (majorRadius + minorRadius * cos(v)) * cos(u)
            let y = (majorRadius + minorRadius * cos(v)) * sin(u)
            let z = minorRadius * sin(v)
            
            let intensity = (z + minorRadius) / (2 * minorRadius)
            
            let point = PointCloudData.PointData(
                x: x,
                y: y,
                z: z,
                intensity: intensity
            )
            cloudPoints.append(point)
        }
        
        var pointCloud = PointCloudData(
            title: "Demo Torus Point Cloud",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "Demo Torus",
            parameters: [
                "majorRadius": majorRadius,
                "minorRadius": minorRadius,
                "points": Double(points)
            ]
        )
        
        pointCloud.points = cloudPoints
        pointCloud.totalPoints = cloudPoints.count
        
        return pointCloud
    }
    
    static func generateWaveSurfaceData(size: Double = 20.0, resolution: Int = 50) -> PointCloudData {
        var cloudPoints: [PointCloudData.PointData] = []
        
        let step = size / Double(resolution)
        
        for i in 0..<resolution {
            for j in 0..<resolution {
                let x = Double(i) * step - size / 2
                let y = Double(j) * step - size / 2
                let z = 2 * sin(x * 0.5) * cos(y * 0.5)
                
                let intensity = (z + 2) / 4
                
                let point = PointCloudData.PointData(
                    x: x,
                    y: y,
                    z: z,
                    intensity: intensity
                )
                cloudPoints.append(point)
            }
        }
        
        var pointCloud = PointCloudData(
            title: "Demo Wave Surface Point Cloud",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "Demo Wave Surface",
            parameters: [
                "size": size,
                "resolution": Double(resolution)
            ]
        )
        
        pointCloud.points = cloudPoints
        pointCloud.totalPoints = cloudPoints.count
        
        return pointCloud
    }
    
    static func generateSpiralGalaxyData(arms: Int = 3, points: Int = 5000) -> PointCloudData {
        var cloudPoints: [PointCloudData.PointData] = []
        
        for i in 0..<points {
            let armIndex = i % arms
            let baseAngle = Double(armIndex) * 2 * Double.pi / Double(arms)
            
            let radius = Double.random(in: 2...15)
            let angle = baseAngle + radius * 0.3 + Double.random(in: -0.2...0.2)
            
            let x = radius * cos(angle)
            let y = radius * sin(angle)
            let z = Double.random(in: -2...2)
            
            let intensity = (15 - radius) / 15
            
            let point = PointCloudData.PointData(
                x: x,
                y: y,
                z: z,
                intensity: intensity
            )
            cloudPoints.append(point)
        }
        
        var pointCloud = PointCloudData(
            title: "Demo Spiral Galaxy Point Cloud",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "Demo Spiral Galaxy",
            parameters: [
                "arms": Double(arms),
                "points": Double(points)
            ]
        )
        
        pointCloud.points = cloudPoints
        pointCloud.totalPoints = cloudPoints.count
        
        return pointCloud
    }
    
    static func generateNoisyCubeData(size: Double = 10.0, pointsPerFace: Int = 500) -> PointCloudData {
        var cloudPoints: [PointCloudData.PointData] = []
        
        let faces = [
            // Front face
            { () -> (Double, Double, Double) in (Double.random(in: -size/2...size/2), Double.random(in: -size/2...size/2), size/2) },
            // Back face
            { () -> (Double, Double, Double) in (Double.random(in: -size/2...size/2), Double.random(in: -size/2...size/2), -size/2) },
            // Left face
            { () -> (Double, Double, Double) in (-size/2, Double.random(in: -size/2...size/2), Double.random(in: -size/2...size/2)) },
            // Right face
            { () -> (Double, Double, Double) in (size/2, Double.random(in: -size/2...size/2), Double.random(in: -size/2...size/2)) },
            // Top face
            { () -> (Double, Double, Double) in (Double.random(in: -size/2...size/2), size/2, Double.random(in: -size/2...size/2)) },
            // Bottom face
            { () -> (Double, Double, Double) in (Double.random(in: -size/2...size/2), -size/2, Double.random(in: -size/2...size/2)) }
        ]
        
        for face in faces {
            for _ in 0..<pointsPerFace {
                let (x, y, z) = face()
                
                // Add some noise
                let noisyX = x + Double.random(in: -0.5...0.5)
                let noisyY = y + Double.random(in: -0.5...0.5)
                let noisyZ = z + Double.random(in: -0.5...0.5)
                
                let intensity = Double.random(in: 0...1)
                
                let point = PointCloudData.PointData(
                    x: noisyX,
                    y: noisyY,
                    z: noisyZ,
                    intensity: intensity
                )
                cloudPoints.append(point)
            }
        }
        
        var pointCloud = PointCloudData(
            title: "Demo Noisy Cube Point Cloud",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "Demo Noisy Cube",
            parameters: [
                "size": size,
                "pointsPerFace": Double(pointsPerFace)
            ]
        )
        
        pointCloud.points = cloudPoints
        pointCloud.totalPoints = cloudPoints.count
        
        return pointCloud
    }
}