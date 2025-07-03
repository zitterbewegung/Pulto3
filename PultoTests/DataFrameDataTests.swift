//
//  DataFrameDataTests.swift
//  PultoTests
//
//  Created by AI Assistant on 1/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import XCTest
@testable import Pulto

final class DataFrameDataTests: XCTestCase {
    
    // MARK: - DataFrameData Tests
    
    func testDataFrameData_Initialization() throws {
        let columns = ["Name", "Age", "City"]
        let rows = [
            ["Alice", "28", "New York"],
            ["Bob", "35", "San Francisco"]
        ]
        let dtypes = ["Name": "string", "Age": "int", "City": "string"]
        
        let dataFrame = DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
        
        XCTAssertEqual(dataFrame.columns, columns)
        XCTAssertEqual(dataFrame.rows, rows)
        XCTAssertEqual(dataFrame.dtypes, dtypes)
    }
    
    func testDataFrameData_ShapeProperties() throws {
        let columns = ["A", "B", "C"]
        let rows = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["10", "11", "12"]
        ]
        let dtypes = ["A": "int", "B": "int", "C": "int"]
        
        let dataFrame = DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
        
        XCTAssertEqual(dataFrame.shapeRows, 4)
        XCTAssertEqual(dataFrame.shapeColumns, 3)
    }
    
    func testDataFrameData_EmptyDataFrame() throws {
        let dataFrame = DataFrameData(columns: [], rows: [], dtypes: [:])
        
        XCTAssertEqual(dataFrame.shapeRows, 0)
        XCTAssertEqual(dataFrame.shapeColumns, 0)
        XCTAssertTrue(dataFrame.columns.isEmpty)
        XCTAssertTrue(dataFrame.rows.isEmpty)
        XCTAssertTrue(dataFrame.dtypes.isEmpty)
    }
    
    func testDataFrameData_SingleColumn() throws {
        let columns = ["Values"]
        let rows = [["1"], ["2"], ["3"]]
        let dtypes = ["Values": "int"]
        
        let dataFrame = DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
        
        XCTAssertEqual(dataFrame.shapeRows, 3)
        XCTAssertEqual(dataFrame.shapeColumns, 1)
    }
    
    func testDataFrameData_SingleRow() throws {
        let columns = ["A", "B", "C"]
        let rows = [["1", "2", "3"]]
        let dtypes = ["A": "int", "B": "int", "C": "int"]
        
        let dataFrame = DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
        
        XCTAssertEqual(dataFrame.shapeRows, 1)
        XCTAssertEqual(dataFrame.shapeColumns, 3)
    }
    
    // MARK: - Data Validation Tests
    
    func testDataFrameData_ConsistentColumnCount() throws {
        let columns = ["A", "B", "C"]
        let rows = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"]
        ]
        let dtypes = ["A": "int", "B": "int", "C": "int"]
        
        let dataFrame = DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
        
        // Verify all rows have the same number of columns as the header
        for row in dataFrame.rows {
            XCTAssertEqual(row.count, dataFrame.columns.count)
        }
    }
    
    func testDataFrameData_DtypesMatchColumns() throws {
        let columns = ["Name", "Age", "Active"]
        let rows = [
            ["Alice", "28", "true"],
            ["Bob", "35", "false"]
        ]
        let dtypes = ["Name": "string", "Age": "int", "Active": "bool"]
        
        let dataFrame = DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
        
        // Verify dtypes contains entries for all columns
        for column in dataFrame.columns {
            XCTAssertNotNil(dataFrame.dtypes[column])
        }
        
        // Verify no extra dtypes
        XCTAssertEqual(dataFrame.dtypes.count, dataFrame.columns.count)
    }
    
    // MARK: - Edge Cases
    
    func testDataFrameData_WithEmptyValues() throws {
        let columns = ["A", "B"]
        let rows = [
            ["", "2"],
            ["3", ""],
            ["", ""]
        ]
        let dtypes = ["A": "string", "B": "string"]
        
        let dataFrame = DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
        
        XCTAssertEqual(dataFrame.shapeRows, 3)
        XCTAssertEqual(dataFrame.shapeColumns, 2)
        
        // Verify empty strings are preserved
        XCTAssertEqual(dataFrame.rows[0][0], "")
        XCTAssertEqual(dataFrame.rows[1][1], "")
        XCTAssertEqual(dataFrame.rows[2][0], "")
        XCTAssertEqual(dataFrame.rows[2][1], "")
    }
    
    func testDataFrameData_WithSpecialCharacters() throws {
        let columns = ["Name", "Symbol", "Unicode"]
        let rows = [
            ["O'Connor", "$", "🚀"],
            ["Smith & Co", "@", "✅"],
            ["Test\nMultiline", "#", "🎉"]
        ]
        let dtypes = ["Name": "string", "Symbol": "string", "Unicode": "string"]
        
        let dataFrame = DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
        
        XCTAssertEqual(dataFrame.shapeRows, 3)
        XCTAssertEqual(dataFrame.rows[0][0], "O'Connor")
        XCTAssertEqual(dataFrame.rows[0][2], "🚀")
        XCTAssertEqual(dataFrame.rows[1][0], "Smith & Co")
        XCTAssertEqual(dataFrame.rows[2][0], "Test\nMultiline")
    }
    
    // MARK: - Data Type Coverage Tests
    
    func testDataFrameData_AllDataTypes() throws {
        let columns = ["StringCol", "IntCol", "FloatCol", "BoolCol"]
        let rows = [
            ["Hello", "42", "3.14", "true"],
            ["World", "-10", "-2.5", "false"],
            ["Test", "0", "0.0", "true"]
        ]
        let dtypes = [
            "StringCol": "string",
            "IntCol": "int",
            "FloatCol": "float",
            "BoolCol": "bool"
        ]
        
        let dataFrame = DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
        
        XCTAssertEqual(dataFrame.dtypes["StringCol"], "string")
        XCTAssertEqual(dataFrame.dtypes["IntCol"], "int")
        XCTAssertEqual(dataFrame.dtypes["FloatCol"], "float")
        XCTAssertEqual(dataFrame.dtypes["BoolCol"], "bool")
    }
    
    // MARK: - Performance Tests
    
    func testDataFrameData_LargeDataSet() throws {
        let columnCount = 50
        let rowCount = 1000
        
        // Generate columns
        let columns = (1...columnCount).map { "Column_\($0)" }
        
        // Generate rows
        let rows = (1...rowCount).map { rowIndex in
            (1...columnCount).map { colIndex in
                "\(rowIndex)_\(colIndex)"
            }
        }
        
        // Generate dtypes
        let dtypes = Dictionary(uniqueKeysWithValues: columns.map { ($0, "string") })
        
        measure {
            let dataFrame = DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
            XCTAssertEqual(dataFrame.shapeRows, rowCount)
            XCTAssertEqual(dataFrame.shapeColumns, columnCount)
        }
    }
    
    // MARK: - Equality Tests
    
    func testDataFrameData_Equality() throws {
        let columns = ["A", "B"]
        let rows = [["1", "2"], ["3", "4"]]
        let dtypes = ["A": "int", "B": "int"]
        
        let dataFrame1 = DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
        let dataFrame2 = DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
        
        XCTAssertEqual(dataFrame1.columns, dataFrame2.columns)
        XCTAssertEqual(dataFrame1.rows, dataFrame2.rows)
        XCTAssertEqual(dataFrame1.dtypes, dataFrame2.dtypes)
    }
    
    func testDataFrameData_Inequality() throws {
        let columns1 = ["A", "B"]
        let columns2 = ["A", "C"]
        let rows = [["1", "2"], ["3", "4"]]
        let dtypes1 = ["A": "int", "B": "int"]
        let dtypes2 = ["A": "int", "C": "int"]
        
        let dataFrame1 = DataFrameData(columns: columns1, rows: rows, dtypes: dtypes1)
        let dataFrame2 = DataFrameData(columns: columns2, rows: rows, dtypes: dtypes2)
        
        XCTAssertNotEqual(dataFrame1.columns, dataFrame2.columns)
        XCTAssertNotEqual(dataFrame1.dtypes, dataFrame2.dtypes)
    }
}