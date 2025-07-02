/*import XCTest
import SwiftUI
@testable import YourAppName

// MARK: - Unit Tests for Data Structures

class NotebookDataStructureTests: XCTestCase {
    
    func testJupyterNotebookCodable() throws {
        let notebook = JupyterNotebook(
            nbformat: 4,
            nbformatMinor: 4,
            cells: [],
            metadata: NotebookMetadata(
                visionosExport: VisionOSExportMetadata(
                    exportDate: Date(),
                    totalWindows: 1,
                    windowTypes: ["Charts"],
                    exportTemplates: ["Matplotlib Chart"],
                    allTags: ["test"]
                ),
                chartPositions: ["chart1": ["x": 100, "y": 200]]
            )
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(notebook)
        
        let decoder = JSONDecoder()
        let decodedNotebook = try decoder.decode(JupyterNotebook.self, from: data)
        
        XCTAssertEqual(notebook.nbformat, decodedNotebook.nbformat)
        XCTAssertEqual(notebook.metadata.chartPositions?["chart1"]?["x"], 100)
    }
    
    func testSpatialMetadataValidation() throws {
        let metadata = CellMetadata(
            windowId: 1001,
            windowType: "Spatial",
            position: WindowPosition(x: -150, y: 100, z: -50, width: 500, height: 300),
            state: WindowState(minimized: false, maximized: false, opacity: 1.0),
            exportTemplate: "Markdown Only",
            tags: ["test", "spatial"]
        )
        
        XCTAssertEqual(metadata.windowId, 1001)
        XCTAssertEqual(metadata.position?.x, -150)
        XCTAssertEqual(metadata.state?.opacity, 1.0)
    }
}

// MARK: - File I/O Tests

class NotebookFileIOTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testNotebookFileSaving() throws {
        let testNotebook = createTestNotebook()
        let fileURL = tempDirectory.appendingPathComponent("test.ipynb")
        
        // Save notebook
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(testNotebook)
        try data.write(to: fileURL)
        
        // Verify file exists and is readable
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        let loadedData = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        let loadedNotebook = try decoder.decode(JupyterNotebook.self, from: loadedData)
        
        XCTAssertEqual(testNotebook.cells.count, loadedNotebook.cells.count)
    }
    
    func testChartPositionPersistence() throws {
        let chartPositions: [String: [String: CGFloat]] = [
            "chart1": ["x": 150.0, "y": -75.0],
            "chart2": ["x": -200.0, "y": 100.0]
        ]
        
        var notebookDict: [String: Any] = [
            "nbformat": 4,
            "nbformat_minor": 4,
            "cells": [],
            "metadata": [:]
        ]
        
        // Simulate the metadata injection process
        if var metadata = notebookDict["metadata"] as? [String: Any] {
            metadata["chartPositions"] = chartPositions
            notebookDict["metadata"] = metadata
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: notebookDict, options: .prettyPrinted)
        
        // Write and read back
        let fileURL = tempDirectory.appendingPathComponent("positions.ipynb")
        try jsonData.write(to: fileURL)
        
        let loadedData = try Data(contentsOf: fileURL)
        let loadedDict = try JSONSerialization.jsonObject(with: loadedData) as! [String: Any]
        let loadedMetadata = loadedDict["metadata"] as! [String: Any]
        let loadedPositions = loadedMetadata["chartPositions"] as! [String: [String: CGFloat]]
        
        XCTAssertEqual(loadedPositions["chart1"]?["x"], 150.0)
        XCTAssertEqual(loadedPositions["chart2"]?["y"], 100.0)
    }
    
    private func createTestNotebook() -> JupyterNotebook {
        return JupyterNotebook(
            nbformat: 4,
            nbformatMinor: 4,
            cells: [
                Cell(
                    cellType: "code",
                    metadata: CellMetadata(windowId: 1, windowType: "Charts"),
                    source: ["print('test')"],
                    executionCount: 1,
                    outputs: []
                )
            ],
            metadata: NotebookMetadata()
        )
    }
}

// MARK: - Network/Backend Integration Tests

class NotebookBackendTests: XCTestCase {
    let mockServerURL = "http://localhost:8000" // Use a test server
    
    func testNotebookUploadRequest() async throws {
        let testNotebook = createMockNotebook()
        let encoder = JSONEncoder()
        let notebookData = try encoder.encode(testNotebook)
        
        guard let url = URL(string: "\(mockServerURL)/convert/test") else {
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"notebook.ipynb\"\r\n")
        body.append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(notebookData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        request.httpBody = body
        
        // For testing, you'd mock this or use a test server
        // let (data, response) = try await URLSession.shared.data(for: request)
        // Validate response format, status codes, etc.
    }
    
    func testSpatialMetadataAPI() async throws {
        let spatial = SpatialMetadata(x: 1, y: 2, z: 3, pitch: 0, yaw: 45, roll: 0)
        
        guard let url = URL(string: "\(mockServerURL)/notebooks/test/cells/0/spatial") else {
            XCTFail("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(spatial)
        
        // Test the request structure
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertNotNil(request.httpBody)
    }
    
    private func createMockNotebook() -> JupyterNotebook {
        return JupyterNotebook(
            nbformat: 4,
            nbformatMinor: 4,
            cells: [],
            metadata: NotebookMetadata()
        )
    }
}

// MARK: - UI Integration Tests

class NotebookChartsViewTests: XCTestCase {
    
    func testChartOffsetCapture() {
        let chartOffsets: [String: CGSize] = [
            "chart1": CGSize(width: 100, height: -50),
            "chart2": CGSize(width: -75, height: 200)
        ]
        
        // Simulate the conversion to chartPositions format
        let chartPositions: [String: [String: CGFloat]] = chartOffsets.mapValues { size in
            ["x": size.width, "y": size.height]
        }
        
        XCTAssertEqual(chartPositions["chart1"]?["x"], 100)
        XCTAssertEqual(chartPositions["chart1"]?["y"], -50)
        XCTAssertEqual(chartPositions["chart2"]?["x"], -75)
        XCTAssertEqual(chartPositions["chart2"]?["y"], 200)
    }
    
    func testNotebookDocumentsDirectorySetup() {
        let fileManager = FileManager.default
        guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            XCTFail("Failed to locate Documents directory")
            return
        }
        
        let notebookURL = docsURL.appendingPathComponent("notebook.ipynb")
        
        // Test the logic from ensureNotebookExistsInDocuments
        if !fileManager.fileExists(atPath: notebookURL.path) {
            if let bundleURL = Bundle.main.url(forResource: "notebook", withExtension: "ipynb") {
                // Would copy file in real implementation
                XCTAssertTrue(fileManager.fileExists(atPath: bundleURL.path))
            }
        }
    }
}

// MARK: - End-to-End Integration Tests

class NotebookSaveLoadCycleTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testCompleteNotebookSaveLoadCycle() throws {
        // 1. Create a notebook with spatial data
        let originalNotebook = createCompleteTestNotebook()
        
        // 2. Save to file (simulating the local save)
        let fileURL = tempDirectory.appendingPathComponent("test_cycle.ipynb")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(originalNotebook)
        try data.write(to: fileURL)
        
        // 3. Load from file
        let loadedData = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        let loadedNotebook = try decoder.decode(JupyterNotebook.self, from: loadedData)
        
        // 4. Verify spatial metadata preservation
        let firstCell = loadedNotebook.cells[0]
        XCTAssertEqual(firstCell.metadata?.windowId, 1001)
        XCTAssertEqual(firstCell.metadata?.position?.x, -150.0)
        XCTAssertEqual(firstCell.metadata?.state?.opacity, 1.0)
        
        // 5. Verify chart positions
        XCTAssertNotNil(loadedNotebook.metadata.chartPositions)
        XCTAssertEqual(loadedNotebook.metadata.chartPositions?["chart1"]?["x"], 120.0)
    }
    
    func testNotebookMetadataInjection() throws {
        // Simulate the metadata injection process from sendNotebookJSON
        let originalDict: [String: Any] = [
            "nbformat": 4,
            "nbformat_minor": 4,
            "cells": [],
            "metadata": [:]
        ]
        
        let chartPositions: [String: [String: CGFloat]] = [
            "chart1": ["x": 150.0, "y": -100.0]
        ]
        
        var updatedDict = originalDict
        if var metadata = updatedDict["metadata"] as? [String: Any] {
            metadata["chartPositions"] = chartPositions
            updatedDict["metadata"] = metadata
        } else {
            updatedDict["metadata"] = ["chartPositions": chartPositions]
        }
        
        // Verify the injection worked
        let metadata = updatedDict["metadata"] as! [String: Any]
        let positions = metadata["chartPositions"] as! [String: [String: CGFloat]]
        XCTAssertEqual(positions["chart1"]?["x"], 150.0)
    }
    
    private func createCompleteTestNotebook() -> JupyterNotebook {
        return JupyterNotebook(
            nbformat: 4,
            nbformatMinor: 4,
            cells: [
                Cell(
                    cellType: "markdown",
                    metadata: CellMetadata(
                        windowId: 1001,
                        windowType: "Spatial",
                        position: WindowPosition(x: -150, y: 100, z: -50, width: 500, height: 300),
                        state: WindowState(minimized: false, maximized: false, opacity: 1.0),
                        exportTemplate: "Markdown Only",
                        tags: ["introduction", "spatial"]
                    ),
                    source: ["# Test Notebook"],
                    executionCount: nil,
                    outputs: []
                )
            ],
            metadata: NotebookMetadata(
                visionosExport: VisionOSExportMetadata(
                    exportDate: Date(),
                    totalWindows: 1,
                    windowTypes: ["Spatial"],
                    exportTemplates: ["Markdown Only"],
                    allTags: ["introduction", "spatial"]
                ),
                chartPositions: ["chart1": ["x": 120.0, "y": -80.0]]
            )
        )
    }
}

// MARK: - Performance Tests

class NotebookPerformanceTests: XCTestCase {
    
    func testLargeNotebookSerialization() {
        measure {
            let largeNotebook = createLargeNotebook(cellCount: 1000)
            let encoder = JSONEncoder()
            _ = try! encoder.encode(largeNotebook)
        }
    }
    
    func testChartPositionProcessing() {
        let largeChartOffsets = (0..<1000).reduce(into: [String: CGSize]()) { result, index in
            result["chart_\(index)"] = CGSize(width: Double(index), height: Double(index * 2))
        }
        
        measure {
            let _ = largeChartOffsets.mapValues { size in
                ["x": size.width, "y": size.height]
            }
        }
    }
    
    private func createLargeNotebook(cellCount: Int) -> JupyterNotebook {
        let cells = (0..<cellCount).map { index in
            Cell(
                cellType: "code",
                metadata: CellMetadata(windowId: index, windowType: "Charts"),
                source: ["print(\(index))"],
                executionCount: index,
                outputs: []
            )
        }
        
        return JupyterNotebook(
            nbformat: 4,
            nbformatMinor: 4,
            cells: cells,
            metadata: NotebookMetadata()
        )
    }
}

// MARK: - Mock Backend for Testing

class MockNotebookBackend {
    static func startMockServer() {
        // Implementation for a simple HTTP mock server
        // Could use frameworks like Embassy or create simple responses
    }
    
    static func createMockResponse(for notebook: Data) -> Data {
        // Return mock chart images or updated notebook
        let mockResponse = ["chart1": ["base64encodedimage"]]
        return try! JSONSerialization.data(withJSONObject: mockResponse)
    }
}

// MARK: - Helper Extensions

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}
*/
