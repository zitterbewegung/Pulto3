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
        VisionOSWindow(depth: 1, isDark: true) {
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
                    .foregroundStyle(.gray)

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
                .fill(isHovered ? .gray.opacity(0.2) : .gray.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(isHovered ? 0.2 : 0.1), lineWidth: 1)
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
                .foregroundStyle(.gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isHovered ? .gray.opacity(0.2) : .gray.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(isHovered ? 0.2 : 0.1), lineWidth: 1)
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
    let isDark: Bool

    init(depth: CGFloat = 0, isDark: Bool = false, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.depth = depth
        self.isDark = isDark
    }

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isDark ? .thinMaterial : .regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(.white.opacity(isDark ? 0.05 : 0.1), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(isDark ? 0.3 : 0.1), radius: 16, x: 0, y: 8)
                    .shadow(color: .black.opacity(isDark ? 0.15 : 0.05), radius: 4, x: 0, y: 2)
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
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.05), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
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
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isSelected ? .gray.opacity(0.8) : (isHovered ? .gray.opacity(0.2) : .clear))
                .animation(.easeInOut(duration: 0.2), value: isSelected)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
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
        ZStack {
            // Main content with dark glass effect
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

                    var mainContent = mainContentView
                    mainContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.black.opacity(0.8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.1), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
                    .shadow(color: .blue.opacity(0.1), radius: 50, x: 0, y: 20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .padding(20)
        }
        .preferredColorScheme(.dark)
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
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "gear")
                                .font(.title)
                                .foregroundStyle(.gray)
                            
                            Text("Pulto Settings")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                        }
                        
                        Text("Configure your Pulto experience")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    
                    // Settings Content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Auto-Save Settings
                            SettingsSection("Workspace") {
                                VStack(alignment: .leading, spacing: 12) {
                                    Toggle("Auto-save after every window action", isOn: .constant(true))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("Automatically saves your workspace configuration after any window is created, moved, or modified")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 4)
                                }
                            }
                            
                            // Jupyter Settings
                            SettingsSection("Jupyter Server") {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Default Server URL")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                    }
                                    
                                    TextField("Enter Jupyter server URL", text: .constant("http://localhost:8888"))
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.system(.body, design: .monospaced))
                                    
                                    Text("Default Jupyter notebook server to connect to when importing or creating notebooks")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            // General Settings
                            SettingsSection("General") {
                                VStack(alignment: .leading, spacing: 12) {
                                    Toggle("Enable Notifications", isOn: .constant(true))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    HStack {
                                        Text("Maximum Recent Projects")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        Text("10")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showSettings = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .frame(width: 700, height: 600)
            .background(Color.black.opacity(0.05))
            .preferredColorScheme(.dark)
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
    private var mainContentView: some View {
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
    @MainActor
    private func closeAllSheets() {
        showWorkspaceDialog = false
        showTemplateGallery = false
        showNotebookImport = false
        showFileImporter = false
        showSettings = false
        showAppleSignIn = false
    }

    @MainActor
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

    @MainActor
    private func loadWorkspace(_ workspace: WorkspaceMetadata) {
        Task {
            do {
                _ = try await workspaceManager.loadWorkspace(
                    workspace,
                    into: windowManager,
                    clearExisting: true
                ) { windowID in
                    openWindow(value: windowID)
                    windowManager.markWindowAsOpened(windowID)
                }
                // Switch to create tab after loading workspace
                selectedTab = .create
            } catch {
                print("Failed to load workspace: \(error)")
            }
        }
    }

    @MainActor
    private func clearAllWindowsWithConfirmation() {
        windowManager.getAllWindows().forEach { window in
            windowManager.removeWindow(window.id)
        }
    }

    @MainActor
    private func createBlankDataTable() {
        createStandardWindow(.dataFrame)
    }

    @MainActor
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
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
                        EnvironmentActionCard(
                            title: "New Project",
                            subtitle: "Create from scratch",
                            icon: "plus.square.fill",
                            color: .blue,
                            action: {
                                showWorkspaceDialog = true
                            }
                        )

                        EnvironmentActionCard(
                            title: "Templates",
                            subtitle: "Pre-built projects",
                            icon: "doc.text.fill",
                            color: .red,
                            action: {
                                showTemplateGallery = true
                            }
                        )

                        EnvironmentActionCard(
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
                    EnvironmentActionCard(
                        title: "Import File",
                        subtitle: "CSV, JSON, Images, 3D",
                        icon: "doc.badge.plus",
                        color: .blue,
                        action: {
                            showFileImporter = true
                        }
                    )

                    EnvironmentActionCard(
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
                                        .background(Color.white.opacity(0.05))
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
                                        .background(Color.white.opacity(0.05))
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

// MARK: - Helper Views for Settings
private func SettingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title)
            .font(.headline)
            .fontWeight(.semibold)
        
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EnvironmentActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(color)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isHovered ? .gray.opacity(0.2) : .gray.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(isHovered ? 0.2 : 0.1), lineWidth: 1)
                }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
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

    var iconColor: Color {
        switch self {
        case .charts: return .blue
        case .dataFrame: return .green
        case .metrics: return .orange
        case .spatial: return .purple
        case .pointCloud: return .cyan
        case .model3d: return .red
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

struct WindowTypeCard: View {
    let type: StandardWindowType
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(type.iconColor)

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
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? .gray.opacity(0.3) : (isHovered ? .gray.opacity(0.2) : .gray.opacity(0.1)))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? .gray : .white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                }
        }
        .scaleEffect(isSelected ? 0.98 : (isHovered ? 1.02 : 1.0))
        .animation(.easeInOut(duration: 0.1), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct WorkspaceRow: View {
    let workspace: WorkspaceMetadata
    let action: () -> Void
    @State private var isHovered = false

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
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? .gray.opacity(0.2) : .gray.opacity(0.1))
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
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
        .background(Color.white.opacity(0.05))
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
        .background(Color.white.opacity(0.05))
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
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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