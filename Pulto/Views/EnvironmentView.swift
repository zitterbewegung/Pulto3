// File: EnvironmentView.swift

//
//  EnvironmentView.swift
//  Pulto
//
//  Created by Joshua Herman on 6/24/25.
//  Updated 07 • 08 • 25 – replace all .regularMaterial / .thinMaterial / .thickMaterial backgrounds
//  with visionOS-native glassBackgroundEffect(in:) for full translucency.
//

import SwiftUI
import UniformTypeIdentifiers
import Foundation
import RealityKit

// MARK: - Project Tab Enum
enum ProjectTab: String, CaseIterable {
    case create = "Create & Data"
    case active = "Active"
    case recent = "Recent"

    var icon: String {
        switch self {
        case .create: return "plus.circle.fill"
        case .active: return "rectangle.stack.fill"
        case .recent: return "clock.fill"
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    @ObservedObject var viewModel: PultoHomeViewModel
    let onLoginTap:    () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pulto")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple],
                                       startPoint: .leading,
                                       endPoint:   .trailing)
                    )
            }

            Spacer(minLength: 0)

            HStack(spacing: 16) {
                SettingsButton(onTap: onSettingsTap)

                UserProfileButton(userName:   viewModel.userName,
                                  isLoggedIn: viewModel.isUserLoggedIn,
                                  onTap:      onLoginTap)
            }
        }
        .padding(20)
    }
}

// MARK: - User Profile Button
struct UserProfileButton: View {
    let userName:   String
    let isLoggedIn: Bool
    let onTap:      () -> Void
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

                    if isLoggedIn {
                        Text("View Profile")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical,   12)
        }
        .buttonStyle(.plain)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Settings Button
struct SettingsButton: View {
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "gearshape")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.gray)
                .padding(.horizontal, 16)
                .padding(.vertical,   12)
        }
        .buttonStyle(.plain)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - visionOS Window Component
struct VisionOSWindow<Content: View>: View {
    let depth: CGFloat
    let content: Content

    init(depth: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.depth    = depth
        self.content = content()
    }

    var body: some View {
        content
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - Main Environment View
struct EnvironmentView: View {
    // Window management
    @State private var nextWindowID = 1
    @Environment(\.openWindow) private var openWindow
    @StateObject private var windowManager    = WindowTypeManager.shared
    @StateObject private var workspaceManager = WorkspaceManager.shared

    // UI State
    @State private var selectedTab: ProjectTab = .create
    @StateObject private var viewModel         = PultooHomeViewModel()

    // Single sheet management - no more multiple @State variables!
    @StateObject private var sheetManager = SheetManager()

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(viewModel: viewModel,
                       onLoginTap:    { sheetManager.presentSheet(.appleSignIn) },
                       onSettingsTap: { sheetManager.presentSheet(.settings) })
                .padding(.horizontal)
                .padding(.top)

            TabView(selection: $selectedTab) {
                Tab("Create & Data", systemImage: "plus.circle.fill", value: .create) {
                    CreateAndDataTab(
                        sheetManager: sheetManager,
                        createWindow: createStandardWindow,
                        loadWorkspace: loadWorkspace
                    )
                }

                Tab("Active", systemImage: "rectangle.stack.fill", value: .active) {
                    ActiveWindowsTab(
                        windowManager:  windowManager,
                        openWindow:     { openWindow(value: $0) },
                        closeWindow:    { windowManager.removeWindow($0) },
                        closeAllWindows: clearAllWindowsWithConfirmation
                    )
                }

                Tab("Recent", systemImage: "clock.fill", value: .recent) {
                    RecentProjectsTab(
                        workspaceManager: workspaceManager,
                        loadWorkspace: loadWorkspace
                    )
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        }
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(20)
        .task {
            await viewModel.loadInitialData()
            checkFirstLaunch()
        }
        .singleSheetManager(sheetManager) { sheetType, data in
            AnyView(sheetContent(for: sheetType, data: data))
        }
    }

    // MARK: - Single Sheet Content Builder
    @ViewBuilder
    private func sheetContent(for type: SheetType, data: AnyHashable?) -> some View {
        Group {
            switch type {
            case .workspaceDialog:
                WorkspaceDialogWrapper(windowManager: windowManager)
                
            case .templateGallery:
                TemplateView()
                    .frame(minWidth: 800, minHeight: 600)
                    
            case .notebookImport:
                NotebookImportDialogWrapper(windowManager: windowManager)
                
            case .classifierSheet:
                FileClassifierAndRecommenderView()
                    .environmentObject(windowManager)
                    
            case .welcome:
                WelcomeSheetWrapper()
                
            case .settings:
                SettingsSheetWrapper()
                
            case .appleSignIn:
                AppleSignInWrapper()
                    .frame(width: 700, height: 800)
                    
            default:
                EmptyView()
            }
        }
        .environmentObject(sheetManager)
    }

    // MARK: - Sheet Wrapper Views (these handle their own dismissal)
    
    struct WorkspaceDialogWrapper: View {
        let windowManager: WindowTypeManager
        @EnvironmentObject var sheetManager: SheetManager
        
        var body: some View {
            WorkspaceDialog(
                isPresented: Binding(
                    get: { true },
                    set: { _ in sheetManager.dismissSheet() }
                ),
                windowManager: windowManager
            )
        }
    }
    
    struct NotebookImportDialogWrapper: View {
        let windowManager: WindowTypeManager
        @EnvironmentObject var sheetManager: SheetManager
        
        var body: some View {
            NotebookImportDialog(
                isPresented: Binding(
                    get: { true },
                    set: { _ in sheetManager.dismissSheet() }
                ),
                windowManager: windowManager
            )
        }
    }
    
    struct WelcomeSheetWrapper: View {
        @EnvironmentObject var sheetManager: SheetManager
        
        var body: some View {
            WelcomeSheet(
                isPresented: Binding(
                    get: { true },
                    set: { _ in sheetManager.dismissSheet() }
                )
            )
        }
    }
    
    struct AppleSignInWrapper: View {
        @EnvironmentObject var sheetManager: SheetManager
        
        var body: some View {
            AppleSignInView(
                isPresented: Binding(
                    get: { true },
                    set: { _ in sheetManager.dismissSheet() }
                )
            )
        }
    }
    
    struct SettingsSheetWrapper: View {
        @EnvironmentObject var sheetManager: SheetManager
        
        var body: some View {
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
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 0))

                    // Settings Content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Auto-Save
                            SettingsSection("Workspace") {
                                Toggle("Auto-save after every window action", isOn: .constant(true))
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("Automatically saves your workspace configuration after any window is created, moved, or modified")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                            }

                            // Example of navigating to another sheet from within a sheet
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Quick Actions")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                VStack(spacing: 8) {
                                    SheetNavHelper(
                                        "Import Notebook",
                                        icon: "doc.badge.arrow.up",
                                        targetSheet: .notebookImport
                                    )
                                    .buttonStyle(.bordered)
                                    
                                    SheetNavHelper(
                                        "Sign In",
                                        icon: "person.circle",
                                        targetSheet: .appleSignIn
                                    )
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding()
                            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))

                            // Jupyter
                            SettingsSection("Jupyter Server") {
                                HStack {
                                    Text("Default Server URL")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                }

                                TextField("Enter Jupyter server URL", text: .constant("http://localhost:8888"))
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))

                                Text("Default Jupyter notebook server to connect to when importing or creating notebooks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            // General
                            SettingsSection("General") {
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
                        .padding()
                    }

                    Spacer()
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { 
                            sheetManager.dismissSheet()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .frame(width: 700, height: 600)
        }
    }

    // MARK: - Helper Methods

    private func checkFirstLaunch() {
        if !UserDefaults.standard.bool(forKey: "HasLaunchedBefore") {
            sheetManager.presentSheet(.welcome)
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        }
    }

    @MainActor
    private func createStandardWindow(_ type: StandardWindowType) {
        let position = WindowPosition(
            x: 100 + Double(nextWindowID * 20),
            y: 100 + Double(nextWindowID * 20),
            z: 0,
            width:  800,
            height: 600
        )

        let windowType = type.toWindowType()
        _ = windowManager.createWindow(windowType,
                                       id:       nextWindowID,
                                       position: position)
        openWindow(value: nextWindowID)
        windowManager.markWindowAsOpened(nextWindowID)
        nextWindowID += 1
    }

    @MainActor
    private func loadWorkspace(_ workspace: WorkspaceMetadata) {
        Task {
            do {
                try await workspaceManager.loadWorkspace(
                    workspace,
                    into: windowManager,
                    clearExisting: true
                ) { id in
                    openWindow(value: id)
                    windowManager.markWindowAsOpened(id)
                }
                selectedTab = .recent
            } catch { print("Failed to load workspace:", error) }
        }
    }

    @MainActor
    private func clearAllWindowsWithConfirmation() {
        windowManager.getAllWindows().forEach { windowManager.removeWindow($0.id) }
    }

    private var supportedFileTypes: [UTType] {
        [.commaSeparatedText, .tabSeparatedText, .json, .plainText,
         .usdz]

        //[.commaSeparatedText, .tabSeparatedText, .json, .plainText,
        // .image, .usdz, .threeDContent, .data]
    }
}

// MARK: - Create and Data Tab (Unified)
struct CreateAndDataTab: View {
    let sheetManager: SheetManager
    let createWindow: (StandardWindowType) -> Void
    @StateObject private var workspaceManager = WorkspaceManager.shared
    let loadWorkspace: (WorkspaceMetadata) -> Void
    @State private var selectedType: StandardWindowType? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Project Creation Section
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Import or Create New Project")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }

                    // Project Actions - 3 column grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
                    ], spacing: 16) {
                        EnvironmentActionCard(
                            title: "New Project", subtitle: "Create from scratch",
                            icon:  "plus.square.fill", color: .blue) {
                            sheetManager.presentSheet(.workspaceDialog)
                        }
                        EnvironmentActionCard(
                            title: "Templates", subtitle: "Pre-built projects",
                            icon:  "doc.text.fill", color: .green) {
                            sheetManager.presentSheet(.templateGallery)
                        }
                        EnvironmentActionCard(
                            title: "Import File", subtitle: "CSV, JSON, Images, 3D",
                            icon:  "doc.badge.plus", color: .blue) {
                            sheetManager.presentSheet(.classifierSheet)
                        }
                    }
                }

                Divider()

                // Create Visualizations Section
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Create Visualizations from existing files.")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }

                    // Visualization Actions - 3 column grid for data view types
                    LazyVGrid(columns: [
                        GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(StandardWindowType.allCases, id: \.self) { type in
                            WindowTypeCard(
                                type:       type,
                                isSelected: selectedType == type
                            ) {
                                selectedType = type
                                createWindow(type)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    selectedType = nil
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            if workspaceManager.getCustomWorkspaces().contains(where: { $0.totalWindows == 0 }) {
                print("🔧 Detected workspaces with 0 views, refreshing metadata...")
                workspaceManager.refreshWorkspaceMetadata()
            }
        }
    }
}

// MARK: - Recent Projects Tab
struct RecentProjectsTab: View {
    @ObservedObject var workspaceManager: WorkspaceManager
    let loadWorkspace: (WorkspaceMetadata) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Recent Projects Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Recent Projects")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }

                    if workspaceManager.getCustomWorkspaces().isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No projects yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Create your first project from the Create & Data tab")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(workspaceManager.getCustomWorkspaces()) { workspace in
                                WorkspaceRow(workspace: workspace) { loadWorkspace(workspace) }
                            }
                        }
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
    let openWindow:      (Int) -> Void
    let closeWindow:     (Int) -> Void
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
                        // Cleanup Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Window Management")
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Spacer()

                                Button("Clean Up") {
                                    windowManager.cleanupClosedWindows()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(.blue)
                            }

                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.blue)
                                Text("Clean up removes windows that were created but never opened or were closed externally")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        // Statistics Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Window Overview")
                                .font(.title2)
                                .fontWeight(.semibold)

                            HStack(spacing: 16) {
                                StatCard(
                                    title: "Total Windows",
                                    value: "\(windowManager.getAllWindows().count)",
                                    icon:  "rectangle.stack"
                                )

                                StatCard(
                                    title: "Actually Open",
                                    value: "\(windowManager.getAllWindows(onlyOpen: true).count)",
                                    icon:  "checkmark.circle"
                                )

                                StatCard(
                                    title: "Window Types",
                                    value: "\(Set(windowManager.getAllWindows().map(\.windowType)).count)",
                                    icon:  "square.grid.2x2"
                                )
                            }
                        }

                        // Window Distribution
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Window Distribution")
                                .font(.title2)
                                .fontWeight(.semibold)

                            LazyVGrid(columns: [
                                GridItem(.flexible()), GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(WindowType.allCases, id: \.self) { type in
                                    let count = windowManager.getAllWindows()
                                        .filter { $0.windowType == type }.count
                                    let openCount = windowManager.getAllWindows(onlyOpen: true)
                                        .filter { $0.windowType == type }.count
                                    if count > 0 {
                                        HStack {
                                            Image(systemName: type.icon)
                                                .foregroundStyle(.blue)
                                            Text(type.displayName)
                                                .font(.subheadline)
                                            Spacer()
                                            Text("\(openCount)/\(count)")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical,   8)
                                        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 8))
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
                                        window:         window,
                                        isActuallyOpen: windowManager.isWindowActuallyOpen(window.id),
                                        onOpen:         { openWindow(window.id) },
                                        onClose:        { closeWindow(window.id) }
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

                                            if windowManager.isWindowActuallyOpen(window.id) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.green)
                                                    .font(.caption)
                                            } else {
                                                Image(systemName: "questionmark.circle")
                                                    .foregroundStyle(.orange)
                                                    .font(.caption)
                                            }

                                            Text(window.createdAt, style: .relative)
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical,   8)
                                        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 8))
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

// MARK: - Helper Views for Settings
private func SettingsSection<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title)
            .font(.headline)
            .fontWeight(.semibold)

        VStack(alignment: .leading, spacing: 8) { content() }
            .padding()
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Environment Action Card
struct EnvironmentActionCard: View {
    let title:    String
    let subtitle: String
    let icon:     String
    let color:    Color
    let action:   () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .padding()
        }
        .buttonStyle(.plain)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Standard Window Types
enum StandardWindowType: String, CaseIterable {
    case dataFrame  = "Data Table"
    case pointCloud = "Point Cloud"
    case model3d    = "3D Model"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .dataFrame:  return "tablecells"
        case .pointCloud: return "circle.grid.3x3"
        case .model3d:    return "cube"
        }
    }

    var iconColor: Color {
        switch self {
        case .dataFrame:  return .green
        case .pointCloud: return .cyan
        case .model3d:    return .red
        }
    }

    var description: String {
        switch self {
        case .dataFrame:  return "Tabular data viewer"
        case .pointCloud: return "3D point clouds"
        case .model3d:    return "3D model viewer"
        }
    }

    func toWindowType() -> WindowType {
        switch self {
        case .dataFrame:  return .column
        case .pointCloud: return .pointcloud
        case .model3d:    return .model3d
        }
    }
}

// MARK: - Window Type Card
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
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.blue.opacity(0.7), lineWidth: 3)
            }
        }
        .scaleEffect(isSelected ? 0.98 : (isHovered ? 1.02 : 1.0))
        .animation(.easeInOut(duration: 0.1),  value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Workspace Row
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
                        Text("•").foregroundStyle(.tertiary)
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
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 8))
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Window Row
struct WindowRow: View {
    let window: NewWindowID
    let isActuallyOpen: Bool
    let onOpen:  () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack {
            Image(systemName: window.windowType.icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(window.windowType.displayName)
                        .font(.headline)

                    if !isActuallyOpen {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }

                HStack {
                    Label("ID: #\(window.id)", systemImage: "number")
                    Text("•").foregroundStyle(.tertiary)
                    Text("\(Int(window.position.width))×\(Int(window.position.height))")
                        .fontDesign(.monospaced)
                    if !isActuallyOpen {
                        Text("• Not Open").foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onOpen) {
                    Label(isActuallyOpen ? "Focus" : "Open",
                          systemImage: isActuallyOpen ? "arrow.up.forward" : "plus.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(isActuallyOpen ? .blue : .green)

                Button(action: onClose) {
                    Label("Remove", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
            }
        }
        .padding()
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            if !isActuallyOpen {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.orange.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon:  String

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
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - WindowType Icon Helper
extension WindowType {
    var icon: String {
        switch self {
        case .charts:     return "chart.line.uptrend.xyaxis"
        case .spatial:    return "rectangle.3.group"
        case .column:     return "tablecells"
        case .volume:     return "gauge"
        case .pointcloud: return "circle.grid.3x3"
        case .model3d:    return "cube"
        }
    }
}

// MARK: - Welcome Sheet
struct WelcomeSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.largeTitle)
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Welcome to Pulto")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)

                                Text("Your spatial data visualization workspace")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }

                        Text("Get started with spatial computing and data visualization in visionOS")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Getting Started Steps
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Getting Started")
                            .font(.title2)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 16) {
                            WelcomeStep(
                                icon: "1.circle.fill",
                                title: "Create Your First Project",
                                description: "Start with a new project, explore templates, or import Jupyter notebooks from the Workspace tab"
                            )

                            WelcomeStep(
                                icon: "2.circle.fill",
                                title: "Import Your Data",
                                description: "Use the Data tab to import CSV, JSON, images, or 3D models and automatically create visualizations"
                            )

                            WelcomeStep(
                                icon: "3.circle.fill",
                                title: "Build Visualizations",
                                description: "Create charts, data tables, and 3D spatial views from the Create tab to explore your data"
                            )
                        }
                    }

                    Divider()

                    // Pro Tips
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                            Text("Pro Tips")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            ProTip(
                                icon: "person.circle.fill",
                                color: .green,
                                title: "Sign in to sync your projects",
                                description: "Tap the profile button in the header to sign in with Apple ID and keep your work synced across devices"
                            )

                            ProTip(
                                icon: "gearshape.fill",
                                color: .orange,
                                title: "Configure your workspace",
                                description: "Access settings from the gear icon to customize auto-save, Jupyter server connections, and more"
                            )

                            ProTip(
                                icon: "cube.fill",
                                color: .purple,
                                title: "Explore spatial views",
                                description: "Use the 3D spatial editor and point cloud viewer to visualize your data in three dimensions"
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Get Started") { isPresented = false }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 600, height: 700)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Pro Tip
struct ProTip: View {
    let icon:  String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Welcome Step
struct WelcomeStep: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Notebook Import Card
struct NotebookImportCard: View {
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: "doc.badge.arrow.up")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)

                Text("Import Jupyter Notebook")
                    .font(.headline)

                Text("Import workspace from notebook")
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
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.orange.opacity(0.7), lineWidth: 3)
            }
        }
        .scaleEffect(isSelected ? 0.98 : (isHovered ? 1.02 : 1.0))
        .animation(.easeInOut(duration: 0.1), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Sheet Navigation Helper

// MARK: - Previews
struct EnvironmentView_Previews: PreviewProvider {
    static var previews: some View { EnvironmentView() }
}