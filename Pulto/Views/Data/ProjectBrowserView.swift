//
//  ProjectBrowserView.swift
//  Pulto
//
//  Created by AI Assistant on 1/4/25.
//  Copyright 2025 Apple. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

private enum FeatureFlags {
    static var jupyterLiteEnabled: Bool {
        if let v = UserDefaults.standard.object(forKey: "feature.jupyterlite") as? Bool { return v }
        return true // default enabled
    }
    static var templatesEnabled: Bool {
        if let v = UserDefaults.standard.object(forKey: "feature.templates") as? Bool { return v }
        return true // default enabled
    }
}

struct ProjectBrowserView: View {
    @ObservedObject var windowManager: WindowTypeManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    
    @State private var availableProjects: [NotebookFile] = []
    @State private var selectedProject: NotebookFile?
    @State private var isLoading = true
    @State private var showingFilePicker = false
    @State private var showingRestoreDialog = false
    @State private var errorMessage: String?

    // Remote Jupyter integration
    @StateObject private var jupyterClient = JupyterAPIClient()
    @State private var remoteProjects: [NotebookFile] = []
    @State private var isLoadingRemote = false
    @State private var remoteError: String?
    @State private var showingJupyterLiteSheet = false
    @State private var showingTemplatesSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                CurvedWindowBackground()
                
                VStack(spacing: 20) {
                    headerView
                    
                    if isLoading {
                        loadingView
                    } else if availableProjects.isEmpty {
                        emptyStateView
                    } else {
                        projectsListView
                    }
                    
                    // Remote projects section
                    remoteProjectsSection
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("Browse Files") {
                            showingFilePicker = true
                        }
                        .buttonStyle(CurvedButtonStyle())
                        
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(CurvedButtonStyle(variant: .secondary))
                        
                        if FeatureFlags.templatesEnabled {
                            Button("Templates") {
                                showingTemplatesSheet = true
                            }
                            .buttonStyle(CurvedButtonStyle())
                        }
                        
                        if FeatureFlags.jupyterLiteEnabled && !hasRemoteSettings() {
                            Button("Set Remote") {
                                showingJupyterLiteSheet = true
                            }
                            .buttonStyle(CurvedButtonStyle())
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType(filenameExtension: "ipynb") ?? .json],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .sheet(isPresented: $showingRestoreDialog) {
                if let project = selectedProject {
                    NavigationView {
                        EnvironmentRestoreDialog(
                            isPresented: $showingRestoreDialog,
                            windowManager: windowManager
                        ) { restoreResult in
                            handleProjectRestoration(restoreResult)
                        }
                        .onAppear {
                            // Pre-select the chosen project
                            // This would require modifying EnvironmentRestoreDialog to accept a file
                        }
                    }
                }
            }
            .sheet(isPresented: $showingJupyterLiteSheet) {
                JupyterLiteWindow()
                    .interactiveDismissDisabled(true)
            }
            .sheet(isPresented: $showingTemplatesSheet) {
                TemplatesSheet()
            }
        }
        .onAppear {
            loadAvailableProjects()
            connectAndLoadRemote()
        }
    }
    
    private var headerView: some View {
        CurvedWindow {
            VStack(spacing: 16) {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)
                
                Text("Open Existing Project")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text("Choose a saved workspace to continue working")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(30)
        }
    }
    
    private var loadingView: some View {
        CurvedWindow {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Scanning for projects...")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        }
    }
    
    private var emptyStateView: some View {
        CurvedWindow {
            VStack(spacing: 24) {
                Image(systemName: "folder")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.bounce)
                
                VStack(spacing: 12) {
                    Text("No Projects Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("No saved workspace files were found in your Documents folder. Create a new project or browse for files from another location.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                }
                
                VStack(spacing: 16) {
                    Button("Browse for Files") {
                        showingFilePicker = true
                    }
                    .buttonStyle(CurvedButtonStyle(variant: .primary))
                    .controlSize(.large)
                    
                    Button("Create New Project") {
                        dismiss()
                        openWindow(id: "main")
                    }
                    .buttonStyle(CurvedButtonStyle(variant: .secondary))
                }
            }
            .padding(40)
        }
    }
    
    private var projectsListView: some View {
        CurvedWindow {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Available Projects")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Text("\(availableProjects.count) project\(availableProjects.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let error = errorMessage {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.bottom, 8)
                }
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(availableProjects) { project in
                            ProjectRowView(project: project) {
                                openProject(project)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(24)
        }
    }
    
    private var remoteProjectsSection: some View {
        Group {
            if isLoadingRemote {
                CurvedWindow {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Connecting to remote Jupyter…")
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                }
            } else if let remoteError {
                CurvedWindow {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Remote Jupyter", systemImage: "server.rack")
                            .font(.headline)
                        Text(remoteError)
                            .font(.caption)
                            .foregroundStyle(.red)
                        Button("Retry") { connectAndLoadRemote() }
                            .buttonStyle(CurvedButtonStyle())
                    }
                    .padding(20)
                }
            } else if !remoteProjects.isEmpty {
                CurvedWindow {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("Remote Projects", systemImage: "server.rack")
                                .font(.title3).fontWeight(.semibold)
                            Spacer()
                            Button("Refresh") { connectAndLoadRemote(force: true) }
                                .buttonStyle(CurvedButtonStyle())
                        }
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(remoteProjects) { project in
                                    ProjectRowView(project: project) {
                                        openRemoteProject(project)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
    
    private func loadAvailableProjects() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let projects = try await scanForProjects()
                
                await MainActor.run {
                    self.availableProjects = projects.sorted { $0.modifiedDate > $1.modifiedDate }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.availableProjects = []
                    self.isLoading = false
                }
            }
        }
    }
    
    private func scanForProjects() async throws -> [NotebookFile] {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ProjectBrowserError.documentsNotFound
        }
        
        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .nameKey]
        
        guard let enumerator = fileManager.enumerator(
            at: documentsDirectory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return []
        }
        
        var projects: [NotebookFile] = []
        
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "ipynb" else { continue }
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                
                let project = NotebookFile(
                    url: fileURL,
                    name: resourceValues.name ?? fileURL.lastPathComponent,
                    size: Int64(resourceValues.fileSize ?? 0),
                    createdDate: resourceValues.creationDate ?? Date(),
                    modifiedDate: resourceValues.contentModificationDate ?? Date()
                )
                
                projects.append(project)
            } catch {
                print("Error reading file attributes for \(fileURL): \(error)")
            }
        }
        
        return projects
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            openProjectFromURL(url)
            
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    private func openProject(_ project: NotebookFile) {
        openProjectFromURL(project.url)
    }
    
    private func openProjectFromURL(_ url: URL) {
        Task {
            do {
                let restoreResult = try await windowManager.importAndRestoreEnvironment(
                    fileURL: url,
                    clearExisting: true
                ) { windowID in
                    DispatchQueue.main.async {
                        openWindow(value: windowID)
                    }
                }
                
                await MainActor.run {
                    handleProjectRestoration(restoreResult)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to open project: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func handleProjectRestoration(_ result: EnvironmentRestoreResult) {
        if result.isFullySuccessful {
            dismiss()
            openWindow(id: "main")
        } else {
            errorMessage = result.summary
        }
    }

    private func hasRemoteSettings() -> Bool {
        if let s = UserDefaults.standard.string(forKey: "remoteJupyter.baseURL") {
            return !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }

    private func loadRemoteServerConfig() -> JupyterServerConfig? {
        let defaults = UserDefaults.standard
        guard let url = defaults.string(forKey: "remoteJupyter.baseURL"),
              !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let token = defaults.string(forKey: "remoteJupyter.token")
        let name = defaults.string(forKey: "remoteJupyter.name") ?? url
        return JupyterServerConfig(baseURL: url, token: token, name: name)
    }

    private func connectAndLoadRemote(force: Bool = false) {
        guard let serverConfig = loadRemoteServerConfig() else { return }
        if jupyterClient.isConnected && !force { return }
        isLoadingRemote = true
        remoteError = nil
        Task { @MainActor in
            await jupyterClient.connect(to: serverConfig)
            if jupyterClient.isConnected {
                do {
                    let notebooks = try await jupyterClient.listNotebooks()
                    self.remoteProjects = notebooks.compactMap { jupyterClient.convertToNotebookFile($0) }
                        .sorted { $0.modifiedDate > $1.modifiedDate }
                    self.remoteError = nil
                } catch {
                    self.remoteError = error.localizedDescription
                    self.remoteProjects = []
                }
            } else {
                self.remoteError = jupyterClient.connectionError
            }
            self.isLoadingRemote = false
        }
    }

    private func openRemoteProject(_ project: NotebookFile) {
        // Remote projects are represented as temp files; reuse local open logic
        openProjectFromURL(project.url)
    }
}

// MARK: - Curved Window Components

struct CurvedWindow<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct CurvedWindowBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15).opacity(0.8),
                        Color(red: 0.1, green: 0.1, blue: 0.2).opacity(0.6),
                        Color(red: 0.15, green: 0.15, blue: 0.25).opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                ForEach(0..<8, id: \.self) { index in
                    FloatingShape(
                        index: index,
                        geometry: geometry
                    )
                }
                
                MeshGradientOverlay()
            }
            .ignoresSafeArea()
        }
    }
}

struct FloatingShape: View {
    let index: Int
    let geometry: GeometryProxy
    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    
    var body: some View {
        let size = CGFloat.random(in: 40...120)
        let opacity = Double.random(in: 0.1...0.3)
        
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: size, height: size)
            .blur(radius: 20)
            .opacity(opacity)
            .offset(offset)
            .rotationEffect(.degrees(rotation))
            .position(
                x: CGFloat.random(in: 0...geometry.size.width),
                y: CGFloat.random(in: 0...geometry.size.height)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: Double.random(in: 15...25))
                    .repeatForever(autoreverses: true)
                ) {
                    offset = CGSize(
                        width: CGFloat.random(in: -100...100),
                        height: CGFloat.random(in: -100...100)
                    )
                    rotation = Double.random(in: 0...360)
                }
            }
    }
}

struct MeshGradientOverlay: View {
    var body: some View {
        Rectangle()
            .fill(
                RadialGradient(
                    colors: [
                        .clear,
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.05),
                        .clear
                    ],
                    center: .center,
                    startRadius: 100,
                    endRadius: 400
                )
            )
            .blur(radius: 30)
            .opacity(0.6)
    }
}

// MARK: - Curved Button Style

struct CurvedButtonStyle: ButtonStyle {
    enum Variant {
        case primary, secondary, tertiary
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return .clear
            case .tertiary: return .clear
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .blue
            case .tertiary: return .secondary
            }
        }
        
        var borderColor: Color {
            switch self {
            case .primary: return .clear
            case .secondary: return .blue
            case .tertiary: return .secondary
            }
        }
    }
    
    let variant: Variant
    
    init(variant: Variant = .primary) {
        self.variant = variant
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .medium))
            .foregroundStyle(variant.foregroundColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(variant.backgroundColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(variant.borderColor, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ProjectRowView: View {
    let project: NotebookFile
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: "doc.text.fill")
                    .font(.title)
                    .foregroundStyle(.blue)
                    .frame(width: 50, height: 50)
                    .background {
                        Circle()
                            .fill(.blue.opacity(0.1))
                    }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 20) {
                        Label(project.formattedSize, systemImage: "doc")
                            .font(.caption)
                        
                        Label(project.formattedModifiedDate, systemImage: "clock")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    
                    Text(project.url.path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .symbolEffect(.bounce, value: isHovered)
                    
                    Text("Open")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .fontWeight(.medium)
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(isHovered ? 0.3 : 0.1), lineWidth: isHovered ? 2 : 1)
                    }
                    .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 12 : 6, x: 0, y: isHovered ? 6 : 3)
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
        }
        .buttonStyle(.plain)
    }
}

enum ProjectBrowserError: LocalizedError {
    case documentsNotFound
    case scanningFailed
    
    var errorDescription: String? {
        switch self {
        case .documentsNotFound:
            return "Could not access Documents folder"
        case .scanningFailed:
            return "Failed to scan for project files"
        }
    }
}

private struct TemplatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                Text("Templates")
                    .font(.title2).fontWeight(.semibold)
                Text("Browse and create from project templates. (Placeholder)")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Close") { dismiss() }
                    .buttonStyle(CurvedButtonStyle())
                    .padding(.top, 12)
                Spacer()
            }
            .padding()
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview
#Preview {
    ProjectBrowserView(windowManager: WindowTypeManager.shared)
}
