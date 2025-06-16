//
//  PointCloudDemo.swift
//  Pulto
//
//  Point Cloud Demonstration
//
/*
import Foundation

class PointCloudDemo {

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
        print("==============================")
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

// MARK: - SwiftUI Preview
import SwiftUI
import Charts

struct PointCloudPreview: View {
    @State private var selectedDemo = 0
    @State private var rotationAngle = 0.0

    let demoNames = ["Sphere", "Torus", "Wave Surface", "Spiral Galaxy", "Noisy Cube"]

    var currentPointCloud: [(x: Double, y: Double, z: Double, intensity: Double?)] {
        switch selectedDemo {
        case 0:
            return PointCloudDemo.generateSpherePointCloud(radius: 10, points: 500)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: nil) }
        case 1:
            return PointCloudDemo.generateTorusPointCloud(majorRadius: 10, minorRadius: 3, points: 800)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: $0.intensity) }
        case 2:
            return PointCloudDemo.generateWaveSurface(size: 20, resolution: 30)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: $0.intensity) }
        case 3:
            return PointCloudDemo.generateSpiralGalaxy(arms: 3, points: 1000)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: $0.intensity) }
        case 4:
            return PointCloudDemo.generateNoisyCube(size: 10, pointsPerFace: 200)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: nil) }
        default:
            return []
        }
    }

    var body: some View {
        VStack(spacing: 20) {


            // Demo selector
            Picker("Select Data", selection: $selectedDemo) {
                ForEach(0..<demoNames.count, id: \.self) { index in
                    Text(demoNames[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

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
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)

            // Export button
            Button(action: {
                PointCloudDemo.runAllDemos()
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
    }
}

// MARK: - Preview Provider
#Preview {
    PointCloudPreview()
        //.frame(width: 600, height: 800)
}

// MARK: - Example Usage
/*
 To run the demo:

 // Run all demos
 PointCloudDemo.runAllDemos()

 // Or generate individual point clouds:
 let sphereData = PointCloudDemo.generateSpherePointCloud()
 let sphereChart = ChartDataExtractor.extractSimplePointCloudData(
     title: "My Sphere",
     data: sphereData
 )

 // Generate visualization code
 let pythonCode = ChartDataExtractor.generateJupyterPythonCode(sphereChart)
 let plotlyCode = ChartDataExtractor.generateJupyterPlotlyCode(sphereChart)
 */
*/
