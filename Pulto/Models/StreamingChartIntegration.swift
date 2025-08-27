//
//  StreamingChartIntegration.swift
//  Pulto3
//
//  Created by Assistant on 1/27/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import Charts
import Combine
import RealityKit

// MARK: - Streaming Chart Integration Manager

@MainActor
class StreamingChartIntegrationManager: ObservableObject {
    @Published var activeDataSources: [StreamingDataSource] = []
    @Published var chartConfigurations: [ChartConfiguration] = []
    @Published var isStreaming = false
    @Published var globalTimeWindow: TimeInterval = 60.0
    @Published var maxDataPointsPerSource = 1000
    
    private var streamingManager: RealTimeStreamingManager?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Interface
    
    func addDataSource(_ source: StreamingDataSource) {
        activeDataSources.append(source)
        source.delegate = self
    }
    
    func removeDataSource(id: String) {
        activeDataSources.removeAll { $0.id == id }
        chartConfigurations.removeAll { $0.dataSourceId == id }
    }
    
    func createChart(config: ChartConfiguration) {
        chartConfigurations.append(config)
    }
    
    func startStreaming() {
        guard !isStreaming else { return }
        
        // Configure and start the streaming manager
        setupStreamingManager()
        
        isStreaming = true
        
        // Start all data sources
        for source in activeDataSources {
            source.start()
        }
    }
    
    func stopStreaming() {
        guard isStreaming else { return }
        
        isStreaming = false
        cancellables.removeAll()
        
        // Stop all data sources
        for source in activeDataSources {
            source.stop()
        }
        
        streamingManager?.stopStreaming()
    }
    
    // MARK: - Private Methods
    
    private func setupStreamingManager() {
        streamingManager = RealTimeStreamingManager()
        
        // Create stream configurations from data sources
        let configs = activeDataSources.map { source in
            DataStreamConfig(
                id: source.id,
                name: source.name,
                type: source.streamType,
                frequency: source.frequency,
                bufferSize: maxDataPointsPerSource
            )
        }
        
        streamingManager?.startStreaming(streamConfigs: configs)
    }
}

// MARK: - Data Source Protocol

protocol StreamingDataSource: AnyObject, Identifiable {
    var id: String { get }
    var name: String { get }
    var streamType: RealTimeStreamingManager.DataStream.DataStreamType { get }
    var frequency: Double { get }
    var isActive: Bool { get set }
    
    var delegate: StreamingDataSourceDelegate? { get set }
    
    func start()
    func stop()
}

protocol StreamingDataSourceDelegate: AnyObject {
    func dataSource(_ source: StreamingDataSource, didReceiveDataPoint point: StreamingDataPoint)
}

// MARK: - Data Point Model

struct StreamingDataPoint {
    let timestamp: Date
    let value: Double
    let sourceId: String
    let coordinates: SIMD3<Float>?
    let metadata: [String: Any]
    
    // Convert to RealTime chart-compatible format
    var asRealTimeChartDataPoint: RealTimeChartDataPoint {
        RealTimeChartDataPoint(
            timestamp: timestamp,
            value: value,
            streamId: sourceId,
            coordinates: coordinates,
            metadata: metadata
        )
    }
}

// MARK: - RealTime Chart Data Point (to avoid ambiguity)
struct RealTimeChartDataPoint: Identifiable, Equatable {
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
    
    static func == (lhs: RealTimeChartDataPoint, rhs: RealTimeChartDataPoint) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Chart Configuration

struct ChartConfiguration: Identifiable {
    let id = UUID()
    let dataSourceId: String
    let chartType: ChartType
    let title: String
    let timeWindow: TimeInterval
    let yAxisRange: ClosedRange<Double>?
    let autoScale: Bool
    let maxPoints: Int
    
    static func lineChart(
        for sourceId: String,
        title: String,
        timeWindow: TimeInterval = 60.0,
        autoScale: Bool = true
    ) -> ChartConfiguration {
        ChartConfiguration(
            dataSourceId: sourceId,
            chartType: .line,
            title: title,
            timeWindow: timeWindow,
            yAxisRange: autoScale ? nil : -1.0...1.0,
            autoScale: autoScale,
            maxPoints: 1000
        )
    }
    
    static func areaChart(
        for sourceId: String,
        title: String,
        timeWindow: TimeInterval = 60.0,
        yAxisRange: ClosedRange<Double>? = nil
    ) -> ChartConfiguration {
        ChartConfiguration(
            dataSourceId: sourceId,
            chartType: .area,
            title: title,
            timeWindow: timeWindow,
            yAxisRange: yAxisRange,
            autoScale: yAxisRange == nil,
            maxPoints: 1000
        )
    }
}

// MARK: - Concrete Data Sources

// Mock sensor data source
class MockSensorDataSource: StreamingDataSource, ObservableObject {
    let id: String
    let name: String
    let streamType: RealTimeStreamingManager.DataStream.DataStreamType = .sensor
    let frequency: Double
    
    @Published var isActive = false
    weak var delegate: StreamingDataSourceDelegate?
    
    private var timer: Timer?
    private var currentValue: Double = 0
    
    init(id: String = UUID().uuidString, name: String, frequency: Double = 10.0) {
        self.id = id
        self.name = name
        self.frequency = frequency
    }
    
    func start() {
        guard !isActive else { return }
        isActive = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / frequency, repeats: true) { [weak self] _ in
            self?.generateDataPoint()
        }
    }
    
    func stop() {
        isActive = false
        timer?.invalidate()
        timer = nil
    }
    
    private func generateDataPoint() {
        // Generate realistic sensor data with noise
        currentValue += Double.random(in: -0.1...0.1)
        currentValue = max(-1.0, min(1.0, currentValue))
        
        let point = StreamingDataPoint(
            timestamp: Date(),
            value: currentValue + sin(Date().timeIntervalSinceReferenceDate * 0.5) * 0.3,
            sourceId: id,
            coordinates: SIMD3<Float>(
                Float.random(in: -1...1),
                Float(currentValue),
                Float.random(in: -1...1)
            ),
            metadata: ["type": "sensor", "unit": "volts"]
        )
        
        delegate?.dataSource(self, didReceiveDataPoint: point)
    }
}

// Financial data source
class MockFinancialDataSource: StreamingDataSource, ObservableObject {
    let id: String
    let name: String
    let streamType: RealTimeStreamingManager.DataStream.DataStreamType = .financial
    let frequency: Double
    
    @Published var isActive = false
    weak var delegate: StreamingDataSourceDelegate?
    
    private var timer: Timer?
    private var basePrice: Double = 100.0
    
    init(id: String = UUID().uuidString, name: String, frequency: Double = 1.0) {
        self.id = id
        self.name = name
        self.frequency = frequency
    }
    
    func start() {
        guard !isActive else { return }
        isActive = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / frequency, repeats: true) { [weak self] _ in
            self?.generateDataPoint()
        }
    }
    
    func stop() {
        isActive = false
        timer?.invalidate()
        timer = nil
    }
    
    private func generateDataPoint() {
        // Simulate stock price movement
        let change = Double.random(in: -0.02...0.02) // ±2% change
        basePrice *= (1.0 + change)
        basePrice = max(50.0, min(200.0, basePrice)) // Bounds
        
        let point = StreamingDataPoint(
            timestamp: Date(),
            value: basePrice,
            sourceId: id,
            coordinates: SIMD3<Float>(
                Float(Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 86400) / 86400), // Time of day
                Float(basePrice / 100.0 - 1.0), // Normalized price
                Float.random(in: -0.5...0.5)
            ),
            metadata: ["type": "price", "currency": "USD"]
        )
        
        delegate?.dataSource(self, didReceiveDataPoint: point)
    }
}

// MARK: - Streaming Chart View Component

struct StreamingChartView: View {
    let configuration: ChartConfiguration
    let dataPoints: [RealTimeChartDataPoint]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Chart header
            HStack {
                Text(configuration.title)
                    .font(.headline)
                
                Spacer()
                
                if let latest = dataPoints.last {
                    Text("\(latest.value, specifier: "%.3f")")
                        .font(.system(.subheadline, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.2))
                        .cornerRadius(6)
                }
            }
            
            // Chart content
            chartContent
                .frame(height: 200)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var chartContent: some View {
        let now = Date()
        let timeRange = now.addingTimeInterval(-configuration.timeWindow)...now
        
        Chart(dataPoints) { point in
            switch configuration.chartType {
            case .line:
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
            case .area:
                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(.blue.gradient)
                .opacity(0.7)
                
            case .bar:
                BarMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(.blue)
                
            case .point:
                PointMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(.blue)
                .symbolSize(50)
                
            case .multiStream:
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(.blue)
            }
        }
        .chartXScale(domain: timeRange)
        .chartYScale(domain: (configuration.autoScale ? nil : configuration.yAxisRange)!)
        .animation(.easeInOut(duration: 0.2), value: dataPoints)
    }
}

// MARK: - Integration Extensions

extension StreamingChartIntegrationManager: StreamingDataSourceDelegate {
    func dataSource(_ source: StreamingDataSource, didReceiveDataPoint point: StreamingDataPoint) {
        // Forward data to streaming manager or handle directly
        // This could be enhanced to work directly with the RealTimeStreamingManager
        objectWillChange.send()
    }
}

// MARK: - Convenience View

struct IntegratedStreamingChartsView: View {
    @StateObject private var integrationManager = StreamingChartIntegrationManager()
    @State private var chartData: [String: [RealTimeChartDataPoint]] = [:]
    
    var body: some View {
        VStack {
            // Controls
            HStack {
                Button(integrationManager.isStreaming ? "Stop" : "Start") {
                    if integrationManager.isStreaming {
                        integrationManager.stopStreaming()
                    } else {
                        integrationManager.startStreaming()
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button("Add Sensor") {
                    addSensorDataSource()
                }
                .buttonStyle(.bordered)
                
                Button("Add Financial") {
                    addFinancialDataSource()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            // Charts
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(integrationManager.chartConfigurations) { config in
                        StreamingChartView(
                            configuration: config,
                            dataPoints: chartData[config.dataSourceId] ?? []
                        )
                    }
                }
                .padding()
            }
        }
        .onAppear {
            setupDefaultDataSources()
        }
    }
    
    private func setupDefaultDataSources() {
        // Add default data sources and charts
        addSensorDataSource()
        addFinancialDataSource()
    }
    
    private func addSensorDataSource() {
        let source = MockSensorDataSource(name: "Temperature Sensor", frequency: 5.0)
        integrationManager.addDataSource(source)
        
        let chartConfig = ChartConfiguration.lineChart(
            for: source.id,
            title: "Temperature Data"
        )
        integrationManager.createChart(config: chartConfig)
        chartData[source.id] = []
    }
    
    private func addFinancialDataSource() {
        let source = MockFinancialDataSource(name: "Stock Price", frequency: 2.0)
        integrationManager.addDataSource(source)
        
        let chartConfig = ChartConfiguration.areaChart(
            for: source.id,
            title: "Stock Price Movement"
        )
        integrationManager.createChart(config: chartConfig)
        chartData[source.id] = []
    }
}

// MARK: - Preview

#Preview("Integrated Streaming Charts") {
    IntegratedStreamingChartsView()
        .preferredColorScheme(.dark)
}
