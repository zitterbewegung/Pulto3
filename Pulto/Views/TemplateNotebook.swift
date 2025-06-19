//
//  TemplateNotebook.swift
//  Pulto
//
//  Updated for visionOS 2.4 (Xcode 16.4 SDK)
//

import SwiftUI
import Foundation

// MARK: - ExportTemplate helper (enum itself lives elsewhere)
extension ExportTemplate {
    /// Safe String → Enum conversion
    static func from(_ raw: String) -> ExportTemplate? {
        ExportTemplate(rawValue: raw)
    }
}

// MARK: - Template Notebook (root view)
struct TemplateNotebook: View {

    // State & environment
    @State private var selectedCellIndex: Int? = nil
    @State private var isLoading            = true
    @State private var errorMessage: String?
    @State private var showImportConfirmation = false
    @State private var templateWindows: [TemplateWindow] = []

    @Environment(\.dismiss)      private var dismiss
    @Environment(\.openWindow)   private var openWindow
    @StateObject private var windowManager = WindowTypeManager.shared

    // Template-window model
    struct TemplateWindow: Identifiable, Hashable {
        let id = UUID()
        let windowId: Int
        let windowType: String
        let exportTemplate: String
        let tags: [String]
        let position: WindowPosition
        let content: String
        let title: String
    }

    // MARK: UI
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading                     { loadingView }
                else if let err = errorMessage   { errorView(err) }
                else if !templateWindows.isEmpty { templateContentView }
                else                             { emptyStateView }
            }
            .navigationTitle("Template Gallery")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import All") { showImportConfirmation = true }
                        .disabled(templateWindows.isEmpty)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .task { loadTemplateWindows() }
        .alert("Import Template", isPresented: $showImportConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Import") { importAllWindows() }
        } message: {
            Text("This will create \(templateWindows.count) new windows in your workspace.")
        }
    }
}

// MARK: - Content sub-views
private extension TemplateNotebook {

    // ---------- States ----------
    var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.5)
            Text("Loading template…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            Text("Failed to Load Template")
                .font(.title2).fontWeight(.semibold)
            Text(error)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button("Try Again") { loadTemplateWindows() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Template Found")
                .font(.title2).fontWeight(.semibold)
            Text("The template file could not be found.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ---------- Main HSplit ----------
    var templateContentView: some View {
        HStack(spacing: 0) {
            windowListView
                .frame(width: 350)
                .background(Color(.systemBackground).opacity(0.95))

            Divider()

            if let idx = selectedCellIndex, idx < templateWindows.count {
                windowPreviewView(templateWindows[idx])
            } else {
                templateOverviewView
            }
        }
    }

    // ---------- Sidebar list ----------
    var windowListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Template Windows")
                    .font(.title2).fontWeight(.semibold)
                Label("\(templateWindows.count) windows",
                      systemImage: "square.stack.3d")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(templateWindows.enumerated()), id: \.element.id) { index, win in
                        TemplatesWindowRowView(
                            window: win,
                            isSelected: selectedCellIndex == index
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCellIndex = index
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    // ---------- Overview ----------
    var templateOverviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 16) {
                    Text("VisionOS Spatial Computing Template")
                        .font(.largeTitle).fontWeight(.bold)
                    Text("A comprehensive template demonstrating spatial data-visualization capabilities.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)

                metadataSection
                previewGridSection

                VStack {
                    Button {
                        showImportConfirmation = true
                    } label: {
                        Label("Import All Windows", systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 40)

                    Text("Creates \(templateWindows.count) windows in your workspace.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 32)
            }
        }
    }

    var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Template Information")
                .font(.title2).fontWeight(.semibold)

            let uniqueTypes     = Set(templateWindows.map { $0.windowType }).count
            let uniqueTags      = Set(templateWindows.flatMap { $0.tags }).count
            let uniqueTemplates = Set(templateWindows.map { $0.exportTemplate }).count

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)],
                      spacing: 16) {
                MetadataCard(icon: "square.stack.3d", title: "Windows",
                             value: "\(templateWindows.count)", color: .blue)
                MetadataCard(icon: "tag", title: "Tags",
                             value: "\(uniqueTags)", color: .green)
                MetadataCard(icon: "doc.text", title: "Templates",
                             value: "\(uniqueTemplates)", color: .orange)
                MetadataCard(icon: "cube", title: "Window Types",
                             value: "\(uniqueTypes)", color: .purple)
            }
        }
        .padding(.horizontal, 40)
    }

    var previewGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Window Previews")
                .font(.title2).fontWeight(.semibold)
                .padding(.horizontal, 40)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(templateWindows) { win in
                        WindowPreviewCard(window: win) {
                            if let idx = templateWindows.firstIndex(of: win) {
                                selectedCellIndex = idx
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }

    // ---------- Single-window preview ----------
    func windowPreviewView(_ win: TemplateWindow) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(win.windowType,
                              systemImage: iconForWindowType(win.windowType))
                            .font(.title2).fontWeight(.semibold)
                        Spacer()
                        Text("Window #\(win.windowId)")
                            .foregroundStyle(.secondary)
                    }

                    Label(win.exportTemplate, systemImage: "doc.text")
                        .foregroundStyle(.secondary)

                    if !win.tags.isEmpty {
                        HStack {
                            ForEach(win.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(.horizontal, 40).padding(.top, 32)

                Divider().padding(.horizontal, 40)

                positionInfoView(win.position)
                contentPreviewView(win)

                Button {
                    importSingleWindow(win)
                } label: {
                    Label("Import This Window", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40).padding(.bottom, 32)
            }
        }
    }

    func positionInfoView(_ pos: WindowPosition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Position & Size").font(.headline)
            HStack(spacing: 24) {
                Label("X: \(Int(pos.x))", systemImage: "arrow.left.and.right")
                Label("Y: \(Int(pos.y))", systemImage: "arrow.up.and.down")
                Label("Z: \(Int(pos.z))", systemImage: "move.3d")
                Spacer()
                Label("\(Int(pos.width)) × \(Int(pos.height))",
                      systemImage: "aspectratio")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 40)
    }

    func contentPreviewView(_ win: TemplateWindow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Content Preview").font(.headline)
            ScrollView {
                Text(win.content)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxHeight: 300)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Data / window-creation helpers
private extension TemplateNotebook {

    func loadTemplateWindows() {
        isLoading = true
        errorMessage = nil

        templateWindows = sampleTemplateWindows()
        selectedCellIndex = templateWindows.isEmpty ? nil : 0
        isLoading = false
    }

    func sampleTemplateWindows() -> [TemplateWindow] {
        [
            TemplateWindow(windowId: 1001, windowType: "Spatial Editor",
                           exportTemplate: "Markdown Only",
                           tags: ["introduction", "spatial"],
                           position: .init(x: -150, y: 100, z: -50,
                                           width: 500, height: 300),
                           content: "# VisionOS Spatial Computing Notebook\n…",
                           title: "Introduction"),
            TemplateWindow(windowId: 1002, windowType: "Charts",
                           exportTemplate: "Matplotlib Chart",
                           tags: ["visualization", "matplotlib", "data"],
                           position: .init(x: 200, y: 50, z: 0,
                                           width: 600, height: 450),
                           content: "# Interactive Data Visualization\n…",
                           title: "Data Visualization"),
            TemplateWindow(windowId: 1003, windowType: "DataFrame Viewer",
                           exportTemplate: "Pandas DataFrame",
                           tags: ["data", "pandas", "analysis"],
                           position: .init(x: -100, y: -150, z: 25,
                                           width: 700, height: 400),
                           content: "# Spatial Data Table Analysis\n…",
                           title: "Data Analysis"),
            TemplateWindow(windowId: 1004, windowType: "Spatial Editor",
                           exportTemplate: "Custom Code",
                           tags: ["3d", "visualization", "interactive"],
                           position: .init(x: 300, y: -100, z: 75,
                                           width: 550, height: 450),
                           content: "# 3D Spatial Visualization & Point-Cloud\n…",
                           title: "3D Visualization"),
            TemplateWindow(windowId: 1005, windowType: "Model Metric Viewer",
                           exportTemplate: "NumPy Array",
                           tags: ["metrics", "performance", "monitoring"],
                           position: .init(x: -50, y: 200, z: 50,
                                           width: 500, height: 350),
                           content: "# Model Performance Metrics\n…",
                           title: "Performance Metrics")
        ]
    }

    func importAllWindows() {
        templateWindows.forEach(importWindow)
        dismiss()
    }

    func importSingleWindow(_ win: TemplateWindow) {
        importWindow(win)
        dismiss()
    }

    func importWindow(_ win: TemplateWindow) {
        // Resolve the WindowType used by the rest of the app
        let wType: WindowType = {
            switch win.windowType {
            case "Charts":              return .charts
            case "Spatial Editor":      return .spatial
            case "DataFrame Viewer":    return .column
            //case "Model Metric Viewer": return .volume
            default:                    return .spatial
            }
        }()

        var state = WindowState()

        // Convert raw String → ExportTemplate
        if let tpl = ExportTemplate.from(win.exportTemplate) {
            state.exportTemplate = tpl
        }

        state.content = win.content
        state.tags    = win.tags

        // Create / update the window
        _ = windowManager.createWindow(wType, id: win.windowId,
                                       position: win.position)
        windowManager.updateWindowState(win.windowId, state: state)

        // Bring it on-screen (visionOS 2 style)
        //openWindow(id: wType.sceneID)
    }

    func iconForWindowType(_ type: String) -> String {
        switch type {
        case "Charts":              return "chart.line.uptrend.xyaxis"
        case "Spatial Editor":      return "cube"
        case "DataFrame Viewer":    return "tablecells"
        case "Model Metric Viewer": return "gauge"
        default:                    return "square.stack.3d"
        }
    }
}

// MARK: - Supporting components
/// Row inside the sidebar
struct TemplatesWindowRowView: View {
    let window: TemplateNotebook.TemplateWindow
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {

                Image(systemName: iconForWindowType(window.windowType))
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : Color.accentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(window.windowType)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .white : .primary)

                    Text(window.exportTemplate)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)

                    Text("Window #\(window.windowId)")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.6) : .secondary)
                }

                Spacer()

                if !window.tags.isEmpty {
                    Label("\(window.tags.count)", systemImage: "tag")
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor
                                   : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func iconForWindowType(_ type: String) -> String {
        switch type {
        case "Charts":              return "chart.line.uptrend.xyaxis"
        case "Spatial Editor":      return "cube"
        case "DataFrame Viewer":    return "tablecells"
        case "Model Metric Viewer": return "gauge"
        default:                    return "square.stack.3d"
        }
    }
}

/// Small info card
struct MetadataCard: View {
    let icon, title, value: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.title2).fontWeight(.semibold)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Horizontal preview card
struct WindowPreviewCard: View {
    let window: TemplateNotebook.TemplateWindow
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: iconForWindowType(window.windowType))
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    Text("#\(window.windowId)")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Text(window.windowType).font(.headline).lineLimit(1)
                Text(window.exportTemplate)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text(window.content)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(3)

                Spacer()

                if !window.tags.isEmpty {
                    HStack {
                        Image(systemName: "tag").font(.caption)
                        Text(window.tags.prefix(2).joined(separator: ", "))
                            .font(.caption).lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(width: 250, height: 200)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }

    private func iconForWindowType(_ type: String) -> String {
        switch type {
        case "Charts":              return "chart.line.uptrend.xyaxis"
        case "Spatial Editor":      return "cube"
        case "DataFrame Viewer":    return "tablecells"
        case "Model Metric Viewer": return "gauge"
        default:                    return "square.stack.3d"
        }
    }
}

// MARK: - Canvas preview
#Preview("Template Notebook") {
    TemplateNotebook()
        .frame(width: 1000, height: 700)
}
