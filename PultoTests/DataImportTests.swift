//
//  DataImportTests.swift
//  PultoTests
//
//  Created by AI Assistant on 1/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import XCTest
@testable import Pulto

final class DataImportTests: XCTestCase {
    
    // MARK: - Basic CSV Import Tests
    
    func testCSVImport_BasicWithHeaders() throws {
        let csvText = """
        Name,Age,City
        Alice,28,New York
        Bob,35,San Francisco
        Charlie,42,Austin
        """
        
        let result = try parseTestCSV(csvText, hasHeader: true)
        
        XCTAssertEqual(result.columns, ["Name", "Age", "City"])
        XCTAssertEqual(result.rows.count, 3)
        XCTAssertEqual(result.rows[0], ["Alice", "28", "New York"])
        XCTAssertEqual(result.rows[1], ["Bob", "35", "San Francisco"])
        XCTAssertEqual(result.rows[2], ["Charlie", "42", "Austin"])
    }
    
    func testCSVImport_BasicWithoutHeaders() throws {
        let csvText = """
        Alice,28,New York
        Bob,35,San Francisco
        Charlie,42,Austin
        """
        
        let result = try parseTestCSV(csvText, hasHeader: false)
        
        XCTAssertEqual(result.columns, ["Column_1", "Column_2", "Column_3"])
        XCTAssertEqual(result.rows.count, 3)
        XCTAssertEqual(result.rows[0], ["Alice", "28", "New York"])
    }
    
    func testCSVImport_WithQuotedFields() throws {
        let csvText = """
        Name,Description,Price
        "iPhone 15","Apple's latest smartphone",999.00
        "MacBook Pro","High-performance laptop with M3 chip",2399.00
        """
        
        let result = try parseTestCSV(csvText, hasHeader: true)
        
        XCTAssertEqual(result.columns, ["Name", "Description", "Price"])
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows[0], ["iPhone 15", "Apple's latest smartphone", "999.00"])
        XCTAssertEqual(result.rows[1], ["MacBook Pro", "High-performance laptop with M3 chip", "2399.00"])
    }
    
    func testCSVImport_WithEmptyFields() throws {
        let csvText = """
        Name,Age,City,Country
        Alice,28,,USA
        Bob,,San Francisco,
        ,,Austin,USA
        """
        
        let result = try parseTestCSV(csvText, hasHeader: true)
        
        XCTAssertEqual(result.rows[0], ["Alice", "28", "", "USA"])
        XCTAssertEqual(result.rows[1], ["Bob", "", "San Francisco", ""])
        XCTAssertEqual(result.rows[2], ["", "", "Austin", "USA"])
    }
    
    // MARK: - TSV Import Tests
    
    func testTSVImport_Basic() throws {
        let tsvText = """
        Name\tAge\tCity
        Alice\t28\tNew York
        Bob\t35\tSan Francisco
        """
        
        let result = try parseTestDelimited(tsvText, delimiter: "\t", hasHeader: true)
        
        XCTAssertEqual(result.columns, ["Name", "Age", "City"])
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows[0], ["Alice", "28", "New York"])
    }
    
    // MARK: - Custom Delimiter Tests
    
    func testCustomDelimiterImport_Pipe() throws {
        let pipeText = """
        Name|Age|City
        Alice|28|New York
        Bob|35|San Francisco
        """
        
        let result = try parseTestDelimited(pipeText, delimiter: "|", hasHeader: true)
        
        XCTAssertEqual(result.columns, ["Name", "Age", "City"])
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows[0], ["Alice", "28", "New York"])
    }
    
    // MARK: - JSON Import Tests
    
    func testJSONImport_ArrayOfObjects() throws {
        let jsonText = """
        [
            {"name": "Alice", "age": 28, "city": "New York"},
            {"name": "Bob", "age": 35, "city": "San Francisco"},
            {"name": "Charlie", "age": 42, "city": "Austin"}
        ]
        """
        
        let result = try parseTestJSON(jsonText)
        
        XCTAssertEqual(Set(result.columns), Set(["name", "age", "city"]))
        XCTAssertEqual(result.rows.count, 3)
        
        // Find the row for Alice (order might vary due to Set)
        let aliceRow = result.rows.first { row in
            let nameIndex = result.columns.firstIndex(of: "name")!
            return row[nameIndex] == "Alice"
        }
        
        XCTAssertNotNil(aliceRow)
    }
    
    // MARK: - Data Type Detection Tests
    
    func testDataTypeDetection_Integer() throws {
        let intValues = ["1", "42", "100", "-5"]
        let detectedType = detectTestDataType(for: intValues)
        
        XCTAssertEqual(detectedType, "int")
    }
    
    func testDataTypeDetection_Float() throws {
        let floatValues = ["1.5", "42.0", "100.99", "-5.25"]
        let detectedType = detectTestDataType(for: floatValues)
        
        XCTAssertEqual(detectedType, "float")
    }
    
    func testDataTypeDetection_Boolean() throws {
        let boolValues = ["true", "false", "yes", "no"]
        let detectedType = detectTestDataType(for: boolValues)
        
        XCTAssertEqual(detectedType, "bool")
    }
    
    func testDataTypeDetection_String() throws {
        let stringValues = ["hello", "world", "test", "data"]
        let detectedType = detectTestDataType(for: stringValues)
        
        XCTAssertEqual(detectedType, "string")
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_LargeCSVImport() throws {
        // Generate large CSV
        var csvText = "ID,Name,Value\n"
        for i in 1...1000 {
            csvText += "\(i),User\(i),\(Double.random(in: 0...100))\n"
        }
        
        measure {
            do {
                _ = try parseTestCSV(csvText, hasHeader: true)
            } catch {
                XCTFail("Import failed: \(error)")
            }
        }
    }
    
    // MARK: - Helper Functions for Testing
    
    private func parseTestCSV(_ text: String, hasHeader: Bool) throws -> DataFrameData {
        return try parseTestDelimited(text, delimiter: ",", hasHeader: hasHeader)
    }
    
    private func parseTestDelimited(_ text: String, delimiter: String, hasHeader: Bool) throws -> DataFrameData {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else {
            throw TestImportError.emptyData
        }

        let parsedRows = lines.map { line in
            parseTestCSVLine(line, delimiter: delimiter)
        }

        let columns: [String]
        let dataRows: [[String]]

        if hasHeader && parsedRows.count > 1 {
            columns = parsedRows[0]
            dataRows = Array(parsedRows[1...])
        } else {
            // Generate column names
            let columnCount = parsedRows.first?.count ?? 0
            columns = (0..<columnCount).map { "Column_\($0 + 1)" }
            dataRows = parsedRows
        }

        // Ensure all rows have the same number of columns
        let expectedColumnCount = columns.count
        let normalizedRows = dataRows.map { row in
            var normalizedRow = row
            while normalizedRow.count < expectedColumnCount {
                normalizedRow.append("")
            }
            return Array(normalizedRow.prefix(expectedColumnCount))
        }

        // Auto-detect data types
        let dtypes = autoDetectTestDataTypes(columns: columns, rows: normalizedRows)

        return DataFrameData(
            columns: columns,
            rows: normalizedRows,
            dtypes: dtypes
        )
    }
    
    private func parseTestJSON(_ text: String) throws -> DataFrameData {
        guard let data = text.data(using: .utf8) else {
            throw TestImportError.invalidFormat("Unable to convert text to data")
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            
            if let array = jsonObject as? [[String: Any]] {
                return try parseTestJSONArrayOfObjects(array)
            } else {
                throw TestImportError.invalidFormat("Unsupported JSON format")
            }
        } catch {
            throw TestImportError.invalidFormat("Invalid JSON: \(error.localizedDescription)")
        }
    }
    
    private func parseTestJSONArrayOfObjects(_ array: [[String: Any]]) throws -> DataFrameData {
        guard !array.isEmpty else {
            throw TestImportError.emptyData
        }

        // Get all unique keys as columns
        let allKeys = Set(array.flatMap { $0.keys })
        let columns = Array(allKeys).sorted()

        // Convert to rows
        let rows = array.map { object in
            columns.map { column in
                if let value = object[column] {
                    return String(describing: value)
                } else {
                    return ""
                }
            }
        }

        // Auto-detect data types
        let dtypes = autoDetectTestDataTypes(columns: columns, rows: rows)

        return DataFrameData(
            columns: columns,
            rows: rows,
            dtypes: dtypes
        )
    }
    
    private func parseTestCSVLine(_ line: String, delimiter: String) -> [String] {
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
                    i = line.index(i, offsetBy: 2)
                    continue
                } else {
                    inQuotes.toggle()
                }
            } else if String(char) == delimiter && !inQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
            
            i = line.index(after: i)
        }
        
        result.append(current.trimmingCharacters(in: .whitespaces))
        return result
    }
    
    private func autoDetectTestDataTypes(columns: [String], rows: [[String]]) -> [String: String] {
        var dtypes: [String: String] = [:]
        
        for (colIndex, column) in columns.enumerated() {
            let columnValues = rows.compactMap { row in
                colIndex < row.count ? row[colIndex] : nil
            }.filter { !$0.isEmpty }
            
            dtypes[column] = detectTestDataType(for: columnValues)
        }
        
        return dtypes
    }
    
    private func detectTestDataType(for values: [String]) -> String {
        guard !values.isEmpty else { return "string" }
        
        // Check for boolean
        let boolValues = Set(["true", "false", "yes", "no", "1", "0"])
        if values.allSatisfy({ boolValues.contains($0.lowercased()) }) {
            return "bool"
        }
        
        // Check for integer
        if values.allSatisfy({ Int($0) != nil }) {
            return "int"
        }
        
        // Check for float
        if values.allSatisfy({ Double($0) != nil }) {
            return "float"
        }
        
        return "string"
    }
}

// MARK: - Test Error Types

enum TestImportError: LocalizedError {
    case emptyData
    case invalidFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyData:
            return "No data found to import"
        case .invalidFormat(let message):
            return message
        }
    }
}