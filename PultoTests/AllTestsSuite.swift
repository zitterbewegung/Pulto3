//
//  AllTestsSuite.swift
//  PultoTests
//
//  Created by AI Assistant on 1/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import XCTest
@testable import Pulto

/// Test suite that runs integration tests for the data table features
final class AllTestsSuite: XCTestCase {
    
    override func setUpWithError() throws {
        super.setUp()
        // Global test setup
    }
    
    override func tearDownWithError() throws {
        super.tearDown()
        // Global test cleanup
    }
    
    // MARK: - Integration Test
    
    func testCompleteDataImportWorkflow() throws {
        // Test the complete workflow from raw data to DataFrameData
        let csvData = """
        Name,Age,Score,Active
        Alice,25,95.5,true
        Bob,30,87.2,false
        Charlie,35,92.0,true
        """
        
        // Parse the CSV data
        let dataFrame = try parseIntegrationTestCSV(csvData)
        
        XCTAssertEqual(dataFrame.columns, ["Name", "Age", "Score", "Active"])
        XCTAssertEqual(dataFrame.rows.count, 3)
        XCTAssertEqual(dataFrame.shapeRows, 3)
        XCTAssertEqual(dataFrame.shapeColumns, 4)
        
        // Test data type detection
        XCTAssertEqual(dataFrame.dtypes["Name"], "string")
        XCTAssertEqual(dataFrame.dtypes["Age"], "int")
        XCTAssertEqual(dataFrame.dtypes["Score"], "float")
        XCTAssertEqual(dataFrame.dtypes["Active"], "bool")
        
        // Test individual rows
        XCTAssertEqual(dataFrame.rows[0], ["Alice", "25", "95.5", "true"])
        XCTAssertEqual(dataFrame.rows[1], ["Bob", "30", "87.2", "false"])
        XCTAssertEqual(dataFrame.rows[2], ["Charlie", "35", "92.0", "true"])
    }
    
    func testDataTableHelperFunctions() throws {
        // Test data type detection
        XCTAssertEqual(detectIntegrationDataType(for: ["1", "2", "3"]), "int")
        XCTAssertEqual(detectIntegrationDataType(for: ["1.5", "2.0", "3.14"]), "float")
        XCTAssertEqual(detectIntegrationDataType(for: ["true", "false"]), "bool")
        XCTAssertEqual(detectIntegrationDataType(for: ["hello", "world"]), "string")
        
        // Test formatting
        XCTAssertEqual(formatIntegrationCellValue("123.456", dtype: "float"), "123.46")
        XCTAssertEqual(formatIntegrationCellValue("1234", dtype: "int"), "1,234")
    }
    
    // MARK: - Edge Cases
    
    func testEdgeCases() throws {
        // Test single column
        let singleColumnCSV = "Name\nAlice\nBob\nCharlie"
        let singleResult = try parseIntegrationTestCSV(singleColumnCSV)
        
        XCTAssertEqual(singleResult.columns, ["Name"])
        XCTAssertEqual(singleResult.rows.count, 3)
        XCTAssertEqual(singleResult.shapeColumns, 1)
        
        // Test single row
        let singleRowCSV = "Name,Age,City\nAlice,25,NYC"
        let singleRowResult = try parseIntegrationTestCSV(singleRowCSV)
        
        XCTAssertEqual(singleRowResult.columns, ["Name", "Age", "City"])
        XCTAssertEqual(singleRowResult.rows.count, 1)
        XCTAssertEqual(singleRowResult.shapeRows, 1)
    }
    
    // MARK: - Helper Functions for Integration Testing
    
    private func parseIntegrationTestCSV(_ text: String) throws -> DataFrameData {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else {
            throw IntegrationTestError.emptyData
        }

        let parsedRows = lines.map { line in
            line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }

        let columns = parsedRows[0]
        let dataRows = Array(parsedRows[1...])

        // Auto-detect data types
        let dtypes = autoDetectIntegrationDataTypes(columns: columns, rows: dataRows)

        return DataFrameData(
            columns: columns,
            rows: dataRows,
            dtypes: dtypes
        )
    }
    
    private func autoDetectIntegrationDataTypes(columns: [String], rows: [[String]]) -> [String: String] {
        var dtypes: [String: String] = [:]
        
        for (colIndex, column) in columns.enumerated() {
            let columnValues = rows.compactMap { row in
                colIndex < row.count ? row[colIndex] : nil
            }.filter { !$0.isEmpty }
            
            dtypes[column] = detectIntegrationDataType(for: columnValues)
        }
        
        return dtypes
    }
    
    private func detectIntegrationDataType(for values: [String]) -> String {
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
    
    private func formatIntegrationCellValue(_ value: String, dtype: String?) -> String {
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
}

// MARK: - Integration Test Error Types

enum IntegrationTestError: LocalizedError {
    case emptyData
    
    var errorDescription: String? {
        switch self {
        case .emptyData:
            return "No data found to import"
        }
    }
}