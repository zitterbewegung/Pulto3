//
//  RealTimeStreaming3DVolumetricView.swift
//  Pulto3
//
//  Created by Assistant on 1/27/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import Charts
import RealityKit
import Combine

// MARK: - Real-Time Streaming 3D Volumetric View

struct RealTimeStreaming3DVolumetricView: View {
    let windowID: Int
    let windowData: NewWindowID
    
    @EnvironmentObject private var windowManager: WindowTypeManager
    @EnvironmentObject private var entityManager: EntityLifecycleManager
    @StateObject private var streamingManager = RealTimeStreamingManager()
    
    @State private var isStreaming = false
    @State private var chartData: [ChartDataPoint] = []
    @State private var spatialEntities: [Entity] = []
    @State private var timeWindow: TimeInterval = 30.0
    @State private var maxSpatialPoints: Int = 1000
    @State private var showControls = true
    @State private var selectedVisualizationMode: VisualizationMode = .realTimeFlow
    @State private var streamingCancellables = Set<AnyCancellable>()
    
    enum VisualizationMode: String, CaseIterable {
        case realTimeFlow = "Real-Time Flow"
        case spatialCloud = "Spatial Cloud"
        case dataTrails = "Data Trails"
        case networkGraph = "Network Graph"
        
        var icon: String {
            switch self {
            case .realTimeFlow: return "waveform.path"
            case .spatialCloud: return "cloud.fill"
            case .dataTrails: return "line.3.connected.angle"
            case .networkGraph: return "network"
            }
        }
        
        var description: String {
            switch self {
            case .realTimeFlow: return "Flowing particles representing data streams"
            case .spatialCloud: return "Point cloud of data values in 3D space"
            case .dataTrails: return "Trailing paths showing data movement"
            case .networkGraph: return "Connected nodes showing data relationships"
            }
        }
    }

    var body: some View {
        ZStack {
            // Main 3D RealityKit view
            RealityView { content in
                setupScene(content)
            } update: { content in
                updateScene(content)
            }
            
            // Overlay controls
            if showControls {
                controlsOverlay
            }
        }
        .onAppear {
            startStreaming()
        }
        .onDisappear {
            stopStreaming()
        }
        .gesture(
            TapGesture(count: 2)
                .onEnded {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showControls.toggle()
                    }
                }
        )
    }
    
    // MARK: - Controls Overlay
    
    private var controlsOverlay: some View {
        VStack {
            HStack {
                streamingStatusIndicator
                Spacer()
                visualizationModeSelector
            }
            
            Spacer()
            
            HStack {
                streamingControls
                Spacer()
                performanceStats
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding()
    }
    
    private var streamingStatusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isStreaming ? .green : .red)
                .frame(width: 12, height: 12)
                .scaleEffect(isStreaming ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isStreaming)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isStreaming ? "STREAMING" : "STOPPED")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isStreaming ? .green : .red)
                
                Text("\(streamingManager.dataStreams.count) streams")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .cornerRadius(8)
    }
    
    private var visualizationModeSelector: some View {
        Menu {
            ForEach(VisualizationMode.allCases, id: \.self) { mode in
                Button {
                    selectedVisualizationMode = mode
                    recreateVisualization()
                } label: {
                    HStack {
                        Image(systemName: mode.icon)
                        VStack(alignment: .leading) {
                            Text(mode.rawValue)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if mode == selectedVisualizationMode {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selectedVisualizationMode.icon)
                Text(selectedVisualizationMode.rawValue)
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial)
            .cornerRadius(8)
        }
    }
    
    private var streamingControls: some View {
        HStack(spacing: 8) {
            Button(action: toggleStreaming) {
                Image(systemName: isStreaming ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button(action: resetVisualization) {
                Image(systemName: "arrow.clockwise")
                    .font(.title2)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Stepper("Points: \(maxSpatialPoints)", value: $maxSpatialPoints, in: 100...2000, step: 100)
                .font(.caption)
        }
    }
    
    private var performanceStats: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Data Points: \(chartData.count)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("Entities: \(spatialEntities.count)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("Memory: \(estimatedMemoryUsage())MB")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial)
        .cornerRadius(6)
    }
    
    // MARK: - RealityKit Scene Setup
    
    private func setupScene(_ content: RealityViewContent) {
        // Clear any existing content
        content.entities.removeAll()
        
        // Add ambient lighting
        let ambientLight = DirectionalLight()
        ambientLight.light.intensity = 1000
        ambientLight.position = SIMD3<Float>(2, 3, 2)
        ambientLight.look(at: SIMD3<Float>(0, 0, 0), from: ambientLight.position, relativeTo: nil)
        content.add(ambientLight)
        
        // Add coordinate axes
        content.add(createAxis(color: .red, direction: .x, length: 2.0))
        content.add(createAxis(color: .green, direction: .y, length: 2.0))
        content.add(createAxis(color: .blue, direction: .z, length: 2.0))
        
        // Add reference grid
        content.add(createGrid(size: 4.0, divisions: 20))
        
        // Register entities with lifecycle manager
        for entity in content.entities {
            entityManager.registerEntity(entity, for: windowID)
        }
    }
    
    private func updateScene(_ content: RealityViewContent) {
        // Remove old data entities beyond limit
        let dataEntities = content.entities.filter { entity in
            entity.name.hasPrefix("streaming_data_")
        }
        
        if dataEntities.count > maxSpatialPoints {
            let entitiesToRemove = dataEntities.prefix(dataEntities.count - maxSpatialPoints)
            for entity in entitiesToRemove {
                content.remove(entity)
                entityManager.unregisterEntity(entity, for: windowID)
            }
        }
        
        // Add new data points based on visualization mode
        let recentData = chartData.suffix(20) // Process 20 most recent points
        
        for point in recentData {
            let entityName = "streaming_data_\(point.id.uuidString)"
            
            // Check if entity already exists
            if content.entities.contains(where: { $0.name == entityName }) {
                continue
            }
            
            let entity = createDataPointEntity(for: point, mode: selectedVisualizationMode)
            entity.name = entityName
            
            content.add(entity)
            entityManager.registerEntity(entity, for: windowID)
            spatialEntities.append(entity)
            
            // Add animation based on mode
            addDataPointAnimation(to: entity, mode: selectedVisualizationMode)
        }
        
        // Update existing entities with flow animations
        if selectedVisualizationMode == .realTimeFlow {
            updateFlowAnimations(content)
        }
    }
    
    private func createDataPointEntity(for point: ChartDataPoint, mode: VisualizationMode) -> ModelEntity {
        let size: Float = 0.03
        let position = calculateSpatialPosition(for: point, mode: mode)
        let color = getStreamColor(for: point.streamId)
        
        let mesh: MeshResource
        let material: Material
        
        switch mode {
        case .realTimeFlow:
            mesh = MeshResource.generateSphere(radius: size)
            material = SimpleMaterial(color: color.withAlphaComponent(0.8), roughness: 0.2, isMetallic: false)
            
        case .spatialCloud:
            mesh = MeshResource.generateSphere(radius: size * 0.8)
            material = SimpleMaterial(color: color.withAlphaComponent(0.6), roughness: 0.5, isMetallic: false)
            
        case .dataTrails:
            mesh = MeshResource.generateBox(width: size * 2, height: size * 0.5, depth: size * 0.5)
            material = SimpleMaterial(color: color.withAlphaComponent(0.7), roughness: 0.3, isMetallic: true)
            
        case .networkGraph:
            mesh = MeshResource.generateSphere(radius: size * 1.2)
            material = SimpleMaterial(color: color.withAlphaComponent(0.9), roughness: 0.1, isMetallic: true)
        }
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = position
        
        return entity
    }
    
    private func calculateSpatialPosition(for point: ChartDataPoint, mode: VisualizationMode) -> SIMD3<Float> {
        guard let coordinates = point.coordinates else {
            // Generate position based on timestamp and value if no coordinates
            let timeOffset = Float(point.timestamp.timeIntervalSinceNow + timeWindow) / Float(timeWindow)
            return SIMD3<Float>(
                Float.random(in: -1...1),
                Float(point.value * 2.0 - 1.0), // Normalize value to -1...1 range
                timeOffset * 4.0 - 2.0
            )
        }
        
        switch mode {
        case .realTimeFlow:
            // Flow along Z-axis with time
            let timeOffset = Float(point.timestamp.timeIntervalSinceNow + timeWindow) / Float(timeWindow)
            return SIMD3<Float>(
                coordinates.x * 1.5,
                coordinates.y * 1.5,
                timeOffset * 3.0 - 1.5
            )
            
        case .spatialCloud:
            // Natural spatial distribution
            return coordinates * 1.5
            
        case .dataTrails:
            // Linear trail based on stream ID
            let streamIndex = Float(abs(point.streamId.hashValue) % 5)
            let timeOffset = Float(point.timestamp.timeIntervalSinceNow + timeWindow) / Float(timeWindow)
            return SIMD3<Float>(
                (streamIndex - 2.0) * 0.5,
                Float(point.value),
                timeOffset * 4.0 - 2.0
            )
            
        case .networkGraph:
            // Clustered around origin with value-based distance
            let distance = Float(abs(point.value)) * 1.5
            let angle = Float(point.streamId.hashValue) * 0.1
            return SIMD3<Float>(
                distance * cos(angle),
                Float(point.value) * 0.5,
                distance * sin(angle)
            )
        }
    }
    
    private func addDataPointAnimation(to entity: ModelEntity, mode: VisualizationMode) {
        switch mode {
        case .realTimeFlow:
            // Flowing animation towards camera
            let moveAnimation = FromToByAnimation(
                from: Transform(translation: entity.position),
                to: Transform(translation: entity.position + SIMD3<Float>(0, 0, 2)),
                duration: 5.0,
                timing: .linear
            )
            
            if let animationResource = try? AnimationResource.generate(with: moveAnimation) {
                entity.playAnimation(animationResource)
            }
            
        case .spatialCloud:
            // Gentle floating animation
            let floatAnimation = FromToByAnimation(
                from: Transform(translation: entity.position),
                to: Transform(translation: entity.position + SIMD3<Float>(0, 0.1, 0)),
                duration: 2.0,
                timing: .easeInOut
            )
            
            if let animationResource = try? AnimationResource.generate(with: floatAnimation) {
                entity.playAnimation(animationResource.repeat())
            }
            
        case .dataTrails:
            // Scaling pulse animation
            let scaleAnimation = FromToByAnimation(
                from: Transform(scale: SIMD3<Float>(repeating: 0.5)),
                to: Transform(scale: SIMD3<Float>(repeating: 1.2)),
                duration: 1.0,
                timing: .easeInOut
            )
            
            if let animationResource = try? AnimationResource.generate(with: scaleAnimation) {
                entity.playAnimation(animationResource.repeat(count: 3))
            }
            
        case .networkGraph:
            // Rotation animation
            let rotationAnimation = FromToByAnimation(
                from: Transform(rotation: simd_quatf(angle: 0, axis: [0, 1, 0])),
                to: Transform(rotation: simd_quatf(angle: .pi * 2, axis: [0, 1, 0])),
                duration: 4.0,
                timing: .linear
            )
            
            if let animationResource = try? AnimationResource.generate(with: rotationAnimation) {
                entity.playAnimation(animationResource.repeat())
            }
        }
    }
    
    private func updateFlowAnimations(_ content: RealityViewContent) {
        // Update positions of flowing entities to create continuous motion
        let flowEntities = content.entities.filter { entity in
            entity.name.hasPrefix("streaming_data_") && selectedVisualizationMode == .realTimeFlow
        }
        
        for entity in flowEntities {
            // Move entities along Z-axis to simulate flow
            entity.position.z += 0.02
            
            // Remove entities that have flowed too far
            if entity.position.z > 3.0 {
                content.remove(entity)
                entityManager.unregisterEntity(entity, for: windowID)
                spatialEntities.removeAll { $0 === entity }
            }
        }
    }
    
    private func createAxis(color: UIColor, direction: AxisDirection, length: Float) -> Entity {
        let axis = Entity()
        
        // Create axis line
        let mesh = MeshResource.generateBox(
            width: direction == .x ? length : 0.02,
            height: direction == .y ? length : 0.02,
            depth: direction == .z ? length : 0.02
        )
        let material = SimpleMaterial(color: color, isMetallic: false)
        let axisModel = ModelEntity(mesh: mesh, materials: [material])
        axisModel.position = SIMD3<Float>(
            direction == .x ? length / 2 : 0,
            direction == .y ? length / 2 : 0,
            direction == .z ? length / 2 : 0
        )
        axis.addChild(axisModel)
        
        // Create arrowhead
        let arrowMesh = MeshResource.generateCone(height: 0.15, radius: 0.08)
        let arrowEntity = ModelEntity(mesh: arrowMesh, materials: [material])
        
        switch direction {
        case .x:
            arrowEntity.position = SIMD3<Float>(length + 0.1, 0, 0)
            arrowEntity.transform.rotation = simd_quatf(angle: -.pi/2, axis: [0, 0, 1])
        case .y:
            arrowEntity.position = SIMD3<Float>(0, length + 0.1, 0)
        case .z:
            arrowEntity.position = SIMD3<Float>(0, 0, length + 0.1)
            arrowEntity.transform.rotation = simd_quatf(angle: .pi/2, axis: [1, 0, 0])
        }
        
        axis.addChild(arrowEntity)
        return axis
    }
    
    private func createGrid(size: Float, divisions: Int) -> Entity {
        let grid = Entity()
        let lineWidth: Float = 0.005
        
        for i in 0...divisions {
            let position = (Float(i) / Float(divisions) - 0.5) * size
            
            // X-direction lines
            let xLineMesh = MeshResource.generateBox(width: size, height: lineWidth, depth: lineWidth)
            let xLineMaterial = SimpleMaterial(color: .white.withAlphaComponent(0.1), isMetallic: false)
            let xLineEntity = ModelEntity(mesh: xLineMesh, materials: [xLineMaterial])
            xLineEntity.position = SIMD3<Float>(0, -size/2, position)
            grid.addChild(xLineEntity)
            
            // Z-direction lines
            let zLineMesh = MeshResource.generateBox(width: lineWidth, height: lineWidth, depth: size)
            let zLineMaterial = SimpleMaterial(color: .white.withAlphaComponent(0.1), isMetallic: false)
            let zLineEntity = ModelEntity(mesh: zLineMesh, materials: [zLineMaterial])
            zLineEntity.position = SIMD3<Float>(position, -size/2, 0)
            grid.addChild(zLineEntity)
        }
        
        return grid
    }
    
    private enum AxisDirection {
        case x, y, z
    }
    
    // MARK: - Streaming Management
    
    private func startStreaming() {
        // Configure streaming based on window tags
        let configs = determineStreamConfigs()
        streamingManager.startStreaming(streamConfigs: configs)
        isStreaming = true
        
        // Set up data collection
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                updateChartData()
            }
            .store(in: &streamingCancellables)
    }
    
    private func stopStreaming() {
        streamingManager.stopStreaming()
        isStreaming = false
        streamingCancellables.removeAll()
        
        // Clean up entities
        Task { @MainActor in
            entityManager.cleanupWindow(windowID)
        }
    }
    
    private func toggleStreaming() {
        if isStreaming {
            stopStreaming()
        } else {
            startStreaming()
        }
    }
    
    private func resetVisualization() {
        chartData.removeAll()
        spatialEntities.removeAll()
        
        Task { @MainActor in
            entityManager.cleanupWindow(windowID)
        }
    }
    
    private func recreateVisualization() {
        // Clear existing visualization and recreate with new mode
        resetVisualization()
        
        // Restart with new mode
        if isStreaming {
            stopStreaming()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startStreaming()
            }
        }
    }
    
    private func determineStreamConfigs() -> [DataStreamConfig] {
        // Determine configs based on window tags or use defaults
        let tags = windowData.state.tags
        
        if tags.contains("Sensor Data Simulation") {
            return [
                DataStreamConfig(id: "temp_sensor", name: "Temperature", type: .sensor, frequency: 5.0, bufferSize: 500),
                DataStreamConfig(id: "humidity_sensor", name: "Humidity", type: .sensor, frequency: 3.0, bufferSize: 500),
                DataStreamConfig(id: "pressure_sensor", name: "Pressure", type: .sensor, frequency: 2.0, bufferSize: 500)
            ]
        } else if tags.contains("Financial Data Stream") {
            return [
                DataStreamConfig(id: "stock_price", name: "Stock Price", type: .financial, frequency: 1.0, bufferSize: 300)
            ]
        } else if tags.contains("Scientific Data Stream") {
            return [
                DataStreamConfig(id: "experiment_data", name: "Experiment Data", type: .scientific, frequency: 20.0, bufferSize: 1000)
            ]
        } else {
            // Default multi-stream configuration
            return [
                DataStreamConfig.sensorData,
                DataStreamConfig.financialData,
                DataStreamConfig.scientificData
            ]
        }
    }
    
    private func updateChartData() {
        guard streamingManager.isStreaming else { return }
        
        let now = Date()
        let cutoffTime = now.addingTimeInterval(-timeWindow)
        
        // Collect new data points
        var newPoints: [ChartDataPoint] = []
        
        for (streamId, stream) in streamingManager.dataStreams {
            while let dataPoint = stream.buffer.peek() {
                let chartPoint = ChartDataPoint(
                    timestamp: dataPoint.timestamp,
                    value: dataPoint.value,
                    streamId: streamId,
                    coordinates: dataPoint.coordinates,
                    metadata: dataPoint.metadata
                )
                newPoints.append(chartPoint)
                _ = stream.buffer.read()
            }
        }
        
        // Update chart data
        chartData.append(contentsOf: newPoints)
        chartData.removeAll { $0.timestamp < cutoffTime }
        
        // Limit for performance
        if chartData.count > maxSpatialPoints * 2 {
            chartData.removeFirst(chartData.count - maxSpatialPoints)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getStreamColor(for streamId: String) -> UIColor {
        switch streamId {
        case "sensor_01", "temp_sensor": return .systemBlue
        case "financial_01", "stock_price": return .systemGreen
        case "scientific_01", "experiment_data": return .systemOrange
        case "humidity_sensor": return .systemCyan
        case "pressure_sensor": return .systemPurple
        default: return .systemRed
        }
    }
    
    private func estimatedMemoryUsage() -> String {
        let entityCount = spatialEntities.count
        let dataPointCount = chartData.count
        
        // Rough estimation: each entity ~100KB, each data point ~1KB
        let estimatedBytes = (entityCount * 100_000) + (dataPointCount * 1000)
        let estimatedMB = Double(estimatedBytes) / (1024 * 1024)
        
        return String(format: "%.1f", estimatedMB)
    }
}

// MARK: - Preview

#Preview {
    // Create a sample window for preview
    let sampleWindow = NewWindowID(
        id: 1,
        windowType: .spatial,
        position: WindowPosition()
    )
    
    RealTimeStreaming3DVolumetricView(
        windowID: 1,
        windowData: sampleWindow
    )
    .environmentObject(WindowTypeManager.shared)
    .environmentObject(EntityLifecycleManager.shared)
}