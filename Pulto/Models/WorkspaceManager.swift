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

@MainActor
class WorkspaceManager: ObservableObject {
    static let shared = WorkspaceManager()
    
    @Published private var workspaces: [WorkspaceMetadata] = []
    @Published var isLoading = false
    @Published var error: WorkspaceError?
    
    // Add auto-save properties
    @AppStorage("autoSaveEnabled") private var autoSaveEnabled: Bool = true
    private var saveTask: Task<Void, Never>? = nil
    private var pendingWindowChanges = false
    
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
    
    func getDemoWorkspaces() -> [WorkspaceMetadata] {
        return workspaces.filter { $0.category == .demo }.sorted { $0.modifiedDate > $1.modifiedDate }
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
    
    /// Refreshes metadata for all workspaces by re-reading their files
    /// This fixes the "0 views" issue for existing workspaces  
    func refreshWorkspaceMetadata() async {
        print("🔄 WorkspaceManager: Refreshing workspace metadata...")
        
        for i in 0..<workspaces.count {
            if let fileURL = workspaces[i].fileURL,
               let refreshedMetadata = createMetadataFromFile(fileURL) {
                // Preserve important user-set fields
                var updatedMetadata = refreshedMetadata
                updatedMetadata.id = workspaces[i].id
                updatedMetadata.name = workspaces[i].name
                updatedMetadata.description = workspaces[i].description
                updatedMetadata.category = workspaces[i].category
                updatedMetadata.isTemplate = workspaces[i].isTemplate
                updatedMetadata.tags = workspaces[i].tags
                
                let oldCount = workspaces[i].totalWindows
                workspaces[i] = updatedMetadata
                
                print("✅ WorkspaceManager: Updated '\(updatedMetadata.name)' - \(oldCount) → \(updatedMetadata.totalWindows) windows")
            } else {
                print("❌ WorkspaceManager: Failed to refresh '\(workspaces[i].name)'")
            }
        }
        
        saveWorkspacesMetadata()
        objectWillChange.send()
        print("🎉 WorkspaceManager: Metadata refresh complete")
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
            print("❌ WorkspaceManager: File URL not found for workspace: \(metadata.name)")
            throw WorkspaceError.fileNotFound
        }
        
        print("🔄 WorkspaceManager: Loading workspace '\(metadata.name)' from \(fileURL.lastPathComponent)")
        
        if clearExisting {
            await windowManager.clearAllWindows()
            print("🗑️ WorkspaceManager: Cleared existing windows")
        }
        
        let importResult = try windowManager.importFromGenericNotebook(fileURL: fileURL)
        print("📥 WorkspaceManager: Imported \(importResult.restoredWindows.count) windows from notebook")
        
        // Open windows with visual feedback and proper window type handling
        var openedWindows: [NewWindowID] = []
        
        for window in importResult.restoredWindows {
            print("🪟 WorkspaceManager: Processing window #\(window.id) (\(window.windowType.displayName))")
            
            // Store window data in manager before opening
            // (This ensures the window data is available when openWindow is called)
            
            openWindow(window.id) // This will call the closure that handles window type detection
            await windowManager.markWindowAsOpened(window.id)
            openedWindows.append(window)
            
            print("✅ WorkspaceManager: Opened and marked window #\(window.id)")
            
            // Small delay for smooth animation
            try? await Task.sleep(nanoseconds: 300_000_000) // Increased delay for volumetric windows
        }
        
        print("✅ WorkspaceManager: Successfully opened \(openedWindows.count) windows")
        
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
        
        try notebookJSON.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        
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
        
        let kernelspec: [String: Any] = [
            "display_name": "Python 3",
            "language": "python",
            "name": "python3"
        ]
        
        let languageInfo: [String: Any] = [
            "name": "python",
            "version": "3.8.0"
        ]
        
        let visionOSExport: [String: Any] = [
            "export_date": ISO8601DateFormatter().string(from: Date()),
            "total_windows": windowManager.getAllWindows().count,
            "window_types": Array(Set(windowManager.getAllWindows().map { $0.windowType.rawValue })),
            "export_templates": Array(Set(windowManager.getAllWindows().map { $0.state.exportTemplate.rawValue })),
            "all_tags": Array(Set(windowManager.getAllWindows().flatMap { $0.state.tags }))
        ]
        
        let workspaceMetadataDict: [String: Any] = [
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
        
        let notebookMetadata: [String: Any] = [
            "kernelspec": kernelspec,
            "language_info": languageInfo,
            "visionos_export": visionOSExport,
            "workspace_metadata": workspaceMetadataDict
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
                let fileName = currentURL.deletingPathExtension().lastPathComponent
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
            
            // Count cells and determine window count
            var windowCount = 0
            var windowTypes: [String] = []
            var isVisionOSNotebook = false
            
            if let cells = json["cells"] as? [[String: Any]] {
                for cell in cells {
                    if let metadata = cell["metadata"] as? [String: Any],
                       let windowType = metadata["window_type"] as? String {
                        // This is a visionOS notebook with window metadata
                        windowCount += 1
                        isVisionOSNotebook = true
                        if !windowTypes.contains(windowType) {
                            windowTypes.append(windowType)
                        }
                    } else if !isVisionOSNotebook {
                        // For regular Jupyter notebooks, count non-empty cells as potential windows
                        if let source = cell["source"] as? [String] {
                            let content = source.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                            if !content.isEmpty {
                                windowCount += 1
                            }
                        } else if let source = cell["source"] as? String {
                            let content = source.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !content.isEmpty {
                                windowCount += 1
                            }
                        }
                    }
                }
                
                // If no visionOS cells were found but we have regular cells, treat as importable notebook
                if !isVisionOSNotebook && windowCount > 0 {
                    windowTypes = ["notebook"] // Generic type for regular notebooks
                }
            }
            
            // Check for workspace metadata in the notebook
            if let notebookMetadata = json["metadata"] as? [String: Any],
               let workspaceMetadata = notebookMetadata["workspace_metadata"] as? [String: Any] {
                
                // Use existing workspace metadata
                var metadata = WorkspaceMetadata(
                    name: workspaceMetadata["name"] as? String ?? fileName,
                    description: workspaceMetadata["description"] as? String ?? "",
                    category: WorkspaceCategory(rawValue: workspaceMetadata["category"] as? String ?? "Custom") ?? .custom,
                    isTemplate: workspaceMetadata["is_template"] as? Bool ?? false,
                    totalWindows: windowCount, // Use actual count from cells
                    windowTypes: windowTypes,
                    tags: workspaceMetadata["tags"] as? [String] ?? []
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
                // Create basic metadata from notebook analysis
                let description = isVisionOSNotebook ? 
                    "VisionOS spatial workspace" : 
                    "Jupyter notebook (\(windowCount) cells)"
                
                var metadata = WorkspaceMetadata(
                    name: fileName,
                    description: description,
                    category: isVisionOSNotebook ? .custom : .demo,
                    isTemplate: false,
                    totalWindows: windowCount,
                    windowTypes: windowTypes,
                    tags: isVisionOSNotebook ? ["visionos"] : ["jupyter", "notebook"]
                )
                
                metadata.createdDate = createdDate
                metadata.modifiedDate = modifiedDate
                metadata.fileURL = fileURL
                
                // Try to get additional info from visionOS export metadata if available
                if let notebookMetadata = json["metadata"] as? [String: Any],
                   let visionOSMetadata = notebookMetadata["visionos_export"] as? [String: Any] {
                    // Use the count from visionOS metadata if it's higher (backup)
                    let visionOSWindowCount = visionOSMetadata["total_windows"] as? Int ?? 0
                    metadata.totalWindows = max(windowCount, visionOSWindowCount)
                    
                    // Use visionOS window types if cell parsing didn't find any
                    if windowTypes.isEmpty {
                        metadata.windowTypes = visionOSMetadata["window_types"] as? [String] ?? []
                    }
                }
                
                return metadata
            }
        } catch {
            print("Error creating metadata from file \(fileURL): \(error)")
            return nil
        }
    }
    
    // Add method to ensure project workspace exists for auto-save
    func ensureProjectWorkspaceExists(for project: ProjectModel) async {
        // Check if workspace already exists
        if workspaces.contains(where: { $0.name == project.name }) {
            print("📁 Workspace already exists for project: \(project.name)")
            return
        }
        
        // Create a workspace metadata entry for the project
        let workspace = WorkspaceMetadata(
            name: project.name,
            description: "Auto-created workspace for project: \(project.name)",
            category: .custom,
            isTemplate: false,
            totalWindows: 0,
            windowTypes: [],
            tags: ["auto-created", "project"]
        )
        
        workspaces.append(workspace)
        saveWorkspacesMetadata()
        print("📁 Created workspace metadata for project: \(project.name)")
    }

    // Add method to handle auto-saving when windows change
    func scheduleAutoSave(windowManager: WindowTypeManager) async {
        guard autoSaveEnabled else {
            print("⏸️ Auto-save disabled, skipping")
            return
        }
        
        guard let selectedProject = await windowManager.selectedProject else {
            print("⚠️ No selected project for auto-save")
            return
        }
        
        // Find or create workspace for the project
        var projectWorkspace = workspaces.first { $0.name == selectedProject.name }
        
        if projectWorkspace == nil {
            // Create workspace metadata if it doesn't exist
            let windows = await windowManager.getAllWindows()
            let newWorkspace = WorkspaceMetadata(
                name: selectedProject.name,
                description: "Auto-created workspace for project: \(selectedProject.name)",
                category: .custom,
                isTemplate: false,
                totalWindows: windows.count,
                windowTypes: Array(Set(windows.map { $0.windowType.rawValue })),
                tags: ["auto-created", "project"]
            )
            workspaces.append(newWorkspace)
            projectWorkspace = newWorkspace
            print("📁 Created new workspace for auto-save: \(selectedProject.name)")
        }
        
        guard let workspace = projectWorkspace else {
            print("❌ Failed to find or create workspace for auto-save")
            return
        }
        
        // Cancel any existing save task
        saveTask?.cancel()
        
        // Mark that we have pending changes
        pendingWindowChanges = true
        
        // Schedule a new save task with debounce (1 second delay)
        saveTask = Task { @MainActor in
            do {
                // Wait for 1 second to debounce
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Perform the save
                if pendingWindowChanges {
                    do {
                        try await saveCurrentWorkspace(with: workspace, windowManager: windowManager)
                        pendingWindowChanges = false
                        print("✅ Auto-saved workspace: \(workspace.name) with \(await windowManager.getAllWindows().count) windows")
                    } catch {
                        print("❌ Failed to auto-save workspace: \(error)")
                    }
                }
            } catch {
                // Task was cancelled, do nothing
                print("⏸️ Auto-save task cancelled")
            }
        }
    }
}

// MARK: - Endpoint Data Streaming Extension

extension WorkspaceManager {
    /// Stream data from a remote endpoint and create/update windows with the data
    /// - Parameters:
    ///   - endpointURL: The URL of the data endpoint
    ///   - windowManager: The window manager to update with the streamed data
    ///   - windowType: The type of window to create/update
    ///   - updateInterval: How frequently to poll the endpoint (in seconds)
    func streamData(
        from endpointURL: String,
        using windowManager: WindowTypeManager,
        as windowType: WindowType,
        updateInterval: TimeInterval = 5.0
    ) async throws {
        guard let url = URL(string: endpointURL) else {
            throw WorkspaceError.loadError("Invalid endpoint URL")
        }
        
        print("📡 Starting data stream from: \(endpointURL)")
        
        // Create a new window for the streamed data
        let nextID = windowManager.getNextWindowID()
        let newWindow = windowManager.createWindow(windowType, id: nextID)
        print("🪟 Created new window #\(newWindow.id) for streaming")
        
        // Start streaming data
        Task {
            while true {
                do {
                    // Fetch data from endpoint
                    let (data, response) = try await URLSession.shared.data(from: url)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        print("❌ HTTP error when fetching data")
                        try await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
                        continue
                    }
                    
                    // Process the data based on window type
                    let dataString = String(data: data, encoding: .utf8) ?? ""
                    
                    // Update window content
                    windowManager.updateWindowContent(newWindow.id, content: dataString)
                    
                    print("✅ Updated window #\(newWindow.id) with \(data.count) bytes of data")
                    
                    // Wait for next update
                    try await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
                } catch {
                    print("❌ Error streaming data: \(error)")
                    try await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
                }
            }
        }
    }
    
    /// Stream data from a Jupyter notebook endpoint
    /// - Parameters:
    ///   - jupyterClient: The Jupyter API client to use
    ///   - notebookPath: Path to the notebook on the server
    ///   - windowManager: The window manager to update with the notebook data
    func streamJupyterNotebook(
        using jupyterClient: JupyterAPIClient,
        notebookPath: String,
        windowManager: WindowTypeManager
    ) async throws {
        print("📡 Starting Jupyter notebook stream: \(notebookPath)")
        
        // Fetch the notebook
        let notebook = try await jupyterClient.fetchNotebook(at: notebookPath)
        
        // Create a window for each cell in the notebook
        if let content = notebook.content {
            for (index, cell) in content.cells.enumerated() {
                let nextID = windowManager.getNextWindowID()
                let window = windowManager.createWindow(.column, id: nextID)
                let cellContent = cell.source.joined(separator: "\n")
                
                windowManager.updateWindowContent(window.id, content: cellContent)
                
                print("🪟 Created window #\(window.id) for cell \(index)")
            }
        }
        
        print("✅ Finished streaming notebook: \(notebookPath)")
    }
    
    /// Stream data from a Superset dashboard
    /// - Parameters:
    ///   - sliceID: The ID of the chart slice to fetch
    ///   - jwt: Authentication token
    ///   - supersetURL: Base URL of the Superset instance
    ///   - windowManager: The window manager to update with the chart data
    func streamSupersetData(
        sliceID: Int,
        jwt: String,
        supersetURL: String,
        windowManager: WindowTypeManager
    ) async throws {
        print("📡 Starting Superset data stream for slice: \(sliceID)")
        
        // Fetch data from Superset
        let chartPoints = try await fetchSeries(sliceID: sliceID, jwt: jwt, supersetURL: supersetURL)
        
        // Create a chart window with the data
        let nextID = windowManager.getNextWindowID()
        let chartWindow = windowManager.createWindow(.charts, id: nextID)
        
        // Convert chart points to a format suitable for display
        let chartData = chartPoints.map { point in
            "Date: \(point.date), Value: \(point.value)"
        }.joined(separator: "\n")
        
        windowManager.updateWindowContent(chartWindow.id, content: chartData)
        
        print("✅ Streamed Superset data to window #\(chartWindow.id)")
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