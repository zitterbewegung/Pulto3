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
    let dataURL: URL?  // Optional URL for the JSON data
    @State private var debugMessage = ""
    @State private var pointCount = 0

    var body: some View {
        ZStack {
            RealityView { content in
                if let chartEntity = await load3DChart() {
                    content.add(chartEntity)
                }
            }
            .frame(width: 400, height: 300)
            .background(Color.black.opacity(0.9)) // Dark background for better contrast

            // Debug overlay
            VStack {
                HStack {
                    if !debugMessage.isEmpty {
                        Text(debugMessage)
                            .font(.caption)
                            .padding(4)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    if pointCount > 0 {
                        Text("\(pointCount) points")
                            .font(.caption)
                            .padding(4)
                            .background(Color.blue.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                Spacer()
                Text("Drag to rotate (if gestures enabled)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(4)
            }
            .padding(8)
        }
    }

    func load3DChart() async -> Entity? {
        let chartEntity = Entity()

        // Generate default data if no URL provided
        let chartData: Chart3DData

        if let url = dataURL {
            // Try to load from provided URL
            do {
                let data = try Data(contentsOf: url)
                chartData = try JSONDecoder().decode(Chart3DData.self, from: data)
                await MainActor.run {
                    debugMessage = "Loaded from URL"
                    pointCount = chartData.points.count
                }
            } catch {
                print("Error loading from URL: \(error)")
                await MainActor.run {
                    debugMessage = "Error: \(error.localizedDescription)"
                }
                // Fall back to default data
                chartData = Chart3DData.defaultData()
            }
        } else {
            // No URL provided, use default data
            chartData = Chart3DData.defaultData()
            await MainActor.run {
                debugMessage = "Using default data"
                pointCount = chartData.points.count
            }
        }

        // Ensure we have data
        guard !chartData.points.isEmpty else {
            await MainActor.run {
                debugMessage = "No data points!"
            }
            return chartEntity
        }

        // Find bounds for better visualization
        let xValues = chartData.points.map { $0.x }
        let yValues = chartData.points.map { $0.y }
        let zValues = chartData.points.map { $0.z }

        let minX = xValues.min() ?? 0
        let maxX = xValues.max() ?? 1
        let minY = yValues.min() ?? 0
        let maxY = yValues.max() ?? 1
        let minZ = zValues.min() ?? 0
        let maxZ = zValues.max() ?? 1

        let rangeX = max(maxX - minX, 0.001)
        let rangeY = max(maxY - minY, 0.001)
        let rangeZ = max(maxZ - minZ, 0.001)

        // Create a container for all points
        let pointsContainer = Entity()

        // Create spheres for each data point
        for (index, point) in chartData.points.enumerated() {
            // Normalize to [-0.5, 0.5] range for better visibility
            let normalizedX = ((point.x - minX) / rangeX - 0.5)
            let normalizedY = ((point.y - minY) / rangeY - 0.5)
            let normalizedZ = ((point.z - minZ) / rangeZ - 0.5)

            // Create larger, more visible spheres
            let sphere = MeshResource.generateSphere(radius: 0.02) // Good size for visibility

            // Use bright, distinct colors
            let hue = Double(index) / Double(chartData.points.count)
            let color = UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)

            // Create material with the color
            let material = SimpleMaterial(color: color, roughness: 0.5, isMetallic: false)

            let pointEntity = ModelEntity(mesh: sphere, materials: [material])
            pointEntity.position = SIMD3<Float>(normalizedX, normalizedY, normalizedZ)

            // Add to container
            pointsContainer.addChild(pointEntity)
        }

        // Scale the entire point cloud for better visibility
        pointsContainer.scale = SIMD3<Float>(repeating: 0.5)
        chartEntity.addChild(pointsContainer)

        // Add axes for reference - make them more visible
        let xAxis = createAxis(color: .red, direction: .x, label: "X")
        xAxis.scale = SIMD3<Float>(repeating: 0.5)
        chartEntity.addChild(xAxis)

        let yAxis = createAxis(color: .green, direction: .y, label: "Y")
        yAxis.scale = SIMD3<Float>(repeating: 0.5)
        chartEntity.addChild(yAxis)

        let zAxis = createAxis(color: .blue, direction: .z, label: "Z")
        zAxis.scale = SIMD3<Float>(repeating: 0.5)
        chartEntity.addChild(zAxis)

        // Add a semi-transparent ground plane
        let groundMesh = MeshResource.generatePlane(width: 1.5, depth: 1.5)
        let groundMaterial = SimpleMaterial(color: UIColor.white.withAlphaComponent(0.1), isMetallic: false)
        let groundEntity = ModelEntity(mesh: groundMesh, materials: [groundMaterial])
        groundEntity.position = SIMD3<Float>(0, -0.4, 0)
        chartEntity.addChild(groundEntity)

        // Add some lighting to make points more visible
        let light = DirectionalLight()
        light.light.intensity = 1000
        light.position = SIMD3<Float>(0, 1, 1)
        light.look(at: SIMD3<Float>(0, 0, 0), from: light.position, relativeTo: nil)
        chartEntity.addChild(light)

        // Position the entire chart closer to camera
        chartEntity.position = SIMD3<Float>(0, 0, -0.5) // Much closer than before

        // Debug: Add a large reference sphere at origin
        let debugSphere = MeshResource.generateSphere(radius: 0.05)
        let debugMaterial = SimpleMaterial(color: .yellow, isMetallic: false)
        let debugEntity = ModelEntity(mesh: debugSphere, materials: [debugMaterial])
        debugEntity.position = SIMD3<Float>(0, 0, 0)
        chartEntity.addChild(debugEntity)

        return chartEntity
    }

    func createAxis(color: UIColor, direction: AxisDirection, label: String) -> Entity {
        let axis = Entity()

        // Create thicker axis line for better visibility
        let mesh = MeshResource.generateBox(width: direction == .x ? 1.0 : 0.05,
                                          height: direction == .y ? 1.0 : 0.05,
                                          depth: direction == .z ? 1.0 : 0.05)
        let material = SimpleMaterial(color: color, isMetallic: false)
        let axisModel = ModelEntity(mesh: mesh, materials: [material])
        axisModel.position = SIMD3<Float>(
            direction == .x ? 0.5 : 0,
            direction == .y ? 0.5 : 0,
            direction == .z ? 0.5 : 0
        )
        axis.addChild(axisModel)

        // Add larger arrow at the end
        let arrowMesh = MeshResource.generateCone(height: 0.15, radius: 0.075)
        let arrowMaterial = SimpleMaterial(color: color, isMetallic: false)
        let arrowEntity = ModelEntity(mesh: arrowMesh, materials: [arrowMaterial])

        // Position arrow at the end of axis
        switch direction {
        case .x:
            arrowEntity.position = SIMD3<Float>(1.1, 0, 0)
            arrowEntity.transform.rotation = simd_quatf(angle: -.pi/2, axis: [0, 0, 1])
        case .y:
            arrowEntity.position = SIMD3<Float>(0, 1.1, 0)
        case .z:
            arrowEntity.position = SIMD3<Float>(0, 0, 1.1)
            arrowEntity.transform.rotation = simd_quatf(angle: .pi/2, axis: [1, 0, 0])
        }
        axis.addChild(arrowEntity)

        return axis
    }

    enum AxisDirection {
        case x, y, z
    }
}

// MARK: - Chart3D Data Model

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

        // Create a 3D grid of points for better visibility
        let gridSize = 5
        for i in 0..<gridSize {
            for j in 0..<gridSize {
                for k in 0..<gridSize {
                    let x = Float(i) / Float(gridSize - 1) * 2.0 - 1.0
                    let y = Float(j) / Float(gridSize - 1) * 2.0 - 1.0
                    let z = Float(k) / Float(gridSize - 1) * 2.0 - 1.0
                    points.append(Point3D(x: x, y: y, z: z))
                }
            }
        }

        // Add some points in a spiral pattern for visual interest
        for i in 0..<50 {
            let t = Float(i) / 50.0 * Float.pi * 2
            let x = sin(t) * 0.8
            let y = Float(i) / 50.0 * 2.0 - 1.0
            let z = cos(t) * 0.8
            points.append(Point3D(x: x, y: y, z: z))
        }

        return Chart3DData(title: "3D Point Cloud", chartType: "scatter", points: points)
    }

    // Generate mathematical surfaces
    static func generateSurface(width: Int = 20, height: Int = 20, function: (Float, Float) -> Float) -> Chart3DData {
        var points: [Point3D] = []

        for i in 0..<width {
            for j in 0..<height {
                let x = Float(i) / Float(width) * 4.0 - 2.0
                let y = Float(j) / Float(height) * 4.0 - 2.0
                let z = function(x, y)
                points.append(Point3D(x: x, y: y, z: z))
            }
        }

        return Chart3DData(title: "3D Surface", chartType: "surface", points: points)
    }

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
    @State private var pointSize: Float = 0.03
    @State private var showAxes = true
    @State private var colorMode: ColorMode = .height
    @State private var showControls = true
    @State private var isAnimating = false

    enum ColorMode: String, CaseIterable {
        case height = "Height"
        case distance = "Distance"
        case category = "Category"
        case uniform = "Uniform"

        var icon: String {
            switch self {
            case .height: return "arrow.up.and.down"
            case .distance: return "circle.dotted"
            case .category: return "square.grid.3x3"
            case .uniform: return "circle.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            // Main 3D visualization
            RealityView { content in
                content.add(rootEntity)
            } update: { content in
                Task { await updateVisualization() }
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
            
            // Controls overlay
            if showControls {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        controlPanel
                    }
                }
                .padding()
            }
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
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls.toggle()
            }
        }
        .task {
            // Auto-hide controls after 5 seconds
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
    
    private var controlPanel: some View {
        VStack(spacing: 16) {
            // Chart info header
            VStack(alignment: .leading, spacing: 8) {
                Text(chartData.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                HStack(spacing: 16) {
                    Label("\(chartData.points.count)", systemImage: "circle.grid.3x3")
                    Label(chartData.chartType.capitalized, systemImage: getChartIcon(for: chartData.chartType))
                    Label("Window #\(windowID)", systemImage: "macwindow")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            }
            
            Divider()
                .background(.white.opacity(0.3))
            
            // Visual controls
            VStack(spacing: 12) {
                HStack {
                    Text("Point Size")
                        .font(.caption)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(pointSize, specifier: "%.3f")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Slider(value: $pointSize, in: 0.01...0.1, step: 0.005)
                    .tint(.blue)
            }
            
            Divider()
                .background(.white.opacity(0.3))
            
            // Display options
            VStack(spacing: 8) {
                HStack {
                    Button(action: { showAxes.toggle() }) {
                        HStack {
                            Image(systemName: showAxes ? "eye" : "eye.slash")
                            Text("Axes")
                        }
                        .font(.caption)
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                    
                    Picker("Color", selection: $colorMode) {
                        ForEach(ColorMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
                
                HStack {
                    Button(action: toggleAnimation) {
                        HStack {
                            Image(systemName: isAnimating ? "pause.fill" : "play.fill")
                            Text(isAnimating ? "Pause" : "Animate")
                        }
                        .font(.caption)
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                    
                    Button(action: resetView) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reset")
                        }
                        .font(.caption)
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 10)
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
        setupLighting()

        // Create chart visualization based on type
        await createChartVisualization()

        // Add axes if enabled
        if showAxes {
            addAxes()
        }

        // Add chart title
        addChartTitle(chartData.title)
    }
    
    private func setupLighting() {
        // Main directional light
        let directionalLight = DirectionalLight()
        directionalLight.light.intensity = 1000
        directionalLight.position = SIMD3<Float>(2, 3, 2)
        directionalLight.look(at: SIMD3<Float>(0, 0, 0), from: directionalLight.position, relativeTo: nil)
        rootEntity.addChild(directionalLight)
        
        // Fill light
        let fillLight = DirectionalLight()
        fillLight.light.intensity = 500
        fillLight.position = SIMD3<Float>(-2, 1, 1)
        fillLight.look(at: SIMD3<Float>(0, 0, 0), from: fillLight.position, relativeTo: nil)
        rootEntity.addChild(fillLight)
        
        // Ambient light
        let ambientLight = DirectionalLight()
        ambientLight.light.intensity = 200
        ambientLight.position = SIMD3<Float>(0, 5, 0)
        rootEntity.addChild(ambientLight)
    }

    private func createChartVisualization() async {
        guard !chartData.points.isEmpty else { return }
        
        // Normalize data for better visualization
        let normalizedData = normalizeChartData(chartData)
        
        // Create visualization based on chart type
        switch chartData.chartType {
        case "scatter":
            await createScatterVisualization(normalizedData)
        case "bar":
            await createBarVisualization(normalizedData)
        case "line":
            await createLineVisualization(normalizedData)
        case "histogram":
            await createHistogramVisualization(normalizedData)
        case "area":
            await createAreaVisualization(normalizedData)
        case "pie":
            await createPieVisualization(normalizedData)
        default:
            await createScatterVisualization(normalizedData)
        }
    }
    
    private func normalizeChartData(_ chartData: Chart3DData) -> Chart3DData {
        let points = chartData.points
        
        let minX = points.map { $0.x }.min() ?? 0
        let maxX = points.map { $0.x }.max() ?? 1
        let minY = points.map { $0.y }.min() ?? 0
        let maxY = points.map { $0.y }.max() ?? 1
        let minZ = points.map { $0.z }.min() ?? 0
        let maxZ = points.map { $0.z }.max() ?? 1
        
        let rangeX = max(maxX - minX, 0.001)
        let rangeY = max(maxY - minY, 0.001)
        let rangeZ = max(maxZ - minZ, 0.001)
        
        let normalizedPoints = points.map { point in
            Point3D(
                x: ((point.x - minX) / rangeX) * 4.0 - 2.0,
                y: ((point.y - minY) / rangeY) * 4.0 - 2.0,
                z: ((point.z - minZ) / rangeZ) * 4.0 - 2.0
            )
        }
        
        return Chart3DData(
            title: chartData.title,
            chartType: chartData.chartType,
            points: normalizedPoints
        )
    }
    
    private func createScatterVisualization(_ chartData: Chart3DData) async {
        for (index, point) in chartData.points.enumerated() {
            let sphere = MeshResource.generateSphere(radius: pointSize)
            let color = getPointColor(point: point, index: index, total: chartData.points.count)
            let material = SimpleMaterial(color: color, roughness: 0.3, isMetallic: false)
            
            let pointEntity = ModelEntity(mesh: sphere, materials: [material])
            pointEntity.position = SIMD3<Float>(point.x, point.y, point.z)
            
            rootEntity.addChild(pointEntity)
        }
    }
    
    private func createBarVisualization(_ chartData: Chart3DData) async {
        // Group points by X and Z coordinates to form bars
        var barGroups: [String: [Point3D]] = [:]
        
        for point in chartData.points {
            let key = "\(Int(point.x * 10))_\(Int(point.z * 10))"
            barGroups[key, default: []].append(point)
        }
        
        for (_, points) in barGroups {
            guard let basePoint = points.first else { continue }
            
            // Create a cylinder for each bar
            let height = Float(points.count) * 0.2
            let cylinder = MeshResource.generateCylinder(height: height, radius: pointSize * 3)
            let color = getPointColor(point: basePoint, index: 0, total: 1)
            let material = SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)
            
            let barEntity = ModelEntity(mesh: cylinder, materials: [material])
            barEntity.position = SIMD3<Float>(basePoint.x, height / 2 - 2, basePoint.z)
            
            rootEntity.addChild(barEntity)
        }
    }
    
    private func createLineVisualization(_ chartData: Chart3DData) async {
        // Sort points by X coordinate for proper line connection
        let sortedPoints = chartData.points.sorted { $0.x < $1.x }
        
        // Create spheres for data points
        for (index, point) in sortedPoints.enumerated() {
            let sphere = MeshResource.generateSphere(radius: pointSize)
            let color = getPointColor(point: point, index: index, total: sortedPoints.count)
            let material = SimpleMaterial(color: color, roughness: 0.3, isMetallic: false)
            
            let pointEntity = ModelEntity(mesh: sphere, materials: [material])
            pointEntity.position = SIMD3<Float>(point.x, point.y, point.z)
            
            rootEntity.addChild(pointEntity)
        }
        
        // Create line segments between consecutive points
        for i in 0..<(sortedPoints.count - 1) {
            let start = sortedPoints[i]
            let end = sortedPoints[i + 1]
            
            let distance = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2) + pow(end.z - start.z, 2))
            let cylinder = MeshResource.generateCylinder(height: distance, radius: pointSize * 0.5)
            
            let material = SimpleMaterial(color: UIColor.systemBlue, roughness: 0.2, isMetallic: true)
            
            let lineEntity = ModelEntity(mesh: cylinder, materials: [material])
            
            // Position and orient the line segment
            let midPoint = SIMD3<Float>(
                (start.x + end.x) / 2,
                (start.y + end.y) / 2,
                (start.z + end.z) / 2
            )
            lineEntity.position = midPoint
            
            // Orient cylinder along the line
            let direction = SIMD3<Float>(end.x - start.x, end.y - start.y, end.z - start.z)
            let up = SIMD3<Float>(0, 1, 0)
            if length(direction) > 0.001 {
                let normalizedDirection = normalize(direction)
                let rotation = simd_quatf(from: up, to: normalizedDirection)
                lineEntity.transform.rotation = rotation
            }
            
            rootEntity.addChild(lineEntity)
        }
    }
    
    private func createHistogramVisualization(_ chartData: Chart3DData) async {
        // Similar to bar chart but with specific histogram styling
        await createBarVisualization(chartData)
    }
    
    private func createAreaVisualization(_ chartData: Chart3DData) async {
        // Create line visualization with filled area below
        await createLineVisualization(chartData)
        
        // Add transparent plane below the line
        let planeMesh = MeshResource.generatePlane(width: 8, depth: 8)
        let planeMaterial = SimpleMaterial(color: UIColor.systemBlue.withAlphaComponent(0.2), roughness: 0.8, isMetallic: false)
        let planeEntity = ModelEntity(mesh: planeMesh, materials: [planeMaterial])
        planeEntity.position = SIMD3<Float>(0, -2.5, 0)
        rootEntity.addChild(planeEntity)
    }
    
    private func createPieVisualization(_ chartData: Chart3DData) async {
        // Create pie slices as 3D sectors
        for (index, point) in chartData.points.enumerated() {
            let sphere = MeshResource.generateSphere(radius: pointSize * 2)
            let color = getPointColor(point: point, index: index, total: chartData.points.count)
            let material = SimpleMaterial(color: color, roughness: 0.3, isMetallic: false)
            
            let pointEntity = ModelEntity(mesh: sphere, materials: [material])
            pointEntity.position = SIMD3<Float>(point.x, point.y, point.z)
            
            rootEntity.addChild(pointEntity)
        }
    }

    private func getPointColor(point: Point3D, index: Int, total: Int) -> UIColor {
        switch colorMode {
        case .height:
            let intensity = (point.y + 2.0) / 4.0 // Normalize to 0-1
            return UIColor(hue: 0.7 - Double(intensity) * 0.5, saturation: 0.8, brightness: 0.9, alpha: 1.0)

        case .distance:
            let distance = sqrt(point.x * point.x + point.y * point.y + point.z * point.z)
            let intensity = min(distance / 3.464, 1.0) // Max distance from origin
            return UIColor(hue: Double(intensity) * 0.8, saturation: 0.9, brightness: 0.8, alpha: 1.0)

        case .category:
            let hue = Double(index) / Double(max(total, 1))
            return UIColor(hue: hue, saturation: 0.8, brightness: 0.9, alpha: 1.0)

        case .uniform:
            return UIColor.systemBlue
        }
    }

    private func addAxes() {
        // X axis (red)
        let xAxis = createAxis(color: .red, direction: .x)
        rootEntity.addChild(xAxis)
        
        // Y axis (green)
        let yAxis = createAxis(color: .green, direction: .y)
        rootEntity.addChild(yAxis)
        
        // Z axis (blue)
        let zAxis = createAxis(color: .blue, direction: .z)
        rootEntity.addChild(zAxis)
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
    
    private func addChartTitle(_ title: String) {
        if let titleMesh = try? MeshResource.generateText(
            title,
            extrusionDepth: 0.05,
            font: .systemFont(ofSize: 0.2),
            containerFrame: CGRect(x: 0, y: 0, width: 10, height: 1),
            alignment: .center
        ) {
            let titleMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let titleEntity = ModelEntity(mesh: titleMesh, materials: [titleMaterial])
            titleEntity.position = SIMD3<Float>(0, 3.5, 0)
            titleEntity.scale = SIMD3<Float>(repeating: 0.3)
            rootEntity.addChild(titleEntity)
        }
    }
    
    private func toggleAnimation() {
        isAnimating.toggle()
        
        if isAnimating {
            startRotationAnimation()
        } else {
            stopRotationAnimation()
        }
    }
    
    private func startRotationAnimation() {
        let rotationAnimation = FromToByAnimation<Transform>(
            from: rootEntity.transform,
            to: Transform(
                scale: rootEntity.transform.scale,
                rotation: rootEntity.transform.rotation * simd_quatf(angle: Float.pi * 2, axis: [0, 1, 0]),
                translation: rootEntity.transform.translation
            ),
            duration: 6.0 / Double(rotationSpeed),
            timing: .linear,
            bindTarget: .transform
        )
        
        if let animationResource = try? AnimationResource.generate(with: rotationAnimation) {
            rootEntity.playAnimation(animationResource, transitionDuration: 0.3, startsPaused: false)
        }
    }
    
    private func stopRotationAnimation() {
        rootEntity.stopAllAnimations()
    }
    
    private func resetView() {
        rootEntity.transform.rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
        rootEntity.transform.scale = SIMD3<Float>(repeating: 1.0)
        rootEntity.position = SIMD3<Float>(0, 0, 0)
    }
    
    private func getChartIcon(for chartType: String) -> String {
        switch chartType {
        case "scatter": return "chart.dots.scatter"
        case "bar": return "chart.bar"
        case "line": return "chart.line.uptrend.xyaxis"
        case "histogram": return "chart.bar.doc.horizontal"
        case "area": return "chart.line.uptrend.xyaxis.circle.fill"
        case "pie": return "chart.pie"
        default: return "chart.xyaxis.line"
        }
    }

    private enum AxisDirection {
        case x, y, z
    }
}

// MARK: - Preview Support

#Preview("3D Point Cloud - Default Data") {
    Chart3DView(dataURL: nil)
        .frame(width: 400, height: 300)
        .padding()
}

#Preview("3D Point Cloud - Wave Surface") {
    struct PreviewWrapper: View {
        @State private var dataURL: URL?

        var body: some View {
            Chart3DView(dataURL: dataURL)
                .frame(width: 400, height: 300)
                .padding()
                .onAppear {
                    // Create wave data
                    let waveData = Chart3DData.generateWave()
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted

                    if let jsonData = try? encoder.encode(waveData) {
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("wave_data.json")
                        try? jsonData.write(to: tempURL)
                        dataURL = tempURL
                    }
                }
        }
    }

    return PreviewWrapper()
}

#Preview("3D Point Cloud - Simple Points") {
    struct PreviewWrapper: View {
        @State private var dataURL: URL?

        var body: some View {
            Chart3DView(dataURL: dataURL)
                .frame(width: 600, height: 300)
                .padding()
                .onAppear {
                    // Create simple test data
                    let simpleData = Chart3DData(
                        title: "Test Points",
                        chartType: "scatter",
                        points: [
                            Point3D(x: 0.0, y: 0.0, z: 0.0),
                            Point3D(x: 0.3, y: 0.5, z: 0.2),
                            Point3D(x: 0.6, y: 0.8, z: 0.4),
                            Point3D(x: 0.7, y: 0.8, z: -0.4),
                            Point3D(x: 0.1, y: -0.8, z: 0.4),
                            Point3D(x: -0.5, y: 0.3, z: 0.6),
                            Point3D(x: -0.8, y: -0.2, z: -0.3)
                        ]
                    )

                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted

                    if let jsonData = try? encoder.encode(simpleData) {
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("simple_data.json")
                        try? jsonData.write(to: tempURL)
                        dataURL = tempURL
                    }
                }
        }
    }

    return PreviewWrapper()
}