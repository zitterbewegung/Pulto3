//
//  ChartDataFrameRestorationTests.swift
//  PultoTests
//
//  Created by AI Assistant on 1/4/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import XCTest
@testable import Pulto

final class ChartDataFrameRestorationTests: XCTestCase {
    
    var windowManager: WindowTypeManager!
    
    override func setUpWithError() throws {
        windowManager = WindowTypeManager()
    }
    
    override func tearDownWithError() throws {
        windowManager.clearAllWindows()
        windowManager = nil
    }
    
    // MARK: - Chart Data Round-Trip Tests
    
    func testChartDataRoundTrip() throws {
        // Create a chart window with real data
        let chartWindow = windowManager.createWindow(.charts, id: 1)
        
        let originalChartData = ChartData(
            title: "Test Revenue Chart",
            chartType: "line",
            xLabel: "Quarter",
            yLabel: "Revenue ($M)",
            xData: [1.0, 2.0, 3.0, 4.0],
            yData: [100.5, 125.3, 110.7, 145.2],
            color: "blue",
            style: "solid"
        )
        
        windowManager.updateWindowChartData(1, chartData: originalChartData)
        
        // Export to notebook
        let notebookJSON = windowManager.exportToJupyterNotebook()
        let exportData = notebookJSON.data(using: .utf8)!
        
        // Clear windows and import back
        windowManager.clearAllWindows()
        XCTAssertEqual(windowManager.getAllWindows().count, 0)
        
        let importResult = try windowManager.importFromGenericNotebook(data: exportData)
        
        // Verify import success
        XCTAssertTrue(importResult.isSuccessful)
        XCTAssertEqual(importResult.restoredWindows.count, 1)
        
        // Verify chart data was restored
        let restoredWindow = importResult.restoredWindows[0]
        XCTAssertEqual(restoredWindow.windowType, .charts)
        
        let restoredChartData = windowManager.getWindowChartData(for: restoredWindow.id)
        XCTAssertNotNil(restoredChartData)
        
        if let restored = restoredChartData {
            XCTAssertEqual(restored.title, "Test Revenue Chart")
            XCTAssertEqual(restored.chartType, "line")
            XCTAssertEqual(restored.xLabel, "Quarter")
            XCTAssertEqual(restored.yLabel, "Revenue ($M)")
            XCTAssertEqual(restored.xData, [1.0, 2.0, 3.0, 4.0])
            XCTAssertEqual(restored.yData, [100.5, 125.3, 110.7, 145.2])
            XCTAssertEqual(restored.color, "blue")
            XCTAssertEqual(restored.style, "solid")
        }
    }
    
    func testBarChartRestoration() throws {
        let chartWindow = windowManager.createWindow(.charts, id: 1)
        
        let barChartData = ChartData(
            title: "Sales by Category",
            chartType: "bar",
            xLabel: "Category",
            yLabel: "Sales",
            xData: [0.0, 1.0, 2.0, 3.0], // Bar charts use indices
            yData: [50.0, 75.0, 60.0, 90.0],
            color: "green",
            style: nil
        )
        
        windowManager.updateWindowChartData(1, chartData: barChartData)
        
        // Round-trip test
        let notebookJSON = windowManager.exportToJupyterNotebook()
        let exportData = notebookJSON.data(using: .utf8)!
        
        windowManager.clearAllWindows()
        let importResult = try windowManager.importFromGenericNotebook(data: exportData)
        
        let restoredChartData = windowManager.getWindowChartData(for: importResult.restoredWindows[0].id)
        XCTAssertNotNil(restoredChartData)
        XCTAssertEqual(restoredChartData?.chartType, "bar")
        XCTAssertEqual(restoredChartData?.color, "green")
        XCTAssertEqual(restoredChartData?.yData, [50.0, 75.0, 60.0, 90.0])
    }
    
    // MARK: - DataFrame Round-Trip Tests
    
    func testDataFrameRoundTrip() throws {
        // Create a DataFrame window with real data
        let dataFrameWindow = windowManager.createWindow(.column, id: 1)
        
        let originalDataFrame = DataFrameData(
            columns: ["Name", "Age", "Salary", "Department"],
            rows: [
                ["Alice Johnson", "28", "75000.50", "Engineering"],
                ["Bob Smith", "35", "85000.00", "Marketing"],
                ["Carol Davis", "42", "95000.75", "Engineering"],
                ["David Wilson", "29", "70000.00", "Sales"]
            ],
            dtypes: [
                "Name": "string",
                "Age": "int",
                "Salary": "float",
                "Department": "string"
            ]
        )
        
        windowManager.updateWindowDataFrame(1, dataFrame: originalDataFrame)
        
        // Export to notebook
        let notebookJSON = windowManager.exportToJupyterNotebook()
        let exportData = notebookJSON.data(using: .utf8)!
        
        // Clear windows and import back
        windowManager.clearAllWindows()
        XCTAssertEqual(windowManager.getAllWindows().count, 0)
        
        let importResult = try windowManager.importFromGenericNotebook(data: exportData)
        
        // Verify import success
        XCTAssertTrue(importResult.isSuccessful)
        XCTAssertEqual(importResult.restoredWindows.count, 1)
        
        // Verify DataFrame was restored
        let restoredWindow = importResult.restoredWindows[0]
        XCTAssertEqual(restoredWindow.windowType, .column)
        
        let restoredDataFrame = windowManager.getWindowDataFrame(for: restoredWindow.id)
        XCTAssertNotNil(restoredDataFrame)
        
        if let restored = restoredDataFrame {
            XCTAssertEqual(restored.columns, ["Name", "Age", "Salary", "Department"])
            XCTAssertEqual(restored.rows.count, 4)
            XCTAssertEqual(restored.rows[0], ["Alice Johnson", "28", "75000.50", "Engineering"])
            XCTAssertEqual(restored.rows[1], ["Bob Smith", "35", "85000.00", "Marketing"])
            XCTAssertEqual(restored.dtypes["Name"], "string")
            XCTAssertEqual(restored.dtypes["Age"], "int")
            XCTAssertEqual(restored.dtypes["Salary"], "float")
        }
    }
    
    func testDataFrameWithMixedTypes() throws {
        let dataFrameWindow = windowManager.createWindow(.column, id: 1)
        
        let mixedDataFrame = DataFrameData(
            columns: ["ID", "Active", "Score", "Description"],
            rows: [
                ["1", "true", "95.5", "Excellent performance"],
                ["2", "false", "78.2", "Good progress"],
                ["3", "true", "88.7", "Very good work"]
            ],
            dtypes: [
                "ID": "int",
                "Active": "bool",
                "Score": "float",
                "Description": "string"
            ]
        )
        
        windowManager.updateWindowDataFrame(1, dataFrame: mixedDataFrame)
        
        // Round-trip test
        let notebookJSON = windowManager.exportToJupyterNotebook()
        let exportData = notebookJSON.data(using: .utf8)!
        
        windowManager.clearAllWindows()
        let importResult = try windowManager.importFromGenericNotebook(data: exportData)
        
        let restoredDataFrame = windowManager.getWindowDataFrame(for: importResult.restoredWindows[0].id)
        XCTAssertNotNil(restoredDataFrame)
        
        if let restored = restoredDataFrame {
            XCTAssertEqual(restored.columns, ["ID", "Active", "Score", "Description"])
            XCTAssertEqual(restored.dtypes["Active"], "bool")
            XCTAssertEqual(restored.dtypes["Score"], "float")
            XCTAssertEqual(restored.rows[0][3], "Excellent performance")
        }
    }
    
    // MARK: - Complex Scenario Tests
    
    func testMultipleChartsAndDataFrames() throws {
        // Create multiple windows with different data
        let chartWindow1 = windowManager.createWindow(.charts, id: 1)
        let chartWindow2 = windowManager.createWindow(.charts, id: 2)
        let dataFrameWindow = windowManager.createWindow(.column, id: 3)
        
        // Add chart data
        let lineChart = ChartData(
            title: "Revenue Trend",
            chartType: "line",
            xLabel: "Month",
            yLabel: "Revenue",
            xData: [1, 2, 3, 4, 5, 6],
            yData: [100, 120, 115, 130, 125, 140]
        )
        windowManager.updateWindowChartData(1, chartData: lineChart)
        
        let scatterChart = ChartData(
            title: "Sales vs Marketing",
            chartType: "scatter",
            xLabel: "Marketing Spend",
            yLabel: "Sales",
            xData: [10, 20, 30, 40, 50],
            yData: [100, 180, 320, 390, 500],
            color: "red"
        )
        windowManager.updateWindowChartData(2, chartData: scatterChart)
        
        // Add DataFrame data
        let employeeData = DataFrameData(
            columns: ["Employee", "Performance", "Bonus"],
            rows: [
                ["John", "85", "5000"],
                ["Jane", "92", "7500"],
                ["Mike", "78", "3000"]
            ],
            dtypes: [
                "Employee": "string",
                "Performance": "int",
                "Bonus": "float"
            ]
        )
        windowManager.updateWindowDataFrame(3, dataFrame: employeeData)
        
        // Export and import
        let notebookJSON = windowManager.exportToJupyterNotebook()
        let exportData = notebookJSON.data(using: .utf8)!
        
        windowManager.clearAllWindows()
        let importResult = try windowManager.importFromGenericNotebook(data: exportData)
        
        // Verify all windows were restored
        XCTAssertEqual(importResult.restoredWindows.count, 3)
        
        let chartWindows = importResult.restoredWindows.filter { $0.windowType == .charts }
        let dataFrameWindows = importResult.restoredWindows.filter { $0.windowType == .column }
        
        XCTAssertEqual(chartWindows.count, 2)
        XCTAssertEqual(dataFrameWindows.count, 1)
        
        // Verify chart data
        for chartWindow in chartWindows {
            let chartData = windowManager.getWindowChartData(for: chartWindow.id)
            XCTAssertNotNil(chartData)
            XCTAssertTrue(chartData?.title == "Revenue Trend" || chartData?.title == "Sales vs Marketing")
        }
        
        // Verify DataFrame data
        let restoredDataFrame = windowManager.getWindowDataFrame(for: dataFrameWindows[0].id)
        XCTAssertNotNil(restoredDataFrame)
        XCTAssertEqual(restoredDataFrame?.columns, ["Employee", "Performance", "Bonus"])
    }
    
    // MARK: - Edge Cases
    
    func testEmptyChart() throws {
        let chartWindow = windowManager.createWindow(.charts, id: 1)
        
        let emptyChart = ChartData(
            title: "Empty Chart",
            chartType: "line",
            xLabel: "X",
            yLabel: "Y",
            xData: [],
            yData: []
        )
        windowManager.updateWindowChartData(1, chartData: emptyChart)
        
        // Round-trip test
        let notebookJSON = windowManager.exportToJupyterNotebook()
        let exportData = notebookJSON.data(using: .utf8)!
        
        windowManager.clearAllWindows()
        let importResult = try windowManager.importFromGenericNotebook(data: exportData)
        
        let restoredChartData = windowManager.getWindowChartData(for: importResult.restoredWindows[0].id)
        XCTAssertNotNil(restoredChartData)
        // Should create sample data when empty
        XCTAssertFalse(restoredChartData?.xData.isEmpty ?? true)
        XCTAssertFalse(restoredChartData?.yData.isEmpty ?? true)
    }
    
    func testEmptyDataFrame() throws {
        let dataFrameWindow = windowManager.createWindow(.column, id: 1)
        
        let emptyDataFrame = DataFrameData(
            columns: [],
            rows: [],
            dtypes: [:]
        )
        windowManager.updateWindowDataFrame(1, dataFrame: emptyDataFrame)
        
        // Round-trip test
        let notebookJSON = windowManager.exportToJupyterNotebook()
        let exportData = notebookJSON.data(using: .utf8)!
        
        windowManager.clearAllWindows()
        let importResult = try windowManager.importFromGenericNotebook(data: exportData)
        
        let restoredDataFrame = windowManager.getWindowDataFrame(for: importResult.restoredWindows[0].id)
        XCTAssertNotNil(restoredDataFrame)
        // Should create sample data when empty
        XCTAssertFalse(restoredDataFrame?.columns.isEmpty ?? true)
        XCTAssertFalse(restoredDataFrame?.rows.isEmpty ?? true)
    }
    
    // MARK: - Performance Tests
    
    func testLargeDataFrameRoundTrip() throws {
        let dataFrameWindow = windowManager.createWindow(.column, id: 1)
        
        // Create large DataFrame
        var rows: [[String]] = []
        for i in 0..<1000 {
            rows.append([
                "User\(i)",
                "\(20 + i % 50)",
                "\(Double(30000 + i * 100))",
                i % 2 == 0 ? "Active" : "Inactive"
            ])
        }
        
        let largeDataFrame = DataFrameData(
            columns: ["Username", "Age", "Salary", "Status"],
            rows: rows,
            dtypes: [
                "Username": "string",
                "Age": "int",
                "Salary": "float",
                "Status": "string"
            ]
        )
        
        windowManager.updateWindowDataFrame(1, dataFrame: largeDataFrame)
        
        // Measure round-trip performance
        measure {
            let notebookJSON = windowManager.exportToJupyterNotebook()
            let exportData = notebookJSON.data(using: .utf8)!
            
            windowManager.clearAllWindows()
            
            do {
                let importResult = try windowManager.importFromGenericNotebook(data: exportData)
                XCTAssertEqual(importResult.restoredWindows.count, 1)
                
                let restoredDataFrame = windowManager.getWindowDataFrame(for: importResult.restoredWindows[0].id)
                XCTAssertNotNil(restoredDataFrame)
                XCTAssertEqual(restoredDataFrame?.rows.count, 1000)
            } catch {
                XCTFail("Import failed: \(error)")
            }
        }
    }
}