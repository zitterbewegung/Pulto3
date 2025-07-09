//
//  NotebookFile.swift
//  Pulto
//
//  Created by Joshua Herman on 6/18/25.
//  Copyright 2025 Apple. All rights reserved.
//


//
//  SharedNotebookTypes.swift
//  All shared types for notebook import and environment restoration
//

import Foundation
import SwiftUI

// MARK: - Forward declarations and imports
// We need to reference types from OpenWindowView, but to avoid circular imports,
// we'll use a protocol or recreate the essential structure

// Essential window types needed for import results
struct ImportedWindowID: Identifiable, Codable, Hashable {
    var id: Int
    var windowType: String
    var position: WindowPosition
    var state: WindowState
    var createdAt: Date
    
    init(id: Int, windowType: String, position: WindowPosition = WindowPosition(), state: WindowState = WindowState()) {
        self.id = id
        self.windowType = windowType
        self.position = position
        self.state = state
        self.createdAt = Date()
    }
}

// MARK: - Notebook File Type

struct NotebookFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let createdDate: Date
    let modifiedDate: Date
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdDate)
    }
    
    var formattedModifiedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modifiedDate)
    }
}

// MARK: - Import Result Types

struct ImportResult {
    let restoredWindows: [ImportedWindowID]
    let errors: [ImportError]
    let originalMetadata: VisionOSExportInfo?
    let idMapping: [Int: Int] // old ID -> new ID
    
    var isSuccessful: Bool {
        return !restoredWindows.isEmpty
    }
    
    var summary: String {
        let windowCount = restoredWindows.count
        let errorCount = errors.count
        
        if windowCount > 0 && errorCount == 0 {
            return "Successfully restored \(windowCount) window\(windowCount == 1 ? "" : "s")"
        } else if windowCount > 0 && errorCount > 0 {
            return "Restored \(windowCount) window\(windowCount == 1 ? "" : "s") with \(errorCount) error\(errorCount == 1 ? "" : "s")"
        } else {
            return "Failed to restore windows: \(errorCount) error\(errorCount == 1 ? "" : "s")"
        }
    }
}

struct NotebookAnalysis {
    let totalCells: Int
    let windowCells: Int
    let windowTypes: [String]
    let exportTemplates: [String]
    let metadata: VisionOSExportInfo?
    
    var hasVisionOSData: Bool {
        return windowCells > 0 || metadata != nil
    }
}

struct VisionOSExportInfo: Codable {
    let export_date: String
    let total_windows: Int
    let window_types: [String]
    let export_templates: [String]
    let all_tags: [String]
}

enum ImportError: Error, LocalizedError {
    case invalidJSON
    case invalidNotebookFormat
    case cellParsingFailed
    case unsupportedWindowType
    case invalidMetadata
    case fileReadError
    
    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid JSON format"
        case .invalidNotebookFormat:
            return "Not a valid Jupyter notebook"
        case .cellParsingFailed:
            return "Failed to parse cell data"
        case .unsupportedWindowType:
            return "Unsupported window type"
        case .invalidMetadata:
            return "Invalid or missing metadata"
        case .fileReadError:
            return "Could not read file"
        }
    }
}

// MARK: - Environment Restore Result

struct EnvironmentRestoreResult {
    let importResult: ImportResult
    let openedWindows: [ImportedWindowID]
    let failedWindows: [ImportedWindowID]
    
    var totalRestored: Int {
        return openedWindows.count
    }
    
    var totalFailed: Int {
        return failedWindows.count
    }
    
    var isFullySuccessful: Bool {
        return failedWindows.isEmpty && importResult.isSuccessful
    }
    
    var summary: String {
        if isFullySuccessful {
            return "Successfully restored \(totalRestored) window\(totalRestored == 1 ? "" : "s") to your 3D environment"
        } else if totalRestored > 0 {
            return "Restored \(totalRestored) window\(totalRestored == 1 ? "" : "s"), \(totalFailed) failed to open"
        } else {
            return "Failed to restore environment: \(importResult.errors.count) error\(importResult.errors.count == 1 ? "" : "s")"
        }
    }
}