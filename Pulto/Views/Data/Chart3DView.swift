//
//  Chart3DView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/10/25.
//  Copyright 2025 Apple. All rights reserved.
//

import SwiftUI
import RealityKit
import Foundation

struct Chart3DView: View {
    let dataURL: URL?  // Optional URL for the JSON data (defaults to iCloud or bundle)

    var body: some View {
        RealityView { content in
            if let chartEntity = await load3DChart() {
                content.add(chartEntity)
            }
        }
        .frame(width: 400, height: 300)  // Adjust size per instance
        .background(Color.gray.opacity(0.2))  // Optional styling for visibility
    }

    func load3DChart() async -> Entity? {
        let chartEntity = Entity()

        // Use provided dataURL or fallback to default iCloud/bundle path
        let url = dataURL ??
                  FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/chart_data.json") ??
                  Bundle.main.url(forResource: "chart_data", withExtension: "json")

        guard let url = url else {
            print("Failed to find JSON file")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let json = try JSONDecoder().decode(Chart3DData.self, from: data)

            // Create spheres for each data point
            for point in json.points {
                let sphere = MeshResource.generateSphere(radius: 0.02)
                let material = SimpleMaterial(color: .blue, isMetallic: false)
                let pointEntity = ModelEntity(mesh: sphere, materials: [material])
                pointEntity.position = SIMD3<Float>(point.x, point.y, point.z)
                chartEntity.addChild(pointEntity)
            }

            // Add axes for reference
            chartEntity.addChild(createAxis(color: .red, direction: .x))
            chartEntity.addChild(createAxis(color: .green, direction: .y))
            chartEntity.addChild(createAxis(color: .blue, direction: .z))

            // Enable interactions
            chartEntity.components.set(InputTargetComponent())
            chartEntity.components.set(CollisionComponent(shapes: [.generateBox(width: 1, height: 1, depth: 1)]))

            // Add a ground plane for reference
            let groundMesh = MeshResource.generatePlane(width: 6.0, depth: 6.0)
            var groundMaterial = SimpleMaterial(color: .gray, roughness: 0.8, isMetallic: false)
            groundMaterial.color = .init(tint: .gray.withAlphaComponent(0.3))
            let groundEntity = ModelEntity(mesh: groundMesh, materials: [groundMaterial])
            groundEntity.position = SIMD3<Float>(0, -2.5, 0)
            chartEntity.addChild(groundEntity)

            return chartEntity
        } catch {
            print("Error loading data: \(error)")
            return nil
        }
    }

    func createAxis(color: UIColor, direction: AxisDirection) -> Entity {
        let axis = Entity()
        let mesh = MeshResource.generateBox(width: direction == .x ? 1.0 : 0.01,
                                            height: direction == .y ? 1.0 : 0.01,
                                            depth: direction == .z ? 1.0 : 0.01)
        let material = SimpleMaterial(color: color, isMetallic: false)
        let axisModel = ModelEntity(mesh: mesh, materials: [material])
        axisModel.position = SIMD3<Float>(direction == .x ? 0.5 : 0,
                                          direction == .y ? 0.5 : 0,
                                          direction == .z ? 0.5 : 0)
        axis.addChild(axisModel)
        return axis
    }

    enum AxisDirection {
        case x, y, z
    }
}

// MARK: - Chart3D Support

struct Chart3DData: Codable, Equatable, Hashable {
    let title: String
    let chartType: String
    let points: [Point3D]

    static func == (lhs: Chart3DData, rhs: Chart3DData) -> Bool {
        lhs.title == rhs.title &&
        lhs.chartType == rhs.chartType &&
        lhs.points == rhs.points
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(chartType)
        hasher.combine(points)
    }

    init(title: String = "3D Chart", chartType: String = "scatter", points: [Point3D] = []) {
        self.title = title
        self.chartType = chartType
        self.points = points
    }

    static func defaultData() -> Chart3DData {
        var points: [Point3D] = []
        for _ in 0..<50 {
            let x = Float.random(in: 0..<1)
            let y = Float.random(in: 0..<1)
            let z = Float(sin(x * 2 * .pi) + cos(y * 2 * .pi))
            points.append(Point3D(x: x, y: y, z: z))
        }
        return Chart3DData(title: "Sample 3D Chart", chartType: "scatter", points: points)
    }

    // Generate mathematical surfaces
    static func generateSurface(width: Int = 20, height: Int = 20, function: (Float, Float) -> Float) -> Chart3DData {
        var points: [Point3D] = []
        
        for i in 0..<width {
            for j in 0..<height {
                let x = Float(i) / Float(width) * 4.0 - 2.0  // Range -2 to 2
                let y = Float(j) / Float(height) * 4.0 - 2.0 // Range -2 to 2
                let z = function(x, y)
                points.append(Point3D(x: x, y: y, z: z))
            }
        }
        
        return Chart3DData(title: "3D Surface", chartType: "surface", points: points)
    }

    // Generate sample data patterns
    static func generateWave() -> Chart3DData {
        return generateSurface { x, y in
            sin(x) * cos(y)
        }
    }

    static func generateRipple() -> Chart3DData {
        return generateSurface { x, y in
            let r = sqrt(x*x + y*y)
            return r > 0 ? sin(r * 3) / r : 1.0
        }
    }

    static func generateParaboloid() -> Chart3DData {
        return generateSurface { x, y in
            (x*x + y*y) * 0.1
        }
    }
}

struct Point3D: Codable, Hashable {
    let x: Float
    let y: Float
    let z: Float
    
    init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
}

// MARK: - Chart3DVolumetricView for visionOS

struct Chart3DVolumetricView: View {
    let windowID: Int
    let chartData: Chart3DData
    @EnvironmentObject var windowManager: WindowTypeManager
    @State private var rootEntity = Entity()
    @State private var isLoading = true
    @State private var rotationSpeed: Float = 1.0
    @State private var pointSize: Float = 0.02
    @State private var showAxes = true
    @State private var colorMode: ColorMode = .height

    enum ColorMode: String, CaseIterable {
        case height = "Height"
        case distance = "Distance"
        case uniform = "Uniform"
        
        var icon: String {
            switch self {
            case .height: return "arrow.up.and.down"
            case .distance: return "circle.dotted"
            case .uniform: return "circle.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Controls overlay
            controlsHeaderView
            
            // Main 3D visualization
            mainVisualizationView
        }
        .task {
            await loadChart()
        }
        .onChange(of: pointSize) { _, _ in
            Task { await updateVisualization() }
        }
        .onChange(of: colorMode) { _, _ in
            Task { await updateVisualization() }
        }
        .onChange(of: showAxes) { _, _ in
            Task { await updateVisualization() }
        }
    }
    
    private var controlsHeaderView: some View {
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
                HStack(spacing: 8) {
                    Button(action: { showAxes.toggle() }) {
                        Image(systemName: showAxes ? "eye" : "eye.slash")
                            .foregroundColor(showAxes ? .blue : .gray)
                    }
                    .help("Toggle axes")
                    
                    Picker("Color Mode", selection: $colorMode) {
                        ForEach(ColorMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
                
                HStack(spacing: 8) {
                    Label("Size", systemImage: "circle")
                        .font(.caption2)
                    Slider(value: $pointSize, in: 0.01...0.1, step: 0.005)
                        .frame(width: 80)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
    }
    
    private var mainVisualizationView: some View {
        RealityView { content in
            content.add(rootEntity)
        } update: { content in
            // Update when parameters change
            Task {
                await updateVisualization()
            }
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
                    let rotationY = Float(value.translation.width * 0.01)
                    let rotationX = Float(value.translation.height * 0.01)
                    rootEntity.transform.rotation = simd_quatf(angle: rotationY, axis: [0, 1, 0]) * simd_quatf(angle: rotationX, axis: [1, 0, 0])
                }
        )
    }
    
    @MainActor
    private func loadChart() async {
        isLoading = true
        await updateVisualization()
        isLoading = false
    }
    
    @MainActor
    private func updateVisualization() async {
        // Clear existing children
        rootEntity.children.removeAll()
        
        // Add lighting
        let ambientLight = DirectionalLight()
        ambientLight.light.intensity = 500
        ambientLight.position = SIMD3<Float>(0, 2, 2)
        ambientLight.look(at: SIMD3<Float>(0, 0, 0), from: ambientLight.position, relativeTo: nil)
        rootEntity.addChild(ambientLight)
        
        let fillLight = DirectionalLight()
        fillLight.light.intensity = 300
        fillLight.position = SIMD3<Float>(-2, 1, 1)
        fillLight.look(at: SIMD3<Float>(0, 0, 0), from: fillLight.position, relativeTo: nil)
        rootEntity.addChild(fillLight)
        
        // Create 3D chart points
        await createChart3D()
        
        // Add axes if enabled
        if showAxes {
            rootEntity.addChild(createAxis(color: .red, direction: .x))
            rootEntity.addChild(createAxis(color: .green, direction: .y))
            rootEntity.addChild(createAxis(color: .blue, direction: .z))
        }
    }
    
    private func createChart3D() async {
        // Find bounds for normalization
        let minX = chartData.points.map { $0.x }.min() ?? 0
        let maxX = chartData.points.map { $0.x }.max() ?? 1
        let minY = chartData.points.map { $0.y }.min() ?? 0
        let maxY = chartData.points.map { $0.y }.max() ?? 1
        let minZ = chartData.points.map { $0.z }.min() ?? 0
        let maxZ = chartData.points.map { $0.z }.max() ?? 1
        
        let rangeX = max(maxX - minX, 0.001)
        let rangeY = max(maxY - minY, 0.001)
        let rangeZ = max(maxZ - minZ, 0.001)
        
        // Create points with better visibility
        for (index, point) in chartData.points.enumerated() {
            let sphere = MeshResource.generateSphere(radius: max(pointSize, 0.03)) // Minimum size for visibility
            
            // Normalize coordinates to [-2, 2] range for better spread
            let normalizedX = (point.x - minX) / rangeX * 4.0 - 2.0
            let normalizedY = (point.y - minY) / rangeY * 4.0 - 2.0
            let normalizedZ = (point.z - minZ) / rangeZ * 4.0 - 2.0
            
            // Calculate color based on mode
            let color = getPointColor(
                point: point,
                normalizedPoint: SIMD3<Float>(normalizedX, normalizedY, normalizedZ),
                index: index
            )
            
            let material = SimpleMaterial(color: color, roughness: 0.3, isMetallic: false)
            let pointEntity = ModelEntity(mesh: sphere, materials: [material])
            
            pointEntity.position = SIMD3<Float>(normalizedX, normalizedY, normalizedZ)
            
            // Add some glow effect for better visibility
            pointEntity.components.set(OpacityComponent(opacity: 0.9))
            
            rootEntity.addChild(pointEntity)
        }
        
        // Add title text above the chart
        if let titleMesh = try? MeshResource.generateText(
            chartData.title,
            extrusionDepth: 0.05
        ) {
            let titleMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let titleEntity = ModelEntity(mesh: titleMesh, materials: [titleMaterial])
            titleEntity.position = SIMD3<Float>(0, 3.0, 0) // Higher position
            titleEntity.scale = SIMD3<Float>(repeating: 0.2) // Larger scale
            rootEntity.addChild(titleEntity)
        }
        
        // Add a ground plane for reference
        let groundMesh = MeshResource.generatePlane(width: 6.0, depth: 6.0)
        var groundMaterial = SimpleMaterial(color: .gray, roughness: 0.8, isMetallic: false)
        groundMaterial.color = .init(tint: .gray.withAlphaComponent(0.3))
        let groundEntity = ModelEntity(mesh: groundMesh, materials: [groundMaterial])
        groundEntity.position = SIMD3<Float>(0, -2.5, 0)
        rootEntity.addChild(groundEntity)
    }
    
    private func getPointColor(point: Point3D, normalizedPoint: SIMD3<Float>, index: Int) -> UIColor {
        switch colorMode {
        case .height:
            let intensity = (normalizedPoint.y + 1.0) / 2.0 // 0 to 1
            return UIColor(hue: 0.7 - Double(intensity) * 0.5, saturation: 0.8, brightness: 0.9, alpha: 1.0)
            
        case .distance:
            let distance = sqrt(normalizedPoint.x * normalizedPoint.x + normalizedPoint.y * normalizedPoint.y + normalizedPoint.z * normalizedPoint.z)
            let intensity = min(distance / 1.732, 1.0) // Normalize by max possible distance (sqrt(3))
            return UIColor(hue: Double(intensity) * 0.8, saturation: 0.9, brightness: 0.8, alpha: 1.0)
            
        case .uniform:
            return .systemBlue
        }
    }

    private func createAxis(color: UIColor, direction: AxisDirection) -> Entity {
        let axis = Entity()
        let mesh = MeshResource.generateBox(
            width: direction == .x ? 2.5 : 0.02,
            height: direction == .y ? 2.5 : 0.02,
            depth: direction == .z ? 2.5 : 0.02
        )
        let material = SimpleMaterial(color: color, isMetallic: false)
        let axisModel = ModelEntity(mesh: mesh, materials: [material])
        axisModel.position = SIMD3<Float>(
            direction == .x ? 0 : 0,
            direction == .y ? 0 : 0,
            direction == .z ? 0 : 0
        )
        axis.addChild(axisModel)
        
        // Add axis label
        let labelText = direction == .x ? "X" : (direction == .y ? "Y" : "Z")
        if let labelMesh = try? MeshResource.generateText(labelText, extrusionDepth: 0.02) {
            let labelMaterial = SimpleMaterial(color: color, isMetallic: false)
            let labelEntity = ModelEntity(mesh: labelMesh, materials: [labelMaterial])
            labelEntity.position = SIMD3<Float>(
                direction == .x ? 1.3 : 0,
                direction == .y ? 1.3 : 0,
                direction == .z ? 1.3 : 0
            )
            labelEntity.scale = SIMD3<Float>(repeating: 0.15)
            axis.addChild(labelEntity)
        }
        
        return axis
    }

    private enum AxisDirection {
        case x, y, z
    }
}

// MARK: - SwiftUI Preview

private extension URL {
    /// Writes a tiny three-point JSON file the first time it's called,
    /// then returns its URL. Replace with your own resource if you like.
    static func previewSampleChartDataURL() -> URL {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("sample_chart_data.json")
        if !FileManager.default.fileExists(atPath: tmp.path) {
            let sampleJSON = """
            {
              "title": "Sample 3D Chart",
              "chartType": "scatter",
              "points": [
                { "x": 0.0, "y": 0.0, "z": 0.0 },
                { "x": 0.3, "y": 0.5, "z": 0.2 },
                { "x": 0.6, "y": 0.8, "z": 0.4 }
                { "x": 0.7, "y": 0.8, "z": -0.4 }
                { "x": 0.1, "y": -0.8, "z": 0.4 }
              ]
            }
            """
            try? Data(sampleJSON.utf8).write(to: tmp)
        }
        return tmp
    }
}


// Customize the surface styles for a sinc function
/*
import SwiftUI
import Charts

struct Chart3DView: View {
  var body: some View {
    Chart3D {
      SurfacePlot(x: "X", y: "Y", z: "Z") { x, z in
        let h = hypot(x, z)
        return sin(h) / h
      }
      .foregroundStyle(.normalBased)
    }
    .chartXScale(domain: -10...10, range: -0.5...0.5)
    .chartZScale(domain: -10...10, range: -0.5...0.5)
    .chartYScale(domain: -0.23...1, range: -0.5...0.5)
  }
}
#Preview("Sample 3-D Chart", traits: .fixedLayout(width: 400, height: 300)) {
    Chart3DView()
        .glassBackgroundEffect()   // optional translucent frame
        .padding()
}
*/
