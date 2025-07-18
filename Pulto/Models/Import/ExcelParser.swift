//
//  ExcelParser.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/18/25.
//  Copyright © 2025 Apple. All rights reserved.
//


//
//  ExcelParser.swift
//  Pulto3
//
//  Excel (.xlsx) file parser for multi-sheet independent import
//

import Foundation
import CoreXLSX

// Note: This assumes you'll add the CoreXLSX package dependency
// If not using CoreXLSX, you can use alternative approaches

class ExcelParser {
    
    struct ExcelWorkbook {
        let sheets: [ExcelSheet]
        let metadata: WorkbookMetadata
    }
    
    struct ExcelSheet {
        let name: String
        let headers: [String]
        let rows: [[String]]
        let columnTypes: [ColumnType]
        let hasHeaders: Bool
        let rowCount: Int
        let columnCount: Int
    }
    
    struct WorkbookMetadata {
        let author: String?
        let createdDate: Date?
        let modifiedDate: Date?
        let application: String?
    }
    
    // MARK: - Public Methods
    
    static func parseExcelFile(at url: URL) throws -> ExcelWorkbook {
        // For production, use CoreXLSX or similar library
        // This is a demonstration of the structure
        
        #if canImport(CoreXLSX)
        return try parseWithCoreXLSX(url: url)
        #else
        // Fallback implementation or mock data for demonstration
        return try parseWithBuiltInParser(url: url)
        #endif
    }
    
    // MARK: - CoreXLSX Implementation
    
    #if canImport(CoreXLSX)
    private static func parseWithCoreXLSX(url: URL) throws -> ExcelWorkbook {
        guard let file = XLSXFile(filepath: url.path) else {
            throw FileAnalysisError.parsingError("Cannot open Excel file")
        }
        
        var sheets: [ExcelSheet] = []
        
        // Parse each worksheet
        for wbk in try file.parseWorkbooks() {
            for (name, path) in try file.parseWorksheetPathsAndNames(workbook: wbk) {
                if let worksheet = try file.parseWorksheet(at: path) {
                    let sheet = try parseWorksheet(worksheet, name: name)
                    sheets.append(sheet)
                }
            }
        }
        
        // Extract metadata
        let metadata = extractMetadata(from: file)
        
        return ExcelWorkbook(sheets: sheets, metadata: metadata)
    }
    
    private static func parseWorksheet(_ worksheet: Worksheet, name: String) throws -> ExcelSheet {
        let data = worksheet.data
        var headers: [String] = []
        var rows: [[String]] = []
        var hasHeaders = false
        
        // Get dimensions
        let maxRow = data?.rows.map { $0.reference }.max() ?? 0
        let maxCol = data?.rows.flatMap { $0.cells }.map { $0.reference.column }.max() ?? 0
        
        guard let data = data, !data.rows.isEmpty else {
            return ExcelSheet(
                name: name,
                headers: [],
                rows: [],
                columnTypes: [],
                hasHeaders: false,
                rowCount: 0,
                columnCount: 0
            )
        }
        
        // Extract headers (first row)
        if let firstRow = data.rows.first {
            headers = extractRowValues(firstRow, maxColumns: maxCol)
            hasHeaders = headers.allSatisfy { !$0.isEmpty && Double($0) == nil }
        }
        
        // Extract data rows
        let startRow = hasHeaders ? 1 : 0
        for rowIndex in startRow..<data.rows.count {
            if rowIndex < data.rows.count {
                let row = data.rows[rowIndex]
                let values = extractRowValues(row, maxColumns: maxCol)
                rows.append(values)
            }
        }
        
        // Infer column types
        let columnTypes = inferColumnTypes(from: rows, columnCount: maxCol)
        
        return ExcelSheet(
            name: name,
            headers: hasHeaders ? headers : generateDefaultHeaders(count: maxCol),
            rows: rows,
            columnTypes: columnTypes,
            hasHeaders: hasHeaders,
            rowCount: rows.count,
            columnCount: maxCol
        )
    }
    
    private static func extractRowValues(_ row: Row, maxColumns: Int) -> [String] {
        var values = Array(repeating: "", count: maxColumns)
        
        for cell in row.cells {
            let colIndex = cell.reference.column.value - 1
            if colIndex < maxColumns {
                values[colIndex] = cell.stringValue(SharedStrings()) ?? ""
            }
        }
        
        return values
    }
    #endif
    
    // MARK: - Built-in Parser (Fallback)
    
    private static func parseWithBuiltInParser(url: URL) throws -> ExcelWorkbook {
        // This is a simplified parser that reads XLSX as a ZIP file
        // and extracts basic information
        
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        do {
            // Create temporary directory
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            
            // Unzip XLSX file
            try fileManager.unzipItem(at: url, to: tempDirectory)
            
            // Parse sheets
            let sheets = try parseSheets(from: tempDirectory)
            
            // Clean up
            try? fileManager.removeItem(at: tempDirectory)
            
            return ExcelWorkbook(
                sheets: sheets,
                metadata: WorkbookMetadata(
                    author: nil,
                    createdDate: nil,
                    modifiedDate: nil,
                    application: nil
                )
            )
            
        } catch {
            // Clean up on error
            try? fileManager.removeItem(at: tempDirectory)
            throw error
        }
    }
    
    private static func parseSheets(from directory: URL) throws -> [ExcelSheet] {
        var sheets: [ExcelSheet] = []
        
        // Look for worksheet files
        let worksheetsDir = directory.appendingPathComponent("xl/worksheets")
        let sheetFiles = try FileManager.default.contentsOfDirectory(
            at: worksheetsDir,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "xml" }
        
        for (index, sheetFile) in sheetFiles.enumerated() {
            let sheetData = try parseSheetXML(at: sheetFile)
            let sheet = ExcelSheet(
                name: "Sheet\(index + 1)",
                headers: sheetData.headers,
                rows: sheetData.rows,
                columnTypes: inferColumnTypes(from: sheetData.rows, columnCount: sheetData.headers.count),
                hasHeaders: true,
                rowCount: sheetData.rows.count,
                columnCount: sheetData.headers.count
            )
            sheets.append(sheet)
        }
        
        return sheets
    }
    
    private static func parseSheetXML(at url: URL) throws -> (headers: [String], rows: [[String]]) {
        let data = try Data(contentsOf: url)
        let parser = XMLParser(data: data)
        let delegate = SheetXMLParserDelegate()
        parser.delegate = delegate
        
        guard parser.parse() else {
            throw FileAnalysisError.parsingError("Failed to parse sheet XML")
        }
        
        return (delegate.headers, delegate.rows)
    }
    
    // MARK: - Helper Methods
    
    private static func inferColumnTypes(from rows: [[String]], columnCount: Int) -> [ColumnType] {
        var types = Array(repeating: ColumnType.unknown, count: columnCount)
        
        for colIndex in 0..<columnCount {
            var numericCount = 0
            var dateCount = 0
            var booleanCount = 0
            var emptyCount = 0
            
            for row in rows {
                guard colIndex < row.count else { continue }
                let value = row[colIndex]
                
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
                types[colIndex] = .unknown
                continue
            }
            
            // Determine type based on majority
            if Double(numericCount) / Double(totalNonEmpty) > 0.8 {
                types[colIndex] = .numeric
            } else if Double(dateCount) / Double(totalNonEmpty) > 0.8 {
                types[colIndex] = .date
            } else if Double(booleanCount) / Double(totalNonEmpty) > 0.8 {
                types[colIndex] = .boolean
            } else {
                types[colIndex] = .categorical
            }
        }
        
        return types
    }
    
    private static func isDate(_ value: String) -> Bool {
        let datePatterns = [
            #"^\d{4}-\d{2}-\d{2}$"#,
            #"^\d{2}/\d{2}/\d{4}$"#,
            #"^\d{2}-\d{2}-\d{4}$"#
        ]
        
        return datePatterns.contains { pattern in
            value.range(of: pattern, options: .regularExpression) != nil
        }
    }
    
    private static func isBoolean(_ value: String) -> Bool {
        let booleanValues = ["true", "false", "yes", "no", "1", "0", "t", "f", "y", "n"]
        return booleanValues.contains(value.lowercased())
    }
    
    private static func generateDefaultHeaders(count: Int) -> [String] {
        return (0..<count).map { "Column \($0 + 1)" }
    }
    
    #if canImport(CoreXLSX)
    private static func extractMetadata(from file: XLSXFile) -> WorkbookMetadata {
        // Extract metadata from CoreProperties if available
        // This would require parsing the docProps/core.xml file
        return WorkbookMetadata(
            author: nil,
            createdDate: nil,
            modifiedDate: nil,
            application: nil
        )
    }
    #endif
}

// MARK: - XML Parser Delegate

private class SheetXMLParserDelegate: NSObject, XMLParserDelegate {
    var headers: [String] = []
    var rows: [[String]] = []
    private var currentRow: [String] = []
    private var currentValue = ""
    private var isInCell = false
    private var currentRowIndex = 0
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "row" {
            currentRow = []
            if let r = attributeDict["r"], let rowNum = Int(r) {
                currentRowIndex = rowNum - 1
            }
        } else if elementName == "c" {
            isInCell = true
            currentValue = ""
        } else if elementName == "v" && isInCell {
            currentValue = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInCell {
            currentValue += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "c" {
            currentRow.append(currentValue)
            isInCell = false
            currentValue = ""
        } else if elementName == "row" {
            if currentRowIndex == 0 && headers.isEmpty {
                headers = currentRow
            } else {
                rows.append(currentRow)
            }
            currentRow = []
        }
    }
}

// MARK: - FileManager Extension for XLSX Unzipping

extension FileManager {
    func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        // Use a system call to unzip or implement using Compression framework
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        task.arguments = ["-q", sourceURL.path, "-d", destinationURL.path]
        
        try task.run()
        task.waitUntilExit()
        
        guard task.terminationStatus == 0 else {
            throw FileAnalysisError.parsingError("Failed to unzip Excel file")
        }
    }
}

// MARK: - Excel Sheet to Window Converter

extension ExcelParser {
    
    /// Convert an Excel sheet to appropriate window data
    static func convertSheetToWindowData(_ sheet: ExcelSheet) -> DataFrameData {
        let dtypes = Dictionary(uniqueKeysWithValues: zip(
            sheet.headers,
            sheet.columnTypes.map { type -> String in
                switch type {
                case .numeric: return "float"
                case .categorical: return "string"
                case .date: return "datetime"
                case .boolean: return "bool"
                case .unknown: return "string"
                }
            }
        ))
        
        return DataFrameData(
            columns: sheet.headers,
            rows: sheet.rows,
            dtypes: dtypes,
            metadata: [
                "source": "excel",
                "sheetName": sheet.name,
                "hasHeaders": sheet.hasHeaders
            ]
        )
    }
    
    /// Analyze sheet for visualization suggestions
    static func analyzeSheetForVisualization(_ sheet: ExcelSheet) -> DataAnalysisResult {
        // Check for coordinate columns
        let coordinateColumns = detectCoordinateColumns(in: sheet)
        let timeColumns = detectTimeColumns(in: sheet)
        
        // Determine data type
        let dataType: DataType
        if coordinateColumns.count >= 2 {
            dataType = .tabularWithCoordinates
        } else if !timeColumns.isEmpty {
            dataType = .timeSeries
        } else {
            dataType = .tabular
        }
        
        // Detect patterns
        var patterns: Set<DataPattern> = []
        if hasHighCardinality(in: sheet) {
            patterns.insert(.highCardinality)
        }
        if hasSparseData(in: sheet) {
            patterns.insert(.sparseData)
        }
        
        return DataAnalysisResult(
            dataType: dataType,
            structure: TabularStructure(
                headers: sheet.headers,
                columnTypes: Dictionary(uniqueKeysWithValues: zip(sheet.headers, sheet.columnTypes)),
                rowCount: sheet.rowCount,
                patterns: patterns,
                coordinateColumns: coordinateColumns,
                timeColumns: timeColumns
            ),
            metadata: [
                "sheetName": sheet.name,
                "format": "xlsx"
            ],
            suggestions: []
        )
    }
    
    private static func detectCoordinateColumns(in sheet: ExcelSheet) -> [String] {
        let coordinatePatterns = [
            ["x", "y", "z"],
            ["lon", "lat", "alt"],
            ["longitude", "latitude", "altitude"],
            ["easting", "northing", "elevation"]
        ]
        
        for pattern in coordinatePatterns {
            let matches = pattern.compactMap { coord in
                sheet.headers.first { header in
                    let h = header.lowercased()
                    let colIndex = sheet.headers.firstIndex(of: header) ?? 0
                    return (h == coord || h.contains(coord)) && 
                           colIndex < sheet.columnTypes.count &&
                           sheet.columnTypes[colIndex] == .numeric
                }
            }
            
            if matches.count >= 2 {
                return matches
            }
        }
        
        return []
    }
    
    private static func detectTimeColumns(in sheet: ExcelSheet) -> [String] {
        return sheet.headers.enumerated().compactMap { index, header in
            let isTimeColumn = sheet.columnTypes[index] == .date ||
                              header.lowercased().contains("time") ||
                              header.lowercased().contains("date") ||
                              header.lowercased().contains("timestamp")
            return isTimeColumn ? header : nil
        }
    }
    
    private static func hasHighCardinality(in sheet: ExcelSheet) -> Bool {
        for (index, columnType) in sheet.columnTypes.enumerated() {
            if columnType == .categorical {
                let uniqueValues = Set(sheet.rows.compactMap { row in
                    index < row.count ? row[index] : nil
                }.filter { !$0.isEmpty })
                
                if uniqueValues.count > sheet.rowCount / 2 {
                    return true
                }
            }
        }
        return false
    }
    
    private static func hasSparseData(in sheet: ExcelSheet) -> Bool {
        let totalCells = sheet.rowCount * sheet.columnCount
        guard totalCells > 0 else { return false }
        
        let emptyCells = sheet.rows.reduce(0) { sum, row in
            sum + row.filter { $0.isEmpty }.count
        }
        
        return Double(emptyCells) / Double(totalCells) > 0.1
    }
}
