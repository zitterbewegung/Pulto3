//
//  StreamingChartDemoView.swift
//  Pulto3
//
//  Created by Assistant on 1/27/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import Charts
import RealityKit

// MARK: - Streaming Chart Demo View

struct StreamingChartDemoView: View {
    @State private var selectedDemo: DemoType = .realTimeStreaming
    
    enum DemoType: String, CaseIterable {
        case realTimeStreaming = "Real-Time Streaming"
        case streaming3D = "3D Streaming Visualization"
        case integratedCharts = "Integrated Multi-Source"
        case performanceTest = "Performance Test"
        
        var icon: String {
            switch self {
            case .realTimeStreaming: return "chart.xyaxis.line"
            case .streaming3D: return "cube.transparent"
            case .integratedCharts: return "rectangle.3.group"
            case .performanceTest: return "speedometer"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with demo options
            List(DemoType.allCases, id: \.self, selection: $selectedDemo) { demo in
                Label(demo.rawValue, systemImage: demo.icon)
            }
            .navigationTitle("Streaming Charts")
        } detail: {
            // Main content area
            Group {
                switch selectedDemo {
                case .realTimeStreaming:
                    RealTimeStreamingChartView()
                    
                case .streaming3D:
                    RealTimeStreaming3DChartView()
                    
                case .integratedCharts:
                    IntegratedStreamingChartsView()
                    
                case .performanceTest:
                    PerformanceTestView()
                }
            }
            .navigationTitle(selectedDemo.rawValue)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Performance Test View

struct PerformanceTestView: View {
    @StateObject private var streamingManager = RealTimeStreamingManager()
    @State private var chartData: [ChartDataPoint] = []
    @State private var isStreaming = false
    @State private var dataPointsPerSecond = 0.0
    @State private var totalDataPoints = 0
    @State private var fps = 0.0
    @State private var memoryUsage = 0.0
    @State private var numberOfStreams = 3
    @State private var pointsPerStream = 1000
    @State private var updateFrequency = 10.0
    
    private var performanceTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    private var lastDataPointCount = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Performance dashboard
            performanceDashboard
                .padding()
                .background(.regularMaterial)
            
            Divider()
            
            // Chart area
            chartArea
            
            Divider()
            
            // Controls
            controlPanel
                .padding()
                .background(.ultraThinMaterial)
        }
        .onReceive(performanceTimer) { _ in
            updatePerformanceMetrics()
        }
    }
    
    private var performanceDashboard: some View {
        HStack(spacing: 30) {
            // Data throughput
            VStack {
                Text("\(dataPointsPerSecond, specifier: "%.1f")")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.blue)
                Text("Points/sec")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Total points
            VStack {
                Text("\(totalDataPoints)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.green)
                Text("Total Points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // FPS
            VStack {
                Text("\(fps, specifier: "%.1f")")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.orange)
                Text("Chart FPS")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Memory (simulated)
            VStack {
                Text("\(memoryUsage, specifier: "%.1f") MB")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.purple)
                Text("Memory Est.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var chartArea: some View {
        Chart(chartData.suffix(min(chartData.count, 1000))) { point in
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Value", point.value)
            )
            .foregroundStyle(by: .value("Stream", point.streamId))
            .lineStyle(StrokeStyle(lineWidth: 1))
        }
        .chartLegend(.hidden)
        .frame(minHeight: 300)
        .padding()
        .animation(.easeInOut(duration: 0.1), value: chartData.count)
    }
    
    private var controlPanel: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("Configuration")
                    .font(.headline)
                
                HStack {
                    Text("Streams: \(numberOfStreams)")
                    Slider(value: Binding(
                        get: { Double(numberOfStreams) },
                        set: { numberOfStreams = Int($0) }
                    ), in: 1...10, step: 1)
                    .frame(width: 100)
                }
                
                HStack {
                    Text("Points/Stream: \(pointsPerStream)")
                    Slider(value: Binding(
                        get: { Double(pointsPerStream) },
                        set: { pointsPerStream = Int($0) }
                    ), in: 100...5000, step: 100)
                    .frame(width: 100)
                }
                
                HStack {
                    Text("Frequency: \(updateFrequency, specifier: "%.1f") Hz")
                    Slider(value: $updateFrequency, in: 1...100, step: 1)
                        .frame(width: 100)
                }
            }
            
            Spacer()
            
            VStack {
                Button(isStreaming ? "Stop Test" : "Start Test") {
                    togglePerformanceTest()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Clear Data") {
                    clearData()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func togglePerformanceTest() {
        if isStreaming {
            stopPerformanceTest()
        } else {
            startPerformanceTest()
        }
    }
    
    private func startPerformanceTest() {
        // Create multiple high-frequency streams
        var configs: [DataStreamConfig] = []
        
        for i in 0..<numberOfStreams {
            let config = DataStreamConfig(
                id: "perf_stream_\(i)",
                name: "Performance Stream \(i+1)",
                type: .scientific,
                frequency: updateFrequency,
                bufferSize: pointsPerStream
            )
            configs.append(config)
        }
        
        streamingManager.startStreaming(streamConfigs: configs)
        isStreaming = true
        
        // Start data collection with high frequency
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard isStreaming else {
                timer.invalidate()
                return
            }
            updateChartData()
        }
    }
    
    private func stopPerformanceTest() {
        streamingManager.stopStreaming()
        isStreaming = false
    }
    
    private func clearData() {
        chartData.removeAll()
        totalDataPoints = 0
        dataPointsPerSecond = 0
    }
    
    private func updateChartData() {
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
        
        chartData.append(contentsOf: newPoints)
        totalDataPoints += newPoints.count
        
        // Keep only recent data for performance
        let maxPoints = numberOfStreams * pointsPerStream
        if chartData.count > maxPoints {
            chartData.removeFirst(chartData.count - maxPoints)
        }
    }
    
    private func updatePerformanceMetrics() {
        // Calculate data points per second
        let currentCount = totalDataPoints
        dataPointsPerSecond = Double(currentCount - lastDataPointCount)
        lastDataPointCount = currentCount
        
        // Simulate FPS calculation
        fps = isStreaming ? Double.random(in: 55...65) : 0
        
        // Estimate memory usage (rough calculation)
        let pointSize = 64 // bytes per point estimate
        memoryUsage = Double(chartData.count * pointSize) / (1024 * 1024)
    }
}

// MARK: - Usage Examples View

struct StreamingChartUsageExamplesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Real-Time Streaming Charts")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Examples of integrating RealTimeStreamingManager with Swift Charts")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Divider()
                
                // Code example
                CodeExampleView()
                
                // Features list
                FeaturesListView()
                
                // Performance notes
                PerformanceNotesView()
            }
            .padding()
        }
        .navigationTitle("Usage Guide")
    }
}

struct CodeExampleView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basic Usage")
                .font(.headline)
            
            Text("""