//
//  FileAnalyzer.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/18/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import TabularData

// MARK: - File Analysis System

class FileAnalyzer: ObservableObject {
    static let shared = FileAnalyzer()

    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0.0
    @Published var currentAnalysisStep: String = ""

    private let schemaInferenceEngine = SchemaInferenceEngine()
    private let visualizationSuggestionEngine = VisualizationSuggestionEngine()

    // MARK: - Main Analysis Entry Point

    func analyzeFile(_ url: URL) async throws -> FileAnalysisResult {
        await MainActor.run {
            isAnalyzing = true
            analysisProgress = 0.0
            currentAnalysisStep = "Reading file..."
        }

        defer {
            Task { @MainActor in
                isAnalyzing = false
                analysisProgress = 1.0
            }
        }

        // Determine file type
        let fileType = detectFileType(from: url)

        // Read file data
        let data = try Data(contentsOf: url)

        await MainActor.run {
            analysisProgress = 0.2
            currentAnalysisStep = "Analyzing structure..."
        }

        // Perform type-specific analysis
        let analysisResult: DataAnalysisResult

        switch fileType {
        case .csv, .tsv:
            analysisResult = try await schemaInferenceEngine.analyzeTabularData(data, delimiter: fileType == .csv ? "," : "\t")
        case .json:
            analysisResult = try await schemaInferenceEngine.analyzeJSONData(data)
        case .xlsx:
            analysisResult = try await schemaInferenceEngine.analyzeExcelData(data, url: url)
        case .las:
            analysisResult = try await schemaInferenceEngine.analyzeLASData(data)
        case .ipynb:
            analysisResult = try await schemaInferenceEngine.analyzeNotebookData(data)
        case .usdz:
            analysisResult = try await schemaInferenceEngine.analyzeUSDZData(data, url: url)
        default:
            throw FileAnalysisError.unsupportedFormat
        }

        await MainActor.run {
            analysisProgress = 0.6
            currentAnalysisStep = "Generating visualization suggestions..."
        }

        // Generate visualization suggestions
        let suggestions = visualizationSuggestionEngine.suggestVisualizations(for: analysisResult)

        await MainActor.run {
            analysisProgress = 1.0
            currentAnalysisStep = "Analysis complete"
        }

        return FileAnalysisResult(
            fileURL: url,
            fileType: fileType,
            analysis: analysisResult,
            suggestions: suggestions
        )
    }

    // MARK: - File Type Detection

    private func detectFileType(from url: URL) -> SupportedFileType {
        // FIX: Renamed variable from 'extension' to 'fileExtension' because 'extension' is a reserved keyword in Swift.
        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "csv": return .csv
        case "tsv": return .tsv
        case "json": return .json
        case "xlsx": return .xlsx
        case "las": return .las
        case "ipynb": return .ipynb
        case "usdz": return .usdz
        default: return .unknown
        }
    }
}

// MARK: - Schema Inference Engine

class SchemaInferenceEngine {

    // MARK: - Tabular Data Analysis

    func analyzeTabularData(_ data: Data, delimiter: String) async throws -> DataAnalysisResult {
        guard let content = String(data: data, encoding: .utf8) else {
            throw FileAnalysisError.encodingError
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else {
            throw FileAnalysisError.emptyFile
        }

        // Pass 1: Detect headers and basic structure
        let headers = parseHeaders(lines[0], delimiter: delimiter)
        var rows: [[String]] = []

        for i in 1..<min(lines.count, 1001) { // Sample first 1000 rows
            let row = parseRow(lines[i], delimiter: delimiter, columnCount: headers.count)
            rows.append(row)
        }

        // Pass 2: Infer column types
        let columnTypes = inferColumnTypes(headers: headers, rows: rows)

        // Pass 3: Detect patterns and relationships
        let patterns = detectDataPatterns(headers: headers, rows: rows, types: columnTypes)

        // Check for coordinate data
        let coordinateColumns = detectCoordinateColumns(headers: headers, types: columnTypes)
        let hasTimeData = detectTimeColumns(headers: headers, types: columnTypes)

        // Determine data type
        let dataType: DataType
        if coordinateColumns.count >= 2 {
            dataType = .tabularWithCoordinates
        } else if hasTimeData {
            dataType = .timeSeries
        } else if patterns.contains(.hierarchical) {
            dataType = .hierarchical
        } else if patterns.contains(.network) {
            dataType = .networkData
        } else {
            dataType = .tabular
        }

        return DataAnalysisResult(
            dataType: dataType,
            structure: TabularStructure(
                headers: headers,
                importcolumnTypes: columnTypes,
                rowCount: lines.count - 1,
                patterns: patterns,
                coordinateColumns: coordinateColumns,
                timeColumns: hasTimeData ? headers.filter { h in
                    columnTypes[h] == .date || h.lowercased().contains("time") || h.lowercased().contains("date")
                } : []
            ),
            metadata: [
                "delimiter": delimiter,
                "encoding": "UTF-8",
                "totalRows": lines.count - 1
            ]
        )
    }

    private func parseHeaders(_ line: String, delimiter: String) -> [String] {
        return line.components(separatedBy: delimiter)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func parseRow(_ line: String, delimiter: String, columnCount: Int) -> [String] {
        var row = line.components(separatedBy: delimiter)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        // Ensure consistent column count
        while row.count < columnCount {
            row.append("")
        }

        return Array(row.prefix(columnCount))
    }

    private func inferColumnTypes(headers: [String], rows: [[String]]) -> [String: ImportColumnType] {
        var types: [String: ImportColumnType] = [:]

        for (index, header) in headers.enumerated() {
            var numericCount = 0
            var dateCount = 0
            var booleanCount = 0
            var emptyCount = 0

            for row in rows {
                guard index < row.count else { continue }
                let value = row[index]

                if value.isEmpty {
                    emptyCount += 1
                    continue
                }

                if Double(value) != nil {
                    numericCount += 1
                } else if isDate(value) {
                    dateCount += 1
                } else if isBoolean(value) {
                    booleanCount += 1
                }
            }

            let totalNonEmpty = rows.count - emptyCount
            guard totalNonEmpty > 0 else {
                types[header] = .unknown
                continue
            }

            // Determine type based on majority
            if Double(numericCount) / Double(totalNonEmpty) > 0.8 {
                types[header] = .numeric
            } else if Double(dateCount) / Double(totalNonEmpty) > 0.8 {
                types[header] = .date
            } else if Double(booleanCount) / Double(totalNonEmpty) > 0.8 {
                types[header] = .boolean
            } else {
                types[header] = .categorical
            }
        }

        return types
    }

    private func detectCoordinateColumns(headers: [String], types: [String: ImportColumnType]) -> [String] {
        var coordinateColumns: [String] = []

        let coordinatePatterns = [
            ["x", "y", "z"],
            ["lon", "lat", "alt"],
            ["longitude", "latitude", "altitude"],
            ["easting", "northing", "elevation"]
        ]

        for pattern in coordinatePatterns {
            let matches = pattern.compactMap { coord in
                headers.first { header in
                    let h = header.lowercased()
                    return (h == coord || h.contains(coord)) && types[header] == .numeric
                }
            }

            if matches.count >= 2 {
                coordinateColumns = matches
                break
            }
        }

        return coordinateColumns
    }

    private func detectTimeColumns(headers: [String], types: [String: ImportColumnType]) -> Bool {
        return headers.contains { header in
            types[header] == .date ||
            header.lowercased().contains("time") ||
            header.lowercased().contains("date") ||
            header.lowercased().contains("timestamp")
        }
    }

    private func detectDataPatterns(headers: [String], rows: [[String]], types: [String: ImportColumnType]) -> Set<DataPattern> {
        var patterns: Set<DataPattern> = []

        // Check for hierarchical data
        if headers.contains(where: { $0.lowercased().contains("parent") || $0.lowercased().contains("child") }) {
            patterns.insert(.hierarchical)
        }

        // Check for network data
        if headers.contains(where: { h in
            let lower = h.lowercased()
            return lower.contains("source") || lower.contains("target") || lower.contains("from") || lower.contains("to")
        }) {
            patterns.insert(.network)
        }

        // Check for high cardinality
        for (index, header) in headers.enumerated() {
            if types[header] == .categorical {
                let uniqueValues = Set(rows.compactMap { row in
                    index < row.count ? row[index] : nil
                }.filter { !$0.isEmpty })

                if uniqueValues.count > rows.count / 2 {
                    patterns.insert(.highCardinality)
                }
            }
        }

        // Check for missing data
        let missingDataRatio = rows.reduce(0.0) { sum, row in
            sum + Double(row.filter { $0.isEmpty }.count) / Double(row.count)
        } / Double(rows.count)

        if missingDataRatio > 0.1 {
            patterns.insert(.sparseData)
        }

        return patterns
    }

    // MARK: - JSON Analysis

    func analyzeJSONData(_ data: Data) async throws -> DataAnalysisResult {
        let json = try JSONSerialization.jsonObject(with: data)

        // Analyze JSON structure
        var structure = JSONStructure()
        analyzeJSONNode(json, depth: 0, structure: &structure)

        // Detect data type based on structure
        let dataType: DataType
        if structure.hasCoordinates {
            dataType = .geospatial
        } else if structure.hasNestedArrays && structure.isNumericData {
            dataType = .matrix
        } else if structure.hasTimestamps {
            dataType = .timeSeries
        } else if structure.isArrayOfObjects {
            dataType = .tabular
        } else if structure.hasNodes && structure.hasEdges {
            dataType = .networkData
        } else {
            dataType = .structured
        }

        return DataAnalysisResult(
            dataType: dataType,
            structure: structure,
            metadata: [
                "depth": structure.maxDepth,
                "totalObjects": structure.objectCount,
                "totalArrays": structure.arrayCount
            ]
        )
    }

    private func analyzeJSONNode(_ node: Any, depth: Int, structure: inout JSONStructure) {
        structure.maxDepth = max(structure.maxDepth, depth)

        if let dict = node as? [String: Any] {
            structure.objectCount += 1

            // Check for coordinate patterns
            let keys = Set(dict.keys.map { $0.lowercased() })
            if keys.contains("lat") || keys.contains("latitude") ||
               keys.contains("x") || keys.contains("coordinates") {
                structure.hasCoordinates = true
            }

            // Check for graph patterns
            if keys.contains("nodes") || keys.contains("vertices") {
                structure.hasNodes = true
            }
            if keys.contains("edges") || keys.contains("links") {
                structure.hasEdges = true
            }

            // Recurse
            for (_, value) in dict {
                analyzeJSONNode(value, depth: depth + 1, structure: &structure)
            }

        } else if let array = node as? [Any] {
            structure.arrayCount += 1

            if !array.isEmpty {
                // Check if array of objects
                if array.allSatisfy({ $0 is [String: Any] }) {
                    structure.isArrayOfObjects = true
                }

                // Check if numeric array
                if array.allSatisfy({ $0 is Double || $0 is Int }) {
                    structure.isNumericData = true

                    // Check for nested arrays (matrix)
                    if depth > 0, array.first is [Any] {
                        structure.hasNestedArrays = true
                    }
                }

                // Analyze first element
                analyzeJSONNode(array[0], depth: depth + 1, structure: &structure)
            }
        }
    }

    // MARK: - Excel Analysis

    func analyzeExcelData(_ data: Data, url: URL) async throws -> DataAnalysisResult {
        // This would use a library like CoreXLSX or similar
        // For now, we'll create a placeholder that demonstrates the structure

        var sheetAnalyses: [SheetAnalysis] = []

        // In a real implementation, this would parse the Excel file
        // and analyze each sheet independently
        let mockSheets = ["Sheet1", "Sheet2"] // Replace with actual sheet parsing

        for sheetName in mockSheets {
            // Analyze each sheet as tabular data
            let sheetAnalysis = SheetAnalysis(
                name: sheetName,
                rowCount: 100, // Replace with actual count
                columnCount: 10, // Replace with actual count
                hasHeaders: true,
                dataTypes: [:] // Would be populated by actual analysis
            )
            sheetAnalyses.append(sheetAnalysis)
        }

        return DataAnalysisResult(
            dataType: .spreadsheet,
            structure: SpreadsheetStructure(sheets: sheetAnalyses),
            metadata: [
                "fileName": url.lastPathComponent,
                "sheetCount": sheetAnalyses.count
            ]
        )
    }

    // MARK: - LAS (LiDAR) Analysis

    func analyzeLASData(_ data: Data) async throws -> DataAnalysisResult {
        // FIX: Added a placeholder LASFileReader to resolve the "Cannot find in scope" error.
        // You will need to replace this with your actual LAS file reading implementation.
        let lasReader = LASFileReader(data: data)
        let header = try lasReader.readHeader()

        // Sample points for analysis
        let sampleSize = min(10000, Int(header.numberOfPointRecords))
        let points = try lasReader.readPoints(count: sampleSize)

        // Analyze point cloud characteristics
        var bounds = PointCloudBounds()
        var hasIntensity = false
        var hasRGB = false
        var hasClassification = false
        var hasGPSTime = false

        for point in points {
            bounds.updateWith(x: point.x, y: point.y, z: point.z)

            if point.intensity > 0 { hasIntensity = true }
            if point.red > 0 || point.green > 0 || point.blue > 0 { hasRGB = true }
            if point.classification > 0 { hasClassification = true }
            if point.gpsTime > 0 { hasGPSTime = true }
        }

        let density = calculatePointDensity(points: points, bounds: bounds)

        return DataAnalysisResult(
            dataType: .pointCloud,
            structure: PointCloudStructure(
                pointCount: Int(header.numberOfPointRecords),
                bounds: bounds,
                hasIntensity: hasIntensity,
                hasColor: hasRGB,
                hasClassification: hasClassification,
                hasGPSTime: hasGPSTime,
                averageDensity: density,
                pointFormat: Int(header.pointDataFormatID)
            ),
            metadata: [
                "version": "\(header.versionMajor).\(header.versionMinor)",
                "systemID": header.systemIdentifier,
                "software": header.generatingSoftware,
                "creationDate": "\(header.fileCreationDayOfYear)-\(header.fileCreationYear)"
            ]
        )
    }

    private func calculatePointDensity(points: [LASPoint], bounds: PointCloudBounds) -> Double {
        let volume = (bounds.maxX - bounds.minX) * (bounds.maxY - bounds.minY) * (bounds.maxZ - bounds.minZ)
        return volume > 0 ? Double(points.count) / volume : 0
    }

    // MARK: - Jupyter Notebook Analysis

    func analyzeNotebookData(_ data: Data) async throws -> DataAnalysisResult {
        // FIX: Cast the result of JSONSerialization to [String: Any] to resolve subscript error.
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cells = json["cells"] as? [[String: Any]] else {
            throw FileAnalysisError.invalidNotebookFormat
        }

        var extractedData: [ExtractedNotebookData] = []
        var visualizationCode: [VisualizationCodeBlock] = []

        for cell in cells {
            guard let cellType = cell["cell_type"] as? String else { continue }

            if cellType == "code" {
                let source = extractSourceFromCell(cell)

                // Look for data definitions
                if let data = extractDataFromCode(source) {
                    extractedData.append(data)
                }

                // Look for visualization code
                if let viz = extractVisualizationFromCode(source) {
                    visualizationCode.append(viz)
                }
            }
        }

        // Determine primary data type based on extracted data
        let dataType = determineDataTypeFromExtracted(extractedData)

        return DataAnalysisResult(
            dataType: dataType,
            structure: NotebookStructure(
                cellCount: cells.count,
                extractedData: extractedData,
                visualizationCode: visualizationCode
            ),
            metadata: [
                "nbformat": json["nbformat"] as? Int ?? 0,
                "language": (json["metadata"] as? [String: Any])?["language_info"] as? [String: Any] ?? [:]
            ]
        )
    }

    private func extractSourceFromCell(_ cell: [String: Any]) -> String {
        if let source = cell["source"] as? String {
            return source
        } else if let sourceArray = cell["source"] as? [String] {
            return sourceArray.joined()
        }
        return ""
    }

    private func extractDataFromCode(_ code: String) -> ExtractedNotebookData? {
        // Look for pandas DataFrames
        if code.contains("pd.DataFrame") || code.contains("read_csv") {
            return ExtractedNotebookData(
                variableName: extractVariableName(from: code),
                dataType: .dataFrame,
                shape: extractDataShape(from: code)
            )
        }

        // Look for numpy arrays
        if code.contains("np.array") || code.contains("numpy.array") {
            return ExtractedNotebookData(
                variableName: extractVariableName(from: code),
                dataType: .array,
                shape: extractDataShape(from: code)
            )
        }

        // Look for point cloud data patterns
        if code.contains("points") && (code.contains("[:,0]") || code.contains("['x']")) {
            return ExtractedNotebookData(
                variableName: extractVariableName(from: code),
                dataType: .pointCloud,
                shape: nil
            )
        }

        return nil
    }

    private func extractVisualizationFromCode(_ code: String) -> VisualizationCodeBlock? {
        var vizType: ImportVisualizationType?
        var data: [String] = []

        if code.contains("plt.scatter") || code.contains("ax.scatter") {
            vizType = code.contains("projection='3d'") ? .scatter3D : .scatter2D
        } else if code.contains("plt.plot") || code.contains("ax.plot") {
            vizType = .line
        } else if code.contains("plt.bar") || code.contains("ax.bar") {
            vizType = .bar
        } else if code.contains("plt.hist") || code.contains("ax.hist") {
            vizType = .histogram
        } else if code.contains("sns.heatmap") || code.contains("plt.imshow") {
            vizType = .heatmap
        } else if code.contains("plot_surface") || code.contains("plot_wireframe") {
            vizType = .surface3D
        }

        guard let type = vizType else { return nil }

        // Extract data variable names
        let lines = code.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("plt.") || line.contains("ax.") || line.contains("sns.") {
                data = extractDataVariables(from: line)
                break
            }
        }

        return VisualizationCodeBlock(
            type: type,
            library: detectVisualizationLibrary(from: code),
            dataVariables: data
        )
    }

    private func extractVariableName(from code: String) -> String {
        let pattern = #"(\w+)\s*="#
        if let match = code.range(of: pattern, options: .regularExpression) {
            let varName = String(code[match]).trimmingCharacters(in: .whitespaces)
            return varName.replacingOccurrences(of: "=", with: "").trimmingCharacters(in: .whitespaces)
        }
        return "data"
    }

    private func extractDataShape(from code: String) -> (Int, Int)? {
        let pattern = #"shape.*?(\d+).*?(\d+)"#
        if let match = code.range(of: pattern, options: .regularExpression) {
            let shapeStr = String(code[match])
            let numbers = shapeStr.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Int($0) }
            if numbers.count >= 2 {
                return (numbers[0], numbers[1])
            }
        }
        return nil
    }

    private func extractDataVariables(from line: String) -> [String] {
        let pattern = #"\(([^,\)]+)"#
        var variables: [String] = []

        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))

            for match in matches {
                if let range = Range(match.range(at: 1), in: line) {
                    let variable = String(line[range]).trimmingCharacters(in: .whitespaces)
                    if !variable.isEmpty && !variable.hasPrefix("'") && !variable.hasPrefix("\"") {
                        variables.append(variable)
                    }
                }
            }
        } catch {
            // Handle regex error if necessary
        }

        return variables
    }

    private func detectVisualizationLibrary(from code: String) -> String {
        if code.contains("plotly") { return "plotly" }
        if code.contains("seaborn") || code.contains("sns") { return "seaborn" }
        if code.contains("matplotlib") || code.contains("plt") { return "matplotlib" }
        return "unknown"
    }

    private func determineDataTypeFromExtracted(_ data: [ExtractedNotebookData]) -> DataType {
        if data.contains(where: { $0.dataType == .pointCloud }) {
            return .pointCloud
        } else if data.contains(where: { $0.dataType == .dataFrame }) {
            return .tabular
        } else if data.contains(where: { $0.dataType == .array }) {
            return .matrix
        }
        return .notebook
    }

    // MARK: - USDZ Analysis

    func analyzeUSDZData(_ data: Data, url: URL) async throws -> DataAnalysisResult {
        // USDZ is a complex format that would require ModelIO or similar
        // For now, we'll create a basic analysis

        return DataAnalysisResult(
            dataType: .model3D,
            structure: Model3DStructure(
                format: "usdz",
                hasTextures: true, // Would be determined by actual parsing
                hasMaterials: true,
                hasAnimations: false,
                vertexCount: 0, // Would be extracted from model
                faceCount: 0
            ),
            metadata: [
                "fileName": url.lastPathComponent,
                "fileSize": data.count
            ]
        )
    }

    // MARK: - Helper Functions

    private func isDate(_ value: String) -> Bool {
        let dateFormatters = [
            ISO8601DateFormatter(),
            DateFormatter.shortDate,
            DateFormatter.mediumDate
        ]

        for formatter in dateFormatters {
            if let isoFormatter = formatter as? ISO8601DateFormatter {
                if isoFormatter.date(from: value) != nil { return true }
            } else if let dateFormatter = formatter as? DateFormatter {
                if dateFormatter.date(from: value) != nil { return true }
            }
        }
        return false
    }

    private func isBoolean(_ value: String) -> Bool {
        let booleanValues = ["true", "false", "yes", "no", "1", "0", "t", "f", "y", "n"]
        return booleanValues.contains(value.lowercased())
    }
}

// MARK: - DateFormatter Extensions

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

