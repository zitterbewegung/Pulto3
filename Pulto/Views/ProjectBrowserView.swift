//
//  ProjectBrowserView.swift
//  Pulto
//
//  Created by AI Assistant on 1/4/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct ProjectBrowserView: View {
    @ObservedObject var windowManager: WindowTypeManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    
    @State private var availableProjects: [NotebookFile] = []
    @State private var selectedProject: NotebookFile?
    @State private var isLoading = true
    @State private var showingFilePicker = false
    @State private var showingRestoreDialog = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerView
                
                if isLoading {
                    loadingView
                } else if availableProjects.isEmpty {
                    emptyStateView
                } else {
                    projectsListView
                }
                
                Spacer()
            }
            .padding()
            //.navigationTitle("Open Project")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("Browse Files") {
                            showingFilePicker = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType(filenameExtension: "ipynb") ?? .json],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .sheet(isPresented: $showingRestoreDialog) {
                if let project = selectedProject {
                    NavigationView {
                        EnvironmentRestoreDialog(
                            isPresented: $showingRestoreDialog,
                            windowManager: windowManager
                        ) { restoreResult in
                            handleProjectRestoration(restoreResult)
                        }
                        .onAppear {
                            // Pre-select the chosen project
                            // This would require modifying EnvironmentRestoreDialog to accept a file
                        }
                    }
                }
            }
        }
        .onAppear {
            loadAvailableProjects()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 50))
                .foregroundStyle(.blue)
            
            Text("Open Existing Project")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Choose a saved workspace to continue working")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Scanning for projects...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("No Projects Found")
                    .font(.headline)
                
                Text("No saved workspace files were found in your Documents folder. Create a new project or browse for files from another location.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button("Browse for Files") {
                    showingFilePicker = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Create New Project") {
                    dismiss()
                    openWindow(id: "main")
                }
                .buttonStyle(.bordered)
                
                Button("Refresh") {
                    loadAvailableProjects()
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(40)
    }
    
    private var projectsListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Available Projects")
                    .font(.headline)
                
                Spacer()
                
                Text("\(availableProjects.count) project\(availableProjects.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Refresh") {
                    loadAvailableProjects()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            
            if let error = errorMessage {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.bottom, 8)
            }
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(availableProjects) { project in
                        ProjectRowView(project: project) {
                            openProject(project)
                        }
                    }
                }
            }
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func loadAvailableProjects() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let projects = try await scanForProjects()
                
                await MainActor.run {
                    self.availableProjects = projects.sorted { $0.modifiedDate > $1.modifiedDate }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.availableProjects = []
                    self.isLoading = false
                }
            }
        }
    }
    
    private func scanForProjects() async throws -> [NotebookFile] {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ProjectBrowserError.documentsNotFound
        }
        
        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .nameKey]
        
        guard let enumerator = fileManager.enumerator(
            at: documentsDirectory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return []
        }
        
        var projects: [NotebookFile] = []
        
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "ipynb" else { continue }
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                
                let project = NotebookFile(
                    url: fileURL,
                    name: resourceValues.name ?? fileURL.lastPathComponent,
                    size: Int64(resourceValues.fileSize ?? 0),
                    createdDate: resourceValues.creationDate ?? Date(),
                    modifiedDate: resourceValues.contentModificationDate ?? Date()
                )
                
                projects.append(project)
            } catch {
                print("Error reading file attributes for \(fileURL): \(error)")
            }
        }
        
        return projects
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            openProjectFromURL(url)
            
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    private func openProject(_ project: NotebookFile) {
        openProjectFromURL(project.url)
    }
    
    private func openProjectFromURL(_ url: URL) {
        Task {
            do {
                // Import and restore the environment
                let restoreResult = try await windowManager.importAndRestoreEnvironment(
                    fileURL: url,
                    clearExisting: true
                ) { windowID in
                    // Open each window visually
                    DispatchQueue.main.async {
                        openWindow(value: windowID)
                    }
                }
                
                await MainActor.run {
                    handleProjectRestoration(restoreResult)
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to open project: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func handleProjectRestoration(_ result: EnvironmentRestoreResult) {
        if result.isFullySuccessful {
            // Project opened successfully, open the main workspace
            dismiss()
            openWindow(id: "main")
        } else {
            // Show error or partial success message
            errorMessage = result.summary
        }
    }
}

struct ProjectRowView: View {
    let project: NotebookFile
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 16) {
                        Label(project.formattedSize, systemImage: "doc")
                            .font(.caption)
                        
                        Label(project.formattedModifiedDate, systemImage: "clock")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    
                    Text(project.url.path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Text("Open")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .background(isHovered ? Color(UIColor.systemGray6) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

enum ProjectBrowserError: LocalizedError {
    case documentsNotFound
    case scanningFailed
    
    var errorDescription: String? {
        switch self {
        case .documentsNotFound:
            return "Could not access Documents folder"
        case .scanningFailed:
            return "Failed to scan for project files"
        }
    }
}

// MARK: - Preview
#Preview {
    ProjectBrowserView(windowManager: WindowTypeManager.shared)
}
