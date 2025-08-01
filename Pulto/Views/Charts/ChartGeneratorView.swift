//
//  ChartGeneratorView.swift
//  Pulto3
//
//  Created by AI Assistant on 1/29/25.
//

import SwiftUI
import Charts
import UniformTypeIdentifiers

// MARK: - File Document Types

struct TextFileDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.pythonScript, .plainText]
    
    var content: String
    
    init(content: String = "") {
        self.content = content
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        content = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}

struct ImageFileDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.png, .jpeg]
    
    let chartBuilder: ChartBuilder?
    
    init(chartBuilder: ChartBuilder) {
        self.chartBuilder = chartBuilder
    }
    
    init(configuration: ReadConfiguration) throws {
        // For reading images, we don't need the chart builder
        self.chartBuilder = nil
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let placeholder = "Chart Image Placeholder"
        let data = placeholder.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}

extension UTType {
    static let pythonScript = UTType(filenameExtension: "py") ?? .plainText
}

// MARK: - Chart Generator View

struct ChartGeneratorView: View {
    let windowID: Int
    
    @StateObject private var windowManager = WindowTypeManager.shared
    @StateObject private var chartBuilder = ChartBuilder()
    
    @State private var selectedTab: ChartGeneratorTab = .create
    @State private var showingDataImporter = false
    @State private var showingCodeExporter = false
    @State private var showingChartExporter = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Navigation
                chartTabNavigation
                
                Divider()
                
                // Main Content
                Group {
                    switch selectedTab {
                    case .create:
                        ChartCreationView(chartBuilder: chartBuilder)
                    case .data:
                        ChartDataView(chartBuilder: chartBuilder, showingDataImporter: $showingDataImporter)
                    case .customize:
                        ChartCustomizationView(chartBuilder: chartBuilder)
                    case .preview:
                        ChartPreviewView(chartBuilder: chartBuilder)
                    case .export:
                        ChartExportView(
                            chartBuilder: chartBuilder,
                            showingCodeExporter: $showingCodeExporter,
                            showingChartExporter: $showingChartExporter
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Chart Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Quick Chart") {
                        chartBuilder.generateSampleData()
                        selectedTab = .preview
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Menu {
                        Button("Import CSV") {
                            showingDataImporter = true
                        }
                        Button("Generate Sample Data") {
                            chartBuilder.generateSampleData()
                        }
                        Button("Clear All") {
                            chartBuilder.clear()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingDataImporter,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleDataImport(result)
        }
        .fileExporter(
            isPresented: $showingCodeExporter,
            document: TextFileDocument(content: chartBuilder.generatePythonCode()),
            contentType: .pythonScript,
            defaultFilename: "chart_generator.py"
        ) { result in
            handleCodeExport(result)
        }
        .fileExporter(
            isPresented: $showingChartExporter,
            document: ImageFileDocument(chartBuilder: chartBuilder),
            contentType: .png,
            defaultFilename: "generated_chart.png"
        ) { result in
            handleChartExport(result)
        }
        .onAppear {
            // Store chart data in window manager when data changes
            // We'll handle this through the chart builder's published properties
        }
    }
    
    // MARK: - Tab Navigation
    
    private var chartTabNavigation: some View {
        HStack(spacing: 0) {
            ForEach(ChartGeneratorTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                    .foregroundStyle(selectedTab == tab ? .blue : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.regularMaterial)
    }
    
    // MARK: - File Handling
    
    private func handleDataImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await chartBuilder.importData(from: url)
                await MainActor.run {
                    selectedTab = .data
                }
            }
        case .failure(let error):
            print("Data import failed: \(error)")
        }
    }
    
    private func handleCodeExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("Python code exported to: \(url)")
        case .failure(let error):
            print("Code export failed: \(error)")
        }
    }
    
    private func handleChartExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("Chart image exported to: \(url)")
        case .failure(let error):
            print("Chart export failed: \(error)")
        }
    }
}

// MARK: - Chart Generator Tabs

enum ChartGeneratorTab: String, CaseIterable {
    case create = "Create"
    case data = "Data"
    case customize = "Style"
    case preview = "Preview"
    case export = "Export"
    
    var icon: String {
        switch self {
        case .create: return "plus.circle"
        case .data: return "tablecells"
        case .customize: return "paintbrush"
        case .preview: return "eye"
        case .export: return "square.and.arrow.up"
        }
    }
}

// MARK: - Chart Builder

@MainActor
class ChartBuilder: ObservableObject {
    @Published var chartType: ChartType = .line
    @Published var chartData: ChartDataSet = ChartDataSet()
    @Published var chartStyle: ChartStyle = ChartStyle()
    @Published var chartMetadata: ChartMetadata = ChartMetadata()
    
    // Special initializer for file reading that doesn't require main actor
    nonisolated init(forReading: Bool = false) {
        // Initialize with default values
    }
    
    // MARK: - Chart Types
    
    enum ChartType: String, CaseIterable {
        case line = "Line Chart"
        case bar = "Bar Chart"
        case scatter = "Scatter Plot"
        case pie = "Pie Chart"
        case area = "Area Chart"
        case histogram = "Histogram"
        case boxPlot = "Box Plot"
        case heatmap = "Heatmap"
        
        var icon: String {
            switch self {
            case .line: return "chart.line.uptrend.xyaxis"
            case .bar: return "chart.bar"
            case .scatter: return "chart.dots.scatter"
            case .pie: return "chart.pie"
            case .area: return "chart.line.uptrend.xyaxis.circle.fill"
            case .histogram: return "chart.bar.doc.horizontal"
            case .boxPlot: return "rectangle.3.group"
            case .heatmap: return "grid.circle"
            }
        }
        
        var description: String {
            switch self {
            case .line: return "Show trends over time or continuous data"
            case .bar: return "Compare values across categories"
            case .scatter: return "Show relationships between two variables"
            case .pie: return "Display proportions of a whole"
            case .area: return "Show cumulative values over time"
            case .histogram: return "Display distribution of numerical data"
            case .boxPlot: return "Show data distribution with quartiles"
            case .heatmap: return "Show data density with color mapping"
            }
        }
    }
    
    // MARK: - Data Management
    
    func generateSampleData() {
        chartData = ChartDataSet.generateSample(for: chartType)
        chartMetadata.title = "Sample \(chartType.rawValue)"
        chartMetadata.description = "Generated sample data for demonstration"
    }
    
    func importData(from url: URL) async {
        do {
            let content = try String(contentsOf: url)
            if let csvData = CSVParser.parse(content) {
                chartData = ChartDataSet.fromCSV(csvData)
                chartMetadata.title = url.deletingPathExtension().lastPathComponent
                chartMetadata.description = "Imported from \(url.lastPathComponent)"
            }
        } catch {
            print("Failed to import data: \(error)")
        }
    }
    
    func clear() {
        chartData = ChartDataSet()
        chartStyle = ChartStyle()
        chartMetadata = ChartMetadata()
    }
    
    // MARK: - Code Generation
    
    func generatePythonCode() -> String {
        let generator = PythonChartCodeGenerator()
        return generator.generateCode(
            chartType: chartType,
            data: chartData,
            style: chartStyle,
            metadata: chartMetadata
        )
    }
    
    func generateJupyterNotebook() -> String {
        let generator = JupyterNotebookGenerator()
        return generator.generateNotebook(
            chartType: chartType,
            data: chartData,
            style: chartStyle,
            metadata: chartMetadata
        )
    }
}

// MARK: - Chart Data Models

struct ChartDataSet {
    var series: [DataSeries] = []
    var categories: [String] = []
    var xAxisData: [Double] = []
    var yAxisData: [Double] = []
    
    static func generateSample(for chartType: ChartBuilder.ChartType) -> ChartDataSet {
        var data = ChartDataSet()
        
        switch chartType {
        case .line, .area:
            data.categories = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"]
            data.series = [
                DataSeries(name: "Sales", values: [120, 135, 155, 142, 168, 185], color: .blue),
                DataSeries(name: "Revenue", values: [100, 125, 140, 138, 155, 172], color: .green)
            ]
            
        case .bar:
            data.categories = ["Product A", "Product B", "Product C", "Product D"]
            data.series = [
                DataSeries(name: "Q1", values: [45, 38, 52, 41], color: .blue),
                DataSeries(name: "Q2", values: [52, 45, 58, 48], color: .orange)
            ]
            
        case .scatter:
            data.xAxisData = Array(stride(from: 0.0, through: 100.0, by: 5.0))
            data.yAxisData = data.xAxisData.map { x in
                x * 0.8 + Double.random(in: -10...10)
            }
            
        case .pie:
            data.categories = ["Mobile", "Desktop", "Tablet", "Other"]
            data.series = [
                DataSeries(name: "Usage", values: [45, 30, 20, 5], color: .blue)
            ]
            
        case .histogram:
            let values = (0..<100).map { _ in Double.random(in: 0...100) }
            data.series = [
                DataSeries(name: "Distribution", values: values, color: .purple)
            ]
            
        case .boxPlot:
            data.categories = ["Dataset A", "Dataset B", "Dataset C"]
            data.series = [
                DataSeries(name: "Values", values: [25, 50, 75, 100, 125], color: .red)
            ]
            
        case .heatmap:
            data.categories = ["Week 1", "Week 2", "Week 3", "Week 4"]
            let heatmapValues = (0..<16).map { _ in Double.random(in: 0...100) }
            data.series = [
                DataSeries(name: "Activity", values: heatmapValues, color: .orange)
            ]
        }
        
        return data
    }
    
    static func fromCSV(_ csvData: CSVData) -> ChartDataSet {
        var data = ChartDataSet()
        
        // Use first column as categories if it's categorical
        if let firstColumnType = csvData.columnTypes.first, firstColumnType == .categorical {
            data.categories = csvData.rows.compactMap { row -> String? in
                return row.first
            }
        }
        
        // Create series from numeric columns
        for (index, columnType) in csvData.columnTypes.enumerated() {
            if columnType == .numeric && index < csvData.headers.count {
                let columnName = csvData.headers[index]
                let values = csvData.rows.compactMap { row -> Double? in
                    guard index < row.count else { return nil }
                    return Double(row[index])
                }
                
                let color = ChartStyle.defaultColors[data.series.count % ChartStyle.defaultColors.count]
                data.series.append(DataSeries(name: columnName, values: values, color: color))
            }
        }
        
        return data
    }
}

struct DataSeries {
    let name: String
    let values: [Double]
    let color: Color
}

struct ChartStyle {
    var primaryColor: Color = .blue
    var secondaryColor: Color = .orange
    var backgroundColor: Color = .clear
    var showGrid: Bool = true
    var showLegend: Bool = true
    var showAxes: Bool = true
    var lineWidth: Double = 2.0
    var pointSize: Double = 4.0
    var cornerRadius: Double = 4.0
    var opacity: Double = 0.8
    
    static let defaultColors: [Color] = [
        .blue, .orange, .green, .red, .purple, .pink, .indigo, .teal
    ]
}

struct ChartMetadata {
    var title: String = "Untitled Chart"
    var description: String = ""
    var xAxisLabel: String = "X Axis"
    var yAxisLabel: String = "Y Axis"
    var source: String = ""
    var createdDate: Date = Date()
}

#Preview {
    ChartGeneratorView(windowID: 1)
        .frame(width: 1200, height: 800)
}
