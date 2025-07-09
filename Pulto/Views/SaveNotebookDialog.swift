//
//  SaveNotebookDialog.swift
//  Pulto
//
//  Created by Joshua Herman on 6/21/25.
//  Copyright 2025 Apple. All rights reserved.
//
import SwiftUI
import UniformTypeIdentifiers
import MachO           // for run-time memory info
import Darwin.Mach     // 〃

// MARK: - File-scope helpers --------------------------------------------------

/// Maps a window type to either a markdown or code cell.
private func getCellType(for windowType: WindowType) -> String {
    windowType == .spatial || windowType == .column ? "markdown" : "code"
}

/// Builds a minimal Jupyter-cell dictionary.
private func createJupyterCell(type: String, content: String) -> [String: Any] {
    [
        "cell_type": type,
        "metadata":  [:],
        "source":    content.components(separatedBy: .newlines)
    ]
}

/// Converts a window into readable cell text.
private func generateCellContent(for window: NewWindowID) -> String {
    var content = """
    # \(window.windowType.rawValue) – ID \(window.id)
    \(window.state.content)
    """
    
    if let chartData = window.state.chartData {
        content += """
        
        # Chart Data
        # Type: \(chartData.chartType)
        # X Label: \(chartData.xLabel)
        # Y Label: \(chartData.yLabel)
        
        \(chartData.toPythonCode())
        """
    }
    
    return content
}

/// Every template your exporter supports right now.
private let availableTemplates: [ExportTemplate] = [
    .matplotlib, .pandas, .markdown, .plotly, .custom, .plain
]

// MARK: - Main View -----------------------------------------------------------

struct SaveNotebookDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject var windowManager: WindowTypeManager
    @Environment(\.dismiss) private var dismiss

    // default filename: spatial_workspace_YYYY-MM-DD
    @State private var filename: String = {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        return "spatial_workspace_\(df.string(from: Date()))"
    }()

    @State private var selectedLocation =
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    @State private var includeDebugInfo     = true
    @State private var includeTimestamps    = true
    @State private var includeWindowMetrics = true

    @State private var saveResult: SaveResult?
    @State private var isSaving          = false
    @State private var showingFilePicker = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {

                // ───── Header ───────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Label("Save Spatial Environment", systemImage: "square.and.arrow.down")
                        .font(.title2).fontWeight(.semibold)

                    Text("Export your current spatial workspace to a Jupyter notebook")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

                // ───── File details ────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    Label("File Details", systemImage: "doc.text").font(.headline)

                    TextField("Filename", text: $filename)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(validateFilename)

                    HStack {
                        Label(truncatedPath(selectedLocation), systemImage: "folder")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        Button("Change Location") { showingFilePicker = true }
                            .font(.caption).buttonStyle(.bordered)
                    }
                }
                .padding().background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // ───── Debug options ───────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    Label("Debug Information", systemImage: "ant.circle").font(.headline)

                    Toggle("Include debug metadata", isOn: $includeDebugInfo)
                    Toggle("Include timestamps",    isOn: $includeTimestamps)
                    Toggle("Include window metrics", isOn: $includeWindowMetrics)

                    if includeDebugInfo {
                        Text("Debug info is added as notebook metadata and comments.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding().background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // ───── Live preview ────────────────────────────────────
                SavePreviewSection(windowManager: windowManager)

                Spacer()

                // ───── Save result banner ──────────────────────────────
                if let result = saveResult { SaveResultView(result: result) }
            }
            .padding()
            .navigationTitle("Save Environment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: performSave)
                        .buttonStyle(.borderedProminent)
                        .disabled(filename.isEmpty || isSaving)
                }
            }
        }
        .fileImporter(isPresented: $showingFilePicker,
                      allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { selectedLocation = url }
        }
    }

    // MARK: - Helpers ------------------------------------------------------

    private func validateFilename() {
        filename = filename.replacingOccurrences(of: "/", with: "-")
                           .replacingOccurrences(of: "\\", with: "-")
                           .replacingOccurrences(of: ":", with: "-")
    }

    private func truncatedPath(_ url: URL) -> String {
        let comps = url.path.split(separator: "/")
        return comps.count > 3 ? "./" + comps.suffix(2).joined(separator: "/") : url.path
    }

    private func performSave() {
        isSaving = true

        // gather options
        let debugOptions = DebugExportOptions(
            includeDebugInfo:     includeDebugInfo,
            includeTimestamps:    includeTimestamps,
            includeWindowMetrics: includeWindowMetrics,
            exportDate:           Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            deviceInfo:           getDeviceInfo()
        )

        // export notebook
        if let url = windowManager.saveNotebookWithDebug(
            filename: filename,
            directory: selectedLocation,
            debugOptions: debugOptions
        ) {
            saveResult = SaveResult(
                success: true,
                fileURL: url,
                windowCount: windowManager.newWindows.count,
                fileSize: getFileSize(url)
            )
        } else {
            saveResult = SaveResult(
                success: false,
                fileURL: nil,
                windowCount: 0,
                fileSize: 0,
                error: "Failed to save notebook"
            )
        }

        isSaving = false

        // auto-dismiss on success
        if saveResult?.success == true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { dismiss() }
        }
    }

    private func getDeviceInfo() -> String {
        #if os(visionOS)
        "Apple Vision Pro"
        #elseif os(iOS)
        UIDevice.current.model
        #else
        "Unknown Device"
        #endif
    }

    private func getFileSize(_ url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }
}

// MARK: - Preview / Result subviews ------------------------------------------

struct SavePreviewSection: View {
    @ObservedObject var windowManager: WindowTypeManager

    private var uniqueTypes: Int {
        Set(windowManager.newWindows.map(\.windowType)).count
    }
    private var estimatedCells: Int {
        windowManager.newWindows.count * 2 + 1   // +1 for metadata cell
    }
    private var windowTypesSummary: String {
        Set(windowManager.newWindows.map(\.windowType))
            .map(\.rawValue).joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Export Preview", systemImage: "eye").font(.headline)

            HStack(spacing: 20) {
                StatBox(title: "Windows",
                        value: "\(windowManager.newWindows.count)")
                StatBox(title: "Window Types",
                        value: "\(uniqueTypes)")
                StatBox(title: "Total Cells",
                        value: "\(estimatedCells)")
            }

            if !windowManager.newWindows.isEmpty {
                Text("Includes: \(windowTypesSummary)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding().background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StatBox: View {
    let title: String; let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3).fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SaveResultView: View {
    let result: SaveResult
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.success ? "checkmark.circle.fill"
                                             : "xmark.circle.fill")
                .foregroundStyle(result.success ? .green : .red)
                .font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(result.success ? "Saved Successfully" : "Save Failed")
                    .fontWeight(.semibold)
                if result.success, let url = result.fileURL {
                    Text(url.lastPathComponent).font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: result.fileSize,
                                                   countStyle: .file))
                        .font(.caption).foregroundStyle(.secondary)
                } else if let error = result.error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            Spacer()
            #if os(macOS)
            if result.success, let url = result.fileURL {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .font(.caption).buttonStyle(.bordered)
            }
            #endif
        }
        .padding().background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Data helpers --------------------------------------------------------

struct DebugExportOptions {
    let includeDebugInfo:     Bool
    let includeTimestamps:    Bool
    let includeWindowMetrics: Bool
    let exportDate:           Date
    let appVersion:           String
    let deviceInfo:           String
}

struct SaveResult {
    let success:     Bool
    let fileURL:     URL?
    let windowCount: Int
    let fileSize:    Int64
    var error: String? = nil
}
/*
// MARK: - WindowTypeManager extension ----------------------------------------

extension WindowTypeManager {
    

    /// Public view of currently open windows.
    var newWindows: [NewWindowID] { getAllWindows() }

    /// Main save entry-point.
    func saveNotebookWithDebug(
        filename: String,
        directory: URL,
        debugOptions: DebugExportOptions
    ) -> URL? {
        
        // capture specific chart view data
        captureChartDataFromActiveViews()

        let notebookJSON = exportToJupyterNotebookWithDebug(debugOptions: debugOptions)
        let finalName = filename.hasSuffix(".ipynb") ? filename : "\(filename).ipynb"
        let fileURL   = directory.appendingPathComponent(finalName)

        do {
            try FileManager.default.createDirectory(at: directory,
                                                    withIntermediateDirectories: true)
            try notebookJSON.write(to: fileURL,
                                   atomically: true,
                                   encoding: .utf8)
            if debugOptions.includeDebugInfo {
                logDebugExport(to: directory, filename: finalName, options: debugOptions)
            }
            return fileURL
        } catch {
            print("Error saving notebook:", error)
            return nil
        }
    }
    
    private func captureChartDataFromActiveViews() {
        for window in getAllWindows() {
            if window.windowType == .charts {
                // Capture chart positions and data
                captureChartViewData(for: window.id)
            }
        }
    }
    
    private func captureChartViewData(for windowID: Int) {
        // Check if there's chart state data stored in UserDefaults
        if let data = UserDefaults.standard.data(forKey: "ChartViewModel_WindowStates"),
           let chartStates = try? JSONDecoder().decode([ChartWindowState].self, from: data) {
            
            // Convert chart states to our ChartData format
            let chartDataArray = chartStates.enumerated().map { index, state in
                ChartData(
                    title: "Chart Window \(index + 1)",
                    chartType: "bar", // Default type, could be enhanced
                    xLabel: "X Axis",
                    yLabel: "Y Axis",
                    xData: Array(stride(from: 0.0, through: Double(index + 5), by: 1.0)),
                    yData: Array(stride(from: 1.0, through: Double(index + 6), by: 1.0))
                )
            }
            
            // Store the first chart data if available
            if let firstChartData = chartDataArray.first {
                self.updateWindowChartData(windowID, chartData: firstChartData)
            }
        }
        
        // Also capture sample chart data for demonstration
        let sampleChartData = generateSampleChartData(for: windowID)
        self.updateWindowChartData(windowID, chartData: sampleChartData)
    }
    
    // Generate sample chart data
    private func generateSampleChartData(for windowID: Int) -> ChartData {
        // Generate some sample data based on window ID
        let dataPoints = 10
        let xData = Array(stride(from: 0.0, through: Double(dataPoints - 1), by: 1.0))
        let yData = xData.map { x in
            sin(x * 0.5 + Double(windowID) * 0.3) * 10 + Double(windowID) * 2
        }
        
        return ChartData(
            title: "Chart from Window \(windowID)",
            chartType: "line",
            xLabel: "Time",
            yLabel: "Value",
            xData: xData,
            yData: yData,
            color: ["blue", "red", "green", "purple"][windowID % 4],
            style: "solid"
        )
    }

    private func logDebugExport(to dir: URL,
                                filename: String,
                                options: DebugExportOptions) {
        let log = """
        VisionOS Export Log
        ===================
        Date: \(options.exportDate)
        File: \(filename)
        Windows Exported: \(newWindows.count)
        Debug Included: \(options.includeDebugInfo)
        Timestamps Included: \(options.includeTimestamps)
        Window Metrics Included: \(options.includeWindowMetrics)
        """
        try? log.write(to: dir.appendingPathComponent("\(filename).debug.log"),
                       atomically: true,
                       encoding: .utf8)
    }

    private func getMemoryUsage() -> Int64 {
        var info  = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func exportToJupyterNotebookWithDebug(
        debugOptions: DebugExportOptions
    ) -> String {

        var cells: [[String: Any]] = []

        // metadata cell
        cells.append(createJupyterCell(type: "markdown",
                                       content: generateEnhancedMetadata(debugOptions)))

        // optional debug summary cell
        if debugOptions.includeDebugInfo {
            cells.append(createJupyterCell(type: "code",
                                           content: generateDebugSummary(debugOptions)))
        }

        // one cell per window
        for win in newWindows {
            var content = generateCellContent(for: win)
            if debugOptions.includeWindowMetrics {
                content = addWindowMetrics(to: content, window: win)
            }
            cells.append(createJupyterCell(type: getCellType(for: win.windowType),
                                           content: content))
        }

        let notebook: [String: Any] = [
            "nbformat":       4,
            "nbformat_minor": 5,
            "metadata":       createEnhancedNotebookMetadata(debugOptions),
            "cells":          cells
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: notebook,
                                                     options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    // ───── Metadata / debug helpers ───────────────────────────────────

    private func generateEnhancedMetadata(_ opt: DebugExportOptions) -> String {
        let date = ISO8601DateFormatter().string(from: opt.exportDate)
        var md = """
        # VisionOS Spatial Environment Export
        
        **Export Date:** \(date)  
        **Total Windows:** \(newWindows.count)  
        **App Version:** \(opt.appVersion)  
        **Device:** \(opt.deviceInfo)
        
        ## Window Summary
        
        | Type | Count | Has Data |
        |------|-------|----------|
        """
        for (type, wins) in Dictionary(grouping: newWindows, by: \.windowType) {
            let dataCount = wins.filter { window in
                switch window.windowType {
                case .charts:
                    return window.state.chartData != nil
                case .spatial, .pointcloud:
                    return window.state.pointCloudData != nil
                case .column:
                    return window.state.dataFrameData != nil
                case .volume:
                    return window.state.volumeData != nil
                case .model3d:
                    return window.state.model3DData != nil
                }
            }.count
            md += "\n| \(type.rawValue) | \(wins.count) | \(dataCount)/\(wins.count) |"
        }

        let chartWindows = newWindows.filter { $0.windowType == .charts }
        if !chartWindows.isEmpty {
            md += """
            
            ## Chart Details
            
            | Window ID | Chart Type | Data Points | Position |
            |-----------|------------|-------------|----------|
            """
            
            for window in chartWindows {
                if let chartData = window.state.chartData {
                    md += "\n| \(window.id) | \(chartData.chartType) | \(chartData.xData.count) | (\(Int(window.position.x)), \(Int(window.position.y))) |"
                } else {
                    md += "\n| \(window.id) | No Data | 0 | (\(Int(window.position.x)), \(Int(window.position.y))) |"
                }
            }
        }

        if opt.includeDebugInfo {
            md += """

            ## Debug Information

            - Memory Usage: \(getMemoryUsage() / 1_048_576) MB
            - Export Duration: < 1 s
            - Charts with Data: \(chartWindows.filter { $0.state.chartData != nil }.count)/\(chartWindows.count)
            """
        }
        return md
    }

    private func generateDebugSummary(_ opt: DebugExportOptions) -> String {
        """
        # Debug info for spatial environment
        import json, datetime, psutil
        
        print(json.dumps({
            "export_timestamp": \(opt.exportDate.timeIntervalSince1970),
            "window_count": \(newWindows.count),
            "window_types": \(newWindows.map(\.windowType.rawValue)),
            "total_content_size": \(newWindows.reduce(0) { $0 + $1.state.content.count }),
            "app_version": "\(opt.appVersion)",
            "device": "\(opt.deviceInfo)",
            "memory_usage_mb": \(getMemoryUsage() / 1_048_576)
        }, indent=2))
        """
    }

    private func addWindowMetrics(to content: String,
                                  window: NewWindowID) -> String {
        var metrics = """
        # Window Metrics (Debug)
        # Position: (\(window.position.x), \(window.position.y), \(window.position.z))
        # Size: \(window.position.width) × \(window.position.height)
        # Created: \(window.createdAt)
        # Modified: \(window.state.lastModified)
        # Content Size: \(window.state.content.count) chars
        """
        
        if window.windowType == .charts, let chartData = window.state.chartData {
            metrics += """
            
            # Chart Metrics
            # Chart Type: \(chartData.chartType)
            # Data Points: \(chartData.xData.count)
            # X Range: [\(chartData.xData.min() ?? 0), \(chartData.xData.max() ?? 0)]
            # Y Range: [\(chartData.yData.min() ?? 0), \(chartData.yData.max() ?? 0)]
            # Color: \(chartData.color ?? "default")
            # Style: \(chartData.style ?? "default")
            """
        }
        
        metrics += """
        
        \(content)
        """
        
        return metrics
    }

    private func createEnhancedNotebookMetadata(
        _ opt: DebugExportOptions
    ) -> [String: Any] {
        var meta: [String: Any] = [
            "kernelspec":   ["display_name": "Python 3", "language": "python", "name": "python3"],
            "language_info":["name": "python", "version": "3.9.0"],
            "visionos_export": [
                "version":        "2.0",
                "export_date":    ISO8601DateFormatter().string(from: opt.exportDate),
                "total_windows":  newWindows.count,
                "window_types":   newWindows.map(\.windowType.rawValue),
                "export_templates": availableTemplates.map { "\($0)" }
            ]
        ]
        if opt.includeDebugInfo {
            meta["debug_info"] = [
                "app_version":        opt.appVersion,
                "device":             opt.deviceInfo,
                "memory_usage_bytes": getMemoryUsage()
            ]
        }
        return meta
    }
    // MARK: - Window ID helper
    /// Generate a fresh, globally-unique window identifier.
    /// Replace this with your own scheme if you already have one.
    @MainActor
    func generateNewWindowID() -> String {
        UUID().uuidString
    }

    // MARK: - Per-window 3-D data helper
    /// Persist the `model3DData` (title, geometry, etc.) for the
    /// window identified by `id`.
    ///
    /// 👉  Hook this up to whatever storage you use for window state.
    ///     The stub below simply prints in Debug builds so the app
    ///     compiles and runs.
    @MainActor
    func updateWindowModel3DData(_ id: String, model3DData: Model3DData) {
        #if DEBUG
        print("updateWindowModel3DData(id: \(id), title: \(model3DData.title))")
        #endif

        // ───────── Real implementation sketch ─────────
        // if var window = windows[id] {
        //     window.model3DData = model3DData
        //     windows[id] = window
        // }
    }
}
*/
