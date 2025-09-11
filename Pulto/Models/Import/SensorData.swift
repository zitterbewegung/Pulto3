//
//  SensorData.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/28/25.
//  Copyright © 2025 Apple. All rights reserved.
//


import SwiftUI
import Charts
import Network
import Combine
import Foundation

// MARK: - Data Models
struct SensorData: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    let sensorId: String
    let type: String
    
    enum CodingKeys: String, CodingKey {
        case timestamp, value, sensorId, type
    }
}

struct IoTJupyterNotebook: Codable, Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let lastModified: Date
    let type: String
}

struct DashboardConfig: Codable {
    let title: String
    var widgets: [WidgetConfig]
}

struct WidgetConfig: Codable, Identifiable {
    let id = UUID()
    let type: WidgetType
    let title: String
    let dataSource: String
    let position: CGPoint
    let size: CGSize
    
    enum WidgetType: String, Codable, CaseIterable {
        case lineChart = "line_chart"
        case barChart = "bar_chart"
        case gauge = "gauge"
        case table = "table"
        case metric = "metric"
    }
}

// MARK: - MQTT Manager
class MQTTManager: ObservableObject {
    @Published var isConnected = false
    @Published var receivedData: [SensorData] = []
    @Published var connectionStatus = "Disconnected"
    
    private var connection: NWConnection?
    private var cancellables = Set<AnyCancellable>()
    
    func connect(to broker: String, port: UInt16 = 1883) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(broker), port: NWEndpoint.Port(rawValue: port)!)
        connection = NWConnection(to: endpoint, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.connectionStatus = "Connected"
                    self?.sendConnectPacket()
                case .failed(let error):
                    self?.connectionStatus = "Failed: \(error.localizedDescription)"
                case .waiting(let error):
                    self?.connectionStatus = "Waiting: \(error.localizedDescription)"
                default:
                    self?.isConnected = false
                    self?.connectionStatus = "Disconnected"
                }
            }
        }
        
        connection?.start(queue: .global())
    }
    
    private func sendConnectPacket() {
        // Simplified MQTT CONNECT packet
        var packet = Data()
        packet.append(0x10) // CONNECT packet type
        packet.append(0x0C) // Remaining length
        packet.append(contentsOf: [0x00, 0x04]) // Protocol name length
        packet.append("MQTT".data(using: .utf8)!)
        packet.append(0x04) // Protocol level
        packet.append(0x00) // Connect flags
        packet.append(contentsOf: [0x00, 0x3C]) // Keep alive (60 seconds)
        
        connection?.send(content: packet, completion: .contentProcessed { error in
            if error == nil {
                self.startReceiving()
            }
        })
    }
    
    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.processReceivedData(data)
            }
            if !isComplete {
                self?.startReceiving()
            }
        }
    }
    
    private func processReceivedData(_ data: Data) {
        // Parse MQTT message and convert to SensorData
        // This is a simplified implementation
        if let jsonString = String(data: data, encoding: .utf8),
           let jsonData = jsonString.data(using: .utf8) {
            do {
                let sensorData = try JSONDecoder().decode(SensorData.self, from: jsonData)
                DispatchQueue.main.async {
                    self.receivedData.append(sensorData)
                    if self.receivedData.count > 1000 {
                        self.receivedData.removeFirst(100)
                    }
                }
            } catch {
                print("Failed to decode sensor data: \(error)")
            }
        }
    }
    
    func subscribe(to topic: String) {
        guard isConnected else { return }
        
        // Simplified MQTT SUBSCRIBE packet
        var packet = Data()
        packet.append(0x82) // SUBSCRIBE packet type
        let topicData = topic.data(using: .utf8)!
        let length = 2 + 2 + topicData.count + 1 // packet identifier + topic length + topic + QoS
        packet.append(UInt8(length))
        packet.append(contentsOf: [0x00, 0x01]) // Packet identifier
        packet.append(contentsOf: [0x00, UInt8(topicData.count)]) // Topic length
        packet.append(topicData)
        packet.append(0x00) // QoS level 0
        
        connection?.send(content: packet, completion: .contentProcessed { _ in })
    }
    
    func disconnect() {
        connection?.cancel()
        isConnected = false
        connectionStatus = "Disconnected"
    }
}

// MARK: - Jupyter Manager
class JupyterManager: ObservableObject {
    @Published var notebooks: [IoTJupyterNotebook] = []
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    
    private var baseURL: String = ""
    private var token: String = ""
    
    func connect(to url: String, token: String) {
        self.baseURL = url
        self.token = token
        
        Task {
            await fetchNotebooks()
        }
    }
    
    @MainActor
    func fetchNotebooks() async {
        guard !baseURL.isEmpty else { return }
        
        let urlString = "\(baseURL)/api/contents"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(JupyterResponse.self, from: data)
            
            self.notebooks = response.content.compactMap { item in
                guard item.type == "notebook" else { return nil }
                return IoTJupyterNotebook(
                    name: item.name,
                    path: item.path,
                    lastModified: ISO8601DateFormatter().date(from: item.lastModified) ?? Date(),
                    type: item.type
                )
            }
            self.isConnected = true
            self.connectionStatus = "Connected"
        } catch {
            self.connectionStatus = "Error: \(error.localizedDescription)"
            self.isConnected = false
        }
    }
    
    func executeNotebook(path: String) async -> String? {
        let urlString = "\(baseURL)/api/contents/\(path)"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

struct JupyterResponse: Codable {
    let content: [JupyterItem]
}

struct JupyterItem: Codable {
    let name: String
    let path: String
    let lastModified: String
    let type: String
    
    enum CodingKeys: String, CodingKey {
        case name, path, type
        case lastModified = "last_modified"
    }
}

// MARK: - Dashboard Manager
class DashboardManager: ObservableObject {
    @Published var dashboards: [DashboardConfig] = []
    @Published var activeDashboard: DashboardConfig?
    
    func createDashboard(title: String) {
        let dashboard = DashboardConfig(title: title, widgets: [])
        dashboards.append(dashboard)
        activeDashboard = dashboard
    }
    
    func addWidget(_ widget: WidgetConfig) {
        guard let dashboard = activeDashboard else { return }
        var mutableDashboard = dashboard
        mutableDashboard.widgets.append(widget)
        
        if let index = dashboards.firstIndex(where: { $0.title == dashboard.title }) {
            dashboards[index] = mutableDashboard
            activeDashboard = mutableDashboard
        }
    }
}

// MARK: - Chart Views
struct IoTLineChartView: View {
    let data: [SensorData]
    let title: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            Chart(data.suffix(50)) { item in
                LineMark(
                    x: .value("Time", item.timestamp),
                    y: .value("Value", item.value)
                )
                .foregroundStyle(.blue)
            }
            .frame(height: 200)
            .padding()
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct GaugeView: View {
    let value: Double
    let title: String
    let range: ClosedRange<Double>
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
            
            Gauge(value: value, in: range) {
                Text(title)
            } currentValueLabel: {
                Text("\(value, specifier: "%.1f")")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
            }
            .gaugeStyle(.accessoryCircular)
            .scaleEffect(1.5)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MetricView: View {
    let value: Double
    let title: String
    let unit: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value, specifier: "%.2f")")
                    .font(.system(size: 36, weight: .bold))
                
                Text(unit)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Main Dashboard View
struct DashboardView: View {
    @StateObject private var mqttManager = MQTTManager()
    @StateObject private var jupyterManager = JupyterManager()
    @StateObject private var dashboardManager = DashboardManager()
    
    @State private var showingConnectionSheet = false
    @AppStorage("defaultMQTTBroker") private var mqttBroker: String = "localhost"
    @AppStorage("defaultJupyterURL") private var jupyterURL: String = "http://localhost:8888"
    @State private var jupyterToken = ""
    
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        NavigationView {
            HStack(spacing: 20) {
                // Sidebar
                VStack(alignment: .leading, spacing: 20) {
                    connectionStatusSection
                    dataSourcesSection
                    dashboardControlsSection
                    Spacer()
                }
                .frame(width: 300)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                // Main Dashboard Area
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 300), spacing: 20)
                    ], spacing: 20) {
                        dashboardWidgets
                    }
                    .padding()
                }
            }
            .padding()
            .navigationTitle("IoT Dashboard")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Label {
                        Text("Jupyter")
                    } icon: {
                        Circle()
                            .fill(jupyterManager.isConnected ? .green : .gray)
                            .frame(width: 8, height: 8)
                    }
                    .labelStyle(.titleAndIcon)

                    Spacer()
                        .frame(width: 8)
                    
                    Button {
                        openWindow(id: "jupyter")
                    } label: {
                        Label("Jupyter", systemImage: "book")
                    }

                    Button("Connections") {
                        showingConnectionSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingConnectionSheet) {
            connectionSheet
        }
        .onAppear {
            // Auto-connect using settings values
            if !mqttManager.isConnected && !mqttBroker.isEmpty {
                mqttManager.connect(to: mqttBroker)
                mqttManager.subscribe(to: "sensors/+/data")
            }
        }
    }
    
    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connection Status")
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(mqttManager.isConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                Text("MQTT: \(mqttManager.connectionStatus)")
                    .font(.caption)
            }
            
            HStack {
                Circle()
                    .fill(jupyterManager.isConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                Text("Jupyter: \(jupyterManager.connectionStatus)")
                    .font(.caption)
            }
        }
    }
    
    private var dataSourcesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Data Sources")
                .font(.headline)
            
            Text("MQTT Messages: \(mqttManager.receivedData.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Notebooks: \(jupyterManager.notebooks.count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var dashboardControlsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dashboard Controls")
                .font(.headline)
            
            Button("Add Line Chart") {
                addLineChart()
            }
            .buttonStyle(.bordered)
            
            Button("Add Gauge") {
                addGauge()
            }
            .buttonStyle(.bordered)
            
            Button("Add Metric") {
                addMetric()
            }
            .buttonStyle(.bordered)
        }
    }
    
    @ViewBuilder
    private var dashboardWidgets: some View {
        if !mqttManager.receivedData.isEmpty {
            IoTLineChartView(
                data: mqttManager.receivedData,
                title: "Sensor Data Stream"
            )
            
            let latestValue = mqttManager.receivedData.last?.value ?? 0
            
            GaugeView(
                value: latestValue,
                title: "Current Reading",
                range: 0...100
            )
            
            MetricView(
                value: latestValue,
                title: "Latest Value",
                unit: "units"
            )
        } else {
            // Show placeholder when no data
            VStack(spacing: 16) {
                Image(systemName: "sensor.tag.radiowaves.forward")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                
                Text("No Sensor Data")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Connect to MQTT broker to start receiving data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Configure Connection") {
                    showingConnectionSheet = true
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        
        if mqttManager.receivedData.count > 10 {
            let avgValue = mqttManager.receivedData.suffix(10).map(\.value).reduce(0, +) / 10
            
            MetricView(
                value: avgValue,
                title: "10-Point Average",
                unit: "units"
            )
        }
    }
    
    private var connectionSheet: some View {
        NavigationView {
            Form {
                Section("MQTT Configuration") {
                    TextField("Broker Address", text: $mqttBroker)
                    
                    Button(mqttManager.isConnected ? "Disconnect" : "Connect") {
                        if mqttManager.isConnected {
                            mqttManager.disconnect()
                        } else {
                            mqttManager.connect(to: mqttBroker)
                            mqttManager.subscribe(to: "sensors/+/data")
                        }
                    }
                }
                
                Section("JupyterLab Configuration") {
                    TextField("Server URL", text: $jupyterURL)
                    TextField("Access Token", text: $jupyterToken)
                    
                    Button("Connect to Jupyter") {
                        jupyterManager.connect(to: jupyterURL, token: jupyterToken)
                    }
                }
            }
            .navigationTitle("Connections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingConnectionSheet = false
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private func addLineChart() {
        let widget = WidgetConfig(
            type: .lineChart,
            title: "New Line Chart",
            dataSource: "mqtt",
            position: CGPoint(x: 0, y: 0),
            size: CGSize(width: 300, height: 200)
        )
        dashboardManager.addWidget(widget)
    }
    
    private func addGauge() {
        let widget = WidgetConfig(
            type: .gauge,
            title: "New Gauge",
            dataSource: "mqtt",
            position: CGPoint(x: 0, y: 0),
            size: CGSize(width: 200, height: 200)
        )
        dashboardManager.addWidget(widget)
    }
    
    private func addMetric() {
        let widget = WidgetConfig(
            type: .metric,
            title: "New Metric",
            dataSource: "mqtt",
            position: CGPoint(x: 0, y: 0),
            size: CGSize(width: 150, height: 100)
        )
        dashboardManager.addWidget(widget)
    }
}

// MARK: - App Entry Point
struct ContentView: View {
    var body: some View {
        DashboardView()
            .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
