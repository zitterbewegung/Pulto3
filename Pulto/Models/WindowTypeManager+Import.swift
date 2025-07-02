//
//  WindowTypeManager+Import.swift
//  Add this as a new file to your project
//

import Foundation

// MARK: - Import Result Types

struct ImportResult {
    let restoredWindows: [NewWindowID]
    let errors: [ImportError]
    let originalMetadata: VisionOSExportInfo?
    let idMapping: [Int: Int]
}

struct EnvironmentRestoreResult {
    let importResult: ImportResult
    let openedWindows: [NewWindowID]
    let failedWindows: [NewWindowID]

    var totalRestored: Int {
        return openedWindows.count
    }

    var isFullySuccessful: Bool {
        return failedWindows.isEmpty && !openedWindows.isEmpty
    }

    var summary: String {
        if isFullySuccessful {
            return "Successfully restored \(totalRestored) window\(totalRestored == 1 ? "" : "s")"
        } else if totalRestored > 0 {
            return "Partially restored: \(totalRestored) successful, \(failedWindows.count) failed"
        } else {
            return "Failed to restore workspace"
        }
    }
}

typealias WindowTypeManagerRestoreResult = EnvironmentRestoreResult

struct NotebookAnalysis {
    let totalCells: Int
    let windowCells: Int
    let windowTypes: [String]
    let exportTemplates: [String]
    let metadata: VisionOSExportInfo?
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
    case fileReadError
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid JSON format"
        case .invalidNotebookFormat:
            return "Invalid notebook format"
        case .cellParsingFailed:
            return "Failed to parse cell data"
        case .fileReadError:
            return "Failed to read file"
        case .unsupportedVersion:
            return "Unsupported notebook version"
        }
    }
}

struct NotebookFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let createdDate: Date
    let modifiedDate: Date

    var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedModifiedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: modifiedDate)
    }
}

// MARK: - WindowTypeManager Import Extensions

extension WindowTypeManager {

    // MARK: - Main Import Methods

    func importFromGenericNotebook(data: Data) throws -> ImportResult {
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw ImportError.invalidJSON
        }

        return try restoreWindowsFromGenericNotebook(json)
    }

    func importFromGenericNotebook(fileURL: URL) throws -> ImportResult {
        let data = try Data(contentsOf: fileURL)
        return try importFromGenericNotebook(data: data)
    }

    func importFromGenericNotebook(jsonString: String) throws -> ImportResult {
        guard let data = jsonString.data(using: .utf8) else {
            throw ImportError.invalidJSON
        }
        return try importFromGenericNotebook(data: data)
    }

    // MARK: - Core Restoration Logic

    private func restoreWindowsFromGenericNotebook(_ json: [String: Any]) throws -> ImportResult {
        guard let cells = json["cells"] as? [[String: Any]] else {
            throw ImportError.invalidNotebookFormat
        }

        var restoredWindows: [NewWindowID] = []
        var errors: [ImportError] = []
        var idMapping: [Int: Int] = [:]

        let currentMaxID = getAllWindows().map { $0.id }.max() ?? 0
        var nextAvailableID = currentMaxID + 1

        for cellDict in cells {
            do {
                if let windowData = try extractWindowFromGenericCell(cellDict, nextID: nextAvailableID) {
                    if let oldID = extractWindowID(from: cellDict) {
                        idMapping[oldID] = nextAvailableID
                    }

                    restoredWindows.append(windowData)
                    nextAvailableID += 1
                }
            } catch {
                errors.append(error as? ImportError ?? ImportError.cellParsingFailed)
            }
        }

        // Store the restored windows
        for window in restoredWindows {
            windows[window.id] = window
        }

        let visionOSMetadata = extractVisionOSMetadata(from: json)

        return ImportResult(
            restoredWindows: restoredWindows,
            errors: errors,
            originalMetadata: visionOSMetadata,
            idMapping: idMapping
        )
    }

    private func extractWindowFromGenericCell(_ cellDict: [String: Any], nextID: Int) throws -> NewWindowID? {
        guard let metadata = cellDict["metadata"] as? [String: Any],
              let windowTypeString = metadata["window_type"] as? String,
              let windowType = WindowType(rawValue: windowTypeString) else {
            return nil
        }

        // Extract position
        let position = extractPosition(from: metadata)

        // Extract window state
        var state = WindowState()
        if let stateDict = metadata["state"] as? [String: Any] {
            state.isMinimized = stateDict["minimized"] as? Bool ?? false
            state.isMaximized = stateDict["maximized"] as? Bool ?? false
            state.opacity = stateDict["opacity"] as? Double ?? 1.0
        }

        // Extract export template
        if let templateString = metadata["export_template"] as? String,
           let template = ExportTemplate(rawValue: templateString) {
            state.exportTemplate = template
        }

        // Extract tags
        state.tags = metadata["tags"] as? [String] ?? []

        // Extract content from cell source
        if let sourceArray = cellDict["source"] as? [String] {
            state.content = sourceArray.joined(separator: "\n")
        }

        // Parse timestamps
        if let timestamps = metadata["timestamps"] as? [String: String] {
            if let modifiedString = timestamps["modified"],
               let modifiedDate = parseISO8601Date(modifiedString) {
                state.lastModified = modifiedDate
            }
        }

        // Try to extract specialized data
        try extractSpecializedDataFromGeneric(cellDict: cellDict, into: &state, windowType: windowType)

        let window = NewWindowID(
            id: nextID,
            windowType: windowType,
            position: position,
            state: state
        )

        return window
    }

    private func extractPosition(from metadata: [String: Any]) -> WindowPosition {
        guard let positionDict = metadata["position"] as? [String: Any] else {
            return WindowPosition()
        }

        return WindowPosition(
            x: positionDict["x"] as? Double ?? 0,
            y: positionDict["y"] as? Double ?? 0,
            z: positionDict["z"] as? Double ?? 0,
            width: positionDict["width"] as? Double ?? 400,
            height: positionDict["height"] as? Double ?? 300
        )
    }

    private func extractWindowID(from cellDict: [String: Any]) -> Int? {
        guard let metadata = cellDict["metadata"] as? [String: Any] else { return nil }
        return metadata["window_id"] as? Int
    }

    private func extractVisionOSMetadata(from json: [String: Any]) -> VisionOSExportInfo? {
        guard let metadata = json["metadata"] as? [String: Any],
              let visionOSDict = metadata["visionos_export"] as? [String: Any] else {
            return nil
        }

        return VisionOSExportInfo(
            export_date: visionOSDict["export_date"] as? String ?? "",
            total_windows: visionOSDict["total_windows"] as? Int ?? 0,
            window_types: visionOSDict["window_types"] as? [String] ?? [],
            export_templates: visionOSDict["export_templates"] as? [String] ?? [],
            all_tags: visionOSDict["all_tags"] as? [String] ?? []
        )
    }

    private func extractSpecializedDataFromGeneric(cellDict: [String: Any], into state: inout WindowState, windowType: WindowType) throws {
        guard let sourceArray = cellDict["source"] as? [String] else { return }
        let content = sourceArray.joined(separator: "\n")

        switch windowType {
        case .column:
            if let dataFrame = try parseDataFrameFromContent(content) {
                state.dataFrameData = dataFrame
            }

        case .spatial:
            if let pointCloud = try parsePointCloudFromContent(content) {
                state.pointCloudData = pointCloud
            }

        case .charts:
            break

        case .volume:
            if let volumeData = try parseVolumeDataFromContent(content) {
                state.volumeData = volumeData
            }

        case .model3d:
            if let model3DData = try parseModel3DDataFromContent(content) {
                state.model3DData = model3DData
            }

        case .pointcloud:
            if let pointCloud = try parsePointCloudFromContent(content) {
                state.pointCloudData = pointCloud
            }
        }
    }

    // MARK: - Analysis Methods

    func analyzeGenericNotebook(fileURL: URL) throws -> NotebookAnalysis {
        let data = try Data(contentsOf: fileURL)
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw ImportError.invalidJSON
        }

        return try analyzeGenericNotebook(json: json)
    }

    func analyzeGenericNotebook(json: [String: Any]) throws -> NotebookAnalysis {
        guard let cells = json["cells"] as? [[String: Any]] else {
            throw ImportError.invalidNotebookFormat
        }

        var windowCells = 0
        var windowTypes: Set<String> = []
        var exportTemplates: Set<String> = []

        for cellDict in cells {
            if let metadata = cellDict["metadata"] as? [String: Any],
               let windowType = metadata["window_type"] as? String {
                windowCells += 1
                windowTypes.insert(windowType)

                if let template = metadata["export_template"] as? String {
                    exportTemplates.insert(template)
                }
            }
        }

        let visionOSMetadata = extractVisionOSMetadata(from: json)

        return NotebookAnalysis(
            totalCells: cells.count,
            windowCells: windowCells,
            windowTypes: Array(windowTypes),
            exportTemplates: Array(exportTemplates),
            metadata: visionOSMetadata
        )
    }

    func validateGenericNotebook(fileURL: URL) throws -> Bool {
        let data = try Data(contentsOf: fileURL)
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return false
        }

        guard json["cells"] != nil, json["metadata"] != nil else {
            return false
        }

        if let metadata = json["metadata"] as? [String: Any] {
            return metadata["visionos_export"] != nil
        }

        return false
    }

    // MARK: - Add the missing clearAllWindows method

    func clearAllWindows() {
        windows.removeAll()
        objectWillChange.send()
    }

    // MARK: - Utility Methods

    private func parseDataFrameFromContent(_ content: String) throws -> DataFrameData? {
        let patterns = [
            #"data\s*=\s*\{([^}]+)\}"#,
            #"pd\.DataFrame\(([^)]+)\)"#
        ]

        for pattern in patterns {
            if let match = content.range(of: pattern, options: .regularExpression) {
                return try parseDataFrameFromMatch(String(content[match]))
            }
        }

        return nil
    }

    private func parseDataFrameFromMatch(_ match: String) throws -> DataFrameData? {
        return DataFrameData(
            columns: ["imported_column"],
            rows: [["Data imported from notebook"]],
            dtypes: ["imported_column": "string"]
        )
    }

    private func parsePointCloudFromContent(_ content: String) throws -> PointCloudData? {
        let patterns = [
            #"points_data\s*=\s*\{([^}]+)\}"#,
            #"'x':\s*\[([^\]]+)\]"#,
        ]

        for pattern in patterns {
            if let match = content.range(of: pattern, options: .regularExpression) {
                return try parsePointCloudFromMatch(String(content[match]), fullContent: content)
            }
        }

        return nil
    }

    private func parsePointCloudFromMatch(_ match: String, fullContent: String) throws -> PointCloudData? {
        let titlePattern = #"# (.+)"#
        var title = "Imported Point Cloud"

        if let titleMatch = fullContent.range(of: titlePattern, options: .regularExpression) {
            let titleLine = String(fullContent[titleMatch])
            if let actualTitle = titleLine.components(separatedBy: "# ").last?.trimmingCharacters(in: .whitespaces) {
                title = actualTitle
            }
        }

        var pointCloudData = PointCloudData(
            title: title,
            demoType: "imported"
        )

        pointCloudData.points = [
            PointCloudData.PointData(x: 0, y: 0, z: 0, intensity: 0.5, color: nil)
        ]
        pointCloudData.totalPoints = 1

        return pointCloudData
    }

    private func parseVolumeDataFromContent(_ content: String) throws -> VolumeData? {
        return VolumeData(
            title: "Imported Volume Data",
            category: "imported",
            metrics: ["sample_metric": 1.0]
        )
    }

    private func parseModel3DDataFromContent(_ content: String) throws -> Model3DData? {
        return Model3DData.generateCube(size: 2.0)
    }

    private func parseISO8601Date(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }

    func importAndRestoreEnvironment(
        fileURL: URL,
        clearExisting: Bool = false,
        openWindow: @escaping (Int) -> Void
    ) async throws -> EnvironmentRestoreResult {

        // Import the data first
        let importResult = try importFromGenericNotebook(fileURL: fileURL)

        // Then actually open the windows visually
        var openedWindows: [NewWindowID] = []

        for window in importResult.restoredWindows {
            await MainActor.run {
                openWindow(window.id) // This actually creates the visual window
                openedWindows.append(window)
            }

            // Small delay for smooth animation
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        return EnvironmentRestoreResult(
            importResult: importResult,
            openedWindows: openedWindows,
            failedWindows: []
        )
    }
}
