//
//  VolumetricChartView.swift
//  Pulto3
//
//  Created by AI Assistant on 1/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import RealityKit
import Charts

struct VolumetricChartView: View {
    let windowID: Int
    @EnvironmentObject var windowManager: WindowTypeManager
    @Environment(\.dismiss) private var dismiss
    @State private var rootEntity = Entity()
    @State private var isLoading = true
    @State private var showControls = true
    @State private var pointSize: Float = 0.03
    @State private var showAxes = true
    @State private var colorMode: ColorMode = .height
    @State private var animationSpeed: Float = 1.0
    @State private var isAnimating = false
    @State private var chartOpacity: Float = 0.8
    
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
    
    var chart3DData: Chart3DData? {
        windowManager.getWindowChart3DData(for: windowID)
    }
    
    var body: some View {
        ZStack {
            // Main 3D visualization
            RealityView { content in
                content.add(rootEntity)
                Task { await loadChart() }
            } update: { content in
                Task { await updateVisualization() }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let rotationY = Float(value.translation.width * 0.01)
                        let rotationX = Float(value.translation.height * 0.01)
                        rootEntity.transform.rotation = simd_quatf(angle: rotationY, axis: [0, 1, 0]) * simd_quatf(angle: rotationX, axis: [1, 0, 0])
                    }
            )
            
            // Control panel overlay
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
            
            // Loading overlay
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
        .onAppear {
            Task { await loadChart() }
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
        .onChange(of: chartOpacity) { _, _ in
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
            if let chartData = chart3DData {
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
            }
            
            Divider()
                .background(.white.opacity(0.3))
            
            // Visual controls
            VStack(spacing: 12) {
                // Point size control
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
                
                // Opacity control
                HStack {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(chartOpacity, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Slider(value: $chartOpacity, in: 0.1...1.0, step: 0.1)
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
            
            Divider()
                .background(.white.opacity(0.3))
            
            // Action buttons
            VStack(spacing: 8) {
                Button(action: exportChart) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export to Jupyter")
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Close")
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 10)
    }
    
    // MARK: - Chart Loading and Visualization
    
    @MainActor
    private func loadChart() async {
        isLoading = true
        await updateVisualization()
        isLoading = false
    }
    
    @MainActor
    private func updateVisualization() async {
        guard let chartData = chart3DData else { return }
        
        // Clear existing children
        rootEntity.children.removeAll()
        
        // Add lighting
        setupLighting()
        
        // Create chart visualization
        await createChartVisualization(chartData)
        
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
    
    private func createChartVisualization(_ chartData: Chart3DData) async {
        guard !chartData.points.isEmpty else { return }
        
        // Normalize data for better visualization
        let normalizedData = normalizeChartData(chartData)
        
        // Create point entities based on chart type
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
            let material = SimpleMaterial(
                color: color.withAlphaComponent(Double(chartOpacity)),
                roughness: 0.3,
                isMetallic: false
            )
            
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
            let material = SimpleMaterial(
                color: color.withAlphaComponent(Double(chartOpacity)),
                roughness: 0.4,
                isMetallic: false
            )
            
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
            let material = SimpleMaterial(
                color: color.withAlphaComponent(Double(chartOpacity)),
                roughness: 0.3,
                isMetallic: false
            )
            
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
            
            let material = SimpleMaterial(
                color: UIColor.systemBlue.withAlphaComponent(Double(chartOpacity)),
                roughness: 0.2,
                isMetallic: true
            )
            
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
        let planeMaterial = SimpleMaterial(
            color: UIColor.systemBlue.withAlphaComponent(0.2),
            roughness: 0.8,
            isMetallic: false
        )
        let planeEntity = ModelEntity(mesh: planeMesh, materials: [planeMaterial])
        planeEntity.position = SIMD3<Float>(0, -2.5, 0)
        rootEntity.addChild(planeEntity)
    }
    
    private func createPieVisualization(_ chartData: Chart3DData) async {
        // Create pie slices as 3D sectors
        for (index, point) in chartData.points.enumerated() {
            let sphere = MeshResource.generateSphere(radius: pointSize * 2)
            let color = getPointColor(point: point, index: index, total: chartData.points.count)
            let material = SimpleMaterial(
                color: color.withAlphaComponent(Double(chartOpacity)),
                roughness: 0.3,
                isMetallic: false
            )
            
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
        let xAxis = createAxis(color: .red, direction: SIMD3<Float>(1, 0, 0), length: 5.0)
        rootEntity.addChild(xAxis)
        
        // Y axis (green)
        let yAxis = createAxis(color: .green, direction: SIMD3<Float>(0, 1, 0), length: 5.0)
        rootEntity.addChild(yAxis)
        
        // Z axis (blue)
        let zAxis = createAxis(color: .blue, direction: SIMD3<Float>(0, 0, 1), length: 5.0)
        rootEntity.addChild(zAxis)
    }
    
    private func createAxis(color: UIColor, direction: SIMD3<Float>, length: Float) -> Entity {
        let axis = Entity()
        
        // Main axis line
        let cylinder = MeshResource.generateCylinder(height: length, radius: 0.02)
        let material = SimpleMaterial(color: color, isMetallic: false)
        let axisEntity = ModelEntity(mesh: cylinder, materials: [material])
        
        // Position at half length along the direction
        axisEntity.position = direction * (length / 2)
        
        // Orient cylinder along direction
        if abs(direction.y) < 0.9 { // Not vertical
            let up = SIMD3<Float>(0, 1, 0)
            let rotation = simd_quatf(from: up, to: direction)
            axisEntity.transform.rotation = rotation
        }
        
        axis.addChild(axisEntity)
        
        // Arrow head
        let cone = MeshResource.generateCone(height: 0.2, radius: 0.05)
        let arrowEntity = ModelEntity(mesh: cone, materials: [material])
        arrowEntity.position = direction * (length * 0.6)
        
        if abs(direction.y) < 0.9 {
            let up = SIMD3<Float>(0, 1, 0)
            let rotation = simd_quatf(from: up, to: direction)
            arrowEntity.transform.rotation = rotation
        }
        
        axis.addChild(arrowEntity)
        
        return axis
    }
    
    private func addChartTitle(_ title: String) {
        if let titleMesh = try? MeshResource.generateText(
            title,
            extrusionDepth: 0.05,
            font: .systemFont(ofSize: 0.2),
            containerFrame: CGRect(x: 0, y: 0, width: 10, height: 1),
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        ) {
            let titleMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let titleEntity = ModelEntity(mesh: titleMesh, materials: [titleMaterial])
            titleEntity.position = SIMD3<Float>(0, 3.5, 0)
            titleEntity.scale = SIMD3<Float>(repeating: 0.3)
            rootEntity.addChild(titleEntity)
        }
    }
    
    // MARK: - Actions
    
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
            duration: 6.0 / Double(animationSpeed),
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
    
    private func exportChart() {
        guard let chartData = chart3DData else { return }
        
        // Generate enhanced Python code for the chart
        let pythonCode = generateEnhancedPythonCode(for: chartData)
        windowManager.updateWindowContent(windowID, content: pythonCode)
        
        // Add chart-specific template
        windowManager.updateWindowTemplate(windowID, template: .matplotlib)
        
        // Add tags
        windowManager.addWindowTag(windowID, tag: "3d-chart")
        windowManager.addWindowTag(windowID, tag: chartData.chartType)
        windowManager.addWindowTag(windowID, tag: "volumetric")
    }
    
    private func generateEnhancedPythonCode(for chartData: Chart3DData) -> String {
        return """
        # \(chartData.title)
        # Generated from VisionOS Volumetric Chart View
        # Chart Type: \(chartData.chartType.capitalized)
        # Data Points: \(chartData.points.count)
        
        import numpy as np
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d import Axes3D
        import plotly.graph_objects as go
        import plotly.express as px
        
        # Extract data points
        x_data = \(chartData.points.map { $0.x })
        y_data = \(chartData.points.map { $0.y })
        z_data = \(chartData.points.map { $0.z })
        
        # Create 3D visualization with matplotlib
        fig = plt.figure(figsize=(12, 8))
        ax = fig.add_subplot(111, projection='3d')
        
        # Plot based on chart type
        if '\(chartData.chartType)' == 'scatter':
            scatter = ax.scatter(x_data, y_data, z_data, 
                               c=z_data, cmap='viridis', 
                               s=50, alpha=0.8)
            plt.colorbar(scatter)
        elif '\(chartData.chartType)' == 'line':
            ax.plot(x_data, y_data, z_data, 'b-', linewidth=2, markersize=6, marker='o')
        elif '\(chartData.chartType)' == 'bar':
            ax.bar3d(x_data, z_data, np.zeros_like(x_data), 
                    0.5, 0.5, y_data, alpha=0.8)
        else:
            # Default to scatter
            ax.scatter(x_data, y_data, z_data, alpha=0.8)
        
        ax.set_title('\(chartData.title)')
        ax.set_xlabel('X Axis')
        ax.set_ylabel('Y Axis')
        ax.set_zlabel('Z Axis')
        
        plt.show()
        
        # Interactive plot with Plotly
        if '\(chartData.chartType)' == 'scatter':
            fig_plotly = go.Figure(data=[go.Scatter3d(
                x=x_data, y=y_data, z=z_data,
                mode='markers',
                marker=dict(
                    size=5,
                    color=z_data,
                    colorscale='Viridis',
                    opacity=0.8
                )
            )])
        elif '\(chartData.chartType)' == 'line':
            fig_plotly = go.Figure(data=[go.Scatter3d(
                x=x_data, y=y_data, z=z_data,
                mode='lines+markers',
                line=dict(width=4),
                marker=dict(size=4)
            )])
        else:
            fig_plotly = go.Figure(data=[go.Scatter3d(
                x=x_data, y=y_data, z=z_data,
                mode='markers'
            )])
        
        fig_plotly.update_layout(
            title='\(chartData.title)',
            scene=dict(
                xaxis_title='X Axis',
                yaxis_title='Y Axis',
                zaxis_title='Z Axis'
            )
        )
        fig_plotly.show()
        
        print(f"3D \(chartData.chartType.capitalized) chart with {len(x_data)} data points")
        print("Exported from VisionOS Volumetric Chart View")
        """
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
}

#Preview {
    VolumetricChartView(windowID: 1)
        .environmentObject(WindowTypeManager.shared)
}