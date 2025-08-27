import SwiftUI
import UniformTypeIdentifiers
import Charts
import RealityKit

struct UnifiedImportSheet: View {
    @EnvironmentObject private var windowManager: WindowTypeManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    @State private var selectedFileType: FileType = .unknown
    @State private var importedFileURL: URL?
    @State private var pointCloudData: PointCloudData?
    @State private var csvData: CSVData?
    @State private var chartRecommendations: [ChartScore] = []
    @State private var errorMessage: String?
    @State private var isProcessing = false
    @State private var showStreamingOptions = false
    @State private var streamingConfig = StreamingImportConfig()
    
    // Real-time streaming state
    @StateObject private var streamingManager = RealTimeStreamingManager()
    @State private var isStreamingActive = false
    @State private var selectedStreamingMode: StreamingMode = .realTimeData
    
    enum FileType {
        case unknown
        case csv
        case pointCloudPLY
        case pointCloudXYZ
        case pointCloudPCD
        case pointCloudPTS
        case modelUSDZ
        case modelOBJ
        case modelSTL
        case streamingData  // New type for streaming data
        
        var description: String {
            switch self {
            case .unknown: return "Unknown File"
            case .csv: return "CSV Data File"
            case .pointCloudPLY: return "PLY Point Cloud"
            case .pointCloudXYZ: return "XYZ Point Cloud"
            case .pointCloudPCD: return "PCD Point Cloud"
            case .pointCloudPTS: return "PTS Point Cloud"
            case .modelUSDZ: return "USDZ 3D Model"
            case .modelOBJ: return "OBJ 3D Model"
            case .modelSTL: return "STL 3D Model"
            case .streamingData: return "Real-Time Stream"
            }
        }
        
        var icon: String {
            switch self {
            case .unknown: return "doc"
            case .csv: return "tablecells"
            case .pointCloudPLY, .pointCloudXYZ, .pointCloudPCD, .pointCloudPTS: return "circle.grid.3x3"
            case .modelUSDZ, .modelOBJ, .modelSTL: return "cube"
            case .streamingData: return "waveform"
            }
        }
        
        var color: Color {
            switch self {
            case .unknown: return .gray
            case .csv: return .green
            case .pointCloudPLY, .pointCloudXYZ, .pointCloudPCD, .pointCloudPTS: return .cyan
            case .modelUSDZ, .modelOBJ, .modelSTL: return .red
            case .streamingData: return .orange
            }
        }
    }
    
    enum StreamingMode: String, CaseIterable {
        case realTimeData = "Real-Time Data Stream"
        case sensorSimulation = "Sensor Data Simulation"
        case financialData = "Financial Data Stream"
        case scientificData = "Scientific Data Stream"
        
        var icon: String {
            switch self {
            case .realTimeData: return "waveform"
            case .sensorSimulation: return "sensor.tag.radiowaves.forward"
            case .financialData: return "chart.line.uptrend.xyaxis"
            case .scientificData: return "atom"
            }
        }
        
        var description: String {
            switch self {
            case .realTimeData: return "Multi-stream real-time data visualization"
            case .sensorSimulation: return "Simulated IoT sensor data with noise"
            case .financialData: return "Stock price and trading data streams"
            case .scientificData: return "High-frequency scientific measurements"
            }
        }
    }
    
    struct StreamingImportConfig {
        var updateFrequency: Double = 10.0 // Hz
        var numberOfStreams: Int = 3
        var dataPointsPerSecond: Int = 50
        var enableSpatialVisualization: Bool = true
        var chartType: ChartType = .multiStream
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isProcessing {
                    processingView
                } else if isStreamingActive {
                    streamingActiveView
                } else if showStreamingOptions {
                    streamingConfigurationView
                } else if pointCloudData != nil {
                    pointCloudPreviewView
                } else if csvData != nil {
                    csvPreviewView
                } else {
                    welcomeView
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Dismiss") {
                        if isStreamingActive {
                            streamingManager.stopStreaming()
                        }
                        dismiss()
                    }
                }
            }
            .navigationTitle("Import & Stream")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [
                    .commaSeparatedText,    // CSV files
                    .plainText,             // For XYZ/PTS files
                    .usdz,                  // USDZ files
                    .data                   // Fallback for any file type
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 30) {
            Image(systemName: "arrow.up.doc")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Import & Stream Data")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Import files or create real-time data streams")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Enhanced Supported Formats Section
            VStack(alignment: .leading, spacing: 20) {
                Text("Import Options")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 16) {
                    UnifiedImportFormatCard(
                        title: "Data Files", 
                        formats: ["CSV", "TSV"], 
                        icon: "tablecells", 
                        color: .green
                    )
                    UnifiedImportFormatCard(
                        title: "Point Clouds", 
                        formats: ["PLY", "XYZ", "PCD", "PTS"], 
                        icon: "circle.grid.3x3", 
                        color: .cyan
                    )
                    UnifiedImportFormatCard(
                        title: "3D Models", 
                        formats: ["USDZ", "OBJ", "STL"], 
                        icon: "cube", 
                        color: .red
                    )
                    UnifiedImportFormatCard(
                        title: "Real-Time Streams", 
                        formats: ["Live Data", "Simulation"], 
                        icon: "waveform", 
                        color: .orange
                    )
                }
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: { isImporting = true }) {
                    Label("Choose File", systemImage: "folder")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: { showStreamingOptions = true }) {
                    Label("Start Stream", systemImage: "waveform")
                        .font(.headline)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Streaming Configuration View
    
    private var streamingConfigurationView: some View {
        VStack(spacing: 24) {
            HStack {
                Image(systemName: "waveform")
                    .font(.title)
                    .foregroundColor(.orange)
                
                Text("Configure Real-Time Stream")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            // Streaming mode selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Stream Type")
                    .font(.headline)
                
                Picker("Streaming Mode", selection: $selectedStreamingMode) {
                    ForEach(StreamingMode.allCases, id: \.self) { mode in
                        HStack {
                            Image(systemName: mode.icon)
                            Text(mode.rawValue)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                
                Text(selectedStreamingMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Configuration controls
            VStack(alignment: .leading, spacing: 16) {
                Text("Stream Configuration")
                    .font(.headline)
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Update Frequency")
                        Spacer()
                        Text("\(streamingConfig.updateFrequency, specifier: "%.1f") Hz")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $streamingConfig.updateFrequency, in: 1...100, step: 1)
                    
                    HStack {
                        Text("Number of Streams")
                        Spacer()
                        Text("\(streamingConfig.numberOfStreams)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(streamingConfig.numberOfStreams) },
                        set: { streamingConfig.numberOfStreams = Int($0) }
                    ), in: 1...10, step: 1)
                    
                    Toggle("Enable 3D Spatial Visualization", isOn: $streamingConfig.enableSpatialVisualization)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chart Type")
                        Picker("Chart Type", selection: $streamingConfig.chartType) {
                            ForEach([ChartType.line, .area, .multiStream], id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
            
            // Action buttons
            HStack {
                Button("Back") {
                    showStreamingOptions = false
                }
                
                Spacer()
                
                Button(action: startRealTimeStream) {
                    Label("Start Streaming", systemImage: "play.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    // MARK: - Streaming Active View
    
    private var streamingActiveView: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "waveform")
                    .font(.title)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading) {
                    Text("Stream Active")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(selectedStreamingMode.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Streaming status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 12, height: 12)
                        .scaleEffect(streamingManager.isStreaming ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(), value: streamingManager.isStreaming)
                    
                    Text("LIVE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            
            // Stream statistics
            VStack(spacing: 12) {
                HStack {
                    StatisticCard(
                        title: "Data Points",
                        value: "\(streamingManager.processedDataPoints)",
                        icon: "circle.fill",
                        color: .blue
                    )
                    
                    StatisticCard(
                        title: "Streams",
                        value: "\(streamingManager.dataStreams.count)",
                        icon: "waveform",
                        color: .orange
                    )
                    
                    StatisticCard(
                        title: "Frequency",
                        value: "\(streamingConfig.updateFrequency, specifier: "%.0f") Hz",
                        icon: "timer",
                        color: .green
                    )
                }
            }
            
            // Mini preview of streaming data (simplified chart)
            if streamingManager.isStreaming {
                RealTimePreviewChart(streamingManager: streamingManager)
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Text("Choose how to visualize your streaming data:")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 16) {
                    Button(action: openIn2DChart) {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.title)
                            Text("2D Charts")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                    
                    if streamingConfig.enableSpatialVisualization {
                        Button(action: openIn3DVisualization) {
                            VStack(spacing: 8) {
                                Image(systemName: "cube.transparent")
                                    .font(.title)
                                Text("3D Spatial")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.purple)
                            .cornerRadius(12)
                        }
                    }
                    
                    Button(action: openInCombinedView) {
                        VStack(spacing: 8) {
                            Image(systemName: "rectangle.split.3x1")
                                .font(.title)
                            Text("Combined")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(12)
                    }
                }
            }
            
            Button("Stop Streaming") {
                stopStreaming()
            }
            .foregroundColor(.red)
        }
        .padding()
    }
    
    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Processing File...")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let fileType = getFileType() {
                HStack {
                    Image(systemName: fileType.icon)
                        .font(.title)
                        .foregroundColor(fileType.color)
                    
                    Text(fileType.description)
                        .font(.headline)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - CSV Preview with Chart Recommendations
    
    private var csvPreviewView: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "tablecells")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    Text("CSV Data Preview")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                if let data = csvData {
                    // Data summary
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("File:")
                            Spacer()
                            Text(importedFileURL?.lastPathComponent ?? "Unknown")
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Rows:")
                            Spacer()
                            Text("\(data.rows.count)")
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Columns:")
                            Spacer()
                            Text("\(data.headers.count)")
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Chart recommendations
                    if !chartRecommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recommended Visualizations")
                                .font(.headline)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(chartRecommendations.prefix(4), id: \.recommendation) { score in
                                    ChartRecommendationCard(
                                        recommendation: score.recommendation,
                                        score: score.score,
                                        reasoning: score.reasoning,
                                        onSelect: { 
                                            createChartWithRecommendation(score.recommendation)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    // Option to convert to streaming
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Real-Time Options")
                            .font(.headline)
                        
                        Button(action: convertToStreamingData) {
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text("Convert to Streaming Data")
                                        .fontWeight(.medium)
                                    Text("Simulate real-time updates from this CSV data")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                HStack {
                    Button("Back") {
                        csvData = nil
                        chartRecommendations = []
                        importedFileURL = nil
                    }
                    
                    Spacer()
                    
                    Button(action: createDataTableWindow) {
                        Label("Open as Data Table", systemImage: "tablecells")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
    }
    
    private var pointCloudPreviewView: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "circle.grid.3x3")
                    .font(.title)
                    .foregroundColor(.cyan)
                
                Text("Point Cloud Preview")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding(.horizontal)
            
            if let data = pointCloudData {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("File:")
                        Spacer()
                        Text(importedFileURL?.lastPathComponent ?? "Unknown")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Points:")
                        Spacer()
                        Text("\(data.totalPoints)")

                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Format:")
                        Spacer()
                        Text(selectedFileType.description)
                            .fontWeight(.medium)
                    }
                    
                    if !data.points.isEmpty {
                        // Show a simple preview of the point cloud bounds
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bounds:")
                                .font(.headline)
                            
                            let xValues = data.points.map { $0.x }
                            let yValues = data.points.map { $0.y }
                            let zValues = data.points.map { $0.z }
                            
                            HStack {
                                Text("X:")
                                Spacer()
                                Text(String(format: "%.2f to %.2f", xValues.min()!, xValues.max()!))
                            }
                            
                            HStack {
                                Text("Y:")
                                Spacer()
                                Text(String(format: "%.2f to %.2f", yValues.min()!, yValues.max()!))
                            }
                            
                            HStack {
                                Text("Z:")
                                Spacer()
                                Text(String(format: "%.2f to %.2f", zValues.min()!, zValues.max()!))
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    pointCloudData = nil
                    importedFileURL = nil
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(action: openInVolumetricView) {
                    Label("Open in 3D View", systemImage: "eye")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func startRealTimeStream() {
        isProcessing = true
        
        // Configure streaming based on selected mode
        let configs = createStreamConfigsForMode(selectedStreamingMode)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            streamingManager.startStreaming(streamConfigs: configs)
            isStreamingActive = true
            isProcessing = false
            showStreamingOptions = false
        }
    }
    
    private func createStreamConfigsForMode(_ mode: StreamingMode) -> [DataStreamConfig] {
        switch mode {
        case .realTimeData:
            return [
                DataStreamConfig.sensorData,
                DataStreamConfig.financialData,
                DataStreamConfig.scientificData
            ]
        case .sensorSimulation:
            return [
                DataStreamConfig(
                    id: "temp_sensor",
                    name: "Temperature Sensor",
                    type: .sensor,
                    frequency: streamingConfig.updateFrequency,
                    bufferSize: 1000
                ),
                DataStreamConfig(
                    id: "humidity_sensor",
                    name: "Humidity Sensor",
                    type: .sensor,
                    frequency: streamingConfig.updateFrequency / 2,
                    bufferSize: 1000
                )
            ]
        case .financialData:
            return [
                DataStreamConfig(
                    id: "stock_prices",
                    name: "Stock Prices",
                    type: .financial,
                    frequency: 1.0,
                    bufferSize: 500
                )
            ]
        case .scientificData:
            return [
                DataStreamConfig(
                    id: "experiment_data",
                    name: "Experiment Data",
                    type: .scientific,
                    frequency: streamingConfig.updateFrequency * 2,
                    bufferSize: 2000
                )
            ]
        }
    }
    
    private func stopStreaming() {
        streamingManager.stopStreaming()
        isStreamingActive = false
        showStreamingOptions = false
    }
    
    private func openIn2DChart() {
        createStreamingChartWindow(type: .charts)
        dismiss()
    }
    
    private func openIn3DVisualization() {
        createStreamingChartWindow(type: .spatial)
        dismiss()
    }
    
    private func openInCombinedView() {
        // Create both 2D and 3D windows
        createStreamingChartWindow(type: .charts)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            createStreamingChartWindow(type: .spatial)
        }
        
        dismiss()
    }
    
    private func createStreamingChartWindow(type: WindowType) {
        let id = windowManager.getNextWindowID()
        let position = WindowPosition(
            x: type == .spatial ? 400 : 100,
            y: type == .spatial ? 100 : 200,
            z: 0,
            width: 800,
            height: 600
        )
        
        _ = windowManager.createWindow(type, id: id, position: position)
        
        // Add streaming-specific tags
        windowManager.addWindowTag(id, tag: "Real-Time-Streaming")
        windowManager.addWindowTag(id, tag: selectedStreamingMode.rawValue)
        
        // Add content description
        let content = """
        # Real-Time Streaming \(type == .spatial ? "3D" : "2D") Visualization
        # Mode: \(selectedStreamingMode.rawValue)
        # Frequency: \(streamingConfig.updateFrequency) Hz
        # Streams: \(streamingConfig.numberOfStreams)
        
        # This window displays live streaming data from the RealTimeStreamingManager
        # Data is updated at \(streamingConfig.updateFrequency) Hz with \(streamingConfig.numberOfStreams) concurrent streams
        """
        
        windowManager.updateWindowContent(id, content: content)
        
        // Open the appropriate window type
        if type == .spatial {
            #if os(visionOS)
            // Create a special volumetric window for streaming visualization
            openWindow(id: "volumetric-streaming", value: id)
            #endif
        } else {
            // Regular 2D window
            openWindow(value: NewWindowID.ID(id))
        }
        
        windowManager.markWindowAsOpened(id)
    }
    
    private func convertToStreamingData() {
        guard let data = csvData else { return }
        
        // Convert CSV data to streaming simulation
        selectedStreamingMode = .realTimeData
        selectedFileType = .streamingData
        
        // Configure streaming to simulate the CSV data
        streamingConfig.numberOfStreams = min(data.headers.count, 5)
        streamingConfig.updateFrequency = 5.0
        
        csvData = nil
        chartRecommendations = []
        showStreamingOptions = true
    }
    
    private func createChartWithRecommendation(_ recommendation: ChartRecommendation) {
        guard let data = csvData else { return }
        
        let id = windowManager.getNextWindowID()
        let position = WindowPosition(x: 100, y: 100, z: 0, width: 800, height: 600)
        
        _ = windowManager.createWindow(.charts, id: id, position: position)
        
        // Create chart data from CSV and recommendation
        let chartData = createChartDataFromCSV(data, recommendation: recommendation)
        windowManager.updateWindowChartData(id, chartData: chartData)
        windowManager.addWindowTag(id, tag: "CSV-Import")
        windowManager.addWindowTag(id, tag: recommendation.name)
        
        openWindow(value: NewWindowID.ID(id))
        windowManager.markWindowAsOpened(id)
        
        dismiss()
    }
    
    private func createDataTableWindow() {
        guard let data = csvData else { return }
        
        let id = windowManager.getNextWindowID()
        let position = WindowPosition(x: 100, y: 100, z: 0, width: 800, height: 600)
        
        _ = windowManager.createWindow(.column, id: id, position: position)
        
        // Convert CSV to DataFrame
        let dtypes = Dictionary(uniqueKeysWithValues: zip(
            data.headers,
            data.columnTypes.map { type -> String in
                switch type {
                case .numeric: return "float"
                case .categorical: return "string"
                case .date: return "string"
                case .unknown: return "string"
                }
            }
        ))
        
        let dataFrame = DataFrameData(
            columns: data.headers,
            rows: data.rows,
            dtypes: dtypes
        )
        
        windowManager.updateWindowDataFrame(id, dataFrame: dataFrame)
        windowManager.addWindowTag(id, tag: "CSV-Import")
        
        openWindow(value: NewWindowID.ID(id))
        windowManager.markWindowAsOpened(id)
        
        dismiss()
    }
    
    // MARK: - File Processing (existing methods remain the same)
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importedFileURL = url
            isProcessing = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.classifyAndProcessFile(url)
            }
            
        case .failure(let error):
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }
    
    private func classifyAndProcessFile(_ url: URL) {
        let classifier = FileClassifier()
        let (fileType, csvData, chartScores) = classifier.classifyFile(at: url)
        
        DispatchQueue.main.async {
            self.isProcessing = false
            
            switch fileType {
            case .csv:
                self.selectedFileType = .csv
                self.csvData = csvData
                self.chartRecommendations = chartScores ?? []
                
            case .pointCloudPLY:
                self.selectedFileType = .pointCloudPLY
                self.processPointCloudFile(url)
                
            case .usdz:
                self.selectedFileType = .modelUSDZ
                self.processModelFile(url)
                
            case .unknown:
                self.errorMessage = "Unsupported file type"
            }
        }
    }
    
    private func processPointCloudFile(_ url: URL) {
        let data: PointCloudData?
        
        switch selectedFileType {
        case .pointCloudPLY:
            data = parsePLYFile(url)
        case .pointCloudXYZ:
            data = parseXYZFile(url)
        case .pointCloudPCD:
            data = parsePCDFile(url)
        case .pointCloudPTS:
            data = parsePTSFile(url)
        default:
            data = nil
        }
        
        DispatchQueue.main.async {
            if let data = data {
                self.pointCloudData = data
            } else {
                self.errorMessage = "Failed to parse point cloud file"
            }
        }
    }
    
    private func processModelFile(_ url: URL) {
        // Create window for 3D model
        let id = windowManager.getNextWindowID()
        let position = WindowPosition(x: 100, y: 100, z: 0, width: 800, height: 600)
        
        _ = windowManager.createWindow(.model3d, id: id, position: position)
        
        do {
            let bookmark = try url.bookmarkData(options: .minimalBookmark)
            windowManager.updateUSDZBookmark(for: id, bookmark: bookmark)
        } catch {
            print("Error creating bookmark: \(error)")
        }
        
        #if os(visionOS)
        openWindow(id: "volumetric-model3d", value: id)
        #endif
        
        windowManager.markWindowAsOpened(id)
        dismiss()
    }
    
    private func openInVolumetricView() {
        guard let data = pointCloudData else { return }
        
        let id = windowManager.getNextWindowID()
        let position = WindowPosition(x: 100, y: 100, z: 0, width: 800, height: 600)
        
        _ = windowManager.createWindow(.pointcloud, id: id, position: position)
        windowManager.updateWindowPointCloud(id, pointCloud: data)
        windowManager.markWindowAsOpened(id)
        
        #if os(visionOS)
        openWindow(id: "volumetric-pointcloud", value: id)
        #endif
        
        dismiss()
    }
    
    // MARK: - Helper Methods
    
    private func createChartDataFromCSV(_ csvData: CSVData, recommendation: ChartRecommendation) -> ChartData {
        // Find appropriate columns for the chart type
        let numericColumns = csvData.headers.enumerated().filter { 
            csvData.columnTypes[$0.offset] == .numeric 
        }
        let dateColumns = csvData.headers.enumerated().filter { 
            csvData.columnTypes[$0.offset] == .date 
        }
        
        let xLabel: String
        let yLabel: String
        let xData: [Double]
        let yData: [Double]
        
        if !dateColumns.isEmpty && !numericColumns.isEmpty {
            // Use date for X-axis
            xLabel = dateColumns.first!.element
            yLabel = numericColumns.first!.element
            
            // For simplicity, use row index as time
            xData = Array(0..<csvData.rows.count).map { Double($0) }
            yData = csvData.rows.compactMap { row in
                let index = numericColumns.first!.offset
                return index < row.count ? Double(row[index]) : nil
            }
        } else if numericColumns.count >= 2 {
            // Use two numeric columns
            let firstCol = numericColumns[0]
            let secondCol = numericColumns[1]
            
            xLabel = firstCol.element
            yLabel = secondCol.element
            
            xData = csvData.rows.compactMap { row in
                let index = firstCol.offset
                return index < row.count ? Double(row[index]) : nil
            }
            yData = csvData.rows.compactMap { row in
                let index = secondCol.offset
                return index < row.count ? Double(row[index]) : nil
            }
        } else {
            // Fallback to row indices
            xLabel = "Index"
            yLabel = numericColumns.first?.element ?? "Value"
            xData = Array(0..<csvData.rows.count).map { Double($0) }
            yData = Array(0..<csvData.rows.count).map { Double($0) }
        }
        
        return ChartData(
            title: "\(recommendation.name) - \(importedFileURL?.deletingPathExtension().lastPathComponent ?? "Imported Data")",
            chartType: recommendation.name.lowercased().replacingOccurrences(of: " ", with: "_"),
            xLabel: xLabel,
            yLabel: yLabel,
            xData: xData,
            yData: yData
        )
    }
    
    private func getFileType() -> FileType? {
        return selectedFileType != .unknown ? selectedFileType : nil
    }
    
    // MARK: - File Parsers (keeping existing implementations)
    
    private func parsePLYFile(_ url: URL) -> PointCloudData? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            guard let headerStr = String(data: data.prefix(1024), encoding: .ascii) else { return nil }
            
            guard let endRange = headerStr.range(of: "end_header\n") else { return nil }
            let header = String(headerStr[..<endRange.upperBound])
            let headerLines = header.components(separatedBy: .newlines)
            
            var format = "ascii 1.0"
            var vertexCount = 0
            var propList = [String]()
            var propTypes = [String]()
            
            for line in headerLines {
                let parts = line.components(separatedBy: " ")
                if parts.count > 1 {
                    if parts[0] == "format" {
                        format = parts[1...].joined(separator: " ")
                    } else if parts[0] == "element" && parts[1] == "vertex" {
                        vertexCount = Int(parts[2]) ?? 0
                    } else if parts[0] == "property" {
                        propTypes.append(parts[1])
                        propList.append(parts.last ?? "")
                    }
                }
            }
            
            let bodyStart = header.utf8CString.count - 1
            let bodyData = data.subdata(in: bodyStart..<data.count)
            
            var points = [PointCloudData.PointData]()
            
            if format.hasPrefix("ascii") {
                guard let bodyStr = String(data: bodyData, encoding: .ascii) else { return nil }
                let bodyLines = bodyStr.components(separatedBy: .newlines).filter { !$0.isEmpty }
                
                for line in bodyLines.prefix(vertexCount) {
                    let values = line.components(separatedBy: " ").compactMap { Float($0) }
                    if values.count >= 3 {
                        points.append(PointCloudData.PointData(
                            x: Double(values[0]), 
                            y: Double(values[1]), 
                            z: Double(values[2])
                        ))
                    }
                }
            }
            
            var pc = PointCloudData(
                title: url.lastPathComponent,
                demoType: "ply-import",
                points: points
            )
            pc.totalPoints = points.count
            return pc
        } catch {
            print("PLY parse error: \(error)")
            return nil
        }
    }
    
    private func parseXYZFile(_ url: URL) -> PointCloudData? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            var points: [PointCloudData.PointData] = []
            
            for line in lines {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if components.count >= 3,
                   let x = Double(components[0]),
                   let y = Double(components[1]),
                   let z = Double(components[2]) {
                    let intensity = components.count > 3 ? Double(components[3]) : nil
                    points.append(PointCloudData.PointData(x: x, y: y, z: z, intensity: intensity))
                }
            }
            
            var pc = PointCloudData(
                title: url.lastPathComponent,
                demoType: "xyz-import",
                points: points
            )
            pc.totalPoints = points.count
            return pc
            
        } catch {
            print("Error parsing XYZ file: \(error)")
            return nil
        }
    }
    
    private func parsePCDFile(_ url: URL) -> PointCloudData? {
        return parseXYZFile(url) // Simplified for now
    }
    
    private func parsePTSFile(_ url: URL) -> PointCloudData? {
        return parseXYZFile(url) // PTS files are often similar to XYZ
    }
}

// MARK: - Supporting Views

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct RealTimePreviewChart: View {
    @ObservedObject var streamingManager: RealTimeStreamingManager
    @State private var chartData: [ChartDataPoint] = []
    
    var body: some View {
        VStack {
            if chartData.isEmpty {
                Text("Collecting data...")
                    .foregroundColor(.secondary)
            } else {
                Chart(chartData.suffix(50)) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(by: .value("Stream", point.streamId))
                }
                .chartLegend(.hidden)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
        }
        .onAppear {
            startDataCollection()
        }
    }
    
    private func startDataCollection() {
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            collectLatestData()
        }
    }
    
    private func collectLatestData() {
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
        
        // Keep only recent data
        let cutoffTime = Date().addingTimeInterval(-10) // Last 10 seconds
        chartData.removeAll { $0.timestamp < cutoffTime }
    }
}

struct ChartRecommendationCard: View {
    let recommendation: ChartRecommendation
    let score: Double
    let reasoning: String
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: recommendation.icon)
                        .foregroundColor(.blue)
                    Text(recommendation.name)
                        .font(.headline)
                    Spacer()
                }
                
                Text(reasoning)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Text("Match: \(Int(score * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Format Card (keeping existing)
struct UnifiedImportFormatCard: View {
    let title: String
    let formats: [String]
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.headline)
            }
            Text(formats.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Helper Extension
extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

#Preview {
    UnifiedImportSheet()
        .environmentObject(WindowTypeManager.shared)
}