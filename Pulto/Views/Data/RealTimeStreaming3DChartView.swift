//
//  RealTimeStreaming3DChartView.swift
//  Pulto3
//
//  Created by Assistant on 1/27/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import Charts
import RealityKit
import Combine

// MARK: - 3D Streaming Chart View

struct RealTimeStreaming3DChartView: View {
    @StateObject private var streamingManager = RealTimeStreamingManager()
    @State private var isStreaming = false
    @State private var show2DChart = true
    @State private var show3DVisualization = true
    @State private var chartData: [ChartDataPoint] = []
    @State private var spatialEntities: [Entity] = []
    @State private var timeWindow: TimeInterval = 30.0
    @State private var maxSpatialPoints: Int = 500
    
    private var streamingCancellables = Set<AnyCancellable>()
    
    var body: some View {
        HStack(spacing: 0) {
            // Left panel - 2D Charts
            if show2DChart {
                chartPanel
                    .frame(width: 400)
                    .background(.ultraThinMaterial)
            }
            
            // Right panel - 3D Visualization
            if show3DVisualization {
                spatial3DPanel
                    .background(.black.opacity(0.9))
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { show2DChart.toggle() }) {
                    Image(systemName: "chart.xyaxis.line")
                        .foregroundColor(show2DChart ? .blue : .gray)
                }
                .help("Toggle 2D Charts")
                
                Button(action: { show3DVisualization.toggle() }) {
                    Image(systemName: "cube.transparent")
                        .foregroundColor(show3DVisualization ? .blue : .gray)
                }
                .help("Toggle 3D Visualization")
                
                Button(action: toggleStreaming) {
                    Image(systemName: isStreaming ? "stop.fill" : "play.fill")
                        .foregroundColor(isStreaming ? .red : .green)
                }
                .help(isStreaming ? "Stop Streaming" : "Start Streaming")
            }
        }
        .onAppear {
            setupStreaming()
        }
        .onDisappear {
            stopStreaming()
        }
    }
    
    // MARK: - 2D Chart Panel
    
    private var chartPanel: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack {
                Text("Real-Time Data Streams")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(chartData.count) points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            // Charts
            ScrollView(.vertical) {
                VStack(spacing: 20) {
                    // Combined multi-stream chart
                    multiStreamChart
                    
                    // Individual stream charts
                    ForEach(Array(streamingManager.dataStreams.keys), id: \.self) { streamId in
                        individualStreamChart(for: streamId)
                    }
                }
                .padding()
            }
        }
    }
    
    private var multiStreamChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All Streams")
                .font(.headline)
            
            Chart(getFilteredData()) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Stream", point.streamId))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
            .frame(height: 150)
            .chartXAxis(.hidden)
            .chartLegend(.hidden)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func individualStreamChart(for streamId: String) -> some View {
        let streamData = chartData.filter { $0.streamId == streamId }
        let stream = streamingManager.dataStreams[streamId]
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stream?.name ?? streamId)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if let latest = streamData.last {
                    Text("\(latest.value, specifier: "%.3f")")
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Chart(streamData) { point in
                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(.blue.gradient)
                .opacity(0.6)
                
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .frame(height: 80)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - 3D Spatial Panel
    
    private var spatial3DPanel: some View {
        VStack(spacing: 0) {
            // 3D controls header
            spatial3DControls
            
            // 3D RealityKit view
            RealityView { content in
                setupSpatial3DScene(content)
            } update: { content in
                updateSpatial3DScene(content)
            }
        }
    }
    
    private var spatial3DControls: some View {
        HStack {
            Text("3D Data Visualization")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Spacer()
            
            HStack(spacing: 16) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Spatial Points: \(spatialEntities.count)")
                    Text("Max: \(maxSpatialPoints)")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                
                Stepper("", value: $maxSpatialPoints, in: 100...2000, step: 100)
                    .labelsHidden()
            }
        }
        .padding()
        .background(.black.opacity(0.3))
    }
    
    private func setupSpatial3DScene(_ content: RealityViewContent) {
        // Add ambient lighting
        let ambientLight = DirectionalLight()
        ambientLight.light.intensity = 1000
        ambientLight.position = SIMD3<Float>(0, 5, 5)
        ambientLight.look(at: SIMD3<Float>(0, 0, 0), from: ambientLight.position, relativeTo: nil)
        content.add(ambientLight)
        
        // Add coordinate axes
        content.add(createAxis(color: .red, direction: .x, length: 3.0))
        content.add(createAxis(color: .green, direction: .y, length: 3.0))
        content.add(createAxis(color: .blue, direction: .z, length: 3.0))
        
        // Add ground plane
        let groundMesh = MeshResource.generatePlane(width: 6, depth: 6)
        let groundMaterial = SimpleMaterial(color: .white.withAlphaComponent(0.1), isMetallic: false)
        let ground = ModelEntity(mesh: groundMesh, materials: [groundMaterial])
        ground.position = SIMD3<Float>(0, -2, 0)
        content.add(ground)
    }
    
    private func updateSpatial3DScene(_ content: RealityViewContent) {
        // Remove old data points beyond limit
        let existingDataEntities = content.entities.filter { entity in
            entity.name.hasPrefix("datapoint_")
        }
        
        if existingDataEntities.count > maxSpatialPoints {
            let entitiesToRemove = existingDataEntities.prefix(existingDataEntities.count - maxSpatialPoints)
            for entity in entitiesToRemove {
                content.remove(entity)
            }
        }
        
        // Add new data points
        let recentData = getFilteredData().suffix(10) // Add 10 most recent points each update
        
        for point in recentData {
            guard let coordinates = point.coordinates else { continue }
            
            // Check if this point already exists
            let pointName = "datapoint_\(point.id.uuidString)"
            if content.entities.contains(where: { $0.name == pointName }) {
                continue
            }
            
            // Create sphere for data point
            let sphere = MeshResource.generateSphere(radius: 0.05)
            let color = getStreamColor(for: point.streamId)
            let material = SimpleMaterial(color: color, roughness: 0.3, isMetallic: false)
            let pointEntity = ModelEntity(mesh: sphere, materials: [material])
            
            // Position based on coordinates and time
            let timeOffset = Float(point.timestamp.timeIntervalSinceNow + timeWindow) / Float(timeWindow)
            pointEntity.position = SIMD3<Float>(
                coordinates.x * 2.0,
                coordinates.y * 2.0,
                coordinates.z * 2.0 + timeOffset * 4.0 - 2.0
            )
            
            pointEntity.name = pointName
            content.add(pointEntity)
            
            // Add animated appearance
            pointEntity.scale = SIMD3<Float>(repeating: 0.1)
            let scaleAnimation = FromToByAnimation(
                from: Transform(scale: SIMD3<Float>(repeating: 0.1)),
                to: Transform(scale: SIMD3<Float>(repeating: 1.0)),
                duration: 0.3,
                timing: .easeOut
            )
            
            if let animationResource = try? AnimationResource.generate(with: scaleAnimation) {
                pointEntity.playAnimation(animationResource)
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
        let arrowMesh = MeshResource.generateCone(height: 0.2, radius: 0.1)
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
    
    private enum AxisDirection {
        case x, y, z
    }
    
    // MARK: - Helper Methods
    
    private func setupStreaming() {
        let configs = [
            DataStreamConfig.sensorData,
            DataStreamConfig.financialData,
            DataStreamConfig.scientificData
        ]
        
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
        if chartData.count > 2000 {
            chartData.removeFirst(chartData.count - 2000)
        }
    }
    
    private func getFilteredData() -> [ChartDataPoint] {
        let now = Date()
        let cutoffTime = now.addingTimeInterval(-timeWindow)
        
        return chartData
            .filter { $0.timestamp >= cutoffTime }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    private func getStreamColor(for streamId: String) -> UIColor {
        switch streamId {
        case "sensor_01": return .systemBlue
        case "financial_01": return .systemGreen
        case "scientific_01": return .systemOrange
        default: return .systemPurple
        }
    }
    
    private func toggleStreaming() {
        if isStreaming {
            stopStreaming()
        } else {
            setupStreaming()
        }
    }
    
    private func stopStreaming() {
        streamingManager.stopStreaming()
        isStreaming = false
        streamingCancellables.removeAll()
    }
}

// MARK: - Preview

#Preview("Real-Time 3D Chart") {
    RealTimeStreaming3DChartView()
        .preferredColorScheme(.dark)
}