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

// MARK: - Extensions

extension WindowType {
    var inspectorIconColor: Color {
        switch self {
        case .column: return .green
        case .charts: return .blue
        case .spatial: return .purple
        case .volume: return .orange
        case .pointcloud: return .cyan
        case .model3d: return .red
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

    // Add workspace manager for recent projects
    @StateObject private var workspaceManager = WorkspaceManager.shared

    @State private var statusCheckTask: Task<Void, Never>?
    @State private var animationTask: Task<Void, Never>?

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
                    if windowManager.getAllWindows().isEmpty {
                        // Show recent projects when no windows are active
                        if !workspaceManager.getCustomWorkspaces().isEmpty {
                            VStack(alignment: .leading, spacing: 20) {
                                HStack {
                                    Text("Recent Projects")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                
                                LazyVGrid(columns: [
                                    GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
                                ], spacing: 16) {
                                    ForEach(workspaceManager.getCustomWorkspaces().prefix(12)) { workspace in
                                        RecentProjectCard(
                                            workspace: workspace,
                                            onTap: { workspace in
                                                // Handle loading the workspace
                                                // This would need to be passed in as a parameter
                                            }
                                        )
                                    }
<<<<<<< HEAD
                                }
                                .padding(.horizontal, 12)
                            }
                        } else {
                            // Show placeholder when no recent projects exist
                            VStack(spacing: 16) {
                                Image(systemName: "folder.badge.questionmark")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                
                                VStack(spacing: 8) {
                                    Text("No Recent Projects")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Text("Create a new project to get started")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
=======
>>>>>>> version_0
                                }
                                .padding(.horizontal, 12)
                            }
<<<<<<< HEAD
=======
                        } else {
                            // Show placeholder when no recent projects exist
                            VStack(spacing: 16) {
                                Image(systemName: "folder.badge.questionmark")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                
                                VStack(spacing: 8) {
                                    Text("No Recent Projects")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Text("Create a new project to get started")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
>>>>>>> version_0
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16))
                        }
                        
                        if workspaceManager.getCustomWorkspaces().isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "rectangle.dashed")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                
                                VStack(spacing: 8) {
                                    Text("No Active Views")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Text("Create a new view using the options above")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16))
                        }
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
                    // GROUP 1: Navigation & Status (pill container)
                    HStack(spacing: 8) {
                        Button(action: onHomeButtonTap) {
                            Image(systemName: showNavigationView ? "sidebar.left" : "sidebar.squares.left")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(showNavigationView ? .blue : .gray)
                        }
                        .buttonStyle(.plain)
                        .help("Toggle sidebar")

                        Button(action: {
                            checkJupyterServerStatus()
                        }) {
                            Image(systemName: jupyterServerStatus.icon)
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(jupyterServerStatus.color)
                                .rotationEffect(isCheckingJupyterServer ? .degrees(360) : .degrees(0))
                                .animation(.easeInOut(duration: 0.3), value: jupyterServerStatus)
                        }
                        .buttonStyle(.plain)
                        .help("Jupyter Server: \(defaultJupyterURL)\nTap to check status")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        if showNavigationView {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.blue.opacity(0.3), lineWidth: 1)
                        }
                    }

                    // GROUP 2: Project & Content Creation (pill container)
                    HStack(spacing: 8) {
                        Button(action: {
                            sheetManager.presentSheet(.workspaceDialog)
                        }) {
                            Image(systemName: "plus.square.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.gray)
                        }
                        .buttonStyle(.plain)
                        .help("New Project")

                        Button(action: {
                            sheetManager.presentSheet(.templateGallery)
                        }) {
                            Image(systemName: "doc.text.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.gray)
                        }
                        .buttonStyle(.plain)
                        .help("Templates")

                        Button(action: {
                            sheetManager.presentSheet(.classifierSheet)
                        }) {
                            Image(systemName: "doc.badge.plus")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.gray)
                        }
                        .buttonStyle(.plain)
                        .help("Import")

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
                                Image(systemName: "chart.bar.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.gray)
                            }
                            .buttonStyle(.plain)
                            .help("Add Window")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                // Principal toolbar item (center)
                ToolbarItem(placement: .principal) {
                    EmptyView()
                }

                // Trailing toolbar items (right side)
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // GROUP 3: User & Settings (pill container)
                    HStack(spacing: 8) {
                        Button(action: {
                            sheetManager.presentSheet(.settings)
                        }) {
                            Image(systemName: "gearshape")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.gray)
                        }
                        .buttonStyle(.plain)
                        .help("Settings")

                        Button(action: {
                            sheetManager.presentSheet(.appleSignIn)
                        }) {
                            HStack(spacing: 6) {
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
                        }
                        .buttonStyle(.plain)
                        .help("User Profile")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Inspector toggle (separate)
                    Button(action: onInspectorToggle) {
                        Image(systemName: showInspector ? "sidebar.right" : "sidebar.trailing")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(showInspector ? .blue : .gray)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        if showInspector {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.blue.opacity(0.3), lineWidth: 1)
                        }
                    }
                    .help("Toggle inspector")
                }
            }
        }
        .onChange(of: windowManager.getAllWindows().count) { count in
            // Clear selected window when all windows are cleared
            if count == 0 {
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
        .onDisappear {
            cancelAllTasks()
        }
    }

    // MARK: - FIXED: Jupyter Server Status Check with proper task management
    private func checkJupyterServerStatus() {
        // Cancel any existing task to prevent multiple concurrent requests
        statusCheckTask?.cancel()

        guard !isCheckingJupyterServer else { return }

        isCheckingJupyterServer = true
        jupyterServerStatus = .checking

        // Create a manual rotation animation task
        startRotationAnimation()

        statusCheckTask = Task {
            let status = await checkJupyterServer(url: defaultJupyterURL)

            // Check if task was cancelled before updating UI
            guard !Task.isCancelled else { return }

            await MainActor.run {
                jupyterServerStatus = status
                isCheckingJupyterServer = false
                stopRotationAnimation()
            }
        }
    }

    private func startRotationAnimation() {
        animationTask?.cancel()

        animationTask = Task {
            while !Task.isCancelled && isCheckingJupyterServer {
                await MainActor.run {
                    // Trigger a single rotation
                    withAnimation(.linear(duration: 1)) {
                        // Use a changing value to trigger animation
                    }
                }

                // Wait for 1 second before next rotation
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 0.5 seconds
            }
        }
    }

    private func stopRotationAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }

    private func cancelAllTasks() {
        statusCheckTask?.cancel()
        statusCheckTask = nil
        animationTask?.cancel()
        animationTask = nil
    }

    private func checkJupyterServer(url: String) async -> ServerStatus {
        guard let serverURL = URL(string: url) else {
            return .offline
        }

        // Create a health check URL for Jupyter
        let healthCheckURL = serverURL.appendingPathComponent("api/kernels")

        // Configure URLSession with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0  // 5 second timeout
        config.timeoutIntervalForResource = 10.0
        let session = URLSession(configuration: config)

        defer {
            session.invalidateAndCancel()  // IMPORTANT: Clean up session
        }

        do {
            let (_, response) = try await session.data(from: healthCheckURL)

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

// MARK: - Window Components

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

// MARK: - Recent Project Card for Grid Layout
struct RecentProjectCard: View {
    let workspace: WorkspaceMetadata
    let onTap: (WorkspaceMetadata) -> Void
    
    var body: some View {
        Button(action: {
            onTap(workspace)
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Project Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .frame(height: 60)
                    
                    Image(systemName: "folder.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                // Project Name
                Text(workspace.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Project Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "rectangle.stack")
                            .font(.caption)
                        Text("\(workspace.totalWindows) views")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    Text(workspace.formattedModifiedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 140)
            .padding(12)
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Views

// StatCard component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 8))
    }
}

// Settings Section Helper
@ViewBuilder
private func SettingsSection<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title)
            .font(.headline)
            .fontWeight(.semibold)
        
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
    }
    .padding()
    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
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
    @State private var showInspector = false
    @State private var selectedWindow: NewWindowID? = nil
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    @State private var initialLoadTask: Task<Void, Never>?
    @State private var welcomeTask: Task<Void, Never>?

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
                    // Show the workspace view
                    workspaceView
                }
            }
        }
        //.glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(20)
        .task {
            initialLoadTask?.cancel()
            initialLoadTask = Task {
                await viewModel.loadInitialData()
                if !Task.isCancelled {
                    await MainActor.run {
                        checkFirstLaunch()
                    }
                }
            }
        }
        .onDisappear {
            initialLoadTask?.cancel()
            welcomeTask?.cancel()
        }
        .singleSheetManager(sheetManager) { sheetType, data in
            AnyView(sheetContent(for: sheetType, data: data))
        }
    }

    // MARK: - Workspace View (broken out to reduce complexity)
    @ViewBuilder
    private var workspaceView: some View {
        if showNavigationView && showInspector {
            threeColumnLayout
        } else if showNavigationView && !showInspector {
            twoColumnLayoutWithSidebar
        } else if !showNavigationView && showInspector {
            twoColumnLayoutWithInspector
        } else {
            singleColumnLayout
        }
    }

    // MARK: - Layout Variations
    @ViewBuilder
    private var threeColumnLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            RecentProjectsSidebar(
                workspaceManager: workspaceManager,
                loadWorkspace: loadWorkspace
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } content: {
            enhancedActiveWindowsView
                .navigationSplitViewColumnWidth(min: 600, ideal: 800, max: 1200)
        } detail: {
            inspectorView
                .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 450)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var twoColumnLayoutWithSidebar: some View {
        NavigationSplitView {
            RecentProjectsSidebar(
                workspaceManager: workspaceManager,
                loadWorkspace: loadWorkspace
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            enhancedActiveWindowsView
        }
    }

    @ViewBuilder
    private var twoColumnLayoutWithInspector: some View {
        NavigationSplitView {
            enhancedActiveWindowsView
                .navigationSplitViewColumnWidth(min: 600, ideal: 900, max: 1200)
        } detail: {
            inspectorView
                .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 450)
        }
    }

    @ViewBuilder
    private var singleColumnLayout: some View {
        enhancedActiveWindowsView
    }

    // MARK: - Reusable View Components
    @ViewBuilder
    private var enhancedActiveWindowsView: some View {
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

    @ViewBuilder
    private var inspectorView: some View {
        WindowInspectorView(
            selectedWindow: selectedWindow,
            windowManager: windowManager,
            onWindowAction: { action, windowId in
                handleWindowAction(action, windowId: windowId)
            }
        )
    }

    // MARK: - Sheet Content Builder
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

    // MARK: - Helper Methods

    private func checkFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        let welcomeSheetDismissed = UserDefaults.standard.bool(forKey: "WelcomeSheetDismissed")

        // Only show welcome sheet if app has never launched AND welcome has never been dismissed
        if !hasLaunchedBefore && !welcomeSheetDismissed {
            // Use Task instead of DispatchQueue to prevent memory leaks
            welcomeTask?.cancel()
            welcomeTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                if !Task.isCancelled {
                    await MainActor.run {
                        sheetManager.presentSheet(.welcome)
                    }
                }
            }
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
        let allWindows = windowManager.getAllWindows()
        let openWindows = windowManager.getAllWindows(onlyOpen: true)
        
        // First, dismiss all actual SwiftUI windows
        for window in openWindows {
            // Dismiss the appropriate window based on window type
            switch window.windowType {
            case .pointcloud:
                dismissWindow(id: "volumetric-pointcloud", value: window.id)
                dismissWindow(id: "volumetric-pointclouddemo", value: window.id)
            case .model3d:
                dismissWindow(id: "volumetric-model3d", value: window.id)
            case .charts:
                dismissWindow(id: "volumetric-chart3d", value: window.id)
            case .column, .spatial, .volume:
                // These use the regular window group
                dismissWindow(value: NewWindowID.ID(window.id))
            }
            
            // Mark as closed in the manager
            windowManager.markWindowAsClosed(window.id)
        }
        
        // Clean up entities
        Task { @MainActor in
            EntityLifecycleManager.shared.cleanupAll()
        }
        
        // Remove all windows from the manager
        windowManager.clearAllWindows()
        
        print("🗑️ Closed and cleaned up \(allWindows.count) windows")
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

                // Add FileImportRowView
                FileImportRowView { fileURL in
                    handleFileImport(fileURL)
                }

                if viewModel.isLoadingProjects {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading projects...")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
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
                    print("✅ Created new project with notebook: \(notebookURL.lastPathComponent)")

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

                    print("✅ New project '\(newProject.name)' created successfully")
                } else {
                    print("❌ Failed to create notebook for new project")
                    // Still continue to open the workspace even if notebook creation failed
                }

                // Switch to workspace view
                await MainActor.run {
                    onOpenWorkspace()
                }

            } catch {
                print("❌ Error creating new project: \(error)")
                // Still try to open the workspace
                await MainActor.run {
                    onOpenWorkspace()
                }
            }
        }
    }

    // MARK: - File Import Handler
    private func handleFileImport(_ fileURL: URL) {
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Determine the appropriate window type based on file extension
        let windowType: StandardWindowType
        switch fileExtension {
        case "usdz":
            windowType = .model3d
        case "ply", "pcd", "xyz", "pts":
            windowType = .pointCloud
        default:
            windowType = .dataFrame // Default fallback
        }
        
        // Create a window for the imported file
        createWindowForImportedFile(windowType, fileURL: fileURL)
        
        // Switch to workspace view to show the new window
        onOpenWorkspace()
    }
    
    private func createWindowForImportedFile(_ type: StandardWindowType, fileURL: URL) {
        let position = WindowPosition(
            x: 100 + Double(Int.random(in: 0...100)),
            y: 100 + Double(Int.random(in: 0...100)),
            z: 0,
            width: 800,
            height: 600
        )
        
        let windowType = type.toWindowType()
        let newWindowID = Int.random(in: 1000...9999) // Generate a unique ID
        
        _ = windowManager.createWindow(windowType,
                                       id: newWindowID,
                                       position: position)
        
        // Store the file URL with the window (this would need to be implemented in WindowTypeManager)
        // For now, just open the window
        openWindow(value: newWindowID)
        windowManager.markWindowAsOpened(newWindowID)
        
        print("📁 Imported file: \(fileURL.lastPathComponent) as \(type.displayName)")
    }
}

// MARK: - Active Windows View
struct ActiveWindowsView: View {
    let windowManager: WindowTypeManager
    let openWindow: (Int) -> Void
    let closeWindow: (Int) -> Void
    let closeAllWindows: () -> Void
    let sheetManager: SheetManager
    let createWindow: (StandardWindowType) -> Void
    @State private var selectedType: StandardWindowType? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if windowManager.getAllWindows().isEmpty {
                    // Show simple empty state when no windows
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

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
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

                        // Quick Actions
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Quick Actions")
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Spacer()

                                Menu("Create Window") {
                                    ForEach(StandardWindowType.allCases, id: \.self) { type in
                                        Button {
                                            createWindow(type)
                                        } label: {
                                            Label(type.displayName, systemImage: type.icon)
                                        }
                                    }
                                } primaryAction: {
                                    // Default action when button is tapped directly
                                    createWindow(.dataFrame)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }

                            LazyVGrid(columns: [
                                GridItem(.flexible()), GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(StandardWindowType.allCases, id: \.self) { type in
                                    Button {
                                        createWindow(type)
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: type.icon)
                                                .font(.title2)
                                                .foregroundStyle(type.iconColor)

                                            Text(type.displayName)
                                                .font(.caption)
                                                .fontWeight(.medium)

                                            Text(type.description)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .multilineTextAlignment(.center)
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity, minHeight: 100)
                                        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedType == type ? type.iconColor : .clear, lineWidth: 2)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { isHovered in
                                        selectedType = isHovered ? type : nil
                                    }
                                }
                            }
                        }

                        Divider()

                        // Active Windows List
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Active Windows")
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
                    }
                }
            }
            .padding()
        }
        .onChange(of: windowManager.getAllWindows().count) { count in
            // Clear selected type when all windows are cleared
            if count == 0 {
                selectedType = nil
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
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(workspace.totalWindows)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Windows")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(workspace.tags.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Tags")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .padding()
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16))

                    // Project Tags
                    if !workspace.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tags")
                                .font(.headline)

                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 80), spacing: 8)
                            ], spacing: 8) {
                                ForEach(workspace.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding()
                        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16))
                    }

                    // Project Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Project Information")
                            .font(.headline)

                        VStack(spacing: 8) {
                            HStack {
                                Text("Created")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(workspace.createdDate, style: .date)
                            }

                            HStack {
                                Text("Last Modified")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(workspace.modifiedDate, style: .relative)
                            }

                            if workspace.totalWindows > 0 {
                                HStack {
                                    Text("Windows")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(workspace.totalWindows)")
                                }
                            }
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

// MARK: - Welcome Sheet Components

struct WelcomeSheet: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        
                        Text("Welcome to Pulto")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Your spatial data visualization platform")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    
                    // Features
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        WelcomeStep(
                            icon: "plus.square.on.square",
                            title: "Create Projects",
                            description: "Start new data visualization projects"
                        )
                        
                        WelcomeStep(
                            icon: "cube",
                            title: "3D Models",
                            description: "Visualize 3D models and point clouds"
                        )
                        
                        WelcomeStep(
                            icon: "chart.bar",
                            title: "Charts & Graphs",
                            description: "Create interactive visualizations"
                        )
                        
                        WelcomeStep(
                            icon: "doc.text",
                            title: "Import Notebooks",
                            description: "Import Jupyter notebooks seamlessly"
                        )
                    }
                    .padding()
                    
                    // Tips
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pro Tips")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            ProTip(
                                icon: "command",
                                text: "Use keyboard shortcuts for faster navigation",
                                color: .blue
                            )
                            
                            ProTip(
                                icon: "hand.tap",
                                text: "Tap and hold for context menus",
                                color: .green
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Get Started") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 600, height: 700)
    }
}

struct WelcomeStep: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.blue)
            
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ProTip: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
            
            Text(text)
                .font(.subheadline)
        }
<<<<<<< HEAD
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
=======
>>>>>>> version_0
    }
}

// MARK: - Preview
struct EnvironmentView_Previews: PreviewProvider {
    static var previews: some View { EnvironmentView() }
}
