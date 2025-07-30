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

// MARK: - Window Actions
enum WindowAction {
    case open
    case close
    case focus
    case duplicate
}

// MARK: - Standard Window Types (moved up for forward declarations)
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

// MARK: - Window info row component
struct WindowInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
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
            Button(action: {
                sheetManager.presentSheet(.workspaceDialog)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.square.fill")
                    Text("New")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Button(action: {
                sheetManager.presentSheet(.templateGallery)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.fill")
                    Text("Templates")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Button(action: {
                sheetManager.presentSheet(.classifierSheet)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.badge.plus")
                    Text("Import")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Enhanced Active Windows View
struct EnhancedActiveWindowsView: View {
    let windowManager: WindowTypeManager
    let openWindow: (Int) -> Void
    let closeWindow: (Int) -> Void
    let closeAllWindows: () -> Void
    let sheetManager: SheetManager
    let createWindow: (StandardWindowType) -> Void
    @Binding var selectedWindow: NewWindowID?
    @State private var showWelcomeContent = true
    
    // Add parameters for toolbar
    let viewModel: PultoHomeViewModel
    let navigationState: NavigationState
    let showNavigationView: Bool
    let showInspector: Bool
    let onHomeButtonTap: () -> Void
    let onInspectorToggle: () -> Void
    
    // Add Jupyter server settings
    @AppStorage("defaultJupyterURL") private var defaultJupyterURL: String = "http://localhost:8888"
    @State private var jupyterServerStatus: ServerStatus = .unknown
    @State private var isCheckingJupyterServer = false
    
    enum ServerStatus {
        case online
        case offline
        case unknown
        case checking
        
        var color: Color {
            switch self {
            case .online: return .green
            case .offline: return .red
            case .unknown: return .orange
            case .checking: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .online: return "checkmark.circle.fill"
            case .offline: return "xmark.circle.fill"
            case .unknown: return "questionmark.circle.fill"
            case .checking: return "arrow.clockwise.circle.fill"
            }
        }
        
        var description: String {
            switch self {
            case .online: return "Online"
            case .offline: return "Offline"
            case .unknown: return "Unknown"
            case .checking: return "Checking..."
            }
        }
    }

    var body: some View {
        NavigationStack {
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
                            // Quick Actions Section
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Quick Actions")
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
                                    Text("Select a window to view details in the inspector")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Divider()

                            // Active Windows List with Selection
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Active Views")
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                LazyVStack(spacing: 8) {
                                    ForEach(windowManager.getAllWindows(), id: \.id) { window in
                                        SelectableWindowRow(
                                            window: window,
                                            isSelected: selectedWindow?.id == window.id,
                                            isActuallyOpen: windowManager.isWindowActuallyOpen(window.id),
                                            onSelect: { selectedWindow = window },
                                            onOpen: { openWindow(window.id) },
                                            onClose: { closeWindow(window.id) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Pulto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Leading toolbar items (left side)
                ToolbarItemGroup(placement: .topBarLeading) {
                    // Sidebar toggle button (left panel only)
                    Button(action: onHomeButtonTap) {
                        Image(systemName: showNavigationView ? "sidebar.left" : "sidebar.squares.left")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(showNavigationView ? .blue : .gray)
                    }
                    .buttonStyle(.plain)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        if showNavigationView {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.blue.opacity(0.7), lineWidth: 2)
                        }
                    }
                    .help("Toggle sidebar")
                    
                    Button(action: {
                        checkJupyterServerStatus()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: jupyterServerStatus.icon)
                                .font(.caption)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(jupyterServerStatus.color)
                                .rotationEffect(isCheckingJupyterServer ? .degrees(360) : .degrees(0))
                                .animation(isCheckingJupyterServer ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isCheckingJupyterServer)

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Jupyter")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                
                                Text(jupyterServerStatus.description)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(jupyterServerStatus.color.opacity(0.3), lineWidth: 1)
                    }
                    .help("Jupyter Server: \(defaultJupyterURL)\nTap to check status")
                    
                    Button(action: {
                        sheetManager.presentSheet(.workspaceDialog)
                    }) {
                        Image(systemName: "plus.square.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .help("New Project")

                    Button(action: {
                        sheetManager.presentSheet(.templateGallery)
                    }) {
                        Image(systemName: "doc.text.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .help("Templates")

                    Button(action: {
                        sheetManager.presentSheet(.classifierSheet)
                    }) {
                        Image(systemName: "doc.badge.plus")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                
                // Principal toolbar item (center)
                ToolbarItem(placement: .principal) {
                    if navigationState == .workspace {
                        Menu {
                            ForEach(StandardWindowType.allCases, id: \.self) { type in
                                Button {
                                    createWindow(type)
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

                                Text("Create View")
                                    .font(.subheadline)
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
                    } else {
                        EmptyView()
                    }
                }
                
                // Trailing toolbar items (right side)
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Inspector toggle button (right panel only)
                    Button(action: onInspectorToggle) {
                        Image(systemName: showInspector ? "sidebar.right" : "sidebar.trailing")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(showInspector ? .blue : .gray)
                    }
                    .buttonStyle(.plain)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        if showInspector {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.blue.opacity(0.7), lineWidth: 2)
                        }
                    }
                    .help("Toggle inspector")
                    
                    // Settings button
                    Button(action: {
                        sheetManager.presentSheet(.settings)
                    }) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // User profile button
                    Button(action: {
                        sheetManager.presentSheet(.appleSignIn)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.isUserLoggedIn ? "person.circle.fill" : "person.circle")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.gray)

                            if viewModel.isUserLoggedIn {
                                Text(viewModel.userName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .onChange(of: windowManager.getAllWindows().count) { count in
            // Reset welcome content when all windows are cleared
            if count == 0 {
                showWelcomeContent = true
                selectedWindow = nil
            }
        }
        .onChange(of: defaultJupyterURL) { _ in
            // Check server status when URL changes
            checkJupyterServerStatus()
        }
        .onAppear {
            // Check server status when view appears
            checkJupyterServerStatus()
        }
    }
    
    // MARK: - Jupyter Server Status Check
    private func checkJupyterServerStatus() {
        guard !isCheckingJupyterServer else { return }
        
        isCheckingJupyterServer = true
        jupyterServerStatus = .checking
        
        Task {
            let status = await checkJupyterServer(url: defaultJupyterURL)
            
            await MainActor.run {
                jupyterServerStatus = status
                isCheckingJupyterServer = false
            }
        }
    }
    
    private func checkJupyterServer(url: String) async -> ServerStatus {
        guard let serverURL = URL(string: url) else {
            return .offline
        }
        
        // Create a simple health check URL for Jupyter
        let healthCheckURL = serverURL.appendingPathComponent("api/kernels")
        
        do {
            let (_, response) = try await URLSession.shared.data(from: healthCheckURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    return .online
                case 401, 403:
                    // Authentication required but server is running
                    return .online
                default:
                    return .offline
                }
            }
            
            return .offline
        } catch {
            // Network error or server not reachable
            return .offline
        }
    }
}

// MARK: - Inspector Components

struct WindowInspectorView: View {
    let selectedWindow: NewWindowID?
    let windowManager: WindowTypeManager
    let onWindowAction: (WindowAction, Int) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                if let window = selectedWindow {
                    VStack(alignment: .leading, spacing: 20) {
                        // Window Header
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: window.windowType.icon)
                                    .font(.title2)
                                    .foregroundStyle(window.windowType.inspectorIconColor)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Window #\(window.id)")
                                        .font(.title2)
                                        .fontWeight(.semibold)

                                    Text(window.windowType.displayName)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }

                            Text(window.windowType.inspectorDescription)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))

                        // Window Properties
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Properties")
                                .font(.headline)

                            VStack(spacing: 8) {
                                WindowInfoRow(label: "Created", value: window.createdAt.formatted(date: .abbreviated, time: .shortened))
                                WindowInfoRow(label: "Position", value: "(\(Int(window.position.x)), \(Int(window.position.y)), \(Int(window.position.z)))")
                                WindowInfoRow(label: "Size", value: "\(Int(window.position.width)) × \(Int(window.position.height))")
                                WindowInfoRow(label: "Template", value: window.state.exportTemplate.rawValue)
                                
                                if !window.state.tags.isEmpty {
                                    WindowInfoRow(label: "Tags", value: window.state.tags.joined(separator: ", "))
                                }
                                
                                WindowInfoRow(label: "Status", value: windowManager.isWindowActuallyOpen(window.id) ? "Open" : "Closed")
                            }
                        }
                        .padding()
                        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))

                        // Window Actions
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Actions")
                                .font(.headline)

                            VStack(spacing: 8) {
                                Button(action: { onWindowAction(.open, window.id) }) {
                                    HStack {
                                        Image(systemName: "play.circle.fill")
                                        Text("Open Window")
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                Button(action: { onWindowAction(.focus, window.id) }) {
                                    HStack {
                                        Image(systemName: "eye.circle.fill")
                                        Text("Focus Window")
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                Button(action: { onWindowAction(.duplicate, window.id) }) {
                                    HStack {
                                        Image(systemName: "doc.on.doc.fill")
                                        Text("Duplicate Window")
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .foregroundColor(.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                Button(action: { onWindowAction(.close, window.id) }) {
                                    HStack {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("Close Window")
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding()
                        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    ContentUnavailableView(
                        "No Window Selected",
                        systemImage: "rectangle.dashed",
                        description: Text("Select a window from the list to view its details")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Inspector")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Missing Window Components

struct SelectableWindowRow: View {
    let window: NewWindowID
    let isSelected: Bool
    let isActuallyOpen: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onClose: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Window type icon
                Image(systemName: window.windowType.icon)
                    .font(.title3)
                    .foregroundStyle(window.windowType.inspectorIconColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Window #\(window.id)")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(window.windowType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !window.state.tags.isEmpty {
                        Text(window.state.tags.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }

                Spacer()

                // Status indicator
                HStack(spacing: 8) {
                    if isActuallyOpen {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .fill(.orange)
                            .frame(width: 8, height: 8)
                    }

                    // Action buttons
                    Button(action: onOpen) {
                        Image(systemName: "play.circle")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)

                    Button(action: onClose) {
                        Image(systemName: "xmark.circle")
                            .font(.title3)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.1) : (isHovered ? Color.gray.opacity(0.05) : Color.clear))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? .blue : .clear, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct WindowRow: View {
    let window: NewWindowID
    let isActuallyOpen: Bool
    let onOpen: () -> Void
    let onClose: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Window type icon
            Image(systemName: window.windowType.icon)
                .font(.title3)
                .foregroundStyle(window.windowType.inspectorIconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("Window #\(window.id)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(window.windowType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !window.state.tags.isEmpty {
                    Text(window.state.tags.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            // Status and actions
            HStack(spacing: 8) {
                if isActuallyOpen {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                }

                Button(action: onOpen) {
                    Image(systemName: "play.circle")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(isHovered ? Color.gray.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { isHovered = $0 }
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
    @State private var showNavigationView = true
    @State private var showInspector = true
    @State private var selectedWindow: NewWindowID? = nil
    @State private var columnVisibility = NavigationSplitViewVisibility.all

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
                                showNavigationView = true
                            }
                        }
                    )
                } else {
                    // Show the workspace - Enhanced three-column layout for visionOS
                    if showNavigationView && showInspector {
                        // Three-column layout: Sidebar + Content + Inspector
                        NavigationSplitView(columnVisibility: $columnVisibility) {
                            // Sidebar with Recent Projects navigation
                            RecentProjectsSidebar(
                                workspaceManager: workspaceManager,
                                loadWorkspace: loadWorkspace
                            )
                            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
                        } content: {
                            // Main content view with NavigationStack toolbar
                            EnhancedActiveWindowsView(
                                windowManager: windowManager,
                                openWindow: { openWindow(value: $0) },
                                closeWindow: { windowManager.removeWindow($0) },
                                closeAllWindows: clearAllWindowsWithConfirmation,
                                sheetManager: sheetManager,
                                createWindow: createStandardWindow,
                                selectedWindow: $selectedWindow,
                                viewModel: viewModel,
                                navigationState: navigationState,
                                showNavigationView: showNavigationView,
                                showInspector: showInspector,
                                onHomeButtonTap: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showNavigationView.toggle()
                                    }
                                },
                                onInspectorToggle: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showInspector.toggle()
                                    }
                                }
                            )
                            .navigationSplitViewColumnWidth(min: 600, ideal: 800, max: 1200)
                        } detail: {
                            // Inspector panel
                            WindowInspectorView(
                                selectedWindow: selectedWindow,
                                windowManager: windowManager,
                                onWindowAction: { action, windowId in
                                    handleWindowAction(action, windowId: windowId)
                                }
                            )
                            .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 450)
                        }
                        .navigationSplitViewStyle(.balanced)
                    } else if showNavigationView && !showInspector {
                        // Two-column layout: Sidebar + Content (no inspector)
                        NavigationSplitView {
                            RecentProjectsSidebar(
                                workspaceManager: workspaceManager,
                                loadWorkspace: loadWorkspace
                            )
                            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
                        } detail: {
                            EnhancedActiveWindowsView(
                                windowManager: windowManager,
                                openWindow: { openWindow(value: $0) },
                                closeWindow: { windowManager.removeWindow($0) },
                                closeAllWindows: clearAllWindowsWithConfirmation,
                                sheetManager: sheetManager,
                                createWindow: createStandardWindow,
                                selectedWindow: $selectedWindow,
                                viewModel: viewModel,
                                navigationState: navigationState,
                                showNavigationView: showNavigationView,
                                showInspector: showInspector,
                                onHomeButtonTap: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showNavigationView.toggle()
                                    }
                                },
                                onInspectorToggle: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showInspector.toggle()
                                    }
                                }
                            )
                        }
                    } else if !showNavigationView && showInspector {
                        // Two-column layout: Content + Inspector (no sidebar)
                        NavigationSplitView {
                            EnhancedActiveWindowsView(
                                windowManager: windowManager,
                                openWindow: { openWindow(value: $0) },
                                closeWindow: { windowManager.removeWindow($0) },
                                closeAllWindows: clearAllWindowsWithConfirmation,
                                sheetManager: sheetManager,
                                createWindow: createStandardWindow,
                                selectedWindow: $selectedWindow,
                                viewModel: viewModel,
                                navigationState: navigationState,
                                showNavigationView: showNavigationView,
                                showInspector: showInspector,
                                onHomeButtonTap: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showNavigationView.toggle()
                                    }
                                },
                                onInspectorToggle: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showInspector.toggle()
                                    }
                                }
                            )
                            .navigationSplitViewColumnWidth(min: 600, ideal: 900, max: 1200)
                        } detail: {
                            WindowInspectorView(
                                selectedWindow: selectedWindow,
                                windowManager: windowManager,
                                onWindowAction: { action, windowId in
                                    handleWindowAction(action, windowId: windowId)
                                }
                            )
                            .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 450)
                        }
                    } else {
                        // Single column: Content only (no sidebar, no inspector)
                        EnhancedActiveWindowsView(
                            windowManager: windowManager,
                            openWindow: { openWindow(value: $0) },
                            closeWindow: { windowManager.removeWindow($0) },
                            closeAllWindows: clearAllWindowsWithConfirmation,
                            sheetManager: sheetManager,
                            createWindow: createStandardWindow,
                            selectedWindow: $selectedWindow,
                            viewModel: viewModel,
                            navigationState: navigationState,
                            showNavigationView: showNavigationView,
                            showInspector: showInspector,
                            onHomeButtonTap: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showNavigationView.toggle()
                                }
                            },
                            onInspectorToggle: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showInspector.toggle()
                                }
                            }
                        )
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
                    createWindow: { _ in }
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
        @AppStorage("defaultJupyterURL") private var defaultJupyterURL: String = "http://localhost:8888"

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

                                TextField("Enter Jupyter server URL", text: $defaultJupyterURL)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))

                                Text("Default Jupyter notebook server to connect to when importing or creating notebooks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    
                                // Quick preset buttons for Jupyter
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Quick Options:")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)

                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                        ForEach(["http://localhost:8888", "http://localhost:8889", "http://127.0.0.1:8888"], id: \.self) { url in
                                            Button(url) {
                                                defaultJupyterURL = url
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            .font(.caption)
                                            .fontDesign(.monospaced)
                                        }
                                    }
                                }
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
        }
    }

    @MainActor
    private func clearAllWindowsWithConfirmation() {
        windowManager.getAllWindows().forEach { windowManager.removeWindow($0.id) }
    }

    // MARK: - Window Action Handler
    private func handleWindowAction(_ action: WindowAction, windowId: Int) {
        switch action {
        case .open:
            openWindow(value: windowId)
            windowManager.markWindowAsOpened(windowId)
        case .close:
            windowManager.removeWindow(windowId)
        case .focus:
            openWindow(value: windowId)
        case .duplicate:
            // Create duplicate window
            let originalWindow = windowManager.getAllWindows().first { $0.id == windowId }
            if let original = originalWindow {
                let duplicateType = original.windowType.toStandardWindowType()
                createStandardWindow(duplicateType)
            }
        }
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
        // Main content without toolbar (since it's now in the navigation bar)
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
                        visualizations: 3,
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

// MARK: - Helper Views

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

// MARK: - Original ActiveWindowsView (maintained for compatibility)
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

// MARK: - WindowType Extensions
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

    var inspectorDescription: String {
        switch self {
        case .charts: return "Interactive data visualization charts"
        case .spatial: return "3D spatial data representation"
        case .column: return "Tabular data display with sorting and filtering"
        case .volume: return "Volumetric data visualization"
        case .pointcloud: return "3D point cloud visualization"
        case .model3d: return "3D model viewer and manipulation"
        }
    }

    var inspectorIconColor: Color {
        switch self {
        case .charts: return .blue
        case .spatial: return .purple
        case .column: return .green
        case .volume: return .orange
        case .pointcloud: return .cyan
        case .model3d: return .red
        }
    }

    func toStandardWindowType() -> StandardWindowType {
        switch self {
        case .column: return .dataFrame
        case .pointcloud: return .pointCloud
        case .model3d: return .model3d
        case .volume: return .iotDashboard
        default: return .dataFrame
        }
    }
}

// MARK: - Welcome Components
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

// MARK: - Previews
struct EnvironmentView_Previews: PreviewProvider {
    static var previews: some View { EnvironmentView() }
}