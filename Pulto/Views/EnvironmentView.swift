import SwiftUI
import UniformTypeIdentifiers
import Foundation

// MARK: - Project Tab Enum
enum ProjectTab: String, CaseIterable {
    case workspace = "Workspace"
    case create = "Create"
    case data = "Data"
    case active = "Active"

    var icon: String {
        switch self {
        case .workspace: return "folder.fill"
        case .create: return "plus.circle.fill"
        case .data: return "square.and.arrow.down.fill"
        case .active: return "rectangle.stack.fill"
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    @ObservedObject var viewModel: PultoHomeViewModel
    let onLoginTap: () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        VisionOSWindow(depth: 1) {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pulto")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Project Manager")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 16) {
                    SettingsButton(onTap: onSettingsTap)

                    UserProfileButton(
                        userName: viewModel.userName,
                        isLoggedIn: viewModel.isUserLoggedIn,
                        onTap: onLoginTap
                    )
                }
            }
            .padding(20)
        }
    }
}

// MARK: - User Profile Button
struct UserProfileButton: View {
    let userName: String
    let isLoggedIn: Bool
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isLoggedIn ? "person.circle.fill" : "person.circle")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isLoggedIn ? userName : "Sign In")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if isLoggedIn {
                        Text("View Profile")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(isHovered ? 0.3 : 0.1), lineWidth: isHovered ? 2 : 1)
                }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct SettingsButton: View {
    let onTap: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button {
            onTap()
        } label: {
            Image(systemName: "gearshape")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(isHovered ? 0.3 : 0.1), lineWidth: isHovered ? 2 : 1)
                }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - visionOS Window Component
struct VisionOSWindow<Content: View>: View {
    let content: Content
    let depth: CGFloat
    
    init(depth: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.depth = depth
    }
    
    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .scaleEffect(depth > 0 ? 1.0 + (depth * 0.01) : 1.0)
    }
}

// MARK: - Horizontal Tab Bar
struct HorizontalTabBar: View {
    @Binding var selectedTab: ProjectTab
    @State private var hoveredTab: ProjectTab? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ProjectTab.allCases, id: \.self) { tab in
                HorizontalTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    isHovered: hoveredTab == tab
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        hoveredTab = hovering ? tab : nil
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 8)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
}

struct HorizontalTabButton: View {
    let tab: ProjectTab
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.blue)
                        .transition(.scale.combined(with: .opacity))
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.blue.opacity(0.1))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Main Environment View
struct EnvironmentView: View {
    @State private var nextWindowID = 1
    @Environment(\.openWindow) private var openWindow
    @StateObject private var windowManager = WindowTypeManager.shared
    @StateObject private var workspaceManager = WorkspaceManager.shared
    @StateObject private var viewModel = PultoHomeViewModel()
    @State private var selectedTab: ProjectTab = .workspace

    // Sheet States
    @State private var showWorkspaceDialog = false
    @State private var showTemplateGallery = false
    @State private var showNotebookImport = false
    @State private var showFileImporter = false
    @State private var showSettings = false
    @State private var showAppleSignIn = false

    var body: some View {
        HStack(spacing: 0) {
            // Main Content Area
            VStack(spacing: 0) {
                HeaderView(viewModel: viewModel, onLoginTap: {
                    closeAllSheets()
                    showAppleSignIn = true
                }, onSettingsTap: {
                    closeAllSheets()
                    showSettings = true
                })
                .padding(.horizontal)
                .padding(.top)
                
                mainContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Detail View
            detailView
                .frame(width: 300)
        }
        .background(.regularMaterial)
        .task {
            await viewModel.loadInitialData()
        }
        .sheet(isPresented: $showWorkspaceDialog) {
            WorkspaceDialog(
                isPresented: $showWorkspaceDialog,
                windowManager: windowManager
            )
        }
        .sheet(isPresented: $showTemplateGallery) {
            TemplateView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .sheet(isPresented: $showNotebookImport) {
            NotebookImportDialog(
                isPresented: $showNotebookImport,
                windowManager: windowManager
            )
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                VStack {
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Settings panel coming soon...")
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding()
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showSettings = false
                        }
                    }
                }
            }
            .frame(width: 600, height: 500)
        }
        .sheet(isPresented: $showAppleSignIn) {
            AppleSignInView(isPresented: $showAppleSignIn)
                .frame(width: 700, height: 800)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: supportedFileTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Main Content Area
    private var mainContent: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .workspace:
                    WorkspaceTab(
                        showWorkspaceDialog: $showWorkspaceDialog,
                        showTemplateGallery: $showTemplateGallery,
                        showNotebookImport: $showNotebookImport,
                        loadWorkspace: loadWorkspace
                    )
                case .create:
                    CreateTab(createWindow: createStandardWindow)
                case .data:
                    DataTab(
                        showFileImporter: $showFileImporter,
                        createBlankTable: createBlankDataTable
                    )
                case .active:
                    ActiveWindowsTab(
                        windowManager: windowManager,
                        openWindow: { id in openWindow(value: id) },
                        closeWindow: { id in windowManager.removeWindow(id) },
                        closeAllWindows: clearAllWindowsWithConfirmation
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)
            
            HorizontalTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
    }

    // MARK: - Detail View
    private var detailView: some View {
        ActiveWindowsDetailView(windowManager: windowManager)
    }

    // MARK: - Computed Properties
    private var supportedFileTypes: [UTType] {
        [
            .commaSeparatedText,
            .tabSeparatedText,
            .json,
            .plainText,
            .image,
            .usdz,
            .threeDContent,
            .data
        ]
    }

    // MARK: - Helper Methods
    private func closeAllSheets() {
        showWorkspaceDialog = false
        showTemplateGallery = false
        showNotebookImport = false
        showFileImporter = false
        showSettings = false
        showAppleSignIn = false
    }

    private func createStandardWindow(_ type: StandardWindowType) {
        let position = WindowPosition(
            x: 100 + Double(nextWindowID * 20),
            y: 100 + Double(nextWindowID * 20),
            z: 0,
            width: 800,
            height: 600
        )

        let windowType = type.toWindowType()
        _ = windowManager.createWindow(windowType, id: nextWindowID, position: position)
        openWindow(value: nextWindowID)
        windowManager.markWindowAsOpened(nextWindowID)
        nextWindowID += 1
    }

    private func loadWorkspace(_ workspace: WorkspaceMetadata) {
        Task {
            do {
                _ = try await workspaceManager.loadWorkspace(
                    workspace,
                    into: windowManager,
                    clearExisting: true
                ) { windowID in
                    // Ensure window operations happen on main thread
                    Task { @MainActor in
                        openWindow(value: windowID)
                        windowManager.markWindowAsOpened(windowID)
                    }
                }
            } catch {
                await MainActor.run {
                    print("Failed to load workspace: \(error)")
                }
            }
        }
    }

    private func clearAllWindowsWithConfirmation() {
        // In a real app, you'd show a confirmation dialog
        windowManager.getAllWindows().forEach { window in
            windowManager.removeWindow(window.id)
        }
    }

    private func createBlankDataTable() {
        createStandardWindow(.dataFrame)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // Implementation for file import
            print("Importing file: \(url.lastPathComponent)")

        case .failure(let error):
            print("Import failed: \(error)")
        }
    }
}

// MARK: - Workspace Tab
struct WorkspaceTab: View {
    @StateObject private var workspaceManager = WorkspaceManager.shared
    @Binding var showWorkspaceDialog: Bool
    @Binding var showTemplateGallery: Bool
    @Binding var showNotebookImport: Bool
    let loadWorkspace: (WorkspaceMetadata) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Quick Actions Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Get Started")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ActionCard(
                            title: "New Project",
                            subtitle: "Create from scratch",
                            icon: "plus.square.fill",
                            color: .blue,
                            action: {
                                showWorkspaceDialog = true
                            }
                        )
                        
                        ActionCard(
                            title: "Templates",
                            subtitle: "Pre-built projects",
                            icon: "doc.text.fill",
                            color: .red,
                            action: {
                                showTemplateGallery = true
                            }
                        )
                        
                        ActionCard(
                            title: "Import Notebook",
                            subtitle: "Jupyter files",
                            icon: "square.and.arrow.down.fill",
                            color: .green,
                            action: {
                                showNotebookImport = true
                            }
                        )
                    }
                }

                Divider()
                    .padding(.vertical, 8)

                // Recent Projects Section
                if !workspaceManager.getCustomWorkspaces().isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Projects")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Spacer()

                            Button("View All") {
                                showWorkspaceDialog = true
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                        }

                        LazyVStack(spacing: 8) {
                            ForEach(workspaceManager.getCustomWorkspaces().prefix(5)) { workspace in
                                WorkspaceRow(workspace: workspace) {
                                    loadWorkspace(workspace)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Create Tab
struct CreateTab: View {
    let createWindow: (StandardWindowType) -> Void
    @State private var selectedType: StandardWindowType? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Create New View")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Choose a visualization type for your data")
                    .font(.body)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(StandardWindowType.allCases, id: \.self) { type in
                        WindowTypeCard(
                            type: type,
                            isSelected: selectedType == type
                        ) {
                            selectedType = type
                            createWindow(type)

                            // Reset selection after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                selectedType = nil
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Data Tab
struct DataTab: View {
    @Binding var showFileImporter: Bool
    let createBlankTable: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Import Data")
                    .font(.title2)
                    .fontWeight(.semibold)

                // Import Actions
                HStack(spacing: 16) {
                    ActionCard(
                        title: "Import File",
                        subtitle: "CSV, JSON, Images, 3D",
                        icon: "doc.badge.plus",
                        color: .blue,
                        action: {
                            showFileImporter = true
                        }
                    )

                    ActionCard(
                        title: "Blank Table",
                        subtitle: "Start with sample data",
                        icon: "tablecells",
                        color: .yellow,
                        action: {
                            createBlankTable()
                        }
                    )
                }

                Divider()
                    .padding(.vertical, 8)

                // Supported Formats
                VStack(alignment: .leading, spacing: 20) {
                    Text("Supported Formats")
                        .font(.headline)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        FormatCard(
                            title: "Data Files",
                            formats: ["CSV", "TSV", "JSON"],
                            icon: "tablecells",
                            color: .blue
                        )

                        FormatCard(
                            title: "3D Models",
                            formats: ["USDZ", "USD", "OBJ"],
                            icon: "cube",
                            color: .purple
                        )

                        FormatCard(
                            title: "Images",
                            formats: ["PNG", "JPG", "HEIC"],
                            icon: "photo",
                            color: .green
                        )

                        FormatCard(
                            title: "Code Files",
                            formats: ["PY", "IPYNB", "R"],
                            icon: "chevron.left.forwardslash.chevron.right",
                            color: .orange
                        )
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Active Windows Tab
struct ActiveWindowsTab: View {
    let windowManager: WindowTypeManager
    let openWindow: (Int) -> Void
    let closeWindow: (Int) -> Void
    let closeAllWindows: () -> Void

    var body: some View {
        Group {
            if windowManager.getAllWindows().isEmpty {
                ContentUnavailableView(
                    "No Active Views",
                    systemImage: "rectangle.dashed",
                    description: Text("Create a new view to get started")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Statistics Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Window Overview")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            HStack(spacing: 16) {
                                StatCard(
                                    title: "Total Windows",
                                    value: "\(windowManager.getAllWindows().count)",
                                    icon: "rectangle.stack"
                                )
                                
                                StatCard(
                                    title: "Window Types",
                                    value: "\(Set(windowManager.getAllWindows().map(\.windowType)).count)",
                                    icon: "square.grid.2x2"
                                )
                            }
                        }
                        
                        // Window Distribution
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Window Distribution")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(WindowType.allCases, id: \.self) { type in
                                    let count = windowManager.getAllWindows().filter { $0.windowType == type }.count
                                    if count > 0 {
                                        HStack {
                                            Image(systemName: type.icon)
                                                .foregroundStyle(.blue)
                                            Text(type.displayName)
                                                .font(.subheadline)
                                            Spacer()
                                            Text("\(count)")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.tertiarySystemFill))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }

                        // Active Windows List
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Active Views")
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Spacer()

                                Button(action: closeAllWindows) {
                                    Label("Close All", systemImage: "xmark.circle")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(.red)
                            }

                            LazyVStack(spacing: 8) {
                                ForEach(windowManager.getAllWindows(), id: \.id) { window in
                                    WindowRow(
                                        window: window,
                                        onOpen: { openWindow(window.id) },
                                        onClose: { closeWindow(window.id) }
                                    )
                                }
                            }
                        }
                        
                        // Recent Activity
                        if windowManager.getAllWindows().count > 1 {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Recent Activity")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                LazyVStack(spacing: 8) {
                                    ForEach(windowManager.getAllWindows().prefix(5), id: \.id) { window in
                                        HStack {
                                            Image(systemName: window.windowType.icon)
                                                .foregroundStyle(.blue)
                                                .frame(width: 24)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Window #\(window.id)")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                
                                                Text(window.windowType.displayName)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Text(window.createdAt, style: .relative)
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.tertiarySystemFill))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct WindowTypeCard: View {
    let type: StandardWindowType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)

                Text(type.displayName)
                    .font(.headline)

                Text(type.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
    }
}

struct WorkspaceRow: View {
    let workspace: WorkspaceMetadata
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.name)
                        .font(.headline)

                    HStack {
                        Label("\(workspace.totalWindows) views", systemImage: "rectangle.stack")
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(workspace.formattedModifiedDate)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct WindowRow: View {
    let window: NewWindowID
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack {
            Image(systemName: window.windowType.icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(window.windowType.displayName)
                    .font(.headline)

                HStack {
                    Label("ID: #\(window.id)", systemImage: "number")
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text("\(Int(window.position.width))×\(Int(window.position.height))")
                        .fontDesign(.monospaced)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onOpen) {
                    Label("Open", systemImage: "arrow.up.forward")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: onClose) {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct FormatCard: View {
    let title: String
    let formats: [String]
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
            }

            Text(formats.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.quaternarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Active Windows Detail View
struct ActiveWindowsDetailView: View {
    let windowManager: WindowTypeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Active Windows")
                .font(.title)
                .fontWeight(.semibold)
            
            if windowManager.getAllWindows().isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("No active windows")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("Create a new view to see it here")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    StatCard(
                        title: "Total Windows",
                        value: "\(windowManager.getAllWindows().count)",
                        icon: "rectangle.stack"
                    )
                    
                    StatCard(
                        title: "Window Types",
                        value: "\(Set(windowManager.getAllWindows().map(\.windowType)).count)",
                        icon: "square.grid.2x2"
                    )
                    
                    Text("Window Distribution")
                        .font(.headline)
                        .padding(.top)
                    
                    ForEach(WindowType.allCases, id: \.self) { type in
                        let count = windowManager.getAllWindows().filter { $0.windowType == type }.count
                        if count > 0 {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)
                                
                                Text(type.displayName)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Text("\(count)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Text("Recent Activity")
                        .font(.headline)
                    
                    ForEach(windowManager.getAllWindows().prefix(5), id: \.id) { window in
                        HStack {
                            Image(systemName: window.windowType.icon)
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Window #\(window.id)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(window.windowType.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(window.createdAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Standard Window Types
enum StandardWindowType: String, CaseIterable {
    case charts = "Charts"
    case dataFrame = "Data Table"
    case metrics = "Metrics"
    case spatial = "Spatial"
    case pointCloud = "Point Cloud"
    case model3d = "3D Model"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .charts: return "chart.line.uptrend.xyaxis"
        case .dataFrame: return "tablecells"
        case .metrics: return "gauge"
        case .spatial: return "rectangle.3.group"
        case .pointCloud: return "circle.grid.3x3"
        case .model3d: return "cube"
        }
    }

    var description: String {
        switch self {
        case .charts: return "Charts and graphs"
        case .dataFrame: return "Tabular data viewer"
        case .metrics: return "Performance metrics"
        case .spatial: return "Spatial editor"
        case .pointCloud: return "3D point clouds"
        case .model3d: return "3D model viewer"
        }
    }

    func toWindowType() -> WindowType {
        switch self {
        case .charts: return .charts
        case .dataFrame: return .column
        case .metrics: return .volume
        case .spatial: return .spatial
        case .pointCloud: return .pointcloud
        case .model3d: return .model3d
        }
    }
}

// MARK: - Window Type Extension
extension WindowType {
    var icon: String {
        switch self {
        case .charts: return "chart.line.uptrend.xyaxis"
        case .spatial: return "rectangle.3.group"
        case .column: return "tablecells"
        case .volume: return "gauge"
        case .pointcloud: return "circle.grid.3x3"
        case .model3d: return "cube"
        }
    }
}