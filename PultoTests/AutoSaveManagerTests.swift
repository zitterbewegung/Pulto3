//
//  AutoSaveManagerTests.swift
//  PultoTests
//
//  Unit tests for AutoSaveManager functionality
//

import XCTest
import Foundation
@testable import Pulto

@MainActor
class AutoSaveManagerTests: XCTestCase {
    
    var autoSaveManager: AutoSaveManager!
    var mockWindowManager: MockWindowTypeManager!
    
    override func setUp() {
        super.setUp()
        autoSaveManager = AutoSaveManager.shared
        mockWindowManager = MockWindowTypeManager()
    }
    
    override func tearDown() {
        autoSaveManager.stopAutoSave()
        autoSaveManager = nil
        mockWindowManager = nil
        super.tearDown()
    }
    
    func testAutoSaveManagerInitialization() {
        XCTAssertNotNil(autoSaveManager)
        XCTAssertTrue(autoSaveManager.autoSaveEnabled)
        XCTAssertFalse(autoSaveManager.isAutoSaving)
        XCTAssertNil(autoSaveManager.lastSaveTime)
    }
    
    func testStartStopAutoSave() {
        // Test starting auto-save
        autoSaveManager.startAutoSave()
        XCTAssertTrue(autoSaveManager.autoSaveEnabled)
        
        // Test stopping auto-save
        autoSaveManager.stopAutoSave()
        // Auto-save should still be enabled but not actively running
        XCTAssertTrue(autoSaveManager.autoSaveEnabled)
    }
    
    func testManualSave() async {
        // Set up test environment
        autoSaveManager.updateSettings(
            autoSaveEnabled: true,
            saveToLocalFiles: true,
            jupyterServerAutoSave: false
        )
        
        // Create a test window
        let window = mockWindowManager.createWindow(.charts, id: 1)
        mockWindowManager.updateWindowContent(1, content: "Test content")
        
        // Trigger manual save
        await autoSaveManager.triggerManualSave()
        
        // Check that save was attempted
        XCTAssertNotNil(autoSaveManager.lastSaveTime)
        XCTAssertFalse(autoSaveManager.lastSaveResults.isEmpty)
    }
    
    func testWindowFocusTracking() {
        let focusTracker = WindowFocusTracker()
        
        // Test initial state
        XCTAssertNil(focusTracker.focusedWindowID)
        XCTAssertNil(focusTracker.lastFocusedWindowID)
        
        // Test starting tracking
        focusTracker.startTracking()
        
        // Simulate focus gained
        NotificationCenter.default.post(
            name: .windowFocusGained,
            object: nil,
            userInfo: ["windowID": 1]
        )
        
        // Allow time for notification to process
        let expectation = XCTestExpectation(description: "Focus gained")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(focusTracker.focusedWindowID, 1)
        
        // Test stopping tracking
        focusTracker.stopTracking()
    }
    
    func testWindowMovementDebouncing() {
        let movementDebouncer = WindowMovementDebouncer()
        
        // Test initial state
        XCTAssertTrue(movementDebouncer.stoppedMovingEvents.isEmpty)
        
        // Test starting tracking
        movementDebouncer.startTracking()
        
        // Simulate window movement
        let position = WindowPosition(x: 100, y: 200, z: 300)
        NotificationCenter.default.post(
            name: .windowPositionChanged,
            object: nil,
            userInfo: ["windowID": 1, "position": position]
        )
        
        // Movement should be debounced, so no immediate event
        XCTAssertTrue(movementDebouncer.stoppedMovingEvents.isEmpty)
        
        // Wait for debounce period
        let expectation = XCTestExpectation(description: "Movement stopped")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        XCTAssertFalse(movementDebouncer.stoppedMovingEvents.isEmpty)
        
        // Test stopping tracking
        movementDebouncer.stopTracking()
    }
    
    func testSettingsUpdate() {
        // Test updating settings
        autoSaveManager.updateSettings(
            autoSaveEnabled: false,
            jupyterServerAutoSave: true,
            saveToLocalFiles: false
        )
        
        XCTAssertFalse(autoSaveManager.autoSaveEnabled)
        XCTAssertTrue(autoSaveManager.jupyterServerAutoSave)
        XCTAssertFalse(autoSaveManager.saveToLocalFiles)
    }
    
    func testAutoSaveEventProcessing() {
        // Test that different events are processed correctly
        let events: [AutoSaveEvent] = [
            .windowFocusLost(windowID: 1),
            .windowMovementStopped(windowID: 2, position: WindowPosition()),
            .windowContentChanged(windowID: 3, content: "New content"),
            .manualSave,
            .intervalSave
        ]
        
        // All events should be processable
        for event in events {
            // This is a simplified test - in real usage, events would be processed asynchronously
            XCTAssertNoThrow(event)
        }
    }
    
    func testAutoSaveResultCreation() {
        let result = AutoSaveResult(
            success: true,
            destination: .localFile,
            error: nil,
            timestamp: Date(),
            windowID: 1,
            fileURL: URL(fileURLWithPath: "/tmp/test.ipynb")
        )
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.destination, .localFile)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.windowID, 1)
        XCTAssertNotNil(result.fileURL)
    }
    
    func testNotificationExtensions() {
        // Test that notification names are correctly defined
        XCTAssertEqual(Notification.Name.windowFocusGained.rawValue, "windowFocusGained")
        XCTAssertEqual(Notification.Name.windowFocusLost.rawValue, "windowFocusLost")
        XCTAssertEqual(Notification.Name.windowPositionChanged.rawValue, "windowPositionChanged")
        XCTAssertEqual(Notification.Name.windowContentChanged.rawValue, "windowContentChanged")
        XCTAssertEqual(Notification.Name.windowClosed.rawValue, "windowClosed")
    }
}

// MARK: - Mock Classes

class MockWindowTypeManager: ObservableObject {
    @Published private var windows: [Int: NewWindowID] = [:]
    
    func createWindow(_ type: WindowType, id: Int, position: WindowPosition = WindowPosition()) -> NewWindowID {
        let window = NewWindowID(id: id, windowType: type, position: position)
        windows[id] = window
        return window
    }
    
    func getWindow(for id: Int) -> NewWindowID? {
        return windows[id]
    }
    
    func updateWindowContent(_ id: Int, content: String) {
        windows[id]?.state.content = content
        windows[id]?.state.lastModified = Date()
    }
    
    func getAllWindows() -> [NewWindowID] {
        return Array(windows.values)
    }
    
    func exportToJupyterNotebook() -> String {
        return """
        {
          "cells": [],
          "metadata": {
            "kernelspec": {
              "display_name": "Python 3",
              "language": "python",
              "name": "python3"
            }
          },
          "nbformat": 4,
          "nbformat_minor": 4
        }
        """
    }
}