//
//  WorkspaceDialog.swift
//  Pulto
//
//  Comprehensive workspace creation and management dialog
//

import SwiftUI

struct WorkspaceDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject var windowManager: WindowTypeManager
    @StateObject private var workspaceManager = WorkspaceManager.shared
    @Environment(\.openWindow) private var openWindow
    
    @State private var selectedTab: WorkspaceTab = .create
    @State private var workspaceName = ""
    @State private var workspaceDescription = ""
    @State private var selectedCategory: WorkspaceCategory = .custom
    @State private var workspaceTags: [String] = []
    @State private var newTag = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isCreating = false
    @State private var searchQuery = ""
    @State private var selectedWorkspace: WorkspaceMetadata?
    @State private var showingDeleteConfirmation = false
    @State private var workspaceToDelete: WorkspaceMetadata?
    
    enum WorkspaceTab: String, CaseIterable {
        case create = "Create"
        case manage = "Manage" 
        case templates = "Templates"
        
        var iconName: String {
            switch self {
            case .create: return "plus.circle"
            case .manage: return "folder"
            case .templates: return "doc.on.doc"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Tab", selection: $selectedTab) {
                    ForEach(WorkspaceTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.iconName)
                            .tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                Divider()
                
                // Tab content
                TabView(selection: $selectedTab) {
                    createWorkspaceView
                        .tag(WorkspaceTab.create)
                    
                    manageWorkspacesView
                        .tag(WorkspaceTab.manage)
                    
                    templatesView
                        .tag(WorkspaceTab.templates)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Workspace Manager")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                if selectedTab == .create {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Create") {
                            createWorkspace()
                        }
                        .disabled(workspaceName.isEmpty || isCreating)
                    }
                }
            }
        }
        .alert("Workspace Manager", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(
            "Delete Workspace",
            isPresented: $showingDeleteConfirmation,
            presenting: workspaceToDelete
        ) { workspace in
            Button("Delete", role: .destructive) {
                deleteWorkspace(workspace)
            }
            Button("Cancel", role: .cancel) { }
        } message: { workspace in
            Text("Are you sure you want to delete '\(workspace.name)'? This action cannot be undone.")
        }
    }
    
    // MARK: - Create Workspace View
    
    private var createWorkspaceView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView
                currentWorkspacePreview
                workspaceDetailsForm
                
                if isCreating {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Creating workspace...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .padding()
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cube.box.fill")
                    .font(.title)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create New Workspace")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Save your current 3D window configuration")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var currentWorkspacePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Current Workspace", systemImage: "eye")
                .font(.headline)
            
            let windows = windowManager.getAllWindows()
            
            if windows.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    Text("No windows currently open")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("Create some windows first before saving a workspace")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(windows.count) window\(windows.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("Ready to save")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.3))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    
                    let windowTypes = Array(Set(windows.map { $0.windowType }))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(windowTypes, id: \.self) { type in
                            let count = windows.filter { $0.windowType == type }.count
                            HStack(spacing: 4) {
                                Image(systemName: iconForWindowType(type))
                                    .font(.caption)
                                Text("\(count) \(type.rawValue)")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.25))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var workspaceDetailsForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Workspace Details", systemImage: "info.circle")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter workspace name", text: $workspaceName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Optional description", text: $workspaceDescription, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Category")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(WorkspaceCategory.allCases.filter { $0 != .template }, id: \.self) { category in
                            Label(category.displayName, systemImage: category.iconName)
                                .tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tags")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        TextField("Add tag", text: $newTag)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                addTag()
                            }
                        
                        Button("Add") {
                            addTag()
                        }
                        .disabled(newTag.isEmpty)
                    }
                    
                    if !workspaceTags.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                            ForEach(workspaceTags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text(tag)
                                        .font(.caption)
                                    
                                    Button {
                                        workspaceTags.removeAll { $0 == tag }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption2)
                                    }
                                    .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedCategory.color.opacity(0.3))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Manage Workspaces View
    
    private var manageWorkspacesView: some View {
        VStack(spacing: 0) {
            // Search bar
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
            .background(Color.primary.opacity(0.08))
            
            // Workspace list
            let workspaces = searchQuery.isEmpty ? 
                workspaceManager.getCustomWorkspaces() : 
                workspaceManager.searchWorkspaces(query: searchQuery)
            
            if workspaces.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    
                    Text(searchQuery.isEmpty ? "No Custom Workspaces" : "No Results")
                        .font(.headline)
                    
                    Text(searchQuery.isEmpty ? 
                         "Create your first workspace to get started" :
                         "Try a different search term")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(workspaces) { workspace in
                        WorkspaceRowView(
                            workspace: workspace,
                            onLoad: { loadWorkspace(workspace) },
                            onDuplicate: { duplicateWorkspace(workspace) },
                            onDelete: { confirmDelete(workspace) }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    // MARK: - Templates View
    
    private var templatesView: some View {
        VStack(spacing: 0) {
            let templates = workspaceManager.getTemplates()
            
            if templates.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    
                    Text("No Templates Available")
                        .font(.headline)
                    
                    Text("Templates will appear here when available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(templates) { template in
                        TemplateRowView(
                            template: template,
                            onLoad: { loadWorkspace(template) }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !workspaceTags.contains(trimmedTag) {
            workspaceTags.append(trimmedTag)
            newTag = ""
        }
    }
    
    private func createWorkspace() {
        guard !workspaceName.isEmpty else { return }
        
        isCreating = true
        
        Task {
            do {
                let workspace = try await workspaceManager.createNewWorkspace(
                    name: workspaceName,
                    description: workspaceDescription,
                    category: selectedCategory,
                    tags: workspaceTags,
                    windowManager: windowManager
                )
                
                await MainActor.run {
                    isCreating = false
                    alertMessage = "Workspace '\(workspace.name)' created successfully!"
                    showingAlert = true
                    
                    // Reset form
                    workspaceName = ""
                    workspaceDescription = ""
                    workspaceTags = []
                    selectedCategory = .custom
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    alertMessage = "Failed to create workspace: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func loadWorkspace(_ workspace: WorkspaceMetadata) {
        Task {
            do {
                let result = try await workspaceManager.loadWorkspace(
                    workspace,
                    into: windowManager,
                    clearExisting: true
                ) { windowID in
                    openWindow(value: windowID)
                }
                
                await MainActor.run {
                    isPresented = false
                    // Could show success message or result summary
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to load workspace: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func duplicateWorkspace(_ workspace: WorkspaceMetadata) {
        do {
            let duplicatedWorkspace = try workspaceManager.duplicateWorkspace(workspace)
            alertMessage = "Workspace duplicated as '\(duplicatedWorkspace.name)'"
            showingAlert = true
        } catch {
            alertMessage = "Failed to duplicate workspace: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func confirmDelete(_ workspace: WorkspaceMetadata) {
        workspaceToDelete = workspace
        showingDeleteConfirmation = true
    }
    
    private func deleteWorkspace(_ workspace: WorkspaceMetadata) {
        do {
            try workspaceManager.deleteWorkspace(workspace)
            alertMessage = "Workspace '\(workspace.name)' deleted"
            showingAlert = true
        } catch {
            alertMessage = "Failed to delete workspace: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func iconForWindowType(_ type: WindowType) -> String {
        switch type {
        case .charts: return "chart.line.uptrend.xyaxis"
        case .spatial: return "cube"
        case .column: return "tablecells"
        case .volume: return "gauge"
        case .model3d: return "cube.transparent"
        case .pointcloud: return "dot.scope"
        }
    }
}

// MARK: - Supporting Views

struct WorkspaceRowView: View {
    let workspace: WorkspaceMetadata
    let onLoad: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.name)
                        .font(.headline)
                    
                    if !workspace.description.isEmpty {
                        Text(workspace.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: workspace.category.iconName)
                            .font(.caption)
                        Text(workspace.category.displayName)
                            .font(.caption)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(workspace.category.color.opacity(0.3))
                    .clipShape(Capsule())
                    
                    Text(workspace.formattedModifiedDate)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            HStack {
                HStack(spacing: 8) {
                    Label("\(workspace.totalWindows)", systemImage: "rectangle.3.group")
                        .font(.caption)
                    
                    Label(workspace.displaySize, systemImage: "doc")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button("Load") {
                        onLoad()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Menu {
                        Button("Duplicate") {
                            onDuplicate()
                        }
                        
                        Divider()
                        
                        Button("Delete", role: .destructive) {
                            onDelete()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            if !workspace.tags.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 4) {
                    ForEach(workspace.tags.prefix(4), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TemplateRowView: View {
    let template: WorkspaceMetadata
    let onLoad: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)
                
                Text(template.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label("\(template.totalWindows) windows", systemImage: "rectangle.3.group")
                        .font(.caption)
                    
                    if !template.windowTypes.isEmpty {
                        Text(template.windowTypes.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button("Load") {
                onLoad()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
    }
}

#Preview {
    WorkspaceDialog(
        isPresented: .constant(true),
        windowManager: WindowTypeManager.shared
    )
}