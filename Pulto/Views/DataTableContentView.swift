//
//  DataTableContentView.swift
//  Pulto
//
//  Created by Joshua Herman on 6/16/25.
//  Copyright 2025 Apple. All rights reserved.
//
import SwiftUI
import RealityKit
import UniformTypeIdentifiers

// MARK: - Supporting Types for Spatial Data Visualization

enum SpatialDataType: String, CaseIterable {
    case pointCloud = "pointCloud"
    case volumetric = "volumetric"
    case mesh = "mesh"
    case voxel = "voxel"
    case notebook = "notebook"
}

struct SpatialDataItem {
    let dataType: SpatialDataType
    let rawData: Data
    let dimensions: SIMD3<Float>
    let pointCount: Int
    let metadata: [String: Any]
    
    init(dataType: SpatialDataType, rawData: Data = Data(), dimensions: SIMD3<Float> = SIMD3<Float>(1, 1, 1), pointCount: Int = 100, metadata: [String: Any] = [:]) {
        self.dataType = dataType
        self.rawData = rawData
        self.dimensions = dimensions
        self.pointCount = pointCount
        self.metadata = metadata
    }
}

struct PointCloudVisualizationData {
    let points: [SIMD3<Float>]
    let colors: [SIMD3<Float>]?
    let center: SIMD3<Float>
    
    init(points: [SIMD3<Float>], colors: [SIMD3<Float>]? = nil) {
        self.points = points
        self.colors = colors
        
        // Calculate center
        let sum = points.reduce(SIMD3<Float>(0, 0, 0)) { $0 + $1 }
        self.center = sum / Float(points.count)
    }
}

// Enhanced DataFrame viewer with spreadsheet-like appearance - Cross-platform version
struct DataTableContentView: View {

    let windowID: Int?
    let initialDataFrame: DataFrameData?

    // use an existing frame, a window-saved frame, or fall back to a sample
    init(windowID: Int? = nil, initialDataFrame: DataFrameData? = nil) {
        self.windowID = windowID
        self.initialDataFrame = initialDataFrame
        let seed = initialDataFrame ?? Self.defaultSample()
        _sampleData = State(initialValue: seed)
    }

    @StateObject private var windowManager = WindowTypeManager.shared
    @State private var sampleData = DataFrameData(
        columns: ["Name", "Age", "City", "Salary"],
        rows: [
            ["Alice", "28", "New York", "75000"],
            ["Bob", "35", "San Francisco", "95000"],
            ["Charlie", "42", "Austin", "68000"],
            ["Diana", "31", "Seattle", "82000"]
        ],
        dtypes: ["Name": "string", "Age": "int", "City": "string", "Salary": "float"]
    )
    @State private var editingData = false
    @State private var selectedCell: (row: Int, col: Int)? = nil
    @State private var hoveredCell: (row: Int, col: Int)? = nil
    @State private var sortColumn: String? = nil
    @State private var sortAscending = true
    @State private var showingDataImport = false
    @State private var showingFileImporter = false
    @State private var importError: String?

    // Column widths
    @State private var columnWidths: [String: CGFloat] = [:]

    // Platform-specific colors
    #if os(macOS)
    let backgroundColor = Color(NSColor.controlBackgroundColor)
    let windowBackgroundColor = Color(NSColor.windowBackgroundColor)
    let textBackgroundColor = Color(NSColor.textBackgroundColor)
    let separatorColor = Color(NSColor.separatorColor)
    let gridColor = Color(NSColor.gridColor)
    let alternatingRowColor = Color(NSColor.alternatingContentBackgroundColors[1])
    let selectedContentColor = Color(NSColor.selectedContentBackgroundColor)
    #else
    let backgroundColor = Color.primary.opacity(0.05)
    let windowBackgroundColor = Color.primary.opacity(0.02)
    let textBackgroundColor = Color.primary.opacity(0.02)
    let separatorColor = Color.primary.opacity(0.2)
    let gridColor = Color.primary.opacity(0.1)
    let alternatingRowColor = Color.primary.opacity(0.03)
    let selectedContentColor = Color.primary.opacity(0.15)
    #endif

    // Static method to provide default sample data
    static func defaultSample() -> DataFrameData {
        return DataFrameData(
            columns: ["Name", "Age", "City", "Salary"],
            rows: [
                ["Alice", "28", "New York", "75000"],
                ["Bob", "35", "San Francisco", "95000"],
                ["Charlie", "42", "Austin", "68000"],
                ["Diana", "31", "Seattle", "82000"]
            ],
            dtypes: ["Name": "string", "Age": "int", "City": "string", "Salary": "float"]
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbarView

            // Main content
            if editingData {
                dataEditorView
            } else {
                spreadsheetView
            }

            // Status bar
            statusBarView
        }
        .background(backgroundColor)
        .onAppear {
            loadDataFromWindow()
            initializeColumnWidths()
        }
        .sheet(isPresented: $showingDataImport) {
            DataImportSheet(
                onDataImported: { importedData in
                    sampleData = importedData
                    initializeColumnWidths()
                    if let windowID = windowID {
                        saveDataToWindow()
                    }
                }
            )
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [
                UTType.commaSeparatedText,
                UTType.tabSeparatedText,
                UTType.json,
                UTType.plainText
            ],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("Import Error", isPresented: .constant(importError != nil)) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    // MARK: - Data Import Sheet
    struct DataImportSheet: View {
        let onDataImported: (DataFrameData) -> Void
        @Environment(\.dismiss) private var dismiss
        @State private var importMethod: ImportMethod = .file
        @State private var showingFileImporter = false
        @State private var showingCSVRecommender = false
        @State private var sampleText = ""
        @State private var customDelimiter = ","
        @State private var hasHeaders = true
        @State private var importError: String?
        @State private var urlString = ""
        @State private var isDownloading = false
        @State private var apiEndpoint = ""
        @State private var apiHeaders: [String: String] = [:]
        @State private var newHeaderKey = ""
        @State private var newHeaderValue = ""
        
        enum ImportMethod: String, CaseIterable {
            case file = "File"
            case paste = "Paste"
            case sample = "Sample"
            case csv = "CSV with Chart Recommendations"
            case webUrl = "Web URL"
            case webApi = "Web API"
            case shareSheet = "Share from Safari"
            
            var icon: String {
                switch self {
                case .file: return "doc.text"
                case .paste: return "doc.on.clipboard"
                case .sample: return "sparkles"
                case .csv: return "chart.bar.doc.horizontal"
                case .webUrl: return "globe"
                case .webApi: return "server.rack"
                case .shareSheet: return "square.and.arrow.up"
                }
            }
        }
        
        var body: some View {
            NavigationView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Import Data")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Choose how you'd like to import your data")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Import methods
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        ForEach(ImportMethod.allCases, id: \.self) { method in
                            ImportMethodCard(
                                method: method,
                                isSelected: importMethod == method
                            ) {
                                importMethod = method
                                handleMethodSelection(method)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            // Options for different import methods
                            switch importMethod {
                            case .paste:
                                pasteDataView
                            case .webUrl:
                                webUrlView
                            case .webApi:
                                webApiView
                            case .shareSheet:
                                shareSheetView
                            default:
                                EmptyView()
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .navigationTitle("Data Import")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                .fileImporter(
                    isPresented: $showingFileImporter,
                    allowedContentTypes: [
                        UTType.commaSeparatedText,
                        UTType.tabSeparatedText,
                        UTType.json,
                        UTType.plainText
                    ],
                    allowsMultipleSelection: false
                ) { result in
                    handleFileImport(result)
                }
                .sheet(isPresented: $showingCSVRecommender) {
                    if #available(iOS 16.0, macOS 13.0, *) {
                        CSVChartRecommenderView()
                    } else {
                        Text("CSV Chart Recommender requires iOS 16.0 or macOS 13.0")
                            .padding()
                    }
                }
                .alert("Import Error", isPresented: .constant(importError != nil)) {
                    Button("OK") { importError = nil }
                } message: {
                    Text(importError ?? "")
                }
            }
        }
        
        // MARK: - Individual Import Views
        
        private var pasteDataView: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Paste your data below:")
                    .font(.headline)
                
                HStack {
                    Text("Delimiter:")
                    TextField("Delimiter", text: $customDelimiter)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    
                    Toggle("Has Headers", isOn: $hasHeaders)
                }
                
                TextEditor(text: $sampleText)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                
                Button("Import Data") {
                    handlePasteImport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(sampleText.isEmpty)
            }
        }
        
        private var webUrlView: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Import CSV from Web URL:")
                    .font(.headline)
                
                Text("Enter a direct link to a CSV file (must be HTTPS)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("https://example.com/data.csv", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                
                HStack {
                    Text("Delimiter:")
                    TextField("Delimiter", text: $customDelimiter)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    
                    Toggle("Has Headers", isOn: $hasHeaders)
                }
                
                // Sample URLs for testing
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sample URLs:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Button("Sample Sales Data") {
                        urlString = "https://raw.githubusercontent.com/datasets/gdp/master/data/gdp.csv"
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    
                    Button("World Population Data") {
                        urlString = "https://raw.githubusercontent.com/datasets/population/master/data/population.csv"
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                Button("Download and Import") {
                    Task {
                        await downloadFromWeb()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlString.isEmpty || isDownloading)
                
                if isDownloading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Downloading...")
                            .font(.caption)
                    }
                }
            }
        }
        
        private var webApiView: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Import from Web API:")
                    .font(.headline)
                
                Text("Connect to a REST API that returns CSV data")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("https://api.example.com/data", text: $apiEndpoint)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                
                // API Headers section
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Headers (Optional):")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        TextField("Header Key", text: $newHeaderKey)
                            .textFieldStyle(.roundedBorder)
                        TextField("Header Value", text: $newHeaderValue)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            if !newHeaderKey.isEmpty && !newHeaderValue.isEmpty {
                                apiHeaders[newHeaderKey] = newHeaderValue
                                newHeaderKey = ""
                                newHeaderValue = ""
                            }
                        }
                        .disabled(newHeaderKey.isEmpty || newHeaderValue.isEmpty)
                    }
                    
                    // Display existing headers
                    ForEach(Array(apiHeaders.keys), id: \.self) { key in
                        HStack {
                            Text("\(key): \(apiHeaders[key] ?? "")")
                                .font(.caption)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                            
                            Spacer()
                            
                            Button("Remove") {
                                apiHeaders.removeValue(forKey: key)
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Common API examples
                VStack(alignment: .leading, spacing: 8) {
                    Text("Common API Patterns:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Button("JSONPlaceholder (Demo API)") {
                        apiEndpoint = "https://jsonplaceholder.typicode.com/users"
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    
                    Button("GitHub API (Public repos)") {
                        apiEndpoint = "https://api.github.com/search/repositories?q=swift&sort=stars"
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                
                HStack {
                    Text("Response Format:")
                    Picker("Format", selection: .constant("JSON")) {
                        Text("JSON").tag("JSON")
                        Text("CSV").tag("CSV")
                    }
                    .pickerStyle(.segmented)
                }
                
                Button("Fetch from API") {
                    Task {
                        await fetchFromAPI()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiEndpoint.isEmpty || isDownloading)
                
                if isDownloading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Fetching data...")
                            .font(.caption)
                    }
                }
            }
        }
        
        private var shareSheetView: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Share from Safari:")
                    .font(.headline)
                
                Text("Use this method to import CSV files from web pages")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Instructions:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Group {
                        Text("1. Open Safari and navigate to a CSV file")
                        Text("2. Tap the Share button")
                        Text("3. Select this app from the share sheet")
                        Text("4. The CSV will be automatically imported")
                    }
                    .font(.caption)
                    .padding(.leading, 16)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Supported Sources:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Group {
                        Text("• Google Sheets (published as CSV)")
                        Text("• Dropbox public links")
                        Text("• GitHub raw CSV files")
                        Text("• Government open data portals")
                        Text("• Any direct CSV download link")
                    }
                    .font(.caption)
                    .padding(.leading, 16)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                
                Button("Open Safari") {
                    if let url = URL(string: "https://www.google.com/search?q=csv+data+site:github.com") {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        
        // MARK: - Import Methods
        
        private func handleMethodSelection(_ method: ImportMethod) {
            switch method {
            case .file:
                showingFileImporter = true
            case .csv:
                if #available(iOS 16.0, macOS 13.0, *) {
                    showingCSVRecommender = true
                } else {
                    importError = "CSV Chart Recommender requires iOS 16.0 or macOS 13.0"
                }
            case .sample:
                loadSampleDataset()
            case .paste, .webUrl, .webApi, .shareSheet:
                break // UI will show appropriate form
            }
        }
        
        private func downloadFromWeb() async {
            guard let url = URL(string: urlString), url.scheme == "https" else {
                importError = "Please enter a valid HTTPS URL"
                return
            }
            
            isDownloading = true
            defer { isDownloading = false }
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    importError = "Failed to download: Invalid response"
                    return
                }
                
                guard let content = String(data: data, encoding: .utf8) else {
                    importError = "Failed to decode CSV data"
                    return
                }
                
                let importedData = try parseDelimitedText(content, delimiter: customDelimiter, hasHeaders: hasHeaders)
                onDataImported(importedData)
                dismiss()
                
            } catch {
                importError = "Download failed: \(error.localizedDescription)"
            }
        }
        
        private func fetchFromAPI() async {
            guard let url = URL(string: apiEndpoint) else {
                importError = "Please enter a valid API endpoint"
                return
            }
            
            isDownloading = true
            defer { isDownloading = false }
            
            do {
                var request = URLRequest(url: url)
                
                // Add custom headers
                for (key, value) in apiHeaders {
                    request.setValue(value, forHTTPHeaderField: key)
                }
                
                // Set content type
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      200...299 ~= httpResponse.statusCode else {
                    importError = "API request failed: Invalid response"
                    return
                }
                
                // Try to parse as JSON first, then convert to CSV format
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) {
                    let importedData = try convertJSONToDataFrame(json: jsonObject)
                    onDataImported(importedData)
                    dismiss()
                } else if let content = String(data: data, encoding: .utf8) {
                    // Try to parse as direct CSV
                    let importedData = try parseDelimitedText(content, delimiter: customDelimiter, hasHeaders: hasHeaders)
                    onDataImported(importedData)
                    dismiss()
                } else {
                    importError = "Unable to parse API response"
                }
                
            } catch {
                importError = "API request failed: \(error.localizedDescription)"
            }
        }
        
        private func convertJSONToDataFrame(json: Any) throws -> DataFrameData {
            if let array = json as? [[String: Any]] {
                // Array of objects
                let allKeys = Set(array.flatMap { $0.keys })
                let columns = Array(allKeys).sorted()
                
                let rows = array.map { object in
                    columns.map { column in
                        if let value = object[column] {
                            return String(describing: value)
                        } else {
                            return ""
                        }
                    }
                }
                
                let dtypes = autoDetectDataTypes(columns: columns, rows: rows)
                return DataFrameData(
                    columns: columns,
                    rows: rows,
                    dtypes: dtypes
                )
                
            } else if let object = json as? [String: Any] {
                // Single object - treat each key-value as a row
                let columns = ["Key", "Value"]
                let rows = object.map { [String($0.key), String(describing: $0.value)] }
                let dtypes = autoDetectDataTypes(columns: columns, rows: rows)
                return DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
                
            } else {
                throw ImportError.invalidFormat
            }
        }
        
        // ... rest of the existing methods remain the same ...
        
        private func loadSampleDataset() {
            let sampleData = DataFrameData(
                columns: ["Product", "Sales", "Region", "Quarter", "Profit"],
                rows: [
                    ["iPhone 15", "1500000", "North America", "Q1", "450000"],
                    ["MacBook Pro", "800000", "Europe", "Q1", "320000"],
                    ["iPad Air", "600000", "Asia", "Q1", "180000"],
                    ["Apple Watch", "400000", "North America", "Q2", "160000"],
                    ["AirPods Pro", "1200000", "Global", "Q2", "360000"],
                    ["Mac Studio", "200000", "North America", "Q2", "100000"],
                    ["iPhone 15 Pro", "2000000", "Global", "Q3", "700000"],
                    ["iPad Pro", "500000", "Europe", "Q3", "200000"]
                ],
                dtypes: ["Product": "string", "Sales": "int", "Region": "string", "Quarter": "string", "Profit": "int"]
            )
            
            onDataImported(sampleData)
            dismiss()
        }
        
        private func handlePasteImport() {
            do {
                let importedData = try parseDelimitedText(sampleText, delimiter: customDelimiter, hasHeaders: hasHeaders)
                onDataImported(importedData)
                dismiss()
            } catch {
                importError = "Failed to parse pasted data: \(error.localizedDescription)"
            }
        }
        
        private func handleFileImport(_ result: Result<[URL], Error>) {
            switch result {
            case .success(let urls):
                guard let url = urls.first else { 
                    importError = "No file selected"
                    return 
                }
                
                do {
                    // Ensure we can access the file
                    guard url.startAccessingSecurityScopedResource() else {
                        importError = "Cannot access the selected file"
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    let content = try String(contentsOf: url)
                    let fileExtension = url.pathExtension.lowercased()
                    
                    let importedData: DataFrameData
                    
                    switch fileExtension {
                    case "csv":
                        importedData = try parseDelimitedText(content, delimiter: ",", hasHeaders: true)
                    case "tsv", "txt":
                        importedData = try parseDelimitedText(content, delimiter: "\t", hasHeaders: true)
                    case "json":
                        importedData = try parseJSONData(content)
                    default:
                        // Try to auto-detect delimiter for unknown extensions
                        if content.contains(",") {
                            importedData = try parseDelimitedText(content, delimiter: ",", hasHeaders: true)
                        } else if content.contains("\t") {
                            importedData = try parseDelimitedText(content, delimiter: "\t", hasHeaders: true)
                        } else {
                            throw ImportError.invalidFormat
                        }
                    }
                    
                    onDataImported(importedData)
                    dismiss()
                } catch {
                    importError = "Error reading file: \(error.localizedDescription)"
                }
                
            case .failure(let error):
                importError = "Import failed: \(error.localizedDescription)"
            }
        }
        
        private func parseDelimitedText(_ content: String, delimiter: String, hasHeaders: Bool) throws -> DataFrameData {
            let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard !lines.isEmpty else {
                throw ImportError.noData
            }
            
            let rows = lines.map { line in
                line.components(separatedBy: delimiter).map { $0.trimmingCharacters(in: .whitespaces) }
            }
            
            let columns: [String]
            let dataRows: [[String]]
            
            if hasHeaders && !rows.isEmpty {
                columns = rows[0]
                dataRows = Array(rows.dropFirst())
            } else {
                let columnCount = rows.first?.count ?? 0
                columns = (1...columnCount).map { "Column \($0)" }
                dataRows = rows
            }
            
            // Auto-detect data types
            let dtypes = autoDetectDataTypes(columns: columns, rows: dataRows)
            
            return DataFrameData(columns: columns, rows: dataRows, dtypes: dtypes)
        }
        
        private func parseJSONData(_ content: String) throws -> DataFrameData {
            guard let data = content.data(using: .utf8) else {
                throw ImportError.invalidFormat
            }
            
            let json = try JSONSerialization.jsonObject(with: data)
            return try convertJSONToDataFrame(json: json)
        }
        
        private func autoDetectDataTypes(columns: [String], rows: [[String]]) -> [String: String] {
            var dtypes: [String: String] = [:]
            
            for (index, column) in columns.enumerated() {
                let columnValues = rows.compactMap { row in
                    index < row.count ? row[index] : nil
                }.filter { !$0.isEmpty }
                
                if columnValues.isEmpty {
                    dtypes[column] = "string"
                    continue
                }
                
                let numericCount = columnValues.compactMap { Double($0) }.count
                let booleanCount = columnValues.filter { $0.lowercased() == "true" || $0.lowercased() == "false" }.count
                
                if Double(numericCount) / Double(columnValues.count) > 0.8 {
                    if columnValues.allSatisfy({ $0.contains(".") || Int($0) == nil }) {
                        dtypes[column] = "float"
                    } else {
                        dtypes[column] = "int"
                    }
                } else if Double(booleanCount) / Double(columnValues.count) > 0.8 {
                    dtypes[column] = "bool"
                } else {
                    dtypes[column] = "string"
                }
            }
            
            return dtypes
        }
        
        enum ImportError: LocalizedError {
            case noData
            case invalidFormat
            case parsingFailed
            
            var errorDescription: String? {
                switch self {
                case .noData:
                    return "No data found in the input"
                case .invalidFormat:
                    return "Invalid data format"
                case .parsingFailed:
                    return "Failed to parse the data"
                }
            }
        }
    }
    
    struct ImportMethodCard: View {
        let method: DataImportSheet.ImportMethod
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 12) {
                    Image(systemName: method.icon)
                        .font(.system(size: 40))
                        .foregroundColor(isSelected ? .white : .blue)
                    
                    Text(method.rawValue)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var toolbarView: some View {
        HStack(spacing: 16) {
            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text("DataFrame")
                    .font(.headline)
                Text("\(sampleData.shapeRows) rows × \(sampleData.shapeColumns) columns")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                /*
                Button(action: { showingDataImport = true }) {
                    Label("Import Data", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(6)
                */

                Button(action: { loadSampleData() }) {
                    Label("Sample Data", systemImage: "doc.text")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)

                Button(action: { editingData.toggle() }) {
                    Label(editingData ? "Done" : "Edit", systemImage: editingData ? "checkmark.circle" : "pencil")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)

                Button(action: { saveDataToWindow() }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(windowBackgroundColor)
    }

    private var spreadsheetView: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                // Column headers
                HStack(spacing: 0) {
                    // Row number header
                    Text("#")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                        .padding(.vertical, 8)
                        .background(gridColor.opacity(0.1))
                        .overlay(
                            Rectangle()
                                .stroke(separatorColor, lineWidth: 0.5)
                        )

                    // Column headers
                    ForEach(sampleData.columns, id: \.self) { column in
                        columnHeaderView(column: column)
                    }
                }

                // Data rows
                ForEach(0..<sampleData.rows.count, id: \.self) { rowIndex in
                    HStack(spacing: 0) {
                        // Row number
                        Text("\(rowIndex + 1)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                            .padding(.vertical, 8)
                            .background(gridColor.opacity(0.1))
                            .overlay(
                                Rectangle()
                                    .stroke(separatorColor, lineWidth: 0.5)
                            )

                        // Data cells
                        ForEach(0..<sampleData.columns.count, id: \.self) { colIndex in
                            cellView(rowIndex: rowIndex, colIndex: colIndex)
                        }
                    }
                    .background(rowIndex % 2 == 0 ? Color.clear : alternatingRowColor)
                }
            }
        }
        .background(textBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(separatorColor, lineWidth: 1)
        )
        .padding()
    }

    private func columnHeaderView(column: String) -> some View {
        HStack(spacing: 4) {
            Text(column)
                .font(.system(.caption))
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer(minLength: 0)

            // Sort indicator
            if sortColumn == column {
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            // Data type indicator
            if let dtype = sampleData.dtypes[column] {
                Image(systemName: dtypeIcon(dtype))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(width: columnWidths[column] ?? 120)
        .background(gridColor.opacity(0.1))
        .overlay(
            Rectangle()
                .stroke(separatorColor, lineWidth: 0.5)
        )
        .onTapGesture {
            toggleSort(column: column)
        }
    }

    private func cellView(rowIndex: Int, colIndex: Int) -> some View {
        let value = rowIndex < sampleData.rows.count && colIndex < sampleData.rows[rowIndex].count
            ? sampleData.rows[rowIndex][colIndex]
            : ""
        let column = sampleData.columns[colIndex]
        let isSelected = selectedCell?.row == rowIndex && selectedCell?.col == colIndex
        let isHovered = hoveredCell?.row == rowIndex && hoveredCell?.col == colIndex

        return Text(formatCellValue(value, dtype: sampleData.dtypes[column]))
            .font(.system(.body, design: .monospaced))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(width: columnWidths[column] ?? 120, alignment: cellAlignment(for: sampleData.dtypes[column]))
            .background(
                Group {
                    if isSelected {
                        Color.accentColor.opacity(0.2)
                    } else if isHovered {
                        selectedContentColor.opacity(0.1)
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                Rectangle()
                    .stroke(
                        isSelected ? Color.accentColor : separatorColor,
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
            .onTapGesture {
                selectedCell = (row: rowIndex, col: colIndex)
            }
            .onHover { hovering in
                if hovering {
                    hoveredCell = (row: rowIndex, col: colIndex)
                } else if hoveredCell?.row == rowIndex && hoveredCell?.col == colIndex {
                    hoveredCell = nil
                }
            }
    }

    private var dataEditorView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pencil.line")
                    .foregroundColor(.secondary)
                Text("Edit DataFrame")
                    .font(.headline)
            }

            Text("Paste CSV data below:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: .constant(toCSVString()))
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(textBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(separatorColor, lineWidth: 1)
                )
        }
        .padding()
    }

    private var statusBarView: some View {
        HStack {
            if let selected = selectedCell {
                Label(
                    "Cell: \(sampleData.columns[selected.col]):\(selected.row + 1)",
                    systemImage: "square.dashed"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                Text("Click a cell to select")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let selected = selectedCell {
                let value = sampleData.rows[selected.row][selected.col]
                Text("Value: \(value)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(windowBackgroundColor)
        .overlay(
            Rectangle()
                .fill(separatorColor)
                .frame(height: 0.5),
            alignment: .top
        )
    }

    // Helper functions
    private func initializeColumnWidths() {
        for column in sampleData.columns {
            let dtype = sampleData.dtypes[column] ?? "string"
            switch dtype {
            case "int", "float":
                columnWidths[column] = 100
            case "string":
                columnWidths[column] = 150
            default:
                columnWidths[column] = 120
            }
        }
    }

    private func dtypeIcon(_ dtype: String) -> String {
        switch dtype {
        case "int", "float":
            return "number"
        case "string":
            return "textformat"
        case "bool":
            return "checkmark.square"
        default:
            return "questionmark"
        }
    }

    private func cellAlignment(for dtype: String?) -> Alignment {
        switch dtype {
        case "int", "float":
            return .trailing
        default:
            return .leading
        }
    }

    private func formatCellValue(_ value: String, dtype: String?) -> String {
        guard let dtype = dtype else { return value }

        switch dtype {
        case "float":
            if let number = Double(value) {
                return String(format: "%.2f", number)
            }
        case "int":
            if let number = Int(value) {
                return NumberFormatter.localizedString(from: NSNumber(value: number), number: .decimal)
            }
        default:
            break
        }

        return value
    }

    private func toggleSort(column: String) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
        
        // Implement actual sorting
        let sortedIndices = sampleData.rows.indices.sorted { i, j in
            let colIndex = sampleData.columns.firstIndex(of: column) ?? 0
            let val1 = sampleData.rows[i][colIndex]
            let val2 = sampleData.rows[j][colIndex]
            
            if let dtype = sampleData.dtypes[column] {
                switch dtype {
                case "int":
                    let num1 = Int(val1) ?? 0
                    let num2 = Int(val2) ?? 0
                    return sortAscending ? num1 < num2 : num1 > num2
                case "float":
                    let num1 = Double(val1) ?? 0.0
                    let num2 = Double(val2) ?? 0.0
                    return sortAscending ? num1 < num2 : num1 > num2
                default:
                    return sortAscending ? val1 < val2 : val1 > val2
                }
            }
            
            return sortAscending ? val1 < val2 : val1 > val2
        }
        
        sampleData = DataFrameData(
            columns: sampleData.columns,
            rows: sortedIndices.map { sampleData.rows[$0] },
            dtypes: sampleData.dtypes
        )
    }

    private func loadDataFromWindow() {
        guard let windowID = windowID,
              let existingData = windowManager.getWindowDataFrame(for: windowID) else {
            return
        }
        sampleData = existingData
    }

    private func saveDataToWindow() {
        guard let windowID = windowID else { return }
        windowManager.updateWindowDataFrame(windowID, dataFrame: sampleData)
    }

    private func loadSampleData() {
        sampleData = DataFrameData(
            columns: ["Product", "Category", "Price", "Quantity", "Revenue"],
            rows: [
                ["iPhone 15", "Electronics", "999.00", "150", "149850.00"],
                ["MacBook Pro", "Electronics", "2399.00", "75", "179925.00"],
                ["AirPods Pro", "Electronics", "249.00", "300", "74700.00"],
                ["iPad Air", "Electronics", "599.00", "120", "71880.00"],
                ["Apple Watch", "Electronics", "399.00", "200", "79800.00"]
            ],
            dtypes: ["Product": "string", "Category": "string", "Price": "float", "Quantity": "int", "Revenue": "float"]
        )
        initializeColumnWidths()

        if let windowID = windowID {
            saveDataToWindow()
        }
    }

    // Helper method to convert to CSV string
    private func toCSVString() -> String {
        var csv = sampleData.columns.joined(separator: ",") + "\n"
        for row in sampleData.rows {
            csv += row.joined(separator: ",") + "\n"
        }
        return csv
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { 
                importError = "No file selected"
                return 
            }
            
            do {
                let content = try String(contentsOf: url)
                let fileExtension = url.pathExtension.lowercased()
                
                let importedData: DataFrameData
                
                switch fileExtension {
                case "csv":
                    importedData = try parseCSVContent(content)
                case "tsv", "txt":
                    importedData = try parseTSVContent(content)
                case "json":
                    importedData = try parseJSONContent(content)
                default:
                    // Try CSV as default
                    importedData = try parseCSVContent(content)
                }
                
                sampleData = importedData
                initializeColumnWidths()
                
                if let windowID = windowID {
                    saveDataToWindow()
                }
            } catch {
                importError = "Error importing file: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            importError = "Import failed: \(error.localizedDescription)"
        }
    }
    
    private func parseCSVContent(_ content: String) throws -> DataFrameData {
        if let csvData = CSVParser.parse(content) {
            let dtypes = csvData.columnTypes.enumerated().reduce(into: [String: String]()) { result, item in
                let (index, type) = item
                if index < csvData.headers.count {
                    switch type {
                    case .numeric:
                        result[csvData.headers[index]] = "float"
                    case .categorical:
                        result[csvData.headers[index]] = "string"
                    case .date:
                        result[csvData.headers[index]] = "string"
                    case .unknown:
                        result[csvData.headers[index]] = "string"
                    }
                }
            }
            
            return DataFrameData(
                columns: csvData.headers,
                rows: csvData.rows,
                dtypes: dtypes
            )
        } else {
            // Fallback to simple CSV parsing
            return try parseDelimitedText(content, delimiter: ",", hasHeaders: true)
        }
    }
    
    private func parseTSVContent(_ content: String) throws -> DataFrameData {
        return try parseDelimitedText(content, delimiter: "\t", hasHeaders: true)
    }
    
    private func parseJSONContent(_ content: String) throws -> DataFrameData {
        guard let data = content.data(using: .utf8) else {
            throw DataImportError.invalidFormat
        }
        
        let json = try JSONSerialization.jsonObject(with: data)
        
        if let array = json as? [[String: Any]] {
            let columns = Array(Set(array.flatMap { $0.keys })).sorted()
            let rows = array.map { object in
                columns.map { column in
                    if let value = object[column] {
                        return String(describing: value)
                    } else {
                        return ""
                    }
                }
            }
            
            let dtypes = autoDetectDataTypes(columns: columns, rows: rows)
            return DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
        } else {
            throw DataImportError.invalidFormat
        }
    }
    
    private func parseDelimitedText(_ content: String, delimiter: String, hasHeaders: Bool) throws -> DataFrameData {
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else {
            throw DataImportError.noData
        }
        
        let rows = lines.map { line in
            line.components(separatedBy: delimiter).map { $0.trimmingCharacters(in: .whitespaces) }
        }
        
        let columns: [String]
        let dataRows: [[String]]
        
        if hasHeaders && !rows.isEmpty {
            columns = rows[0]
            dataRows = Array(rows.dropFirst())
        } else {
            let columnCount = rows.first?.count ?? 0
            columns = (1...columnCount).map { "Column \($0)" }
            dataRows = rows
        }
        
        // Auto-detect data types
        let dtypes = autoDetectDataTypes(columns: columns, rows: dataRows)
        
        return DataFrameData(columns: columns, rows: dataRows, dtypes: dtypes)
    }
    
    private func autoDetectDataTypes(columns: [String], rows: [[String]]) -> [String: String] {
        var dtypes: [String: String] = [:]
        
        for (index, column) in columns.enumerated() {
            let columnValues = rows.compactMap { row in
                index < row.count ? row[index] : nil
            }.filter { !$0.isEmpty }
            
            if columnValues.isEmpty {
                dtypes[column] = "string"
                continue
            }
            
            let numericCount = columnValues.compactMap { Double($0) }.count
            let booleanCount = columnValues.filter { $0.lowercased() == "true" || $0.lowercased() == "false" }.count
            
            if Double(numericCount) / Double(columnValues.count) > 0.8 {
                if columnValues.allSatisfy({ $0.contains(".") || Int($0) == nil }) {
                    dtypes[column] = "float"
                } else {
                    dtypes[column] = "int"
                }
            } else if Double(booleanCount) / Double(columnValues.count) > 0.8 {
                dtypes[column] = "bool"
            } else {
                dtypes[column] = "string"
            }
        }
        
        return dtypes
    }
    
    enum DataImportError: LocalizedError {
        case noData
        case invalidFormat
        case parsingFailed
        
        var errorDescription: String? {
            switch self {
            case .noData:
                return "No data found in the file"
            case .invalidFormat:
                return "Invalid file format"
            case .parsingFailed:
                return "Failed to parse the data"
            }
        }
    }
}