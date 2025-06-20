//
//  WindowTypeManager+Import.swift
//  Add this as a new file to your project
//

import Foundation

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
    
    private func parseISO8601Date(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    // Add this method to WindowTypeManager
    func importAndRestoreEnvironment(
        fileURL: URL,
        clearExisting: Bool = false,
        openWindow: @escaping (Int) -> Void
    ) async throws -> WindowTypeManagerRestoreResult {

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
    // Add this method to WindowTypeManager
    private func generateVolumeCellContent(for window: NewWindowID) -> String {
        if let volumeData = window.state.volumeData {
            return volumeData.toPythonCode()
        }

        let baseContent = """
        # Volume Metrics Window #\(window.id)
        # Created: \(DateFormatter.localizedString(from: window.createdAt, dateStyle: .short, timeStyle: .short))
        # Position: (\(window.position.x), \(window.position.y), \(window.position.z))
        
        import matplotlib.pyplot as plt
        import numpy as np
        import pandas as pd
        
        # Volume metrics configuration from VisionOS window
        # Window size: \(window.position.width) × \(window.position.height)
        
        """

        return window.state.content.isEmpty ? baseContent : baseContent + "\n" + window.state.content
        // Add this function to WindowTypeManager class
        private func parseModel3DDataFromContent(_ content: String) throws -> Model3DData? {
            let patterns = [
                #"vertices\s*=\s*\[([^\]]+)\]"#,           // vertices = [...]
                #"faces\s*=\s*\[([^\]]+)\]"#,              // faces = [...]
                #"model_data\s*=\s*\{([^}]+)\}"#,          // model_data = {...}
                #"mesh\s*=\s*\{([^}]+)\}"#                 // mesh = {...}
            ]

            for pattern in patterns {
                if let match = content.range(of: pattern, options: .regularExpression) {
                    return try parseModel3DFromMatch(String(content[match]), fullContent: content)
                }
            }

            // Generate a default model if none found
            return generateDefaultModel(from: content)
        }

        private func parseModel3DFromMatch(_ match: String, fullContent: String) throws -> Model3DData? {
            // Extract title from comments
            let titlePattern = #"# (.+)"#
            var title = "Imported 3D Model"

            if let titleMatch = fullContent.range(of: titlePattern, options: .regularExpression) {
                let titleLine = String(fullContent[titleMatch])
                if let actualTitle = titleLine.components(separatedBy: "# ").last?.trimmingCharacters(in: .whitespaces) {
                    title = actualTitle
                }
            }

            // Determine model type from content
            let modelType = determineModelType(from: fullContent)

            // For now, generate a sample model based on the detected type
            switch modelType {
            case "sphere":
                return Model3DData.generateSphere(radius: 2.0, segments: 12)
            case "cube":
                return Model3DData.generateCube(size: 3.0)
            default:
                return Model3DData.generateCube(size: 2.0)
            }
        }

        private func generateDefaultModel(from content: String) -> Model3DData? {
            let modelType = determineModelType(from: content)

            switch modelType {
            case "sphere":
                return Model3DData.generateSphere(radius: 1.5, segments: 16)
            case "cube":
                return Model3DData.generateCube(size: 2.0)
            default:
                return Model3DData.generateCube(size: 1.0)
            }
        }

        private func determineModelType(from content: String) -> String {
            let lowercased = content.lowercased()
            if lowercased.contains("sphere") || lowercased.contains("ball") || lowercased.contains("round") {
                return "sphere"
            } else if lowercased.contains("cube") || lowercased.contains("box") || lowercased.contains("square") {
                return "cube"
            }
            return "mesh"
        }
      
    }
}
