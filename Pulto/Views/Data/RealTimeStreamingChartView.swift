//
//  RealTimeStreamingChartView.swift
//  Pulto3
//
//  Created by Assistant on 1/27/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import Charts
import Combine
import RealityKit

// MARK: - Real-Time Chart Data Models

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    let streamId: String
    let coordinates: SIMD3<Float>?
    let metadata: [String: Any]
    
    // For Chart compatibility
    var timeInterval: TimeInterval {
        timestamp.timeIntervalSinceReferenceDate
    }
}

enum ChartType: String, CaseIterable {
    case line = "Line Chart"
    case area = "Area Chart"
    case bar = "Bar Chart"
    case point = "Point Chart"
    case multiStream = "Multi-Stream"
    
    var icon: String {
        switch self {
        case .line: return "chart.xyaxis.line"
        case .area: return "chart.line.uptrend.xyaxis"
        case .bar: return "chart.bar"
        case .point: return "point.3.connected.trianglepath.dotted"
        case .multiStream: return "waveform"
        }
    }
}

// MARK: - Real-Time Streaming Chart View

struct RealTimeStreamingChartView: View {
    @StateObject private var streamingManager = RealTimeStreamingManager()
    @State private var selectedChartType: ChartType = .line
    @State private var isStreaming = false
    @State private var chartData: [ChartDataPoint] = []
    @State private var selectedStreams: Set<String> = []
    @State private var timeWindow: TimeInterval = 60.0 // Show last 60 seconds
    @State private var maxDataPoints: Int = 1000
    @State private var updateRate: Double = 0.1 // 100ms updates
    @State private var showStatistics = true
    @State private var autoScale = true
    @State private var yAxisRange: ClosedRange<Double> = -1.0...1.0
    
    // Performance tracking
    @State private var fps: Double = 0
    @State private var lastFrameTime = Date()
    @State private var frameCount = 0
    
    private var streamingCancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            headerView
            
            // Main chart area
            mainChartView
                .background(Color.black.opacity(0.05))
        }
        .onAppear {
            setupStreaming()
        }
        .onDisappear {
            stopStreaming()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            // Streaming controls
            streamingControls
            
            Spacer()
            
            // Chart type picker
            chartTypePicker
            
            Spacer()
            
            // Statistics and settings
            statisticsView
        }
        .padding()
        .background(.regularMaterial)
    }
    
    private var streamingControls: some View {
        HStack(spacing: 12) {
            // Start/Stop button
            Button(action: toggleStreaming) {
                HStack(spacing: 6) {
                    Image(systemName: isStreaming ? "stop.fill" : "play.fill")
                    Text(isStreaming ? "Stop" : "Start")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isStreaming ? Color.red : Color.green)
                .cornerRadius(8)
            }
            
            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(streamingManager.isStreaming ? .green : .gray)
                    .frame(width: 8, height: 8)
                
                Text(streamingManager.streamingStatus.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var chartTypePicker: some View {
        Picker("Chart Type", selection: $selectedChartType) {
            ForEach(ChartType.allCases, id: \.self) { type in
                Label(type.rawValue, systemImage: type.icon)
                    .tag(type)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 400)
    }
    
    private var statisticsView: some View {
        HStack(spacing: 16) {
            // Performance stats
            if showStatistics {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("FPS: \(fps, specifier: "%.1f")")
                    Text("Points: \(chartData.count)")
                    Text("Streams: \(streamingManager.dataStreams.count)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // Settings button
            Menu {
                settingsMenu
            } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var settingsMenu: some View {
        VStack {
            Section("Display") {
                Toggle("Show Statistics", isOn: $showStatistics)
                Toggle("Auto Scale", isOn: $autoScale)
            }
            
            Section("Performance") {
                Stepper("Max Points: \(maxDataPoints)", value: $maxDataPoints, in: 100...5000, step: 100)
                Stepper("Time Window: \(Int(timeWindow))s", value: $timeWindow, in: 10...300, step: 10)
            }
            
            Section("Streams") {
                ForEach(Array(streamingManager.dataStreams.keys), id: \.self) { streamId in
                    Toggle(streamingManager.dataStreams[streamId]?.name ?? streamId, 
                           isOn: Binding(
                               get: { selectedStreams.contains(streamId) },
                               set: { isSelected in
                                   if isSelected {
                                       selectedStreams.insert(streamId)
                                   } else {
                                       selectedStreams.remove(streamId)
                                   }
                               }
                           ))
                }
            }
        }
    }
    
    // MARK: - Main Chart View
    
    private var mainChartView: some View {
        VStack(spacing: 0) {
            // Chart area
            chartView
                .frame(minHeight: 400)
            
            // Stream selection and controls
            streamSelectionView
                .padding()
                .background(.ultraThinMaterial)
        }
    }
    
    @ViewBuilder
    private var chartView: some View {
        let filteredData = getFilteredData()
        let now = Date()
        let timeRange = (now.addingTimeInterval(-timeWindow))...now
        
        Chart(filteredData) { point in
            switch selectedChartType {
            case .line:
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Stream", point.streamId))
                .lineStyle(StrokeStyle(lineWidth: 2))
                
            case .area:
                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Stream", point.streamId))
                .opacity(0.7)
                
            case .bar:
                BarMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Stream", point.streamId))
                
            case .point:
                PointMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Stream", point.streamId))
                .symbolSize(30)
                
            case .multiStream:
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Stream", point.streamId))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .opacity(0.8)
        }
        }
        .chartXScale(domain: timeRange)
        .chartYScale(domain: autoScale ? .automatic : yAxisRange)
        .chartAngle(.degrees(0))
        .chartXAxis {
            AxisMarks(values: .stride(by: .second, count: Int(timeWindow / 6))) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute().second(), centered: false)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartLegend(position: .top, alignment: .leading) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(selectedStreams), id: \.self) { streamId in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(streamColor(for: streamId))
                                .frame(width: 8, height: 8)
                            Text(streamingManager.dataStreams[streamId]?.name ?? streamId)
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .animation(.easeInOut(duration: updateRate), value: chartData)
        .padding()
    }
    
    private var streamSelectionView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(streamingManager.dataStreams.keys), id: \.self) { streamId in
                    streamCard(for: streamId)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func streamCard(for streamId: String) -> some View {
        let stream = streamingManager.dataStreams[streamId]
        let isSelected = selectedStreams.contains(streamId)
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(streamColor(for: streamId))
                    .frame(width: 12, height: 12)
                
                Text(stream?.name ?? streamId)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .gray)
            }
            
            HStack {
                Text("\(stream?.frequency ?? 0, specifier: "%.1f") Hz")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(stream?.buffer.size ?? 0) pts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Latest value
            if let latestValue = getLatestValue(for: streamId) {
                Text("\(latestValue, specifier: "%.3f")")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.semibold)
            }
        }
        .padding(12)
        .frame(width: 140, height: 80)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            if isSelected {
                selectedStreams.remove(streamId)
            } else {
                selectedStreams.insert(streamId)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupStreaming() {
        // Initialize with default stream configurations
        let configs = [
            DataStreamConfig.sensorData,
            DataStreamConfig.financialData,
            DataStreamConfig.scientificData
        ]
        
        streamingManager.startStreaming(streamConfigs: configs)
        
        // Select all streams by default
        selectedStreams = Set(configs.map { $0.id })
        
        // Set up data collection timer
        Timer.publish(every: updateRate, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                updateChartData()
                updateFPS()
            }
            .store(in: &streamingCancellables)
    }
    
    private func updateChartData() {
        guard streamingManager.isStreaming else { return }
        
        let now = Date()
        let cutoffTime = now.addingTimeInterval(-timeWindow)
        
        // Collect data from selected streams
        var newPoints: [ChartDataPoint] = []
        
        for streamId in selectedStreams {
            guard let stream = streamingManager.dataStreams[streamId] else { continue }
            
            // Read available data points from the circular buffer
            while let dataPoint = stream.buffer.peek() {
                let chartPoint = ChartDataPoint(
                    timestamp: dataPoint.timestamp,
                    value: dataPoint.value,
                    streamId: streamId,
                    coordinates: dataPoint.coordinates,
                    metadata: dataPoint.metadata
                )
                
                newPoints.append(chartPoint)
                _ = stream.buffer.read() // Remove the point after reading
            }
        }
        
        // Add new points and remove old ones
        chartData.append(contentsOf: newPoints)
        chartData.removeAll { $0.timestamp < cutoffTime }
        
        // Limit total points for performance
        if chartData.count > maxDataPoints {
            chartData.removeFirst(chartData.count - maxDataPoints)
        }
    }
    
    private func updateFPS() {
        frameCount += 1
        let currentTime = Date()
        let timeDiff = currentTime.timeIntervalSince(lastFrameTime)
        
        if timeDiff >= 1.0 {
            fps = Double(frameCount) / timeDiff
            frameCount = 0
            lastFrameTime = currentTime
        }
    }
    
    private func getFilteredData() -> [ChartDataPoint] {
        let now = Date()
        let cutoffTime = now.addingTimeInterval(-timeWindow)
        
        return chartData
            .filter { $0.timestamp >= cutoffTime }
            .filter { selectedStreams.contains($0.streamId) }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    private func streamColor(for streamId: String) -> Color {
        // Generate consistent colors for streams
        let colors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .yellow, .mint]
        let hash = abs(streamId.hashValue)
        return colors[hash % colors.count]
    }
    
    private func getLatestValue(for streamId: String) -> Double? {
        return chartData
            .filter { $0.streamId == streamId }
            .last?.value
    }
    
    private func toggleStreaming() {
        if isStreaming {
            stopStreaming()
        } else {
            let configs = [
                DataStreamConfig.sensorData,
                DataStreamConfig.financialData,
                DataStreamConfig.scientificData
            ]
            streamingManager.startStreaming(streamConfigs: configs)
        }
        isStreaming = streamingManager.isStreaming
    }
    
    private func stopStreaming() {
        streamingManager.stopStreaming()
        isStreaming = false
        streamingCancellables.removeAll()
    }
}

// MARK: - Extensions

extension RealTimeStreamingManager.StreamingStatus {
    var description: String {
        switch self {
        case .idle: return "Idle"
        case .connecting: return "Connecting..."
        case .streaming: return "Streaming"
        case .paused: return "Paused"
        case .error(let message): return "Error: \(message)"
        }
    }
}

// MARK: - Preview

#Preview("Real-Time Streaming Chart") {
    RealTimeStreamingChartView()
        .preferredColorScheme(.dark)
}

#Preview("Real-Time Streaming Chart - Light") {
    RealTimeStreamingChartView()
        .preferredColorScheme(.light)
}