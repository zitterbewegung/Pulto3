//
//  EnvironmentRestoreDialog.swift
//  Pulto
//
//  Created by Joshua Herman on 6/18/25.
//  Copyright 2025 Apple. All rights reserved.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct EnvironmentRestoreDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject var windowManager: WindowTypeManager
    @StateObject private var workspaceManager = WorkspaceManager.shared
    @Environment(\.openWindow) private var openWindow

    let onEnvironmentRestored: (EnvironmentRestoreResult) -> Void

    @State private var selectedTab: RestoreTab = .workspaces
    @State private var availableNotebooks: [NotebookFile] = []
    @State private var selectedNotebook: NotebookFile?
    @State private var selectedWorkspace: WorkspaceMetadata?
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
    @State private var searchQuery = ""

    enum RestoreTab: String, CaseIterable {
        case workspaces = "My Workspaces"
        case templates = "Templates"
        case files = "Browse Files"

        var iconName: String {
            switch self {
            case .workspaces: return "folder"
            case .templates: return "doc.on.doc"
            case .files: return "folder.badge.questionmark"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView

                Picker("Source", selection: $selectedTab) {
                    ForEach(RestoreTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.iconName)
                            .tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                Divider()

                TabView(selection: $selectedTab) {
                    workspacesTabView
                        .tag(RestoreTab.workspaces)


                    templatesTabView
                        .tag(RestoreTab.templates)

                    filesTabView
                        .tag(RestoreTab.files)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                if isRestoring {
                    environmentRestoreProgressView
                }

                if let result = environmentRestoreResult {
                    environmentRestoreResultView(result)
                }

                Spacer()
            }
            .navigationTitle("Restore Environment")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    restoreButton
                }
            }
        }
        .onAppear {
            loadAvailableNotebooks()
        }
    }

    private var restoreButton: some View {
        Group {
            switch selectedTab {
            case .workspaces:
                if let workspace = selectedWorkspace {
                    Button("Restore") {
                        restoreWorkspace(workspace)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRestoring)
                }
            case .templates:
                if let workspace = selectedWorkspace {
                    Button("Load Template") {
                        restoreWorkspace(workspace)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRestoring)
                }
            case .files:
                Button("Browse Files") {
                    showingFilePicker = true
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var workspacesTabView: some View {
        VStack(spacing: 16) {
            workspaceSearchBar

            let workspaces = searchQuery.isEmpty ?
                workspaceManager.getCustomWorkspaces() :
                workspaceManager.searchWorkspaces(query: searchQuery)

            if workspaces.isEmpty {
                emptyWorkspacesView
            } else {
                workspacesList(workspaces)
            }

            if let workspace = selectedWorkspace, !workspace.isTemplate {
                workspaceDetailsView(workspace)
            }
        }
        .padding()
    }

    private var templatesTabView: some View {
        VStack(spacing: 16) {
            let templates = workspaceManager.getTemplates()

            if templates.isEmpty {
                emptyTemplatesView
            } else {
                templatesList(templates)
            }

            if let template = selectedWorkspace, template.isTemplate {
                workspaceDetailsView(template)
            }
        }
        .padding()
    }

    private var filesTabView: some View {
        VStack(spacing: 20) {
            Text("Browse for Workspace Files")
                .font(.headline)

            Text("Select .ipynb files from other locations or external sources")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Choose File") {
                showingFilePicker = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let notebook = selectedNotebook {
                selectedNotebookView

                if let analysis = notebookAnalysis {
                    environmentAnalysisView(analysis)
                    environmentRestoreOptionsView
                } else if let error = analysisError {
                    errorView(error)
                } else if isAnalyzing {
                    ProgressView("Analyzing workspace...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.init(filenameExtension: "ipynb") ?? .json],
            allowsMultipleSelection: false
        ) { result in
            handleExternalFileSelection(result)
        }
    }

    private var workspaceSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search workspaces", text: $searchQuery)
                .textFieldStyle(PlainTextFieldStyle())

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func workspacesList(_ workspaces: [WorkspaceMetadata]) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(workspaces) { workspace in
                    WorkspaceRestoreRowView(
                        workspace: workspace,
                        isSelected: selectedWorkspace?.id == workspace.id,
                        onSelect: { selectedWorkspace = workspace }
                    )
                }
            }
        }
        .frame(maxHeight: 300)
    }

    private func templatesList(_ templates: [WorkspaceMetadata]) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(templates) { template in
                    WorkspaceRestoreRowView(
                        workspace: template,
                        isSelected: selectedWorkspace?.id == template.id,
                        onSelect: { selectedWorkspace = template }
                    )
                }
            }
        }
        .frame(maxHeight: 300)
    }

    private func workspaceDetailsView(_ workspace: WorkspaceMetadata) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(workspace.isTemplate ? "Template Details" : "Workspace Details",
                      systemImage: workspace.category.iconName)
                    .font(.headline)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: workspace.category.iconName)
                        .font(.caption)
                    Text(workspace.category.displayName)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(workspace.category.color.opacity(0.2))
                .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(workspace.name)
                    .font(.title3)
                    .fontWeight(.semibold)

                if !workspace.description.isEmpty {
                    Text(workspace.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Windows")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(workspace.totalWindows)")
                            .font(.body)
                            .fontWeight(.medium)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Size")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(workspace.displaySize)
                            .font(.body)
                            .fontWeight(.medium)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Modified")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(workspace.formattedModifiedDate)
                            .font(.body)
                            .fontWeight(.medium)
                    }

                    Spacer()
                }

                if !workspace.windowTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Window Types:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(workspace.windowTypes, id: \.self) { type in
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

                if !workspace.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(workspace.tags, id: \.self) { tag in
                                    Text(tag)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(workspace.category.color.opacity(0.1))
                                        .clipShape(Capsule())
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }

            environmentRestoreOptionsView
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyWorkspacesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Saved Workspaces")
                    .font(.headline)

                Text("Create and save workspaces to access them here")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var emptyTemplatesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Templates Available")
                    .font(.headline)

                Text("Templates will appear here when available")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

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

    private var selectedNotebookView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Selected File", systemImage: "doc")
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
                        resetState()
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
                            if let workspace = selectedWorkspace {
                                restoreWorkspace(workspace)
                            }
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

    private func resetState() {
        selectedWorkspace = nil
        selectedNotebook = nil
        notebookAnalysis = nil
        environmentRestoreResult = nil
        analysisError = nil
    }

    private func restoreWorkspace(_ workspace: WorkspaceMetadata) {
        isRestoring = true
        restoreProgress = 0.0
        currentlyOpeningWindow = "Preparing environment..."

        Task {
            do {
                let result = try await workspaceManager.loadWorkspace(
                    workspace,
                    into: windowManager,
                    clearExisting: clearExistingWindows
                ) { windowID in
                    openWindow(value: windowID)
                }

                await MainActor.run {
                    self.environmentRestoreResult = result
                    self.isRestoring = false
                    self.restoreProgress = 1.0
                    self.currentlyOpeningWindow = "Environment restored!"

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

                selectedNotebook = notebook
                analyzeSelectedNotebook()
            } catch {
                analysisError = "Failed to read file information: \(error.localizedDescription)"
            }

        case .failure(let error):
            analysisError = error.localizedDescription
        }
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
        case "volume":
            return "gauge"
        case "pointcloud":
            return "dot.scope"
        case "model3d":
            return "cube.transparent"
        default:
            return "square.stack.3d"
        }
    }
}

struct WorkspaceRestoreRowView: View {
    let workspace: WorkspaceMetadata
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: workspace.category.iconName)
                    .font(.title2)
                    .foregroundStyle(workspace.category.color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !workspace.description.isEmpty {
                        Text(workspace.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 12) {
                        Label("\(workspace.totalWindows) windows", systemImage: "rectangle.3.group")
                            .font(.caption)

                        Label(workspace.formattedModifiedDate, systemImage: "clock")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Text(workspace.displaySize)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
