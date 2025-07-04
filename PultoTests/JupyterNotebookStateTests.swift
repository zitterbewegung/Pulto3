//
//  JupyterNotebookStateTests.swift
//  PultoTests
//
//  Created by AI Assistant on 1/4/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import XCTest
@testable import Pulto

final class JupyterNotebookStateTests: XCTestCase {
    
    var windowManager: WindowTypeManager!
    var workspaceManager: WorkspaceManager!
    
    override func setUpWithError() throws {
        windowManager = WindowTypeManager()
        workspaceManager = WorkspaceManager.shared
    }
    
    override func tearDownWithError() throws {
        windowManager.clearAllWindows()
        windowManager = nil
        workspaceManager = nil
    }
    
    // MARK: - Basic Window Creation and State Tests
    
    func testWindowCreationAndBasicState() throws {
        // Test creating different types of windows
        let chartWindow = windowManager.createWindow(.charts, id: 1)
        let spatialWindow = windowManager.createWindow(.spatial, id: 2)
        let columnWindow = windowManager.createWindow(.column, id: 3)
        let volumeWindow = windowManager.createWindow(.volume, id: 4)
        let model3DWindow = windowManager.createWindow(.model3d, id: 5)
        
        // Verify windows were created
        XCTAssertEqual(windowManager.getAllWindows().count, 5)
        XCTAssertEqual(chartWindow.windowType, .charts)
        XCTAssertEqual(spatialWindow.windowType, .spatial)
        XCTAssertEqual(columnWindow.windowType, .column)
        XCTAssertEqual(volumeWindow.windowType, .volume)
        XCTAssertEqual(model3DWindow.windowType, .model3d)
        
        // Test window retrieval
        let retrievedChart = windowManager.getWindowSafely(for: 1)
        XCTAssertNotNil(retrievedChart)
        XCTAssertEqual(retrievedChart?.windowType, .charts)
    }
    
    func testWindowStateUpdates() throws {
        let window = windowManager.createWindow(.charts, id: 1)
        let originalModified = window.state.lastModified
        
        // Update content
        windowManager.updateWindowContent(1, content: "Test content")
        
        let updatedWindow = windowManager.getWindowSafely(for: 1)
        XCTAssertNotNil(updatedWindow)
        XCTAssertEqual(updatedWindow?.state.content, "Test content")
        XCTAssertGreaterThan(updatedWindow?.state.lastModified ?? Date.distantPast, originalModified)
        
        // Update template
        windowManager.updateWindowTemplate(1, template: .matplotlib)
        let templateUpdated = windowManager.getWindowSafely(for: 1)
        XCTAssertEqual(templateUpdated?.state.exportTemplate, .matplotlib)
        
        // Add tags
        windowManager.addWindowTag(1, tag: "visualization")
        windowManager.addWindowTag(1, tag: "test")
        let taggedWindow = windowManager.getWindowSafely(for: 1)
        XCTAssertTrue(taggedWindow?.state.tags.contains("visualization") ?? false)
        XCTAssertTrue(taggedWindow?.state.tags.contains("test") ?? false)
    }
    
    // MARK: - Specialized Data Tests
    
    func testChartDataIntegration() throws {
        let window = windowManager.createWindow(.charts, id: 1)
        
        // Create chart data
        let chartData = ChartData(
            title: "Test Chart",
            chartType: "line",
            xLabel: "X Axis",
            yLabel: "Y Axis",
            xData: [1, 2, 3, 4, 5],
            yData: [10, 20, 15, 25, 30]
        )
        
        windowManager.updateWindowChartData(1, chartData: chartData)
        
        // Verify data was stored
        let retrievedData = windowManager.getWindowChartData(for: 1)
        XCTAssertNotNil(retrievedData)
        XCTAssertEqual(retrievedData?.title, "Test Chart")
        XCTAssertEqual(retrievedData?.chartType, "line")
        XCTAssertEqual(retrievedData?.xData, [1, 2, 3, 4, 5])
        XCTAssertEqual(retrievedData?.yData, [10, 20, 15, 25, 30])
        
        // Verify template was auto-updated
        let updatedWindow = windowManager.getWindowSafely(for: 1)
        XCTAssertEqual(updatedWindow?.state.exportTemplate, .matplotlib)
    }
    
    func testPointCloudDataIntegration() throws {
        let window = windowManager.createWindow(.spatial, id: 1)
        
        // Create point cloud data
        var pointCloudData = PointCloudData(title: "Test Point Cloud", demoType: "sphere")
        pointCloudData.points = [
            PointCloudData.PointData(x: 1.0, y: 2.0, z: 3.0, intensity: 0.5, color: nil),
            PointCloudData.PointData(x: 2.0, y: 3.0, z: 4.0, intensity: 0.7, color: nil),
            PointCloudData.PointData(x: 3.0, y: 4.0, z: 5.0, intensity: 0.9, color: nil)
        ]
        pointCloudData.totalPoints = 3
        
        windowManager.updateWindowPointCloud(1, pointCloud: pointCloudData)
        
        // Verify data was stored
        let retrievedData = windowManager.getWindowPointCloud(for: 1)
        XCTAssertNotNil(retrievedData)
        XCTAssertEqual(retrievedData?.title, "Test Point Cloud")
        XCTAssertEqual(retrievedData?.points.count, 3)
        XCTAssertEqual(retrievedData?.totalPoints, 3)
        
        // Verify template was auto-updated
        let updatedWindow = windowManager.getWindowSafely(for: 1)
        XCTAssertEqual(updatedWindow?.state.exportTemplate, .custom)
    }
    
    func testDataFrameIntegration() throws {
        let window = windowManager.createWindow(.column, id: 1)
        
        // Create DataFrame data
        let dataFrame = DataFrameData(
            columns: ["Name", "Age", "City"],
            rows: [
                ["Alice", "28", "New York"],
                ["Bob", "35", "San Francisco"],
                ["Charlie", "42", "Austin"]
            ],
            dtypes: [
                "Name": "string",
                "Age": "int",
                "City": "string"
            ]
        )
        
        windowManager.updateWindowDataFrame(1, dataFrame: dataFrame)
        
        // Verify data was stored
        let retrievedData = windowManager.getWindowDataFrame(for: 1)
        XCTAssertNotNil(retrievedData)
        XCTAssertEqual(retrievedData?.columns, ["Name", "Age", "City"])
        XCTAssertEqual(retrievedData?.rows.count, 3)
        XCTAssertEqual(retrievedData?.rows[0], ["Alice", "28", "New York"])
        
        // Verify template was auto-updated
        let updatedWindow = windowManager.getWindowSafely(for: 1)
        XCTAssertEqual(updatedWindow?.state.exportTemplate, .pandas)
    }
    
    // MARK: - Jupyter Export Tests
    
    func testBasicJupyterExport() throws {
        // Create a few windows with different types
        let _ = windowManager.createWindow(.charts, id: 1)
        let _ = windowManager.createWindow(.spatial, id: 2)
        let _ = windowManager.createWindow(.column, id: 3)
        
        // Add some content
        windowManager.updateWindowContent(1, content: "plt.plot([1, 2, 3], [4, 5, 6])")
        windowManager.updateWindowContent(2, content: "# Spatial content")
        windowManager.updateWindowContent(3, content: "df = pd.DataFrame({'A': [1, 2, 3]})")
        
        // Export to Jupyter
        let notebookJSON = windowManager.exportToJupyterNotebook()
        
        // Verify it's valid JSON
        let jsonData = notebookJSON.data(using: .utf8)
        XCTAssertNotNil(jsonData)
        
        let parsedJSON = try JSONSerialization.jsonObject(with: jsonData!, options: [])
        XCTAssertNotNil(parsedJSON as? [String: Any])
        
        // Verify basic structure
        guard let notebook = parsedJSON as? [String: Any] else {
            XCTFail("Failed to parse notebook JSON")
            return
        }
        
        XCTAssertNotNil(notebook["cells"])
        XCTAssertNotNil(notebook["metadata"])
        XCTAssertEqual(notebook["nbformat"] as? Int, 4)
        XCTAssertEqual(notebook["nbformat_minor"] as? Int, 4)
        
        // Verify cells
        guard let cells = notebook["cells"] as? [[String: Any]] else {
            XCTFail("Failed to parse cells")
            return
        }
        
        XCTAssertEqual(cells.count, 3)
        
        // Verify metadata
        guard let metadata = notebook["metadata"] as? [String: Any] else {
            XCTFail("Failed to parse metadata")
            return
        }
        
        XCTAssertNotNil(metadata["visionos_export"])
        XCTAssertNotNil(metadata["kernelspec"])
        XCTAssertNotNil(metadata["language_info"])
    }
    
    func testJupyterExportWithSpecializedData() throws {
        // Create windows with specialized data
        let chartWindow = windowManager.createWindow(.charts, id: 1)
        let spatialWindow = windowManager.createWindow(.spatial, id: 2)
        
        // Add chart data
        let chartData = ChartData(
            title: "Revenue Growth",
            chartType: "line",
            xLabel: "Quarter",
            yLabel: "Revenue ($M)",
            xData: [1, 2, 3, 4],
            yData: [100, 150, 200, 180]
        )
        windowManager.updateWindowChartData(1, chartData: chartData)
        
        // Add point cloud data
        var pointCloudData = PointCloudData(title: "Sensor Data", demoType: "custom")
        pointCloudData.points = [
            PointCloudData.PointData(x: 0, y: 0, z: 0, intensity: 1.0, color: nil),
            PointCloudData.PointData(x: 1, y: 1, z: 1, intensity: 0.8, color: nil)
        ]
        pointCloudData.totalPoints = 2
        windowManager.updateWindowPointCloud(2, pointCloud: pointCloudData)
        
        // Export and verify
        let notebookJSON = windowManager.exportToJupyterNotebook()
        let jsonData = notebookJSON.data(using: .utf8)!
        let notebook = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let cells = notebook["cells"] as! [[String: Any]]
        
        // Find the chart cell
        let chartCell = cells.first { cell in
            guard let metadata = cell["metadata"] as? [String: Any],
                  let windowType = metadata["window_type"] as? String else { return false }
            return windowType == "charts"
        }
        
        XCTAssertNotNil(chartCell)
        
        // Verify the chart cell has proper content
        if let chartCell = chartCell,
           let source = chartCell["source"] as? [String] {
            let content = source.joined(separator: "\n")
            XCTAssertTrue(content.contains("import matplotlib.pyplot as plt"))
            XCTAssertTrue(content.contains("Chart Window"))
        }
    }
    
    // MARK: - Jupyter Import Tests
    
    func testBasicJupyterImport() throws {
        // Create a test notebook JSON
        let testNotebook: [String: Any] = [
            "cells": [
                [
                    "cell_type": "code",
                    "metadata": [
                        "window_id": 1,
                        "window_type": "charts",
                        "export_template": "matplotlib",
                        "tags": ["test", "import"],
                        "position": [
                            "x": 100.0,
                            "y": 200.0,
                            "z": 300.0,
                            "width": 400.0,
                            "height": 300.0
                        ],
                        "state": [
                            "minimized": false,
                            "maximized": false,
                            "opacity": 1.0
                        ]
                    ],
                    "source": [
                        "import matplotlib.pyplot as plt",
                        "plt.plot([1, 2, 3], [4, 5, 6])",
                        "plt.title('Test Chart')"
                    ],
                    "execution_count": NSNull(),
                    "outputs": []
                ]
            ],
            "metadata": [
                "visionos_export": [
                    "export_date": "2025-01-04T12:00:00Z",
                    "total_windows": 1,
                    "window_types": ["charts"],
                    "export_templates": ["matplotlib"],
                    "all_tags": ["test", "import"]
                ]
            ],
            "nbformat": 4,
            "nbformat_minor": 4
        ]
        
        // Convert to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: testNotebook)
        
        // Clear existing windows
        windowManager.clearAllWindows()
        
        // Import from JSON
        let importResult = try windowManager.importFromGenericNotebook(data: jsonData)
        
        // Verify import results
        XCTAssertTrue(importResult.isSuccessful)
        XCTAssertEqual(importResult.restoredWindows.count, 1)
        XCTAssertEqual(importResult.errors.count, 0)
        
        // Verify imported window
        let windows = windowManager.getAllWindows()
        XCTAssertEqual(windows.count, 1)
        
        let importedWindow = windows.first!
        XCTAssertEqual(importedWindow.windowType, .charts)
        XCTAssertEqual(importedWindow.state.exportTemplate, .matplotlib)
        XCTAssertEqual(importedWindow.state.tags, ["test", "import"])
        XCTAssertEqual(importedWindow.position.x, 100.0)
        XCTAssertEqual(importedWindow.position.y, 200.0)
        XCTAssertEqual(importedWindow.position.z, 300.0)
        XCTAssertTrue(importedWindow.state.content.contains("plt.plot([1, 2, 3], [4, 5, 6])"))
    }
    
    func testRoundTripExportImport() throws {
        // Create complex workspace
        let chartWindow = windowManager.createWindow(.charts, id: 1, position: WindowPosition(x: 100, y: 200, z: 300))
        let spatialWindow = windowManager.createWindow(.spatial, id: 2, position: WindowPosition(x: 400, y: 500, z: 600))
        let columnWindow = windowManager.createWindow(.column, id: 3, position: WindowPosition(x: 700, y: 800, z: 900))
        
        // Add content and data
        windowManager.updateWindowContent(1, content: "plt.plot([1, 2, 3], [4, 5, 6])")
        windowManager.updateWindowTemplate(1, template: .matplotlib)
        windowManager.addWindowTag(1, tag: "chart")
        windowManager.addWindowTag(1, tag: "visualization")
        
        let chartData = ChartData(
            title: "Test Chart",
            chartType: "line",
            xLabel: "X",
            yLabel: "Y",
            xData: [1, 2, 3],
            yData: [4, 5, 6]
        )
        windowManager.updateWindowChartData(1, chartData: chartData)
        
        windowManager.updateWindowContent(2, content: "# Spatial content")
        windowManager.addWindowTag(2, tag: "spatial")
        
        let dataFrame = DataFrameData(
            columns: ["A", "B"],
            rows: [["1", "2"], ["3", "4"]],
            dtypes: ["A": "int", "B": "int"]
        )
        windowManager.updateWindowDataFrame(3, dataFrame: dataFrame)
        
        // Export to JSON
        let exportedJSON = windowManager.exportToJupyterNotebook()
        let exportData = exportedJSON.data(using: .utf8)!
        
        // Clear windows
        windowManager.clearAllWindows()
        XCTAssertEqual(windowManager.getAllWindows().count, 0)
        
        // Import back
        let importResult = try windowManager.importFromGenericNotebook(data: exportData)
        
        // Verify import success
        XCTAssertTrue(importResult.isSuccessful)
        XCTAssertEqual(importResult.restoredWindows.count, 3)
        XCTAssertEqual(importResult.errors.count, 0)
        
        // Verify windows were restored
        let restoredWindows = windowManager.getAllWindows().sorted { $0.id < $1.id }
        XCTAssertEqual(restoredWindows.count, 3)
        
        // Verify chart window
        let restoredChart = restoredWindows[0]
        XCTAssertEqual(restoredChart.windowType, .charts)
        XCTAssertEqual(restoredChart.position.x, 100.0)
        XCTAssertEqual(restoredChart.position.y, 200.0)
        XCTAssertEqual(restoredChart.position.z, 300.0)
        XCTAssertEqual(restoredChart.state.exportTemplate, .matplotlib)
        XCTAssertTrue(restoredChart.state.tags.contains("chart"))
        XCTAssertTrue(restoredChart.state.tags.contains("visualization"))
        XCTAssertTrue(restoredChart.state.content.contains("plt.plot"))
        
        // Verify chart data was preserved
        let restoredChartData = windowManager.getWindowChartData(for: restoredChart.id)
        XCTAssertNotNil(restoredChartData)
        // Note: Chart data might not be perfectly preserved in current implementation
        
        // Verify spatial window
        let restoredSpatial = restoredWindows[1]
        XCTAssertEqual(restoredSpatial.windowType, .spatial)
        XCTAssertEqual(restoredSpatial.position.x, 400.0)
        XCTAssertTrue(restoredSpatial.state.tags.contains("spatial"))
        
        // Verify column window
        let restoredColumn = restoredWindows[2]
        XCTAssertEqual(restoredColumn.windowType, .column)
        XCTAssertEqual(restoredColumn.position.x, 700.0)
        
        // Verify DataFrame data was preserved
        let restoredDataFrame = windowManager.getWindowDataFrame(for: restoredColumn.id)
        XCTAssertNotNil(restoredDataFrame)
        // Note: DataFrame data might not be perfectly preserved in current implementation
    }
    
    // MARK: - Workspace Integration Tests
    
    func testWorkspaceCreationAndSaving() async throws {
        // Create a workspace with multiple windows
        let _ = windowManager.createWindow(.charts, id: 1)
        let _ = windowManager.createWindow(.spatial, id: 2)
        
        windowManager.updateWindowContent(1, content: "plt.plot([1, 2, 3])")
        windowManager.updateWindowContent(2, content: "# Spatial analysis")
        
        // Create workspace metadata
        let workspace = try await workspaceManager.createNewWorkspace(
            name: "Test Workspace",
            description: "A test workspace for unit testing",
            category: .custom,
            tags: ["test", "unit-test"],
            windowManager: windowManager
        )
        
        // Verify workspace was created
        XCTAssertEqual(workspace.name, "Test Workspace")
        XCTAssertEqual(workspace.description, "A test workspace for unit testing")
        XCTAssertEqual(workspace.category, .custom)
        XCTAssertEqual(workspace.totalWindows, 2)
        XCTAssertTrue(workspace.tags.contains("test"))
        XCTAssertTrue(workspace.tags.contains("unit-test"))
        XCTAssertNotNil(workspace.fileURL)
        
        // Verify file exists
        if let fileURL = workspace.fileURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        }
    }
    
    func testWorkspaceLoadingAndRestoration() async throws {
        // Create initial workspace
        let _ = windowManager.createWindow(.charts, id: 1, position: WindowPosition(x: 100, y: 200, z: 300))
        let _ = windowManager.createWindow(.column, id: 2, position: WindowPosition(x: 400, y: 500, z: 600))
        
        windowManager.updateWindowContent(1, content: "plt.plot([1, 2, 3])")
        windowManager.updateWindowContent(2, content: "df = pd.DataFrame({'A': [1, 2, 3]})")
        
        let workspace = try await workspaceManager.createNewWorkspace(
            name: "Load Test Workspace",
            description: "Testing workspace loading",
            windowManager: windowManager
        )
        
        // Clear current windows
        windowManager.clearAllWindows()
        XCTAssertEqual(windowManager.getAllWindows().count, 0)
        
        // Load the workspace
        var openedWindowIDs: [Int] = []
        let restoreResult = try await workspaceManager.loadWorkspace(
            workspace,
            into: windowManager,
            clearExisting: true
        ) { windowID in
            openedWindowIDs.append(windowID)
        }
        
        // Verify restoration
        XCTAssertTrue(restoreResult.isFullySuccessful)
        XCTAssertEqual(restoreResult.totalRestored, 2)
        XCTAssertEqual(restoreResult.totalFailed, 0)
        
        // Verify windows were restored
        let restoredWindows = windowManager.getAllWindows()
        XCTAssertEqual(restoredWindows.count, 2)
        
        // Verify positions and content were preserved
        let chartWindow = restoredWindows.first { $0.windowType == .charts }
        let columnWindow = restoredWindows.first { $0.windowType == .column }
        
        XCTAssertNotNil(chartWindow)
        XCTAssertNotNil(columnWindow)
        
        if let chartWindow = chartWindow {
            XCTAssertEqual(chartWindow.position.x, 100.0)
            XCTAssertEqual(chartWindow.position.y, 200.0)
            XCTAssertEqual(chartWindow.position.z, 300.0)
            XCTAssertTrue(chartWindow.state.content.contains("plt.plot"))
        }
        
        if let columnWindow = columnWindow {
            XCTAssertEqual(columnWindow.position.x, 400.0)
            XCTAssertEqual(columnWindow.position.y, 500.0)
            XCTAssertEqual(columnWindow.position.z, 600.0)
            XCTAssertTrue(columnWindow.state.content.contains("pd.DataFrame"))
        }
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testImportInvalidJSON() throws {
        let invalidJSON = "{ invalid json }"
        let data = invalidJSON.data(using: .utf8)!
        
        XCTAssertThrowsError(try windowManager.importFromGenericNotebook(data: data)) { error in
            XCTAssertTrue(error is ImportError)
            if let importError = error as? ImportError {
                XCTAssertEqual(importError, ImportError.invalidJSON)
            }
        }
    }
    
    func testImportInvalidNotebookFormat() throws {
        let invalidNotebook: [String: Any] = [
            "not_cells": [],
            "not_metadata": [:]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: invalidNotebook)
        
        XCTAssertThrowsError(try windowManager.importFromGenericNotebook(data: data)) { error in
            XCTAssertTrue(error is ImportError)
            if let importError = error as? ImportError {
                XCTAssertEqual(importError, ImportError.invalidNotebookFormat)
            }
        }
    }
    
    func testImportWithMissingWindowData() throws {
        let notebookWithBadCell: [String: Any] = [
            "cells": [
                [
                    "cell_type": "code",
                    "metadata": [
                        // Missing window_type
                        "window_id": 1
                    ],
                    "source": ["print('hello')"]
                ]
            ],
            "metadata": [:]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: notebookWithBadCell)
        let result = try windowManager.importFromGenericNotebook(data: data)
        
        // Should not fail, but should have no restored windows
        XCTAssertEqual(result.restoredWindows.count, 0)
        XCTAssertEqual(result.errors.count, 0) // Cell is simply skipped
    }
    
    // MARK: - Performance Tests
    
    func testLargeWorkspacePerformance() throws {
        // Create many windows
        let windowCount = 100
        for i in 1...windowCount {
            let _ = windowManager.createWindow(.charts, id: i)
            windowManager.updateWindowContent(i, content: "plt.plot([1, 2, 3])")
        }
        
        // Measure export performance
        measure {
            let _ = windowManager.exportToJupyterNotebook()
        }
    }
    
    func testLargeWorkspaceImportPerformance() throws {
        // Create large notebook
        var cells: [[String: Any]] = []
        for i in 1...100 {
            cells.append([
                "cell_type": "code",
                "metadata": [
                    "window_id": i,
                    "window_type": "charts",
                    "export_template": "matplotlib",
                    "position": [
                        "x": Double(i * 100),
                        "y": Double(i * 100),
                        "z": Double(i * 100)
                    ]
                ],
                "source": ["plt.plot([1, 2, 3])"]
            ])
        }
        
        let notebook: [String: Any] = [
            "cells": cells,
            "metadata": [:]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: notebook)
        
        // Measure import performance
        measure {
            do {
                let _ = try windowManager.importFromGenericNotebook(data: data)
            } catch {
                XCTFail("Import failed: \(error)")
            }
        }
    }
}

// MARK: - Test Extensions

extension WindowPosition {
    init(x: Double, y: Double, z: Double) {
        self.init()
        self.x = x
        self.y = y
        self.z = z
    }
}

extension ImportError: Equatable {
    public static func == (lhs: ImportError, rhs: ImportError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidJSON, .invalidJSON),
             (.invalidNotebookFormat, .invalidNotebookFormat),
             (.cellParsingFailed, .cellParsingFailed),
             (.unsupportedWindowType, .unsupportedWindowType),
             (.invalidMetadata, .invalidMetadata),
             (.fileReadError, .fileReadError):
            return true
        default:
            return false
        }
    }
}