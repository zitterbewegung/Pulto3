//
//  WindowTypeManagerExtension.swift
//  Pulto3
//
//  Extensions to WindowTypeManager for spatial integration compatibility
//  Created by Joshua Herman on 7/21/25.
//

import Foundation

// MARK: - WindowTypeManager Extensions for Spatial Integration

extension WindowTypeManager {
    
    // MARK: - Tag Management Methods
    
    /// Remove a specific tag from a window
    /// NOTE: You'll need to add this method to your main WindowTypeManager class:
    ///
    /// func removeWindowTag(_ windowID: Int, tag: String) {
    ///     guard var window = windows[windowID] else { return }
    ///     window.state.tags.removeAll { $0 == tag }
    ///     window.state.lastModified = Date()
    ///     windows[windowID] = window
    /// }
    
    /// Check if a window has a specific tag
    func windowHasTag(_ windowID: Int, tag: String) -> Bool {
        guard let window = getWindow(for: windowID) else { return false }
        return window.state.tags.contains(tag)
    }
    
    /// Get all tags for a window
    func getWindowTags(_ windowID: Int) -> [String] {
        guard let window = getWindow(for: windowID) else { return [] }
        return window.state.tags
    }
    
    /// Add multiple tags to a window
    func addWindowTags(_ windowID: Int, tags: [String]) {
        for tag in tags {
            addWindowTag(windowID, tag: tag)
        }
    }
    
    // MARK: - Bulk Operations
    
    /// Get all windows of a specific type
    func getWindowsOfType(_ windowType: WindowType) -> [NewWindowID] {
        return getAllWindows().filter { $0.windowType == windowType }
    }
    
    /// Get windows with specific tag
    func getWindowsWithTag(_ tag: String) -> [NewWindowID] {
        return getAllWindows().filter { $0.state.tags.contains(tag) }
    }
    
    // MARK: - Spatial Integration Helpers
    
    /// Mark a window as spatially enabled
    func markWindowAsSpatial(_ windowID: Int) {
        addWindowTag(windowID, tag: "visionos-spatial")
    }
    
    /// Check if a window is spatially enabled
    func isWindowSpatial(_ windowID: Int) -> Bool {
        return windowHasTag(windowID, tag: "visionos-spatial") || 
               windowHasTag(windowID, tag: "spatial-anchored") ||
               getWindowTags(windowID).contains { $0.hasPrefix("spatial-anchored:") }
    }
    
    /// Get the spatial anchor ID for a window (if any)
    func getSpatialAnchorID(for windowID: Int) -> UUID? {
        let tags = getWindowTags(windowID)
        
        for tag in tags {
            if tag.hasPrefix("spatial-anchored:") {
                let anchorIDString = String(tag.dropFirst("spatial-anchored:".count))
                return UUID(uuidString: anchorIDString)
            }
        }
        
        return nil
    }
    
    /// Remove spatial anchoring tag from a window (placeholder - requires removeWindowTag method)
    func removeSpatialAnchoring(from windowID: Int) {
        let tags = getWindowTags(windowID)
        
        for tag in tags {
            if tag.hasPrefix("spatial-anchored:") || tag == "visionos-spatial" {
                // This requires the removeWindowTag method to be implemented
                print("ℹ️ Would remove spatial tag: \(tag) from window #\(windowID)")
                // removeWindowTag(windowID, tag: tag)
            }
        }
    }
}