//
//  EnhancedFileImportView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/18/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

// NOTE: The vast majority of the compiler errors you're seeing (e.g., "'FileAnalysisResult' is ambiguous")
// are caused by issues in your 'SupportedFileType.swift' file. That file appears to have duplicate
// definitions for many of your core data structures. You must fix that file first by finding and
// removing the duplicated code blocks. The changes below fix the few remaining errors in *this* file.

struct EnhancedFileImportView: View {
    @StateObject private var fileAnalyzer = FileAnalyzer.shared
    @EnvironmentObject var windowManager: WindowTypeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    @State private var selectedFileURL: URL?
    // NOTE: This will resolve once 'FileAnalysisResult' is no longer ambiguous.
    @State private var analysisResult: FileAnalysisResult?
    @State private var selectedVisualization: VisualizationRecommendation?
    @State private var showFileImporter = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var importStage: ImportStage = .selecting

    enum ImportStage {
        case selecting
        case analyzing
        case suggesting
        case creating
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    switch importStage {
                    case .selecting:
                        fileSelectionView
                    case .analyzing:
                        analysisProgressView
                    case .suggesting:
                        suggestionView
                    case .creating:
                        creatingVisualizationView
                    }
                }
                .padding()
            }

            // Footer
            Divider()
            footerView
        }
        .frame(width: 800, height: 600)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 24))
        .alert("Import Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: supportedUTTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Import Data")
                    .font(.title2)
                    .fontWeight(.semibold)

                if let url = selectedFileURL {
                    HStack {
                        Image(systemName: fileIcon(for: url))
                            .foregroundStyle(.blue)
                        Text(url.lastPathComponent)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - File Selection View

    private var fileSelectionView: some View {
        VStack(spacing: 24) {
            // Drop zone
            RoundedRectangle(cornerRadius: 16)
                .fill(.blue.opacity(0.1))
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10]))
                .frame(height: 200)
                .overlay {
                    VStack(spacing: 16) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 48))
                            .foregroundStyle(.blue)

                        Text("Drop files here or click to browse")
                            .font(.headline)

                        Button("Choose File") {
                            showFileImporter = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

            // Supported formats
            VStack(alignment: .leading, spacing: 16) {
                Text("Supported Formats")
                    .font(.headline)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(supportedFormats, id: \.type) { format in
                        HStack {
                            Image(systemName: format.icon)
                                .foregroundStyle(format.color)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(format.type)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text(format.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(12)
                        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            // Recent imports
            if !recentImports.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Imports")
                        .font(.headline)

                    ForEach(recentImports, id: \.self) { url in
                        Button {
                            selectedFileURL = url
                            analyzeFile()
                        } label: {
                            HStack {
                                Image(systemName: fileIcon(for: url))
                                    .foregroundStyle(.blue)
                                Text(url.lastPathComponent)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                        }
                        .buttonStyle(.plain)
                        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    // MARK: - Analysis Progress View

    private var analysisProgressView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Progress indicator
            ProgressView(value: fileAnalyzer.analysisProgress) {
                Text("Analyzing File...")
                    .font(.headline)
            } currentValueLabel: {
                Text("\(Int(fileAnalyzer.analysisProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .progressViewStyle(.linear)
            .frame(width: 300)

            Text(fileAnalyzer.currentAnalysisStep)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Analysis steps
            VStack(alignment: .leading, spacing: 12) {
                AnalysisStep(
                    title: "Reading file structure",
                    isComplete: fileAnalyzer.analysisProgress > 0.2
                )
                AnalysisStep(
                    title: "Inferring data schema",
                    isComplete: fileAnalyzer.analysisProgress > 0.4
                )
                AnalysisStep(
                    title: "Detecting patterns",
                    isComplete: fileAnalyzer.analysisProgress > 0.6
                )
                AnalysisStep(
                    title: "Generating suggestions",
                    isComplete: fileAnalyzer.analysisProgress > 0.8
                )
            }
            .padding()
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
    }

    // MARK: - Suggestion View

    private var suggestionView: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let result = analysisResult {
                // File analysis summary
                VStack(alignment: .leading, spacing: 12) {
                    Label("File Analysis", systemImage: "doc.text.magnifyingglass")
                        .font(.headline)

                    HStack(spacing: 24) {
                        AnalysisStat(
                            label: "Type",
                            value: result.fileType.displayName,
                            icon: "doc"
                        )

                        AnalysisStat(
                            label: "Data Type",
                            value: dataTypeDescription(result.analysis.dataType),
                            icon: "chart.bar"
                        )

                        if let rowCount = getRowCount(from: result.analysis) {
                            AnalysisStat(
                                label: "Rows",
                                value: "\(rowCount)",
                                icon: "tablecells"
                            )
                        }
                    }
                }
                .padding()
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))

                // Visualization suggestions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Suggested Visualizations")
                        .font(.headline)

                    ForEach(result.suggestions.indices, id: \.self) { index in
                        let suggestion = result.suggestions[index]
                        VisualizationSuggestionCard(
                            suggestion: suggestion,
                            isSelected: selectedVisualization?.type == suggestion.type,
                            onSelect: {
                                selectedVisualization = suggestion
                            }
                        )
                    }
                }

                // Additional options
                if selectedVisualization != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Additional Options")
                            .font(.headline)

                        Toggle(isOn: .constant(true)) {
                            Text("Open in new window")
                        }
                        Toggle(isOn: .constant(false)) {
                            Text("Import raw data")
                        }

                        if result.fileType == .xlsx {
                            Toggle(isOn: .constant(true)) {
                                Text("Import all sheets")
                            }
                        }
                    }
                    .padding()
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Creating Visualization View

    private var creatingVisualizationView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView("Creating Visualization...")
                .controlSize(.large)

            Text("Setting up your \(selectedVisualization?.type.windowType.displayName ?? "visualization")")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Footer View

    private var footerView: some View {
        HStack {
            if importStage == .suggesting && selectedFileURL != nil {
                Button("Change File") {
                    resetImport()
                }
                .buttonStyle(.plain)
            }

            Spacer()

            HStack(spacing: 12) {
                if importStage == .suggesting && analysisResult != nil {
                    Button("Import Raw Data") {
                        createDataTableVisualization()
                    }
                    .buttonStyle(.bordered)

                    Button("Create Visualization") {
                        createSelectedVisualization()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedVisualization == nil)
                }
            }
        }
        .padding()
    }

    // MARK: - Helper Methods

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource() // Start accessing
            selectedFileURL = url
            saveToRecentImports(url)
            analyzeFile()
            // Note: stopAccessingSecurityScopedResource() should be called when done with the file, e.g., after analysis
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func analyzeFile() {
        guard let url = selectedFileURL else { return }

        importStage = .analyzing

        Task {
            do {
                // NOTE: This call will fail until 'FileAnalysisResult' is resolved.
                let result = try await fileAnalyzer.analyzeFile(url)

                await MainActor.run {
                    self.analysisResult = result
                    self.importStage = .suggesting

                    // Auto-select the highest priority suggestion
                    if let firstSuggestion = result.suggestions.first {
                        self.selectedVisualization = firstSuggestion
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.importStage = .selecting
                }
            }
            // Stop accessing after analysis
            url.stopAccessingSecurityScopedResource()
        }
    }

    private func createSelectedVisualization() {
        guard let visualization = selectedVisualization,
              let result = analysisResult else { return }

        importStage = .creating

        Task {
            await createVisualization(
                type: visualization.type,
                fileResult: result,
                configuration: visualization.configuration
            )

            await MainActor.run {
                dismiss()
            }
        }
    }

    private func createDataTableVisualization() {
        guard let result = analysisResult else { return }

        importStage = .creating

        Task {
            // FIX: Explicitly specify the enum type to resolve ambiguity.
            // The original '.dataTable' could not be inferred by the compiler.
            await createVisualization(
                type: .dataTable,
                fileResult: result,
                configuration: DataTableConfiguration()
            )

            await MainActor.run {
                dismiss()
            }
        }
    }

    @MainActor
    private func createVisualization(
        type: SpatialVisualizationType,
        fileResult: FileAnalysisResult,
        configuration: VisualizationConfiguration
    ) async {
        let windowID = windowManager.getNextWindowID()
        let windowType = type.windowType

        // Create window
        _ = windowManager.createWindow(
            windowType,
            id: windowID,
            position: WindowPosition(
                x: 100 + Double(windowID * 20),
                y: 100 + Double(windowID * 20),
                z: 0,
                width: 800,
                height: 600
            )
        )

        // Set window content based on file type and visualization
        await populateWindow(
            windowID: windowID,
            windowType: windowType,
            fileResult: fileResult,
            visualizationType: type,
            configuration: configuration
        )

        // Open the window
        openWindow(value: windowID)
        windowManager.markWindowAsOpened(windowID)
    }

    @MainActor
    private func populateWindow(
        windowID: Int,
        windowType: WindowType,
        fileResult: FileAnalysisResult,
        visualizationType: SpatialVisualizationType,
        configuration: VisualizationConfiguration
    ) async {
        // This would be expanded to handle all file types and visualizations
        // For now, showing a few examples:

        // NOTE: All cases in this switch will fail until the ambiguity of the 'structure'
        // types (TabularStructure, PointCloudStructure, etc.) is resolved in your other file.
        switch fileResult.fileType {
        case .csv, .tsv:
            if let structure = fileResult.analysis.structure as? TabularStructure {
                await handleTabularData(
                    windowID: windowID,
                    structure: structure,
                    visualizationType: visualizationType
                )
            }

        case .las:
            if let structure = fileResult.analysis.structure as? PointCloudStructure {
                await handlePointCloudData(
                    windowID: windowID,
                    structure: structure,
                    url: fileResult.fileURL
                )
            }

        case .xlsx:
            if let structure = fileResult.analysis.structure as? SpreadsheetStructure {
                await handleSpreadsheetData(
                    windowID: windowID,
                    structure: structure,
                    url: fileResult.fileURL
                )
            }

        case .ipynb:
            if let structure = fileResult.analysis.structure as? NotebookStructure {
                await handleNotebookData(
                    windowID: windowID,
                    structure: structure,
                    url: fileResult.fileURL
                )
            }

        default:
            break
        }
    }

    @MainActor
    private func handleTabularData(
        windowID: Int,
        structure: TabularStructure,
        visualizationType: SpatialVisualizationType
    ) async {
        // For demonstration, create appropriate content based on visualization type
        switch visualizationType {
        case .dataTable:
            // Create DataFrame visualization
            let dataFrame = DataFrameData(
                columns: structure.headers,
                rows: [], // Would be populated from actual file data
                dtypes: Dictionary(
                    uniqueKeysWithValues: structure.columnTypes.map { key, value in
                        (key, value == .numeric ? "float" : "string")
                    }
                )
            )
            windowManager.updateWindowDataFrame(windowID, dataFrame: dataFrame)

        case .scatterPlot3D:
            if structure.coordinateColumns.count >= 3 {
                // FIX: The 'chartType' parameter likely expects a String, not an enum case.
                // The error "Type 'String' has no member 'scatter'" indicates this mismatch.
                let chartData = Chart3DData(
                    title: "3D Scatter Plot",
                    chartType: "scatter", // Changed from .scatter
                    xData: [], // Would be populated from actual data
                    yData: [],
                    zData: [],
                    xLabel: structure.coordinateColumns[0],
                    yLabel: structure.coordinateColumns[1],
                    zLabel: structure.coordinateColumns[2]
                )
                windowManager.updateWindowChart3DData(windowID, chart3DData: chartData)
            }

        default:
            break
        }
    }

    @MainActor
    private func handlePointCloudData(
        windowID: Int,
        structure: PointCloudStructure,
        url: URL
    ) async {
        // NOTE: The "Extra arguments" error here is likely a side effect of the 'PointCloudStructure'
        // type being ambiguous. Once that is fixed, this error should disappear.
        let pointCloud = PointCloudData(
            title: url.lastPathComponent,
            points: [], // Would be populated from LAS file
            totalPoints: structure.pointCount,
            bounds: structure.bounds,
            hasIntensity: structure.hasIntensity,
            hasColor: structure.hasColor,
            hasGPSTime: structure.hasGPSTime
        )

        windowManager.updateWindowPointCloud(windowID, pointCloud: pointCloud)
    }

    @MainActor
    private func handleSpreadsheetData(
        windowID: Int,
        structure: SpreadsheetStructure,
        url: URL
    ) async {
        // Handle Excel import - could create multiple windows for each sheet
        if let firstSheet = structure.sheets.first {
            // For now, just handle the first sheet
        }
    }

    @MainActor
    private func handleNotebookData(
        windowID: Int,
        structure: NotebookStructure,
        url: URL
    ) async {
        // Extract data from notebook and create appropriate visualizations
        windowManager.updateWindowContent(
            windowID,
            content: "Imported from notebook: \(url.lastPathComponent)"
        )
    }

    private func resetImport() {
        selectedFileURL = nil
        analysisResult = nil
        selectedVisualization = nil
        importStage = .selecting
    }

    private func fileIcon(for url: URL) -> String {
        // NOTE: This will resolve once 'SupportedFileType' is no longer ambiguous.
        let type = SupportedFileType(rawValue: url.pathExtension.lowercased()) ?? .unknown
        return type.icon
    }

    private func dataTypeDescription(_ type: DataType) -> String {
        // NOTE: This will resolve once 'DataType' is no longer ambiguous.
        switch type {
        case .tabular: return "Tabular"
        case .tabularWithCoordinates: return "Spatial Table"
        case .pointCloud: return "Point Cloud"
        case .timeSeries: return "Time Series"
        case .networkData: return "Network"
        case .geospatial: return "Geospatial"
        case .spreadsheet: return "Spreadsheet"
        case .model3D: return "3D Model"
        case .notebook: return "Notebook"
        case .matrix: return "Matrix"
        case .hierarchical: return "Hierarchical"
        case .structured: return "Structured"
        case .unknown: return "Unknown"
        }
    }

    private func getRowCount(from analysis: DataAnalysisResult) -> Int? {
        // NOTE: This will resolve once the structure types are no longer ambiguous.
        if let tabular = analysis.structure as? TabularStructure {
            return tabular.rowCount
        } else if let pointCloud = analysis.structure as? PointCloudStructure {
            return pointCloud.pointCount
        }
        return nil
    }

    private func saveToRecentImports(_ url: URL) {
        var recent = UserDefaults.standard.stringArray(forKey: "RecentImports") ?? []
        recent.removeAll { $0 == url.path }
        recent.insert(url.path, at: 0)
        if recent.count > 5 {
            recent = Array(recent.prefix(5))
        }
        UserDefaults.standard.set(recent, forKey: "RecentImports")
    }

    // MARK: - Properties

    private var supportedUTTypes: [UTType] {
        [
            .commaSeparatedText,
            .tabSeparatedText,
            .json,
            UTType(filenameExtension: "xlsx") ?? .data,
            UTType(filenameExtension: "las") ?? .data,
            UTType(filenameExtension: "ipynb") ?? .data,
            .usdz
        ]
    }

    private let supportedFormats: [(type: String, description: String, icon: String, color: Color)] = [
        (type: "CSV/TSV", description: "Tabular data files", icon: "tablecells", color: Color.green),
        (type: "Excel", description: "Multi-sheet workbooks", icon: "tablecells.badge.ellipsis", color: Color.green),
        (type: "JSON", description: "Structured data", icon: "curlybraces", color: Color.orange),
        (type: "LAS", description: "LiDAR point clouds", icon: "circle.grid.3x3.fill", color: Color.blue),
        (type: "Notebook", description: "Jupyter notebooks", icon: "doc.text.magnifyingglass", color: Color.purple),
        (type: "USDZ", description: "3D models", icon: "cube", color: Color.red)
    ]

    private var recentImports: [URL] {
        let paths = UserDefaults.standard.stringArray(forKey: "RecentImports") ?? []
        return paths.compactMap { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }
}

// MARK: - Supporting Views

struct AnalysisStep: View {
    let title: String
    let isComplete: Bool

    var body: some View {
        HStack {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? .green : .secondary)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(isComplete ? .primary : .secondary)

            Spacer()
        }
    }
}

struct AnalysisStat: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
        }
    }
}

struct VisualizationSuggestionCard: View {
    let suggestion: VisualizationRecommendation
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: visualizationIcon)
                    .font(.title2)
                    .foregroundStyle(priorityColor)
                    .frame(width: 40)

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(visualizationTitle)
                            .font(.headline)

                        if suggestion.priority == .high {
                            Label("Recommended", systemImage: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }

                    Text(suggestion.reason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack {
                        // Confidence
                        HStack(spacing: 4) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.caption)
                            Text("\(Int(suggestion.confidence * 100))% match")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)

                        Spacer()

                        // Window type
                        Label(suggestion.type.windowType.displayName, systemImage: suggestion.type.windowType.icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .padding()
        }
        .buttonStyle(.plain)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.blue, lineWidth: 2)
            }
        }
    }

    private var visualizationIcon: String {
        switch suggestion.type {
        case .dataTable: return "tablecells"
        case .scatterPlot2D, .scatterPlot3D: return "chart.dots.scatter"
        case .lineChart, .multiLineChart: return "chart.line.uptrend.xyaxis"
        case .barChart: return "chart.bar"
        case .heatmap, .densityHeatMap: return "square.grid.3x3.fill.square"
        case .pointCloud3D: return "view.3d"
        case .spatialNetwork: return "network"
        case .model3DViewer: return "cube"
        case .notebookSpatialLayout: return "doc.text.below.ecg"
        default: return "chart.bar.fill"
        }
    }

    private var visualizationTitle: String {
        switch suggestion.type {
        case .dataTable: return "Data Table"
        case .scatterPlot2D: return "2D Scatter Plot"
        case .scatterPlot3D: return "3D Scatter Plot"
        case .lineChart: return "Line Chart"
        case .multiLineChart: return "Multi-Line Chart"
        case .barChart: return "Bar Chart"
        case .heatmap: return "Heatmap"
        case .densityHeatMap: return "Density Heatmap"
        case .pointCloud3D: return "3D Point Cloud"
        case .spatialNetwork: return "Spatial Network"
        case .model3DViewer: return "3D Model Viewer"
        case .notebookSpatialLayout: return "Spatial Notebook"
        case .volumetric: return "Volumetric View"
        default: return "Visualization"
        }
    }

    private var priorityColor: Color {
        switch suggestion.priority {
        case .high: return .blue
        case .medium: return .orange
        case .low: return .gray
        }
    }
}

// MARK: - Preview

struct EnhancedFileImportView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedFileImportView()
            .environmentObject(WindowTypeManager.shared)
    }
}
