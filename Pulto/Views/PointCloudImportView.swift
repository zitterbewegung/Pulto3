//
//  PointCloudImportView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import RealityKit
import UniformTypeIdentifiers

struct PointCloudImportView: View {
    let windowID: Int
    
    @State private var importedPointCloud: PointCloudData?
    @State private var showingVolumetricView = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showingSettings = false
    @State private var importConfiguration = PointCloudImporter.ImportConfiguration.default
    
    @StateObject private var windowManager = WindowTypeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let pointCloud = importedPointCloud {
                    if showingVolumetricView {
                        VolumetricPointCloudView(
                            pointCloud: pointCloud,
                            windowID: windowID,
                            onClose: {
                                showingVolumetricView = false
                            }
                        )
                    } else {
                        importedPointCloudView(pointCloud)
                    }
                } else {
                    importView
                }
            }
            .navigationTitle("Point Cloud Import")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings") {
                        showingSettings = true
                    }
                    .disabled(isImporting)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            ImportSettingsView(configuration: $importConfiguration)
        }
        .alert("Import Error", isPresented: .constant(importError != nil)) {
            Button("OK") {
                importError = nil
            }
        } message: {
            if let error = importError {
                Text(error)
            }
        }
    }
    
    // MARK: - Import View
    
    private var importView: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue.gradient)
                
                Text("Import Point Cloud")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Import real point cloud data and visualize it in volumetric space")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Import Section
            VStack(spacing: 20) {
                PointCloudFilePicker { pointCloudData in
                    handleImportComplete(pointCloudData)
                }
                
                // Quick info about supported formats
                supportedFormatsView
            }
            
            Spacer()
            
            // Sample data option
            sampleDataSection
        }
        .padding()
    }
    
    private var supportedFormatsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supported Formats")
                .font(.headline)
                .foregroundStyle(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(PointCloudImporter.SupportedFormat.allCases, id: \.self) { format in
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(format.rawValue.uppercased())
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            Text(format.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
    
    private var sampleDataSection: some View {
        VStack(spacing: 16) {
            Text("Or try sample data")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                Button("Sample Sphere") {
                    let sampleData = PointCloudImporter.generateDemoSphere(radius: 10.0, points: 2000)
                    handleImportComplete(sampleData)
                }
                .buttonStyle(.bordered)
                
                Button("Sample Cube") {
                    let sampleData = PointCloudDemo.generateNoisyCubeData(size: 15.0, pointsPerFace: 300)
                    handleImportComplete(sampleData)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // MARK: - Imported Point Cloud View
    
    private func importedPointCloudView(_ pointCloud: PointCloudData) -> some View {
        VStack(spacing: 24) {
            // Header with point cloud info
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import Successful")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(pointCloud.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Point cloud statistics
                pointCloudStatsView(pointCloud)
            }
            
            // Preview and actions
            VStack(spacing: 20) {
                // 2D Preview
                pointCloudPreview(pointCloud)
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        showingVolumetricView = true
                    }) {
                        Label("View in Volumetric Space", systemImage: "cube.transparent")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    HStack(spacing: 12) {
                        Button("Save to Window") {
                            savePointCloudToWindow(pointCloud)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Import Another") {
                            importedPointCloud = nil
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func pointCloudStatsView(_ pointCloud: PointCloudData) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Points",
                value: "\(pointCloud.totalPoints)",
                icon: "dot.scope",
                color: .blue
            )
            
            StatCard(
                title: "Type",
                value: pointCloud.demoType,
                icon: "tag",
                color: .green
            )
            
            StatCard(
                title: "Parameters",
                value: "\(pointCloud.parameters.count)",
                icon: "slider.horizontal.3",
                color: .orange
            )
        }
    }
    
    private func pointCloudPreview(_ pointCloud: PointCloudData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2D Preview")
                .font(.headline)
            
            // Simple 2D scatter plot preview
            Canvas { context, size in
                guard !pointCloud.points.isEmpty else { return }
                
                let points = pointCloud.points.prefix(min(500, pointCloud.points.count)) // Limit for performance
                
                // Calculate bounds
                let xValues = points.map { $0.x }
                let yValues = points.map { $0.y }
                
                let minX = xValues.min() ?? 0
                let maxX = xValues.max() ?? 0
                let minY = yValues.min() ?? 0
                let maxY = yValues.max() ?? 0
                
                let rangeX = maxX - minX
                let rangeY = maxY - minY
                let maxRange = max(rangeX, rangeY)
                
                guard maxRange > 0 else { return }
                
                let padding: CGFloat = 20
                let drawSize = min(size.width, size.height) - (padding * 2)
                
                for point in points {
                    let x = padding + ((point.x - minX) / rangeX) * drawSize
                    let y = padding + ((point.y - minY) / rangeY) * drawSize
                    
                    let intensity = point.intensity ?? 0.5
                    let color = Color.blue.opacity(0.3 + intensity * 0.7)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                        with: .color(color)
                    )
                }
            }
            .frame(height: 200)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)
            
            Text("Showing \(min(500, pointCloud.points.count)) of \(pointCloud.totalPoints) points")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleImportComplete(_ pointCloudData: PointCloudData) {
        importedPointCloud = pointCloudData
        
        // Update the window with the imported data
        var state = windowManager.getWindow(for: windowID)?.state ?? WindowState()
        state.pointCloudData = pointCloudData
        state.lastModified = Date()
        windowManager.updateWindowState(windowID, state: state)
    }
    
    private func savePointCloudToWindow(_ pointCloud: PointCloudData) {
        var state = windowManager.getWindow(for: windowID)?.state ?? WindowState()
        state.pointCloudData = pointCloud
        state.content = pointCloud.toPythonCode()
        state.lastModified = Date()
        
        windowManager.updateWindowState(windowID, state: state)
        
        dismiss()
    }
}

// MARK: - Volumetric Point Cloud View

struct VolumetricPointCloudView: View {
    let pointCloud: PointCloudData
    let windowID: Int
    let onClose: () -> Void
    
    @State private var rotationAngle: Float = 0
    @State private var scale: Float = 1.0
    @State private var autoRotate = true
    @State private var showControls = true
    @State private var selectedVisualizationMode: VisualizationMode = .points
    @State private var pointSize: Float = 0.02
    @State private var colorMode: ColorMode = .intensity
    
    enum VisualizationMode: String, CaseIterable {
        case points = "Points"
        case spheres = "Spheres"
        case cubes = "Cubes"
        
        var iconName: String {
            switch self {
            case .points: return "circle.fill"
            case .spheres: return "sphere.fill"
            case .cubes: return "cube.fill"
            }
        }
    }
    
    enum ColorMode: String, CaseIterable {
        case intensity = "Intensity"
        case height = "Height"
        case distance = "Distance"
        case uniform = "Uniform"
        
        var iconName: String {
            switch self {
            case .intensity: return "paintbrush.fill"
            case .height: return "arrow.up.and.down"
            case .distance: return "scope"
            case .uniform: return "paintpalette.fill"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Main 3D view
            RealityView { content in
                setupPointCloudScene(content)
            } update: { content in
                updatePointCloudScene(content)
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = Float(value)
                    }
            )
            
            // Controls overlay
            if showControls {
                VStack {
                    Spacer()
                    controlsPanel
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Top bar
            VStack {
                topBar
                Spacer()
            }
        }
        .onAppear {
            startAutoRotation()
        }
        .preferredColorScheme(.dark) // Better for 3D visualization
    }
    
    // MARK: - UI Components
    
    private var topBar: some View {
        HStack {
            Button("Close") {
                onClose()
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Text(pointCloud.title)
                .font(.headline)
                .foregroundStyle(.white)
            
            Spacer()
            
            Button(showControls ? "Hide Controls" : "Show Controls") {
                withAnimation(.easeInOut) {
                    showControls.toggle()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.regularMaterial)
    }
    
    private var controlsPanel: some View {
        VStack(spacing: 16) {
            // Point cloud info
            HStack {
                Text("\(pointCloud.totalPoints) points")
                Spacer()
                Text(pointCloud.demoType)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            // Visualization controls
            VStack(spacing: 12) {
                // Visualization mode
                VStack(alignment: .leading, spacing: 8) {
                    Text("Visualization Mode")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Mode", selection: $selectedVisualizationMode) {
                        ForEach(VisualizationMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.iconName)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Color mode
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color Mode")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Color", selection: $colorMode) {
                        ForEach(ColorMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.iconName)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Point size
                VStack(alignment: .leading, spacing: 8) {
                    Text("Point Size: \(String(format: "%.3f", pointSize))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Slider(value: $pointSize, in: 0.005...0.1) {
                        Text("Point Size")
                    }
                }
                
                // Scale
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scale: \(String(format: "%.2f", scale))x")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Slider(value: $scale, in: 0.1...5.0) {
                        Text("Scale")
                    }
                }
                
                // Auto-rotation toggle
                Toggle("Auto Rotate", isOn: $autoRotate)
                    .font(.subheadline)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Reset View") {
                    withAnimation(.easeInOut) {
                        scale = 1.0
                        rotationAngle = 0
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Export Data") {
                    exportPointCloudData()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
        .padding()
    }
    
    // MARK: - RealityKit Scene Setup
    
    private func setupPointCloudScene(_ content: RealityViewContent) {
        // Create main point cloud entity
        let pointCloudEntity = createPointCloudEntity()
        pointCloudEntity.name = "pointCloud"
        content.add(pointCloudEntity)
        
        // Add lighting
        setupLighting(content)
        
        // Position the point cloud
        pointCloudEntity.position = [0, 0, -2]
        
        print("✅ VolumetricPointCloudView: Created point cloud with \(pointCloud.points.count) points")
    }
    
    private func updatePointCloudScene(_ content: RealityViewContent) {
        guard let pointCloudEntity = content.entities.first(where: { $0.name == "pointCloud" }) else {
            return
        }
        
        // Update rotation
        if autoRotate {
            pointCloudEntity.transform.rotation = simd_quatf(angle: rotationAngle, axis: [0, 1, 0])
        }
        
        // Update scale
        pointCloudEntity.scale = [scale, scale, scale]
        
        // Recreate point cloud if visualization settings changed
        // (In a real implementation, you'd want to optimize this)
    }
    
    private func createPointCloudEntity() -> Entity {
        let entity = Entity()
        
        switch selectedVisualizationMode {
        case .points:
            createPointEntities(entity)
        case .spheres:
            createSphereEntities(entity)
        case .cubes:
            createCubeEntities(entity)
        }
        
        return entity
    }
    
    private func createPointEntities(_ parent: Entity) {
        // For performance, limit the number of points rendered
        let maxRenderPoints = min(5000, pointCloud.points.count)
        let step = max(1, pointCloud.points.count / maxRenderPoints)
        
        for (index, point) in pointCloud.points.enumerated() {
            if index % step != 0 { continue }
            
            let pointEntity = Entity()
            
            // Create a small sphere for each point
            let sphereMesh = MeshResource.generateSphere(radius: pointSize)
            let color = getColorForPoint(point, index: index)
            
            var material = UnlitMaterial()
            material.color = .init(tint: color)
            
            pointEntity.components.set(ModelComponent(mesh: sphereMesh, materials: [material]))
            pointEntity.position = [Float(point.x), Float(point.y), Float(point.z)]
            
            parent.addChild(pointEntity)
        }
        
        print("✅ Created \(parent.children.count) point entities")
    }
    
    private func createSphereEntities(_ parent: Entity) {
        let maxRenderPoints = min(2000, pointCloud.points.count) // Fewer for performance
        let step = max(1, pointCloud.points.count / maxRenderPoints)
        
        for (index, point) in pointCloud.points.enumerated() {
            if index % step != 0 { continue }
            
            let sphereEntity = Entity()
            let sphereMesh = MeshResource.generateSphere(radius: pointSize * 2)
            let color = getColorForPoint(point, index: index)
            
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: color)
            material.metallic = 0.0
            material.roughness = 0.5
            
            sphereEntity.components.set(ModelComponent(mesh: sphereMesh, materials: [material]))
            sphereEntity.position = [Float(point.x), Float(point.y), Float(point.z)]
            
            parent.addChild(sphereEntity)
        }
    }
    
    private func createCubeEntities(_ parent: Entity) {
        let maxRenderPoints = min(1500, pointCloud.points.count) // Even fewer for cubes
        let step = max(1, pointCloud.points.count / maxRenderPoints)
        
        for (index, point) in pointCloud.points.enumerated() {
            if index % step != 0 { continue }
            
            let cubeEntity = Entity()
            let cubeMesh = MeshResource.generateBox(size: pointSize * 3)
            let color = getColorForPoint(point, index: index)
            
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: color)
            material.metallic = 0.1
            material.roughness = 0.3
            
            cubeEntity.components.set(ModelComponent(mesh: cubeMesh, materials: [material]))
            cubeEntity.position = [Float(point.x), Float(point.y), Float(point.z)]
            
            parent.addChild(cubeEntity)
        }
    }
    
    private func getColorForPoint(_ point: PointCloudData.PointData, index: Int) -> UIColor {
        switch colorMode {
        case .intensity:
            let intensity = point.intensity ?? 0.5
            return UIColor(red: CGFloat(intensity), green: CGFloat(1.0 - intensity), blue: 0.5, alpha: 1.0)
            
        case .height:
            // Calculate relative height
            let yValues = pointCloud.points.map { $0.y }
            let minY = yValues.min() ?? 0
            let maxY = yValues.max() ?? 0
            let range = maxY - minY
            
            let normalizedHeight = range > 0 ? (point.y - minY) / range : 0.5
            return UIColor(red: CGFloat(normalizedHeight), green: 0.5, blue: CGFloat(1.0 - normalizedHeight), alpha: 1.0)
            
        case .distance:
            // Distance from origin
            let distance = sqrt(point.x * point.x + point.y * point.y + point.z * point.z)
            let maxDistance = pointCloud.points.map { sqrt($0.x * $0.x + $0.y * $0.y + $0.z * $0.z) }.max() ?? 1.0
            let normalizedDistance = distance / maxDistance
            
            return UIColor(red: CGFloat(normalizedDistance), green: CGFloat(1.0 - normalizedDistance), blue: 0.5, alpha: 1.0)
            
        case .uniform:
            return UIColor.systemBlue
        }
    }
    
    private func setupLighting(_ content: RealityViewContent) {
        // Add ambient light
        let ambientLight = Entity()
        ambientLight.components.set(AmbientLightComponent(color: .white, intensity: 0.3))
        content.add(ambientLight)
        
        // Add directional light
        let directionalLight = Entity()
        directionalLight.components.set(DirectionalLightComponent(color: .white, intensity: 1.0))
        directionalLight.look(at: [0, 0, -2], from: [2, 2, 2], relativeTo: nil)
        content.add(directionalLight)
    }
    
    // MARK: - Animation and Interaction
    
    private func startAutoRotation() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            if autoRotate {
                rotationAngle += 0.01
            }
        }
    }
    
    private func exportPointCloudData() {
        // Implementation for exporting point cloud data
        print("📤 Exporting point cloud data...")
        // This could save to files, copy to clipboard, etc.
    }
}

// MARK: - Import Settings View

struct ImportSettingsView: View {
    @Binding var configuration: PointCloudImporter.ImportConfiguration
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Performance Limits") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Max Points: \(configuration.maxPoints)")
                        Slider(value: .init(
                            get: { Double(configuration.maxPoints) },
                            set: { configuration.maxPoints = Int($0) }
                        ), in: 1000...2_000_000, step: 1000)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Max File Size: \(ByteCountFormatter.string(fromByteCount: configuration.maxFileSize, countStyle: .file))")
                        Slider(value: .init(
                            get: { Double(configuration.maxFileSize) },
                            set: { configuration.maxFileSize = Int64($0) }
                        ), in: 1_000_000...500_000_000, step: 1_000_000)
                    }
                }
                
                Section("Point Processing") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Skip Every N Points: \(configuration.skipEveryNPoints)")
                        Slider(value: .init(
                            get: { Double(configuration.skipEveryNPoints) },
                            set: { configuration.skipEveryNPoints = Int($0) }
                        ), in: 1...20, step: 1)
                    }
                    
                    Toggle("Normalize Coordinates", isOn: $configuration.normalizeCoordinates)
                    Toggle("Center at Origin", isOn: $configuration.centerAtOrigin)
                    Toggle("Auto-Detect Format", isOn: $configuration.autoDetectFormat)
                }
                
                Section("Reset") {
                    Button("Reset to Defaults") {
                        configuration = .default
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Import Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Helper Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    PointCloudImportView(windowID: 1)
}