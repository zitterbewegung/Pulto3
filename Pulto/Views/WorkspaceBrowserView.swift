//
//  WorkspaceBrowserView.swift
//  Pulto
//
//  Workspace browser and management view
//

import SwiftUI

struct WorkspaceBrowserView: View {
    @EnvironmentObject private var workspaceManager: WorkspaceManager
    @State private var showingNewWorkspaceDialog = false
    @State private var showingWorkspaceDetails = false
    @State private var selectedWorkspace: WorkspaceMetadata?
    @State private var searchQuery = ""
    @State private var selectedCategory: WorkspaceCategory? = nil
    
    var body: some View {
        VStack {
            // Header with search and new workspace button
            HStack {
                TextField("Search workspaces...", text: $searchQuery)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Spacer()
                
                newWorkspaceButton
            }
            .padding()
            
            // Category filter
            categoryFilterView
            
            // Workspace list
            workspaceListView
        }
        .navigationTitle("Workspaces")
    }
    
    private var newWorkspaceButton: some View {
        Button(action: { showingNewWorkspaceDialog = true }) {
            Label("New Workspace", systemImage: "plus")
        }
        .sheet(isPresented: $showingNewWorkspaceDialog) {
            WorkspaceDialog(
                isPresented: $showingNewWorkspaceDialog,
                onSave: createNewWorkspace
            )
        }
    }
    
    private var categoryFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryFilterButton(
                    category: nil,
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )
                
                ForEach(WorkspaceCategory.allCases, id: \.self) { category in
                    CategoryFilterButton(
                        category: category,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var workspaceListView: some View {
        List {
            ForEach(filteredWorkspaces) { workspace in
                WorkspaceRowView(workspace: workspace)
                    .onTapGesture {
                        selectedWorkspace = workspace
                        showingWorkspaceDetails = true
                    }
            }
            .onDelete(perform: deleteWorkspaces)
        }
        .sheet(isPresented: $showingWorkspaceDetails) {
            if let workspace = selectedWorkspace {
                WorkspaceDetailsView(workspace: workspace)
            }
        }
    }
    
    private var filteredWorkspaces: [WorkspaceMetadata] {
        let workspaces = workspaceManager.searchWorkspaces(query: searchQuery)
        
        if let category = selectedCategory {
            return workspaces.filter { $0.category == category }
        }
        
        return workspaces
    }
    
    private func createNewWorkspace(
        name: String,
        description: String,
        category: WorkspaceCategory,
        isTemplate: Bool,
        tags: [String]
    ) {
        Task {
            do {
                // Create the workspace using the workspace manager
                // This would typically involve creating a new workspace metadata entry
                var newWorkspace = WorkspaceMetadata(
                    name: name,
                    description: description,
                    category: category,
                    isTemplate: isTemplate,
                    tags: tags
                )
                
                // Add to the workspace manager
                await MainActor.run {
                    workspaceManager.workspaces.append(newWorkspace)
                    workspaceManager.saveWorkspacesMetadata()
                }
                
                print("Created new workspace: \(name)")
            } catch {
                print("Failed to create workspace: \(error)")
            }
        }
    }
    
    private func deleteWorkspaces(offsets: IndexSet) {
        // Implementation for deleting workspaces
    }
}

struct CategoryFilterButton: View {
    let category: WorkspaceCategory?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let category = category {
                    Image(systemName: category.iconName)
                    Text(category.displayName)
                } else {
                    Image(systemName: "square.grid.2x2")
                    Text("All")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct WorkspaceRowView: View {
    let workspace: WorkspaceMetadata
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workspace.name)
                    .font(.headline)
                
                Text(workspace.description.isEmpty ? "No description" : workspace.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Label(workspace.formattedModifiedDate, systemImage: "calendar")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if workspace.isTemplate {
                        Label("Template", systemImage: "doc.on.doc")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    if !workspace.tags.isEmpty {
                        ForEach(workspace.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(6)
                        }
                        
                        if workspace.tags.count > 2 {
                            Text("+\(workspace.tags.count - 2)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Label("\(workspace.totalWindows)", systemImage: "macwindow")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label(workspace.displaySize, systemImage: "externaldrive")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}