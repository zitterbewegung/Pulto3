//
//  PointCloudImporter.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/8/25.
//  Copyright Apple. All rights reserved.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Point Cloud File Importer
/// Supports importing real point cloud data from various file formats
struct PointCloudImporter {
    
    // MARK: - Supported File Types
    
    enum SupportedFormat: String, CaseIterable {
        case ply = "ply"
        case pcd = "pcd"
        case xyz = "xyz"
        case csv = "csv"
        case obj = "obj"
        case txt = "txt"
        case json = "json"
        
        var displayName: String {
            switch self {
            case .ply: return "PLY (Stanford Polygon Library)"
            case .pcd: return "PCD (Point Cloud Data)"
            case .xyz: return "XYZ (Simple Text Format)"
            case .csv: return "CSV (Comma Separated Values)"
            case .obj: return "OBJ (Wavefront OBJ)"
            case .txt: return "TXT (Text Format)"
            case .json: return "JSON (JavaScript Object Notation)"
            }
        }
        
        var uniformTypeIdentifier: UTType {
            switch self {
            case .ply: return UTType("public.ply") ?? .data
            case .pcd: return UTType("public.pcd") ?? .data
            case .xyz: return UTType("public.xyz") ?? .plainText
            case .csv: return .commaSeparatedText
            case .obj: return UTType("public.geometry-definition-format") ?? .data
            case .txt: return .plainText
            case .json: return .json
            }
        }
        
        var fileExtension: String {
            return self.rawValue
        }
    }
    
    // MARK: - Import Result
    
    struct ImportResult {
        let pointCloudData: PointCloudData
        let originalFileName: String
        let fileSize: Int64
        let importDuration: TimeInterval
        let warnings: [String]
    }
    
    // MARK: - Import Errors
    
    enum ImportError: LocalizedError {
        case unsupportedFormat(String)
        case fileNotFound
        case invalidFileStructure(String)
        case parsingError(String)
        case noPointsFound
        case fileTooLarge(Int64)
        case memoryLimitExceeded
        
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let format):
                return "Unsupported file format: \(format)"
            case .fileNotFound:
                return "File not found or inaccessible"
            case .invalidFileStructure(let details):
                return "Invalid file structure: \(details)"
            case .parsingError(let details):
                return "Parsing error: \(details)"
            case .noPointsFound:
                return "No valid points found in file"
            case .fileTooLarge(let size):
                return "File too large: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
            case .memoryLimitExceeded:
                return "Memory limit exceeded during import"
            }
        }
    }
    
    // MARK: - Configuration
    
    struct ImportConfiguration {
        var maxPoints: Int = 1_000_000  // Limit for performance
        var maxFileSize: Int64 = 100 * 1024 * 1024  // 100MB limit
        var skipEveryNPoints: Int = 1  // Decimation factor
        var normalizeCoordinates: Bool = true
        var centerAtOrigin: Bool = true
        var autoDetectFormat: Bool = true
        
        static let `default` = ImportConfiguration()
    }
    
    // MARK: - Main Import Method
    
    static func importPointCloud(from url: URL, configuration: ImportConfiguration = .default) async throws -> ImportResult {
        let startTime = Date()
        
        // Validate file
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImportError.fileNotFound
        }
        
        // Check file size
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        if fileSize > configuration.maxFileSize {
            throw ImportError.fileTooLarge(fileSize)
        }
        
        // Determine format
        let format = try detectFormat(from: url, autoDetect: configuration.autoDetectFormat)
        
        // Import based on format
        let (pointCloudData, warnings) = try await importPointCloudData(
            from: url,
            format: format,
            configuration: configuration
        )
        
        let importDuration = Date().timeIntervalSince(startTime)
        
        return ImportResult(
            pointCloudData: pointCloudData,
            originalFileName: url.lastPathComponent,
            fileSize: fileSize,
            importDuration: importDuration,
            warnings: warnings
        )
    }
    
    // MARK: - Format Detection
    
    private static func detectFormat(from url: URL, autoDetect: Bool) throws -> SupportedFormat {
        let fileExtension = url.pathExtension.lowercased()
        
        if let format = SupportedFormat(rawValue: fileExtension) {
            return format
        }
        
        if autoDetect {
            // Try to detect format from file content
            let content = try String(contentsOf: url, encoding: .utf8).prefix(1000)
            
            if content.contains("ply") || content.contains("format ascii") || content.contains("element vertex") {
                return .ply
            } else if content.contains("# .PCD") || content.contains("VERSION") || content.contains("FIELDS") {
                return .pcd
            } else if content.contains("{") && content.contains("}") {
                return .json
            } else if content.contains(",") {
                return .csv
            } else if content.contains("v ") || content.contains("vn ") {
                return .obj
            } else {
                return .xyz  // Default to XYZ for plain text
            }
        }
        
        throw ImportError.unsupportedFormat(fileExtension)
    }
    
    // MARK: - Format-Specific Import Methods
    
    private static func importPointCloudData(
        from url: URL,
        format: SupportedFormat,
        configuration: ImportConfiguration
    ) async throws -> (PointCloudData, [String]) {
        
        switch format {
        case .ply:
            return try await importPLY(from: url, configuration: configuration)
        case .pcd:
            return try await importPCD(from: url, configuration: configuration)
        case .xyz:
            return try await importXYZ(from: url, configuration: configuration)
        case .csv:
            return try await importCSV(from: url, configuration: configuration)
        case .obj:
            return try await importOBJ(from: url, configuration: configuration)
        case .txt:
            return try await importTXT(from: url, configuration: configuration)
        case .json:
            return try await importJSON(from: url, configuration: configuration)
        }
    }
    
    // MARK: - PLY Format Import
    
    private static func importPLY(from url: URL, configuration: ImportConfiguration) async throws -> (PointCloudData, [String]) {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        var warnings: [String] = []
        var points: [PointCloudData.PointData] = []
        var vertexCount = 0
        var inHeader = true
        var hasColor = false
        var hasNormals = false
        
        // Parse header
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed == "end_header" {
                inHeader = false
                continue
            }
            
            if inHeader {
                if trimmed.hasPrefix("element vertex") {
                    let components = trimmed.components(separatedBy: .whitespaces)
                    if components.count >= 3 {
                        vertexCount = Int(components[2]) ?? 0
                    }
                }
                
                if trimmed.contains("property") {
                    if trimmed.contains("red") || trimmed.contains("green") || trimmed.contains("blue") {
                        hasColor = true
                    }
                    if trimmed.contains("nx") || trimmed.contains("ny") || trimmed.contains("nz") {
                        hasNormals = true
                    }
                }
                continue
            }
            
            // Parse vertex data
            if !trimmed.isEmpty && points.count < configuration.maxPoints {
                let components = trimmed.components(separatedBy: .whitespaces)
                if components.count >= 3 {
                    if let x = Double(components[0]),
                       let y = Double(components[1]),
                       let z = Double(components[2]) {
                        
                        // Skip points based on decimation
                        if points.count % configuration.skipEveryNPoints == 0 {
                            var intensity: Double = 0.5
                            
                            // Extract color if available
                            if hasColor && components.count >= 6 {
                                if let r = Double(components[3]),
                                   let g = Double(components[4]),
                                   let b = Double(components[5]) {
                                    intensity = (r + g + b) / (3.0 * 255.0)
                                }
                            }
                            
                            let point = PointCloudData.PointData(
                                x: x,
                                y: y,
                                z: z,
                                intensity: intensity
                            )
                            points.append(point)
                        }
                    }
                }
            }
        }
        
        if points.isEmpty {
            throw ImportError.noPointsFound
        }
        
        if points.count < vertexCount {
            warnings.append("Only imported \(points.count) of \(vertexCount) vertices due to limits")
        }
        
        let processedPoints = processPoints(points, configuration: configuration)
        
        var pointCloudData = PointCloudData(
            title: "Imported PLY: \(url.lastPathComponent)",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "Imported PLY",
            parameters: [
                "originalVertexCount": Double(vertexCount),
                "importedPoints": Double(processedPoints.count),
                "hasColor": hasColor ? 1.0 : 0.0,
                "hasNormals": hasNormals ? 1.0 : 0.0
            ]
        )
        
        pointCloudData.points = processedPoints
        pointCloudData.totalPoints = processedPoints.count
        
        return (pointCloudData, warnings)
    }
    
    // MARK: - PCD Format Import
    
    private static func importPCD(from url: URL, configuration: ImportConfiguration) async throws -> (PointCloudData, [String]) {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        var warnings: [String] = []
        var points: [PointCloudData.PointData] = []
        var fields: [String] = []
        var pointCount = 0
        var dataStarted = false
        
        // Parse header
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("FIELDS") {
                fields = trimmed.components(separatedBy: .whitespaces).dropFirst().map { String($0) }
            } else if trimmed.hasPrefix("POINTS") {
                let components = trimmed.components(separatedBy: .whitespaces)
                if components.count >= 2 {
                    pointCount = Int(components[1]) ?? 0
                }
            } else if trimmed.hasPrefix("DATA") {
                dataStarted = true
                continue
            }
            
            if dataStarted && !trimmed.isEmpty && points.count < configuration.maxPoints {
                let components = trimmed.components(separatedBy: .whitespaces)
                
                // Find x, y, z indices
                guard let xIndex = fields.firstIndex(of: "x"),
                      let yIndex = fields.firstIndex(of: "y"),
                      let zIndex = fields.firstIndex(of: "z"),
                      components.count > max(xIndex, yIndex, zIndex) else {
                    continue
                }
                
                if let x = Double(components[xIndex]),
                   let y = Double(components[yIndex]),
                   let z = Double(components[zIndex]) {
                    
                    if points.count % configuration.skipEveryNPoints == 0 {
                        var intensity: Double = 0.5
                        
                        // Try to extract intensity or RGB
                        if let intensityIndex = fields.firstIndex(of: "intensity"),
                           intensityIndex < components.count,
                           let intensityValue = Double(components[intensityIndex]) {
                            intensity = min(1.0, max(0.0, intensityValue / 255.0))
                        }
                        
                        let point = PointCloudData.PointData(
                            x: x,
                            y: y,
                            z: z,
                            intensity: intensity
                        )
                        points.append(point)
                    }
                }
            }
        }
        
        if points.isEmpty {
            throw ImportError.noPointsFound
        }
        
        if points.count < pointCount {
            warnings.append("Only imported \(points.count) of \(pointCount) points due to limits")
        }
        
        let processedPoints = processPoints(points, configuration: configuration)
        
        var pointCloudData = PointCloudData(
            title: "Imported PCD: \(url.lastPathComponent)",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "Imported PCD",
            parameters: [
                "originalPointCount": Double(pointCount),
                "importedPoints": Double(processedPoints.count),
                "fields": Double(fields.count)
            ]
        )
        
        pointCloudData.points = processedPoints
        pointCloudData.totalPoints = processedPoints.count
        
        return (pointCloudData, warnings)
    }
    
    // MARK: - XYZ Format Import
    
    private static func importXYZ(from url: URL, configuration: ImportConfiguration) async throws -> (PointCloudData, [String]) {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        var warnings: [String] = []
        var points: [PointCloudData.PointData] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("//") {
                continue
            }
            
            if points.count >= configuration.maxPoints {
                break
            }
            
            let components = trimmed.components(separatedBy: .whitespaces)
            if components.count >= 3 {
                if let x = Double(components[0]),
                   let y = Double(components[1]),
                   let z = Double(components[2]) {
                    
                    if points.count % configuration.skipEveryNPoints == 0 {
                        var intensity: Double = 0.5
                        
                        // If there's a 4th column, use it as intensity
                        if components.count >= 4,
                           let intensityValue = Double(components[3]) {
                            intensity = min(1.0, max(0.0, intensityValue))
                        }
                        
                        let point = PointCloudData.PointData(
                            x: x,
                            y: y,
                            z: z,
                            intensity: intensity
                        )
                        points.append(point)
                    }
                }
            }
        }
        
        if points.isEmpty {
            throw ImportError.noPointsFound
        }
        
        let processedPoints = processPoints(points, configuration: configuration)
        
        var pointCloudData = PointCloudData(
            title: "Imported XYZ: \(url.lastPathComponent)",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "Imported XYZ",
            parameters: [
                "importedPoints": Double(processedPoints.count)
            ]
        )
        
        pointCloudData.points = processedPoints
        pointCloudData.totalPoints = processedPoints.count
        
        return (pointCloudData, warnings)
    }
    
    // MARK: - CSV Format Import
    
    private static func importCSV(from url: URL, configuration: ImportConfiguration) async throws -> (PointCloudData, [String]) {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        var warnings: [String] = []
        var points: [PointCloudData.PointData] = []
        var headers: [String] = []
        var isFirstLine = true
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                continue
            }
            
            if points.count >= configuration.maxPoints {
                break
            }
            
            let components = trimmed.components(separatedBy: ",")
            
            if isFirstLine {
                // Check if first line is headers
                if components.contains(where: { $0.lowercased().contains("x") || $0.lowercased().contains("y") || $0.lowercased().contains("z") }) {
                    headers = components.map { $0.trimmingCharacters(in: .whitespaces) }
                    isFirstLine = false
                    continue
                }
                isFirstLine = false
            }
            
            // Find x, y, z columns
            var xIndex = 0, yIndex = 1, zIndex = 2
            
            if !headers.isEmpty {
                xIndex = headers.firstIndex(where: { $0.lowercased().contains("x") }) ?? 0
                yIndex = headers.firstIndex(where: { $0.lowercased().contains("y") }) ?? 1
                zIndex = headers.firstIndex(where: { $0.lowercased().contains("z") }) ?? 2
            }
            
            if components.count > max(xIndex, yIndex, zIndex) {
                if let x = Double(components[xIndex].trimmingCharacters(in: .whitespaces)),
                   let y = Double(components[yIndex].trimmingCharacters(in: .whitespaces)),
                   let z = Double(components[zIndex].trimmingCharacters(in: .whitespaces)) {
                    
                    if points.count % configuration.skipEveryNPoints == 0 {
                        var intensity: Double = 0.5
                        
                        // Look for intensity or color columns
                        if !headers.isEmpty {
                            if let intensityIndex = headers.firstIndex(where: { $0.lowercased().contains("intensity") || $0.lowercased().contains("i") }),
                               intensityIndex < components.count,
                               let intensityValue = Double(components[intensityIndex].trimmingCharacters(in: .whitespaces)) {
                                intensity = min(1.0, max(0.0, intensityValue / 255.0))
                            }
                        }
                        
                        let point = PointCloudData.PointData(
                            x: x,
                            y: y,
                            z: z,
                            intensity: intensity
                        )
                        points.append(point)
                    }
                }
            }
        }
        
        if points.isEmpty {
            throw ImportError.noPointsFound
        }
        
        let processedPoints = processPoints(points, configuration: configuration)
        
        var pointCloudData = PointCloudData(
            title: "Imported CSV: \(url.lastPathComponent)",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "Imported CSV",
            parameters: [
                "importedPoints": Double(processedPoints.count),
                "hasHeaders": headers.isEmpty ? 0.0 : 1.0
            ]
        )
        
        pointCloudData.points = processedPoints
        pointCloudData.totalPoints = processedPoints.count
        
        return (pointCloudData, warnings)
    }
    
    // MARK: - OBJ Format Import
    
    private static func importOBJ(from url: URL, configuration: ImportConfiguration) async throws -> (PointCloudData, [String]) {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        var warnings: [String] = []
        var points: [PointCloudData.PointData] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            if points.count >= configuration.maxPoints {
                break
            }
            
            if trimmed.hasPrefix("v ") {
                let components = trimmed.components(separatedBy: .whitespaces)
                if components.count >= 4 {
                    if let x = Double(components[1]),
                       let y = Double(components[2]),
                       let z = Double(components[3]) {
                        
                        if points.count % configuration.skipEveryNPoints == 0 {
                            let point = PointCloudData.PointData(
                                x: x,
                                y: y,
                                z: z,
                                intensity: 0.5
                            )
                            points.append(point)
                        }
                    }
                }
            }
        }
        
        if points.isEmpty {
            throw ImportError.noPointsFound
        }
        
        let processedPoints = processPoints(points, configuration: configuration)
        
        var pointCloudData = PointCloudData(
            title: "Imported OBJ: \(url.lastPathComponent)",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "Imported OBJ",
            parameters: [
                "importedPoints": Double(processedPoints.count)
            ]
        )
        
        pointCloudData.points = processedPoints
        pointCloudData.totalPoints = processedPoints.count
        
        return (pointCloudData, warnings)
    }
    
    // MARK: - TXT Format Import
    
    private static func importTXT(from url: URL, configuration: ImportConfiguration) async throws -> (PointCloudData, [String]) {
        // TXT format is treated the same as XYZ
        return try await importXYZ(from: url, configuration: configuration)
    }
    
    // MARK: - JSON Format Import
    
    private static func importJSON(from url: URL, configuration: ImportConfiguration) async throws -> (PointCloudData, [String]) {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        var warnings: [String] = []
        var points: [PointCloudData.PointData] = []
        
        // Try different JSON structures
        if let pointsArray = json?["points"] as? [[String: Any]] {
            for pointDict in pointsArray {
                if points.count >= configuration.maxPoints {
                    break
                }
                
                if let x = pointDict["x"] as? Double,
                   let y = pointDict["y"] as? Double,
                   let z = pointDict["z"] as? Double {
                    
                    if points.count % configuration.skipEveryNPoints == 0 {
                        let intensity = pointDict["intensity"] as? Double ?? 0.5
                        
                        let point = PointCloudData.PointData(
                            x: x,
                            y: y,
                            z: z,
                            intensity: intensity
                        )
                        points.append(point)
                    }
                }
            }
        }
        
        if points.isEmpty {
            throw ImportError.noPointsFound
        }
        
        let processedPoints = processPoints(points, configuration: configuration)
        
        var pointCloudData = PointCloudData(
            title: "Imported JSON: \(url.lastPathComponent)",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "Imported JSON",
            parameters: [
                "importedPoints": Double(processedPoints.count)
            ]
        )
        
        pointCloudData.points = processedPoints
        pointCloudData.totalPoints = processedPoints.count
        
        return (pointCloudData, warnings)
    }
    
    // MARK: - Point Processing
    
    private static func processPoints(_ points: [PointCloudData.PointData], configuration: ImportConfiguration) -> [PointCloudData.PointData] {
        var processedPoints = points
        
        if configuration.normalizeCoordinates || configuration.centerAtOrigin {
            // Calculate bounds
            let xValues = points.map { $0.x }
            let yValues = points.map { $0.y }
            let zValues = points.map { $0.z }
            
            let minX = xValues.min() ?? 0
            let maxX = xValues.max() ?? 0
            let minY = yValues.min() ?? 0
            let maxY = yValues.max() ?? 0
            let minZ = zValues.min() ?? 0
            let maxZ = zValues.max() ?? 0
            
            let centerX = (minX + maxX) / 2
            let centerY = (minY + maxY) / 2
            let centerZ = (minZ + maxZ) / 2
            
            let rangeX = maxX - minX
            let rangeY = maxY - minY
            let rangeZ = maxZ - minZ
            let maxRange = max(rangeX, rangeY, rangeZ)
            
            processedPoints = points.map { point in
                var newPoint = point
                
                if configuration.centerAtOrigin {
                    newPoint.x -= centerX
                    newPoint.y -= centerY
                    newPoint.z -= centerZ
                }
                
                if configuration.normalizeCoordinates && maxRange > 0 {
                    let scale = 20.0 / maxRange  // Scale to fit in a 20x20x20 cube
                    newPoint.x *= scale
                    newPoint.y *= scale
                    newPoint.z *= scale
                }
                
                return newPoint
            }
        }
        
        return processedPoints
    }
}

// MARK: - SwiftUI File Picker Integration

struct PointCloudFilePicker: View {
    @State private var showingFilePicker = false
    @State private var isImporting = false
    @State private var importProgress: Double = 0.0
    @State private var importResult: PointCloudImporter.ImportResult?
    @State private var importError: PointCloudImporter.ImportError?
    
    let onImportComplete: (PointCloudData) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            if isImporting {
                importingView
            } else {
                importButtonView
            }
            
            if let result = importResult {
                importResultView(result)
            }
            
            if let error = importError {
                errorView(error)
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: PointCloudImporter.SupportedFormat.allCases.map { $0.uniformTypeIdentifier },
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }
    
    private var importButtonView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Import Point Cloud")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Import real point cloud data from various file formats")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Supported formats:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(PointCloudImporter.SupportedFormat.allCases, id: \.self) { format in
                    Label(format.displayName, systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            Button("Choose File") {
                showingFilePicker = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
    
    private var importingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: importProgress)
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(2.0)
            
            Text("Importing Point Cloud...")
                .font(.headline)
            
            Text("This may take a moment for large files")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    private func importResultView(_ result: PointCloudImporter.ImportResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Import Successful")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("File: \(result.originalFileName)")
                Text("Points: \(result.pointCloudData.totalPoints)")
                Text("Size: \(ByteCountFormatter.string(fromByteCount: result.fileSize, countStyle: .file))")
                Text("Duration: \(String(format: "%.2f", result.importDuration))s")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Warnings:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                    
                    ForEach(result.warnings, id: \.self) { warning in
                        Text("• \(warning)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Button("Use This Point Cloud") {
                onImportComplete(result.pointCloudData)
                importResult = nil
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func errorView(_ error: PointCloudImporter.ImportError) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("Import Failed")
                    .font(.headline)
            }
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(.secondary)
            
            Button("Try Again") {
                importError = nil
                showingFilePicker = true
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            isImporting = true
            importError = nil
            importResult = nil
            
            Task {
                do {
                    let configuration = PointCloudImporter.ImportConfiguration.default
                    let result = try await PointCloudImporter.importPointCloud(from: url, configuration: configuration)
                    
                    await MainActor.run {
                        isImporting = false
                        importResult = result
                    }
                } catch let error as PointCloudImporter.ImportError {
                    await MainActor.run {
                        isImporting = false
                        importError = error
                    }
                } catch {
                    await MainActor.run {
                        isImporting = false
                        importError = .parsingError(error.localizedDescription)
                    }
                }
            }
            
        case .failure(let error):
            importError = .parsingError(error.localizedDescription)
        }
    }
}

// MARK: - Legacy Compatibility

/// Provides compatibility with existing PointCloudDemo calls
/// NOTE: This is now defined in Models/PointCloudDemo.swift
/// Keep this comment for reference but remove the duplicate struct definition

// The rest of the file remains the same

extension PointCloudImporter {
    
    static func generateDemoSphere(radius: Double = 10.0, points: Int = 1000) -> PointCloudData {
        var cloudPoints: [PointCloudData.PointData] = []
        
        for i in 0..<points {
            let theta = Double.random(in: 0...(2 * Double.pi))
            let phi = Double.random(in: 0...Double.pi)
            
            let x = radius * sin(phi) * cos(theta)
            let y = radius * sin(phi) * sin(theta)
            let z = radius * cos(phi)
            
            let intensity = (z + radius) / (2 * radius)
            
            let point = PointCloudData.PointData(
                x: x,
                y: y,
                z: z,
                intensity: intensity
            )
            cloudPoints.append(point)
        }
        
        var pointCloud = PointCloudData(
            title: "Demo Sphere Point Cloud",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "Demo Sphere",
            parameters: [
                "radius": radius,
                "points": Double(points)
            ]
        )
        
        pointCloud.points = cloudPoints
        pointCloud.totalPoints = cloudPoints.count
        
        return pointCloud
    }
}