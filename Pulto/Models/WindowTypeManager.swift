//
//  WindowTypeManager.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/13/25.
//  Copyright 22025 Apple. All rights reserved.
//

import SwiftUI
import Foundation
import Charts

// Type alias to resolve Project type conflicts
typealias ProjectModel = Project

// Notification names for project events
extension Notification.Name {
    static let projectSelected = Notification.Name("projectSelected")
    static let projectCleared = Notification.Name("projectCleared")
}

// Enhanced window manager with export capabilities and lifecycle management
class WindowTypeManager: ObservableObject {

    static let shared = WindowTypeManager()
    @Published var activeWindowID: Int? = nil        // NEW
    @Published private var windows: [Int: NewWindowID] = [:]
    @Published private var openWindowIDs: Set<Int> = []
    @Published var selectedProject: ProjectModel? = nil
    var usdzBookmark: Data? = nil

    private init() {}

    func setSelectedProject(_ project: ProjectModel) {
        selectedProject = project
        objectWillChange.send()

        // Notify that a project has been selected - can be used to trigger 3D content creation
        NotificationCenter.default.post(name: .projectSelected, object: project)
        
        Task { @MainActor in
            await WorkspaceManager.shared.ensureProjectWorkspaceExists(for: project)
        }
    }

    func clearSelectedProject() {
        selectedProject = nil
        objectWillChange.send()

        // Notify that project has been cleared
        NotificationCenter.default.post(name: .projectCleared, object: nil)
    }

    func getNextWindowID() -> Int {
        let currentMaxID = getAllWindows().map { $0.id }.max() ?? 0
        return currentMaxID + 1
    }

    func markWindowAsOpened(_ id: Int) {
        openWindowIDs.insert(id)
        objectWillChange.send()
        
        WorkspaceManager.shared.scheduleAutoSave(windowManager: self)
        print("🪟 Window #\(id) marked as opened, triggering auto-save")
    }

    func markWindowAsClosed(_ id: Int) {
        openWindowIDs.remove(id)
        
        // NEW: Clean up entities when window closes
        Task { @MainActor in
            EntityLifecycleManager.shared.cleanupWindow(id)
        }
        
        objectWillChange.send()
        
        WorkspaceManager.shared.scheduleAutoSave(windowManager: self)
        print("🪟 Window #\(id) marked as closed, triggering auto-save")
    }

    func isWindowActuallyOpen(_ id: Int) -> Bool {
        return openWindowIDs.contains(id)
    }

    func cleanupClosedWindows() {
        let windowsToRemove = windows.keys.filter { !openWindowIDs.contains($0) }
        for windowID in windowsToRemove {
            // Clean up entities before removing window data
            Task { @MainActor in
                EntityLifecycleManager.shared.cleanupWindow(windowID)
            }
            windows.removeValue(forKey: windowID)
        }
        objectWillChange.send()
    }

    func getAllWindows(onlyOpen: Bool = false) -> [NewWindowID] {
        let allWindows = Array(windows.values).sorted { $0.id < $1.id }
        if onlyOpen {
            return allWindows.filter { openWindowIDs.contains($0.id) }
        }
        return allWindows
    }

    func getWindowSafely(for id: Int) -> NewWindowID? {
        guard let window = windows[id] else {
            print(" Warning: Window #\(id) not found in WindowTypeManager")
            return nil
        }

        // If window exists in manager but not marked as open, it might have been closed
        if !openWindowIDs.contains(id) {
            print(" Info: Window #\(id) exists in manager but is not marked as open")
        }

        return window
    }

    // Add these functions to WindowTypeManager class
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
        // A full OBJ/glTF parser would be needed for true parsing
        switch modelType {
        case "sphere":
            var model = Model3DData.generateSphere(radius: 2.0, segments: 12)
            model.title = title
            return model
        case "cube":
            var model = Model3DData.generateCube(size: 3.0)
            model.title = title
            return model
        default:
            var model = Model3DData.generateCube(size: 2.0)
            model.title = title
            return model
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

    // Add these methods to WindowTypeManager class
    func updateWindowModel3DData(_ id: Int, model3DData: Model3DData) {
        windows[id]?.state.model3DData = model3DData
        windows[id]?.state.lastModified = Date()

        // Auto-set template to custom if not already set
        if let window = windows[id], window.windowType == .model3d && window.state.exportTemplate == .plain {
            windows[id]?.state.exportTemplate = .custom
        }
    }

    func getWindowModel3DData(for id: Int) -> Model3DData? {
        return windows[id]?.state.model3DData
    }

    // Chart data methods
    func updateWindowChartData(_ id: Int, chartData: ChartData) {
        windows[id]?.state.chartData = chartData
        windows[id]?.state.lastModified = Date()

        // Auto-set template to matplotlib if not already set
        if let window = windows[id], window.windowType == .charts && window.state.exportTemplate == .plain {
            windows[id]?.state.exportTemplate = .matplotlib
        }
    }

    func getWindowChartData(for id: Int) -> ChartData? {
        return windows[id]?.state.chartData
    }

    // Chart3D data methods
    func updateWindowChart3DData(_ id: Int, chart3DData: Chart3DData) {
        windows[id]?.state.chart3DData = chart3DData
        windows[id]?.state.lastModified = Date()

        // Auto-set template to custom if not already set
        if let window = windows[id], window.windowType == .charts && window.state.exportTemplate == .plain {
            windows[id]?.state.exportTemplate = .custom
        }
    }

    func getWindowChart3DData(for id: Int) -> Chart3DData? {
        return windows[id]?.state.chart3DData
    }

    // New point cloud methods
    func updateWindowPointCloud(_ id: Int, pointCloud: PointCloudData) {
        windows[id]?.state.pointCloudData = pointCloud
        windows[id]?.state.lastModified = Date()

        // Auto-set template to custom if not already set
        if let window = windows[id], window.windowType == .spatial && window.state.exportTemplate == .plain {
            windows[id]?.state.exportTemplate = .custom
        }
    }

    func getWindowPointCloud(for id: Int) -> PointCloudData? {
        return windows[id]?.state.pointCloudData
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
                markWindowAsOpened(window.id)
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

    // MARK: - Import Methods

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

        case .pointcloud:
            if let pointCloud = try parsePointCloudFromContent(content) {
                state.pointCloudData = pointCloud
            }

        case .volume:
            if let volumeData = try parseVolumeDataFromContent(content) {
                state.volumeData = volumeData
            }

        case .charts:
            if let chartData = try parseChartDataFromContent(content) {
                state.chartData = chartData
            }

        case .model3d:
            if let model3DData = try parseModel3DDataFromContent(content) {
                state.model3DData = model3DData
            }

        case .spatial:
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

    /// Removes all windows from the manager and cleans up associated resources
    func clearAllWindows() {
        // Clean up all entities before clearing windows
        Task { @MainActor in
            EntityLifecycleManager.shared.cleanupAll()
        }
        
        windows.removeAll()
        openWindowIDs.removeAll()
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

    // Add these functions to WindowTypeManager class

    private func parseVolumeDataFromContent(_ content: String) throws -> VolumeData? {
        let patterns = [
            #"metrics\s*=\s*\{([^}]+)\}"#,           // metrics = {...}
            #"performance\s*=\s*\{([^}]+)\}"#,       // performance = {...}
            #"volume_data\s*=\s*\{([^}]+)\}"#,       // volume_data = {...}
            #"model_metrics\s*=\s*\{([^}]+)\}"#      // model_metrics = {...}
        ]

        for pattern in patterns {
            if let match = content.range(of: pattern, options: .regularExpression) {
                return try parseVolumeDataFromMatch(String(content[match]), fullContent: content)
            }
        }

        // Look for individual metric patterns
        return try parseIndividualMetrics(from: content)
    }

    private func parseVolumeDataFromMatch(_ match: String, fullContent: String) throws -> VolumeData? {
        // Extract title from comments
        let titlePattern = #"# (.+)"#
        var title = "Imported Volume Data"

        if let titleMatch = fullContent.range(of: titlePattern, options: .regularExpression) {
            let titleLine = String(fullContent[titleMatch])
            if let actualTitle = titleLine.components(separatedBy: "# ").last?.trimmingCharacters(in: .whitespaces) {
                title = actualTitle
            }
        }

        // Parse metrics from the match
        var metrics: [String: Double] = [:]

        // Simple regex to extract key-value pairs
        let kvPattern = #"['""]([^'"",]+)['""]:\s*([0-9.]+)"#
        let regex = try NSRegularExpression(pattern: kvPattern)
        let nsString = match as NSString
        let results = regex.matches(in: match, range: NSRange(location: 0, length: nsString.length))

        for result in results {
            if result.numberOfRanges >= 3 {
                let keyRange = result.range(at: 1)
                let valueRange = result.range(at: 2)

                let key = nsString.substring(with: keyRange)
                let valueString = nsString.substring(with: valueRange)

                if let value = Double(valueString) {
                    metrics[key] = value
                }
            }
        }

        // If no metrics found, add some sample data
        if metrics.isEmpty {
            metrics = [
                "accuracy": 0.95,
                "latency_ms": 120,
                "throughput_rps": 300
            ]
        }

        let category = determineVolumeCategory(from: fullContent)
        let unit = extractUnit(from: fullContent)

        return VolumeData(
            title: title,
            category: category,
            metrics: metrics,
            unit: unit
        )
    }

    private func parseIndividualMetrics(from content: String) throws -> VolumeData? {
        var metrics: [String: Double] = [:]

        // Look for patterns like "accuracy = 0.95" or "latency: 120"
        let patterns = [
            #"(\w+)\s*=\s*([0-9.]+)"#,
            #"(\w+):\s*([0-9.]+)"#,
            #"print\(f?['""](\w+):\s*\{([^}]+)\}"#
        ]

        for pattern in patterns {
            let regex = try NSRegularExpression(pattern: pattern)
            let nsString = content as NSString
            let results = regex.matches(in: content, range: NSRange(location: 0, length: nsString.length))

            for result in results {
                if result.numberOfRanges >= 3 {
                    let keyRange = result.range(at: 1)
                    let valueRange = result.range(at: 2)

                    let key = nsString.substring(with: keyRange)
                    let valueString = nsString.substring(with: valueRange)

                    if let value = Double(valueString) {
                        metrics[key] = value
                    }
                }
            }
        }

        guard !metrics.isEmpty else { return nil }

        return VolumeData(
            title: "Extracted Metrics",
            category: "general",
            metrics: metrics
        )
    }

    private func parseChartDataFromContent(_ content: String) throws -> ChartData? {
        let patterns = [
            #"x\s*=\s*\[([^\]]+)\]"#,               // x = [...]
            #"y\s*=\s*\[([^\]]+)\]"#,               // y = [...]
            #"x_data\s*=\s*\[([^\]]+)\]"#,          // x_data = [...]
            #"y_data\s*=\s*\[([^\]]+)\]"#,          // y_data = [...]
            #"plt\.plot\(([^)]+)\)"#,               // plt.plot(...)
            #"ax\.plot\(([^)]+)\)"#                 // ax.plot(...)
        ]

        var xData: [Double] = []
        var yData: [Double] = []
        var chartType = "line"
        var title = "Imported Chart"

        // Extract title from comments or plot titles
        let titlePattern = #"plt\.title\(['""]([^'""]+)['""]"#
        if let titleMatch = content.range(of: titlePattern, options: .regularExpression) {
            let titleLine = String(content[titleMatch])
            if let extractedTitle = extractQuotedString(from: titleLine) {
                title = extractedTitle
            }
        }

        // Determine chart type
        if content.contains("scatter") || content.contains("plt.scatter") {
            chartType = "scatter"
        } else if content.contains("bar") || content.contains("plt.bar") {
            chartType = "bar"
        } else if content.contains("fill_between") || content.contains("area") {
            chartType = "area"
        }

        // Extract data arrays
        for pattern in patterns {
            if let match = content.range(of: pattern, options: .regularExpression) {
                let matchString = String(content[match])

                if matchString.contains("x") && !matchString.contains("y") {
                    xData = extractNumberArray(from: matchString)
                } else if matchString.contains("y") {
                    yData = extractNumberArray(from: matchString)
                } else if matchString.contains("plot") {
                    let arrays = extractMultipleArrays(from: matchString)
                    if arrays.count >= 2 {
                        xData = arrays[0]
                        yData = arrays[1]
                    }
                }
            }
        }

        // Generate sample data if none found
        if xData.isEmpty || yData.isEmpty {
            xData = Array(stride(from: 0.0, through: 10.0, by: 0.5))
            yData = xData.map { sin($0) }
        }

        // Extract labels
        let xLabel = extractLabel(from: content, type: "xlabel") ?? "X"
        let yLabel = extractLabel(from: content, type: "ylabel") ?? "Y"

        return ChartData(
            title: title,
            chartType: chartType,
            xLabel: xLabel,
            yLabel: yLabel,
            xData: xData,
            yData: yData
        )
    }

    // Helper functions for parsing
    private func determineVolumeCategory(from content: String) -> String {
        let lowercased = content.lowercased()
        if lowercased.contains("performance") || lowercased.contains("metric") {
            return "performance"
        } else if lowercased.contains("model") || lowercased.contains("ml") {
            return "model"
        } else if lowercased.contains("system") || lowercased.contains("resource") {
            return "system"
        }
        return "general"
    }

    private func extractUnit(from content: String) -> String? {
        let unitPatterns = [
            #"unit[s]?['""]:\s*['""]([^'""]+)['""]"#,
            #"([a-zA-Z]+)\s*per\s*([p-zA-Z]+)"#
        ]

        for pattern in unitPatterns {
            if let match = content.range(of: pattern, options: .regularExpression) {
                return String(content[match])
            }
        }
        return nil
    }

    private func extractQuotedString(from text: String) -> String? {
        let pattern = #"['""]([^'""]+)['""]"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            let matchString = String(text[match])
            return matchString.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        return nil
    }

    private func extractNumberArray(from text: String) -> [Double] {
        let pattern = #"\[([^\]]+)\]"#
        guard let match = text.range(of: pattern, options: .regularExpression) else { return [] }

        let arrayString = String(text[match])
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))

        return arrayString.components(separatedBy: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }

    private func extractMultipleArrays(from text: String) -> [[Double]] {
        let pattern = #"\[([^\]]+)\]"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = text as NSString
        let results = regex?.matches(in: text, range: NSRange(location: 0, length: nsString.length)) ?? []

        var arrays: [[Double]] = []
        for result in results {
            let arrayString = nsString.substring(with: result.range(at: 1))
            let numbers = arrayString.components(separatedBy: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if !numbers.isEmpty {
                arrays.append(numbers)
            }
        }

        return arrays
    }

    private func extractLabel(from content: String, type: String) -> String? {
        let pattern = #"plt\.\#(type)\(['""]([^'""]+)['""]"#
        if let match = content.range(of: pattern, options: .regularExpression) {
            return extractQuotedString(from: String(content[match]))
        }
        return nil
    }

    private func parseISO8601Date(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }

    func createWindow(_ type: WindowType, id: Int, position: WindowPosition = WindowPosition()) -> NewWindowID {
        let window = NewWindowID(id: id, windowType: type, position: position)
        windows[id] = window
        // Don't automatically mark as open here - let the caller do it when the window actually opens
        
        // Notify that windows have changed, which will trigger auto-save
        objectWillChange.send()
        WorkspaceManager.shared.scheduleAutoSave(windowManager: self)
        return window
    }

    func getWindow(for id: Int) -> NewWindowID? {
        return getWindowSafely(for: id)
    }

    func getType(for id: Int) -> WindowType {
        return getWindowSafely(for: id)?.windowType ?? .spatial
    }

    func updateWindowPosition(_ id: Int, position: WindowPosition) {
        windows[id]?.position = position
        objectWillChange.send()
        WorkspaceManager.shared.scheduleAutoSave(windowManager: self)
    }

    func updateWindowState(_ id: Int, state: WindowState) {
        windows[id]?.state = state
        objectWillChange.send()
        WorkspaceManager.shared.scheduleAutoSave(windowManager: self)
    }

    func updateWindowContent(_ id: Int, content: String) {
        windows[id]?.state.content = content
        windows[id]?.state.lastModified = Date()
        objectWillChange.send()
        WorkspaceManager.shared.scheduleAutoSave(windowManager: self)
    }

    func updateWindowTemplate(_ id: Int, template: ExportTemplate) {
        windows[id]?.state.exportTemplate = template
        windows[id]?.state.lastModified = Date()
        objectWillChange.send()
        WorkspaceManager.shared.scheduleAutoSave(windowManager: self)
    }

    func updateWindowImports(_ id: Int, imports: [String]) {
        windows[id]?.state.customImports = imports
        windows[id]?.state.lastModified = Date()
        objectWillChange.send()
        WorkspaceManager.shared.scheduleAutoSave(windowManager: self)
    }

    func addWindowTag(_ id: Int, tag: String) {
        if windows[id]?.state.tags.contains(tag) == false {
            windows[id]?.state.tags.append(tag)
            windows[id]?.state.lastModified = Date()
            objectWillChange.send()
            WorkspaceManager.shared.scheduleAutoSave(windowManager: self)
        }
    }

    func updateWindowDataFrame(_ id: Int, dataFrame: DataFrameData) {
        windows[id]?.state.dataFrameData = dataFrame
        windows[id]?.state.lastModified = Date()

        // Auto-set template to pandas if not already set and this is a DataFrame window
        if let window = windows[id], window.windowType == .column && window.state.exportTemplate == .plain {
            windows[id]?.state.exportTemplate = .pandas
        }
        objectWillChange.send()
        WorkspaceManager.shared.scheduleAutoSave(windowManager: self)
    }

    func getWindowDataFrame(for id: Int) -> DataFrameData? {
        return windows[id]?.state.dataFrameData
    }

    func removeWindow(_ id: Int) {
        // Clean up entities before removing window
        Task { @MainActor in
            EntityLifecycleManager.shared.cleanupWindow(id)
        }
        
        windows.removeValue(forKey: id)
        markWindowAsClosed(id)
        objectWillChange.send()
        WorkspaceManager.shared.scheduleAutoSave(windowManager: self)
    }

    // MARK: - Jupyter Export Functions

    func exportToJupyterNotebook() -> String {
        let notebook = createJupyterNotebook()
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: notebook, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            print("Error creating JSON: \(error)")
            return "{}"
        }
    }

    private func createJupyterNotebook() -> [String: Any] {
        let cells = getAllWindows().map { window in
            createJupyterCell(from: window)
        }

        let metadata: [String: Any] = [
            "kernelspec": [
                "display_name": "Python 3",
                "language": "python",
                "name": "python3"
            ],
            "language_info": [
                "name": "python",
                "version": "3.8.0",
                "mimetype": "text/x-python",
                "codemirror_mode": [
                    "name": "ipython",
                    "version": 3
                ],
                "pygments_lexer": "ipython3",
                "nbconvert_exporter": "python",
                "file_extension": ".py"
            ],
            "visionos_export": [
                "export_date": ISO8601DateFormatter().string(from: Date()),
                "total_windows": windows.count,
                "window_types": Array(Set(windows.values.map { $0.windowType.rawValue })),
                "export_templates": Array(Set(windows.values.map { $0.state.exportTemplate.rawValue })),
                "all_tags": Array(Set(windows.values.flatMap { $0.state.tags })),
                "created_by": "Pulto Spatial Data Platform",
                "platform_version": "1.0"
            ]
        ]

        return [
            "cells": cells,
            "metadata": metadata,
            "nbformat": 4,
            "nbformat_minor": 5
        ]
    }

    private func createJupyterCell(from window: NewWindowID) -> [String: Any] {
        let cellType = window.state.exportTemplate == .markdown ? "markdown" : "code"

        var cell: [String: Any] = [
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
                ],
                "timestamps": [
                    "created": ISO8601DateFormatter().string(from: window.createdAt),
                    "modified": ISO8601DateFormatter().string(from: window.state.lastModified)
                ]
            ]
        ]

        // Add content based on template configuration
        let source = generateCellContent(for: window)
        cell["source"] = source.components(separatedBy: .newlines)

        // Add execution count for code cells
        if cellType == "code" {
            cell["execution_count"] = NSNull()
            cell["outputs"] = []
        }

        return cell
    }

    private func generateCellContent(for window: NewWindowID) -> String {
        switch window.windowType {
        case .charts:
            return generateChartCellContent(for: window)
        case .spatial:
            return generateSpatialCellContent(for: window)
        case .column:
            return generateDataFrameCellContent(for: window)
        case .volume:
            return generateVolumeCellContent(for: window)
        case .pointcloud:
            return generateSpatialCellContent(for: window)
        case .model3d:
            return generateModel3DCellContent(for: window)
        }
    }

    private func generateChartCellContent(for window: NewWindowID) -> String {
        if let chartData = window.state.chartData {
            return chartData.toEnhancedPythonCode()
        }

        let content = """
        # Chart Window #\(window.id) - \(window.windowType.displayName)
        # Position: (\(window.position.x), \(window.position.y), \(window.position.z))
        
        import matplotlib.pyplot as plt
        import numpy as np
        
        """
        return window.state.content.isEmpty ? content : content + "\n" + window.state.content
    }

    private func generateDataFrameCellContent(for window: NewWindowID) -> String {
        if let dataFrame = window.state.dataFrameData {
            return dataFrame.toEnhancedPandasCode()
        }

        let baseContent = """
        # DataFrame Viewer Window #\(window.id)
        # Created: \(DateFormatter.localizedString(from: window.createdAt, dateStyle: .short, timeStyle: .short))
        # Position: (\(window.position.x), \(window.position.y), \(window.position.z))
        
        import pandas as pd
        import numpy as np
        
        # DataFrame configuration from VisionOS window
        # Window size: \(window.position.width) × \(window.position.height)
        
        """

        return window.state.content.isEmpty ? baseContent : baseContent + "\n" + window.state.content
    }

    private func generateModel3DCellContent(for window: NewWindowID) -> String {
        if let model3DData = window.state.model3DData {
            return model3DData.toPythonCode()
        }

        let baseContent = """
        # 3D Model Window #\(window.id)
        # Created: \(DateFormatter.localizedString(from: window.createdAt, dateStyle: .short, timeStyle: .short))
        # Position: (\(window.position.x), \(window.position.y), \(window.position.z))
        
        import matplotlib.pyplot as plt
        import numpy as np
        from mpl_toolkits.mplot3d import Axes3D
        from mpl_toolkits.mplot3d.art3d import Poly3DCollection
        import plotly.graph_objects as go
        
        # 3D Model configuration from VisionOS window
        # Window size: \(window.position.width) × \(window.position.height)
        
        """

        return window.state.content.isEmpty ? baseContent : baseContent + "\n" + window.state.content
    }

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
    }

    private func generateSpatialCellContent(for window: NewWindowID) -> String {
        if let pointCloudData = window.state.pointCloudData {
            return pointCloudData.toPythonCode()
        }

        let content = """
        # Spatial Editor Window #\(window.id)
        
        **Position:** (\(window.position.x), \(window.position.y), \(window.position.z))  
        **Size:** \(window.position.width) × \(window.position.height)  
        **Created:** \(DateFormatter.localizedString(from: window.createdAt, dateStyle: .short, timeStyle: .short))  
        **Last Modified:** \(DateFormatter.localizedString(from: window.state.lastModified, dateStyle: .short, timeStyle: .short))
        
        ## Spatial Content
        
        """

        return window.state.content.isEmpty ? content + "*No content available*" : content + window.state.content
    }

    // MARK: - File Export

    func saveNotebookToFile(filename: String = "visionos_workspace") -> URL? {
        let notebook = exportToJupyterNotebook()

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory,
                                                                in: .userDomainMask).first else {
            return nil
        }

        let fileURL = documentsDirectory.appendingPathComponent("\(filename).ipynb")

        do {
            try notebook.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error saving notebook: \(error)")
            return nil
        }
    }

    // MARK: - Project Creation with Notebook Generation
    
    func createNewProjectWithNotebook(projectName: String) -> URL? {
        print("🚀 Creating new project: \(projectName)")
        
        // Create a basic project structure with template windows
        createTemplateWindows()
        
        // Generate and save the notebook
        let sanitizedName = projectName.replacingOccurrences(of: " ", with: "_")
        let notebookURL = saveNotebookToFile(filename: sanitizedName)
        
        if let url = notebookURL {
            print("📓 Notebook created at: \(url.path)")
            print("📊 Project contains \(getAllWindows().count) template windows")
        } else {
            print("❌ Failed to create notebook file")
        }
        
        return notebookURL
    }
    
    private func createTemplateWindows() {
        // Create a welcome markdown window
        let welcomeWindowID = getNextWindowID()
        let welcomeWindow = createWindow(.spatial, id: welcomeWindowID)
        updateWindowTemplate(welcomeWindowID, template: .markdown)
        updateWindowContent(welcomeWindowID, content: """
        # Welcome to Your New Spatial Data Project!
        
        This is your new spatial data visualization project. You can:
        
        - Add charts and visualizations
        - Import 3D models and point clouds
        - Create interactive data tables
        - Build spatial interfaces
        
        ## Getting Started
        
        1. Use the "+" button to add new windows
        2. Import your data files
        3. Create visualizations
        4. Export to Jupyter notebook when ready
        
        Happy visualizing! 🚀
        """)
        addWindowTag(welcomeWindowID, tag: "welcome")
        addWindowTag(welcomeWindowID, tag: "getting-started")
        
        // Create a sample chart window
        let chartWindowID = getNextWindowID()
        let chartWindow = createWindow(.charts, id: chartWindowID)
        updateWindowTemplate(chartWindowID, template: .matplotlib)
        updateWindowContent(chartWindowID, content: """
        # Sample Chart
        # This is a template chart to get you started
        
        import matplotlib.pyplot as plt
        import numpy as np
        
        # Generate sample data
        x = np.linspace(0, 4*np.pi, 100)
        y = np.sin(x)
        
        # Create the plot
        plt.figure(figsize=(10, 6))
        plt.plot(x, y, 'b-', linewidth=2, label='sin(x)');
        plt.title('Welcome Chart - Getting Started');
        plt.xlabel('X values');
        plt.ylabel('Y values');
        plt.grid(True, alpha=0.3);
        plt.legend();
        plt.show();
        
        print("Welcome to your new project!");
        """)
        addWindowTag(chartWindowID, tag: "sample");
        addWindowTag(chartWindowID, tag: "chart");
        
        // Create a data table template
        let dataWindowID = getNextWindowID()
        let dataWindow = createWindow(.column, id: dataWindowID)
        updateWindowTemplate(dataWindowID, template: .pandas)
        updateWindowContent(dataWindowID, content: """
        # Sample Data Table
        # This shows how to work with DataFrames
        
        import pandas as pd
        import numpy as np
        
        # Create sample data
        data = {
            'Name': ['Project A', 'Project B', 'Project C', 'Project D'],
            'Value': [23.5, 45.2, 67.8, 32.1],
            'Category': ['Research', 'Development', 'Analysis', 'Modeling'],
            'Date': pd.date_range('2024-01-01', periods=4, freq='M')
        }
        
        df = pd.DataFrame(data)
        
        print("Sample DataFrame:")
        print(df)
        print("\\nDataFrame Info:")
        print(df.info())
        """)
        addWindowTag(dataWindowID, tag: "sample");
        addWindowTag(dataWindowID, tag: "data");
        
        print("✅ Created template windows for new project")
    }

    // MARK: - 3-D Model payload --------------------------------------------
    @MainActor
    func updateWindowModel3D(_ id: Int,
                             modelData: Model3DData,
                             replaceExisting: Bool = true)
    {
        // 1. Fetch the window (dictionaries return an optional).
        guard var win = windows[id] else { return }

        // 2. Respect the caller's choice not to overwrite.
        if win.state.model3DData != nil && !replaceExisting { return }

        // 3. Update the payload and meta-data.
        win.windowType              = .model3d
        win.state.model3DData       = modelData
        win.state.lastModified      = Date()

        // 4. Write the mutated value back into the dictionary.
        windows[id] = win
        objectWillChange.send()
        WorkspaceManager.shared.scheduleAutoSave(windowManager: self)
    }

    // Updated updateUSDZBookmark function in WindowTypeManager
    func updateUSDZBookmark(for id: Int, bookmark: Data?) {
        if var window = windows[id] {
            window.state.usdzBookmark = bookmark
            windows[id] = window  // Re-assign to mutate the struct in the dictionary
            WorkspaceManager.shared.scheduleAutoSave(windowManager: self)
        }
    }

    func updatePointCloudBookmark(for id: Int, bookmark: Data?) {
        if var window = windows[id] {
            window.state.pointCloudBookmark = bookmark
            windows[id] = window  // Re-assign to mutate the struct in the dictionary
            WorkspaceManager.shared.scheduleAutoSave(windowManager: self)
        }
    }
    
    // Add this method to your existing WindowTypeManager class
    func removeWindowTag(_ windowID: Int, tag: String) {
        guard var window = windows[windowID] else { return }
        window.state.tags.removeAll { $0 == tag }
        window.state.lastModified = Date()
        windows[windowID] = window
        WorkspaceManager.shared.scheduleAutoSave(windowManager: self)
    }

    // Add these methods to WindowTypeManager class for streaming support

    // MARK: - Streaming Chart Support

    func updateWindowStreamingData(_ id: Int, streamingData: StreamingChartData) {
        windows[id]?.state.streamingChartData = streamingData
        windows[id]?.state.lastModified = Date()
        
        // Auto-set template to custom for streaming data
        if let window = windows[id], window.windowType == .spatial && window.state.exportTemplate == .plain {
            windows[id]?.state.exportTemplate = .custom
        }
    }

    func getWindowStreamingData(for id: Int) -> StreamingChartData? {
        return windows[id]?.state.streamingChartData
    }

    // Enhanced window creation for streaming
    func createStreamingWindow(_ type: WindowType, streamConfig: StreamingWindowConfig) -> NewWindowID {
        let id = getNextWindowID()
        let position = WindowPosition(
            x: streamConfig.position.x,
            y: streamConfig.position.y,
            z: streamConfig.position.z,
            width: streamConfig.size.width,
            height: streamConfig.size.height
        )
        
        let window = createWindow(type, id: id, position: position)
        
        // Add streaming-specific configuration
        addWindowTag(id, tag: "Real-Time-Streaming")
        addWindowTag(id, tag: streamConfig.streamingMode.rawValue)
        
        // Set up streaming content
        let content = generateStreamingContent(for: streamConfig)
        updateWindowContent(id, content: content)
        
        return window
    }

    private func generateStreamingContent(for config: StreamingWindowConfig) -> String {
        return """
        # Real-Time Streaming Window
        # Mode: \(config.streamingMode.rawValue)
        # Update Frequency: \(config.updateFrequency) Hz
        # Streams: \(config.numberOfStreams)
        # Created: \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))
        
        # This window displays live streaming data using RealTimeStreamingManager
        # Visualization Mode: \(config.visualizationMode.rawValue)
        # Spatial Enabled: \(config.enableSpatialVisualization)
        
        import matplotlib.pyplot as plt
        import numpy as np
        from matplotlib.animation import FuncAnimation
        
        # Real-time streaming visualization setup
        # This would be the Python equivalent of the Swift streaming implementation
        
        fig, ax = plt.subplots(figsize=(10, 6))
        ax.set_title('\(config.streamingMode.rawValue) - Real-Time Data')
        ax.set_xlabel('Time')
        ax.set_ylabel('Value')
        
        # Animation function would update the plot with new streaming data
        def animate(frame):
            # Update plot with latest data from streaming source
            pass
        
        # Set up animation with \(config.updateFrequency) Hz update rate
        ani = FuncAnimation(fig, animate, interval=\(Int(1000/config.updateFrequency)), blit=True)
        plt.show()
        
        print("Real-time streaming visualization active")
        print("Streams: \(config.numberOfStreams)")
        print("Update rate: \(config.updateFrequency) Hz")
        """
    }

    // Supporting data structures for streaming

    struct StreamingWindowConfig {
        let streamingMode: StreamingMode
        let updateFrequency: Double
        let numberOfStreams: Int
        let enableSpatialVisualization: Bool
        let visualizationMode: VisualizationMode
        let position: CGPoint
        let size: CGSize
        
        enum StreamingMode: String, CaseIterable {
            case realTimeData = "Real-Time Data Stream"
            case sensorSimulation = "Sensor Data Simulation"
            case financialData = "Financial Data Stream"
            case scientificData = "Scientific Data Stream"
        }
        
        enum VisualizationMode: String, CaseIterable {
            case realTimeFlow = "Real-Time Flow"
            case spatialCloud = "Spatial Cloud"
            case dataTrails = "Data Trails"
            case networkGraph = "Network Graph"
        }
    }

    struct StreamingChartData: Codable {
        let streamingMode: String
        let updateFrequency: Double
        let numberOfStreams: Int
        let enableSpatialVisualization: Bool
        let timeWindow: TimeInterval
        let createdDate: Date
        let isActive: Bool
        
        func toPythonCode() -> String {
            return """
            # Real-Time Streaming Chart Data
            # Mode: \(streamingMode)
            # Created: \(DateFormatter.localizedString(from: createdDate, dateStyle: .short, timeStyle: .short))
            
            import matplotlib.pyplot as plt
            import numpy as np
            import asyncio
            from matplotlib.animation import FuncAnimation
            
            # Streaming configuration
            STREAMING_MODE = '\(streamingMode)'
            UPDATE_FREQUENCY = \(updateFrequency)  # Hz
            NUMBER_OF_STREAMS = \(numberOfStreams)
            TIME_WINDOW = \(timeWindow)  # seconds
            SPATIAL_ENABLED = \(enableSpatialVisualization)
            
            class RealTimeStreamer:
                def __init__(self):
                    self.data_buffer = []
                    self.is_streaming = \(isActive ? "True" : "False")
                    
                def start_streaming(self):
                    # Initialize streaming data collection
                    print(f"Starting {STREAMING_MODE} with {NUMBER_OF_STREAMS} streams")
                    print(f"Update frequency: {UPDATE_FREQUENCY} Hz")
                    
                def update_data(self):
                    # Generate or collect new data points
                    timestamp = time.time()
                    for stream_id in range(NUMBER_OF_STREAMS):
                        value = np.random.randn()  # Simulated data
                        self.data_buffer.append({
                            'timestamp': timestamp,
                            'value': value,
                            'stream_id': stream_id
                        })
                    
                    # Keep only recent data within time window
                    cutoff_time = timestamp - TIME_WINDOW
                    self.data_buffer = [p for p in self.data_buffer if p['timestamp'] > cutoff_time]
            
            # Create and start streaming visualization
            streamer = RealTimeStreamer()
            streamer.start_streaming()
            
            print("Real-time streaming visualization initialized")
            """
        }
    }
    
    struct WindowState: Codable {
        var isMinimized = false
        var isMaximized = false
        var opacity: Double = 1.0
        var lastModified = Date()
        var content: String = ""
        var exportTemplate: ExportTemplate = .plain
        var customImports: [String] = []
        var tags: [String] = []

        // Data payloads
        var dataFrameData: DataFrameData?
        var chartData: ChartData?
        var chart3DData: Chart3DData?
        var pointCloudData: PointCloudData?
        var model3DData: Model3DData?
        var volumeData: VolumeData?
        var streamingChartData: StreamingChartData?

        // File bookmarks for security-scoped resources
        var usdzBookmark: Data?
        var pointCloudBookmark: Data?
    }
}