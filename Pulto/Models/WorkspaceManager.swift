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
    
    /// Ensures the Teapot IoT Demo project exists with all required components
    func ensureTeapotDemoProjectExists() async {
        // Check if demo already exists
        if workspaces.contains(where: { $0.name == "Teapot IoT Demo" }) {
            print("🍵 Teapot demo project already exists")
            return
        }
        
        print("🍵 Creating Teapot IoT Demo project...")
        
        // Create the demo project workspace metadata
        var demoWorkspace = WorkspaceMetadata(
            name: "Teapot IoT Demo",
            description: "Interactive 3D teapot visualization with point cloud data and IoT metrics",
            category: .demo,
            isTemplate: false,
            totalWindows: 4,
            windowTypes: ["column", "model3d", "pointcloud", "volume"],
            tags: ["demo", "teapot", "iot", "3d", "pointcloud"]
        )
        
        // Set a fixed ID for consistency in tests
        demoWorkspace.id = UUID(uuidString: "12345678-1234-1234-1234-123456789012") ?? UUID()
        
        // Use shared instance instead of creating new instance
        let windowManager = WindowTypeManager.shared
        
        // Window 1: Data table (column)
        let dataTableWindowID = 1001
        let dataTableWindow = windowManager.createWindow(.column, id: dataTableWindowID, position: WindowPosition(x: -200, y: 100, z: 0, width: 500, height: 400))
        windowManager.updateWindowTemplate(dataTableWindowID, template: .pandas)
        windowManager.updateWindowContent(dataTableWindowID, content: """
        # Teapot IoT Sensor Data
        # Simulated temperature and pressure readings
        
        import pandas as pd
        import numpy as np
        
        # Generate sample IoT data for teapot
        timestamps = pd.date_range('2024-01-01', periods=100, freq='1min')
        temperature = 95 + 5 * np.sin(np.linspace(0, 4*np.pi, 100)) + np.random.normal(0, 1, 100)
        pressure = 14.7 + 0.5 * np.cos(np.linspace(0, 2*np.pi, 100)) + np.random.normal(0, 0.1, 100)
        water_level = np.clip(80 + 20 * np.sin(np.linspace(0, 2*np.pi, 100)) + np.random.normal(0, 5, 100), 0, 100)
        
        df = pd.DataFrame({
            'timestamp': timestamps,
            'temperature_f': temperature,
            'pressure_psi': pressure,
            'water_level_percent': water_level
        })
        
        print("Teapot IoT Data Sample:")
        print(df.head(10))
        """)
        windowManager.addWindowTag(dataTableWindowID, tag: "iot")
        windowManager.addWindowTag(dataTableWindowID, tag: "data")
        
        // Window 2: 3D Model (model3d) with cup_saucer_set.usdz
        let modelWindowID = 1002
        let modelWindow = windowManager.createWindow(.model3d, id: modelWindowID, position: WindowPosition(x: 200, y: 150, z: 50, width: 600, height: 500))
        windowManager.updateWindowTemplate(modelWindowID, template: .custom)
        windowManager.updateWindowContent(modelWindowID, content: """
        # Teapot 3D Model Visualization
        # Using cup_saucer_set.usdz asset
        
        import matplotlib.pyplot as plt
        import numpy as np
        from mpl_toolkits.mplot3d import Axes3D
        import plotly.graph_objects as go
        
        # Model information
        model_name = "Teapot & Saucer Set"
        asset_file = "cup_saucer_set.usdz"
        vertices = 15420
        faces = 15200
        materials = 3
        
        print(f"Loaded 3D model: {model_name}")
        print(f"Asset file: {asset_file}")
        print(f"Vertices: {vertices}, Faces: {faces}, Materials: {materials}")
        
        # Placeholder for 3D visualization
        # In the actual app, this would load the USDZ file
        """)
        windowManager.addWindowTag(modelWindowID, tag: "3d")
        windowManager.addWindowTag(modelWindowID, tag: "model")
        windowManager.addWindowTag(modelWindowID, tag: "usdz")
        
        // Window 3: Point Cloud (pointcloud) - teapot shape
        let pointCloudWindowID = 1003
        let pointCloudWindow = windowManager.createWindow(.pointcloud, id: pointCloudWindowID, position: WindowPosition(x: -150, y: -100, z: 100, width: 550, height: 450))
        windowManager.updateWindowTemplate(pointCloudWindowID, template: .custom)
        
        // Create teapot point cloud data
        let teapotPoints = PointCloudDemo2.generateTeapotPointCloud(points: 1500)
        var pointCloudData = PointCloudData(
            title: "Teapot Point Cloud",
            xAxisLabel: "Width (cm)",
            yAxisLabel: "Depth (cm)", 
            zAxisLabel: "Height (cm)",
            demoType: "teapot",
            parameters: ["points": Double(teapotPoints.count)]
        )
        
        // Convert to PointCloudData.PointData format
        pointCloudData.points = teapotPoints.map { point in
            PointCloudData.PointData(
                x: point.x,
                y: point.y,
                z: point.z,
                intensity: point.intensity,
                color: point.color
            )
        }
        pointCloudData.totalPoints = pointCloudData.points.count
        
        windowManager.updateWindowPointCloud(pointCloudWindowID, pointCloud: pointCloudData)
        windowManager.updateWindowContent(pointCloudWindowID, content: pointCloudData.toPythonCode())
        windowManager.addWindowTag(pointCloudWindowID, tag: "pointcloud")
        windowManager.addWindowTag(pointCloudWindowID, tag: "teapot")
        windowManager.addWindowTag(pointCloudWindowID, tag: "3d")
        
        // Window 4: Volume Metrics (volume)
        let volumeWindowID = 1004
        let volumeWindow = windowManager.createWindow(.volume, id: volumeWindowID, position: WindowPosition(x: 250, y: -150, z: -50, width: 450, height: 350))
        windowManager.updateWindowTemplate(volumeWindowID, template: .numpy)
        windowManager.updateWindowContent(volumeWindowID, content: """
        # Teapot Performance Metrics
        # Real-time IoT monitoring data
        
        import numpy as np
        
        # Simulated performance metrics
        metrics = {
            "brew_temperature": 98.6,  // Fahrenheit
            "brew_time_seconds": 240,
            "water_level_percent": 85.3,
            "pressure_psi": 14.7,
            "power_consumption_watts": 1200,
            "efficiency_ratio": 0.92,
            "uptime_hours": 1250.5
        }
        
        # Convert to NumPy array for processing
        metrics_array = np.array(list(metrics.values()))
        metrics_keys = list(metrics.keys())
        
        print("Teapot Performance Metrics:")
        for key, value in metrics.items():
            print(f"  {key}: {value}")
            
        print(f"\\nMetrics Array Shape: {metrics_array.shape}")
        """)
        windowManager.addWindowTag(volumeWindowID, tag: "metrics")
        windowManager.addWindowTag(volumeWindowID, tag: "iot")
        windowManager.addWindowTag(volumeWindowID, tag: "performance")
        
        // Save the workspace file
        do {
            let fileURL = try await saveWorkspaceToFile(metadata: demoWorkspace, windowManager: windowManager)
            demoWorkspace.fileURL = fileURL
            workspaces.append(demoWorkspace)
            saveWorkspacesMetadata()
            print("✅ Teapot IoT Demo project created successfully")
        } catch {
            print("❌ Failed to create Teapot IoT Demo project: \(error)")
        }
    }
    
    // MARK: - Teapot Geometry Generation
    
    /// Generate vertices for a teapot model (simplified)
    private func generateTeapotVertices() -> [SIMD3<Float>] {
        var vertices: [SIMD3<Float>] = []
        
        // Create a simple teapot-like shape with body, spout, and handle
        let bodyRadius: Float = 5.0
        let bodyHeight: Float = 8.0
        let segments = 32
        
        // Body (cylindrical with tapered top)
        for i in 0..<segments {
            let angle = Float(i) * 2 * .pi / Float(segments)
            let x = bodyRadius * cos(angle)
            let z = bodyRadius * sin(angle)
            
            // Bottom ring
            vertices.append(SIMD3(x, -bodyHeight/2, z))
            
            // Middle ring
            vertices.append(SIMD3(x * 0.9, 0, z * 0.9))
            
            // Top ring (narrower)
            vertices.append(SIMD3(x * 0.6, bodyHeight/2, z * 0.6))
        }
        
        // Spout (cylinder)
        let spoutLength: Float = 3.0
        let spoutRadius: Float = 1.0
        for i in 0..<16 {
            let angle = Float(i) * 2 * .pi / 16
            let x = bodyRadius + spoutLength + spoutRadius * cos(angle)
            let y: Float = 1.0
            let z = spoutRadius * sin(angle)
            vertices.append(SIMD3(x, y, z))
        }
        
        // Handle (torus shape)
        let handleRadius: Float = 2.0
        let handleTubeRadius: Float = 0.5
        for i in 0..<16 {
            let majorAngle = Float(i) * 2 * .pi / 16
            let centerX = -(bodyRadius + handleRadius)
            let centerY: Float = 0.0
            let centerZ: Float = 0.0
            
            for j in 0..<8 {
                let minorAngle = Float(j) * 2 * .pi / 8
                let x = centerX + (handleRadius + handleTubeRadius * cos(minorAngle)) * cos(majorAngle)
                let y = centerY + handleTubeRadius * sin(minorAngle)
                let z = centerZ + (handleRadius + handleTubeRadius * cos(minorAngle)) * sin(majorAngle)
                vertices.append(SIMD3(Float(x), Float(y), Float(z)))
            }
        }
        
        return vertices
    }
    
    /// Generate faces for the teapot model (simplified)
    private func generateTeapotFaces() -> [Model3DData.Face3D] {
        var faces: [Model3DData.Face3D] = []
        
        // Simple face generation for demonstration
        // In a real implementation, this would properly connect vertices
        for i in stride(from: 0, to: 100, by: 3) {
            faces.append(Model3DData.Face3D(vertices: [i, i+1, i+2], materialIndex: 0))
        }
        
        return faces
    }
    
    /// Generate point cloud data for a teapot shape
    private func generateTeapotPointCloud() -> [PointCloudData.PointData] {
        var points: [PointCloudData.PointData] = []
        
        // Teapot body (using parametric equations)
        let uSteps = 50
        let vSteps = 50
        let scale: Float = 10.0
        
        for i in 0..<uSteps {
            for j in 0..<vSteps {
                let u = Float(i) * .pi / Float(uSteps)
                let v = Float(j) * 2 * .pi / Float(vSteps)
                
                // Teapot parametric equations (simplified)
                let x = scale * (2 * cos(v) * sin(u))
                let y = scale * (2 * sin(v) * sin(u))
                let z = scale * (2 * cos(u))
                
                // Add some noise for a more natural look
                let noiseX = Float.random(in: -0.2...0.2)
                let noiseY = Float.random(in: -0.2...0.2)
                let noiseZ = Float.random(in: -0.2...0.2)
                
                // Calculate intensity based on position
                let intensity = Double((z + scale) / (2 * scale))
                
                points.append(PointCloudData.PointData(
                    x: Double(x + noiseX),
                    y: Double(y + noiseY),
                    z: Double(z + noiseZ),
                    intensity: intensity,
                    color: nil
                ))
            }
        }
        
        // Add spout points
        for i in 0..<20 {
            let angle = Float(i) * 2 * .pi / 20
            let length = Float.random(in: 0...3)
            let radius = Float.random(in: 0...1)
            
            let x = scale * (2 + length)
            let y = scale * (radius * cos(angle))
            let z = scale * (radius * sin(angle))
            
            let intensity = Double((length / 3))
            
            points.append(PointCloudData.PointData(
                x: Double(x),
                y: Double(y),
                z: Double(z),
                intensity: intensity,
                color: nil
            ))
        }
        
        // Add handle points
        for i in 0..<30 {
            let angle = Float(i) * 2 * .pi / 30
            let majorRadius: Float = 7.0
            let minorRadius: Float = 1.0
            
            let x = scale * (-(majorRadius + minorRadius * cos(angle)))
            let y = scale * (minorRadius * sin(angle))
            let z: Double = 0.0
            
            let intensity = 0.7
            
            points.append(PointCloudData.PointData(
                x: Double(x),
                y: Double(y),
                z: z,
                intensity: intensity,
                color: nil
            ))
        }
        
        return points
    }
}

// Add this method to WindowTypeManager to support volume data updates
extension WindowTypeManager {
    func updateWindowVolumeData(_ id: Int, volumeData: VolumeData) {
        // Use the public method instead of accessing private windows directly
        if var window = self.getWindow(for: id) {
            window.state.volumeData = volumeData
            window.state.lastModified = Date()
            
            // Auto-set template to numpy if not already set and this is a volume window
            if window.windowType == .volume && window.state.exportTemplate == .plain {
                window.state.exportTemplate = .numpy
            }
            
            // Update the window state using the public method
            self.updateWindowState(id, state: window.state)
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