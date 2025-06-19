//
//  NotebookTestFixtures.swift
//  Pulto
//
//  Created by Joshua Herman on 6/17/25.
//  Copyright © 2025 Apple. All rights reserved.
//

/*
import XCTest
import Foundation
import SwiftUI
@testable import UnderstandingVisionos

// MARK: - Test Fixtures and Helpers

class NotebookTestFixtures {
    
    static let sampleNotebookJSON = """
    {
      "cells": [
        {
          "cell_type": "markdown",
          "metadata": {
            "window_id": 1001,
            "window_type": "Spatial",
            "export_template": "Markdown Only",
            "tags": ["introduction", "spatial"],
            "position": {
              "x": -150.0,
              "y": 100.0,
              "z": -50.0,
              "width": 500.0,
              "height": 300.0,
              "depth": 10.0
            },
            "state": {
              "minimized": false,
              "maximized": false,
              "opacity": 1.0
            },
            "timestamps": {
              "created": "2025-06-17T10:30:00Z",
              "modified": "2025-06-17T10:45:00Z"
            }
          },
          "source": [
            "# Test Markdown Window\\n",
            "This is a test markdown cell."
          ],
          "execution_count": null,
          "outputs": []
        },
        {
          "cell_type": "code",
          "metadata": {
            "window_id": 1002,
            "window_type": "Charts",
            "export_template": "Matplotlib Chart",
            "tags": ["visualization", "matplotlib"],
            "position": {
              "x": 200.0,
              "y": 50.0,
              "z": 0.0,
              "width": 600.0,
              "height": 450.0
            },
            "state": {
              "minimized": false,
              "maximized": false,
              "opacity": 0.95
            },
            "timestamps": {
              "created": "2025-06-17T10:31:00Z",
              "modified": "2025-06-17T10:50:00Z"
            }
          },
          "source": [
            "import matplotlib.pyplot as plt\\n",
            "import numpy as np\\n",
            "plt.plot([1, 2, 3], [4, 5, 6])\\n",
            "plt.show()"
          ],
          "execution_count": 1,
          "outputs": []
        }
      ],
      "metadata": {
        "kernelspec": {
          "display_name": "Python 3",
          "language": "python",
          "name": "python3"
        },
        "language_info": {
          "name": "python",
          "version": "3.8.0"
        },
        "visionos_export": {
          "export_date": "2025-06-17T10:55:00Z",
          "total_windows": 2,
          "window_types": ["Charts", "Spatial"],
          "export_templates": ["Matplotlib Chart", "Markdown Only"],
          "all_tags": ["introduction", "spatial", "visualization", "matplotlib"]
        },
        "chartPositions": {
          "chartKey_001": {
            "x": 120.0,
            "y": -80.0
          },
          "chartKey_002": {
            "x": -90.0,
            "y": 45.0
          }
        }
      },
      "nbformat": 4,
      "nbformat_minor": 4
    }
    """
    
    static let invalidNotebookJSON = """
    {
      "cells": "invalid",
      "metadata": {},
      "nbformat": "not_a_number"
    }
    """
    
    static let emptyNotebookJSON = """
    {
      "cells": [],
      "metadata": {},
      "nbformat": 4,
      "nbformat_minor": 4
    }
    """
    
    static func createSampleNotebookFile(in directory: URL, named filename: String) throws -> URL {
        let fileURL = directory.appendingPathComponent(filename)
        try sampleNotebookJSON.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    static func createInvalidNotebookFile(in directory: URL, named filename: String) throws -> URL {
        let fileURL = directory.appendingPathComponent(filename)
        try invalidNotebookJSON.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}

// MARK: - Mock Window Manager for Testing

class MockWindowTypeManager: ObservableObject {
    @Published private var windows: [Int: NewWindowID] = [:]
    private var nextWindowID = 1000
    
    func createWindow(_ type: WindowType, id: Int, position: WindowPosition = WindowPosition()) -> NewWindowID {
        let window = NewWindowID(id: id, windowType: type, position: position)
        windows[id] = window
        return window
    }
    
    func getWindow(for id: Int) -> NewWindowID? {
        return windows[id]
    }
    
    func updateWindowState(_ id: Int, state: WindowState) {
        windows[id]?.state = state
    }
    
    func updateWindowContent(_ id: Int, content: String) {
        windows[id]?.state.content = content
    }
    
    func getAllWindows() -> [NewWindowID] {
        return Array(windows.values).sorted { $0.id < $1.id }
    }
    
    func clearAllWindows() {
        windows.removeAll()
    }
    
    func getWindowCount() -> Int {
        return windows.count
    }
}

// MARK: - Main Test Suite

class VisionOSNotebookTests: XCTestCase {
    
    var tempDirectory: URL!
    var mockWindowManager: MockWindowTypeManager!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VisionOSNotebookTests_\(UUID().uuidString)")
        
        try! FileManager.default.createDirectory(at: tempDirectory, 
                                                withIntermediateDirectories: true, 
                                                attributes: nil)
        
        // Initialize mock window manager
        mockWindowManager = MockWindowTypeManager()
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        mockWindowManager = nil
        
        super.tearDown()
    }
    
    // MARK: - Notebook Parsing Tests
    
    func testNotebookJSONParsing() throws {
        // Test parsing valid notebook JSON
        let data = NotebookTestFixtures.sampleNotebookJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let notebook = try decoder.decode(JupyterNotebook.self, from: data)
        
        XCTAssertEqual(notebook.nbformat, 4)
        XCTAssertEqual(notebook.nbformatMinor, 4)
        XCTAssertEqual(notebook.cells.count, 2)
        
        // Test first cell (markdown)
        let firstCell = notebook.cells[0]
        XCTAssertEqual(firstCell.cellType, "markdown")
        XCTAssertEqual(firstCell.metadata?.windowId, 1001)
        XCTAssertEqual(firstCell.metadata?.windowType, "Spatial")
        XCTAssertEqual(firstCell.metadata?.exportTemplate, "Markdown Only")
        XCTAssertEqual(firstCell.metadata?.tags, ["introduction", "spatial"])
        
        // Test position data
        XCTAssertEqual(firstCell.metadata?.position?.x, -150.0)
        XCTAssertEqual(firstCell.metadata?.position?.y, 100.0)
        XCTAssertEqual(firstCell.metadata?.position?.z, -50.0)
        XCTAssertEqual(firstCell.metadata?.position?.width, 500.0)
        XCTAssertEqual(firstCell.metadata?.position?.height, 300.0)
        
        // Test state data
        XCTAssertEqual(firstCell.metadata?.state?.minimized, false)
        XCTAssertEqual(firstCell.metadata?.state?.maximized, false)
        XCTAssertEqual(firstCell.metadata?.state?.opacity, 1.0)
        
        // Test second cell (code)
        let secondCell = notebook.cells[1]
        XCTAssertEqual(secondCell.cellType, "code")
        XCTAssertEqual(secondCell.metadata?.windowId, 1002)
        XCTAssertEqual(secondCell.metadata?.windowType, "Charts")
        XCTAssertEqual(secondCell.metadata?.exportTemplate, "Matplotlib Chart")
        
        // Test metadata
        XCTAssertEqual(notebook.metadata.visionosExport?.totalWindows, 2)
        XCTAssertEqual(notebook.metadata.visionosExport?.windowTypes, ["Charts", "Spatial"])
        XCTAssertNotNil(notebook.metadata.chartPositions)
        XCTAssertEqual(notebook.metadata.chartPositions?["chartKey_001"]?["x"], 120.0)
    }
    
    func testInvalidNotebookJSONParsing() {
        let data = NotebookTestFixtures.invalidNotebookJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        XCTAssertThrowsError(try decoder.decode(JupyterNotebook.self, from: data)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    func testEmptyNotebookParsing() throws {
        let data = NotebookTestFixtures.emptyNotebookJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let notebook = try decoder.decode(JupyterNotebook.self, from: data)
        
        XCTAssertEqual(notebook.cells.count, 0)
        XCTAssertEqual(notebook.nbformat, 4)
        XCTAssertEqual(notebook.nbformatMinor, 4)
    }
    
    // MARK: - Window Type Conversion Tests
    
    func testWindowTypeMapping() {
        XCTAssertEqual(WindowType(rawValue: "Charts"), .charts)
        XCTAssertEqual(WindowType(rawValue: "Spatial"), .spatial)
        XCTAssertEqual(WindowType(rawValue: "DataFrame Viewer"), .column)
        XCTAssertEqual(WindowType(rawValue: "Model Metric Viewer"), .volume)
        XCTAssertNil(WindowType(rawValue: "InvalidType"))
    }
    
    func testExportTemplateMapping() {
        XCTAssertEqual(ExportTemplate(rawValue: "Matplotlib Chart"), .matplotlib)
        XCTAssertEqual(ExportTemplate(rawValue: "Pandas DataFrame"), .pandas)
        XCTAssertEqual(ExportTemplate(rawValue: "Markdown Only"), .markdown)
        XCTAssertEqual(ExportTemplate(rawValue: "Custom Code"), .custom)
        XCTAssertNil(ExportTemplate(rawValue: "InvalidTemplate"))
    }
    
    // MARK: - Window State Restoration Tests
    
    func testWindowStateRestoration() throws {
        let data = NotebookTestFixtures.sampleNotebookJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let notebook = try decoder.decode(JupyterNotebook.self, from: data)
        
        // Simulate window restoration process
        var restoredWindows: [NewWindowID] = []
        var nextWindowID = 1000
        
        for cell in notebook.cells {
            guard let metadata = cell.metadata,
                  let windowId = metadata.windowId,
                  let windowTypeString = metadata.windowType,
                  let windowType = WindowType(rawValue: windowTypeString) else {
                continue
            }
            
            let position = WindowPosition(
                x: metadata.position?.x ?? 0,
                y: metadata.position?.y ?? 0,
                z: metadata.position?.z ?? 0,
                width: metadata.position?.width ?? 400,
                height: metadata.position?.height ?? 300,
                depth: metadata.position?.depth
            )
            
            var state = WindowState()
            if let stateData = metadata.state {
                state.isMinimized = stateData.minimized
                state.isMaximized = stateData.maximized
                state.opacity = stateData.opacity
            }
            
            if let exportTemplateString = metadata.exportTemplate,
               let exportTemplate = ExportTemplate(rawValue: exportTemplateString) {
                state.exportTemplate = exportTemplate
            }
            
            state.tags = metadata.tags ?? []
            state.content = cell.source.joined(separator: "\n")
            
            let uniqueWindowId = nextWindowID
            nextWindowID += 1
            
            let window = mockWindowManager.createWindow(windowType, id: uniqueWindowId, position: position)
            mockWindowManager.updateWindowState(uniqueWindowId, state: state)
            
            restoredWindows.append(window)
        }
        
        // Verify restoration
        XCTAssertEqual(restoredWindows.count, 2)
        XCTAssertEqual(mockWindowManager.getWindowCount(), 2)
        
        // Check first restored window
        let firstWindow = restoredWindows[0]
        XCTAssertEqual(firstWindow.windowType, .spatial)
        XCTAssertEqual(firstWindow.position.x, -150.0)
        XCTAssertEqual(firstWindow.position.y, 100.0)
        XCTAssertEqual(firstWindow.position.z, -50.0)
        XCTAssertEqual(firstWindow.state.exportTemplate, .markdown)
        XCTAssertEqual(firstWindow.state.tags, ["introduction", "spatial"])
        XCTAssertTrue(firstWindow.state.content.contains("# Test Markdown Window"))
        
        // Check second restored window
        let secondWindow = restoredWindows[1]
        XCTAssertEqual(secondWindow.windowType, .charts)
        XCTAssertEqual(secondWindow.position.x, 200.0)
        XCTAssertEqual(secondWindow.position.y, 50.0)
        XCTAssertEqual(secondWindow.position.z, 0.0)
        XCTAssertEqual(secondWindow.state.exportTemplate, .matplotlib)
        XCTAssertEqual(secondWindow.state.opacity, 0.95)
        XCTAssertTrue(secondWindow.state.content.contains("matplotlib.pyplot"))
    }
    
    // MARK: - Chart Position Restoration Tests
    
    func testChartPositionRestoration() throws {
        let data = NotebookTestFixtures.sampleNotebookJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let notebook = try decoder.decode(JupyterNotebook.self, from: data)
        
        var chartOffsets: [String: CGSize] = [:]
        
        if let chartPositions = notebook.metadata.chartPositions {
            for (chartKey, position) in chartPositions {
                if let x = position["x"], let y = position["y"] {
                    chartOffsets[chartKey] = CGSize(width: x, height: y)
                }
            }
        }
        
        XCTAssertEqual(chartOffsets.count, 2)
        XCTAssertEqual(chartOffsets["chartKey_001"]?.width, 120.0)
        XCTAssertEqual(chartOffsets["chartKey_001"]?.height, -80.0)
        XCTAssertEqual(chartOffsets["chartKey_002"]?.width, -90.0)
        XCTAssertEqual(chartOffsets["chartKey_002"]?.height, 45.0)
    }
    
    // MARK: - File I/O Tests
    
    func testNotebookFileCreation() throws {
        let filename = "test_notebook.ipynb"
        let fileURL = try NotebookTestFixtures.createSampleNotebookFile(in: tempDirectory, named: filename)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        let fileData = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        let notebook = try decoder.decode(JupyterNotebook.self, from: fileData)
        
        XCTAssertEqual(notebook.cells.count, 2)
        XCTAssertEqual(notebook.nbformat, 4)
    }
    
    func testNotebookFileLoadingError() throws {
        let filename = "invalid_notebook.ipynb"
        let fileURL = try NotebookTestFixtures.createInvalidNotebookFile(in: tempDirectory, named: filename)
        
        let fileData = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        
        XCTAssertThrowsError(try decoder.decode(JupyterNotebook.self, from: fileData))
    }
    
    func testMissingNotebookFile() {
        let nonExistentURL = tempDirectory.appendingPathComponent("missing.ipynb")
        
        XCTAssertThrowsError(try Data(contentsOf: nonExistentURL)) { error in
            XCTAssertTrue(error is CocoaError)
        }
    }
    
    // MARK: - Metadata Validation Tests
    
    func testVisionOSExportMetadataValidation() throws {
        let data = NotebookTestFixtures.sampleNotebookJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let notebook = try decoder.decode(JupyterNotebook.self, from: data)
        
        guard let visionOSData = notebook.metadata.visionosExport else {
            XCTFail("VisionOS export metadata missing")
            return
        }
        
        XCTAssertNotNil(visionOSData.exportDate)
        XCTAssertEqual(visionOSData.totalWindows, 2)
        XCTAssertEqual(visionOSData.windowTypes?.count, 2)
        XCTAssertTrue(visionOSData.windowTypes?.contains("Charts") == true)
        XCTAssertTrue(visionOSData.windowTypes?.contains("Spatial") == true)
        XCTAssertEqual(visionOSData.exportTemplates?.count, 2)
        XCTAssertEqual(visionOSData.allTags?.count, 4)
        
        // Validate ISO8601 date format
        let formatter = ISO8601DateFormatter()
        if let dateString = visionOSData.exportDate {
            XCTAssertNotNil(formatter.date(from: dateString))
        }
    }
    
    func testCellMetadataValidation() throws {
        let data = NotebookTestFixtures.sampleNotebookJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let notebook = try decoder.decode(JupyterNotebook.self, from: data)
        
        for (index, cell) in notebook.cells.enumerated() {
            XCTAssertNotNil(cell.metadata, "Cell \(index) missing metadata")
            XCTAssertNotNil(cell.metadata?.windowId, "Cell \(index) missing window ID")
            XCTAssertNotNil(cell.metadata?.windowType, "Cell \(index) missing window type")
            XCTAssertNotNil(cell.metadata?.position, "Cell \(index) missing position data")
            XCTAssertNotNil(cell.metadata?.state, "Cell \(index) missing state data")
            XCTAssertNotNil(cell.metadata?.timestamps, "Cell \(index) missing timestamps")
            
            // Validate position bounds
            if let position = cell.metadata?.position {
                XCTAssertGreaterThanOrEqual(position.width, 100, "Cell \(index) width too small")
                XCTAssertGreaterThanOrEqual(position.height, 100, "Cell \(index) height too small")
                XCTAssertLessThanOrEqual(position.width, 2000, "Cell \(index) width too large")
                XCTAssertLessThanOrEqual(position.height, 2000, "Cell \(index) height too large")
            }
            
            // Validate state bounds
            if let state = cell.metadata?.state {
                XCTAssertGreaterThanOrEqual(state.opacity, 0.0, "Cell \(index) opacity below minimum")
                XCTAssertLessThanOrEqual(state.opacity, 1.0, "Cell \(index) opacity above maximum")
            }
        }
    }
    
    // MARK: - Export Generation Tests
    
    func testNotebookExportGeneration() throws {
        // Create sample windows in mock manager
        let window1 = mockWindowManager.createWindow(.charts, id: 2001, position: WindowPosition(x: 100, y: 200, z: 50, width: 500, height: 400))
        let window2 = mockWindowManager.createWindow(.spatial, id: 2002, position: WindowPosition(x: -100, y: 100, z: -25, width: 600, height: 350))
        
        // Update window states
        var state1 = WindowState()
        state1.exportTemplate = .matplotlib
        state1.tags = ["test", "chart"]
        state1.content = "plt.plot([1, 2, 3])"
        mockWindowManager.updateWindowState(2001, state: state1)
        
        var state2 = WindowState()
        state2.exportTemplate = .markdown
        state2.tags = ["spatial", "demo"]
        state2.content = "# Spatial Window"
        state2.opacity = 0.8
        mockWindowManager.updateWindowState(2002, state: state2)
        
        // Test export generation (would need actual WindowTypeManager implementation)
        let allWindows = mockWindowManager.getAllWindows()
        XCTAssertEqual(allWindows.count, 2)
        
        // Validate that we can create proper notebook structure
        let cells = allWindows.map { window -> [String: Any] in
            let cellType = window.windowType == .spatial && window.state.exportTemplate == .markdown ? "markdown" : "code"
            
            return [
                "cell_type": cellType,
                "metadata": [
                    "window_id": window.id,
                    "window_type": window.windowType.rawValue,
                    "export_template": window.state.exportTemplate.rawValue,
                    "tags": window.state.tags,
                    "position": [
                        "x": window.position.x,
                        "y": window.position.y,
                        "z": window.position.z,
                        "width": window.position.width,
                        "height": window.position.height
                    ],
                    "state": [
                        "minimized": window.state.isMinimized,
                        "maximized": window.state.isMaximized,
                        "opacity": window.state.opacity
                    ]
                ],
                "source": [window.state.content],
                "execution_count": NSNull(),
                "outputs": []
            ]
        }
        
        XCTAssertEqual(cells.count, 2)
        
        // Validate first cell structure
        let firstCell = cells[0]
        XCTAssertEqual(firstCell["cell_type"] as? String, "code")
        
        if let metadata = firstCell["metadata"] as? [String: Any] {
            XCTAssertEqual(metadata["window_id"] as? Int, 2001)
            XCTAssertEqual(metadata["window_type"] as? String, "Charts")
            XCTAssertEqual(metadata["export_template"] as? String, "Matplotlib Chart")
        }
    }
    
    // MARK: - Round-Trip Tests
    
    func testNotebookRoundTrip() throws {
        // Start with sample notebook
        let originalData = NotebookTestFixtures.sampleNotebookJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let originalNotebook = try decoder.decode(JupyterNotebook.self, from: originalData)
        
        // Encode back to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let encodedData = try encoder.encode(originalNotebook)
        
        // Decode again to verify consistency
        let roundTripNotebook = try decoder.decode(JupyterNotebook.self, from: encodedData)
        
        XCTAssertEqual(originalNotebook.nbformat, roundTripNotebook.nbformat)
        XCTAssertEqual(originalNotebook.nbformatMinor, roundTripNotebook.nbformatMinor)
        XCTAssertEqual(originalNotebook.cells.count, roundTripNotebook.cells.count)
        
        // Compare first cell metadata
        let originalCell = originalNotebook.cells[0]
        let roundTripCell = roundTripNotebook.cells[0]
        
        XCTAssertEqual(originalCell.metadata?.windowId, roundTripCell.metadata?.windowId)
        XCTAssertEqual(originalCell.metadata?.windowType, roundTripCell.metadata?.windowType)
        XCTAssertEqual(originalCell.metadata?.position?.x, roundTripCell.metadata?.position?.x)
        XCTAssertEqual(originalCell.metadata?.state?.opacity, roundTripCell.metadata?.state?.opacity)
    }
    
    // MARK: - Error Handling Tests
    
    func testCorruptedMetadataHandling() {
        let corruptedJSON = """
        {
          "cells": [
            {
              "cell_type": "code",
              "metadata": {
                "window_id": "invalid_id",
                "position": {
                  "x": "not_a_number"
                }
              },
              "source": ["test"],
              "execution_count": null,
              "outputs": []
            }
          ],
          "metadata": {},
          "nbformat": 4,
          "nbformat_minor": 4
        }
        """
        
        let data = corruptedJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        XCTAssertThrowsError(try decoder.decode(JupyterNotebook.self, from: data))
    }
    
    func testMissingRequiredFields() {
        let incompleteJSON = """
        {
          "cells": [
            {
              "cell_type": "code",
              "metadata": {
                "window_id": 1001
              },
              "source": ["test"]
            }
          ],
          "metadata": {},
          "nbformat": 4
        }
        """
        
        let data = incompleteJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // Should still parse, but with missing optional fields
        XCTAssertNoThrow(try decoder.decode(JupyterNotebook.self, from: data))
        
        let notebook = try! decoder.decode(JupyterNotebook.self, from: data)
        XCTAssertEqual(notebook.cells.count, 1)
        XCTAssertNil(notebook.cells[0].metadata?.windowType)
        XCTAssertNil(notebook.cells[0].metadata?.position)
    }
    
    // MARK: - Performance Tests
    
    func testLargeNotebookParsing() throws {
        // Generate a large notebook with many cells
        let cellTemplate = """
        {
          "cell_type": "code",
          "metadata": {
            "window_id": %d,
            "window_type": "Charts",
            "export_template": "Matplotlib Chart",
            "position": {
              "x": %f,
              "y": %f,
              "z": 0.0,
              "width": 400.0,
              "height": 300.0
            },
            "state": {
              "minimized": false,
              "maximized": false,
              "opacity": 1.0
            },
            "timestamps": {
              "created": "2025-06-17T10:30:00Z",
              "modified": "2025-06-17T10:45:00Z"
            }
          },
          "source": ["print('Cell %d')"],
          "execution_count": null,
          "outputs": []
        }
        """
        
        let numberOfCells = 100
        var cellsJSON: [String] = []
        
        for i in 0..<numberOfCells {
            let x = Double(i % 10) * 100.0
            let y = Double(i / 10) * 100.0
            let cellJSON = String(format: cellTemplate, i + 1000, x, y, i)
            cellsJSON.append(cellJSON)
        }
        
        let largeNotebookJSON = """
        {
          "cells": [\(cellsJSON.joined(separator: ","))],
          "metadata": {
            "visionos_export": {
              "total_windows": \(numberOfCells)
            }
          },
          "nbformat": 4,
          "nbformat_minor": 4
        }
        """
        
        measure {
            let data = largeNotebookJSON.data(using: .utf8)!
            let decoder = JSONDecoder()
            
            do {
                let notebook = try decoder.decode(JupyterNotebook.self, from: data)
                XCTAssertEqual(notebook.cells.count, numberOfCells)
            } catch {
                XCTFail("Failed to parse large notebook: \(error)")
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testNotebookChartsViewIntegration() throws {
        // This would test the actual NotebookChartsView if we had access to it
        // For now, we'll test the restoration logic
        
        let data = NotebookTestFixtures.sampleNotebookJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let notebook = try decoder.decode(JupyterNotebook.self, from: data)
        
        // Simulate the restoration process from NotebookChartsView
        var chartOffsets: [String: CGSize] = [:]
        var restoredWindows: [NewWindowID] = []
        
        // Restore chart positions
        if let chartPositions = notebook.metadata.chartPositions {
            for (chartKey, position) in chartPositions {
                if let x = position["x"], let y = position["y"] {
                    chartOffsets[chartKey] = CGSize(width: x, height: y)
                }
            }
        }
        
        // Restore windows
        for cell in notebook.cells {
            guard let metadata = cell.metadata,
                  let windowTypeString = metadata.windowType,
                  let windowType = WindowType(rawValue: windowTypeString) else {
                continue
            }
            
            let position = WindowPosition(
                x: metadata.position?.x ?? 0,
                y: metadata.position?.y ?? 0,
                z: metadata.position?.z ?? 0,
                width: metadata.position?.width ?? 400,
                height: metadata.position?.height ?? 300
            )
            
            let window = mockWindowManager.createWindow(windowType, id: 1000 + restoredWindows.count, position: position)
            restoredWindows.append(window)
        }
        
        // Verify integration
        XCTAssertEqual(chartOffsets.count, 2)
        XCTAssertEqual(restoredWindows.count, 2)
        XCTAssertEqual(mockWindowManager.getWindowCount(), 2)
        
        // Verify chart positions were restored correctly
        XCTAssertNotNil(chartOffsets["chartKey_001"])
        XCTAssertNotNil(chartOffsets["chartKey_002"])
        
        // Verify windows were restored with correct types
        let chartWindow = restoredWindows.first { $0.windowType == .charts }
        let spatialWindow = restoredWindows.first { $0.windowType == .spatial }
        
        XCTAssertNotNil(chartWindow)
        XCTAssertNotNil(spatialWindow)
        XCTAssertEqual(chartWindow?.position.x, 200.0)
        XCTAssertEqual(spatialWindow?.position.x, -150.0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyMetadataHandling() throws {
        let emptyMetadataJSON = """
        {
          "cells": [
            {
              "cell_type": "code",
              "metadata": {},
              "source": ["print('test')"],
              "execution_count": null,
              "outputs": []
            }
          ],
          "metadata": {},
          "nbformat": 4,
          "nbformat_minor": 4
        }
        """
        
        let data = emptyMetadataJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let notebook = try decoder.decode(JupyterNotebook.self, from: data)
        
        XCTAssertEqual(notebook.cells.count, 1)
        XCTAssertNil(notebook.cells[0].metadata?.windowId)
        XCTAssertNil(notebook.cells[0].metadata?.windowType)
    }
    
    func testUnicodeContentHandling() throws {
        let unicodeJSON = """
        {
          "cells": [
            {
              "cell_type": "markdown",
              "metadata": {
                "window_id": 1001,
                "window_type": "Spatial"
              },
              "source": ["# 🌟 Unicode Test 测试 🚀\\n", "Emoji and international characters: 🎯📊🔬"],
              "execution_count": null,
              "outputs": []
            }
          ],
          "metadata": {},
          "nbformat": 4,
          "nbformat_minor": 4
        }
        """
        
        let data = unicodeJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let notebook = try decoder.decode(JupyterNotebook.self, from: data)
        
        XCTAssertEqual(notebook.cells.count, 1)
        XCTAssertTrue(notebook.cells[0].source[0].contains("🌟"))
        XCTAssertTrue(notebook.cells[0].source[0].contains("测试"))
    }
}

// MARK: - Test Extensions

extension VisionOSNotebookTests {
    
    func createTestNotebook(withCells cellCount: Int) -> JupyterNotebook {
        var cells: [JupyterCell] = []
        
        for i in 0..<cellCount {
            let metadata = JupyterCell.CellMetadata(
                windowId: 1000 + i,
                windowType: i % 2 == 0 ? "Charts" : "Spatial",
                exportTemplate: i % 2 == 0 ? "Matplotlib Chart" : "Markdown Only",
                tags: ["test", "cell\(i)"],
                position: JupyterCell.CellMetadata.PositionData(
                    x: Double(i * 100),
                    y: Double(i * 50),
                    z: 0.0,
                    width: 400.0,
                    height: 300.0
                ),
                state: JupyterCell.CellMetadata.StateData(
                    minimized: false,
                    maximized: false,
                    opacity: 1.0
                ),
                timestamps: JupyterCell.CellMetadata.TimestampData(
                    created: "2025-06-17T10:30:00Z",
                    modified: "2025-06-17T10:45:00Z"
                )
            )
            
            let cell = JupyterCell(
                cellType: i % 2 == 0 ? "code" : "markdown",
                metadata: metadata,
                source: ["# Cell \(i)", "Content for cell \(i)"],
                executionCount: i % 2 == 0 ? i + 1 : nil,
                outputs: []
            )
            
            cells.append(cell)
        }
        
        let visionOSExport = NotebookMetadata.VisionOSExport(
            exportDate: "2025-06-17T10:55:00Z",
            totalWindows: cellCount,
            windowTypes: ["Charts", "Spatial"],
            exportTemplates: ["Matplotlib Chart", "Markdown Only"],
            allTags: ["test"]
        )
        
        let metadata = NotebookMetadata(
            visionosExport: visionOSExport
        )
        
        return JupyterNotebook(
            cells: cells,
            metadata: metadata,
            nbformat: 4,
            nbformatMinor: 4
        )
    }
}
*/
