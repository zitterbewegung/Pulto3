//
//  AutoSaveIntegrationTests.swift
//  PultoTests
//
//  Integration tests for auto-save functionality
//

import XCTest
import Foundation
@testable import Pulto

@MainActor
class AutoSaveIntegrationTests: XCTestCase {
    
    var windowManager: WindowTypeManager!
    var autoSaveManager: AutoSaveManager!
    
    override func setUp() {
        super.setUp()
        windowManager = WindowTypeManager.shared
        autoSaveManager = AutoSaveManager.shared
        
        // Reset state
        windowManager.clearAllWindows()
        autoSaveManager.updateSettings(
            autoSaveEnabled: true,
            saveToLocalFiles: true,
            jupyterServerAutoSave: false
        )
    }
    
    override func tearDown() {
        autoSaveManager.stopAutoSave()
        windowManager.clearAllWindows()
        super.tearDown()
    }
    
    func testWindowFocusAutoSave() async {
        // Start auto-save system
        autoSaveManager.startAutoSave()
        
        // Create a window
        let window = windowManager.createWindow(.charts, id: 1)
        windowManager.updateWindowContent(1, content: "Test chart content")
        
        // Simulate window opening (gaining focus)
        windowManager.markWindowAsOpened(1)
        
        // Simulate window losing focus
        NotificationCenter.default.post(
            name: .windowFocusLost,
            object: nil,
            userInfo: ["windowID": 1]
        )
        
        // Allow time for auto-save to process
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Check that auto-save was triggered
        XCTAssertNotNil(autoSaveManager.lastSaveTime)
        XCTAssertFalse(autoSaveManager.lastSaveResults.isEmpty)
        
        // Check that save was successful
        let lastResult = autoSaveManager.lastSaveResults.last
        XCTAssertNotNil(lastResult)
        XCTAssertTrue(lastResult?.success ?? false)
        XCTAssertEqual(lastResult?.destination, .localFile)
        XCTAssertEqual(lastResult?.windowID, 1)
    }
    
    func testWindowMovementAutoSave() async {
        // Start auto-save system
        autoSaveManager.startAutoSave()
        
        // Create a window
        let window = windowManager.createWindow(.spatial, id: 2)
        windowManager.updateWindowContent(2, content: "Test spatial content")
        
        // Simulate window movement
        let newPosition = WindowPosition(x: 100, y: 200, z: 300)
        windowManager.updateWindowPosition(2, position: newPosition)
        
        // Allow time for debouncing and auto-save
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Check that auto-save was triggered
        XCTAssertNotNil(autoSaveManager.lastSaveTime)
        XCTAssertFalse(autoSaveManager.lastSaveResults.isEmpty)
        
        // Check that save was successful
        let lastResult = autoSaveManager.lastSaveResults.last
        XCTAssertNotNil(lastResult)
        XCTAssertTrue(lastResult?.success ?? false)
        XCTAssertEqual(lastResult?.destination, .localFile)
        XCTAssertEqual(lastResult?.windowID, 2)
    }
    
    func testContentChangeAutoSave() async {
        // Start auto-save system
        autoSaveManager.startAutoSave()
        
        // Create a window
        let window = windowManager.createWindow(.column, id: 3)
        
        // Update content
        windowManager.updateWindowContent(3, content: "import pandas as pd\ndf = pd.DataFrame()")
        
        // Allow time for auto-save to process
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Check that auto-save was triggered
        XCTAssertNotNil(autoSaveManager.lastSaveTime)
        XCTAssertFalse(autoSaveManager.lastSaveResults.isEmpty)
        
        // Check that save was successful
        let lastResult = autoSaveManager.lastSaveResults.last
        XCTAssertNotNil(lastResult)
        XCTAssertTrue(lastResult?.success ?? false)
        XCTAssertEqual(lastResult?.destination, .localFile)
        XCTAssertEqual(lastResult?.windowID, 3)
    }
    
    func testManualSaveOverride() async {
        // Start auto-save system
        autoSaveManager.startAutoSave()
        
        // Create multiple windows
        let window1 = windowManager.createWindow(.charts, id: 1)
        let window2 = windowManager.createWindow(.spatial, id: 2)
        let window3 = windowManager.createWindow(.column, id: 3)
        
        // Add content to windows
        windowManager.updateWindowContent(1, content: "Chart content")
        windowManager.updateWindowContent(2, content: "Spatial content")
        windowManager.updateWindowContent(3, content: "DataFrame content")
        
        // Trigger manual save
        await autoSaveManager.triggerManualSave()
        
        // Check that save was successful
        XCTAssertNotNil(autoSaveManager.lastSaveTime)
        XCTAssertFalse(autoSaveManager.lastSaveResults.isEmpty)
        
        // Manual save should be successful
        let lastResult = autoSaveManager.lastSaveResults.last
        XCTAssertNotNil(lastResult)
        XCTAssertTrue(lastResult?.success ?? false)
        XCTAssertEqual(lastResult?.destination, .localFile)
        XCTAssertNil(lastResult?.windowID) // Manual save affects all windows
    }
    
    func testAutoSaveDisabled() async {
        // Disable auto-save
        autoSaveManager.updateSettings(autoSaveEnabled: false)
        
        // Create a window
        let window = windowManager.createWindow(.charts, id: 1)
        windowManager.updateWindowContent(1, content: "Test content")
        
        // Simulate window focus loss
        NotificationCenter.default.post(
            name: .windowFocusLost,
            object: nil,
            userInfo: ["windowID": 1]
        )
        
        // Allow time
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Check that auto-save was NOT triggered
        XCTAssertNil(autoSaveManager.lastSaveTime)
        XCTAssertTrue(autoSaveManager.lastSaveResults.isEmpty)
    }
    
    func testMultipleWindowsAutoSave() async {
        // Start auto-save system
        autoSaveManager.startAutoSave()
        
        // Create multiple windows
        let windows = [
            (1, WindowType.charts, "Chart data"),
            (2, WindowType.spatial, "Spatial data"),
            (3, WindowType.column, "DataFrame data"),
            (4, WindowType.volume, "Volume data"),
            (5, WindowType.model3d, "3D model data")
        ]
        
        for (id, type, content) in windows {
            let window = windowManager.createWindow(type, id: id)
            windowManager.updateWindowContent(id, content: content)
        }
        
        // Trigger manual save
        await autoSaveManager.triggerManualSave()
        
        // Check that all windows were saved
        XCTAssertNotNil(autoSaveManager.lastSaveTime)
        XCTAssertFalse(autoSaveManager.lastSaveResults.isEmpty)
        
        // Verify the notebook contains all windows
        let notebookJSON = windowManager.exportToJupyterNotebook()
        XCTAssertTrue(notebookJSON.contains("Chart data"))
        XCTAssertTrue(notebookJSON.contains("Spatial data"))
        XCTAssertTrue(notebookJSON.contains("DataFrame data"))
        XCTAssertTrue(notebookJSON.contains("Volume data"))
        XCTAssertTrue(notebookJSON.contains("3D model data"))
    }
}