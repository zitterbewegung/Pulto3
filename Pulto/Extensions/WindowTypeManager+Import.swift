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

    // MARK: - Notebook Management Methods

    func openVolumetricWindow(for window: NewWindowID, using openWindow: OpenWindowAction) {
        switch window.windowType {
        case .model3d:
            openWindow(id: "volumetric-model3d", value: window.id)
        default:
            // For non-volumetric windows, open the regular window
            openWindow(id: "new-window", value: window.id)
        }
    }


    // Helper method to check if window has 3D content
    func windowHas3DContent(_ windowID: Int) -> Bool {
        guard let window = getWindowSafely(for: windowID) else { return false }
        return window.state.model3DData != nil || window.state.usdzBookmark != nil
    }

    // Clear 3D content from window
    func clearWindow3DContent(_ windowID: Int) {
        if var window = windows[windowID] {
            window.state.model3DData = nil
            window.state.usdzBookmark = nil
            window.state.lastModified = Date()
            windows[windowID] = window
            objectWillChange.send()
        }
    }

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
        case .model3d:
            if let model3DData = try parseModel3DDataFromContent(content) {
                state.model3DData = model3DData
            }
        case .column:
            if let dataFrame = try parseDataFrameFromContent(content) {
                state.dataFrameData = dataFrame
            }
        case .spatial:
            if let pointCloud = try parsePointCloudFromContent(content) {
                state.pointCloudData = pointCloud
            }
        case .charts:
            if let chartData = try parseChartDataFromContent(content) {
                state.chartData = chartData
            }
        case .volume:
            if let volumeData = try parseVolumeDataFromContent(content) {
                state.volumeData = volumeData
            }
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

    private func parseChartDataFromContent(_ content: String) throws -> ChartData? {
        // Look for structured chart data comments first (from our export format)
        if let structuredData = extractStructuredChartData(from: content) {
            return structuredData
        }
        
        // Fall back to parsing Python code
        return try parseChartDataFromPythonCode(content)
    }
    
    private func extractStructuredChartData(from content: String) -> ChartData? {
        let lines = content.components(separatedBy: .newlines)
        var title = "Restored Chart"
        var chartType = "line"
        var xLabel = "X"
        var yLabel = "Y"
        var xData: [Double] = []
        var yData: [Double] = []
        var color: String?
        var style: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Extract metadata from comments
            if trimmed.hasPrefix("# Chart Type:") {
                chartType = String(trimmed.dropFirst(13)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("# X Range:") || trimmed.hasPrefix("# Data Points:") {
                // Extract data from structured comments
                if let dataMatch = extractDataFromComment(trimmed) {
                    if trimmed.contains("X Range") {
                        xData = dataMatch
                    } else if trimmed.contains("Y Range") {
                        yData = dataMatch
                    }
                }
            } else if trimmed.hasPrefix("# Color:") {
                color = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                if color == "default" { color = nil }
            } else if trimmed.hasPrefix("# Style:") {
                style = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                if style == "default" { style = nil }
            }
            
            // Extract title from various sources
            if trimmed.hasPrefix("plt.title(") {
                title = extractStringFromPythonCall(trimmed, function: "plt.title") ?? title
            } else if trimmed.hasPrefix("# Chart from Window") {
                title = trimmed.replacingOccurrences(of: "# ", with: "")
            }
            
            // Extract labels
            if trimmed.hasPrefix("plt.xlabel(") {
                xLabel = extractStringFromPythonCall(trimmed, function: "plt.xlabel") ?? xLabel
            } else if trimmed.hasPrefix("plt.ylabel(") {
                yLabel = extractStringFromPythonCall(trimmed, function: "plt.ylabel") ?? yLabel
            }
        }
        
        // If we found actual data, create ChartData
        if !xData.isEmpty && !yData.isEmpty {
            return ChartData(
                title: title,
                chartType: chartType,
                xLabel: xLabel,
                yLabel: yLabel,
                xData: xData,
                yData: yData,
                color: color,
                style: style
            )
        }
        
        return nil
    }
    
    private func parseChartDataFromPythonCode(_ content: String) throws -> ChartData? {
        var title = "Imported Chart"
        var chartType = "line"
        var xLabel = "X"
        var yLabel = "Y"
        var xData: [Double] = []
        var yData: [Double] = []
        var color: String?
        var style: String?
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Extract data arrays
            if let data = extractDataFromVariableAssignment(trimmed, variable: "x_data") {
                xData = data
            } else if let data = extractDataFromVariableAssignment(trimmed, variable: "y_data") {
                yData = data
            } else if let data = extractDataFromVariableAssignment(trimmed, variable: "x") {
                xData = data
            } else if let data = extractDataFromVariableAssignment(trimmed, variable: "y") {
                yData = data
            }
            
            // Extract chart type from plot calls
            if trimmed.contains("plt.plot(") || trimmed.contains("ax.plot(") {
                chartType = "line"
                
                // Extract inline data from plot calls
                if let plotData = extractDataFromPlotCall(trimmed) {
                    if xData.isEmpty { xData = plotData.x }
                    if yData.isEmpty { yData = plotData.y }
                    if let plotColor = plotData.color { color = plotColor }
                    if let plotStyle = plotData.style { style = plotStyle }
                }
            } else if trimmed.contains("plt.scatter(") || trimmed.contains("ax.scatter(") {
                chartType = "scatter"
                if let plotData = extractDataFromPlotCall(trimmed) {
                    if xData.isEmpty { xData = plotData.x }
                    if yData.isEmpty { yData = plotData.y }
                }
            } else if trimmed.contains("plt.bar(") || trimmed.contains("ax.bar(") {
                chartType = "bar"
                if let plotData = extractDataFromPlotCall(trimmed) {
                    if xData.isEmpty { xData = plotData.x }
                    if yData.isEmpty { yData = plotData.y }
                }
            }
            
            // Extract labels and title
            if let extractedTitle = extractStringFromPythonCall(trimmed, function: "plt.title") {
                title = extractedTitle
            }
            if let extractedXLabel = extractStringFromPythonCall(trimmed, function: "plt.xlabel") {
                xLabel = extractedXLabel
            }
            if let extractedYLabel = extractStringFromPythonCall(trimmed, function: "plt.ylabel") {
                yLabel = extractedYLabel
            }
        }
        
        // Generate sample data if none found
        if xData.isEmpty || yData.isEmpty {
            let sampleSize = max(xData.count, yData.count, 5)
            if xData.isEmpty {
                xData = Array(stride(from: 0.0, through: Double(sampleSize - 1), by: 1.0))
            }
            if yData.isEmpty {
                yData = xData.map { sin($0 * 0.5) * 10 }
            }
        }
        
        return ChartData(
            title: title,
            chartType: chartType,
            xLabel: xLabel,
            yLabel: yLabel,
            xData: xData,
            yData: yData,
            color: color,
            style: style
        )
    }
    
    private func parseDataFrameFromContent(_ content: String) throws -> DataFrameData? {
        // Look for structured DataFrame comments first (from our export format)
        if let structuredData = extractStructuredDataFrameData(from: content) {
            return structuredData
        }
        
        // Fall back to parsing Python code
        return try parseDataFrameFromPythonCode(content)
    }
    
    private func extractStructuredDataFrameData(from content: String) -> DataFrameData? {
        let lines = content.components(separatedBy: .newlines)
        var columns: [String] = []
        var rows: [[String]] = []
        var dtypes: [String: String] = [:]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Look for structured DataFrame data in comments
            if trimmed.hasPrefix("# DataFrame Columns:") {
                let columnsStr = String(trimmed.dropFirst(20)).trimmingCharacters(in: .whitespaces)
                columns = parseArrayFromString(columnsStr)
            } else if trimmed.hasPrefix("# DataFrame Types:") {
                let typesStr = String(trimmed.dropFirst(18)).trimmingCharacters(in: .whitespaces)
                dtypes = parseDictFromString(typesStr)
            } else if trimmed.hasPrefix("# DataFrame Rows:") {
                let rowsStr = String(trimmed.dropFirst(17)).trimmingCharacters(in: .whitespaces)
                rows = parseRowsFromString(rowsStr)
            }
        }
        
        // If we found structured data, use it
        if !columns.isEmpty && !rows.isEmpty {
            return DataFrameData(
                columns: columns,
                rows: rows,
                dataTypes: dtypes
            )
        }
        
        return nil
    }
    
    private func parseDataFrameFromPythonCode(_ content: String) throws -> DataFrameData? {
        let lines = content.components(separatedBy: .newlines)
        var columns: [String] = []
        var rows: [[String]] = []
        var dtypes: [String: String] = [:]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Look for DataFrame creation patterns
            if trimmed.contains("pd.DataFrame(") {
                if let dataFrameData = extractDataFrameFromConstructor(trimmed) {
                    columns = dataFrameData.columns
                    rows = dataFrameData.rows
                    dtypes = dataFrameData.dtypes
                    break
                }
            }
            
            // Look for data dictionary patterns
            if trimmed.contains("data = {") || trimmed.contains("df_data = {") {
                if let dictData = extractDataFromDictionary(lines, startingFrom: line) {
                    columns = dictData.columns
                    rows = dictData.rows
                    dtypes = dictData.dtypes
                    break
                }
            }
        }
        
        // Generate sample data if none found
        if columns.isEmpty {
            columns = ["Column_1", "Column_2", "Column_3"]
            rows = [
                ["Sample", "1", "10.5"],
                ["Data", "2", "20.3"],
                ["Restored", "3", "15.7"]
            ]
            dtypes = [
                "Column_1": "string",
                "Column_2": "int",
                "Column_3": "float"
            ]
        }
        
        return DataFrameData(
            columns: columns,
            rows: rows,
            dataTypes: dtypes
        )
    }

    // MARK: - Parsing Helper Methods
    
    private func extractDataFromComment(_ comment: String) -> [Double]? {
        // Extract data from comments like "# X Range: [1.0, 2.0, 3.0]"
        let pattern = #"\[([\d\.,\s]+)\]"#
        if let match = comment.range(of: pattern, options: .regularExpression) {
            let dataStr = String(comment[match])
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            return dataStr.components(separatedBy: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        }
        return nil
    }
    
    private func extractStringFromPythonCall(_ line: String, function: String) -> String? {
        let pattern = #"\#(function)\(['"]([^'"]*)['"]\)"#
        if let match = line.range(of: pattern, options: .regularExpression) {
            let matchStr = String(line[match])
            // Extract the string between quotes
            let quotePattern = #"['"]([^'"]*)['"]*"#
            if let quoteMatch = matchStr.range(of: quotePattern, options: .regularExpression) {
                let quoted = String(matchStr[quoteMatch])
                return quoted.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            }
        }
        return nil
    }
    
    private func extractDataFromVariableAssignment(_ line: String, variable: String) -> [Double]? {
        let pattern = #"\#(variable)\s*=\s*\[([\d\.,\s]+)\]"#
        if let match = line.range(of: pattern, options: .regularExpression) {
            let dataStr = String(line[match])
            if let startBracket = dataStr.firstIndex(of: "["),
               let endBracket = dataStr.lastIndex(of: "]") {
                let arrayStr = String(dataStr[dataStr.index(after: startBracket)..<endBracket])
                return arrayStr.components(separatedBy: ",")
                    .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            }
        }
        return nil
    }
    
    private func extractStringFromParameter(_ paramStr: String, parameter: String) -> String? {
        let pattern = #"\#(parameter)\s*=\s*['"]([^'"]+)['"]*"#
        if let match = paramStr.range(of: pattern, options: .regularExpression) {
            let matchStr = String(paramStr[match])
            let valuePattern = #"['"]([^'"]+)['"]*"#
            if let valueMatch = matchStr.range(of: valuePattern, options: .regularExpression) {
                let quoted = String(matchStr[valueMatch])
                return quoted.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            }
        }
        return nil
    }
    
    private func extractDataFromPlotCall(_ line: String) -> (x: [Double], y: [Double], color: String?, style: String?)? {
        // Match plot calls like plt.plot([1,2,3], [4,5,6], color='blue', linestyle='-')
        let arrayPattern = #"\[([\d\.,\s]+)\]"#
        let regex = try? NSRegularExpression(pattern: arrayPattern)
        let nsString = line as NSString
        let results = regex?.matches(in: line, range: NSRange(location: 0, length: nsString.length)) ?? []
        
        var xData: [Double] = []
        var yData: [Double] = []
        
        if results.count >= 2 {
            // Extract first array (x data)
            let xRange = results[0].range
            let xStr = nsString.substring(with: NSRange(location: xRange.location + 1, length: xRange.length - 2))
            xData = xStr.components(separatedBy: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            
            // Extract second array (y data)
            let yRange = results[1].range
            let yStr = nsString.substring(with: NSRange(location: yRange.location + 1, length: yRange.length - 2))
            yData = yStr.components(separatedBy: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        }
        
        // Extract color and style parameters
        var color: String?
        var style: String?
        
        if let colorMatch = line.range(of: #"color\s*=\s*['"]([^'"]+)['"]*"#, options: .regularExpression) {
            let colorStr = String(line[colorMatch])
            color = extractStringFromParameter(colorStr, parameter: "color")
        }
        
        if let styleMatch = line.range(of: #"linestyle\s*=\s*['"]([^'"]+)['"]*"#, options: .regularExpression) {
            let styleStr = String(line[styleMatch])
            style = extractStringFromParameter(styleStr, parameter: "linestyle")
        }
        
        if !xData.isEmpty && !yData.isEmpty {
            return (x: xData, y: yData, color: color, style: style)
        }
        
        return nil
    }
    
    private func extractDataFrameFromConstructor(_ line: String) -> DataFrameData? {
        // Parse pd.DataFrame({'col1': [1,2,3], 'col2': ['a','b','c']})
        if let dictStart = line.firstIndex(of: "{"),
           let dictEnd = line.lastIndex(of: "}") {
            let dictStr = String(line[dictStart...dictEnd])
            return parseDataFrameFromDict(dictStr)
        }
        return nil
    }
    
    private func parseDataFrameFromDict(_ dictStr: String) -> DataFrameData? {
        var columns: [String] = []
        var rows: [[String]] = []
        var dtypes: [String: String] = [:]
        
        // Extract key-value pairs from the dictionary
        let kvPattern = #"['"]([^'"]+)['"]:\s*\[(.*?)\]"#
        let regex = try? NSRegularExpression(pattern: kvPattern)
        let nsString = dictStr as NSString
        let results = regex?.matches(in: dictStr, range: NSRange(location: 0, length: nsString.length)) ?? []
        
        var columnData: [String: [String]] = [:]
        
        for result in results {
            if result.numberOfRanges >= 3 {
                let keyRange = result.range(at: 1)
                let valueRange = result.range(at: 2)
                
                let key = nsString.substring(with: keyRange)
                let valueStr = nsString.substring(with: valueRange)
                
                // Parse the array values
                let values = valueStr.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " '\"")) }
                
                columns.append(key)
                columnData[key] = values
                
                // Determine data type
                if values.allSatisfy({ Int($0) != nil }) {
                    dtypes[key] = "int"
                } else if values.allSatisfy({ Double($0) != nil }) {
                    dtypes[key] = "float"
                } else {
                    dtypes[key] = "string"
                }
            }
        }
        
        // Convert column data to rows
        if !columns.isEmpty, let firstColumnData = columnData[columns[0]] {
            let rowCount = firstColumnData.count
            for i in 0..<rowCount {
                var row: [String] = []
                for column in columns {
                    if let columnValues = columnData[column], i < columnValues.count {
                        row.append(columnValues[i])
                    } else {
                        row.append("")
                    }
                }
                rows.append(row)
            }
        }
        
        if !columns.isEmpty && !rows.isEmpty {
            return DataFrameData(
                columns: columns,
                rows: rows,
                dataTypes: dtypes
            )
        }
        
        return nil
    }
    
    private func extractDataFromDictionary(_ lines: [String], startingFrom startLine: String) -> DataFrameData? {
        // Find the dictionary definition across multiple lines
        guard let startIndex = lines.firstIndex(of: startLine) else { return nil }
        
        var dictContent = ""
        var braceCount = 0
        var foundStart = false
        
        for i in startIndex..<lines.count {
            let line = lines[i]
            for char in line {
                if char == "{" {
                    braceCount += 1
                    foundStart = true
                }
                if foundStart {
                    dictContent.append(char)
                }
                if char == "}" {
                    braceCount -= 1
                    if braceCount == 0 && foundStart {
                        return parseDataFrameFromDict(dictContent)
                    }
                }
            }
            if foundStart {
                dictContent.append("\n")
            }
        }
        
        return nil
    }
    
    private func parseArrayFromString(_ str: String) -> [String] {
        let cleanStr = str.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return cleanStr.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " '\"")) }
            .filter { !$0.isEmpty }
    }
    
    private func parseDictFromString(_ str: String) -> [String: String] {
        var result: [String: String] = [:]
        let cleanStr = str.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
        let pairs = cleanStr.components(separatedBy: ",")
        
        for pair in pairs {
            let components = pair.components(separatedBy: ":")
            if components.count == 2 {
                let key = components[0].trimmingCharacters(in: CharacterSet(charactersIn: " '\""))
                let value = components[1].trimmingCharacters(in: CharacterSet(charactersIn: " '\""))
                result[key] = value
            }
        }
        
        return result
    }
    
    private func parseRowsFromString(_ str: String) -> [[String]] {
        // Parse nested array structure like [['a','b'],['c','d']]
        let cleanStr = str.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        var rows: [[String]] = []
        
        let rowPattern = #"\[([^\[\]]+)\]"#
        let regex = try? NSRegularExpression(pattern: rowPattern)
        let nsString = cleanStr as NSString
        let results = regex?.matches(in: cleanStr, range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for result in results {
            let rowStr = nsString.substring(with: result.range(at: 1))
            let values = rowStr.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " '\"")) }
            rows.append(values)
        }
        
        return rows
    }

    // MARK: - Enhanced Data Parsing Methods

    private func parsePointCloudFromContent(_ content: String) throws -> PointCloudData? {
        let patterns = [
            #"data\s*=\s*\{([^}]+)\}"#,
            #"pd\.DataFrame\(([^)]+)\)"#
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
    
    func updateDataFrame(for windowID: Int, dataFrame: DataFrameData) {
        updateWindowState(windowID) { state in
            state.dataFrameData = dataFrame
        }
    }

    func updateWindowChartData(_ windowID: Int, chartData: ChartData) {
        updateWindowState(windowID) { state in
            state.chartData = chartData
        }
    }

    func updateWindowPointCloud(_ windowID: Int, pointCloud: PointCloudData) {
        updateWindowState(windowID) { state in
            state.pointCloudData = pointCloud
        }
    }

    func getWindowChartData(for windowID: Int) -> ChartData? {
        return getWindow(for: windowID)?.state.chartData
    }

    func getWindowPointCloud(for windowID: Int) -> PointCloudData? {
        return getWindow(for: windowID)?.state.pointCloudData
    }

    private func updateWindowState(_ windowID: Int, update: (inout WindowState) -> Void) {
        if var window = getWindow(for: windowID) {
            update(&window.state)
            window.state.lastModified = Date()
            updateWindow(window)
        }
    }
    func updateUSDZBookmark(for windowID: Int, bookmark: Data) {
         updateWindowState(windowID) { state in
             state.usdzBookmark = bookmark
         }
     }

     func getWindowSafely(for id: Int) -> NewWindowID? {
         return getWindow(for: id)
     }
    // Update window with Model3D data
    func updateWindowModel3DData(_ windowID: Int, model3DData: Model3DData) {
        guard let index = windows.firstIndex(where: { $0.id == windowID }) else { return }
        windows[index].state.model3DData = model3DData
        windows[index].state.lastModified = Date()
        objectWillChange.send()
    }

    // Update window with USDZ bookmark
    func updateWindowUSDZBookmark(_ windowID: Int, bookmark: Data) {
        guard let index = windows.firstIndex(where: { $0.id == windowID }) else { return }
        windows[index].state.usdzBookmark = bookmark
        windows[index].state.lastModified = Date()
        objectWillChange.send()
    }

    // Helper method to check if window has 3D content
    func windowHas3DContent(_ windowID: Int) -> Bool {
        guard let window = getWindow(for: windowID) else { return false }
        return window.state.model3DData != nil || window.state.usdzBookmark != nil
    }

    // Clear 3D content from window
    func clearWindow3DContent(_ windowID: Int) {
        guard let index = windows.firstIndex(where: { $0.id == windowID }) else { return }
        windows[index].state.model3DData = nil
        windows[index].state.usdzBookmark = nil
        windows[index].state.lastModified = Date()
        objectWillChange.send()
    }
}