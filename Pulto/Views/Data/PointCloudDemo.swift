//
//  PointCloudDemo.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/16/25.
//  Copyright 2025 Apple. All rights reserved.
//

import Foundation
import SwiftUI
import Charts
import UniformTypeIdentifiers

// MARK: - Helper Extensions
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

class PointCloudDemo2 {

    // MARK: - Demo Functions

    /// Generate a simple sphere point cloud
    static func generateSpherePointCloud(radius: Double = 10.0, points: Int = 1000) -> [(x: Double, y: Double, z: Double)] {
        var pointCloud: [(x: Double, y: Double, z: Double)] = []

        for _ in 0..<points {
            // Random angles
            let theta = Double.random(in: 0...(2 * .pi))
            let phi = Double.random(in: 0...(.pi))

            // Convert spherical to Cartesian coordinates
            let x = radius * sin(phi) * cos(theta)
            let y = radius * sin(phi) * sin(theta)
            let z = radius * cos(phi)

            pointCloud.append((x: x, y: y, z: z))
        }

        return pointCloud
    }

    /// Generate a torus (donut) point cloud
    static func generateTorusPointCloud(majorRadius: Double = 10.0, minorRadius: Double = 3.0, points: Int = 2000) -> [(x: Double, y: Double, z: Double, color: String?, intensity: Double?)] {
        var pointCloud: [(x: Double, y: Double, z: Double, color: String?, intensity: Double?)] = []

        for _ in 0..<points {
            let u = Double.random(in: 0...(2 * .pi))
            let v = Double.random(in: 0...(2 * .pi))

            let x = (majorRadius + minorRadius * cos(v)) * cos(u)
            let y = (majorRadius + minorRadius * cos(v)) * sin(u)
            let z = minorRadius * sin(v)

            // Calculate intensity based on height (z-coordinate)
            let intensity = (z + minorRadius) / (2 * minorRadius)

            pointCloud.append((x: x, y: y, z: z, color: nil, intensity: intensity))
        }

        return pointCloud
    }

    /// Generate a wave surface point cloud
    static func generateWaveSurface(size: Double = 20.0, resolution: Int = 50) -> [(x: Double, y: Double, z: Double, color: String?, intensity: Double?)] {
        var pointCloud: [(x: Double, y: Double, z: Double, color: String?, intensity: Double?)] = []

        let step = size / Double(resolution)

        for i in 0..<resolution {
            for j in 0..<resolution {
                let x = -size/2 + Double(i) * step
                let y = -size/2 + Double(j) * step

                // Wave equation: z = A * sin(kx * x) * sin(ky * y)
                let z = 3.0 * sin(0.3 * x) * sin(0.3 * y)

                // Intensity based on height
                let intensity = (z + 3.0) / 6.0

                pointCloud.append((x: x, y: y, z: z, color: nil, intensity: intensity))
            }
        }

        return pointCloud
    }

    /// Generate a spiral galaxy point cloud
    static func generateSpiralGalaxy(arms: Int = 3, points: Int = 5000) -> [(x: Double, y: Double, z: Double, color: String?, intensity: Double?)] {
        var pointCloud: [(x: Double, y: Double, z: Double, color: String?, intensity: Double?)] = []

        for i in 0..<points {
            let armIndex = i % arms
            let armAngle = (2.0 * .pi * Double(armIndex)) / Double(arms)

            // Distance from center
            let r = Double.random(in: 1...20)

            // Spiral angle
            let theta = armAngle + (r * 0.3)

            // Add some randomness
            let spread = 2.0 / (1.0 + r * 0.1)
            let xOffset = Double.random(in: -spread...spread)
            let yOffset = Double.random(in: -spread...spread)

            let x = r * cos(theta) + xOffset
            let y = r * sin(theta) + yOffset
            let z = Double.random(in: -1...1) * (1.0 / (1.0 + r * 0.1))

            // Intensity decreases with distance from center
            let intensity = 1.0 / (1.0 + r * 0.05)

            pointCloud.append((x: x, y: y, z: z, color: nil, intensity: intensity))
        }

        return pointCloud
    }

    /// Generate a cube with noise
    static func generateNoisyCube(size: Double = 10.0, pointsPerFace: Int = 500) -> [(x: Double, y: Double, z: Double)] {
        var pointCloud: [(x: Double, y: Double, z: Double)] = []
        let halfSize = size / 2.0
        let noiseLevel = 0.5

        // Generate points for each face
        for _ in 0..<pointsPerFace {
            // Top face
            pointCloud.append((
                x: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel),
                y: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel),
                z: halfSize + Double.random(in: -noiseLevel...noiseLevel)
            ))

            // Bottom face
            pointCloud.append((
                x: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel),
                y: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel),
                z: -halfSize + Double.random(in: -noiseLevel...noiseLevel)
            ))

            // Front face
            pointCloud.append((
                x: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel),
                y: halfSize + Double.random(in: -noiseLevel...noiseLevel),
                z: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel)
            ))

            // Back face
            pointCloud.append((
                x: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel),
                y: -halfSize + Double.random(in: -noiseLevel...noiseLevel),
                z: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel)
            ))

            // Right face
            pointCloud.append((
                x: halfSize + Double.random(in: -noiseLevel...noiseLevel),
                y: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel),
                z: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel)
            ))

            // Left face
            pointCloud.append((
                x: -halfSize + Double.random(in: -noiseLevel...noiseLevel),
                y: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel),
                z: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel)
            ))
        }

        return pointCloud
    }

    /// Generate CSV demo point cloud based on the provided sample data
    static func generateCSVCloud() -> [(x: Double, y: Double, z: Double, intensity: Double?)] {
        // Based on the sample CSV data in the comments
        let csvData: [(Double, Double, Double, Double?)] = [
            (-6.546342442212422, -4.179903666068734, 6.298714628531242, 0.8),
            (-2.019376912037411, -6.147036408083054, 7.624700668539823, 0.9),
            (9.59621907909937, -2.2192208519935686, -1.7284785784053573, 0.7),
            (8.716651471147433, -1.189249275314604, 4.75454238509943, nil),
            (4.362438263364272, -7.8615570443755045, -4.3777909082510105, nil),
            (-4.4427639844136015, -2.0944798486744487, -8.710625829542561, nil),
            (-0.6746971176831776, 0.3812547298886156, -9.969926209873751, nil),
            (7.655368516294206, 1.6789262084001224, 6.211001502694926, nil),
            (4.423516297334105, -4.471041172543755, -7.774464251679221, nil),
            (2.5149683123126407, 9.193033413950568, -3.0270564973339558, nil)
        ]
        
        var pointCloud: [(x: Double, y: Double, z: Double, intensity: Double?)] = []
        
        // Add the base CSV data points
        for (x, y, z, intensity) in csvData {
            pointCloud.append((x: x, y: y, z: z, intensity: intensity))
        }
        
        return pointCloud
    }

    /// Load point cloud from various file formats (CSV, PLY, PCD, XYZ)
    static func loadPointCloud(from url: URL) -> [(x: Double, y: Double, z: Double, intensity: Double?)] {
        do {
            #if !os(visionOS)
            let accessing = url.startAccessingSecurityScopedResource()
            if accessing {
                defer { url.stopAccessingSecurityScopedResource() }
            }
            #endif

            let data = try Data(contentsOf: url)
            guard let string = String(data: data, encoding: .utf8) else {
                return []
            }

            let fileExtension = url.pathExtension.lowercased()
            
            switch fileExtension {
            case "csv":
                return parseCSVPointCloud(string)
            case "ply":
                return parsePLYPointCloud(string)
            case "pcd":
                return parsePCDPointCloud(string)
            case "xyz":
                return parseXYZPointCloud(string)
            default:
                print("Unsupported file format: \(fileExtension)")
                return []
            }
        } catch {
            print("Error loading point cloud: \(error)")
            return []
        }
    }

    /// Parse CSV format point cloud
    private static func parseCSVPointCloud(_ content: String) -> [(x: Double, y: Double, z: Double, intensity: Double?)] {
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var points: [(x: Double, y: Double, z: Double, intensity: Double?)] = []

        for line in lines.dropFirst() { // skip header
            let parts = line.components(separatedBy: ",")
            if parts.count >= 3 {
                if let x = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                   let y = Double(parts[1].trimmingCharacters(in: .whitespaces)),
                   let z = Double(parts[2].trimmingCharacters(in: .whitespaces)) {
                    let intensity = parts.count > 3 ? Double(parts[3].trimmingCharacters(in: .whitespaces)) : nil
                    points.append((x: x, y: y, z: z, intensity: intensity))
                }
            }
        }
        return points
    }

    /// Parse PLY format point cloud
    private static func parsePLYPointCloud(_ content: String) -> [(x: Double, y: Double, z: Double, intensity: Double?)] {
        let lines = content.components(separatedBy: .newlines)
        var points: [(x: Double, y: Double, z: Double, intensity: Double?)] = []
        
        var headerEnded = false
        var vertexCount = 0
        var currentVertex = 0
        var xIndex = 0, yIndex = 1, zIndex = 2
        var intensityIndex: Int? = nil
        var propertyIndex = 0
        
        // Parse header
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.starts(with: "element vertex") {
                let parts = trimmedLine.components(separatedBy: " ")
                if parts.count >= 3 {
                    vertexCount = Int(parts[2]) ?? 0
                }
            } else if trimmedLine.starts(with: "property") {
                let parts = trimmedLine.components(separatedBy: " ")
                if parts.count >= 3 {
                    let propertyName = parts.last?.lowercased() ?? ""
                    
                    // Map standard property names to indices
                    switch propertyName {
                    case "x": xIndex = propertyIndex
                    case "y": yIndex = propertyIndex
                    case "z": zIndex = propertyIndex
                    case "intensity", "scalar_intensity", "i": intensityIndex = propertyIndex
                    default: break
                    }
                    propertyIndex += 1
                }
            } else if trimmedLine == "end_header" {
                headerEnded = true
                continue
            }
            
            if headerEnded && currentVertex < vertexCount {
                let parts = trimmedLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 3 {
                    if let x = Double(parts[safe: xIndex] ?? ""),
                       let y = Double(parts[safe: yIndex] ?? ""),
                       let z = Double(parts[safe: zIndex] ?? "") {
                        let intensity: Double? = intensityIndex != nil ? Double(parts[safe: intensityIndex!] ?? "") : nil
                        points.append((x: x, y: y, z: z, intensity: intensity))
                    }
                }
                currentVertex += 1
            }
        }
        
        return points
    }

    /// Parse PCD format point cloud
    private static func parsePCDPointCloud(_ content: String) -> [(x: Double, y: Double, z: Double, intensity: Double?)] {
        let lines = content.components(separatedBy: .newlines)
        var points: [(x: Double, y: Double, z: Double, intensity: Double?)] = []
        
        var dataStarted = false
        var fields: [String] = []
        var xIndex = 0, yIndex = 1, zIndex = 2
        var intensityIndex: Int? = nil
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.starts(with: "FIELDS") {
                fields = trimmedLine.components(separatedBy: .whitespaces).dropFirst().map { $0.lowercased() }
                
                // Find indices for x, y, z, and intensity
                for (index, field) in fields.enumerated() {
                    switch field {
                    case "x": xIndex = index
                    case "y": yIndex = index
                    case "z": zIndex = index
                    case "intensity", "i": intensityIndex = index
                    default: break
                    }
                }
            } else if trimmedLine.starts(with: "DATA") {
                dataStarted = true
                continue
            }
            
            if dataStarted && !trimmedLine.isEmpty && !trimmedLine.starts(with: "#") {
                let parts = trimmedLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 3 {
                    if let x = Double(parts[safe: xIndex] ?? ""),
                       let y = Double(parts[safe: yIndex] ?? ""),
                       let z = Double(parts[safe: zIndex] ?? "") {
                        let intensity: Double? = intensityIndex != nil ? Double(parts[safe: intensityIndex!] ?? "") : nil
                        points.append((x: x, y: y, z: z, intensity: intensity))
                    }
                }
            }
        }
        
        return points
    }

    /// Parse XYZ format point cloud
    private static func parseXYZPointCloud(_ content: String) -> [(x: Double, y: Double, z: Double, intensity: Double?)] {
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var points: [(x: Double, y: Double, z: Double, intensity: Double?)] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments and empty lines
            if trimmedLine.starts(with: "#") || trimmedLine.isEmpty {
                continue
            }
            
            // Handle both space and tab separation
            let parts = trimmedLine.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            if parts.count >= 3 {
                if let x = Double(parts[0]),
                   let y = Double(parts[1]),
                   let z = Double(parts[2]) {
                    // XYZ format can have intensity as 4th column
                    let intensity = parts.count > 3 ? Double(parts[3]) : nil
                    points.append((x: x, y: y, z: z, intensity: intensity))
                }
            }
        }
        
        return points
    }

    // MARK: - Demo Execution

    static func runAllDemos() {
        print("🎯 Point Cloud Demo Starting...\n")

        // Demo 1: Simple Sphere
        print("1️⃣ Generating Sphere Point Cloud...")
        let sphereData = generateSpherePointCloud(radius: 10.0, points: 1000)
        let sphereChart = ChartDataExtractor.extractSimplePointCloudData(
            title: "Sphere Point Cloud (1000 points)",
            data: sphereData,
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z"
        )
        let sphereCode = ChartDataExtractor.generateJupyterPythonCode(sphereChart)
        ChartDataExtractor.saveJupyterCode(sphereCode, to: "sphere_pointcloud.py")
        print("✅ Sphere point cloud saved to sphere_pointcloud.py\n")

        // Demo 2: Torus with Intensity
        print("2️⃣ Generating Torus Point Cloud with Intensity...")
        let torusData = generateTorusPointCloud(majorRadius: 10.0, minorRadius: 3.0, points: 2000)
        let torusChart = ChartDataExtractor.extractPointCloudData(
            title: "Torus Point Cloud with Height-based Intensity",
            data: torusData,
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z"
        )
        let torusCode = ChartDataExtractor.generateJupyterPythonCode(torusChart)
        ChartDataExtractor.saveJupyterCode(torusCode, to: "torus_pointcloud.py")
        print("✅ Torus point cloud saved to torus_pointcloud.py\n")

        // Demo 3: Wave Surface
        print("3️⃣ Generating Wave Surface...")
        let waveData = generateWaveSurface(size: 20.0, resolution: 50)
        let waveChart = ChartDataExtractor.extractPointCloudData(
            title: "Wave Surface Point Cloud",
            data: waveData,
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Height"
        )
        let waveCode = ChartDataExtractor.generateJupyterPythonCode(waveChart)
        ChartDataExtractor.saveJupyterCode(waveCode, to: "wave_pointcloud.py")
        print("✅ Wave surface saved to wave_pointcloud.py\n")

        // Demo 4: Spiral Galaxy
        print("4️⃣ Generating Spiral Galaxy...")
        let galaxyData = generateSpiralGalaxy(arms: 3, points: 5000)
        let galaxyChart = ChartDataExtractor.extractPointCloudData(
            title: "Spiral Galaxy Point Cloud",
            data: galaxyData,
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z"
        )
        let galaxyCode = ChartDataExtractor.generateJupyterPythonCode(galaxyChart)
        let galaxyPlotlyCode = ChartDataExtractor.generateJupyterPlotlyCode(galaxyChart)
        ChartDataExtractor.saveJupyterCode(galaxyCode, to: "galaxy_pointcloud.py")
        ChartDataExtractor.saveJupyterCode(galaxyPlotlyCode, to: "galaxy_pointcloud_plotly.py")
        print("✅ Galaxy point cloud saved (both matplotlib and plotly versions)\n")

        // Demo 5: Noisy Cube
        print("5️⃣ Generating Noisy Cube...")
        let cubeData = generateNoisyCube(size: 10.0, pointsPerFace: 500)
        let cubeChart = ChartDataExtractor.extractSimplePointCloudData(
            title: "Noisy Cube Point Cloud",
            data: cubeData,
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z"
        )
        let cubeCode = ChartDataExtractor.generateJupyterPythonCode(cubeChart)
        ChartDataExtractor.saveJupyterCode(cubeCode, to: "cube_pointcloud.py")
        print("✅ Noisy cube saved to cube_pointcloud.py\n")

        // Generate a combined demo notebook
        print("📓 Generating Jupyter Notebook with all demos...")
        generateCombinedNotebook()

        print("🎉 Demo Complete! Generated files:")
        print("   - sphere_pointcloud.py")
        print("   - torus_pointcloud.py")
        print("   - wave_pointcloud.py")
        print("   - galaxy_pointcloud.py")
        print("   - galaxy_pointcloud_plotly.py")
        print("   - cube_pointcloud.py")
        print("   - pointcloud_demo_notebook.py")
        print("\n")
        print("\n💡 Tip: Run these .py files in Jupyter Notebook to see the visualizations!")
    }

    static func generateCombinedNotebook() {
        let notebookCode = """
        # Point Cloud Visualization Demo
        # Generated by Swift ChartDataExtractor
        
        import json
        import matplotlib.pyplot as plt
        import pandas as pd
        import numpy as np
        from mpl_toolkits.mplot3d import Axes3D
        import plotly.graph_objects as go
        from plotly.subplots import make_subplots
        
        # Create a figure with multiple subplots
        fig = plt.figure(figsize=(20, 16))
        
        # You can run each demo separately by copying the generated Python files
        # This is a combined view showing the variety of point clouds you can create
        
        print("Point Cloud Visualization Demo")
        print("===============================")
        print("This notebook demonstrates various types of point clouds:")
        print("1. Sphere - Basic 3D shape")
        print("2. Torus - Shape with intensity mapping")
        print("3. Wave Surface - Mathematical function visualization")
        print("4. Spiral Galaxy - Complex pattern with intensity")
        print("5. Noisy Cube - Shape with added noise")
        print("")
        print("Run each individual .py file for detailed visualizations!")
        
        # Quick stats summary
        datasets = [
            ("Sphere", 1000, "Basic geometric shape"),
            ("Torus", 2000, "Donut shape with height-based coloring"),
            ("Wave Surface", 2500, "Mathematical sin wave surface"),
            ("Spiral Galaxy", 5000, "3-arm spiral with distance-based intensity"),
            ("Noisy Cube", 3000, "Cube faces with random noise")
        ]
        
        print("\\nDataset Summary:")
        print("-" * 60)
        for name, points, description in datasets:
            print(f"{name:15} | {points:6} points | {description}")
        """

        ChartDataExtractor.saveJupyterCode(notebookCode, to: "pointcloud_demo_notebook.py")
    }
}

// MARK: - Teapot Point Cloud Generation
extension PointCloudDemo2 {
    /// Generate a teapot point cloud using parametric equations
    static func generateTeapotPointCloud(points: Int = 2000) -> [(x: Double, y: Double, z: Double, color: String?, intensity: Double?)] {
        var pointCloud: [(x: Double, y: Double, z: Double, color: String?, intensity: Double?)] = []
        
        // Teapot parametric equations (simplified version)
        // Based on the classic Utah teapot model
        for _ in 0..<points {
            // Generate random parameters for the teapot surface
            let u = Double.random(in: 0...(2 * .pi))  // Azimuthal angle
            let v = Double.random(in: 0...(.pi))      // Polar angle
            
            // Teapot body parameters (simplified)
            let bodyRadius = 1.0 + 0.3 * cos(3 * u)   // Create the ribbed effect
            let heightFactor = 0.8 + 0.2 * sin(2 * v) // Height variation
            
            // Calculate position
            let x = bodyRadius * sin(v) * cos(u) * heightFactor
            let y = bodyRadius * sin(v) * sin(u) * heightFactor
            let z = bodyRadius * cos(v) * heightFactor
            
            // Add teapot spout and handle details
            if u < .pi/4 || u > 7 * .pi/4 {  // Spout area
                let spoutFactor = 1.0 + 0.3 * sin(u * 4)
                let newX = x * spoutFactor
                let newZ = z + 0.2 * sin(v)  // Lift the spout
                pointCloud.append((x: newX, y: y, z: newZ, color: nil, intensity: Double.random(in: 0.6...1.0)))
            } else if u > .pi/2 && u < .pi {  // Handle area
                let handleRadius = 0.2
                let handleX = x + handleRadius * cos(u) * 1.5
                let handleY = y + handleRadius * sin(u) * 0.5
                pointCloud.append((x: handleX, y: handleY, z: z, color: nil, intensity: Double.random(in: 0.3...0.7)))
            } else {
                // Regular body points
                pointCloud.append((x: x, y: y, z: z, color: nil, intensity: Double.random(in: 0.5...0.9)))
            }
        }
        
        // Add teapot lid (simplified)
        for _ in 0..<points/4 {
            let u = Double.random(in: 0...(2 * .pi))
            let v = Double.random(in: 0...(.pi/3))  // Smaller polar angle for lid
            
            let lidRadius = 0.8 + 0.1 * cos(4 * u)  // Ribbed lid
            let x = lidRadius * sin(v) * cos(u)
            let y = lidRadius * sin(v) * sin(u)
            let z = lidRadius * cos(v) + 1.2  // Lifted above the body
            
            pointCloud.append((x: x, y: y, z: z, color: nil, intensity: Double.random(in: 0.7...1.0)))
        }
        
        return pointCloud
    }
}

/*
 Supported Point Cloud Formats:
 
 1. CSV Format:
 x,y,z,intensity
 -6.546342442212422,-4.179903666068734,6.298714628531242,0.8
 -2.019376912037411,-6.147036408083054,7.624700668539823,0.9
 9.59621907909937,-2.2192208519935686,-1.7284785784053573,0.7
 
 2. PLY Format:
 ply
 format ascii 1.0
 element vertex 3
 property float x
 property float y
 property float z
 property float intensity
 end_header
 -6.546342 -4.179904 6.298715 0.8
 -2.019377 -6.147036 7.624701 0.9
 9.596219 -2.219221 -1.728479 0.7
 
 3. PCD Format:
 VERSION .7
 FIELDS x y z intensity
 SIZE 4 4 4 4
 TYPE F F F F
 COUNT 1 1 1 1
 WIDTH 3
 HEIGHT 1
 VIEWPOINT 0 0 0 1 0 0 0
 POINTS 3
 DATA ascii
 -6.546342 -4.179904 6.298715 0.8
 -2.019377 -6.147036 7.624701 0.9
 9.596219 -2.219221 -1.728479 0.7
 
 4. XYZ Format:
 # Simple XYZ format with optional intensity
 -6.546342 -4.179904 6.298715 0.8
 -2.019377 -6.147036 7.624701 0.9
 9.596219 -2.219221 -1.728479 0.7
 */

// MARK: - SwiftUI Preview
struct PointCloudPlotView: View {
    @State private var selectedDemo: Int
    @State private var rotationAngle = 0.0
    @State private var showFileImporter = false
    @State private var hasAutoPresentedImporter = false
    @State private var importedPoints: [(x: Double, y: Double, z: Double, intensity: Double?)] = []
    @State private var loadedFileName: String = ""
    @State private var loadingError: String?
    @StateObject private var windowManager = WindowTypeManager.shared

    let windowID: Int
    let fileURL: URL?

    let demoNames = ["Sphere", "Torus", "Wave Surface", "Spiral Galaxy", "Noisy Cube", "CSV Demo", "Imported"]

    // MARK: - Initializers
    
    /// Initialize with optional file URL for automatic loading
    /// - Parameters:
    ///   - windowID: Window identifier
    ///   - fileURL: Optional URL to CSV, PLY, PCD, or XYZ file to load automatically
    init(windowID: Int, fileURL: URL? = nil) {
        self.windowID = windowID
        self.fileURL = fileURL
        
        // Set initial demo based on whether file is provided
        if fileURL != nil {
            self._selectedDemo = State(initialValue: 6) // Imported tab
        } else {
            self._selectedDemo = State(initialValue: 5) // CSV Demo tab
        }
    }

    var currentPointCloud: [(x: Double, y: Double, z: Double, intensity: Double?)] {
        // FIRST: Check if there's imported data from WindowManager
        if let storedPointCloud = windowManager.getWindowPointCloud(for: windowID) {
            // Convert PointCloudData to the format expected by this view
            return storedPointCloud.points.map { point in
                (x: Double(point.x), y: Double(point.y), z: Double(point.z), intensity: point.intensity != nil ? Double(point.intensity!) : nil)
            }
        }
        switch selectedDemo {
        case 0:
            return PointCloudDemo2.generateSpherePointCloud(radius: 10, points: 500)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: nil) }
        case 1:
            return PointCloudDemo2.generateTorusPointCloud(majorRadius: 10, minorRadius: 3, points: 800)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: $0.intensity) }
        case 2:
            return PointCloudDemo2.generateWaveSurface(size: 20, resolution: 30)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: $0.intensity) }
        case 3:
            return PointCloudDemo2.generateSpiralGalaxy(arms: 3, points: 1000)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: $0.intensity) }
        case 4:
            return PointCloudDemo2.generateNoisyCube(size: 10, pointsPerFace: 200)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: nil) }
        case 5:
            return PointCloudDemo2.generateCSVCloud()
        case 6:
            return importedPoints
        default:
            return []
        }
    }

    var body: some View {
        VStack(spacing: 20) {

            // Show loaded file name if available
            if !loadedFileName.isEmpty {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.blue)
                    Text("Loaded: \(loadedFileName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }

            // Show loading error if any
            if let error = loadingError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal)
            }


            // 3D visualization using 2D projection
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 400)

                // Point cloud visualization
                GeometryReader { geometry in
                    Canvas { context, size in
                        let centerX = size.width / 2
                        let centerY = size.height / 2
                        let scale = min(size.width, size.height) / 40

                        // Apply rotation
                        let angle = rotationAngle * .pi / 180

                        for point in currentPointCloud {
                            // Simple 3D rotation around Y axis
                            let rotatedX = point.x * cos(angle) - point.z * sin(angle)
                            let rotatedZ = point.x * sin(angle) + point.z * cos(angle)

                            // Project to 2D (simple orthographic projection)
                            let projectedX = centerX + rotatedX * scale
                            let projectedY = centerY - point.y * scale

                            // Size based on Z depth
                            let pointSize = 2.0 + (rotatedZ + 20) / 20

                            // Color based on intensity or Z depth
                            let intensity = point.intensity ?? ((point.z + 10) / 20)
                            let color = Color(
                                hue: 0.6 - intensity * 0.4,
                                saturation: 0.8,
                                brightness: 0.9
                            )

                            context.fill(
                                Path(ellipseIn: CGRect(
                                    x: projectedX - pointSize/2,
                                    y: projectedY - pointSize/2,
                                    width: pointSize,
                                    height: pointSize
                                )),
                                with: .color(color.opacity(0.8))
                            )
                        }
                    }
                }
                .frame(height: 400)
                .onAppear {
                    // Load file if provided; otherwise auto-present importer once if no stored point cloud
                    if let fileURL = fileURL {
                        loadPointCloudFromFile(fileURL)
                    } else if !hasAutoPresentedImporter {
                        // Only present automatically if there's no point cloud already stored for this window
                        if windowManager.getWindowPointCloud(for: windowID) == nil {
                            hasAutoPresentedImporter = true
                            // Defer to next run loop to avoid presentation during view creation
                            DispatchQueue.main.async {
                                showFileImporter = true
                            }
                        }
                    }
                    
                    // Auto-rotate animation
                    withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
            }
            .padding()

            // Stats
            VStack(alignment: .leading, spacing: 8) {
                Text("Statistics")
                    .font(.headline)

                HStack {
                    Label("\(currentPointCloud.count) points", systemImage: "circle.grid.3x3.fill")
                    Spacer()
                    Label(String(format: "%.1f°", rotationAngle.truncatingRemainder(dividingBy: 360)), systemImage: "rotate.3d")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                                
                // Show intensity information
                if !currentPointCloud.isEmpty {
                    let hasIntensity = currentPointCloud.contains { $0.intensity != nil }
                    HStack {
                        Label(hasIntensity ? "With Intensity Data" : "No Intensity Data", 
                              systemImage: hasIntensity ? "waveform" : "waveform.slash")
                        Spacer()
                        if hasIntensity {
                            let intensityRange = currentPointCloud.compactMap { $0.intensity }
                            if !intensityRange.isEmpty {
                                let minInt = intensityRange.min() ?? 0
                                let maxInt = intensityRange.max() ?? 0
                                Label(String(format: "%.2f - %.2f", minInt, maxInt), systemImage: "slider.horizontal.3")
                            }
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)

            // Import button
            Button("Import Point Cloud (CSV/PLY/PCD/XYZ)") {
                showFileImporter = true
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.horizontal)

            // Export button
            Button(action: {
                PointCloudDemo2.runAllDemos()
                print("✅ Exported all demos to Python files!")
            }) {
                Label("Export to Jupyter", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [
                .commaSeparatedText,  // CSV
                UTType(filenameExtension: "ply") ?? .data,  // PLY
                UTType(filenameExtension: "pcd") ?? .data,  // PCD
                UTType(filenameExtension: "xyz") ?? .data   // XYZ
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                loadPointCloudFromFile(url)
            case .failure(let error):
                loadingError = error.localizedDescription
                print("Error importing file: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Load point cloud data from a file URL
    /// - Parameter url: URL to the point cloud file (CSV, PLY, PCD, XYZ)
    private func loadPointCloudFromFile(_ url: URL) {
        let supportedExtensions = ["csv", "ply", "pcd", "xyz"]
        let fileExtension = url.pathExtension.lowercased()
        
        // Reset previous error
        loadingError = nil
        
        if supportedExtensions.contains(fileExtension) {
            let points = PointCloudDemo2.loadPointCloud(from: url)
            
            if points.isEmpty {
                loadingError = "No valid points found in file or unsupported format"
            } else {
                importedPoints = points
                selectedDemo = 6 // Switch to imported tab
                loadedFileName = url.lastPathComponent
                print("Successfully imported \(importedPoints.count) points from \(url.lastPathComponent) (\(fileExtension.uppercased()) format)")
            }
        } else {
            loadingError = "Unsupported file format: \(fileExtension). Supported formats: CSV, PLY, PCD, XYZ"
            print("Unsupported file format: \(fileExtension). Supported formats: CSV, PLY, PCD, XYZ")
        }
    }
}

// MARK: - Preview Provider
struct PointCloudPlotView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default view without file
            PointCloudPlotView(windowID: 1)
                .frame(width: 600, height: 800)
                .previewDisplayName("Default Demo")
            
            // Example with file URL (uncomment and provide actual file path for testing)
            // PointCloudPlotView(windowID: 1, fileURL: URL(fileURLWithPath: "/path/to/sample.csv"))
            //     .frame(width: 600, height: 800)
            //     .previewDisplayName("With File")
        }
    }
}

// MARK: - Example Usage
/*
 To use with file loading:

 // Without file (shows demo data)
 PointCloudPlotView(windowID: 1)

 // With file (automatically loads and displays the file)
 PointCloudPlotView(windowID: 1, fileURL: URL(fileURLWithPath: "/path/to/pointcloud.csv"))
 
 // With URL from file picker or other source
 let fileURL = URL(fileURLWithPath: "/Users/username/Documents/data.ply")
 PointCloudPlotView(windowID: 1, fileURL: fileURL)

 // Run all demos
 PointCloudDemo2.runAllDemos()

 // Or generate individual point clouds:
 let sphereData = PointCloudDemo2.generateSpherePointCloud()
 let sphereChart = ChartDataExtractor.extractSimplePointCloudData(
     title: "My Sphere",
     data: sphereData
 )

 // Generate visualization code
 let pythonCode = ChartDataExtractor.generateJupyterPythonCode(sphereChart)
 let plotlyCode = ChartDataExtractor.generateJupyterPlotlyCode(sphereChart)
 */

