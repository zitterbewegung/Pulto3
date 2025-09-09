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

// ==== JUPYTER HELPERS (place at file scope; remove any duplicate old versions) ====

func httpToWebSocketURL(base: URL, kernelID: String) -> URL? {
    var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
    if comps?.scheme == "http" { comps?.scheme = "ws" }
    else if comps?.scheme == "https" { comps?.scheme = "wss" }
    comps?.path += "/api/kernels/\(kernelID)/channels"
    return comps?.url
}

final class JupyterClient: ObservableObject {
    @Published var serverURLString: String
    @Published var kernelID: String? = nil
    @Published var sessionID: String? = nil

    private var webSocket: URLSessionWebSocketTask?
    private let urlSession: URLSession

    init(serverURLString: String) {
        self.serverURLString = serverURLString
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 10
        cfg.timeoutIntervalForResource = 30
        self.urlSession = URLSession(configuration: cfg)
    }

    @discardableResult
    func ensureSession(notebookPath: String = "Untitled.ipynb") async throws -> String {
        if let sid = sessionID { return sid }
        guard let base = URL(string: serverURLString) else { throw URLError(.badURL) }
        var req = URLRequest(url: base.appendingPathComponent("api/sessions"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "kernel": ["name": "python3"],
            "name": UUID().uuidString,
            "path": notebookPath,
            "type": "notebook"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let sid = json["id"] as? String { self.sessionID = sid }
            if let kernel = json["kernel"] as? [String: Any],
               let kid = kernel["id"] as? String { self.kernelID = kid }
        }
        guard let sid = self.sessionID else { throw URLError(.badServerResponse) }
        return sid
    }

    func connectChannels() async throws {
        guard let kid = kernelID, let base = URL(string: serverURLString) else {
            throw URLError(.badURL)
        }
        guard let wsURL = httpToWebSocketURL(base: base, kernelID: kid) else {
            throw URLError(.badURL)
        }
        let task = urlSession.webSocketTask(with: wsURL)
        self.webSocket = task
        task.resume()
        Task { await self.receiveLoop() }
    }

    private func receiveLoop() async {
        guard let ws = webSocket else { return }
        while true {
            do {
                let msg = try await ws.receive()
                switch msg {
                case .string(let text):
                    print("[Jupyter IOPub] \(text.prefix(300))…")
                case .data(let data):
                    if let s = String(data: data, encoding: .utf8) {
                        print("[Jupyter IOPub bin] \(s.prefix(300))…")
                    }
                @unknown default: break
                }
            } catch {
                break
            }
        }
    }

    func execute(code: String) async throws {
        guard let ws = webSocket else { throw URLError(.cannotConnectToHost) }
        let envelope: [String: Any] = [
            "header": [
                "msg_id": UUID().uuidString,
                "username": "pulto",
                "session": UUID().uuidString,
                "msg_type": "execute_request",
                "version": "5.3"
            ],
            "parent_header": [:],
            "metadata": [:],
            "content": [
                "code": code,
                "silent": false,
                "store_history": true,
                "user_expressions": [:],
                "allow_stdin": false,
                "stop_on_error": true
            ],
            "channel": "shell"
        ]
        let data = try JSONSerialization.data(withJSONObject: envelope)
        try await ws.send(.data(data))
    }

    func interruptKernel() async {
        guard let kid = kernelID, let base = URL(string: serverURLString) else { return }
        var req = URLRequest(url: base.appendingPathComponent("api/kernels/\(kid)/interrupt"))
        req.httpMethod = "POST"
        _ = try? await urlSession.data(for: req)
    }

    func shutdownSession() async {
        guard let sid = sessionID, let base = URL(string: serverURLString) else { return }
        var req = URLRequest(url: base.appendingPathComponent("api/sessions/\(sid)"))
        req.httpMethod = "DELETE"
        _ = try? await urlSession.data(for: req)
        sessionID = nil
        kernelID  = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }
}

struct JupyterContentsClient {
    let baseURLString: () -> String

    private func baseURL() throws -> URL {
        guard let u = URL(string: baseURLString()) else { throw URLError(.badURL) }
        return u
    }

    /// PUT /api/contents/<path> for a notebook JSON object
    func putNotebook(path: String, notebookObject: Any) async throws {
        var u = try baseURL()
        u.appendPathComponent("api/contents")
        u.appendPathComponent(path)

        var req = URLRequest(url: u)
        req.httpMethod = "PUT"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "type": "notebook",
            "format": "json",
            "content": notebookObject
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

struct NBCodeCell: Identifiable, Codable {
    let id = UUID()
    var source: [String]
    var outputs: [NBOutput]
    var execution_count: Int?

    enum CodingKeys: String, CodingKey { case source, outputs, execution_count }
}

enum NBOutput: Codable, Identifiable {
    var id: UUID { UUID() }

    case stream(text: String)
    case executeResult(text: String)
    case displayData(text: String)
    case error(ename: String, evalue: String)

    enum CodingKeys: String, CodingKey { case output_type, name, text, data, ename, evalue }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let ot = try c.decode(String.self, forKey: .output_type)
        switch ot {
        case "stream":
            let text = (try? c.decode(String.self, forKey: .text)) ?? ""
            self = .stream(text: text)
        case "execute_result":
            if let data = try? c.decode([String: String].self, forKey: .data),
               let text = data["text/plain"] { self = .executeResult(text: text) }
            else { self = .executeResult(text: "") }
        case "display_data":
            if let data = try? c.decode([String: String].self, forKey: .data),
               let text = data["text/plain"] { self = .displayData(text: text) }
            else { self = .displayData(text: "") }
        case "error":
            let ename = (try? c.decode(String.self, forKey: .ename)) ?? "Error"
            let evalue = (try? c.decode(String.self, forKey: .evalue)) ?? ""
            self = .error(ename: ename, evalue: evalue)
        default:
            self = .displayData(text: "")
        }
    }

    func encode(to encoder: Encoder) throws { /* not needed */ }
}

struct NBNotebook: Codable {
    var cells: [NBAnyCell]
    var nbformat: Int
    var nbformat_minor: Int

    struct NBAnyCell: Codable {
        var cell_type: String
        var source: [String]?
        var outputs: [NBOutput]?
        var execution_count: Int?

        func asCode() -> NBCodeCell? {
            guard cell_type == "code", let src = source else { return nil }
            return NBCodeCell(source: src, outputs: outputs ?? [], execution_count: execution_count)
        }
    }

    func codeCells() -> [NBCodeCell] { cells.compactMap { $0.asCode() } }
}

final class NotebookManager: ObservableObject {
    struct Session {
        var client: JupyterClient
        var path: String
        var cells: [NBCodeCell]
        var sessionID: String
    }

    @Published private(set) var sessions: [Int: Session] = [:] // windowId → Session

    private let baseURLProvider: () -> String
    private lazy var contentsClient = JupyterContentsClient(baseURLString: baseURLProvider)

    init(baseURLProvider: @escaping () -> String) {
        self.baseURLProvider = baseURLProvider
    }

    func bootstrap(windowId: Int, notebookJSON: String, suggestedPath: String? = nil) async {
        guard sessions[windowId] == nil else { return }
        do {
            guard let data = notebookJSON.data(using: .utf8) else { return }
            let nb = try JSONDecoder().decode(NBNotebook.self, from: data)
            let cells = nb.codeCells()

            let path = suggestedPath ?? "Pulto-\(UUID().uuidString.prefix(8)).ipynb"

            let obj = try JSONSerialization.jsonObject(with: data)
            try await contentsClient.putNotebook(path: path, notebookObject: obj)

            let client = JupyterClient(serverURLString: baseURLProvider())
            let sid = try await client.ensureSession(notebookPath: path)
            try await client.connectChannels()

            await MainActor.run {
                sessions[windowId] = Session(client: client, path: path, cells: cells, sessionID: sid)
            }
        } catch {
            print("NotebookManager bootstrap error: \(error)")
        }
    }

    func runAll(windowId: Int) async {
        guard let s = sessions[windowId] else { return }
        do {
            for cell in s.cells {
                try await s.client.execute(code: cell.source.joined())
            }
        } catch {
            print("runAll error: \(error)")
        }
    }

    func runCell(windowId: Int, index: Int) async {
        guard let s = sessions[windowId], s.cells.indices.contains(index) else { return }
        do {
            try await s.client.execute(code: s.cells[index].source.joined())
        } catch {
            print("runCell error: \(error)")
        }
    }

    func shutdown(windowId: Int, politelyInterruptFirst: Bool = true) async {
        guard let s = sessions[windowId] else { return }
        if politelyInterruptFirst { await s.client.interruptKernel() }
        await s.client.shutdownSession()
        await MainActor.run { sessions.removeValue(forKey: windowId) }
    }

    func shutdownAll(politelyInterruptFirst: Bool = true) async {
        let ids = await MainActor.run { Array(sessions.keys) }
        for wid in ids {
            await shutdown(windowId: wid, politelyInterruptFirst: politelyInterruptFirst)
        }
    }

    func cells(windowId: Int) -> [NBCodeCell] { sessions[windowId]?.cells ?? [] }
    func path(windowId: Int) -> String? { sessions[windowId]?.path }
}

// ==== /JUPYTER HELPERS ====


// MARK: - Enhanced Active Windows View
struct EnhancedActiveWindowsView: View {
    let windowManager: WindowTypeManager
    let openWindow: (Int) -> Void
    let closeWindow: (Int) -> Void
    let closeAllWindows: () -> Void
    let sheetManager: SheetManager
    let createWindow: (StandardWindowType) -> Void
    @Binding var selectedWindow: NewWindowID?
    let viewModel: PultoHomeViewModel
    let navigationState: NavigationState
    let showNavigationView: Bool
    let showInspector: Bool
    let onHomeButtonTap: () -> Void
    let onInspectorToggle: () -> Void

    // Add Jupyter server settings
    @AppStorage("defaultJupyterURL") private var defaultJupyterURL: String = "http://localhost:8888"
    @State private var jupyterServerStatus: EnhancedActiveWindowsView.ServerStatus = .unknown
    @State private var isCheckingJupyterServer = false

    // Add workspace manager for recent projects
    @StateObject private var workspaceManager = WorkspaceManager.shared

    @State private var statusCheckTask: Task<Void, Never>?
    @State private var animationTask: Task<Void, Never>?

    // Add state for local Jupyter
    @State private var isLocalJupyterRunning = false
    
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
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if windowManager.getAllWindows().isEmpty {
                    // Show placeholder when no active windows exist (removed recent projects section)
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
                        .padding(.horizontal, 12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 16))
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
        .toolbar {
            // Leading toolbar items (left side)
            ToolbarItemGroup(placement: .topBarLeading) {
                // GROUP 1: Navigation & Status (pill container)
                HStack(spacing: 12) {
                    Button(action: onHomeButtonTap) {
                        Image(systemName: showNavigationView ? "sidebar.left" : "sidebar.squares.left")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(showNavigationView ? .blue : .gray)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle sidebar")

                    Button(action: {
                        checkJupyterServerStatus()
                    }) {
                        Image(systemName: jupyterServerStatus.icon)
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(jupyterServerStatus.color)
                            .rotationEffect(isCheckingJupyterServer ? .degrees(360) : .degrees(0))
                            .animation(.easeInOut(duration: 0.3), value: jupyterServerStatus)
                    }
                    .buttonStyle(.plain)
                    .help("Jupyter Server: \(defaultJupyterURL)\nTap to check status")

                    #if !os(visionOS)
                    Button(action: {
                        toggleLocalJupyter()
                    }) {
                        Image(systemName: isLocalJupyterRunning ? "stop.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(isLocalJupyterRunning ? .red : .green)
                    }
                    .buttonStyle(.plain)
                    .help(isLocalJupyterRunning ? "Stop Local Jupyter" : "Start Local Jupyter")
                    #endif
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                //.glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    if showNavigationView {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.blue.opacity(0.3), lineWidth: 1)
                    }
                }

                // GROUP 2: Project & Content Creation (pill container)
                HStack(spacing: 12) {
                    Button(action: {
                        sheetManager.presentSheet(.workspaceDialog)
                    }) {
                        Image(systemName: "plus.square.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                    .help("New Project")

                    Button(action: {
                        sheetManager.presentSheet(.templateGallery)
                    }) {
                        Image(systemName: "doc.text.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                    .help("Templates")

                    Button(action: {
                        sheetManager.presentSheet(.classifierSheet)
                    }) {
                        Image(systemName: "doc.badge.plus")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                    .help("Import")

                    Button(action: {
                        createWindow(.dataFrame)
                    }) {
                        Image(systemName: "chart.bar.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                    .help("Add Window")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
            }

            // Principal toolbar item (center)
            ToolbarItem(placement: .principal) {
                EmptyView()
            }

            // Trailing toolbar items (right side)
            ToolbarItemGroup(placement: .topBarTrailing) {
                // GROUP 3: User & Settings (pill container)
                HStack(spacing: 12) {
                    // Export Notebook JSON button
                    Button(action: {
                        exportNotebookJSON()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                    .help("Export Notebook JSON")

                    Button(action: {
                        sheetManager.presentSheet(.settings)
                    }) {
                        Image(systemName: "gearshape")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")

                    // Commented out the login button
                    /*
                    Button(action: {
                        sheetManager.presentSheet(.appleSignIn)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.isUserLoggedIn ? "person.circle.fill" : "person.circle")
                                .font(.title2)
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
                    */
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                // Inspector toggle (separate)
                Button(action: onInspectorToggle) {
                    Image(systemName: showInspector ? "sidebar.right" : "sidebar.trailing")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(showInspector ? .blue : .gray)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    if showInspector {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.blue.opacity(0.3), lineWidth: 1)
                    }
                }
                .help("Toggle inspector")
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

    // MARK: - Export Notebook JSON
    private func exportNotebookJSON() {
        // Generate notebook JSON for all open windows
        let notebookJSON = generateNotebookJSON()
        sheetManager.presentSheet(.notebookJSON, data: notebookJSON)
    }

    // MARK: - Toggle Local Jupyter
    private func toggleLocalJupyter() {
        #if !os(visionOS)
        if isLocalJupyterRunning {
            stopLocalJupyter()
        } else {
            startLocalJupyter()
        }
        #endif
    }

    // MARK: - Start Local Jupyter
    private func startLocalJupyter() {
        #if !os(visionOS)
        do {
            let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            _ = try CarnetsCore.startLocalJupyterServer(root: root)
            isLocalJupyterRunning = true
        } catch {
            print("Carnets start error: \(error)")
            isLocalJupyterRunning = false
        }
        #endif
    }

    // MARK: - Stop Local Jupyter
    private func stopLocalJupyter() {
        #if !os(visionOS)
        CarnetsCore.stopLocalJupyterServer()
        isLocalJupyterRunning = false
        #endif
    }

    // MARK: - Generate Notebook JSON
    private func generateNotebookJSON() -> String {
        // Create a basic Jupyter notebook structure
        var cells: [[String: Any]] = []
        
        // Add a markdown cell with project info
        if let project = windowManager.selectedProject {
            let projectInfoCell: [String: Any] = [
                "cell_type": "markdown",
                "metadata": [:],
                "source": [
                    "# \(project.name)\n",
                    "Generated by Pulto\n",
                    "Last modified: \(Date().formatted(date: .complete, time: .shortened))\n"
                ]
            ]
            cells.append(projectInfoCell)
        }
        
        // Add cells for each window
        for window in windowManager.getAllWindows() {
            let windowCell: [String: Any] = [
                "cell_type": "code",
                "execution_count": NSNull(),
                "metadata": [
                    "window_id": window.id,
                    "window_type": window.windowType.rawValue
                ] as [String : Any],
                "outputs": [],
                "source": [
                    "# Window #\(window.id): \(window.windowType.displayName)\n",
                    "# Position: (\(window.position.x), \(window.position.y), \(window.position.z))\n",
                    "# Size: \(window.position.width) × \(window.position.height)\n",
                    "print(\"Window #\(window.id) - \(window.windowType.displayName)\")\n"
                ]
            ]
            cells.append(windowCell)
        }
        
        // Create the notebook structure
        let notebook: [String: Any] = [
            "cells": cells,
            "metadata": [
                "kernelspec": [
                    "display_name": "Python 3",
                    "language": "python",
                    "name": "python3"
                ] as [String : Any],
                "language_info": [
                    "name": "python",
                    "version": "3.9.0"
                ] as [String : Any]
            ] as [String : Any],
            "nbformat": 4,
            "nbformat_minor": 4
        ]
        
        // Convert to JSON string
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: notebook, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            print("Error generating notebook JSON: \(error)")
            return "{}"
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
            HStack {
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
                HStack {
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
        HStack {
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
            HStack {
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

    // Navigation state - ensure we always default to workspace view
    @State private var navigationState: NavigationState = .workspace
    @State private var showNavigationView = true
    @State private var showInspector = false
    @State private var selectedWindow: NewWindowID? = nil
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    // Main window visibility
    @State private var isMainWindowVisible = true

    @State private var initialLoadTask: Task<Void, Never>?
    @State private var welcomeTask: Task<Void, Never>?

    var body: some View {
        // Main content area
        VStack(spacing: 0) {
            // Main content without toolbar (since it's now in the navigation bar)
            Group {
                // Always show workspace view - removed the conditional home/workspace logic
                workspaceView
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
                loadWorkspace: loadWorkspaceFromSidebar
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
                loadWorkspace: loadWorkspaceFromSidebar
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
            closeAllWindows: closeAllWindowsWithConfirmation,
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
            UnifiedImportSheet()
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

        case .notebookJSON:
            if let notebookJSON = data as? String {
                NotebookJSONSheet(notebookJSON: notebookJSON)
                    .environmentObject(sheetManager)
            } else {
                EmptyView()
            }

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

        switch type {
        case .model3d:
            windowManager.addWindowTag(nextWindowID, tag: "User-Created")
            windowManager.addWindowTag(nextWindowID, tag: "3D-Model")
        case .pointCloud:
            windowManager.addWindowTag(nextWindowID, tag: "User-Created")
            windowManager.addWindowTag(nextWindowID, tag: "Point-Cloud")
        case .dataFrame:
            windowManager.addWindowTag(nextWindowID, tag: "User-Created")
            windowManager.addWindowTag(nextWindowID, tag: "Data-Table")
        case .iotDashboard:
            windowManager.addWindowTag(nextWindowID, tag: "User-Created")
            windowManager.addWindowTag(nextWindowID, tag: "IoT-Dashboard")
        }

        #if os(visionOS)
        switch type {
        case .model3d:
            // Handle volumetric windows on visionOS
            openWindow(id: "volumetric-model3d", value: nextWindowID)
            print(" Created and opened volumetric-model3d #\(nextWindowID)")
        case .pointCloud:
            // Check if it's a demo point cloud or regular point cloud
            if windowManager.getWindow(for: nextWindowID)?.state.tags.contains("Demo-PointCloud") ?? false {
                openWindow(id: "volumetric-pointclouddemo", value: nextWindowID)
                print(" Opened volumetric-pointclouddemo for window #\(nextWindowID)")
            } else {
                openWindow(id: "volumetric-pointcloud", value: nextWindowID)
                print(" Opened volumetric-pointcloud for window #\(nextWindowID)")
            }

        case .dataFrame, .iotDashboard:
            openWindow(value: NewWindowID.ID(nextWindowID))
            print(" Created and opened regular window #\(nextWindowID)")
        }
        #else
        openWindow(value: NewWindowID.ID(nextWindowID))
        print(" Created and opened regular window #\(nextWindowID) (non-visionOS)")
        #endif

        windowManager.markWindowAsOpened(nextWindowID)
        nextWindowID += 1
    }

    private func handleWindowAction(_ action: WindowAction, windowId: Int) {
        switch action {
        case .open:
            if let window = windowManager.getWindow(for: windowId) {
                openCorrectWindowType(for: window)
            } else {
                openWindow(value: windowId)
            }
            windowManager.markWindowAsOpened(windowId)
        case .close:
            windowManager.removeWindow(windowId)
        case .focus:
            if let window = windowManager.getWindow(for: windowId) {
                openCorrectWindowType(for: window)
            } else {
                openWindow(value: windowId)
            }
        case .duplicate:
            // Create duplicate window
            let originalWindow = windowManager.getAllWindows().first { $0.id == windowId }
            if let original = originalWindow {
                let duplicateType = original.windowType.toStandardWindowType()
                createStandardWindow(duplicateType)
            }
        }
    }

    @MainActor
    private func loadWorkspaceFromSidebar(_ workspace: WorkspaceMetadata) {
        Task {
            do {
                // Load the workspace into the window manager
                let result = try await workspaceManager.loadWorkspace(
                    workspace,
                    into: windowManager,
                    clearExisting: true
                ) { id in
                    // FIXED: Open the correct window type based on the window's type
                    if let window = windowManager.getWindow(for: id) {
                        openCorrectWindowType(for: window)
                    } else {
                        // Fallback to regular window if window not found
                        openWindow(value: id)
                    }
                    windowManager.markWindowAsOpened(id)
                }
                print(" Loaded workspace: \(workspace.name) with \(result.openedWindows.count) windows")

                if windowManager.selectedProject == nil {
                    let project = Project(
                        name: workspace.name,
                        type: workspace.category.displayName,
                        icon: workspace.category.iconName,
                        color: workspace.category.color,
                        lastModified: workspace.modifiedDate,
                        visualizations: workspace.totalWindows,
                        dataPoints: 0,
                        collaborators: 1,
                        filename: workspace.fileURL?.lastPathComponent ?? ""
                    )
                    windowManager.setSelectedProject(project)
                }
            } catch {
                print(" Failed to load workspace: \(error)")
            }
        }
    }

    @MainActor
    private func openCorrectWindowType(for window: NewWindowID) {
        print(" Opening window #\(window.id) of type: \(window.windowType)")

        #if os(visionOS)
        // Handle volumetric windows on visionOS
        switch window.windowType {
        case .pointcloud:
            // Check if it's a demo point cloud or regular point cloud
            if window.state.tags.contains("Demo-PointCloud") {
                openWindow(id: "volumetric-pointclouddemo", value: window.id)
                print(" Opened volumetric-pointclouddemo for window #\(window.id)")
            } else {
                openWindow(id: "volumetric-pointcloud", value: window.id)
                print(" Opened volumetric-pointcloud for window #\(window.id)")
            }

        case .model3d:
            openWindow(id: "volumetric-model3d", value: window.id)
            print(" Opened volumetric-model3d for window #\(window.id)")

        case .charts:
            // Check if it has 3D chart data
            if window.state.chart3DData != nil {
                openWindow(id: "volumetric-chart3d", value: window.id)
                print(" Opened volumetric-chart3d for window #\(window.id)")
            } else {
                // Regular 2D window
                openWindow(value: NewWindowID.ID(window.id))
                print(" Opened regular window for 2D chart #\(window.id)")
            }

        case .column, .spatial, .volume:
            // Regular 2D windows
            openWindow(value: NewWindowID.ID(window.id))
            print(" Opened regular window #\(window.id)")
        }
        #else
        // On non-visionOS platforms, open as regular windows
        openWindow(value: NewWindowID.ID(window.id))
        print(" Opened regular window #\(window.id) (non-visionOS)")
        #endif
    }

    private func closeAllWindowsWithConfirmation() {
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

        print(" Closed and cleaned up \(allWindows.count) windows")
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

            await WorkspaceManager.shared.ensureProjectWorkspaceExists(for: project)

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
                if let notebookURL = await windowManager.createNewProjectWithNotebook(projectName: projectName) {
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

                    // Set as selected project AND ensure workspace exists
                    windowManager.setSelectedProject(newProject)

                    await WorkspaceManager.shared.ensureProjectWorkspaceExists(for: newProject)

                    print(" Created new project '\(newProject.name)' successfully")
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

    private func handleFileImport(_ fileURL: URL) {
        let fileExtension = fileURL.pathExtension.lowercased()

        let windowType: StandardWindowType
        switch fileExtension {
        case "usdz":
            windowType = .model3d
        case "ply", "pcd", "xyz", "pts":
            windowType = .pointCloud
        default:
            windowType = .dataFrame // Default fallback
        }

        createWindowForImportedFile(windowType, fileURL: fileURL)

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

        openWindow(value: newWindowID)
        windowManager.markWindowAsOpened(newWindowID)

        print(" Imported file: \(fileURL.lastPathComponent) as \(type.displayName)")
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
                    ContentUnavailableView(
                        "No Active Views",
                        systemImage: "rectangle.dashed",
                        description: Text("Create a new view using the options above")
                    )
                } else {
                    VStack(alignment: .leading, spacing: 20) {
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
                // Show main projects list as data table rows
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Recent Projects")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 12)

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
                            // Simple data table style list with consistent row heights
                            VStack(spacing: 1) {
                                ForEach(workspaceManager.getCustomWorkspaces()) { workspace in
                                    Button(action: {
                                        selectedWorkspace = workspace
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            showingProjectDetail = true
                                        }
                                    }) {
                                        HStack {
                                            // Project name (removed folder icon)
                                            Text(workspace.name)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                            // Windows count
                                            Text("\(workspace.totalWindows) views")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .frame(width: 80, alignment: .trailing)

                                            // Last modified
                                            Text(workspace.formattedModifiedDate)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .frame(width: 100, alignment: .trailing)

                                            // Chevron
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10) // Standardized padding for consistent height
                                        .frame(height: 44) // Fixed height for all rows
                                    }
                                    .buttonStyle(.plain)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(.vertical, 8)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Created")
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
                .fill(.blue.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                }
        }
        .scaleEffect(1.01)
        .animation(.easeInOut(duration: 0.15))
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Project Detail View
struct ProjectDetailView: View {
    let workspace: WorkspaceMetadata
    let onBack: () -> Void
    let onLoad: () -> Void

    var body: some View {
        VStack(spacing: 0) {
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

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
                    VStack(alignment: .leading, spacing: 16) {
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

        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Notebook JSON Sheet
struct NotebookJSONSheet: View {
    let notebookJSON: String
    @EnvironmentObject var sheetManager: SheetManager
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Loading notebook...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        
                        Text("Error loading notebook")
                            .font(.title2)
                        
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Close") {
                            sheetManager.dismissSheet()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    VStack {
                        TextEditor(text: .constant(notebookJSON))
                            .font(.system(.body, design: .monospaced))
                            .frame(minWidth: 600, minHeight: 500)
                            .padding(4)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        HStack {
                            Spacer()
                            
                            Button("Copy to Clipboard") {
                                copyToClipboard()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Save to File") {
                                saveToFile()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .navigationTitle("Notebook JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        sheetManager.dismissSheet()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 800, height: 600)
    }
    
    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(notebookJSON, forType: .string)
        #else
        UIPasteboard.general.string = notebookJSON
        #endif
    }
    
    private func saveToFile() {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Notebook JSON"
        panel.allowedContentTypes = [.json]
        
        Task { @MainActor in
            if panel.runModal() == .OK, let url = panel.url {
                do {
                    try notebookJSON.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Error saving file: \(error)")
                }
            }
        }
        #else
        copyToClipboard()
        #endif
    }
}

// MARK: - Sheet Wrapper Views

struct WorkspaceDialogWrapper: View {
    let windowManager: WindowTypeManager
    @EnvironmentObject var sheetManager: SheetManager

    var body: some View {
        WorkspaceDialog(
            isPresented: Binding(
                get: { true },
                set: { _ in sheetManager.dismissSheet() }
            ),
            onSave: { name, description, category, isTemplate, tags in
                Task {
                    do {
                        let workspace = try await WorkspaceManager.shared.createNewWorkspace(
                            name: name,
                            description: description,
                            category: category,
                            tags: tags,
                            windowManager: windowManager
                        )
                        print(" Created workspace: \(workspace.name)")
                        await MainActor.run {
                            sheetManager.dismissSheet()
                        }
                    } catch {
                        print(" Failed to create workspace: \(error)")
                    }
                }
            }
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SettingsSection("Workspace") {
                            Toggle("Auto-save after every window action", isOn: .constant(true))
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("Automatically saves your workspace configuration after any window is created, moved, or modified")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                        }

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

// MARK: - Preview
struct EnvironmentView_Previews: PreviewProvider {
    static var previews: some View { EnvironmentView() }
}
