//
//  ImportTypes.swift
//  Pulto
//
//  Central store for every runtime-created window.
//  Updated 2025-06-18 for VisionOS 2.4

import Foundation

// MARK: - Import Result Types

struct ImportResult {
    let restoredWindows: [NewWindowID]
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
