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

// MARK: - Navigation State
enum NavigationState {
    case home
    case workspace
}

// MARK: - Toolbar Components

struct PultoTitleView: View {
    var body: some View {
        Text("Pulto")
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(colors: [.blue, .purple],
                               startPoint: .leading,
                               endPoint:   .trailing)
            )
    }
}

struct ProjectActionButtons: View {
    let sheetManager: SheetManager
    
    var body: some View {
        HStack(spacing: 8) {
            GlassButton(
                icon: "plus.square.fill",
                text: "New Project"
            ) {
                sheetManager.presentSheet(.workspaceDialog)
            }
            
            GlassButton(
                icon: "doc.text.fill",
                text: "Templates"
            ) {
                sheetManager.presentSheet(.templateGallery)
            }
            
            GlassButton(
                icon: "doc.badge.plus",
                text: "Import File"
            ) {
                sheetManager.presentSheet(.classifierSheet)
            }
        }
    }
}

struct CreateVisualizationsButton: View {
    let createWindow: (StandardWindowType) -> Void
    @State private var showingCreationMenu = false
    @State private var selectedType: StandardWindowType? = nil
    
    var body: some View {
        Menu {
            ForEach(StandardWindowType.allCases, id: \.self) { type in
                Button {
                    selectedType = type
                    createWindow(type)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedType = nil
                    }
                } label: {
                    Label(type.displayName, systemImage: type.icon)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.gray)
                
                Text("Create Visualizations")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .menuStyle(.borderlessButton)
    }
}

struct GlassButton: View {
    let icon: String
    let text: String?
    let action: () -> Void
    @State private var isHovered = false
    
    init(icon: String, text: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.text = text
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.gray)
                
                if let text = text {
                    Text(text)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

struct UserProfileToolbarButton: View {
    let userName: String
    let isLoggedIn: Bool
    let onTap: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: isLoggedIn ? "person.circle.fill" : "person.circle")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isLoggedIn ? userName : "Sign In")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    if isLoggedIn {
                        Text("Profile")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
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
                                title: "Explore volumetric 3D models",
                                description: "Import 3D models and view them in immersive space for the ultimate spatial computing experience"
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
                    Button("Close") { 
                        // Mark welcome as dismissed when closed
                        UserDefaults.standard.set(true, forKey: "WelcomeSheetDismissed")
                        isPresented = false 
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 600, height: 700)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 24))
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

struct SettingsToolbarButton: View {
    let onTap: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: "gearshape")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

struct MainToolbar: View {
    let viewModel: PultoHomeViewModel
    let sheetManager: SheetManager
    let createWindow: (StandardWindowType) -> Void
    let navigationState: NavigationState
    let showNavigationView: Bool
    let onHomeButtonTap: () -> Void
    
    var body: some View {
        HStack {
            // Left side - Home button and project actions
            HStack(spacing: 16) {
                // Home Button (now toggles navigation view)
                HStack(spacing: 8) {
                    Button(action: onHomeButtonTap) {
                        HStack(spacing: 8) {
                            Image(systemName: showNavigationView ? "sidebar.left" : "sidebar.squares.left")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(showNavigationView ? .blue : .gray)
                            
                            /*Text(showNavigationView ? "Hide Sidebar" : "Show Sidebar")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(showNavigationView ? .blue : .primary)*/
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        if showNavigationView {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.blue.opacity(0.7), lineWidth: 2)
                        }
                    }
                    
                    // Divider
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                        .frame(width: 1, height: 24)
                }
                
                PultoTitleView()
                ProjectActionButtons(sheetManager: sheetManager)
            }
            
            Spacer()
            
            // Center - Create Visualizations (only show when in workspace mode)
            if navigationState == .workspace {
                CreateVisualizationsButton(createWindow: createWindow)
            }
            
            Spacer()
            
            // Right side - Settings and profile
            HStack(spacing: 12) {
                SettingsToolbarButton { 
                    sheetManager.presentSheet(.settings) 
                }
                
                UserProfileToolbarButton(
                    userName: viewModel.userName,
                    isLoggedIn: viewModel.isUserLoggedIn
                ) {
                    sheetManager.presentSheet(.appleSignIn)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
    @Environment(\.dismissWindow) private var dismissWindow
    @StateObject private var windowManager    = WindowTypeManager.shared
    @StateObject private var workspaceManager = WorkspaceManager.shared

    // UI State
    @StateObject private var viewModel         = PultoHomeViewModel()

    // Single sheet management - no more multiple @State variables!
    @StateObject private var sheetManager = SheetManager()
    
    // Navigation state
    @State private var navigationState: NavigationState = .workspace
    @State private var showNavigationView = true // New state for navigation view visibility

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            Group {
                if navigationState == .home {
                    // Show the home view
                    PultoHomeContentView(
                        viewModel: viewModel,
                        sheetManager: sheetManager,
                        onOpenWorkspace: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                navigationState = .workspace
                                showNavigationView = true // Show navigation when opening workspace
                            }
                        }
                    )
                } else {
                    // Show the workspace - conditionally with or without NavigationView
                    if showNavigationView {
                        NavigationSplitView {
                            // Sidebar with Recent Projects navigation
                            RecentProjectsSidebar(
                                workspaceManager: workspaceManager,
                                loadWorkspace: loadWorkspace
                            )
                        } detail: {
                            // Default view: Active Windows with toolbar above it
                            VStack(spacing: 0) {
                                // Toolbar above the ActiveWindowsView
                                MainToolbar(
                                    viewModel: viewModel,
                                    sheetManager: sheetManager,
                                    createWindow: createStandardWindow,
                                    navigationState: navigationState,
                                    showNavigationView: showNavigationView,
                                    onHomeButtonTap: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            showNavigationView.toggle()
                                        }
                                    }
                                )
                                
                                ActiveWindowsView(
                                    windowManager: windowManager,
                                    openWindow: { openWindow(value: $0) },
                                    closeWindow: { windowManager.removeWindow($0) },
                                    closeAllWindows: clearAllWindowsWithConfirmation,
                                    sheetManager: sheetManager,
                                    createWindow: createStandardWindow
                                )
                            }
                        }
                    } else {
                        // Show just the main content without sidebar but with toolbar
                        VStack(spacing: 0) {
                            // Toolbar above the ActiveWindowsView
                            MainToolbar(
                                viewModel: viewModel,
                                sheetManager: sheetManager,
                                createWindow: createStandardWindow,
                                navigationState: navigationState,
                                showNavigationView: showNavigationView,
                                onHomeButtonTap: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showNavigationView.toggle()
                                    }
                                }
                            )
                            
                            ActiveWindowsView(
                                windowManager: windowManager,
                                openWindow: { openWindow(value: $0) },
                                closeWindow: { windowManager.removeWindow($0) },
                                closeAllWindows: clearAllWindowsWithConfirmation,
                                sheetManager: sheetManager,
                                createWindow: createStandardWindow
                            )
                        }
                    }
                }
            }
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
        switch type {
        case .workspaceDialog:
            WorkspaceDialogWrapper(windowManager: windowManager)
                .environmentObject(sheetManager)
            
        case .templateGallery:
            TemplateView()
                .frame(minWidth: 800, minHeight: 600)
                .environmentObject(sheetManager)
                
        case .notebookImport:
            NotebookImportDialogWrapper(windowManager: windowManager)
                .environmentObject(sheetManager)
            
        case .classifierSheet:
            FileClassifierAndRecommenderView()
                .environmentObject(windowManager)
                .environmentObject(sheetManager)
                
        case .welcome:
            WelcomeSheetWrapper()
                .environmentObject(sheetManager)
            
        case .settings:
            SettingsSheetWrapper()
                .environmentObject(sheetManager)
            
        case .appleSignIn:
            AppleSignInWrapper()
                .frame(width: 700, height: 800)
                .environmentObject(sheetManager)
                
        case .activeWindows:
            ActiveWindowsSheetWrapper()
                .environmentObject(sheetManager)
                .environmentObject(windowManager)
                
        default:
            EmptyView()
                .environmentObject(sheetManager)
        }
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
                    set: { _ in 
                        // Mark welcome as dismissed when the sheet is closed
                        UserDefaults.standard.set(true, forKey: "WelcomeSheetDismissed")
                        sheetManager.dismissSheet() 
                    }
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
    
    struct ActiveWindowsSheetWrapper: View {
        @EnvironmentObject var sheetManager: SheetManager
        @StateObject private var windowManager = WindowTypeManager.shared
        @Environment(\.openWindow) private var openWindow
        
        var body: some View {
            NavigationStack {
                ActiveWindowsView(
                    windowManager: windowManager,
                    openWindow: { openWindow(value: $0) },
                    closeWindow: { windowManager.removeWindow($0) },
                    closeAllWindows: { 
                        windowManager.getAllWindows().forEach { windowManager.removeWindow($0.id) }
                    },
                    sheetManager: sheetManager,
                    createWindow: { _ in } // Empty since we don't want window creation from the sheet
                )
                .navigationTitle("Active Windows")
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
            .frame(width: 1000, height: 700)
        }
    }
    
    struct SettingsSheetWrapper: View {
        @EnvironmentObject var sheetManager: SheetManager
        @AppStorage("defaultSupersetURL") private var defaultSupersetURL: String = "https://your-superset-instance.com"

        var body: some View {
            NavigationStack {
                VStack(spacing: 20) {
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

                            // Superset
                            SettingsSection("Superset Server") {
                                HStack {
                                    Text("Default Server URL")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                }

                                TextField("Enter Superset server URL", text: $defaultSupersetURL)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))

                                Text("Default Apache Superset server to connect to for dashboard visualizations")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                // Quick preset buttons
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Quick Options:")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)

                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                        ForEach(["http://localhost:8088", "https://your-superset-instance.com"], id: \.self) { url in
                                            Button(url) {
                                                defaultSupersetURL = url
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            .font(.caption)
                                            .fontDesign(.monospaced)
                                        }
                                    }
                                }
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
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        let welcomeSheetDismissed = UserDefaults.standard.bool(forKey: "WelcomeSheetDismissed")
        
        // Only show welcome sheet if app has never launched AND welcome has never been dismissed
        if !hasLaunchedBefore && !welcomeSheetDismissed {
            sheetManager.presentSheet(.welcome)
        }
        
        // Mark that the app has launched
        if !hasLaunchedBefore {
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
                // Load the workspace into the window manager
                try await workspaceManager.loadWorkspace(
                    workspace,
                    into: windowManager,
                    clearExisting: true
                ) { id in
                    openWindow(value: id)
                    windowManager.markWindowAsOpened(id)
                }
                print(" Loaded workspace: \(workspace.name)")
            } catch { 
                print(" Failed to load workspace:", error) 
            }
        }
    }

    @MainActor
    private func clearAllWindowsWithConfirmation() {
        windowManager.getAllWindows().forEach { windowManager.removeWindow($0.id) }
    }

    private var supportedFileTypes: [UTType] {
        [.commaSeparatedText, .tabSeparatedText, .json, .plainText,
         .usdz]
    }
}

// MARK: - Pulto Home Content View
struct PultoHomeContentView: View {
    @ObservedObject var viewModel: PultoHomeViewModel
    let sheetManager: SheetManager
    let onOpenWorkspace: () -> Void
    @Environment(\.openWindow) private var openWindow
    @StateObject private var windowManager = WindowTypeManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar for home view
            HStack {
                // Left side - Pulto title
                HStack(spacing: 16) {
                    PultoTitleView()
                    ProjectActionButtons(sheetManager: sheetManager)
                }
                
                Spacer()
                
                // Right side - Settings and profile
                HStack(spacing: 12) {
                    SettingsToolbarButton { 
                        sheetManager.presentSheet(.settings) 
                    }
                    
                    UserProfileToolbarButton(
                        userName: viewModel.userName,
                        isLoggedIn: viewModel.isUserLoggedIn
                    ) {
                        sheetManager.presentSheet(.appleSignIn)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    SimpleHeaderView(viewModel: viewModel, onLoginTap: {
                        sheetManager.presentSheet(.appleSignIn)
                    }, onSettingsTap: {
                        sheetManager.presentSheet(.settings)
                    })

                    PrimaryActionsGrid(
                        sheetManager: sheetManager,
                        onOpenProject: onOpenWorkspace,
                        createNewProject: createNewProject
                    )

                    if viewModel.isLoadingProjects {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading projects...")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(24)
                        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                    } else if !viewModel.recentProjects.isEmpty {
                        RecentProjectsSection(
                            projects: viewModel.recentProjects,
                            onProjectTap: openRecentProject
                        )
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
            }
        }
    }
    
    private func openRecentProject(_ project: Project) {
        Task {
            // Update the project's last modified date
            await viewModel.updateProjectLastModified(project.id)
            
            // Store the selected project in the window manager
            windowManager.setSelectedProject(project)
            
            // Switch to workspace view
            onOpenWorkspace()
        }
    }
    
    private func createNewProject() {
        Task {
            do {
                // Generate a unique project name with timestamp
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = formatter.string(from: Date())
                let projectName = "New_Project_\(timestamp)"
                
                // Create the project with automatic notebook generation
                if let notebookURL = windowManager.createNewProjectWithNotebook(projectName: projectName) {
                    print(" Created new project with notebook: \(notebookURL.lastPathComponent)")
                    
                    // Create a new project object
                    let newProject = Project(
                        name: projectName.replacingOccurrences(of: "_", with: " "),
                        type: "Data Visualization",
                        icon: "chart.bar.doc.horizontal",
                        color: .blue,
                        lastModified: Date(),
                        visualizations: 3, // Template windows created
                        dataPoints: 0,
                        collaborators: 1,
                        filename: notebookURL.lastPathComponent
                    )
                    
                    // Add to recent projects
                    await viewModel.addRecentProject(newProject)
                    
                    // Set as selected project
                    windowManager.setSelectedProject(newProject)
                    
                    print(" New project '\(newProject.name)' created successfully")
                } else {
                    print(" Failed to create notebook for new project")
                    // Still continue to open the workspace even if notebook creation failed
                }
                
                // Switch to workspace view
                await MainActor.run {
                    onOpenWorkspace()
                }
                
            } catch {
                print(" Error creating new project: \(error)")
                // Still try to open the workspace
                await MainActor.run {
                    onOpenWorkspace()
                }
            }
        }
    }
}

// MARK: - Recent Projects Sidebar
struct RecentProjectsSidebar: View {
    @ObservedObject var workspaceManager: WorkspaceManager
    let loadWorkspace: (WorkspaceMetadata) -> Void
    @State private var selectedWorkspace: WorkspaceMetadata?
    @State private var showingProjectDetail = false

    var body: some View {
        VStack(spacing: 0) {
            if showingProjectDetail, let selectedWorkspace = selectedWorkspace {
                // Show project detail view
                ProjectDetailView(
                    workspace: selectedWorkspace,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingProjectDetail = false
                            self.selectedWorkspace = nil
                        }
                    },
                    onLoad: { loadWorkspace(selectedWorkspace) }
                )
            } else {
                // Show main projects list
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Recent Projects")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding()
                    
                    if workspaceManager.getCustomWorkspaces().isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            
                            Text("No projects yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Text("Create a new project to get started")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(workspaceManager.getCustomWorkspaces()) { workspace in
                                    ProjectSummaryCard(
                                        workspace: workspace,
                                        onSelect: {
                                            selectedWorkspace = workspace
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                showingProjectDetail = true
                                            }
                                        },
                                        onLoad: { loadWorkspace(workspace) }
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Project Summary Card (for main list)
struct ProjectSummaryCard: View {
    let workspace: WorkspaceMetadata
    let onSelect: () -> Void
    let onLoad: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Project Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.name)
                        .font(.headline)
                    
                    if !workspace.description.isEmpty {
                        Text(workspace.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button("Load") {
                        onLoad()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button("Details") {
                        onSelect()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            // Detailed Project Stats
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 20) {
                    Label("\(workspace.totalWindows) views", systemImage: "rectangle.stack")
                        .font(.caption)
                        .foregroundStyle(.primary)
                    
                    Label(workspace.displaySize, systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.primary)
                    
                    Label(workspace.formattedModifiedDate, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 20) {
                    Label(workspace.category.displayName, systemImage: workspace.category.iconName)
                        .font(.caption)
                        .foregroundStyle(workspace.category.color)
                    
                    if !workspace.tags.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(workspace.tags.count) tags")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // Tags Preview (show first 3 tags)
            if !workspace.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(workspace.tags.prefix(4), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                        
                        if workspace.tags.count > 4 {
                            Text("+\(workspace.tags.count - 4)")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.15))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Progress indicator or status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Created")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(workspace.createdDate, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    // Progress bar based on how many windows vs expected
                    //let progress = min(Double(workspace.totalWindows) / 5.0, 1.0) // Assume 5 windows is "complete"

                    /*HStack(spacing: 8) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(height: 4)
                            .scaleEffect(y: 0.5)
                        
                        Text(progressText(for: workspace.totalWindows))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }*/
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovered ? .blue.opacity(0.05) : .clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isHovered ? .blue.opacity(0.3) : .gray.opacity(0.1), lineWidth: 1)
                }
        }
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture {
            onSelect()
        }
    }
    
    private func progressText(for windowCount: Int) -> String {
        switch windowCount {
        case 0: return "Empty"
        case 1...2: return "Getting started"
        case 3...4: return "In progress"
        case 5...8: return "Well developed"
        default: return "Comprehensive"
        }
    }
}

// MARK: - Project Detail View (replaces ProjectDetailCard)
struct ProjectDetailView: View {
    let workspace: WorkspaceMetadata
    let onBack: () -> Void
    let onLoad: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                        Text("Back")
                            .font(.headline)
                    }
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("Load Project") {
                    onLoad()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding()
            
            // Project content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Project Header
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(workspace.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            if !workspace.description.isEmpty {
                                Text(workspace.description)
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Project Stats
                        HStack(spacing: 20) {
                            Label("\(workspace.totalWindows) views", systemImage: "rectangle.stack")
                            Label(workspace.displaySize, systemImage: "doc")
                            Label(workspace.formattedModifiedDate, systemImage: "clock")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16))
                    
                    // Project Tags
                    if !workspace.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tags")
                                .font(.headline)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                ForEach(workspace.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding()
                        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16))
                    }
                    
                    // Category Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: workspace.category.iconName)
                                .foregroundStyle(workspace.category.color)
                            Text(workspace.category.displayName)
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                    .padding()
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
        }
    }
}

// MARK: - Enhanced Active Windows View (with creation tools)
struct WelcomeContentView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header with dismiss button
            HStack {
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
                    }

                    Text("Get started with spatial computing and data visualization in visionOS")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
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
                        title: "Explore volumetric 3D models",
                        description: "Import 3D models and view them in immersive space for the ultimate spatial computing experience"
                    )
                }
            }
            
            // Action buttons
            HStack {
                Spacer()
                
                Button("Get Started") {
                    // Mark welcome as dismissed when user clicks Get Started
                    UserDefaults.standard.set(true, forKey: "WelcomeSheetDismissed")
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.top)
        }
        .padding(24)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Enhanced Active Windows View (with creation tools)
struct ActiveWindowsView: View {
    let windowManager: WindowTypeManager
    let openWindow: (Int) -> Void
    let closeWindow: (Int) -> Void
    let closeAllWindows: () -> Void
    let sheetManager: SheetManager
    let createWindow: (StandardWindowType) -> Void
    @State private var selectedType: StandardWindowType? = nil
    @State private var showWelcomeContent = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Show welcome content if no windows and user hasn't dismissed it
                if windowManager.getAllWindows().isEmpty && showWelcomeContent {
                    WelcomeContentView(onDismiss: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showWelcomeContent = false
                        }
                    })
                } else if windowManager.getAllWindows().isEmpty {
                    // Show simple empty state after welcome is dismissed
                    ContentUnavailableView(
                        "No Active Views",
                        systemImage: "rectangle.dashed",
                        description: Text("Create a new view using the options above")
                    )
                } else {
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
                                
                                Button(action: closeAllWindows) {
                                    Label("Close All", systemImage: "xmark.circle")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(.red)
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
                                    icon: "rectangle.stack"
                                )

                                StatCard(
                                    title: "Actually Open",
                                    value: "\(windowManager.getAllWindows(onlyOpen: true).count)",
                                    icon: "checkmark.circle"
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
                                        .padding(.vertical, 8)
                                        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }

                        // Active Windows List
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Active Views")
                                .font(.title2)
                                .fontWeight(.semibold)

                            LazyVStack(spacing: 8) {
                                ForEach(windowManager.getAllWindows(), id: \.id) { window in
                                    WindowRow(
                                        window: window,
                                        isActuallyOpen: windowManager.isWindowActuallyOpen(window.id),
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
                                        .padding(.vertical, 8)
                                        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .onChange(of: windowManager.getAllWindows().count) { count in
            // Reset welcome content when all windows are cleared
            if count == 0 {
                showWelcomeContent = true
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

// MARK: - Environment Action 
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
    case iotDashboard = "IoT Dashboard"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .dataFrame:  return "tablecells"
        case .pointCloud: return "circle.grid.3x3"
        case .model3d:    return "cube"
        case .iotDashboard: return "sensor.tag.radiowaves.forward"
        }
    }

    var iconColor: Color {
        switch self {
        case .dataFrame:  return .green
        case .pointCloud: return .cyan
        case .model3d:    return .red
        case .iotDashboard: return .orange
        }
    }

    var description: String {
        switch self {
        case .dataFrame:  return "Tabular data viewer"
        case .pointCloud: return "3D point clouds"
        case .model3d:    return "3D model viewer"
        case .iotDashboard: return "Real-time IoT dashboard"
        }
    }

    func toWindowType() -> WindowType {
        switch self {
        case .dataFrame:  return .column
        case .pointCloud: return .pointcloud
        case .model3d:    return .model3d
        case .iotDashboard: return .volume  // Maps to volume type for IoT metrics
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


// MARK: - Active Windows Sheet Wrapper
struct ActiveWindowsSheetWrapper: View {
    @EnvironmentObject var sheetManager: SheetManager
    @StateObject private var windowManager = WindowTypeManager.shared
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        NavigationStack {
            ActiveWindowsView(
                windowManager: windowManager,
                openWindow: { openWindow(value: $0) },
                closeWindow: { windowManager.removeWindow($0) },
                closeAllWindows: { 
                    windowManager.getAllWindows().forEach { windowManager.removeWindow($0.id) }
                },
                sheetManager: sheetManager,
                createWindow: { _ in } // Empty since we don't want window creation from the sheet
            )
            .navigationTitle("Active Windows")
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
        .frame(width: 1000, height: 700)
    }
}

// MARK: - Previews
struct EnvironmentView_Previews: PreviewProvider {
    static var previews: some View { EnvironmentView() }
}
