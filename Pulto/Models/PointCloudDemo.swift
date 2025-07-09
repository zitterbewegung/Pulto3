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
    
    /// Generate a realistic LiDAR-style building scan point cloud
    static func generateBuildingScanData(buildingWidth: Double = 30.0, buildingDepth: Double = 20.0, buildingHeight: Double = 15.0, density: Int = 2000) -> PointCloudData {
        var cloudPoints: [PointCloudData.PointData] = []
        
        // Building facade points
        let wallDensity = density / 8
        
        // Front wall
        for _ in 0..<wallDensity {
            let x = Double.random(in: -buildingWidth/2...buildingWidth/2)
            let y = Double.random(in: 0...buildingHeight)
            let z = buildingDepth/2
            
            // Add some realistic noise and missing data patches
            if Double.random(in: 0...1) > 0.15 { // 85% coverage
                let point = PointCloudData.PointData(
                    x: x + Double.random(in: -0.1...0.1),
                    y: y + Double.random(in: -0.05...0.05),
                    z: z + Double.random(in: -0.05...0.05),
                    intensity: Double.random(in: 0.3...0.9)
                )
                cloudPoints.append(point)
            }
        }
        
        // Back wall
        for _ in 0..<wallDensity {
            let x = Double.random(in: -buildingWidth/2...buildingWidth/2)
            let y = Double.random(in: 0...buildingHeight)
            let z = -buildingDepth/2
            
            if Double.random(in: 0...1) > 0.2 { // 80% coverage (less visible)
                let point = PointCloudData.PointData(
                    x: x + Double.random(in: -0.1...0.1),
                    y: y + Double.random(in: -0.05...0.05),
                    z: z + Double.random(in: -0.05...0.05),
                    intensity: Double.random(in: 0.2...0.7)
                )
                cloudPoints.append(point)
            }
        }
        
        // Left wall
        for _ in 0..<wallDensity {
            let x = -buildingWidth/2
            let y = Double.random(in: 0...buildingHeight)
            let z = Double.random(in: -buildingDepth/2...buildingDepth/2)
            
            if Double.random(in: 0...1) > 0.1 {
                let point = PointCloudData.PointData(
                    x: x + Double.random(in: -0.05...0.05),
                    y: y + Double.random(in: -0.05...0.05),
                    z: z + Double.random(in: -0.1...0.1),
                    intensity: Double.random(in: 0.4...0.8)
                )
                cloudPoints.append(point)
            }
        }
        
        // Right wall
        for _ in 0..<wallDensity {
            let x = buildingWidth/2
            let y = Double.random(in: 0...buildingHeight)
            let z = Double.random(in: -buildingDepth/2...buildingDepth/2)
            
            if Double.random(in: 0...1) > 0.1 {
                let point = PointCloudData.PointData(
                    x: x + Double.random(in: -0.05...0.05),
                    y: y + Double.random(in: -0.05...0.05),
                    z: z + Double.random(in: -0.1...0.1),
                    intensity: Double.random(in: 0.4...0.8)
                )
                cloudPoints.append(point)
            }
        }
        
        // Roof
        for _ in 0..<wallDensity {
            let x = Double.random(in: -buildingWidth/2...buildingWidth/2)
            let y = buildingHeight
            let z = Double.random(in: -buildingDepth/2...buildingDepth/2)
            
            if Double.random(in: 0...1) > 0.05 { // Good roof coverage
                let point = PointCloudData.PointData(
                    x: x + Double.random(in: -0.1...0.1),
                    y: y + Double.random(in: -0.05...0.05),
                    z: z + Double.random(in: -0.1...0.1),
                    intensity: Double.random(in: 0.6...1.0)
                )
                cloudPoints.append(point)
            }
        }
        
        // Ground plane
        for _ in 0..<wallDensity {
            let x = Double.random(in: -buildingWidth/2 - 5...buildingWidth/2 + 5)
            let y = 0
            let z = Double.random(in: -buildingDepth/2 - 5...buildingDepth/2 + 5)
            
            if Double.random(in: 0...1) > 0.3 { // Sparse ground coverage
                let point = PointCloudData.PointData(
                    x: Double(x) + Double.random(in: -0.2...0.2),
                    y: Double(y) + Double.random(in: -0.1...0.1),
                    z: Double(z) + Double.random(in: -0.2...0.2),
                    intensity: Double.random(in: 0.1...0.4)
                )
                cloudPoints.append(point)
            }
        }
        
        // Add some windows (gaps in the walls)
        let windowCount = 6
        for _ in 0..<windowCount {
            let windowX = Double.random(in: -buildingWidth/2 + 3...buildingWidth/2 - 3)
            let windowY = Double.random(in: 2...buildingHeight - 2)
            let windowZ = buildingDepth/2
            
            // Remove points in window area (create gaps)
            cloudPoints.removeAll { point in
                abs(point.x - windowX) < 2 && 
                abs(point.y - windowY) < 1.5 && 
                abs(point.z - windowZ) < 0.1
            }
        }
        
        var pointCloud = PointCloudData(
            title: "LiDAR Building Scan",
            xAxisLabel: "X (meters)",
            yAxisLabel: "Height (meters)",
            zAxisLabel: "Z (meters)",
            demoType: "LiDAR Building Scan",
            parameters: [
                "buildingWidth": buildingWidth,
                "buildingDepth": buildingDepth,
                "buildingHeight": buildingHeight,
                "targetDensity": Double(density)
            ]
        )
        
        pointCloud.points = cloudPoints
        pointCloud.totalPoints = cloudPoints.count
        
        return pointCloud
    }
    
    /// Generate a terrain scan with vegetation
    static func generateTerrainWithVegetationData(size: Double = 50.0, elevationVariation: Double = 8.0, vegetationDensity: Double = 0.3, points: Int = 8000) -> PointCloudData {
        var cloudPoints: [PointCloudData.PointData] = []
        
        let terrainPoints = Int(Double(points) * 0.6) // 60% terrain
        let vegetationPoints = points - terrainPoints // 40% vegetation
        
        // Generate terrain base
        for _ in 0..<terrainPoints {
            let x = Double.random(in: -size/2...size/2)
            let z = Double.random(in: -size/2...size/2)
            
            // Create realistic terrain height using multiple sine waves
            let height = sin(x * 0.1) * cos(z * 0.1) * elevationVariation +
                        sin(x * 0.3) * sin(z * 0.2) * (elevationVariation * 0.3) +
                        Double.random(in: -0.5...0.5) // Add noise
            
            let point = PointCloudData.PointData(
                x: x,
                y: height,
                z: z,
                intensity: (height + elevationVariation) / (2 * elevationVariation), // Height-based intensity
                color: "terrain"
            )
            cloudPoints.append(point)
        }
        
        // Generate vegetation on top of terrain
        for _ in 0..<vegetationPoints {
            let x = Double.random(in: -size/2...size/2)
            let z = Double.random(in: -size/2...size/2)
            
            // Get ground height at this position
            let groundHeight = sin(x * 0.1) * cos(z * 0.1) * elevationVariation +
                             sin(x * 0.3) * sin(z * 0.2) * (elevationVariation * 0.3)
            
            // Only place vegetation where it makes sense (not too steep)
            let slope = abs(cos(x * 0.1) * 0.1 * elevationVariation)
            if slope < 2.0 && Double.random(in: 0...1) < vegetationDensity {
                // Random vegetation height
                let vegetationHeight = Double.random(in: 0.5...6.0)
                let y = groundHeight + vegetationHeight
                
                let point = PointCloudData.PointData(
                    x: x + Double.random(in: -0.3...0.3), // Slight horizontal spread
                    y: y,
                    z: z + Double.random(in: -0.3...0.3),
                    intensity: Double.random(in: 0.4...0.9), // Variable vegetation intensity
                    color: "vegetation"
                )
                cloudPoints.append(point)
            }
        }
        
        // Add some scattered rocks/boulders
        let rockPoints = 200
        for _ in 0..<rockPoints {
            let x = Double.random(in: -size/2...size/2)
            let z = Double.random(in: -size/2...size/2)
            
            let groundHeight = sin(x * 0.1) * cos(z * 0.1) * elevationVariation +
                             sin(x * 0.3) * sin(z * 0.2) * (elevationVariation * 0.3)
            
            if Double.random(in: 0...1) < 0.1 { // Sparse rocks
                let y = groundHeight + Double.random(in: 0.2...2.0)
                
                let point = PointCloudData.PointData(
                    x: x,
                    y: y,
                    z: z,
                    intensity: Double.random(in: 0.2...0.6),
                    color: "rock"
                )
                cloudPoints.append(point)
            }
        }
        
        var pointCloud = PointCloudData(
            title: "Terrain Survey with Vegetation",
            xAxisLabel: "X (meters)",
            yAxisLabel: "Elevation (meters)",
            zAxisLabel: "Z (meters)",
            demoType: "Terrain Survey",
            parameters: [
                "areaSize": size,
                "elevationVariation": elevationVariation,
                "vegetationDensity": vegetationDensity,
                "totalPoints": Double(cloudPoints.count)
            ]
        )
        
        pointCloud.points = cloudPoints
        pointCloud.totalPoints = cloudPoints.count
        
        return pointCloud
    }
    
    /// Generate a car traffic intersection scan
    static func generateTrafficIntersectionData(intersectionSize: Double = 40.0, points: Int = 6000) -> PointCloudData {
        var cloudPoints: [PointCloudData.PointData] = []
        
        // Road surfaces (4 roads meeting at intersection)
        let roadWidth = 8.0
        let roadPoints = points / 3
        
        // Horizontal road (east-west)
        for _ in 0..<roadPoints/2 {
            let x = Double.random(in: -intersectionSize/2...intersectionSize/2)
            let z = Double.random(in: -roadWidth/2...roadWidth/2)
            let y = Double.random(in: -0.1...0.1) // Slight road surface variation
            
            let point = PointCloudData.PointData(
                x: x,
                y: y,
                z: z,
                intensity: Double.random(in: 0.2...0.5),
                color: "road"
            )
            cloudPoints.append(point)
        }
        
        // Vertical road (north-south)
        for _ in 0..<roadPoints/2 {
            let x = Double.random(in: -roadWidth/2...roadWidth/2)
            let z = Double.random(in: -intersectionSize/2...intersectionSize/2)
            let y = Double.random(in: -0.1...0.1)
            
            let point = PointCloudData.PointData(
                x: x,
                y: y,
                z: z,
                intensity: Double.random(in: 0.2...0.5),
                color: "road"
            )
            cloudPoints.append(point)
        }
        
        // Traffic lights and poles
        let polePositions = [
            (-roadWidth/2 - 2, -roadWidth/2 - 2),
            (roadWidth/2 + 2, -roadWidth/2 - 2),
            (-roadWidth/2 - 2, roadWidth/2 + 2),
            (roadWidth/2 + 2, roadWidth/2 + 2)
        ]
        
        for (poleX, poleZ) in polePositions {
            // Pole
            for height in stride(from: 0.0, to: 5.0, by: 0.2) {
                let point = PointCloudData.PointData(
                    x: poleX + Double.random(in: -0.1...0.1),
                    y: height,
                    z: poleZ + Double.random(in: -0.1...0.1),
                    intensity: Double.random(in: 0.6...0.8),
                    color: "infrastructure"
                )
                cloudPoints.append(point)
            }
            
            // Traffic light box
            for _ in 0..<50 {
                let point = PointCloudData.PointData(
                    x: poleX + Double.random(in: -0.3...0.3),
                    y: 4.5 + Double.random(in: -0.2...0.2),
                    z: poleZ + Double.random(in: -0.3...0.3),
                    intensity: Double.random(in: 0.7...0.9),
                    color: "infrastructure"
                )
                cloudPoints.append(point)
            }
        }
        
        // Vehicles (parked and moving)
        let vehicleCount = 8
        for _ in 0..<vehicleCount {
            let vehicleX = Double.random(in: -intersectionSize/3...intersectionSize/3)
            let vehicleZ = Double.random(in: -intersectionSize/3...intersectionSize/3)
            
            // Avoid placing vehicles right in the intersection center
            if abs(vehicleX) > roadWidth/2 || abs(vehicleZ) > roadWidth/2 {
                // Car body points
                for _ in 0..<80 {
                    let point = PointCloudData.PointData(
                        x: vehicleX + Double.random(in: -2...2),
                        y: Double.random(in: 0.3...1.8),
                        z: vehicleZ + Double.random(in: -1...1),
                        intensity: Double.random(in: 0.5...0.8),
                        color: "vehicle"
                    )
                    cloudPoints.append(point)
                }
            }
        }
        
        // Sidewalks and curbs
        let curbHeight = 0.15
        let sidewalkWidth = 3.0
        
        // Add curb points
        for side in [-1.0, 1.0] {
            // Horizontal curbs
            for x in stride(from: -intersectionSize/2, to: intersectionSize/2, by: 0.5) {
                for curbSide in [-roadWidth/2, roadWidth/2] {
                    let z = curbSide + (side * 0.2)
                    if Double.random(in: 0...1) > 0.3 {
                        let point = PointCloudData.PointData(
                            x: x + Double.random(in: -0.1...0.1),
                            y: curbHeight + Double.random(in: -0.02...0.02),
                            z: z,
                            intensity: Double.random(in: 0.3...0.6),
                            color: "sidewalk"
                        )
                        cloudPoints.append(point)
                    }
                }
            }
            
            // Vertical curbs
            for z in stride(from: -intersectionSize/2, to: intersectionSize/2, by: 0.5) {
                for curbSide in [-roadWidth/2, roadWidth/2] {
                    let x = curbSide + (side * 0.2)
                    if Double.random(in: 0...1) > 0.3 {
                        let point = PointCloudData.PointData(
                            x: x,
                            y: curbHeight + Double.random(in: -0.02...0.02),
                            z: z + Double.random(in: -0.1...0.1),
                            intensity: Double.random(in: 0.3...0.6),
                            color: "sidewalk"
                        )
                        cloudPoints.append(point)
                    }
                }
            }
        }
        
        var pointCloud = PointCloudData(
            title: "Traffic Intersection LiDAR Scan",
            xAxisLabel: "X (meters)",
            yAxisLabel: "Height (meters)",
            zAxisLabel: "Z (meters)",
            demoType: "Traffic Intersection",
            parameters: [
                "intersectionSize": intersectionSize,
                "roadWidth": roadWidth,
                "vehicleCount": Double(vehicleCount),
                "totalPoints": Double(cloudPoints.count)
            ]
        )
        
        pointCloud.points = cloudPoints
        pointCloud.totalPoints = cloudPoints.count
        
        return pointCloud
    }
}
