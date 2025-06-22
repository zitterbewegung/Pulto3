//
//  EnhancedFileManagement.swift
//  Enhanced file save/load with dialogs and debugging
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Save Dialog View
struct SaveNotebookDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject var windowManager: WindowTypeManager
    @Environment(\.dismiss) var dismiss
    
    @State private var filename: String = "spatial_workspace_\(Date().formatted(date: .abbreviated, time: .omitted).replacingOccurrences(of: "/", with: "-"))"
    @State private var selectedLocation: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    @State private var includeDebugInfo = true
    @State private var includeTimestamps = true
    @State private var includeWindowMetrics = true
    @State private var saveResult: SaveResult?
    @State private var isSaving = false
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Label("Save Spatial Environment", systemImage: "square.and.arrow.down")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Export your current spatial workspace to a Jupyter notebook")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // File naming section
                VStack(alignment: .leading, spacing: 12) {
                    Label("File Details", systemImage: "doc.text")
                        .font(.headline)
                    
                    TextField("Filename", text: $filename)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { validateFilename() }
                    
                    HStack {
                        Label(truncatedPath(selectedLocation), systemImage: "folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button("Change Location") {
                            showingFilePicker = true
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Debug options
                VStack(alignment: .leading, spacing: 12) {
                    Label("Debug Information", systemImage: "ant.circle")
                        .font(.headline)
                    
                    Toggle("Include debug metadata", isOn: $includeDebugInfo)
                    Toggle("Include timestamps", isOn: $includeTimestamps)
                    Toggle("Include window metrics", isOn: $includeWindowMetrics)
                    
                    if includeDebugInfo {
                        Text("Debug info will be added as notebook metadata and comments")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Preview section
                SavePreviewSection(windowManager: windowManager)
                
                Spacer()
                
                // Result display
                if let result = saveResult {
                    SaveResultView(result: result)
                }
            }
            .padding()
            .navigationTitle("Save Environment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        performSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(filename.isEmpty || isSaving)
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.folder]
        ) { result in
            switch result {
            case .success(let url):
                selectedLocation = url
            case .failure(let error):
                print("Folder selection error: \(error)")
            }
        }
    }
    
    private func validateFilename() {
        // Remove invalid characters
        filename = filename.replacingOccurrences(of: "/", with: "-")
        filename = filename.replacingOccurrences(of: "\\", with: "-")
        filename = filename.replacingOccurrences(of: ":", with: "-")
    }
    
    private func truncatedPath(_ url: URL) -> String {
        let path = url.path
        let components = path.components(separatedBy: "/")
        if components.count > 3 {
            return ".../\(components.suffix(2).joined(separator: "/"))"
        }
        return path
    }
    
    private func performSave() {
        isSaving = true
        
        // Create debug options
        let debugOptions = DebugExportOptions(
            includeDebugInfo: includeDebugInfo,
            includeTimestamps: includeTimestamps,
            includeWindowMetrics: includeWindowMetrics,
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            deviceInfo: getDeviceInfo()
        )
        
        // Perform the save with enhanced export
        if let savedURL = windowManager.saveNotebookWithDebug(
            filename: filename,
            directory: selectedLocation,
            debugOptions: debugOptions
        ) {
            saveResult = SaveResult(
                success: true,
                fileURL: savedURL,
                windowCount: windowManager.newWindows.count,
                fileSize: getFileSize(savedURL)
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
        
        // Auto-dismiss after successful save
        if saveResult?.success == true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        }
    }
    
    private func getDeviceInfo() -> String {
        #if os(visionOS)
        return "Apple Vision Pro"
        #elseif os(iOS)
        return UIDevice.current.model
        #else
        return "Unknown Device"
        #endif
    }
    
    private func getFileSize(_ url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}

// MARK: - Supporting Views
struct SavePreviewSection: View {
    @ObservedObject var windowManager: WindowTypeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Export Preview", systemImage: "eye")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatBox(title: "Windows", value: "\(windowManager.newWindows.count)")
                StatBox(title: "Window Types", value: "\(uniqueWindowTypes)")
                StatBox(title: "Total Cells", value: "\(estimatedCells)")
            }
            
            if !windowManager.newWindows.isEmpty {
                Text("Includes: \(windowTypesSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var uniqueWindowTypes: Int {
        Set(windowManager.newWindows.map { $0.windowType }).count
    }
    
    private var estimatedCells: Int {
        // Each window gets at least 2 cells (markdown + code)
        windowManager.newWindows.count * 2 + 1 // +1 for metadata
    }
    
    private var windowTypesSummary: String {
        let types = Set(windowManager.newWindows.map { $0.windowType })
        return types.joined(separator: ", ")
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SaveResultView: View {
    let result: SaveResult
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.success ? .green : .red)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.success ? "Saved Successfully" : "Save Failed")
                    .fontWeight(.semibold)
                
                if result.success, let url = result.fileURL {
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(ByteCountFormatter.string(fromByteCount: result.fileSize, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let error = result.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            
            Spacer()
            
            if result.success, let url = result.fileURL {
                Button("Show in Finder") {
                    #if os(macOS)
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                    #endif
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Data Models
struct DebugExportOptions {
    let includeDebugInfo: Bool
    let includeTimestamps: Bool
    let includeWindowMetrics: Bool
    let exportDate: Date
    let appVersion: String
    let deviceInfo: String
}

struct SaveResult {
    let success: Bool
    let fileURL: URL?
    let windowCount: Int
    let fileSize: Int64
    var error: String? = nil
}

// MARK: - WindowTypeManager Extension for Enhanced Export
extension WindowTypeManager {
    func saveNotebookWithDebug(
        filename: String,
        directory: URL,
        debugOptions: DebugExportOptions
    ) -> URL? {
        let notebook = exportToJupyterNotebookWithDebug(debugOptions: debugOptions)
        
        // Ensure .ipynb extension
        let cleanFilename = filename.hasSuffix(".ipynb") ? filename : "\(filename).ipynb"
        let fileURL = directory.appendingPathComponent(cleanFilename)
        
        do {
            // Create directory if needed
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            // Write file
            try notebook.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // Add debug log
            if debugOptions.includeDebugInfo {
                logDebugExport(to: directory, filename: cleanFilename, options: debugOptions)
            }
            
            return fileURL
        } catch {
            print("Error saving notebook: \(error)")
            return nil
        }
    }
    
    private func exportToJupyterNotebookWithDebug(debugOptions: DebugExportOptions) -> String {
        var cells: [[String: Any]] = []
        
        // Enhanced metadata cell with debug info
        let metadataContent = generateEnhancedMetadata(debugOptions: debugOptions)
        cells.append(createJupyterCell(type: "markdown", content: metadataContent))
        
        // Add debug summary cell if enabled
        if debugOptions.includeDebugInfo {
            let debugContent = generateDebugSummary(debugOptions: debugOptions)
            cells.append(createJupyterCell(type: "code", content: debugContent))
        }
        
        // Process each window with optional debug info
        for window in newWindows {
            let cellType = getCellType(for: window.windowType)
            var content = generateCellContent(for: window)
            
            if debugOptions.includeWindowMetrics {
                content = addWindowMetrics(to: content, window: window)
            }
            
            cells.append(createJupyterCell(type: cellType, content: content))
        }
        
        // Create notebook with enhanced metadata
        let notebook: [String: Any] = [
            "nbformat": 4,
            "nbformat_minor": 5,
            "metadata": createEnhancedNotebookMetadata(debugOptions: debugOptions),
            "cells": cells
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: notebook, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            print("Error creating notebook JSON: \(error)")
            return "{}"
        }
    }
    
    private func generateEnhancedMetadata(debugOptions: DebugExportOptions) -> String {
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.string(from: debugOptions.exportDate)
        
        var metadata = """
        # VisionOS Spatial Environment Export
        
        **Export Date:** \(date)  
        **Total Windows:** \(newWindows.count)  
        **App Version:** \(debugOptions.appVersion)  
        **Device:** \(debugOptions.deviceInfo)
        
        ## Window Summary
        
        | Type | Count | Tags |
        |------|-------|------|
        """
        
        // Group windows by type
        let groupedWindows = Dictionary(grouping: newWindows) { $0.windowType }
        for (type, windows) in groupedWindows {
            let tags = Set(windows.flatMap { $0.tags }).joined(separator: ", ")
            metadata += "\n| \(type) | \(windows.count) | \(tags.isEmpty ? "None" : tags) |"
        }
        
        if debugOptions.includeDebugInfo {
            metadata += "\n\n## Debug Information\n\n"
            metadata += "- Memory Usage: \(getMemoryUsage())\n"
            metadata += "- Export Duration: < 1s\n"
            metadata += "- Compression: None\n"
        }
        
        return metadata
    }
    
    private func generateDebugSummary(debugOptions: DebugExportOptions) -> String {
        return """
        # Debug information for spatial environment
        import json
        import datetime
        
        debug_info = {
            "export_timestamp": "\(debugOptions.exportDate.timeIntervalSince1970)",
            "window_count": \(newWindows.count),
            "window_types": \(Array(Set(newWindows.map { $0.windowType })).map { "\"\($0)\"" }),
            "total_content_size": \(newWindows.reduce(0) { $0 + $1.state.content.count }),
            "app_version": "\(debugOptions.appVersion)",
            "device": "\(debugOptions.deviceInfo)",
            "has_point_clouds": \(newWindows.contains { $0.state.pointCloudData != nil }),
            "memory_usage_mb": \(getMemoryUsage() / 1024 / 1024)
        }
        
        print(json.dumps(debug_info, indent=2))
        """
    }
    
    private func addWindowMetrics(to content: String, window: NewWindowID) -> String {
        let metrics = """
        
        # Window Metrics (Debug)
        # Position: (\(window.position.x), \(window.position.y), \(window.position.z))
        # Size: \(window.position.width) x \(window.position.height)
        # Created: \(window.createdAt)
        # Modified: \(window.state.lastModified)
        # Content Size: \(window.state.content.count) characters
        # Has Point Cloud: \(window.state.pointCloudData != nil)
        
        """
        return metrics + content
    }
    
    private func createEnhancedNotebookMetadata(debugOptions: DebugExportOptions) -> [String: Any] {
        var metadata: [String: Any] = [
            "kernelspec": [
                "display_name": "Python 3",
                "language": "python",
                "name": "python3"
            ],
            "language_info": [
                "name": "python",
                "version": "3.9.0"
            ],
            "visionos_export": [
                "version": "2.0",
                "export_date": ISO8601DateFormatter().string(from: debugOptions.exportDate),
                "total_windows": newWindows.count,
                "window_types": Array(Set(newWindows.map { $0.windowType })),
                "export_templates": availableTemplates.map { $0.name },
                "all_tags": Array(Set(newWindows.flatMap { $0.tags }))
            ]
        ]
        
        if debugOptions.includeDebugInfo {
            metadata["debug_info"] = [
                "app_version": debugOptions.appVersion,
                "device": debugOptions.deviceInfo,
                "export_duration_ms": 0,
                "memory_usage_bytes": getMemoryUsage()
            ]
        }
        
        return metadata
    }
    
    private func logDebugExport(to directory: URL, filename: String, options: DebugExportOptions) {
        let logContent = """
        VisionOS Export Log
        ===================
        Date: \(options.exportDate)
        File: \(filename)
        Windows Exported: \(newWindows.count)
        Debug Info Included: \(options.includeDebugInfo)
        Timestamps Included: \(options.includeTimestamps)
        Window Metrics Included: \(options.includeWindowMetrics)
        
        Window Details:
        """
        
        let logURL = directory.appendingPathComponent("\(filename).debug.log")
        
        do {
            try logContent.write(to: logURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write debug log: \(error)")
        }
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Usage Example
struct ContentView: View {
    @StateObject private var windowManager = WindowTypeManager.shared
    @State private var showingSaveDialog = false
    @State private var showingImportDialog = false
    
    var body: some View {
        VStack(spacing: 20) {
            Button("Save Environment...") {
                showingSaveDialog = true
            }
            .buttonStyle(.borderedProminent)
            
            Button("Import Environment...") {
                showingImportDialog = true
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $showingSaveDialog) {
            SaveNotebookDialog(
                isPresented: $showingSaveDialog,
                windowManager: windowManager
            )
        }
        .sheet(isPresented: $showingImportDialog) {
            NotebookImportDialog(
                isPresented: $showingImportDialog,
                windowManager: windowManager
            )
        }
    }
}