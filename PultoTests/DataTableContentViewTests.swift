//
//  DataTableContentViewTests.swift
//  PultoTests
//
//  Created by AI Assistant on 1/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import XCTest
import SwiftUI
@testable import Pulto

final class DataTableContentViewTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testInitialization_WithoutParameters() throws {
        let view = DataTableContentView()
        
        XCTAssertEqual(view.windowID, nil)
        XCTAssertNil(view.initialDataFrame)
    }
    
    func testInitialization_WithWindowID() throws {
        let windowID = 123
        let view = DataTableContentView(windowID: windowID)
        
        XCTAssertEqual(view.windowID, windowID)
    }
    
    func testInitialization_WithInitialDataFrame() throws {
        let testData = DataFrameData(
            columns: ["A", "B"],
            rows: [["1", "2"], ["3", "4"]],
            dtypes: ["A": "int", "B": "int"]
        )
        
        let view = DataTableContentView(initialDataFrame: testData)
        
        XCTAssertNotNil(view.initialDataFrame)
        XCTAssertEqual(view.initialDataFrame?.columns.count, 2)
    }
    
    func testDefaultSample() throws {
        let defaultData = DataTableContentView.defaultSample()
        
        XCTAssertEqual(defaultData.columns.count, 4)
        XCTAssertEqual(defaultData.columns, ["Name", "Age", "City", "Salary"])
        XCTAssertEqual(defaultData.rows.count, 4)
        XCTAssertEqual(defaultData.dtypes.count, 4)
    }
    
    // MARK: - Helper Function Tests
    
    func testFormatCellValue_Float() throws {
        let formatter = TestCellFormatter()
        
        let floatValue = formatter.formatCellValue("123.456789", dtype: "float")
        XCTAssertEqual(floatValue, "123.46")
        
        let invalidFloat = formatter.formatCellValue("not_a_number", dtype: "float")
        XCTAssertEqual(invalidFloat, "not_a_number")
    }
    
    func testFormatCellValue_Int() throws {
        let formatter = TestCellFormatter()
        
        let intValue = formatter.formatCellValue("1234", dtype: "int")
        XCTAssertEqual(intValue, "1,234")
        
        let invalidInt = formatter.formatCellValue("not_a_number", dtype: "int")
        XCTAssertEqual(invalidInt, "not_a_number")
    }
    
    func testFormatCellValue_String() throws {
        let formatter = TestCellFormatter()
        
        let stringValue = formatter.formatCellValue("hello", dtype: "string")
        XCTAssertEqual(stringValue, "hello")
    }
    
    func testCSVStringConversion() throws {
        let testData = DataFrameData(
            columns: ["A", "B"],
            rows: [["1", "2"], ["3", "4"]],
            dtypes: ["A": "int", "B": "int"]
        )
        
        let csvConverter = TestCSVConverter()
        let csvString = csvConverter.toCSVString(for: testData)
        let expectedCSV = "A,B\n1,2\n3,4\n"
        
        XCTAssertEqual(csvString, expectedCSV)
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_LargeDataset() throws {
        let columns = (1...100).map { "Column_\($0)" }
        let rows = (1...1000).map { rowIndex in
            columns.map { _ in String(Int.random(in: 1...1000)) }
        }
        
        measure {
            let testData = DataFrameData(columns: columns, rows: rows, dtypes: [:])
            XCTAssertEqual(testData.shapeRows, 1000)
            XCTAssertEqual(testData.shapeColumns, 100)
        }
    }
}

// MARK: - Test Helper Classes

class TestCellFormatter {
    func formatCellValue(_ value: String, dtype: String?) -> String {
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

class TestCSVConverter {
    func toCSVString(for data: DataFrameData) -> String {
        var csv = data.columns.joined(separator: ",") + "\n"
        for row in data.rows {
            csv += row.joined(separator: ",") + "\n"
        }
        return csv
    }
}