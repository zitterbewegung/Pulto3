//
//  Chart3DVolumetricView.swift
//  Pulto3
//
//  Created by Assistant on 2024-12-19.
//

import SwiftUI
import RealityKit
import Foundation

// MARK: - Chart3D Content Builder
struct Chart3DContentBuilder {
    static func buildChart3D(from data: Chart3DData) -> Entity {
        let rootEntity = Entity()
        
        // Add lighting
        let lightEntity = DirectionalLight()
        lightEntity.light.intensity = 1000
        lightEntity.position = SIMD3<Float>(0, 5, 5)
        lightEntity.look(at: SIMD3<Float>(0, 0, 0), from: lightEntity.position, relativeTo: nil)
        rootEntity.addChild(lightEntity)
        
        // Create data points
        let pointsEntity = createDataPoints(from: data)
        rootEntity.addChild(pointsEntity)
        
        // Create axes
        let axesEntity = createAxes(for: data)
        rootEntity.addChild(axesEntity)
        
        // Create title
        if let titleEntity = createTitle(data.title) {
            rootEntity.addChild(titleEntity)
        }
        
        return rootEntity
    }
    
    private static func createDataPoints(from data: Chart3DData) -> Entity {
        let pointsEntity = Entity()
        
        // Find data bounds for normalization
        let bounds = calculateBounds(from: data.points)
        
        for (index, point) in data.points.enumerated() {
            let normalizedPoint = normalizePoint(point, bounds: bounds)
            let pointEntity = createPointEntity(at: normalizedPoint, index: index, data: data)
            pointsEntity.addChild(pointEntity)
        }
        
        return pointsEntity
    }
    
    private static func createPointEntity(at position: SIMD3<Float>, index: Int, data: Chart3DData) -> Entity {
        let pointSize: Float = 0.02
        let sphere = MeshResource.generateSphere(radius: pointSize)
        
        // Color based on height (y-axis)
        let colorIntensity = (position.y + 1.0) / 2.0 // Normalize to 0-1
        let color = UIColor(
            hue: 0.7 - Double(colorIntensity) * 0.5,
            saturation: 0.8,
            brightness: 0.9,
            alpha: 1.0
        )
        
        let material = SimpleMaterial(color: color, isMetallic: false)
        let pointEntity = ModelEntity(mesh: sphere, materials: [material])
        pointEntity.position = position
        
        // Add collision for interaction
        pointEntity.components.set(CollisionComponent(shapes: [.generateSphere(radius: pointSize)]))
        pointEntity.components.set(InputTargetComponent())
        
        return pointEntity
    }
    
    private static func createAxes(for data: Chart3DData) -> Entity {
        let axesEntity = Entity()
        
        // X-axis (red)
        let xAxis = createAxisLine(from: SIMD3<Float>(-1, 0, 0), to: SIMD3<Float>(1, 0, 0), color: .red)
        axesEntity.addChild(xAxis)
        
        // Y-axis (green)
        let yAxis = createAxisLine(from: SIMD3<Float>(0, -1, 0), to: SIMD3<Float>(0, 1, 0), color: .green)
        axesEntity.addChild(yAxis)
        
        // Z-axis (blue)
        let zAxis = createAxisLine(from: SIMD3<Float>(0, 0, -1), to: SIMD3<Float>(0, 0, 1), color: .blue)
        axesEntity.addChild(zAxis)
        
        // Add axis labels
        if let xLabel = createAxisLabel(data.xAxisLabel, at: SIMD3<Float>(1.2, 0, 0), color: .red) {
            axesEntity.addChild(xLabel)
        }
        if let yLabel = createAxisLabel(data.yAxisLabel, at: SIMD3<Float>(0, 1.2, 0), color: .green) {
            axesEntity.addChild(yLabel)
        }
        if let zLabel = createAxisLabel(data.zAxisLabel, at: SIMD3<Float>(0, 0, 1.2), color: .blue) {
            axesEntity.addChild(zLabel)
        }
        
        return axesEntity
    }
    
    private static func createAxisLine(from start: SIMD3<Float>, to end: SIMD3<Float>, color: UIColor) -> Entity {
        let lineEntity = Entity()
        let distance = simd_length(end - start)
        let direction = simd_normalize(end - start)
        
        let cylinder = MeshResource.generateCylinder(height: distance, radius: 0.005)
        let material = SimpleMaterial(color: color, isMetallic: false)
        let cylinderEntity = ModelEntity(mesh: cylinder, materials: [material])
        
        // Position and rotate the cylinder
        let midpoint = (start + end) / 2
        cylinderEntity.position = midpoint
        
        // Rotate to align with direction
        let up = SIMD3<Float>(0, 1, 0)
        if simd_length(simd_cross(up, direction)) > 0.001 {
            let axis = simd_normalize(simd_cross(up, direction))
            let angle = acos(simd_dot(up, direction))
            cylinderEntity.orientation = simd_quatf(angle: angle, axis: axis)
        }
        
        lineEntity.addChild(cylinderEntity)
        return lineEntity
    }
    
    private static func createAxisLabel(_ text: String, at position: SIMD3<Float>, color: UIColor) -> Entity? {
        guard let textMesh = try? MeshResource.generateText(text, extrusionDepth: 0.01) else { return nil }
        
        let material = SimpleMaterial(color: color, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [material])
        textEntity.position = position
        textEntity.scale = SIMD3<Float>(repeating: 0.1)
        
        return textEntity
    }
    
    private static func createTitle(_ text: String) -> Entity? {
        guard let textMesh = try? MeshResource.generateText(text, extrusionDepth: 0.02) else { return nil }
        
        let material = SimpleMaterial(color: .white, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [material])
        textEntity.position = SIMD3<Float>(0, 1.5, 0)
        textEntity.scale = SIMD3<Float>(repeating: 0.15)
        
        return textEntity
    }
    
    private static func calculateBounds(from points: [Chart3DData.Point3D]) -> (min: SIMD3<Double>, max: SIMD3<Double>) {
        guard !points.isEmpty else { return (SIMD3<Double>(), SIMD3<Double>()) }
        
        let xValues = points.map { $0.x }
        let yValues = points.map { $0.y }
        let zValues = points.map { $0.z }
        
        let minBounds = SIMD3<Double>(
            xValues.min() ?? 0,
            yValues.min() ?? 0,
            zValues.min() ?? 0
        )
        
        let maxBounds = SIMD3<Double>(
            xValues.max() ?? 0,
            yValues.max() ?? 0,
            zValues.max() ?? 0
        )
        
        return (minBounds, maxBounds)
    }
    
    private static func normalizePoint(_ point: Chart3DData.Point3D, bounds: (min: SIMD3<Double>, max: SIMD3<Double>)) -> SIMD3<Float> {
        let range = bounds.max - bounds.min
        let safeRange = SIMD3<Double>(
            range.x != 0 ? range.x : 1,
            range.y != 0 ? range.y : 1,
            range.z != 0 ? range.z : 1
        )
        
        let normalized = SIMD3<Double>(
            2 * (point.x - bounds.min.x) / safeRange.x - 1,
            2 * (point.y - bounds.min.y) / safeRange.y - 1,
            2 * (point.z - bounds.min.z) / safeRange.z - 1
        )
        
        return SIMD3<Float>(Float(normalized.x), Float(normalized.y), Float(normalized.z))
    }
}

// MARK: - Chart3D Volumetric View
struct Chart3DVolumetricView: View {
    let windowID: Int
    let chartData: Chart3DData
    @EnvironmentObject var windowManager: WindowTypeManager
    
    @State private var rootEntity = Entity()
    @State private var isLoading = true
    @State private var showImportDialog = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header controls
            headerView
            
            // Main 3D view
            RealityView { content in
                content.add(rootEntity)
            }
            .overlay(alignment: .center) {
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading 3D Chart...")
                            .font(.headline)
                            .padding(.top)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(12)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let rotationY = Float(value.translation.x * 0.01)
                        let rotationX = Float(value.translation.y * 0.01)
                        rootEntity.transform.rotation = simd_quatf(angle: rotationY, axis: [0, 1, 0]) * simd_quatf(angle: rotationX, axis: [1, 0, 0])
                    }
            )
        }
        .task {
            await loadChart()
        }
        .fileImporter(
            isPresented: $showImportDialog,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(chartData.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 16) {
                    Label("\(chartData.points.count)", systemImage: "circle.grid.3x3")
                    Label(chartData.chartType, systemImage: "cube.transparent")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                Button("Import Data") {
                    showImportDialog = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Reset View") {
                    resetView()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.regularMaterial)
    }
    
    @MainActor
    private func loadChart() async {
        isLoading = true
        
        // Clear existing content
        rootEntity.children.removeAll()
        
        // Build new chart
        let chartEntity = Chart3DContentBuilder.buildChart3D(from: chartData)
        rootEntity.addChild(chartEntity)
        
        isLoading = false
    }
    
    private func resetView() {
        rootEntity.transform = Transform()
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard let url = try? result.get().first else { return }
        
        // Handle CSV import or other file types
        Task {
            do {
                let content = try String(contentsOf: url)
                let parsedData = parseCSV3DData(content, filename: url.lastPathComponent)
                
                await MainActor.run {
                    // Update window manager with new data
                    windowManager.updateWindowChart3DData(windowID, chart3DData: parsedData)
                    
                    // Reload the chart
                    Task {
                        await loadChart()
                    }
                }
            } catch {
                print("Error parsing file: \(error)")
            }
        }
    }
    
    private func parseCSV3DData(_ content: String, filename: String) -> Chart3DData {
        var chartData = Chart3DData(
            title: filename,
            chartType: "scatter",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z"
        )
        
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var startIndex = 0
        if let firstLine = lines.first {
            let components = firstLine.components(separatedBy: ",")
            if components.count >= 3 && Double(components[0]) == nil {
                startIndex = 1
            }
        }
        
        for i in startIndex..<lines.count {
            let components = lines[i].components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            
            if components.count >= 3,
               let x = Double(components[0]),
               let y = Double(components[1]),
               let z = Double(components[2]) {
                
                let point = Chart3DData.Point3D(x: x, y: y, z: z)
                chartData.points.append(point)
            }
        }
        
        return chartData
    }
}