//
//  WorkspaceManager.swift
//  Pulto
//
//  Enhanced workspace management for custom workspaces and templates
//

import Foundation
import SwiftUI

// MARK: - Workspace Metadata Structures

struct WorkspaceMetadata: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var description: String
    var category: WorkspaceCategory
    var isTemplate: Bool
    var createdDate: Date
    var modifiedDate: Date
    var totalWindows: Int
    var windowTypes: [String]
    var tags: [String]
    var thumbnailData: Data?
    var version: String
    var fileURL: URL?
    
    init(name: String, 
         description: String = "", 
         category: WorkspaceCategory = .custom,
         isTemplate: Bool = false,
         totalWindows: Int = 0,
         windowTypes: [String] = [],
         tags: [String] = []) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.category = category
        self.isTemplate = isTemplate
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.totalWindows = totalWindows
        self.windowTypes = windowTypes
        self.tags = tags
        self.version = "1.0"
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
    
    var displaySize: String {
        if let url = fileURL,
           let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attributes[.size] as? Int64 {
            return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        }
        return "Unknown"
    }
}

enum WorkspaceCategory: String, CaseIterable, Codable {
    case custom = "Custom"
    case template = "Template"
    case demo = "Demo"
    case dataVisualization = "Data Visualization"
    case analysis = "Analysis"
    case modeling = "3D Modeling"
    case dashboard = "Dashboard"
    case research = "Research"
    
    var displayName: String {
        return self.rawValue
    }
    
    var iconName: String {
        switch self {
        case .custom:
            return "person.crop.circle"
        case .template:
            return "doc.on.doc"
        case .demo:
            return "play.circle"
        case .dataVisualization:
            return "chart.bar.xaxis"
        case .analysis:
            return "chart.line.uptrend.xyaxis"
        case .modeling:
            return "cube.transparent"
        case .dashboard:
            return "rectangle.3.group"
        case .research:
            return "magnifyingglass.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .custom:
            return .blue
        case .template:
            return .green
        case .demo:
            return .orange
        case .dataVisualization:
            return .purple
        case .analysis:
            return .pink
        case .modeling:
            return .cyan
        case .dashboard:
            return .indigo
        case .research:
            return .teal
        }
    }
}

// MARK: - Workspace Manager

class WorkspaceManager: ObservableObject {
    static let shared = WorkspaceManager()
    
    @Published private var workspaces: [WorkspaceMetadata] = []
    @Published var isLoading = false
    @Published var error: WorkspaceError?
    
    private let metadataFileName = "workspace_metadata.json"
    private let workspacesFolder = "Workspaces"
    
    private var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    private var workspacesDirectory: URL? {
        guard let documentsDirectory = documentsDirectory else { return nil }
        let workspacesURL = documentsDirectory.appendingPathComponent(workspacesFolder)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: workspacesURL.path) {
            try? FileManager.default.createDirectory(at: workspacesURL, withIntermediateDirectories: true)
        }
        
        return workspacesURL
    }
    
    private init() {
        loadWorkspacesMetadata()
    }
    
    // MARK: - Public Methods
    
    func getAllWorkspaces() -> [WorkspaceMetadata] {
        return workspaces.sorted { $0.modifiedDate > $1.modifiedDate }
    }
    
    func getCustomWorkspaces() -> [WorkspaceMetadata] {
        return workspaces.filter { !$0.isTemplate }.sorted { $0.modifiedDate > $1.modifiedDate }
    }
    
    func getTemplates() -> [WorkspaceMetadata] {
        return workspaces.filter { $0.isTemplate }.sorted { $0.name < $1.name }
    }
    
    func getWorkspaces(for category: WorkspaceCategory) -> [WorkspaceMetadata] {
        return workspaces.filter { $0.category == category }.sorted { $0.modifiedDate > $1.modifiedDate }
    }
    
    func searchWorkspaces(query: String) -> [WorkspaceMetadata] {
        guard !query.isEmpty else { return getAllWorkspaces() }
        
        let lowercaseQuery = query.lowercased()
        return workspaces.filter { workspace in
            workspace.name.lowercased().contains(lowercaseQuery) ||
            workspace.description.lowercased().contains(lowercaseQuery) ||
            workspace.tags.contains { $0.lowercased().contains(lowercaseQuery) }
        }.sorted { $0.modifiedDate > $1.modifiedDate }
    }
    
    // MARK: - Workspace Creation and Management
    
    func createNewWorkspace(
        name: String,
        description: String = "",
        category: WorkspaceCategory = .custom,
        tags: [String] = [],
        windowManager: WindowTypeManager
    ) async throws -> WorkspaceMetadata {
        
        guard !name.isEmpty else {
            throw WorkspaceError.invalidName
        }
        
        // Check for duplicate names
        if workspaces.contains(where: { $0.name == name }) {
            throw WorkspaceError.duplicateName
        }
        
        let windows = windowManager.getAllWindows()
        let windowTypes = Array(Set(windows.map { $0.windowType.rawValue }))
        
        var metadata = WorkspaceMetadata(
            name: name,
            description: description,
            category: category,
            isTemplate: false,
            totalWindows: windows.count,
            windowTypes: windowTypes,
            tags: tags
        )
        
        // Save the workspace file
        let fileURL = try await saveWorkspaceToFile(metadata: metadata, windowManager: windowManager)
        metadata.fileURL = fileURL
        
        // Add to metadata
        workspaces.append(metadata)
        saveWorkspacesMetadata()
        
        return metadata
    }
    
    func saveCurrentWorkspace(
        with metadata: WorkspaceMetadata,
        windowManager: WindowTypeManager
    ) async throws {
        
        let windows = windowManager.getAllWindows()
        var updatedMetadata = metadata
        updatedMetadata.modifiedDate = Date()
        updatedMetadata.totalWindows = windows.count
        updatedMetadata.windowTypes = Array(Set(windows.map { $0.windowType.rawValue }))
        
        // Save the workspace file
        let fileURL = try await saveWorkspaceToFile(metadata: updatedMetadata, windowManager: windowManager)
        updatedMetadata.fileURL = fileURL
        
        // Update in array
        if let index = workspaces.firstIndex(where: { $0.id == metadata.id }) {
            workspaces[index] = updatedMetadata
            saveWorkspacesMetadata()
        }
    }
    
    func loadWorkspace(
        _ metadata: WorkspaceMetadata,
        into windowManager: WindowTypeManager,
        clearExisting: Bool = true,
        openWindow: @escaping (Int) -> Void
    ) async throws -> EnvironmentRestoreResult {
        
        guard let fileURL = metadata.fileURL else {
            throw WorkspaceError.fileNotFound
        }
        
        if clearExisting {
            await MainActor.run {
                windowManager.clearAllWindows()
            }
        }
        
        let importResult = try windowManager.importFromGenericNotebook(fileURL: fileURL)
        
        // Open windows with visual feedback
        var openedWindows: [NewWindowID] = []
        
        for window in importResult.restoredWindows {
            await MainActor.run {
                openWindow(window.id)
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
    
    func deleteWorkspace(_ metadata: WorkspaceMetadata) throws {
        // Delete file
        if let fileURL = metadata.fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        // Remove from metadata
        workspaces.removeAll { $0.id == metadata.id }
        saveWorkspacesMetadata()
    }
    
    func duplicateWorkspace(_ metadata: WorkspaceMetadata) throws -> WorkspaceMetadata {
        var newMetadata = metadata
        newMetadata.id = UUID()
        newMetadata.name = "\(metadata.name) Copy"
        newMetadata.createdDate = Date()
        newMetadata.modifiedDate = Date()
        newMetadata.isTemplate = false
        newMetadata.category = .custom
        
        // Copy file if it exists
        if let originalURL = metadata.fileURL,
           let workspacesDir = workspacesDirectory {
            
            let newFileName = generateFileName(for: newMetadata.name)
            let newURL = workspacesDir.appendingPathComponent(newFileName)
            
            try FileManager.default.copyItem(at: originalURL, to: newURL)
            newMetadata.fileURL = newURL
        }
        
        workspaces.append(newMetadata)
        saveWorkspacesMetadata()
        
        return newMetadata
    }
    
    // MARK: - File Management
    
    private func saveWorkspaceToFile(
        metadata: WorkspaceMetadata,
        windowManager: WindowTypeManager
    ) async throws -> URL {
        
        guard let workspacesDir = workspacesDirectory else {
            throw WorkspaceError.directoryCreationFailed
        }
        
        let fileName = generateFileName(for: metadata.name)
        let fileURL = workspacesDir.appendingPathComponent(fileName)
        
        // Generate enhanced notebook with workspace metadata
        let notebookJSON = generateEnhancedNotebook(metadata: metadata, windowManager: windowManager)
        
        try notebookJSON.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    private func generateFileName(for name: String) -> String {
        let sanitizedName = name
            .components(separatedBy: .alphanumerics.inverted)
            .joined(separator: "_")
            .lowercased()
        
        let timestamp = DateFormatter.fileNameFormatter.string(from: Date())
        return "\(sanitizedName)_\(timestamp).ipynb"
    }
    
    private func generateEnhancedNotebook(
        metadata: WorkspaceMetadata,
        windowManager: WindowTypeManager
    ) -> String {
        
        let cells = windowManager.getAllWindows().map { window in
            createJupyterCell(from: window)
        }
        
        let notebookMetadata: [String: Any] = [
            "kernelspec": [
                "display_name": "Python 3",
                "language": "python",
                "name": "python3"
            ],
            "language_info": [
                "name": "python",
                "version": "3.8.0"
            ],
            "visionos_export": [
                "export_date": ISO8601DateFormatter().string(from: Date()),
                "total_windows": windowManager.getAllWindows().count,
                "window_types": Array(Set(windowManager.getAllWindows().map { $0.windowType.rawValue })),
                "export_templates": Array(Set(windowManager.getAllWindows().map { $0.state.exportTemplate.rawValue })),
                "all_tags": Array(Set(windowManager.getAllWindows().flatMap { $0.state.tags }))
            ],
            "workspace_metadata": [
                "id": metadata.id.uuidString,
                "name": metadata.name,
                "description": metadata.description,
                "category": metadata.category.rawValue,
                "is_template": metadata.isTemplate,
                "created_date": ISO8601DateFormatter().string(from: metadata.createdDate),
                "modified_date": ISO8601DateFormatter().string(from: Date()),
                "tags": metadata.tags,
                "version": metadata.version
            ]
        ]
        
        let notebook: [String: Any] = [
            "cells": cells,
            "metadata": notebookMetadata,
            "nbformat": 4,
            "nbformat_minor": 4
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: notebook, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            print("Error creating enhanced notebook JSON: \(error)")
            return "{}"
        }
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
        
        // Add content based on window type
        let source = generateCellContent(for: window)
        cell["source"] = source.components(separatedBy: .newlines)
        
        if cellType == "code" {
            cell["execution_count"] = NSNull()
            cell["outputs"] = []
        }
        
        return cell
    }
    
    private func generateCellContent(for window: NewWindowID) -> String {
        // This would call the existing WindowTypeManager methods
        switch window.windowType {
        case .charts:
            return generateChartCellContent(for: window)
        case .spatial, .pointcloud:
            return generateSpatialCellContent(for: window)
        case .column:
            return generateDataFrameCellContent(for: window)
        case .volume:
            return generateVolumeCellContent(for: window)
        case .model3d:
            return generateModel3DCellContent(for: window)
        }
    }
    
    // Basic content generation (simplified versions)
    private func generateChartCellContent(for window: NewWindowID) -> String {
        let content = """
        # Chart Window #\(window.id) - \(window.windowType.displayName)
        # Position: (\(window.position.x), \(window.position.y), \(window.position.z))
        
        import matplotlib.pyplot as plt
        import numpy as np
        
        """
        return window.state.content.isEmpty ? content : content + "\n" + window.state.content
    }
    
    private func generateSpatialCellContent(for window: NewWindowID) -> String {
        if let pointCloud = window.state.pointCloudData {
            return pointCloud.toPythonCode()
        }
        
        let content = """
        # Spatial Window #\(window.id) - \(window.windowType.displayName)
        # Position: (\(window.position.x), \(window.position.y), \(window.position.z))
        
        """
        return window.state.content.isEmpty ? content : content + "\n" + window.state.content
    }
    
    private func generateDataFrameCellContent(for window: NewWindowID) -> String {
        if let dataFrame = window.state.dataFrameData {
            return dataFrame.toPandasCode()
        }
        
        let content = """
        # DataFrame Window #\(window.id)
        # Position: (\(window.position.x), \(window.position.y), \(window.position.z))
        
        import pandas as pd
        import numpy as np
        
        """
        return window.state.content.isEmpty ? content : content + "\n" + window.state.content
    }
    
    private func generateVolumeCellContent(for window: NewWindowID) -> String {
        if let volumeData = window.state.volumeData {
            return volumeData.toPythonCode()
        }
        
        let content = """
        # Volume Window #\(window.id)
        # Position: (\(window.position.x), \(window.position.y), \(window.position.z))
        
        """
        return window.state.content.isEmpty ? content : content + "\n" + window.state.content
    }
    
    private func generateModel3DCellContent(for window: NewWindowID) -> String {
        if let model3D = window.state.model3DData {
            return model3D.toPythonCode()
        }
        
        let content = """
        # 3D Model Window #\(window.id)
        # Position: (\(window.position.x), \(window.position.y), \(window.position.z))
        
        """
        return window.state.content.isEmpty ? content : content + "\n" + window.state.content
    }
    
    // MARK: - Metadata Management
    
    private func loadWorkspacesMetadata() {
        guard let documentsDirectory = documentsDirectory else { return }
        
        let metadataURL = documentsDirectory.appendingPathComponent(metadataFileName)
        
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            // Initialize with empty array and scan for existing files
            scanForExistingWorkspaces()
            return
        }
        
        do {
            let data = try Data(contentsOf: metadataURL)
            let decoder = JSONDecoder()
            self.workspaces = try decoder.decode([WorkspaceMetadata].self, from: data)
            
            // Verify files still exist and update file URLs
            updateFileURLs()
        } catch {
            print("Error loading workspace metadata: \(error)")
            scanForExistingWorkspaces()
        }
    }
    
    private func saveWorkspacesMetadata() {
        guard let documentsDirectory = documentsDirectory else { return }
        
        let metadataURL = documentsDirectory.appendingPathComponent(metadataFileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(workspaces)
            try data.write(to: metadataURL)
        } catch {
            print("Error saving workspace metadata: \(error)")
        }
    }
    
    private func scanForExistingWorkspaces() {
        guard let workspacesDir = workspacesDirectory else { return }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: workspacesDir,
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension == "ipynb" }
            
            for fileURL in fileURLs {
                if !workspaces.contains(where: { $0.fileURL == fileURL }) {
                    if let metadata = createMetadataFromFile(fileURL) {
                        workspaces.append(metadata)
                    }
                }
            }
            
            saveWorkspacesMetadata()
        } catch {
            print("Error scanning for existing workspaces: \(error)")
        }
    }
    
    private func updateFileURLs() {
        guard let workspacesDir = workspacesDirectory else { return }
        
        for i in 0..<workspaces.count {
            if let currentURL = workspaces[i].fileURL,
               !FileManager.default.fileExists(atPath: currentURL.path) {
                
                // Try to find the file by name
                let fileName = currentURL.lastPathComponent
                let newURL = workspacesDir.appendingPathComponent(fileName)
                
                if FileManager.default.fileExists(atPath: newURL.path) {
                    workspaces[i].fileURL = newURL
                } else {
                    // File not found, remove from metadata
                    workspaces.remove(at: i)
                }
            }
        }
        
        saveWorkspacesMetadata()
    }
    
    private func createMetadataFromFile(_ fileURL: URL) -> WorkspaceMetadata? {
        do {
            let data = try Data(contentsOf: fileURL)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            // Extract metadata from notebook
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            
            let createdDate = attributes[.creationDate] as? Date ?? Date()
            let modifiedDate = attributes[.modificationDate] as? Date ?? Date()
            
            // Check for workspace metadata in the notebook
            if let notebookMetadata = json["metadata"] as? [String: Any],
               let workspaceMetadata = notebookMetadata["workspace_metadata"] as? [String: Any] {
                
                // Use existing workspace metadata
                var metadata = WorkspaceMetadata(
                    name: workspaceMetadata["name"] as? String ?? fileName,
                    description: workspaceMetadata["description"] as? String ?? "",
                    category: WorkspaceCategory(rawValue: workspaceMetadata["category"] as? String ?? "Custom") ?? .custom,
                    isTemplate: workspaceMetadata["is_template"] as? Bool ?? false
                )
                
                if let idString = workspaceMetadata["id"] as? String,
                   let uuid = UUID(uuidString: idString) {
                    metadata.id = uuid
                }
                
                metadata.createdDate = createdDate
                metadata.modifiedDate = modifiedDate
                metadata.fileURL = fileURL
                
                return metadata
            } else {
                // Create basic metadata from VisionOS export info
                var metadata = WorkspaceMetadata(
                    name: fileName,
                    description: "Imported workspace",
                    category: .custom,
                    isTemplate: false
                )
                
                metadata.createdDate = createdDate
                metadata.modifiedDate = modifiedDate
                metadata.fileURL = fileURL
                
                if let notebookMetadata = json["metadata"] as? [String: Any],
                   let visionOSMetadata = notebookMetadata["visionos_export"] as? [String: Any] {
                    metadata.totalWindows = visionOSMetadata["total_windows"] as? Int ?? 0
                    metadata.windowTypes = visionOSMetadata["window_types"] as? [String] ?? []
                }
                
                return metadata
            }
        } catch {
            print("Error creating metadata from file \(fileURL): \(error)")
            return nil
        }
    }
}

// MARK: - Error Types

enum WorkspaceError: LocalizedError {
    case invalidName
    case duplicateName
    case fileNotFound
    case directoryCreationFailed
    case saveError(String)
    case loadError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Invalid workspace name"
        case .duplicateName:
            return "A workspace with this name already exists"
        case .fileNotFound:
            return "Workspace file not found"
        case .directoryCreationFailed:
            return "Failed to create workspace directory"
        case .saveError(let message):
            return "Save error: \(message)"
        case .loadError(let message):
            return "Load error: \(message)"
        }
    }
}

// MARK: - Navigation Helper
// Add this to your main app or navigation controller

struct ChartVisualizationNavigator {
    static func openSpatialEditorWithChart(
        windowID: Int,
        csvData: CSVData,
        recommendation: ChartRecommendation,
        chartData: ChartData
    ) {
        let chartVizData = SpatialEditorView.ChartVisualizationData(
            csvData: csvData,
            recommendation: recommendation,
            chartData: chartData
        )

        // Create and present the spatial editor
        // This depends on your navigation system
        // Example for SwiftUI:

        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let spatialEditor = SpatialEditorView(
                windowID: windowID,
                initialChart: chartVizData
            )

            let hostingController = UIHostingController(rootView: spatialEditor)
            window.rootViewController?.present(hostingController, animated: true)
        }
        #elseif os(macOS)
        let spatialEditor = SpatialEditorView(
            windowID: windowID,
            initialChart: chartVizData
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Spatial Editor - Window #\(windowID)"
        window.contentView = NSHostingView(rootView: spatialEditor)
        window.makeKeyAndOrderFront(nil)
        #endif
    }
}


// MARK: - Helper Extensions

extension DateFormatter {
    static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}
