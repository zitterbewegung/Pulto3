//
//  FileAnalyzer.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/18/25.
//  Copyright © 2025 Apple. All rights reserved.
//
/*
import Foundation
import SwiftUI
import TabularData

// Main FileAnalyzer class
class FileAnalyzer: ObservableObject {
    static let shared = FileAnalyzer()

    @Published var analysisProgress: Double = 0.0
    @Published var currentAnalysisStep: String = ""

    private let suggestionEngine = VisualizationSuggestionEngine()
    private let queue = DispatchQueue(label: "com.pulto3.fileanalyzer", qos: .userInitiated)

    func analyzeFile(at url: URL) async throws -> FileAnalysisResult {
        let fileType = SupportedFileType(rawValue: url.pathExtension.lowercased()) ?? .unknown
        if fileType == .unknown {
            throw FileAnalysisError.unsupportedFormat
        }

        // Perform the core analysis to get the data structure
        let analysisResult = try await performAnalysis(for: url, type: fileType)

        // Generate suggestions based on the analysis
        let suggestions = suggestionEngine.suggestVisualizations(for: analysisResult)

        // The final result includes the analysis and the new suggestions
        let finalAnalysis = DataAnalysisResult(
            dataType: analysisResult.dataType,
            structure: analysisResult.structure,
            metadata: analysisResult.metadata,
            suggestions: suggestions
        )

        return FileAnalysisResult(
            fileURL: url,
            fileType: fileType,
            analysis: finalAnalysis,
            suggestions: suggestions
        )
    }

    private func performAnalysis(for url: URL, type: SupportedFileType) async throws -> DataAnalysisResult {
        await updateProgress(step: "Starting analysis...", progress: 0.1)

        switch type {
        case .csv, .tsv:
            return try await analyzeTabular(url: url, isCSV: type == .csv)
        case .json:
            return try await analyzeJSON(url: url)
        case .xlsx:
            return try await analyzeSpreadsheet(url: url)
        case .las:
            return try await analyzePointCloud(url: url)
        case .ipynb:
            return try await analyzeNotebook(url: url)
        case .usdz:
            return try await analyze3DModel(url: url)
        default:
            throw FileAnalysisError.unsupportedFormat
        }
    }

    // MARK: - Analysis Implementations

    private func analyzeTabular(url: URL, isCSV: Bool) async throws -> DataAnalysisResult {
        await updateProgress(step: "Reading tabular data...", progress: 0.2)
        let data = try String(contentsOf: url, encoding: .utf8)
        guard !data.isEmpty else { throw FileAnalysisError.emptyFile }

        let delimiter: Character = isCSV ? "," : "\t"
        let (headers, rows) = ImportCSVParser.parse(data, delimiter: delimiter)
        let rowCount = rows.count

        await updateProgress(step: "Inferring schema...", progress: 0.4)
        let columnTypes = inferColumnTypes(rows: Array(rows.prefix(100)), headers: headers)

        await updateProgress(step: "Detecting patterns...", progress: 0.6)
        var patterns: Set<DataPattern> = []
        if columnTypes.values.contains(.date) {
            patterns.insert(.timeSeries)
        }

        let coordinateColumns = findCoordinateColumns(headers)
        if coordinateColumns.count >= 2 {
            patterns.insert(.spatial)
        }

        let timeColumns = findTimeColumns(headers, columnTypes: columnTypes)

        let dataType: DataType = !coordinateColumns.isEmpty ? .tabularWithCoordinates : .tabular

        let structure = TabularStructure(
            headers: headers,
            columnTypes: columnTypes,
            rowCount: rowCount,
            patterns: patterns,
            coordinateColumns: coordinateColumns,
            timeColumns: timeColumns
        )

        return DataAnalysisResult(
            dataType: dataType,
            structure: structure,
            metadata: ["delimiter": isCSV ? "comma" : "tab"],
            suggestions: []
        )
    }

    private func analyzeJSON(url: URL) async throws -> DataAnalysisResult {
        await updateProgress(step: "Parsing JSON...", progress: 0.3)
        let data = try Data(contentsOf: url)
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) else {
            throw FileAnalysisError.parsingError("Invalid JSON format.")
        }

        await updateProgress(step: "Analyzing JSON structure...", progress: 0.5)
        var structure = JSONStructure()
        var dataType: DataType = .hierarchical // Default for JSON

        // Recursive traversal to analyze structure
        traverseJSON(jsonObject, currentDepth: 1, structure: &structure)

        if structure.hasNodes && structure.hasEdges {
            dataType = .networkData
        } else if structure.hasCoordinates {
            dataType = .geospatial
        } else if structure.isArrayOfObjects {
            dataType = .tabular
        }

        return DataAnalysisResult(
            dataType: dataType,
            structure: structure,
            metadata: ["fileSize": data.count],
            suggestions: []
        )
    }

    private func analyzeSpreadsheet(url: URL) async throws -> DataAnalysisResult {
        await updateProgress(step: "Parsing Excel workbook...", progress: 0.3)

        // Use the new, robust ExcelParser
        let workbook = try ExcelParser.parseExcelFile(at: url)

        await updateProgress(step: "Analyzing sheets...", progress: 0.6)

        // Convert the parser's detailed sheets into the standard SheetAnalysis model
        let sheetAnalyses = workbook.sheets.map { excelSheet -> SheetAnalysis in
            return SheetAnalysis(
                name: excelSheet.name,
                rowCount: excelSheet.rowCount,
                columnCount: excelSheet.columnCount,
                hasHeaders: excelSheet.hasHeaders,
                dataTypes: excelSheet.columnTypes
            )
        }

        let structure = SpreadsheetStructure(sheets: sheetAnalyses)

        var metadata: [String: Any] = ["sheetCount": workbook.sheets.count]
        if let author = workbook.metadata.author {
            metadata["author"] = author
        }

        return DataAnalysisResult(
            dataType: .spreadsheet,
            structure: structure,
            metadata: metadata,
            suggestions: []
        )
    }

    private func analyzePointCloud(url: URL) async throws -> DataAnalysisResult {
        await updateProgress(step: "Reading LAS file...", progress: 0.3)
        let data = try Data(contentsOf: url)
        let reader = LASFileReader(data: data)
        let header = try reader.readHeader()

        await updateProgress(step: "Analyzing point cloud header...", progress: 0.6)
        let structure = PointCloudStructure(
            pointCount: Int(header.numberOfPointRecords),
            bounds: PointCloudBounds(minX: header.minX, maxX: header.maxX, minY: header.minY, maxY: header.maxY, minZ: header.minZ, maxZ: header.maxZ),
            hasIntensity: reader.pointFormatHasIntensity(),
            hasColor: reader.pointFormatHasColor(),
            hasClassification: true, // All standard formats have classification
            hasGPSTime: reader.pointFormatHasGPSTime(),
            averageDensity: 0, // Would require full point analysis to calculate
            pointFormat: Int(header.pointDataFormatID)
        )

        return DataAnalysisResult(
            dataType: .pointCloud,
            structure: structure,
            metadata: ["version": "\(header.versionMajor).\(header.versionMinor)", "software": header.generatingSoftware],
            suggestions: []
        )
    }

    private func analyzeNotebook(url: URL) async throws -> DataAnalysisResult {
        // A full implementation would parse the .ipynb JSON structure
        await updateProgress(step: "Analyzing notebook...", progress: 0.4)
        let structure = NotebookStructure(cellCount: 0, extractedData: [], visualizationCode: [])
        return DataAnalysisResult(dataType: .notebook, structure: structure, metadata: [:], suggestions: [])
    }

    private func analyze3DModel(url: URL) async throws -> DataAnalysisResult {
        // A full implementation would use Model I/O or RealityKit to inspect the USDZ asset
        await updateProgress(step: "Analyzing 3D model...", progress: 0.4)
        let structure = Model3DStructure(format: "usdz", hasTextures: false, hasMaterials: false, hasAnimations: false, vertexCount: 0, faceCount: 0)
        return DataAnalysisResult(dataType: .model3D, structure: structure, metadata: [:], suggestions: [])
    }

    // MARK: - Helper Functions

    private func traverseJSON(_ json: Any, currentDepth: Int, structure: inout JSONStructure) {
        structure.maxDepth = max(structure.maxDepth, currentDepth)

        if let dictionary = json as? [String: Any] {
            structure.objectCount += 1
            if Set(dictionary.keys).contains("nodes") && Set(dictionary.keys).contains("edges") {
                structure.hasNodes = true
                structure.hasEdges = true
            }
            if Set(dictionary.keys).contains("lat") && Set(dictionary.keys).contains("lon") {
                structure.hasCoordinates = true
            }

            for value in dictionary.values {
                traverseJSON(value, currentDepth: currentDepth + 1, structure: &structure)
            }
        } else if let array = json as? [Any] {
            structure.arrayCount += 1
            if !array.isEmpty {
                // Check if it's an array of objects (potential tabular data)
                if array[0] is [String: Any] {
                    structure.isArrayOfObjects = true
                }
                // Check for nested arrays
                if array[0] is [Any] {
                    structure.hasNestedArrays = true
                }
                traverseJSON(array[0], currentDepth: currentDepth + 1, structure: &structure)
            }
        }
    }

    private func inferColumnTypes(rows: [[String]], headers: [String]) -> [String: ColumnType] {
        var columnTypes: [String: ColumnType] = [:]
        guard !rows.isEmpty else { return [:] }

        for (index, header) in headers.enumerated() {
            let sampleValues = rows.compactMap { $0.count > index ? $0[index] : nil }
            columnTypes[header] = inferTypeForColumn(values: sampleValues)
        }
        return columnTypes
    }

    private func inferTypeForColumn(values: [String]) -> ColumnType {
        guard !values.isEmpty else { return .unknown }

        var numericCount = 0
        var dateCount = 0
        let sampleSize = min(values.count, 100) // Don't check the whole file for performance

        for i in 0..<sampleSize {
            let value = values[i].trimmingCharacters(in: .whitespaces)
            if value.isEmpty { continue }

            if Double(value) != nil { numericCount += 1 }
            if ISO8601DateFormatter().date(from: value) != nil { dateCount += 1 }
        }

        let threshold = 0.8 // 80% of values must match the type

        if Double(numericCount) / Double(sampleSize) >= threshold { return .numeric }
        if Double(dateCount) / Double(sampleSize) >= threshold { return .date }

        return .categorical
    }

    private func findCoordinateColumns(_ headers: [String]) -> [String] {
        let h = headers.map { $0.lowercased() }
        var coords: [String] = []
        if let xIndex = h.firstIndex(of: "x"), let yIndex = h.firstIndex(of: "y") {
            coords.append(headers[xIndex])
            coords.append(headers[yIndex])
            if let zIndex = h.firstIndex(of: "z") {
                coords.append(headers[zIndex])
            }
        } else if let latIndex = h.firstIndex(where: { $0 == "lat" || $0 == "latitude" }),
                  let lonIndex = h.firstIndex(where: { $0 == "lon" || $0 == "longitude" }) {
            coords.append(headers[latIndex])
            coords.append(headers[lonIndex])
        }
        return coords
    }

    private func findTimeColumns(_ headers: [String], columnTypes: [String: ColumnType]) -> [String] {
        return headers.filter { header in
            columnTypes[header] == .date || header.lowercased().contains("time") || header.lowercased().contains("date")
        }
    }

    @MainActor
    private func updateProgress(step: String, progress: Double) {
        self.currentAnalysisStep = step
        self.analysisProgress = progress
    }
}
*/
