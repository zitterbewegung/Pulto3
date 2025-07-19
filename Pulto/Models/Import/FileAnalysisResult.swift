//
//  FileAnalysisResult.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/19/25.
//  Copyright © 2025 Apple. All rights reserved.
//

/*
import SwiftUI
import RealityKit
import UniformTypeIdentifiers

// MARK: - File Analysis Result
struct FileAnalysisResult {
    enum VisualizationType {
        case dataTable
        case chart2D(ChartRecommendation)
        case pointCloud3D
        case volumetric3D
        case notebook
        case unknown
    }
    
    let fileURL: URL
    let fileName: String
    let fileType: String
    let visualizationType: VisualizationType
    let metadata: [String: Any]
    let suggestedWindowTitle: String
}

// MARK: - Main File Analyzer View
struct FileAnalyzerView: View {
    @StateObject private var windowManager = WindowTypeManager.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFiles: [URL] = []
    @State private var analysisResults: [FileAnalysisResult] = []
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var showingFilePicker = false
    @State private var dragOver = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with file list
            sidebarView
        } detail: {
            // Main content area
            if analysisResults.isEmpty {
                emptyStateView
            } else {
                resultsView
            }
        }
        .navigationTitle("Spatial Data Analyzer")
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: supportedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
        .onDrop(of: supportedContentTypes, isTargeted: $dragOver) { providers in
            handleDrop(providers)
            return true
        }
    }
    
    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.viewfinder")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    
                    Text("File Analyzer")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: { showingFilePicker = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                
                Text("\(analysisResults.count) files analyzed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            
            Divider()
            
            // File list
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(analysisResults, id: \.fileURL) { result in
                        FileResultRow(result: result) {
                            openVisualization(for: result)
                        }
                    }
                }
                .padding()
            }
            
            Spacer()
            
            // Actions
            VStack(spacing: 12) {
                Button(action: { showingFilePicker = true }) {
                    Label("Add Files", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                if !analysisResults.isEmpty {
                    Button(action: openAllVisualizations) {
                        Label("Open All Visualizations", systemImage: "square.stack.3d.forward.dottedline")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .frame(minWidth: 300, maxWidth: 400)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text("Drop Files Here")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("Or click the + button to browse")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            // Supported formats
            VStack(alignment: .leading, spacing: 12) {
                Text("Supported Formats:")
                    .font(.headline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    FormatBadge(icon: "tablecells", text: "CSV/TSV", color: .green)
                    FormatBadge(icon: "cube", text: "USDZ", color: .blue)
                    FormatBadge(icon: "circle.grid.3x3.fill", text: "Point Clouds", color: .purple)
                    FormatBadge(icon: "doc.text", text: "JSON", color: .orange)
                    FormatBadge(icon: "text.book.closed", text: "Notebooks", color: .red)
                    FormatBadge(icon: "cube.transparent", text: "3D Models", color: .indigo)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(dragOver ? Color.blue.opacity(0.1) : Color.clear)
        .animation(.easeInOut(duration: 0.2), value: dragOver)
    }
    
    // MARK: - Results View
    private var resultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Summary
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Analysis Complete")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("\(analysisResults.count) files ready for visualization")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: openAllVisualizations) {
                        Label("Open All", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                // File cards
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    ForEach(analysisResults, id: \.fileURL) { result in
                        FileAnalysisCard(result: result) {
                            openVisualization(for: result)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - File Analysis
    private func analyzeFiles(_ urls: [URL]) {
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            var results: [FileAnalysisResult] = []
            
            for url in urls {
                if let result = await analyzeFile(url) {
                    results.append(result)
                }
            }
            
            await MainActor.run {
                analysisResults.append(contentsOf: results)
                isAnalyzing = false
            }
        }
    }
    
    private func analyzeFile(_ url: URL) async -> FileAnalysisResult? {
        let fileExtension = url.pathExtension.lowercased()
        let fileName = url.lastPathComponent
        
        // Determine visualization type based on file extension and content
        let visualizationType: FileAnalysisResult.VisualizationType
        var metadata: [String: Any] = [:]
        
        switch fileExtension {
        case "csv", "tsv":
            // Analyze CSV for chart recommendations
            if let csvData = await analyzeCSVFile(url) {
                metadata["csvData"] = csvData
                let recommendations = ChartRecommender.recommend(for: csvData)
                if let bestRecommendation = recommendations.first?.recommendation {
                    visualizationType = .chart2D(bestRecommendation)
                } else {
                    visualizationType = .dataTable
                }
            } else {
                visualizationType = .dataTable
            }
            
        case "usdz", "usd", "usda", "usdc":
            visualizationType = .volumetric3D
            metadata["modelType"] = "usdz"
            
        case "ply", "pcd", "xyz", "pts":
            visualizationType = .pointCloud3D
            metadata["pointFormat"] = fileExtension
            
        case "obj", "fbx", "dae", "gltf", "glb", "stl":
            visualizationType = .volumetric3D
            metadata["modelType"] = fileExtension
            metadata["requiresConversion"] = true
            
        case "ipynb":
            visualizationType = .notebook
            metadata["notebookType"] = "jupyter"
            
        case "json":
            // Analyze JSON structure
            if let jsonType = await analyzeJSONFile(url) {
                metadata["jsonType"] = jsonType
                visualizationType = jsonType == "dataframe" ? .dataTable : .unknown
            } else {
                visualizationType = .unknown
            }
            
        default:
            visualizationType = .unknown
        }
        
        let suggestedTitle = generateWindowTitle(fileName: fileName, type: visualizationType)
        
        return FileAnalysisResult(
            fileURL: url,
            fileName: fileName,
            fileType: fileExtension,
            visualizationType: visualizationType,
            metadata: metadata,
            suggestedWindowTitle: suggestedTitle
        )
    }
    
    private func analyzeCSVFile(_ url: URL) async -> CSVData? {
        do {
            let content = try String(contentsOf: url)
            return CSVParser.parse(content)
        } catch {
            print("Error reading CSV file: \(error)")
            return nil
        }
    }
    
    private func analyzeJSONFile(_ url: URL) async -> String? {
        do {
            let data = try Data(contentsOf: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Check for DataFrame structure
                if json["columns"] != nil && json["rows"] != nil {
                    return "dataframe"
                }
                // Check for notebook structure
                if json["cells"] != nil && json["metadata"] != nil {
                    return "notebook"
                }
                // Check for point cloud structure
                if json["points"] != nil || json["vertices"] != nil {
                    return "pointcloud"
                }
            }
            return "generic"
        } catch {
            print("Error analyzing JSON file: \(error)")
            return nil
        }
    }
    
    private func generateWindowTitle(fileName: String, type: FileAnalysisResult.VisualizationType) -> String {
        let baseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        
        switch type {
        case .dataTable:
            return "\(baseName) - Data Table"
        case .chart2D(let recommendation):
            return "\(baseName) - \(recommendation.name)"
        case .pointCloud3D:
            return "\(baseName) - Point Cloud"
        case .volumetric3D:
            return "\(baseName) - 3D Model"
        case .notebook:
            return "\(baseName) - Notebook"
        case .unknown:
            return baseName
        }
    }
    
    // MARK: - Visualization Opening
    private func openVisualization(for result: FileAnalysisResult) {
        // Create a new window with appropriate content
        let windowID = windowManager.createWindow(
            type: mapVisualizationTypeToWindowType(result.visualizationType), id: <#Int#>, id: <#Int#>, id: <#Int#>, id: <#Int#>,
            title: result.suggestedWindowTitle
        )
        
        // Store file data in window
        windowManager.updateWindowMetadata(windowID, key: "fileURL", value: result.fileURL.absoluteString)
        windowManager.updateWindowMetadata(windowID, key: "fileName", value: result.fileName)
        
        // Open appropriate view based on visualization type
        switch result.visualizationType {
        case .dataTable:
            openDataTable(windowID: windowID, fileURL: result.fileURL, metadata: result.metadata)
            
        case .chart2D(let recommendation):
            openChart2D(windowID: windowID, fileURL: result.fileURL, recommendation: recommendation, metadata: result.metadata)
            
        case .pointCloud3D:
            openPointCloud3D(windowID: windowID, fileURL: result.fileURL, metadata: result.metadata)
            
        case .volumetric3D:
            openVolumetric3D(windowID: windowID, fileURL: result.fileURL, metadata: result.metadata)
            
        case .notebook:
            openNotebook(windowID: windowID, fileURL: result.fileURL, metadata: result.metadata)
            
        case .unknown:
            print("Unknown file type, cannot open visualization")
        }
    }
    
    private func mapVisualizationTypeToWindowType(_ type: FileAnalysisResult.VisualizationType) -> WindowType {
        switch type {
        case .dataTable:
            return .dataTable
        case .chart2D:
            return .chart
        case .pointCloud3D, .volumetric3D:
            return .spatialEditor
        case .notebook:
            return .notebook
        case .unknown:
            return .editor
        }
    }
    
    private func openDataTable(windowID: Int, fileURL: URL, metadata: [String: Any]) {
        // Load data and create DataFrame
        if let dataFrame = loadDataFrameFromFile(fileURL) {
            windowManager.updateWindowDataFrame(windowID, dataFrame: dataFrame)
            openWindow(id: "data-table", value: windowID)
        }
    }
    
    private func openChart2D(windowID: Int, fileURL: URL, recommendation: ChartRecommendation, metadata: [String: Any]) {
        // Create chart data from CSV
        if let csvData = metadata["csvData"] as? CSVData {
            let chartData = createChartDataFromCSV(csvData, recommendation: recommendation)
            windowManager.updateWindowChartData(windowID, chartData: chartData)
            openWindow(id: "chart-2d", value: windowID)
        }
    }
    
    private func openPointCloud3D(windowID: Int, fileURL: URL, metadata: [String: Any]) {
        // Store point cloud file reference
        windowManager.updateWindowMetadata(windowID, key: "pointCloudURL", value: fileURL.absoluteString)
        openWindow(id: "volumetric-pointcloud", value: windowID)
    }
    
    private func openVolumetric3D(windowID: Int, fileURL: URL, metadata: [String: Any]) {
        // For 3D models, we need to load or convert them
        Task {
            do {
                if metadata["requiresConversion"] as? Bool == true {
                    // Convert non-USDZ formats
                    let modelFile = ModelFile(
                        url: fileURL,
                        name: fileURL.lastPathComponent,
                        size: try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    )
                    let model3D = try await Model3DImporter.createModel3DFromFile(modelFile)
                    
                    await MainActor.run {
                        windowManager.updateWindowModel3D(windowID, modelData: model3D)
                        openWindow(id: "volumetric-model3d", value: windowID)
                    }
                } else {
                    // Direct USDZ loading
                    let bookmark = try fileURL.bookmarkData()
                    await MainActor.run {
                        windowManager.updateUSDZBookmark(for: windowID, bookmark: bookmark)
                        openWindow(id: "volumetric-model3d", value: windowID)
                    }
                }
            } catch {
                print("Error loading 3D model: \(error)")
            }
        }
    }
    
    private func openNotebook(windowID: Int, fileURL: URL, metadata: [String: Any]) {
        windowManager.updateWindowMetadata(windowID, key: "notebookURL", value: fileURL.absoluteString)
        openWindow(id: "notebook-viewer", value: windowID)
    }
    
    private func openAllVisualizations() {
        for result in analysisResults {
            openVisualization(for: result)
        }
    }
    
    // MARK: - Helper Methods
    private func loadDataFrameFromFile(_ url: URL) -> DataFrameData? {
        do {
            let content = try String(contentsOf: url)
            let fileExtension = url.pathExtension.lowercased()
            
            switch fileExtension {
            case "csv":
                if let csvData = CSVParser.parse(content) {
                    return DataFrameData(
                        columns: csvData.headers,
                        rows: csvData.rows,
                        dtypes: Dictionary(uniqueKeysWithValues: csvData.headers.enumerated().map { index, header in
                            (header, csvData.columnTypes[index] == .numeric ? "float" : "string")
                        })
                    )
                }
            case "json":
                if let data = content.data(using: .utf8),
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let columns = json["columns"] as? [String],
                   let rows = json["rows"] as? [[String]],
                   let dtypes = json["dtypes"] as? [String: String] {
                    return DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
                }
            default:
                break
            }
        } catch {
            print("Error loading DataFrame from file: \(error)")
        }
        return nil
    }
    
    private func createChartDataFromCSV(_ csvData: CSVData, recommendation: ChartRecommendation) -> ChartData {
        // Find appropriate columns
        let numericColumns = csvData.headers.enumerated().compactMap { index, header in
            csvData.columnTypes[index] == .numeric ? header : nil
        }
        
        let xData = Array(0..<csvData.rows.count).map { Double($0) }
        let yData: [Double] = {
            guard let firstNumericColumn = numericColumns.first,
                  let columnIndex = csvData.headers.firstIndex(of: firstNumericColumn) else {
                return []
            }
            
            return csvData.rows.compactMap { row in
                columnIndex < row.count ? Double(row[columnIndex]) : nil
            }
        }()
        
        return ChartData(
            title: "\(recommendation.name) - \(csvData.headers.first ?? "Data")",
            chartType: recommendation.name,
            xLabel: "Index",
            yLabel: numericColumns.first ?? "Value",
            xData: xData,
            yData: yData,
            color: "blue",
            style: "solid"
        )
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedFiles = urls
            analyzeFiles(urls)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    Task { @MainActor in
                        selectedFiles.append(url)
                        analyzeFiles([url])
                    }
                }
            }
        }
        return true
    }
    
    private var supportedContentTypes: [UTType] {
        [
            .commaSeparatedText,
            .tabSeparatedText,
            .json,
            UTType(filenameExtension: "usdz") ?? .data,
            UTType(filenameExtension: "usd") ?? .data,
            UTType(filenameExtension: "ply") ?? .data,
            UTType(filenameExtension: "pcd") ?? .data,
            UTType(filenameExtension: "xyz") ?? .data,
            UTType(filenameExtension: "obj") ?? .data,
            UTType(filenameExtension: "fbx") ?? .data,
            UTType(filenameExtension: "gltf") ?? .data,
            UTType(filenameExtension: "glb") ?? .data,
            UTType(filenameExtension: "stl") ?? .data,
            UTType(filenameExtension: "dae") ?? .data,
            UTType(filenameExtension: "ipynb") ?? .data
        ]
    }
}

// MARK: - Supporting Views
struct FileResultRow: View {
    let result: FileAnalysisResult
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: iconForVisualizationType(result.visualizationType))
                    .font(.title3)
                    .foregroundStyle(colorForVisualizationType(result.visualizationType))
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.fileName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(descriptionForVisualizationType(result.visualizationType))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func iconForVisualizationType(_ type: FileAnalysisResult.VisualizationType) -> String {
        switch type {
        case .dataTable: return "tablecells"
        case .chart2D: return "chart.xyaxis.line"
        case .pointCloud3D: return "circle.grid.3x3.fill"
        case .volumetric3D: return "cube.transparent"
        case .notebook: return "text.book.closed"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private func colorForVisualizationType(_ type: FileAnalysisResult.VisualizationType) -> Color {
        switch type {
        case .dataTable: return .green
        case .chart2D: return .blue
        case .pointCloud3D: return .purple
        case .volumetric3D: return .orange
        case .notebook: return .red
        case .unknown: return .gray
        }
    }
    
    private func descriptionForVisualizationType(_ type: FileAnalysisResult.VisualizationType) -> String {
        switch type {
        case .dataTable: return "Data Table"
        case .chart2D(let rec): return rec.name
        case .pointCloud3D: return "3D Point Cloud"
        case .volumetric3D: return "3D Model"
        case .notebook: return "Interactive Notebook"
        case .unknown: return "Unknown Type"
        }
    }
}

struct FileAnalysisCard: View {
    let result: FileAnalysisResult
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                // Icon and type
                HStack {
                    Image(systemName: iconForVisualizationType(result.visualizationType))
                        .font(.largeTitle)
                        .foregroundStyle(colorForVisualizationType(result.visualizationType))
                    
                    Spacer()
                    
                    Text(result.fileType.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
                
                // File info
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.fileName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(descriptionForVisualizationType(result.visualizationType))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Metadata preview
                if !result.metadata.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(Array(result.metadata.keys.prefix(3)), id: \.self) { key in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: 6, height: 6)
                                Text(key)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Action hint
                HStack {
                    Text("Click to visualize")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.forward.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .frame(height: 180)
        }
        .buttonStyle(.plain)
        .background(Color.gray.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.blue.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: isHovered ? 2 : 1)
        )
        .cornerRadius(12)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 8 : 4)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func iconForVisualizationType(_ type: FileAnalysisResult.VisualizationType) -> String {
        switch type {
        case .dataTable: return "tablecells"
        case .chart2D: return "chart.xyaxis.line"
        case .pointCloud3D: return "circle.grid.3x3.fill"
        case .volumetric3D: return "cube.transparent"
        case .notebook: return "text.book.closed"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private func colorForVisualizationType(_ type: FileAnalysisResult.VisualizationType) -> Color {
        switch type {
        case .dataTable: return .green
        case .chart2D: return .blue
        case .pointCloud3D: return .purple
        case .volumetric3D: return .orange
        case .notebook: return .red
        case .unknown: return .gray
        }
    }
    
    private func descriptionForVisualizationType(_ type: FileAnalysisResult.VisualizationType) -> String {
        switch type {
        case .dataTable: return "Tabular Data Visualization"
        case .chart2D(let rec): return "\(rec.name) Visualization"
        case .pointCloud3D: return "3D Point Cloud Visualization"
        case .volumetric3D: return "3D Model Visualization"
        case .notebook: return "Interactive Notebook Visualization"
        case .unknown: return "Unknown Visualization Type"
        }
    }
}

struct FormatBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview
struct FileAnalyzerView_Previews: PreviewProvider {
    static var previews: some View {
        FileAnalyzerView()
            .frame(width: 1000, height: 700)
    }
}

*/
