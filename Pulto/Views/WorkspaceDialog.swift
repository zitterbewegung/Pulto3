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
    
    @State private var workspaceName = ""
    @State private var selectedCategory: WorkspaceCategory = .custom
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Direct to create workspace view (no tabs)
                createWorkspaceView
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Create") {
                        createWorkspace()
                    }
                    .disabled(workspaceName.isEmpty || isCreating)
                }
            }
        }
        .alert("New Project", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
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
                        Text("Creating project...")
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
                    Text("Create New Project")
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
            Label("Project Details", systemImage: "info.circle")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter project name", text: $workspaceName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
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
            }
            .padding()
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Helper Methods
    
    private func createWorkspace() {
        guard !workspaceName.isEmpty else { return }
        
        isCreating = true
        
        Task {
            do {
                let workspace = try await workspaceManager.createNewWorkspace(
                    name: workspaceName,
                    description: "", // Empty description
                    category: selectedCategory,
                    tags: [], // Empty tags
                    windowManager: windowManager
                )
                
                await MainActor.run {
                    isCreating = false
                    alertMessage = "Project '\(workspace.name)' created successfully!"
                    showingAlert = true
                    
                    // Reset form
                    workspaceName = ""
                    selectedCategory = .custom
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    alertMessage = "Failed to create project: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func iconForWindowType(_ type: WindowType) -> String {
        switch type {
        case .charts: return "chart.line.uptrend.xyaxis"
        case .spatial: return "cube"
        case .column: return "tablecells"
        case .volume: return "gauge"
        case .pointcloud: return "dot.scope"
        case .model3d: return "cube.transparent"
        case .iotDashboard: return "sensor.tag.radiowaves.forward"
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

#Preview {
    WorkspaceDialog(
        isPresented: .constant(true),
        windowManager: WindowTypeManager.shared
    )
}