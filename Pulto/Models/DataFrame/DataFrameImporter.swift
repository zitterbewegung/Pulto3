//
//  DataFrameImporter.swift
//  Pulto
//
//  Enhanced CSV/TSV importer with comprehensive format support
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI

// MARK: - DataFrame Import Error

enum DataFrameImportError: LocalizedError {
    case accessDenied
    case fileNotFound
    case invalidFormat
    case emptyFile
    case corruptedData(String)
    case unsupportedFormat(String)
    case memoryLimit
    case cancelled
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access denied to the selected file"
        case .fileNotFound:
            return "File not found"
        case .invalidFormat:
            return "Invalid file format"
        case .emptyFile:
            return "The file is empty"
        case .corruptedData(let message):
            return "Corrupted data: \(message)"
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format)"
        case .memoryLimit:
            return "File too large - exceeds memory limit"
        case .cancelled:
            return "Import was cancelled"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Import Format

enum ImportFormat: Hashable {
    case csv(delimiter: String)
    case json
    case excel
    
    var displayName: String {
        switch self {
        case .csv(let delimiter):
            return "CSV (\(delimiter))"
        case .json:
            return "JSON"
        case .excel:
            return "Excel"
        }
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        switch self {
        case .csv(let delimiter):
            hasher.combine("csv")
            hasher.combine(delimiter)
        case .json:
            hasher.combine("json")
        case .excel:
            hasher.combine("excel")
        }
    }
    
    static func == (lhs: ImportFormat, rhs: ImportFormat) -> Bool {
        switch (lhs, rhs) {
        case (.csv(let lhsDelimiter), .csv(let rhsDelimiter)):
            return lhsDelimiter == rhsDelimiter
        case (.json, .json), (.excel, .excel):
            return true
        default:
            return false
        }
    }
}

// MARK: - File Format Importer Protocol

protocol FileFormatImporter {
    func importData(from url: URL, progressCallback: @escaping (Double, String) -> Void) async throws -> DataFrameModel
    func importFromText(_ text: String, progressCallback: @escaping (Double, String) -> Void) async throws -> DataFrameModel
}

// MARK: - CSV Importer

class CSVImporter: FileFormatImporter {
    private let delimiter: String
    private let maxFileSize: Int = 100 * 1024 * 1024 // 100MB limit
    private let chunkSize = 10000 // Process in chunks of 10k rows
    
    init(delimiter: String) {
        self.delimiter = delimiter
    }
    
    func importData(from url: URL, progressCallback: @escaping (Double, String) -> Void) async throws -> DataFrameModel {
        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int ?? 0
        
        if fileSize > maxFileSize {
            throw DataFrameImportError.memoryLimit
        }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        return try await importFromText(content, progressCallback: progressCallback)
    }
    
    func importFromText(_ text: String, progressCallback: @escaping (Double, String) -> Void) async throws -> DataFrameModel {
        guard !text.isEmpty else {
            throw DataFrameImportError.emptyFile
        }
        
        await progressCallback(0.1, "Parsing CSV structure...")
        
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        guard !lines.isEmpty else {
            throw DataFrameImportError.emptyFile
        }
        
        await progressCallback(0.2, "Processing headers...")
        
        // Parse headers
        let headers = parseCSVLine(lines[0])
        guard !headers.isEmpty else {
            throw DataFrameImportError.invalidFormat
        }
        
        await progressCallback(0.3, "Processing data rows...")
        
        // Parse data rows in chunks
        var allRows: [[String]] = []
        let dataLines = Array(lines.dropFirst()) // Skip header
        
        for (index, line) in dataLines.enumerated() {
            let row = parseCSVLine(line)
            allRows.append(row)
            
            // Update progress every 1000 rows
            if index % 1000 == 0 {
                let progress = 0.3 + (Double(index) / Double(dataLines.count)) * 0.5
                await progressCallback(progress, "Processed \(index + 1) of \(dataLines.count) rows...")
            }
        }
        
        await progressCallback(0.8, "Detecting data types...")
        
        // Create DataFrame
        let dataFrame = DataFrameModel(name: "Imported CSV")
        
        // Create columns with type inference
        for (columnIndex, header) in headers.enumerated() {
            let columnValues = allRows.map { row in
                columnIndex < row.count ? row[columnIndex] : ""
            }
            
            let dataType = DataTypeConverter.inferType(from: columnValues)
            let column = DataColumn(name: header, dataType: dataType, values: columnValues)
            dataFrame.columns.append(column)
        }
        
        // Update metadata
        dataFrame.metadata.source = "CSV Import"
        dataFrame.metadata.delimiter = delimiter
        dataFrame.metadata.hasHeaders = true
        dataFrame.metadata.encoding = "UTF-8"
        
        await progressCallback(1.0, "Import completed")
        
        return dataFrame
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                if inQuotes && i < line.index(before: line.endIndex) && line[line.index(after: i)] == "\"" {
                    // Escaped quote
                    current.append("\"")
                    i = line.index(after: i) // Skip next quote
                } else {
                    inQuotes.toggle()
                }
            } else if String(char) == delimiter && !inQuotes {
                result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(char)
            }
            
            i = line.index(after: i)
        }
        
        result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return result
    }
}

// MARK: - JSON Importer

class JSONImporter: FileFormatImporter {
    func importData(from url: URL, progressCallback: @escaping (Double, String) -> Void) async throws -> DataFrameModel {
        let data = try Data(contentsOf: url)
        let jsonString = String(data: data, encoding: .utf8) ?? ""
        return try await importFromText(jsonString, progressCallback: progressCallback)
    }
    
    func importFromText(_ text: String, progressCallback: @escaping (Double, String) -> Void) async throws -> DataFrameModel {
        guard let data = text.data(using: .utf8) else {
            throw DataFrameImportError.invalidFormat
        }
        
        await progressCallback(0.2, "Parsing JSON...")
        
        let json = try JSONSerialization.jsonObject(with: data)
        
        await progressCallback(0.5, "Converting to DataFrame...")
        
        if let array = json as? [[String: Any]] {
            return try await createDataFrameFromArray(array, progressCallback: progressCallback)
        } else if let dictionary = json as? [String: Any] {
            return try await createDataFrameFromDictionary(dictionary, progressCallback: progressCallback)
        } else {
            throw DataFrameImportError.invalidFormat
        }
    }
    
    private func createDataFrameFromArray(_ array: [[String: Any]], progressCallback: @escaping (Double, String) -> Void) async throws -> DataFrameModel {
        guard !array.isEmpty else {
            throw DataFrameImportError.emptyFile
        }
        
        // Get all possible keys
        let allKeys = Set(array.flatMap { $0.keys })
        let headers = Array(allKeys).sorted()
        
        await progressCallback(0.7, "Processing JSON records...")
        
        // Create rows
        var rows: [[String]] = []
        for (index, record) in array.enumerated() {
            let row = headers.map { key in
                if let value = record[key] {
                    return String(describing: value)
                } else {
                    return ""
                }
            }
            rows.append(row)
            
            if index % 100 == 0 {
                let progress = 0.7 + (Double(index) / Double(array.count)) * 0.2
                await progressCallback(progress, "Processed \(index + 1) of \(array.count) records...")
            }
        }
        
        await progressCallback(0.9, "Creating DataFrame...")
        
        let dataFrame = DataFrameModel(name: "Imported JSON")
        
        for (columnIndex, header) in headers.enumerated() {
            let columnValues = rows.map { row in
                columnIndex < row.count ? row[columnIndex] : ""
            }
            
            let dataType = DataTypeConverter.inferType(from: columnValues)
            let column = DataColumn(name: header, dataType: dataType, values: columnValues)
            dataFrame.columns.append(column)
        }
        
        dataFrame.metadata.source = "JSON Import"
        
        return dataFrame
    }
    
    private func createDataFrameFromDictionary(_ dictionary: [String: Any], progressCallback: @escaping (Double, String) -> Void) async throws -> DataFrameModel {
        // Convert dictionary to key-value pairs
        let dataFrame = DataFrameModel(name: "Imported JSON Dictionary")
        
        let keyColumn = DataColumn(name: "Key", dataType: .string, values: Array(dictionary.keys))
        let valueColumn = DataColumn(name: "Value", dataType: .string, values: dictionary.values.map { String(describing: $0) })
        
        dataFrame.columns.append(keyColumn)
        dataFrame.columns.append(valueColumn)
        
        dataFrame.metadata.source = "JSON Import"
        
        return dataFrame
    }
}

// MARK: - Excel Importer (Placeholder)

class ExcelImporter: FileFormatImporter {
    func importData(from url: URL, progressCallback: @escaping (Double, String) -> Void) async throws -> DataFrameModel {
        // This would require a third-party library like ClosedXML or similar
        // For now, throw unsupported format error
        throw DataFrameImportError.unsupportedFormat("Excel import not yet implemented")
    }
    
    func importFromText(_ text: String, progressCallback: @escaping (Double, String) -> Void) async throws -> DataFrameModel {
        throw DataFrameImportError.unsupportedFormat("Excel import from text not supported")
    }
}

// MARK: - Import Manager

class DataFrameImporter: ObservableObject {
    @Published var isImporting = false
    @Published var importProgress: Double = 0.0
    @Published var importStatus = ""
    @Published var lastError: DataFrameImportError?
    
    private var importTask: Task<Void, Never>?
    
    // MARK: - Public Import Methods
    
    func importFromFile(url: URL) async throws -> DataFrameModel {
        guard url.startAccessingSecurityScopedResource() else {
            throw DataFrameImportError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        await MainActor.run {
            isImporting = true
            importProgress = 0.0
            importStatus = "Reading file..."
        }
        
        let fileExtension = url.pathExtension.lowercased()
        let importer = getImporter(for: fileExtension)
        
        do {
            let dataFrame = try await importer.importData(from: url, progressCallback: { progress, status in
                Task { @MainActor in
                    self.importProgress = progress
                    self.importStatus = status
                }
            })
            
            await MainActor.run {
                isImporting = false
                importProgress = 1.0
                importStatus = "Import completed"
            }
            
            return dataFrame
        } catch {
            await MainActor.run {
                isImporting = false
                lastError = error as? DataFrameImportError ?? DataFrameImportError.unknown(error.localizedDescription)
            }
            throw error
        }
    }
    
    func importFromText(_ text: String, format: ImportFormat) async throws -> DataFrameModel {
        await MainActor.run {
            isImporting = true
            importProgress = 0.0
            importStatus = "Parsing text..."
        }
        
        let importer = getImporter(for: format)
        
        do {
            let dataFrame = try await importer.importFromText(text, progressCallback: { progress, status in
                Task { @MainActor in
                    self.importProgress = progress
                    self.importStatus = status
                }
            })
            
            await MainActor.run {
                isImporting = false
                importProgress = 1.0
                importStatus = "Import completed"
            }
            
            return dataFrame
        } catch {
            await MainActor.run {
                isImporting = false
                lastError = error as? DataFrameImportError ?? DataFrameImportError.unknown(error.localizedDescription)
            }
            throw error
        }
    }
    
    func cancelImport() {
        importTask?.cancel()
        isImporting = false
        importStatus = "Import cancelled"
    }
    
    // MARK: - Private Methods
    
    private func getImporter(for fileExtension: String) -> FileFormatImporter {
        switch fileExtension.lowercased() {
        case "csv":
            return CSVImporter(delimiter: ",")
        case "tsv", "tab":
            return CSVImporter(delimiter: "\t")
        case "json":
            return JSONImporter()
        case "xlsx", "xls":
            return ExcelImporter()
        default:
            return CSVImporter(delimiter: ",") // Default fallback
        }
    }
    
    private func getImporter(for format: ImportFormat) -> FileFormatImporter {
        switch format {
        case .csv(let delimiter):
            return CSVImporter(delimiter: delimiter)
        case .json:
            return JSONImporter()
        case .excel:
            return ExcelImporter()
        }
    }
}

// MARK: - Import Configuration

struct ImportConfiguration {
    var hasHeaders: Bool = true
    var delimiter: String = ","
    var encoding: String.Encoding = .utf8
    var skipRows: Int = 0
    var maxRows: Int?
    var selectedColumns: [String]?
    var dateFormat: String?
    var decimalSeparator: String = "."
    var thousandsSeparator: String?
    var nullValues: [String] = ["", "null", "NULL", "na", "NA", "n/a", "N/A"]
    var skipBlankLines: Bool = true
    var trimWhitespace: Bool = true
}

// MARK: - Sample Data Generator

struct SampleDataGenerator {
    static func generateSalesData() -> DataFrameModel {
        let dataFrame = DataFrameModel(name: "Sample Sales Data")
        
        let products = ["iPhone 15", "MacBook Pro", "iPad Air", "Apple Watch", "AirPods Pro", "Mac Studio", "iPad Pro", "iMac"]
        let regions = ["North America", "Europe", "Asia", "South America", "Africa", "Oceania"]
        let quarters = ["Q1", "Q2", "Q3", "Q4"]
        
        var productData: [String] = []
        var salesData: [String] = []
        var revenueData: [String] = []
        var regionData: [String] = []
        var quarterData: [String] = []
        
        for _ in 0..<200 {
            productData.append(products.randomElement()!)
            salesData.append(String(Int.random(in: 100...5000)))
            revenueData.append(String(Double.random(in: 10000...500000)))
            regionData.append(regions.randomElement()!)
            quarterData.append(quarters.randomElement()!)
        }
        
        dataFrame.columns = [
            DataColumn(name: "Product", dataType: .categorical, values: productData),
            DataColumn(name: "Sales", dataType: .integer, values: salesData),
            DataColumn(name: "Revenue", dataType: .double, values: revenueData),
            DataColumn(name: "Region", dataType: .categorical, values: regionData),
            DataColumn(name: "Quarter", dataType: .categorical, values: quarterData)
        ]
        
        dataFrame.metadata.source = "Sample Data Generator"
        
        return dataFrame
    }
    
    static func generateWeatherData() -> DataFrameModel {
        let dataFrame = DataFrameModel(name: "Sample Weather Data")
        
        let cities = ["New York", "London", "Tokyo", "Sydney", "São Paulo", "Dubai", "Mumbai", "Toronto"]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var cityData: [String] = []
        var dateData: [String] = []
        var temperatureData: [String] = []
        var humidityData: [String] = []
        var precipitationData: [String] = []
        
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -365, to: Date())!
        
        for i in 0..<365 {
            let date = calendar.date(byAdding: .day, value: i, to: startDate)!
            
            for city in cities {
                cityData.append(city)
                dateData.append(formatter.string(from: date))
                temperatureData.append(String(format: "%.1f", Double.random(in: -10...40)))
                humidityData.append(String(Int.random(in: 20...90)))
                precipitationData.append(String(format: "%.1f", Double.random(in: 0...50)))
            }
        }
        
        dataFrame.columns = [
            DataColumn(name: "City", dataType: .categorical, values: cityData),
            DataColumn(name: "Date", dataType: .date, values: dateData),
            DataColumn(name: "Temperature", dataType: .double, values: temperatureData),
            DataColumn(name: "Humidity", dataType: .integer, values: humidityData),
            DataColumn(name: "Precipitation", dataType: .double, values: precipitationData)
        ]
        
        dataFrame.metadata.source = "Sample Data Generator"
        
        return dataFrame
    }
}