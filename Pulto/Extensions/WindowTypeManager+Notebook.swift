//
//  WindowTypeManager+Notebook.swift
//  Pulto3
//
//  Combined extension: import / restore, analysis, enhanced export + debug,
//  and unified Int-based Model-3D helpers.
//
//  Created by ChatGPT on 09 Jul 2025.
//

import Foundation
import SwiftUI
import MachO          // for memory-usage helper

// MARK: - Main notebook & export logic
extension WindowTypeManager {

    // ─────────────────────────────────────────────────────────────
    // MARK: 1. Generic-notebook import / restore
    // ─────────────────────────────────────────────────────────────

    func importFromGenericNotebook(data: Data) throws -> ImportResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.invalidJSON
        }
        return try restoreWindowsFromGenericNotebook(json)
    }

    func importFromGenericNotebook(fileURL: URL) throws -> ImportResult {
        try importFromGenericNotebook(data: .init(contentsOf: fileURL))
    }

    func importFromGenericNotebook(jsonString: String) throws -> ImportResult {
        guard let data = jsonString.data(using: .utf8) else { throw ImportError.invalidJSON }
        return try importFromGenericNotebook(data: data)
    }

    // ---------- core restore ----------

    private func restoreWindowsFromGenericNotebook(_ json: [String: Any]) throws -> ImportResult {
        guard let cells = json["cells"] as? [[String: Any]] else {
            throw ImportError.invalidNotebookFormat
        }

        var restored: [NewWindowID] = []
        var errors:   [ImportError] = []
        var idMap:    [Int: Int]    = [:]

        var nextID   = (getAllWindows().map(\.id).max() ?? 0) + 1

        for cell in cells {
            do {
                if let window = try extractWindowFromGenericCell(cell, nextID: nextID) {
                    if let old = extractWindowID(from: cell) { idMap[old] = nextID }
                    restored.append(window)
                    nextID += 1
                }
            } catch {
                errors.append(error as? ImportError ?? .cellParsingFailed)
            }
        }

        // persist
        for w in restored { windows[w.id] = w }

        return ImportResult(
            restoredWindows: restored,
            errors:          errors,
            originalMetadata: extractVisionOSMetadata(from: json),
            idMapping:       idMap
        )
    }

    private func extractWindowFromGenericCell(_ cell: [String: Any],
                                              nextID: Int) throws -> NewWindowID? {
        guard
            let meta        = cell["metadata"]      as? [String: Any],
            let typeString  = meta["window_type"]   as? String,
            let windowType  = WindowType(rawValue: typeString)
        else { return nil }

        var state = WindowState()
        if let st = meta["state"] as? [String: Any] {
            state.isMinimized = st["minimized"] as? Bool ?? false
            state.isMaximized = st["maximized"] as? Bool ?? false
            state.opacity     = st["opacity"]   as? Double ?? 1.0
        }

        if let t = meta["export_template"] as? String,
           let tpl = ExportTemplate(rawValue: t)       { state.exportTemplate = tpl }

        state.tags    = meta["tags"] as? [String] ?? []
        state.content = (cell["source"] as? [String])?.joined(separator: "\n") ?? ""

        if let ts  = meta["timestamps"] as? [String: String],
           let mod = ts["modified"].flatMap(parseISO8601Date) { state.lastModified = mod }

        try extractSpecializedDataFromGeneric(cellDict: cell,
                                              into: &state,
                                              windowType: windowType)

        return NewWindowID(id: nextID,
                           windowType: windowType,
                           position: extractPosition(from: meta),
                           state: state)
    }

    // ---------- helpers used above ----------

    private func extractPosition(from meta: [String: Any]) -> WindowPosition {
        let p = meta["position"] as? [String: Any] ?? [:]
        return WindowPosition(
            x:      p["x"]      as? Double ?? 0,
            y:      p["y"]      as? Double ?? 0,
            z:      p["z"]      as? Double ?? 0,
            width:  p["width"]  as? Double ?? 400,
            height: p["height"] as? Double ?? 300
        )
    }
    private func extractWindowID(from cell: [String: Any]) -> Int? {
        (cell["metadata"] as? [String: Any])?["window_id"] as? Int
    }
    private func extractVisionOSMetadata(from json: [String: Any]) -> VisionOSExportInfo? {
        guard
            let meta = json["metadata"]        as? [String: Any],
            let vOS  = meta["visionos_export"] as? [String: Any]
        else { return nil }

        return VisionOSExportInfo(
            export_date:      vOS["export_date"]      as? String ?? "",
            total_windows:    vOS["total_windows"]    as? Int    ?? 0,
            window_types:     vOS["window_types"]     as? [String] ?? [],
            export_templates: vOS["export_templates"] as? [String] ?? [],
            all_tags:         vOS["all_tags"]         as? [String] ?? []
        )
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: 2. Analysis / validation helpers
    // ─────────────────────────────────────────────────────────────

    func analyzeGenericNotebook(fileURL: URL) throws -> NotebookAnalysis {
        try analyzeGenericNotebook(
            json: try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as! [String: Any]
        )
    }

    func analyzeGenericNotebook(json: [String: Any]) throws -> NotebookAnalysis {
        guard let cells = json["cells"] as? [[String: Any]] else {
            throw ImportError.invalidNotebookFormat
        }

        var windowCells      = 0
        var types:  Set<String> = []
        var temps:  Set<String> = []

        for c in cells {
            if let m = c["metadata"] as? [String: Any],
               let t = m["window_type"] as? String {
                windowCells += 1; types.insert(t)
                if let tp = m["export_template"] as? String { temps.insert(tp) }
            }
        }

        return NotebookAnalysis(
            totalCells:    cells.count,
            windowCells:   windowCells,
            windowTypes:   Array(types),
            exportTemplates: Array(temps),
            metadata:      extractVisionOSMetadata(from: json)
        )
    }

    func validateGenericNotebook(fileURL: URL) throws -> Bool {
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        guard let root = json,
              root["cells"] != nil,
              let meta = root["metadata"] as? [String: Any],
              meta["visionos_export"] != nil
        else { return false }
        return true
    }

    // quick utility
    func clearAllWindows() {
        windows.removeAll(); objectWillChange.send()
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: 3. Enhanced export & debug helpers
    // ─────────────────────────────────────────────────────────────

    /// Public view of all windows (ordered).
    var newWindows: [NewWindowID] { getAllWindows() }
    
    /// High-level “Save with debug” entry.
    func saveNotebookWithDebug(filename:   String,
                               directory:  URL,
                               debugOptions opt: DebugExportOptions) -> URL? {

        captureChartDataFromActiveViews()

        let json   = exportToJupyterNotebookWithDebug(debugOptions: opt)
        let name   = filename.hasSuffix(".ipynb") ? filename : "\(filename).ipynb"
        let url    = directory.appendingPathComponent(name)

        do {
            try FileManager.default.createDirectory(at: directory,
                                                    withIntermediateDirectories: true)
            try json.write(to: url, atomically: true, encoding: .utf8)
            if opt.includeDebugInfo { logDebugExport(to: directory,
                                                     filename: name,
                                                     options: opt) }
            return url
        } catch {
            print("Error saving:", error); return nil
        }
    }

    // ---------- chart-capture helpers ----------

    private func captureChartDataFromActiveViews() {
        for w in getAllWindows() where w.windowType == .charts {
            captureChartViewData(for: w.id)
        }
    }

    private func captureChartViewData(for id: Int) {
        if let data = UserDefaults.standard.data(forKey: "ChartViewModel_WindowStates"),
           let states = try? JSONDecoder().decode([ChartWindowState].self, from: data),
           let first   = states.first {

            let chart = ChartData(
                title: first.title ?? "Chart Window",
                chartType: "bar",
                xLabel: "X",
                yLabel: "Y",
                xData: Array(0..<first.dataPoints).map(Double.init),
                yData: Array(0..<first.dataPoints).map(Double.init)
            )
            updateWindowChartData(id, chartData: chart)
        }

        updateWindowChartData(id, chartData: generateSampleChartData(for: id))
    }

    private func generateSampleChartData(for id: Int) -> ChartData {
        let N = 10
        let xs = (0..<N).map(Double.init)
        let ys = xs.map { sin($0 * 0.5 + Double(id) * 0.3) * 10 + Double(id) * 2 }
        return ChartData(
            title: "Chart from Window \(id)",
            chartType: "line",
            xLabel: "Time",
            yLabel: "Value",
            xData: xs,
            yData: ys,
            color: ["blue","red","green","purple"][id % 4],
            style: "solid"
        )
    }

    // ---------- export-with-debug ----------

    public func exportToJupyterNotebookWithDebug(debugOptions opt: DebugExportOptions) -> String {

        var cells: [[String: Any]] = [
            createJupyterCell(type: "markdown",
                              content: generateEnhancedMetadata(opt))
        ]

        if opt.includeDebugInfo {
            cells.append(createJupyterCell(type: "code",
                                           content: generateDebugSummary(opt)))
        }

        for w in newWindows {
            var content = generateCellContent(for: w)
            if opt.includeWindowMetrics { content = addWindowMetrics(to: content, window: w) }
            cells.append(createJupyterCell(type: getCellType(for: w.windowType),
                                           content: content))
        }

        let notebook: [String: Any] = [
            "nbformat": 4, "nbformat_minor": 5,
            "metadata": createEnhancedNotebookMetadata(opt),
            "cells":    cells
        ]

        let data = try? JSONSerialization.data(withJSONObject: notebook, options: .prettyPrinted)
        return String(data: data ?? Data(), encoding: .utf8) ?? "{}"
    }

    // ---------- debug-metadata ----------

    private func generateEnhancedMetadata(_ opt: DebugExportOptions) -> String {
        let date = ISO8601DateFormatter().string(from: opt.exportDate)
        var md   = """
        # VisionOS Spatial Environment Export

        **Export Date:** \(date)  
        **Total Windows:** \(newWindows.count)  
        **App Version:** \(opt.appVersion)  
        **Device:** \(opt.deviceInfo)

        ## Window Summary

        | Type | Count |
        |------|-------|
        """
        for (t, arr) in Dictionary(grouping: newWindows, by: \.windowType) {
            md += "\n| \(t.rawValue) | \(arr.count) |"
        }
        if opt.includeDebugInfo {
            md += """

            ## Debug

            *Memory:* \(getMemoryUsage()/1_048_576) MB
            """
        }
        return md
    }

    private func generateDebugSummary(_ opt: DebugExportOptions) -> String {
        """
        import json, psutil, datetime
        print(json.dumps({
          "export_timestamp": \(opt.exportDate.timeIntervalSince1970),
          "window_count": \(newWindows.count),
          "memory_usage_mb": \(getMemoryUsage()/1_048_576)
        }, indent=2))
        """
    }

    private func addWindowMetrics(to content: String, window: NewWindowID) -> String {
        """
        # Window Metrics
        # Position: (\(window.position.x), \(window.position.y), \(window.position.z))
        # Size: \(window.position.width)×\(window.position.height)
        # Modified: \(window.state.lastModified)

        \(content)
        """
    }

    private func logDebugExport(to dir: URL,
                                filename: String,
                                options: DebugExportOptions) {
        let log = """
        Export log — \(options.exportDate)
        Windows: \(newWindows.count)
        Debug: \(options.includeDebugInfo)
        """
        try? log.write(to: dir.appendingPathComponent("\(filename).debug.log"),
                       atomically: true, encoding: .utf8)
    }

    // ---------- helpers ----------

    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info(); var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info))/4
        _ = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return Int64(info.resident_size)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: 4. Unified Model-3D helpers  (Int IDs)
    // ─────────────────────────────────────────────────────────────

    /// Return next available Int window-ID.
    @MainActor
    func generateNewWindowID() -> Int { getNextWindowID() }

    /// Basic per-window Model-3D update.
    @MainActor
    func updateWindowModel3DData(_ id: Int, model3DData: Model3DData) {
        windows[id]?.state.model3DData = model3DData
        windows[id]?.state.lastModified = Date()
    }

    /// Overload that also stores a transform (used by VolumetricModelView).
    @MainActor
    func updateWindowModel3DData(
        _ id: Int,
        model3DData: Model3DData,
        transform: ImmersiveWindowState.Transform3D,
        rotation: SIMD3<Float>,
        scale: SIMD3<Float>
    ) {
        windows[id]?.state.model3DData = model3DData
        windows[id]?.state.lastModified = Date()
        SpatialWindowManager.shared.setWindowTransform(windowID: id, transform: transform)
        // persist rotation / scale as needed ...
    }
    // MARK: - Overloads with positional 2nd parameter ❶ & async-friendly capture

    @MainActor
    func updateWindowModel3DData(_ id: Int,
                                 _ model3DData: Model3DData) {
        updateWindowModel3DData(id, model3DData: model3DData)
    }

    @MainActor
    func updateWindowModel3DData(_ id: Int,
                                 _ model3DData: Model3DData,
                                 transform: ImmersiveWindowState.Transform3D,
                                 rotation: SIMD3<Float>,
                                 scale: SIMD3<Float>) {
        updateWindowModel3DData(id,
                                model3DData: model3DData,
                                transform: transform,
                                rotation: rotation,
                                scale: scale)
    }

}
