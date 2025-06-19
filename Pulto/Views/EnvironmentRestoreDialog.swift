//
//  EnvironmentRestoreDialog.swift
//  Pulto
//
//  Created by Joshua Herman on 6/18/25.
//  Copyright © 2025 Apple. All rights reserved.
//


//
//  EnvironmentRestoreDialog.swift
//  Create this as a new file in your project
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct EnvironmentRestoreDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject var windowManager: WindowTypeManager
    @Environment(\.openWindow) private var openWindow
    
    let onEnvironmentRestored: (EnvironmentRestoreResult) -> Void
    
    @State private var availableNotebooks: [NotebookFile] = []
    @State private var selectedNotebook: NotebookFile?
    @State private var isLoadingFiles = true
    @State private var notebookAnalysis: NotebookAnalysis?
    @State private var isAnalyzing = false
    @State private var analysisError: String?
    @State private var clearExistingWindows = true
    @State private var environmentRestoreResult: EnvironmentRestoreResult?
    @State private var isRestoring = false
    @State private var showingFilePicker = false
    @State private var fileLoadError: String?
    @State private var restoreProgress: Double = 0.0
    @State private var currentlyOpeningWindow: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerView
                
                if isLoadingFiles {
                    loadingView
                } else if let notebook = selectedNotebook {
                    selectedNotebookView
                    
                    if let analysis = notebookAnalysis {
                        environmentAnalysisView(analysis)
                        environmentRestoreOptionsView
                        environmentRestoreActionsView
                    } else if let error = analysisError {
                        errorView(error)
                    } else if isAnalyzing {
                        ProgressView("Analyzing workspace...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if !availableNotebooks.isEmpty {
                    availableNotebooksView
                } else {
                    emptyStateView
                }
                
                if isRestoring {
                    environmentRestoreProgressView
                }
                
                if let result = environmentRestoreResult {
                    environmentRestoreResultView(result)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Restore Environment")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Browse Files") {
                        showingFilePicker = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.init(filenameExtension: "ipynb") ?? .json],
            allowsMultipleSelection: false
        ) { result in
            handleExternalFileSelection(result)
        }
        .onAppear {
            loadAvailableNotebooks()
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "cube.box.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)
            
            Text("Restore 3D Environment")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Load a saved workspace with windows positioned in 3D space")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Scanning for saved workspaces...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var availableNotebooksView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Available Workspaces", systemImage: "cube.box")
                    .font(.headline)
                
                Spacer()
                
                Button("Refresh") {
                    loadAvailableNotebooks()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if let error = fileLoadError {
                Text("Error loading files: \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.bottom, 8)
            }
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(availableNotebooks) { notebook in
                        notebookRowView(notebook)
                    }
                }
            }
            .frame(maxHeight: 400)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private func notebookRowView(_ notebook: NotebookFile) -> some View {
        Button(action: {
            selectNotebook(notebook)
        }) {
            HStack(spacing: 12) {
                Image(systemName: "cube.box")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(notebook.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        Label(notebook.formattedSize, systemImage: "doc")
                            .font(.caption)
                        
                        Label(notebook.formattedModifiedDate, systemImage: "clock")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    private var selectedNotebookView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Selected Workspace", systemImage: "cube.box")
                    .font(.headline)
                
                Spacer()
                
                Button("Change") {
                    selectedNotebook = nil
                    notebookAnalysis = nil
                    analysisError = nil
                    environmentRestoreResult = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if let notebook = selectedNotebook {
                VStack(alignment: .leading, spacing: 8) {
                    Text(notebook.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Size")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(notebook.formattedSize)
                                .font(.body)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Modified")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(notebook.formattedModifiedDate)
                                .font(.body)
                        }
                        
                        Spacer()
                    }
                    
                    Text(notebook.url.path)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                .padding()
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.box.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("No Saved Workspaces Found")
                    .font(.headline)
                
                Text("No .ipynb workspace files were found in your Documents folder. Save a workspace first or browse for files from another location.")
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
                
                Button("Refresh") {
                    loadAvailableNotebooks()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
    }
    
    private func environmentAnalysisView(_ analysis: NotebookAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Workspace Analysis", systemImage: "chart.bar.doc.horizontal")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Total Cells:")
                    Spacer()
                    Text("\(analysis.totalCells)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("3D Windows:")
                    Spacer()
                    Text("\(analysis.windowCells)")
                        .fontWeight(.medium)
                        .foregroundStyle(analysis.windowCells > 0 ? .green : .orange)
                }
                
                if !analysis.windowTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Window Types:")
                            .fontWeight(.medium)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(analysis.windowTypes, id: \.self) { type in
                                    HStack(spacing: 4) {
                                        Image(systemName: iconForWindowType(type))
                                            .font(.caption2)
                                        Text(type)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.blue.opacity(0.1))
                                    .clipShape(Capsule())
                                    .font(.caption)
                                }
                            }
                        }
                    }
                }
                
                if let metadata = analysis.metadata {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Workspace Info:")
                            .fontWeight(.medium)
                        
                        Text("Saved: \(formatDate(metadata.export_date))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("Original Windows: \(metadata.total_windows)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var environmentRestoreOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Environment Options", systemImage: "gearshape.2")
                .font(.headline)
            
            Toggle("Clear current windows first", isOn: $clearExistingWindows)
                .toggleStyle(SwitchToggleStyle())
            
            HStack {
                Image(systemName: clearExistingWindows ? "sparkles" : "plus.circle")
                    .foregroundStyle(clearExistingWindows ? .blue : .secondary)
                
                Text(clearExistingWindows ? 
                     "This will create a clean environment with only the restored windows" :
                     "Restored windows will be added to your current environment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 20)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var environmentRestoreActionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Restore to 3D Environment", systemImage: "cube.box")
                .font(.headline)
            
            Text("This will restore \(notebookAnalysis?.windowCells ?? 0) windows to your 3D environment with their saved positions and content.")
                .font(.body)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    selectedNotebook = nil
                    notebookAnalysis = nil
                    environmentRestoreResult = nil
                }
                .buttonStyle(.bordered)
                .disabled(isRestoring)
                
                Spacer()
                
                Button("Restore Environment") {
                    performEnvironmentRestore()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRestoring || notebookAnalysis?.windowCells == 0)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var environmentRestoreProgressView: some View {
        VStack(spacing: 12) {
            Label("Restoring 3D Environment", systemImage: "cube.box.fill")
                .font(.headline)
            
            ProgressView(value: restoreProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(y: 2)
            
            Text(currentlyOpeningWindow)
                .font(.body)
                .foregroundStyle(.secondary)
                .animation(.easeInOut(duration: 0.3), value: currentlyOpeningWindow)
            
            Text("\(Int(restoreProgress * 100))% Complete")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func environmentRestoreResultView(_ result: EnvironmentRestoreResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.isFullySuccessful ? "checkmark.circle.fill" : 
                      result.totalRestored > 0 ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result.isFullySuccessful ? .green : 
                                   result.totalRestored > 0 ? .orange : .red)
                
                Text("Environment Restore Result")
                    .font(.headline)
            }
            
            Text(result.summary)
                .font(.body)
            
            if !result.openedWindows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Opened Windows:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(result.openedWindows, id: \.id) { window in
                                HStack {
                                    Image(systemName: iconForWindowType(window.windowType.rawValue))
                                        .foregroundStyle(.green)
                                        .frame(width: 20)
                                    
                                    Text("\(window.windowType.displayName) #\(window.id)")
                                        .font(.caption)
                                    
                                    Spacer()
                                    
                                    Text("(\(Int(window.position.x)), \(Int(window.position.y)), \(Int(window.position.z)))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary.opacity(0.5))
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.green.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }
            
            if !result.failedWindows.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Failed to Open:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(result.failedWindows, id: \.id) { window in
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.red)
                            Text("\(window.windowType.displayName) #\(window.id)")
                                .font(.caption)
                        }
                    }
                }
            }
            
            HStack(spacing: 12) {
                if result.isFullySuccessful {
                    Button("Explore Environment") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Restore Another") {
                        selectedNotebook = nil
                        environmentRestoreResult = nil
                        notebookAnalysis = nil
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Done") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    
                    if result.totalRestored > 0 {
                        Button("Try Again") {
                            environmentRestoreResult = nil
                            performEnvironmentRestore()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(result.isFullySuccessful ? .green.opacity(0.1) : 
                   result.totalRestored > 0 ? .orange.opacity(0.1) : .red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            
            Text("Analysis Failed")
                .font(.headline)
            
            Text(error)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                analyzeSelectedNotebook()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Helper Methods
    
    private func loadAvailableNotebooks() {
        isLoadingFiles = true
        fileLoadError = nil
        
        Task {
            do {
                let notebooks = try await scanForNotebookFiles()
                
                await MainActor.run {
                    self.availableNotebooks = notebooks.sorted { $0.modifiedDate > $1.modifiedDate }
                    self.isLoadingFiles = false
                }
            } catch {
                await MainActor.run {
                    self.fileLoadError = error.localizedDescription
                    self.availableNotebooks = []
                    self.isLoadingFiles = false
                }
            }
        }
    }
    
    private func scanForNotebookFiles() async throws -> [NotebookFile] {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ImportError.fileReadError
        }
        
        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .nameKey]
        
        guard let enumerator = fileManager.enumerator(
            at: documentsDirectory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
            errorHandler: nil
        ) else {
            return []
        }
        
        var notebooks: [NotebookFile] = []
        
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "ipynb" else { continue }
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                
                let notebook = NotebookFile(
                    url: fileURL,
                    name: resourceValues.name ?? fileURL.lastPathComponent,
                    size: Int64(resourceValues.fileSize ?? 0),
                    createdDate: resourceValues.creationDate ?? Date(),
                    modifiedDate: resourceValues.contentModificationDate ?? Date()
                )
                
                notebooks.append(notebook)
            } catch {
                print("Error reading file attributes for \(fileURL): \(error)")
            }
        }
        
        return notebooks
    }
    
    private func selectNotebook(_ notebook: NotebookFile) {
        selectedNotebook = notebook
        analyzeSelectedNotebook()
    }
    
    private func analyzeSelectedNotebook() {
        guard let notebook = selectedNotebook else { return }
        
        isAnalyzing = true
        analysisError = nil
        
        let manager = windowManager
        
        Task {
            do {
                let analysis = try manager.analyzeGenericNotebook(fileURL: notebook.url)
                
                await MainActor.run {
                    self.notebookAnalysis = analysis
                    self.isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    self.analysisError = error.localizedDescription
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    private func handleExternalFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let resourceValues = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .nameKey])
                
                let notebook = NotebookFile(
                    url: url,
                    name: resourceValues.name ?? url.lastPathComponent,
                    size: Int64(resourceValues.fileSize ?? 0),
                    createdDate: resourceValues.creationDate ?? Date(),
                    modifiedDate: resourceValues.contentModificationDate ?? Date()
                )
                
                selectNotebook(notebook)
            } catch {
                analysisError = "Failed to read file information: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            analysisError = error.localizedDescription
        }
    }
    
    private func performEnvironmentRestore() {
        guard let notebook = selectedNotebook else { return }
        
        isRestoring = true
        restoreProgress = 0.0
        currentlyOpeningWindow = "Preparing environment..."
        
        // Capture values outside the Task to avoid concurrency issues
        let manager = windowManager
        let shouldClearWindows = clearExistingWindows
        let notebookURL = notebook.url
        
        Task {
            do {
                await MainActor.run {
                    restoreProgress = 0.1
                    currentlyOpeningWindow = "Loading workspace data..."
                }
                
                // Perform the restoration
                let result = try await performRestoration(
                    manager: manager,
                    fileURL: notebookURL,
                    clearExisting: shouldClearWindows
                )
                
                await MainActor.run {
                    self.environmentRestoreResult = result
                    self.isRestoring = false
                    self.restoreProgress = 1.0
                    self.currentlyOpeningWindow = "Environment restored!"
                    
                    // Notify parent about successful restoration
                    onEnvironmentRestored(result)
                }
                
            } catch {
                await MainActor.run {
                    self.environmentRestoreResult = EnvironmentRestoreResult(
                        importResult: ImportResult(
                            restoredWindows: [],
                            errors: [ImportError.fileReadError],
                            originalMetadata: nil,
                            idMapping: [:]
                        ),
                        openedWindows: [],
                        failedWindows: []
                    )
                    self.isRestoring = false
                    self.restoreProgress = 1.0
                    self.currentlyOpeningWindow = "Restoration failed"
                }
            }
        }
    }
    
    // Helper method to perform the restoration outside the main class
    private func performRestoration(
        manager: WindowTypeManager,
        fileURL: URL,
        clearExisting: Bool
    ) async throws -> EnvironmentRestoreResult {
        
        // Step 1: Clear existing windows if requested
        if clearExisting {
            await MainActor.run {
                manager.clearAllWindows()
            }
        }
        
        // Step 2: Import the data
        let importResult = try manager.importFromGenericNotebook(fileURL: fileURL)
        
        // Step 3: Open windows on main thread with progress updates
        var openedWindows: [NewWindowID] = []
        let totalWindows = importResult.restoredWindows.count
        
        for (index, window) in importResult.restoredWindows.enumerated() {
            await MainActor.run {
                // Update progress
                let progress = 0.1 + (0.9 * Double(index) / Double(totalWindows))
                self.restoreProgress = progress
                self.currentlyOpeningWindow = "Opening \(window.windowType.displayName) #\(window.id)..."
                
                // Open the window
                openWindow(value: window.id)
                openedWindows.append(window)
            }
            
            // Small delay between windows
            if index < totalWindows - 1 {
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            }
        }
        
        return EnvironmentRestoreResult(
            importResult: importResult,
            openedWindows: openedWindows,
            failedWindows: []
        )
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    private func iconForWindowType(_ type: String) -> String {
        switch type.lowercased() {
        case "charts":
            return "chart.line.uptrend.xyaxis"
        case "spatial":
            return "cube"
        case "column":
            return "tablecells"
        default:
            return "square.stack.3d"
        }
    }
}
