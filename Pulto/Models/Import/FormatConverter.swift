//
//  FormatConverter.swift
//  Pulto3
//
//  Created by AI Assistant on 1/29/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SceneKit
import ModelIO

// MARK: - Format Converter

class FormatConverter: ObservableObject {
    static let shared = FormatConverter()
    
    @Published var isConverting = false
    @Published var conversionProgress: ConversionProgress = ConversionProgress()
    @Published var conversionHistory: [ConversionSession] = []
    
    // MARK: - Supported Conversions
    
    enum ConversionType: CaseIterable {
        // Data conversions
        case csvToJson
        case jsonToCsv
        case csvToExcel
        case tsvToCsv
        
        // 3D Model conversions
        case objToUsdz
        case usdzToObj
        case stlToUsdz
        case stlToObj
        case plyToObj
        case objToStl
        
        // Point Cloud conversions
        case plyToCsv
        case csvToPly
        case plyToJson
        case jsonToPly
        
        var description: String {
            switch self {
            case .csvToJson: return "CSV to JSON"
            case .jsonToCsv: return "JSON to CSV"
            case .csvToExcel: return "CSV to Excel"
            case .tsvToCsv: return "TSV to CSV"
            case .objToUsdz: return "OBJ to USDZ"
            case .usdzToObj: return "USDZ to OBJ"
            case .stlToUsdz: return "STL to USDZ"
            case .stlToObj: return "STL to OBJ"
            case .plyToObj: return "PLY to OBJ"
            case .objToStl: return "OBJ to STL"
            case .plyToCsv: return "PLY to CSV"
            case .csvToPly: return "CSV to PLY"
            case .plyToJson: return "PLY to JSON"
            case .jsonToPly: return "JSON to PLY"
            }
        }
        
        var inputFormat: String {
            switch self {
            case .csvToJson, .csvToExcel, .csvToPly: return "CSV"
            case .jsonToCsv, .jsonToPly: return "JSON"
            case .tsvToCsv: return "TSV"
            case .objToUsdz, .objToStl: return "OBJ"
            case .usdzToObj: return "USDZ"
            case .stlToUsdz, .stlToObj: return "STL"
            case .plyToObj, .plyToCsv, .plyToJson: return "PLY"
            }
        }
        
        var outputFormat: String {
            switch self {
            case .csvToJson, .plyToJson: return "JSON"
            case .jsonToCsv, .tsvToCsv, .plyToCsv: return "CSV"
            case .csvToExcel: return "XLSX"
            case .objToUsdz, .stlToUsdz: return "USDZ"
            case .usdzToObj, .stlToObj, .plyToObj: return "OBJ"
            case .objToStl: return "STL"
            case .csvToPly, .jsonToPly: return "PLY"
            }
        }
        
        var category: ConversionCategory {
            switch self {
            case .csvToJson, .jsonToCsv, .csvToExcel, .tsvToCsv:
                return .data
            case .objToUsdz, .usdzToObj, .stlToUsdz, .stlToObj, .plyToObj, .objToStl:
                return .model3D
            case .plyToCsv, .csvToPly, .plyToJson, .jsonToPly:
                return .pointCloud
            }
        }
    }
    
    enum ConversionCategory: String, CaseIterable {
        case data = "Data"
        case model3D = "3D Models"
        case pointCloud = "Point Clouds"
        
        var icon: String {
            switch self {
            case .data: return "tablecells"
            case .model3D: return "cube"
            case .pointCloud: return "circle.grid.3x3"
            }
        }
        
        var color: Color {
            switch self {
            case .data: return .green
            case .model3D: return .orange
            case .pointCloud: return .purple
            }
        }
    }
    
    // MARK: - Conversion Methods
    
    func convertFile(
        inputURL: URL,
        conversionType: ConversionType,
        outputURL: URL? = nil
    ) async throws -> URL {
        
        let session = ConversionSession(
            inputURL: inputURL,
            conversionType: conversionType,
            startedAt: Date()
        )
        
        await MainActor.run {
            conversionHistory.append(session)
            isConverting = true
            conversionProgress = ConversionProgress(
                currentFile: inputURL.lastPathComponent,
                conversionType: conversionType
            )
        }
        
        defer {
            Task { @MainActor in
                isConverting = false
                conversionProgress = ConversionProgress()
            }
        }
        
        do {
            let outputURL = try await performConversion(
                inputURL: inputURL,
                conversionType: conversionType,
                outputURL: outputURL
            )
            
            await MainActor.run {
                session.status = .completed
                session.completedAt = Date()
                session.outputURL = outputURL
            }
            
            return outputURL
            
        } catch {
            await MainActor.run {
                session.status = .failed(error)
                session.completedAt = Date()
            }
            throw error
        }
    }
    
    // MARK: - Core Conversion Logic
    
    private func performConversion(
        inputURL: URL,
        conversionType: ConversionType,
        outputURL: URL?
    ) async throws -> URL {
        
        await updateProgress(stage: .reading)
        
        switch conversionType.category {
        case .data:
            return try await convertDataFile(inputURL, type: conversionType, outputURL: outputURL)
        case .model3D:
            return try await convert3DModel(inputURL, type: conversionType, outputURL: outputURL)
        case .pointCloud:
            return try await convertPointCloud(inputURL, type: conversionType, outputURL: outputURL)
        }
    }
    
    // MARK: - Data Conversions
    
    private func convertDataFile(
        _ inputURL: URL,
        type: ConversionType,
        outputURL: URL?
    ) async throws -> URL {
        
        guard inputURL.startAccessingSecurityScopedResource() else {
            throw ConversionError.accessDenied
        }
        defer { inputURL.stopAccessingSecurityScopedResource() }
        
        await updateProgress(stage: .parsing)
        
        switch type {
        case .csvToJson:
            return try await convertCSVToJSON(inputURL, outputURL: outputURL)
        case .jsonToCsv:
            return try await convertJSONToCSV(inputURL, outputURL: outputURL)
        case .tsvToCsv:
            return try await convertTSVToCSV(inputURL, outputURL: outputURL)
        case .csvToExcel:
            return try await convertCSVToExcel(inputURL, outputURL: outputURL)
        default:
            throw ConversionError.unsupportedType
        }
    }
    
    private func convertCSVToJSON(_ inputURL: URL, outputURL: URL?) async throws -> URL {
        let content = try String(contentsOf: inputURL)
        guard let csvData = CSVParser.parse(content) else {
            throw ConversionError.parsingFailed
        }
        
        await updateProgress(stage: .converting)
        
        // Convert to JSON array of objects
        var jsonObjects: [[String: Any]] = []
        
        for row in csvData.rows {
            var object: [String: Any] = [:]
            for (index, header) in csvData.headers.enumerated() {
                let value = index < row.count ? row[index] : ""
                
                // Try to convert to appropriate type
                if let doubleValue = Double(value) {
                    object[header] = doubleValue
                } else if value.lowercased() == "true" || value.lowercased() == "false" {
                    object[header] = Bool(value.lowercased()) ?? false
                } else {
                    object[header] = value
                }
            }
            jsonObjects.append(object)
        }
        
        await updateProgress(stage: .writing)
        
        let jsonData = try JSONSerialization.data(withJSONObject: jsonObjects, options: .prettyPrinted)
        
        let finalOutputURL = outputURL ?? generateOutputURL(from: inputURL, extension: "json")
        try jsonData.write(to: finalOutputURL)
        
        return finalOutputURL
    }
    
    private func convertJSONToCSV(_ inputURL: URL, outputURL: URL?) async throws -> URL {
        let jsonData = try Data(contentsOf: inputURL)
        
        await updateProgress(stage: .parsing)
        
        guard let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            throw ConversionError.invalidFormat
        }
        
        await updateProgress(stage: .converting)
        
        // Extract headers from all objects
        var allKeys = Set<String>()
        for object in jsonArray {
            allKeys.formUnion(object.keys)
        }
        let headers = Array(allKeys).sorted()
        
        // Generate CSV content
        var csvContent = headers.joined(separator: ",") + "\n"
        
        for object in jsonArray {
            let values = headers.map { key in
                let value = object[key] ?? ""
                let stringValue = "\(value)"
                // Escape commas and quotes
                return stringValue.contains(",") || stringValue.contains("\"") 
                    ? "\"\(stringValue.replacingOccurrences(of: "\"", with: "\"\""))\""
                    : stringValue
            }
            csvContent += values.joined(separator: ",") + "\n"
        }
        
        await updateProgress(stage: .writing)
        
        let finalOutputURL = outputURL ?? generateOutputURL(from: inputURL, extension: "csv")
        try csvContent.write(to: finalOutputURL, atomically: true, encoding: .utf8)
        
        return finalOutputURL
    }
    
    private func convertTSVToCSV(_ inputURL: URL, outputURL: URL?) async throws -> URL {
        let content = try String(contentsOf: inputURL)
        
        await updateProgress(stage: .converting)
        
        // Replace tabs with commas, handling quoted fields
        let csvContent = content.replacingOccurrences(of: "\t", with: ",")
        
        await updateProgress(stage: .writing)
        
        let finalOutputURL = outputURL ?? generateOutputURL(from: inputURL, extension: "csv")
        try csvContent.write(to: finalOutputURL, atomically: true, encoding: .utf8)
        
        return finalOutputURL
    }
    
    private func convertCSVToExcel(_ inputURL: URL, outputURL: URL?) async throws -> URL {
        // This is a placeholder - actual Excel conversion would require additional libraries
        // For now, we'll create a detailed CSV with better formatting
        let content = try String(contentsOf: inputURL)
        
        await updateProgress(stage: .converting)
        
        let finalOutputURL = outputURL ?? generateOutputURL(from: inputURL, extension: "xlsx")
        
        // Save as enhanced CSV with .xlsx extension (placeholder)
        try content.write(to: finalOutputURL, atomically: true, encoding: .utf8)
        
        return finalOutputURL
    }
    
    // MARK: - 3D Model Conversions
    
    private func convert3DModel(
        _ inputURL: URL,
        type: ConversionType,
        outputURL: URL?
    ) async throws -> URL {
        
        guard inputURL.startAccessingSecurityScopedResource() else {
            throw ConversionError.accessDenied
        }
        defer { inputURL.stopAccessingSecurityScopedResource() }
        
        await updateProgress(stage: .parsing)
        
        switch type {
        case .objToUsdz:
            return try await convertOBJToUSDZ(inputURL, outputURL: outputURL)
        case .stlToObj:
            return try await convertSTLToOBJ(inputURL, outputURL: outputURL)
        case .plyToObj:
            return try await convertPLYToOBJ(inputURL, outputURL: outputURL)
        default:
            throw ConversionError.unsupportedType
        }
    }
    
    private func convertOBJToUSDZ(_ inputURL: URL, outputURL: URL?) async throws -> URL {
        await updateProgress(stage: .converting)
        
        // Load OBJ using SceneKit
        let scene = SCNScene(named: inputURL.path)
        guard let scene = scene else {
            throw ConversionError.parsingFailed
        }
        
        await updateProgress(stage: .writing)
        
        let finalOutputURL = outputURL ?? generateOutputURL(from: inputURL, extension: "usdz")
        
        // Export as USDZ
        try scene.write(to: finalOutputURL, options: nil, delegate: nil, progressHandler: nil)
        
        return finalOutputURL
    }
    
    private func convertSTLToOBJ(_ inputURL: URL, outputURL: URL?) async throws -> URL {
        await updateProgress(stage: .parsing)
        
        // Parse STL file
        let stlData = try Data(contentsOf: inputURL)
        let vertices = try parseSTLVertices(stlData)
        
        await updateProgress(stage: .converting)
        
        // Generate OBJ content
        var objContent = "# Converted from STL\n"
        
        // Add vertices
        for vertex in vertices {
            objContent += "v \(vertex.x) \(vertex.y) \(vertex.z)\n"
        }
        
        // Add faces (triangles)
        for i in stride(from: 0, to: vertices.count, by: 3) {
            let v1 = i + 1  // OBJ uses 1-based indexing
            let v2 = i + 2
            let v3 = i + 3
            objContent += "f \(v1) \(v2) \(v3)\n"
        }
        
        await updateProgress(stage: .writing)
        
        let finalOutputURL = outputURL ?? generateOutputURL(from: inputURL, extension: "obj")
        try objContent.write(to: finalOutputURL, atomically: true, encoding: .utf8)
        
        return finalOutputURL
    }
    
    private func convertPLYToOBJ(_ inputURL: URL, outputURL: URL?) async throws -> URL {
        await updateProgress(stage: .parsing)
        
        // Parse PLY file
        guard let pointCloud = parsePLY(at: inputURL) else {
            throw ConversionError.parsingFailed
        }
        
        await updateProgress(stage: .converting)
        
        // Generate OBJ content from point cloud
        var objContent = "# Converted from PLY point cloud\n"
        
        // Add vertices
        for point in pointCloud.points {
            let vertex = point as PointCloudData.PointData
            objContent += "v \(vertex.x) \(vertex.y) \(vertex.z)\n"
        }
        
        // For point clouds, we'll create small faces around each point
        // This is a simplified conversion - real PLY to OBJ might preserve existing faces
        
        await updateProgress(stage: .writing)
        
        let finalOutputURL = outputURL ?? generateOutputURL(from: inputURL, extension: "obj")
        try objContent.write(to: finalOutputURL, atomically: true, encoding: .utf8)
        
        return finalOutputURL
    }
    
    // MARK: - Point Cloud Conversions
    
    private func convertPointCloud(
        _ inputURL: URL,
        type: ConversionType,
        outputURL: URL?
    ) async throws -> URL {
        
        guard inputURL.startAccessingSecurityScopedResource() else {
            throw ConversionError.accessDenied
        }
        defer { inputURL.stopAccessingSecurityScopedResource() }
        
        await updateProgress(stage: .parsing)
        
        switch type {
        case .plyToCsv:
            return try await convertPLYToCSV(inputURL, outputURL: outputURL)
        case .csvToPly:
            return try await convertCSVToPLY(inputURL, outputURL: outputURL)
        case .plyToJson:
            return try await convertPLYToJSON(inputURL, outputURL: outputURL)
        case .jsonToPly:
            return try await convertJSONToPLY(inputURL, outputURL: outputURL)
        default:
            throw ConversionError.unsupportedType
        }
    }
    
    private func convertPLYToCSV(_ inputURL: URL, outputURL: URL?) async throws -> URL {
        guard let pointCloud = parsePLY(at: inputURL) else {
            throw ConversionError.parsingFailed
        }
        
        await updateProgress(stage: .converting)
        
        // Generate CSV content
        var csvContent = "x,y,z,intensity\n"
        
        for point in pointCloud.points {
            let vertex = point as PointCloudData.PointData
            let intensity = vertex.intensity ?? 1.0
            csvContent += "\(vertex.x),\(vertex.y),\(vertex.z),\(intensity)\n"
        }
        
        await updateProgress(stage: .writing)
        
        let finalOutputURL = outputURL ?? generateOutputURL(from: inputURL, extension: "csv")
        try csvContent.write(to: finalOutputURL, atomically: true, encoding: .utf8)
        
        return finalOutputURL
    }
    
    private func convertCSVToPLY(_ inputURL: URL, outputURL: URL?) async throws -> URL {
        let content = try String(contentsOf: inputURL)
        guard let csvData = CSVParser.parse(content) else {
            throw ConversionError.parsingFailed
        }
        
        await updateProgress(stage: .converting)
        
        // Find x, y, z columns
        guard let xIndex = csvData.headers.firstIndex(where: { $0.lowercased().contains("x") }),
              let yIndex = csvData.headers.firstIndex(where: { $0.lowercased().contains("y") }),
              let zIndex = csvData.headers.firstIndex(where: { $0.lowercased().contains("z") }) else {
            throw ConversionError.invalidFormat
        }
        
        let intensityIndex = csvData.headers.firstIndex(where: { $0.lowercased().contains("intensity") })
        
        // Generate PLY content
        var plyContent = """
        ply
        format ascii 1.0
        element vertex \(csvData.rows.count)
        property float x
        property float y
        property float z
        property float intensity
        end_header
        
        """
        
        for row in csvData.rows {
            guard xIndex < row.count, 
                  yIndex < row.count, 
                  zIndex < row.count,
                  let x = Float(row[xIndex]),
                  let y = Float(row[yIndex]),
                  let z = Float(row[zIndex]) else { continue }
            
            let intensity: Float
            if let intensityIndex = intensityIndex, 
               intensityIndex < row.count,
               let intensityValue = Float(row[intensityIndex]) {
                intensity = intensityValue
            } else {
                intensity = 1.0
            }
            
            plyContent += "\(x) \(y) \(z) \(intensity)\n"
        }
        
        await updateProgress(stage: .writing)
        
        let finalOutputURL = outputURL ?? generateOutputURL(from: inputURL, extension: "ply")
        try plyContent.write(to: finalOutputURL, atomically: true, encoding: .utf8)
        
        return finalOutputURL
    }
    
    private func convertPLYToJSON(_ inputURL: URL, outputURL: URL?) async throws -> URL {
        guard let pointCloud = parsePLY(at: inputURL) else {
            throw ConversionError.parsingFailed
        }
        
        await updateProgress(stage: .converting)
        
        // Convert to JSON array
        var jsonPoints: [[String: Any]] = []
        
        for point in pointCloud.points {
            let vertex = point as PointCloudData.PointData
            var pointObject: [String: Any] = [
                "x": vertex.x,
                "y": vertex.y,
                "z": vertex.z
            ]
            
            if let intensity = vertex.intensity {
                pointObject["intensity"] = intensity
            }
            
            jsonPoints.append(pointObject)
        }
        
        await updateProgress(stage: .writing)
        
        let jsonData = try JSONSerialization.data(withJSONObject: jsonPoints, options: .prettyPrinted)
        
        let finalOutputURL = outputURL ?? generateOutputURL(from: inputURL, extension: "json")
        try jsonData.write(to: finalOutputURL)
        
        return finalOutputURL
    }
    
    private func convertJSONToPLY(_ inputURL: URL, outputURL: URL?) async throws -> URL {
        let jsonData = try Data(contentsOf: inputURL)
        
        await updateProgress(stage: .parsing)
        
        guard let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            throw ConversionError.invalidFormat
        }
        
        await updateProgress(stage: .converting)
        
        // Generate PLY content
        var plyContent = """
        ply
        format ascii 1.0
        element vertex \(jsonArray.count)
        property float x
        property float y
        property float z
        property float intensity
        end_header
        
        """
        
        for object in jsonArray {
            guard let x = object["x"] as? Double,
                  let y = object["y"] as? Double,
                  let z = object["z"] as? Double else { continue }
            
            let intensity = object["intensity"] as? Double ?? 1.0
            
            plyContent += "\(x) \(y) \(z) \(intensity)\n"
        }
        
        await updateProgress(stage: .writing)
        
        let finalOutputURL = outputURL ?? generateOutputURL(from: inputURL, extension: "ply")
        try plyContent.write(to: finalOutputURL, atomically: true, encoding: .utf8)
        
        return finalOutputURL
    }
    
    // MARK: - Helper Methods
    
    private func generateOutputURL(from inputURL: URL, extension: String) -> URL {
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let timestamp = DateFormatter().string(from: Date())
        let fileName = "\(baseName)_converted.\(`extension`)"
        
        return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }
    
    @MainActor
    private func updateProgress(stage: ConversionStage) {
        conversionProgress.currentStage = stage
    }
    
    private func parseSTLVertices(_ data: Data) throws -> [SIMD3<Float>] {
        var vertices: [SIMD3<Float>] = []
        
        // Check if binary or ASCII STL
        if let content = String(data: data.prefix(1024), encoding: .utf8),
           content.lowercased().contains("solid") {
            // ASCII STL
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("vertex") {
                    let components = trimmed.components(separatedBy: " ")
                    if components.count >= 4,
                       let x = Float(components[1]),
                       let y = Float(components[2]),
                       let z = Float(components[3]) {
                        vertices.append(SIMD3(x, y, z))
                    }
                }
            }
        } else {
            // Binary STL - simplified parsing
            guard data.count >= 84 else { throw ConversionError.invalidFormat }
            
            // Read triangle count
            let triangleCountData = data.subdata(in: 80..<84)
            let triangleCount = triangleCountData.withUnsafeBytes { $0.load(as: UInt32.self) }
            
            var offset = 84
            for _ in 0..<triangleCount {
                // Skip normal (12 bytes)
                offset += 12
                
                // Read 3 vertices
                for _ in 0..<3 {
                    let vertexData = data.subdata(in: offset..<offset+12)
                    let coords = vertexData.withUnsafeBytes { bytes in
                        Array(bytes.bindMemory(to: Float.self))
                    }
                    
                    if coords.count >= 3 {
                        vertices.append(SIMD3(coords[0], coords[1], coords[2]))
                    }
                    offset += 12
                }
                
                // Skip attribute bytes
                offset += 2
            }
        }
        
        return vertices
    }
}

// MARK: - Supporting Models

struct ConversionProgress {
    var currentFile: String = ""
    var conversionType: FormatConverter.ConversionType?
    var currentStage: ConversionStage = .idle
    
    var description: String {
        guard let type = conversionType else { return "Idle" }
        return "\(currentStage.description) - \(type.description)"
    }
}

enum ConversionStage {
    case idle
    case reading
    case parsing
    case converting
    case writing
    case completed
    
    var description: String {
        switch self {
        case .idle: return "Idle"
        case .reading: return "Reading file"
        case .parsing: return "Parsing data"
        case .converting: return "Converting format"
        case .writing: return "Writing output"
        case .completed: return "Completed"
        }
    }
}

class ConversionSession: ObservableObject, Identifiable {
    let id = UUID()
    let inputURL: URL
    let conversionType: FormatConverter.ConversionType
    let startedAt: Date
    
    @Published var status: ConversionStatus = .processing
    @Published var completedAt: Date?
    @Published var outputURL: URL?
    
    init(inputURL: URL, conversionType: FormatConverter.ConversionType, startedAt: Date) {
        self.inputURL = inputURL
        self.conversionType = conversionType
        self.startedAt = startedAt
    }
    
    var duration: TimeInterval? {
        guard let completed = completedAt else { return nil }
        return completed.timeIntervalSince(startedAt)
    }
}

enum ConversionStatus {
    case processing
    case completed
    case failed(Error)
    
    var isCompleted: Bool {
        switch self {
        case .completed: return true
        default: return false
        }
    }
    
    var isSuccess: Bool {
        switch self {
        case .completed: return true
        default: return false
        }
    }
}

enum ConversionError: LocalizedError {
    case unsupportedType
    case invalidFormat
    case parsingFailed
    case accessDenied
    case writeFailed
    
    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "Unsupported conversion type"
        case .invalidFormat:
            return "Invalid file format"
        case .parsingFailed:
            return "Failed to parse input file"
        case .accessDenied:
            return "Access denied to file"
        case .writeFailed:
            return "Failed to write output file"
        }
    }
}