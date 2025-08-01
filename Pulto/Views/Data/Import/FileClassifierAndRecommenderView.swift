//
//  PointCloudData.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/19/25.
//  Copyright © 2025 Apple. All rights reserved.
//


/// File: FileClassifierAndRecommenderView.swift

import SwiftUI
import Charts
import UniformTypeIdentifiers
import RealityKit


// MARK: - File Classifier and Recommender Integration
// The following code is the integrated FileClassifierAndRecommenderView
// Place this in the same file or a separate one and import if needed.


func parsePLY(at url: URL) -> PointCloudData? {
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

        let bodyStart = header.utf8CString.count - 1 // Account for null terminator or line break
        let bodyData = data.subdata(in: bodyStart..<data.count)

        var points = [SIMD3<Float>]()

        if format.hasPrefix("ascii") {
            guard let bodyStr = String(data: bodyData, encoding: .ascii) else { return nil }
            let bodyLines = bodyStr.components(separatedBy: .newlines).filter { !$0.isEmpty }

            for line in bodyLines.prefix(vertexCount) {
                let values = line.components(separatedBy: " ").compactMap { Float($0) }
                if values.count >= 3 {
                    points.append(SIMD3(values[0], values[1], values[2]))
                }
            }
        } else if format.hasPrefix("binary") {
            let isBigEndian = format.contains("big_endian")
            var offset = 0
            let xIndex = propList.firstIndex(of: "x") ?? -1
            let yIndex = propList.firstIndex(of: "y") ?? -1
            let zIndex = propList.firstIndex(of: "z") ?? -1
            if xIndex == -1 || yIndex == -1 || zIndex == -1 { return nil }

            for _ in 0..<vertexCount {
                var x: Float = 0, y: Float = 0, z: Float = 0
                for propIndex in 0..<propList.count {
                    let propType = propTypes[propIndex]
                    let size: Int
                    switch propType {
                    case "float32", "float":
                        size = 4
                    case "double":
                        size = 8
                    case "int32", "uint32":
                        size = 4
                    case "uchar", "uint8":
                        size = 1
                    default:
                        size = 4 // Default to 4 bytes
                    }
                    let propData = bodyData.subdata(in: offset..<offset + size)
                    offset += size

                    let value: Float
                    switch size {
                    case 4:
                        let uint32 = propData.withUnsafeBytes { $0.load(as: UInt32.self) }
                        let finalUInt32 = isBigEndian ? uint32.bigEndian : uint32.littleEndian
                        value = Float(bitPattern: finalUInt32)
                    case 8:
                        let uint64 = propData.withUnsafeBytes { $0.load(as: UInt64.self) }
                        let finalUInt64 = isBigEndian ? uint64.bigEndian : uint64.littleEndian
                        value = Float(bitPattern: UInt32(finalUInt64)) // Approximate
                    default:
                        value = 0
                    }

                    if propIndex == xIndex { x = value }
                    else if propIndex == yIndex { y = value }
                    else if propIndex == zIndex { z = value }
                }
                points.append(SIMD3(x, y, z))
            }
        }

        return PointCloudData(points: points)
    } catch {
        print("PLY parse error: \(error)")
        return nil
    }
}

// MARK: - Main View
struct FileClassifierAndRecommenderView: View {
    @EnvironmentObject private var windowManager: WindowTypeManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @State private var csvData: CSVData?
    @State private var recommendations: [ChartScore] = []
    @State private var selectedRecommendation: ChartRecommendation?
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var nonCSVType: FileType?
    @State private var importedURL: URL?
    @State private var showingBatchImporter = false

    private var welcomeScreen: some View {
        VStack(spacing: 30) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("File Classifier and Chart Recommender")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Import a file from iCloud to classify it and get chart recommendations for CSV/TSV")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Supported Formats Section
            VStack(alignment: .leading, spacing: 20) {
                Text("Supported Formats")
                    .font(.title2)
                    .fontWeight(.semibold)

                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 16) {
                    FormatCard(
                        title: "Data Files", formats: ["CSV", "TSV", "JSON"],
                        icon: "tablecells", color: .green
                    )
                    FormatCard(
                        title: "3D Models", formats: ["USDZ", "USD", "OBJ"],
                        icon: "cube", color: .red
                    )
                    FormatCard(
                        title: "Point Clouds", formats: ["PLY", "XYZ", "HEIC"],
                        icon: "photo", color: .green
                    )
                    FormatCard(
                        title: "Code Files", formats: ["PY", "IPYNB"],
                        icon: "chevron.left.forwardslash.chevron.right", color: .orange
                    )
                }
            }

            VStack(spacing: 16) {
                Button(action: { isImporting = true }) {
                    Label("Import Single File", systemImage: "icloud.and.arrow.down")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: { showingBatchImporter = true }) {
                    Label("Import Multiple Files", systemImage: "square.and.arrow.down.on.square")
                        .font(.headline)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            
            // Add a test button for creating sample 3D charts
            Button(action: { createSampleVolumetricChart() }) {
                Label("Create Sample 3D Chart", systemImage: "cube.transparent")
                    .font(.headline)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }

    private var nonCSVScreen: some View {
        Group {
            if let type = nonCSVType {
                VStack(spacing: 30) {
                    Image(systemName: "doc")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    Text("File Classified")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("This is a \(type.description)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Text("Chart recommendations are only available for CSV/TSV files.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button(action: { isImporting = true }) {
                        Label("Import Another File", systemImage: "icloud.and.arrow.down")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
    }

    private var dataLoadedScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Data Summary
                VStack(alignment: .leading, spacing: 10) {
                    Text("Data Summary")
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 30) {
                        DataSummaryItem(
                            icon: "tablecells",
                            label: "Rows",
                            value: "\(csvData!.rows.count)"
                        )

                        DataSummaryItem(
                            icon: "rectangle.split.3x1",
                            label: "Columns",
                            value: "\(csvData!.headers.count)"
                        )

                        DataSummaryItem(
                            icon: "number",
                            label: "Numeric",
                            value: "\(csvData!.columnTypes.filter { $0 == .numeric }.count)"
                        )
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }

                // Recommendations
                VStack(alignment: .leading, spacing: 15) {
                    Text("Recommended Charts")
                        .font(.title2)
                        .fontWeight(.bold)

                    ForEach(recommendations, id: \.recommendation) { score in
                        RecommendationCardView(
                            score: score,
                            selectedRecommendation: selectedRecommendation,
                            onSelection: { selectedRecommendation = score.recommendation }
                        )
                    }
                }

                // Chart Preview
                if let selected = selectedRecommendation {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Chart Preview")
                            .font(.title2)
                            .fontWeight(.bold)

                        SampleChartView(data: csvData!, recommendation: selected)
                    }
                }
            }
            .padding()
        }
    }

    private var bottomToolbar: some View {
        HStack {
            Button(action: { isImporting = true }) {
                Label("Import New File", systemImage: "arrow.up.doc")
            }

            Spacer()

            if selectedRecommendation != nil {
                Button(action: generateFullChart) {
                    Label("Generate Full Chart", systemImage: "wand.and.stars")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                nonCSVScreen

                if csvData == nil && nonCSVType == nil {
                    welcomeScreen
                } else if csvData != nil {
                    dataLoadedScreen
                    bottomToolbar
                }
            }
            .toolbar { // Add a toolbar
                ToolbarItem(placement: .navigationBarTrailing) { // Place the button on the trailing edge
                    Button("Dismiss") { // Create a button with the text "Dismiss"
                        dismiss() // Dismiss the current view
                    }
                }
            }
            .navigationTitle("File Classifier and Chart Recommender")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [
                    .commaSeparatedText,    // CSV files
                    .tabSeparatedText,      // TSV files
                    .plainText,             // TSV files might be detected as plain text
                    .text,                  // Alternative text type
                    .usdz,                  // USDZ files (3D models)
                    .data,                  // Fallback for any file type
                    .plyFile,               // Custom PLY type
                    .pcdFile,               // Custom PCD type
                    .xyzFile                // Custom XYZ type
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showingBatchImporter) {
                BatchImportView()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: nonCSVType) { oldValue, newValue in
                if let type = newValue {
                    handleNonCSVType(type)
                }
            }
        }
    }

     // Enhanced handleFileImport with TSV debugging
     private func handleFileImport(_ result: Result<[URL], Error>) {
         nonCSVType = nil
         csvData = nil
         recommendations = []
         selectedRecommendation = nil

         switch result {
         case .success(let urls):
             guard let url = urls.first else { return }
             importedURL = url

             // Enhanced DEBUG: Print detailed file information
             print("📁 Selected file: \(url.lastPathComponent)")
             print("📁 File extension: \(url.pathExtension.lowercased())")
             print("📁 Full path: \(url.path)")
             print("📁 File size: \(getFileSize(url)) bytes")

             // Check if it's a TSV file and handle it directly
             let fileExtension = url.pathExtension.lowercased()
             if fileExtension == "tsv" || fileExtension == "tab" {
                 print("📁 Detected TSV file, handling directly...")
                 handleTSVFile(at: url)
                 return
             }

             let classifier = FileClassifier()
             let (type, data, recs) = classifier.classifyFile(at: url)

             // Enhanced DEBUG: Print classification result
             print("📁 Classified as: \(type)")
             print("📁 Has data: \(data != nil)")
             print("📁 Has recommendations: \(recs?.count ?? 0)")

             switch type {
             case .csv(_):
                 if let data = data, let recommendationsList = recs, !recommendationsList.isEmpty {
                     csvData = data
                     recommendations = recommendationsList
                     selectedRecommendation = recommendations.first?.recommendation
                     print("✅ Successfully loaded CSV/TSV with \(data.rows.count) rows")
                 } else {
                     errorMessage = "Failed to parse CSV/TSV file or no recommendations available"
                     print("❌ Failed to parse CSV/TSV: data=\(data != nil), recs=\(recs?.count ?? 0)")
                 }
             case .unknown:
                 errorMessage = "Unknown file type: \(url.pathExtension)"
                 print("❌ Unknown file type: \(url.pathExtension)")
             default:
                 nonCSVType = type
                 print("📁 Non-CSV type: \(type)")
             }

         case .failure(let error):
             errorMessage = "Import failed: \(error.localizedDescription)"
             print("📁 Import error: \(error)")
         }
     }

     // Direct TSV handling function
     private func handleTSVFile(at url: URL) {
         guard url.startAccessingSecurityScopedResource() else {
             errorMessage = "Cannot access file"
             return
         }
         defer { url.stopAccessingSecurityScopedResource() }

         do {
             let content = try String(contentsOf: url, encoding: .utf8)
             print("📄 TSV file content preview (first 200 chars):")
             print(String(content.prefix(200)))

             let csvData = parseTSVContent(content)
             if let csvData = csvData {
                 self.csvData = csvData
                 self.recommendations = generateTSVRecommendations(for: csvData)
                 self.selectedRecommendation = recommendations.first?.recommendation
                 print("✅ Successfully parsed TSV file with \(csvData.rows.count) rows and \(csvData.headers.count) columns")
             } else {
                 errorMessage = "Failed to parse TSV file"
                 print("❌ Failed to parse TSV content")
             }
         } catch {
             errorMessage = "Error reading TSV file: \(error.localizedDescription)"
             print("❌ TSV read error: \(error)")
         }
     }

     // TSV parsing function
     private func parseTSVContent(_ content: String) -> CSVData? {
         let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

         guard !lines.isEmpty else {
             print("❌ TSV file is empty")
             return nil
         }

         // Parse headers (first line)
         let headers = lines[0].components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
         print("📄 TSV Headers: \(headers)")

         guard !headers.isEmpty else {
             print("❌ No headers found in TSV")
             return nil
         }

         // Parse data rows
         var rows: [[String]] = []
         for (index, line) in lines.dropFirst().enumerated() {
             let values = line.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }

             // Pad with empty strings if row has fewer columns than headers
             var paddedValues = values
             while paddedValues.count < headers.count {
                 paddedValues.append("")
             }

             // Truncate if row has more columns than headers
             if paddedValues.count > headers.count {
                 paddedValues = Array(paddedValues.prefix(headers.count))
             }

             rows.append(paddedValues)

             if index < 3 { // Debug first few rows
                 print("📄 TSV Row \(index): \(paddedValues)")
             }
         }

         print("📄 Parsed \(rows.count) data rows")

         // Determine column types
         let columnTypes = determineColumnTypes(headers: headers, rows: rows)
         print("📄 Column types: \(columnTypes)")

         return CSVData(
             headers: headers,
             rows: rows,
             columnTypes: columnTypes
         )
     }

     // Helper function to determine column types for TSV
     private func determineColumnTypes(headers: [String], rows: [[String]]) -> [ColumnType] {
         return headers.enumerated().map { index, header in
             // Sample first few non-empty values in this column
             let sampleValues = rows.prefix(min(10, rows.count))
                 .compactMap { row in
                     index < row.count ? row[index] : nil
                 }
                 .filter { !$0.isEmpty }

             // Check if most values are numeric
             let numericCount = sampleValues.compactMap { Double($0) }.count
             let totalSamples = sampleValues.count

             if totalSamples == 0 {
                 return .categorical
             }

             // If 80% or more values are numeric, consider it numeric
             return Double(numericCount) / Double(totalSamples) >= 0.8 ? .numeric : .categorical
         }
     }

     // Generate recommendations for TSV data
     private func generateTSVRecommendations(for data: CSVData) -> [ChartScore] {
         // Use the same logic as CSV recommendations
         // This is a simplified version - you might want to use your existing recommendation engine

         let numericColumns = data.columnTypes.enumerated().compactMap { index, type in
             type == .numeric ? index : nil
         }

         var recommendations: [ChartScore] = []

         if numericColumns.count >= 2 {
             recommendations.append(ChartScore(
                 recommendation: .scatterPlot,
                 score: 0.9,
                 reasoning: "Multiple numeric columns suitable for scatter plot analysis"
             ))

             recommendations.append(ChartScore(
                 recommendation: .lineChart,
                 score: 0.8,
                 reasoning: "Numeric data can show trends over sequence"
             ))
         }

         if numericColumns.count >= 1 {
             recommendations.append(ChartScore(
                 recommendation: .barChart,
                 score: 0.7,
                 reasoning: "Numeric values can be displayed as bars"
             ))

             recommendations.append(ChartScore(
                 recommendation: .histogram,
                 score: 0.6,
                 reasoning: "Show distribution of numeric values"
             ))
         }

         if data.headers.count <= 10 && data.rows.count <= 20 {
             recommendations.append(ChartScore(
                 recommendation: .pieChart,
                 score: 0.5,
                 reasoning: "Small dataset suitable for categorical breakdown"
             ))
         }

         return recommendations.sorted { $0.score > $1.score }
     }

     // Helper function to get file size
     private func getFileSize(_ url: URL) -> Int {
         do {
             let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
             return attributes[.size] as? Int ?? 0
         } catch {
             return 0
         }
     }

    private func handleNonCSVType(_ type: FileType) {
        guard let url = importedURL else {
            errorMessage = "No file URL available"
            return
        }

        let id = windowManager.getNextWindowID()
        let position = WindowPosition(x: 100, y: 100, z: 0, width: 800, height: 600)

        switch type {
        case .pointCloudPLY:
            _ = windowManager.createWindow(.pointcloud, id: id, position: position)
            if let pointCloud = parsePLY(at: url) {
                windowManager.updateWindowPointCloud(id, pointCloud: pointCloud)
            }
            openWindow(id: "volumetric-pointclouddemo", value: id)
            windowManager.markWindowAsOpened(id)

        case .usdz:
            _ = windowManager.createWindow(.model3d, id: id, position: position)
            do {
                let bookmark = try url.bookmarkData(options: .minimalBookmark)
                windowManager.updateUSDZBookmark(for: id, bookmark: bookmark)
            } catch {
                print("Error creating bookmark: \(error)")
            }
            openWindow(id: "volumetric-model3d", value: id)
            windowManager.markWindowAsOpened(id)

        default:
            print("📁 Unhandled file type: \(type)")
            break
        }

        dismiss()
    }

    private func generateFullChart() {
        guard let csvData = csvData, let selectedRecommendation = selectedRecommendation else { return }
        
        let id = windowManager.getNextWindowID()
        let position = WindowPosition(x: 100, y: 100, z: 0, width: 1000, height: 700)

        // Create regular chart window instead of volumetric chart window
        _ = windowManager.createWindow(.charts, id: id, position: position)
        
        // TEMPORARILY COMMENTED OUT: Store CSV data and chart recommendation in the window
        // This is causing type conflicts and will be re-implemented properly
        // windowManager.updateWindowCSVData(id, csvData: csvData, recommendation: selectedRecommendation)
        
        // For now, just add a tag to indicate this is a chart from file import
        windowManager.addWindowTag(id, tag: "file-import")
        windowManager.addWindowTag(id, tag: "chart-data")
        
        // Open a regular window with the new chart view
        openWindow(value: id)
        windowManager.markWindowAsOpened(id)

        dismiss()
    }
    
    // MARK: - CSV to 3D Chart Conversion
    private func convertCSVToChart3D(csvData: CSVData, recommendation: ChartRecommendation) -> Chart3DData {
        switch recommendation {
        case .scatterPlot:
            return createScatter3D(from: csvData)
        case .barChart:
            return createBar3D(from: csvData)
        case .lineChart:
            return createLine3D(from: csvData)
        case .histogram:
            return createHistogram3D(from: csvData)
        case .areaChart:
            return createArea3D(from: csvData)
        case .pieChart:
            return createPie3D(from: csvData)
        }
    }
    
    private func createScatter3D(from csvData: CSVData) -> Chart3DData {
        let numericIndices = csvData.columnTypes.enumerated().compactMap { index, type in
            type == .numeric ? index : nil
        }
        
        guard numericIndices.count >= 2 else {
            return Chart3DData(title: "3D Scatter Plot", chartType: "scatter", points: [])
        }
        
        let xIndex = numericIndices[0]
        let yIndex = numericIndices[1]
        let zIndex = numericIndices.count > 2 ? numericIndices[2] : nil
        
        var points: [Point3D] = []
        
        for row in csvData.rows.prefix(100) { // Limit to 100 points for performance
            guard xIndex < row.count, yIndex < row.count,
                  let x = Float(row[xIndex]),
                  let y = Float(row[yIndex]) else { continue }
            
            let z: Float
            if let zIndex = zIndex, zIndex < row.count, let zValue = Float(row[zIndex]) {
                z = zValue
            } else {
                // Use row index as Z if no third numeric column
                z = Float(points.count) * 0.1
            }
            
            points.append(Point3D(x: x, y: y, z: z))
        }
        
        return Chart3DData(
            title: "3D Scatter Plot - \(csvData.headers[xIndex]) vs \(csvData.headers[yIndex])",
            chartType: "scatter",
            points: points
        )
    }
    
    private func createBar3D(from csvData: CSVData) -> Chart3DData {
        guard let categoryIndex = csvData.columnTypes.firstIndex(of: .categorical),
              let numericIndex = csvData.columnTypes.firstIndex(of: .numeric) else {
            return Chart3DData(title: "3D Bar Chart", chartType: "bar", points: [])
        }
        
        var points: [Point3D] = []
        
        for (index, row) in csvData.rows.prefix(20).enumerated() {
            guard categoryIndex < row.count, numericIndex < row.count,
                  let value = Float(row[numericIndex]) else { continue }
            
            // Position bars in a grid
            let x = Float(index % 5) * 2.0 - 4.0  // Grid X position
            let z = Float(index / 5) * 2.0 - 4.0  // Grid Z position
            
            // Create multiple points to represent bar height
            let barHeight = max(value * 0.1, 0.1) // Scale value for visibility
            let segments = max(Int(barHeight * 10), 1)
            
            for segment in 0..<segments {
                let y = Float(segment) * 0.2
                points.append(Point3D(x: x, y: y, z: z))
            }
        }
        
        return Chart3DData(
            title: "3D Bar Chart - \(csvData.headers[categoryIndex]) by \(csvData.headers[numericIndex])",
            chartType: "bar",
            points: points
        )
    }
    
    private func createLine3D(from csvData: CSVData) -> Chart3DData {
        let numericIndices = csvData.columnTypes.enumerated().compactMap { index, type in
            type == .numeric ? index : nil
        }
        
        guard !numericIndices.isEmpty else {
            return Chart3DData(title: "3D Line Chart", chartType: "line", points: [])
        }
        
        var points: [Point3D] = []
        
        for (index, row) in csvData.rows.prefix(50).enumerated() {
            let x = Float(index) * 0.2 - 5.0 // Spread along X axis
            
            // Use first numeric column for Y
            guard numericIndices[0] < row.count,
                  let y = Float(row[numericIndices[0]]) else { continue }
            
            // Use second numeric column for Z if available, otherwise use sine wave
            let z: Float
            if numericIndices.count > 1, numericIndices[1] < row.count,
               let zValue = Float(row[numericIndices[1]]) {
                z = zValue * 0.1
            } else {
                z = Float(sin(Float(index) * 0.3)) * 2.0
            }
            
            points.append(Point3D(x: x, y: y * 0.1, z: z))
        }
        
        return Chart3DData(
            title: "3D Line Chart - \(csvData.headers[numericIndices[0]])",
            chartType: "line",
            points: points
        )
    }
    
    private func createHistogram3D(from csvData: CSVData) -> Chart3DData {
        guard let numericIndex = csvData.columnTypes.firstIndex(of: .numeric) else {
            return Chart3DData(title: "3D Histogram", chartType: "histogram", points: [])
        }
        
        let values = csvData.rows.compactMap { row in
            numericIndex < row.count ? Float(row[numericIndex]) : nil
        }
        
        guard !values.isEmpty else {
            return Chart3DData(title: "3D Histogram", chartType: "histogram", points: [])
        }
        
        // Create histogram bins
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let binCount = 20
        let binWidth = (maxValue - minValue) / Float(binCount)
        
        var binCounts = Array(repeating: 0, count: binCount)
        
        for value in values {
            let binIndex = min(Int((value - minValue) / binWidth), binCount - 1)
            binCounts[binIndex] += 1
        }
        
        var points: [Point3D] = []
        
        for (binIndex, count) in binCounts.enumerated() {
            let x = Float(binIndex) * 0.5 - Float(binCount) * 0.25
            let height = Float(count) * 0.2
            
            // Create points for each bin as a vertical stack
            for i in 0..<count {
                let y = Float(i) * 0.1
                let z = Float(0.0)
                points.append(Point3D(x: x, y: y, z: z))
            }
        }
        
        return Chart3DData(
            title: "3D Histogram - \(csvData.headers[numericIndex])",
            chartType: "histogram",
            points: points
        )
    }
    
    private func createArea3D(from csvData: CSVData) -> Chart3DData {
        // Similar to line chart but with filled area below
        let lineData = createLine3D(from: csvData)
        var points = lineData.points
        
        // Add points below the line to create "area" effect
        for point in lineData.points {
            // Add points from ground level up to the line
            let steps = max(Int(point.y * 10), 1)
            for step in 0..<steps {
                let fillY = Float(step) * 0.1
                points.append(Point3D(x: point.x, y: fillY, z: point.z))
            }
        }
        
        return Chart3DData(
            title: lineData.title.replacingOccurrences(of: "Line", with: "Area"),
            chartType: "area",
            points: points
        )
    }
    
    private func createPie3D(from csvData: CSVData) -> Chart3DData {
        guard let categoryIndex = csvData.columnTypes.firstIndex(of: .categorical),
              let numericIndex = csvData.columnTypes.firstIndex(of: .numeric) else {
            return Chart3DData(title: "3D Pie Chart", chartType: "pie", points: [])
        }
        
        // Group data by category
        var categoryValues: [String: Float] = [:]
        
        for row in csvData.rows.prefix(20) {
            guard categoryIndex < row.count, numericIndex < row.count,
                  let value = Float(row[numericIndex]) else { continue }
            
            let category = row[categoryIndex]
            categoryValues[category, default: 0] += value
        }
        
        let total = categoryValues.values.reduce(0, +)
        var points: [Point3D] = []
        var currentAngle: Float = 0
        
        for (_, value) in categoryValues {
            let percentage = value / total
            let sliceAngle = percentage * 2 * Float.pi
            let endAngle = currentAngle + sliceAngle
            
            // Create points for this pie slice
            let segments = max(Int(sliceAngle * 10), 3)
            for i in 0..<segments {
                let angle = currentAngle + (Float(i) / Float(segments)) * sliceAngle
                let radius = 2.0 + percentage * 2.0 // Vary radius by percentage
                
                let x = Float(cos(angle)) * radius
                let z = Float(sin(angle)) * radius
                let y = Float(0.0)
                
                points.append(Point3D(x: x, y: y, z: z))
            }
            
            currentAngle = endAngle
        }
        
        return Chart3DData(
            title: "3D Pie Chart - \(csvData.headers[categoryIndex])",
            chartType: "pie",
            points: points
        )
    }
    
    // MARK: - Sample Chart Creation
    private func createSampleVolumetricChart() {
        let id = windowManager.getNextWindowID()
        let position = WindowPosition(x: 100, y: 100, z: 0, width: 800, height: 600)

        // Create volumetric chart window
        _ = windowManager.createWindow(.charts, id: id, position: position)
        
        // Create sample data representing sales over months with regions
        var points: [Point3D] = []
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let regions = ["North", "South", "East", "West"]
        
        for (monthIndex, _) in months.enumerated() {
            for (regionIndex, _) in regions.enumerated() {
                // Create sales data with some variation
                let sales = Float(15000 + monthIndex * 1000 + regionIndex * 500 + Int.random(in: -2000...3000))
                let profit = sales * 0.2 + Float(Int.random(in: -500...1000))
                
                // Position in 3D space
                let x = (sales - 15000) / 5000.0  // Normalize sales
                let y = (profit - 3000) / 1000.0  // Normalize profit  
                let z = Float(monthIndex - 6) * 0.3  // Spread months along Z axis
                
                points.append(Point3D(x: x, y: y, z: z))
            }
        }
        
        let chart3DData = Chart3DData(
            title: "Sample Sales Data - 3D Scatter Plot",
            chartType: "scatter",
            points: points
        )
        windowManager.updateWindowChart3DData(id, chart3DData: chart3DData)
        
        // Open the volumetric chart window  
        openWindow(id: "volumetric-chart3d", value: id)
        windowManager.markWindowAsOpened(id)
        
        print("✅ Created sample volumetric chart with \(points.count) data points")
        print("🎯 Chart title: \(chart3DData.title)")
        print("🎯 Chart type: \(chart3DData.chartType)")
        
        dismiss()
    }
}

struct RecommendationCardView: View {
    let score: ChartScore
    let selectedRecommendation: ChartRecommendation?
    let onSelection: () -> Void

    private var isSelected: Bool {
        selectedRecommendation == score.recommendation
    }

    private var iconColor: Color {
        isSelected ? .white : .blue
    }

    private var titleColor: Color {
        isSelected ? .white : .primary
    }

    private var descriptionColor: Color {
        isSelected ? .white.opacity(0.8) : .secondary
    }

    private var scoreColor: Color {
        isSelected ? .white : .green
    }

    private var backgroundColor: Color {
        isSelected ? Color.blue : Color.gray.opacity(0.1)
    }

    var body: some View {
        Button(action: onSelection) {
            HStack {
                Image(systemName: score.recommendation.icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 5) {
                    Text(score.recommendation.name)
                        .font(.headline)
                        .foregroundColor(titleColor)

                    Text(score.reasoning)
                        .font(.caption)
                        .foregroundColor(descriptionColor)
                        .lineLimit(2)
                }

                Spacer()

                VStack {
                    Text("\(Int(score.score * 100))%")
                        .font(.headline)
                        .foregroundColor(scoreColor)
                    Text("match")
                        .font(.caption2)
                        .foregroundColor(descriptionColor)
                }
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct DataSummaryItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}

// MARK: - Format Card
struct FormatCard: View {
    let title:    String
    let formats:  [String]
    let icon:     String
    let color:    Color

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

#Preview {
    FileClassifierAndRecommenderView()
}