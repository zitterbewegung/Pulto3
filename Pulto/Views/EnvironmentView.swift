//
//  OpenWindowView 2.swift
//  Pulto
//
//  Created by Joshua Herman on 6/24/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

// MARK: - Design System Constants
struct DesignSystem {
    // Spacing
    static let spacing = (
        xs: CGFloat(4),
        sm: CGFloat(8),
        md: CGFloat(12),
        lg: CGFloat(16),
        xl: CGFloat(20),
        xxl: CGFloat(24),
        xxxl: CGFloat(32)
    )

    // Padding
    static let padding = (
        xs: CGFloat(4),
        sm: CGFloat(8),
        md: CGFloat(12),
        lg: CGFloat(16),
        xl: CGFloat(20),
        xxl: CGFloat(24)
    )

    // Corner Radius
    static let cornerRadius = (
        sm: CGFloat(6),
        md: CGFloat(8),
        lg: CGFloat(12),
        xl: CGFloat(16)
    )

    // Shadows
    static let shadow = (
        sm: (radius: CGFloat(4), opacity: 0.05),
        md: (radius: CGFloat(8), opacity: 0.08),
        lg: (radius: CGFloat(12), opacity: 0.10)
    )

    // Icon Sizes
    static let iconSize = (
        sm: CGFloat(16),
        md: CGFloat(20),
        lg: CGFloat(24),
        xl: CGFloat(32),
        xxl: CGFloat(40)
    )

    // Button Heights
    static let buttonHeight = (
        sm: CGFloat(36),
        md: CGFloat(44),
        lg: CGFloat(60),
        xl: CGFloat(80)
    )

    // Card Heights
    static let cardHeight = (
        sm: CGFloat(80),
        md: CGFloat(120),
        lg: CGFloat(140),
        xl: CGFloat(160)
    )
}

// MARK: - Custom View Modifiers
struct CardStyle: ViewModifier {
    var isSelected: Bool = false
    var isHovering: Bool = false

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .shadow(
                color: .black.opacity(DesignSystem.shadow.md.opacity),
                radius: DesignSystem.shadow.md.radius,
                x: 0,
                y: 4
            )
    }
}

extension View {
    func cardStyle(isSelected: Bool = false) -> some View {
        self.modifier(CardStyle(isSelected: isSelected))
    }
}

// MARK: - Optimized OpenWindowView with Consistent Design

struct EnvironmentView: View {
    @State var nextWindowID = 1
    @Environment(\.openWindow) private var openWindow
    @StateObject private var windowManager = WindowTypeManager.shared
    @State private var showExportSidebar = false
    @State private var showImportDialog = false
    @State private var showTemplateGallery = false
    @State private var selectedWindowType: WindowType?
    @State private var hoveredWindowType: WindowType?

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Main content with adaptive layout
                ScrollView {
                    LazyVStack(spacing: DesignSystem.spacing.xxl) {
                        headerSection
                            // Narrow layout: stacked
                            VStack(spacing: DesignSystem.spacing.xxl) {
                                quickActionsSection
                                windowTypeSection
                                if !windowManager.getAllWindows().isEmpty {
                                    activeWindowsSection
                                }

                        }
                    }
                    .padding(DesignSystem.padding.xxl)
                    .frame(minWidth: 700)
                }
                .frame(maxWidth: .infinity)

                // Enhanced export sidebar with smooth animation
                if showExportSidebar {
                    ExportConfigurationSidebar()
                        .frame(width: 380)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.2), value: showExportSidebar)
        }
        .frame(minHeight: 1200)
        .background(Color(.systemBackground))
        .sheet(isPresented: $showImportDialog) {
            NotebookImportDialog(
                isPresented: $showImportDialog,
                windowManager: windowManager
            )
        }
        .sheet(isPresented: $showTemplateGallery) {
            TemplateView()
                .frame(minWidth: 1200, minHeight: 700)
        }
    }

    // MARK: - Enhanced View Components

    private var headerSection: some View {
        HStack(alignment: .center, spacing: DesignSystem.spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.spacing.sm) {
                Text("VisionOS Workspace")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Create, manage, and orchestrate your 3D computational environment")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
            }

            Spacer()

            // Quick status indicator
            HStack(spacing: DesignSystem.spacing.md) {
                WindowCountIndicator(
                    count: windowManager.getAllWindows().count
                )
                
                //CircularButton(
                //    icon: showExportSidebar ? "sidebar.trailing" : "gearshape",
                //    action: { showExportSidebar.toggle() }
                //)
            }
        }
        .padding(.bottom, DesignSystem.padding.md)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing.lg) {
            SectionHeader(
                title: "Workspace Management",
                subtitle: "Save, load, and manage your 3D workspace configuration",
                icon: "folder.badge.gearshape"
            )

            // Primary action cards
            HStack(spacing: DesignSystem.spacing.md) {
                PrimaryActionCard(
                    title: "Save Workspace",
                    subtitle: "Export current configuration",
                    icon: "square.and.arrow.up.fill",
                    action: exportToJupyter,
                    style: .prominent
                )

                PrimaryActionCard(
                    title: "Template Gallery",
                    subtitle: "Browse pre-built workspaces",
                    icon: "cube.box.fill",
                    action: { showTemplateGallery = true },
                    style: .secondary
                )
            }

            // Secondary actions grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.spacing.md), count: 3),
                spacing: DesignSystem.spacing.md
            ) {
                SecondaryActionButton(
                    title: "Import",
                    icon: "square.and.arrow.down",
                    action: { showImportDialog = true }
                )

                SecondaryActionButton(
                    title: "Demo",
                    icon: "doc.badge.plus",
                    action: createSampleWorkspace
                )

                SecondaryActionButton(
                    title: "Clear All",
                    icon: "trash",
                    action: clearAllWindowsWithConfirmation,
                    isDestructive: true
                )
            }
        }
        .padding(DesignSystem.padding.xl)
        .cardStyle()
    }

    private var windowTypeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing.lg) {
            SectionHeader(
                title: "Create New Window",
                subtitle: "Choose a window type to add to your workspace",
                icon: "plus.rectangle.on.folder"
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DesignSystem.spacing.md),
                    GridItem(.flexible(), spacing: DesignSystem.spacing.md)
                ],
                spacing: DesignSystem.spacing.md
            ) {
                ForEach(WindowType.allCases, id: \.self) { windowType in
                    WindowTypeCard(
                        windowType: windowType,
                        isSelected: selectedWindowType == windowType,
                        isHovered: hoveredWindowType == windowType,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedWindowType = windowType
                                createWindow(type: windowType)
                            }
                        }
                    )
                    .onHover { hovering in
                        hoveredWindowType = hovering ? windowType : nil
                    }
                }
            }
        }
        .padding(DesignSystem.padding.xl)
        .cardStyle()
    }

    private var activeWindowsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing.lg) {
            HStack {
                SectionHeader(
                    title: "Active Windows",
                    subtitle: "\(windowManager.getAllWindows().count) window\(windowManager.getAllWindows().count == 1 ? "" : "s") currently open",
                    icon: "rectangle.3.group"
                )

                Spacer()

                Button("Close All") {
                    clearAllWindowsWithConfirmation()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.red)
                .fontWeight(.medium)
            }

            if windowManager.getAllWindows().isEmpty {
                EmptyStateView()
            } else {
                activeWindowsList
            }
        }
        .padding(DesignSystem.padding.xl)
        .cardStyle()
    }

    private var activeWindowsList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.spacing.sm) {
                ForEach(windowManager.getAllWindows(), id: \.id) { window in
                    HStack(spacing: DesignSystem.spacing.lg) {
                        // Window type indicator
                        IconBadge(icon: iconForWindowType(window.windowType))
                            .scaleEffect(0.8)

                        // Window info
                        VStack(alignment: .leading, spacing: DesignSystem.spacing.xs) {
                            Text(window.windowType.displayName)
                                .font(.headline)
                                .fontWeight(.medium)

                            HStack(spacing: DesignSystem.spacing.md) {
                                Label("ID: #\(window.id)", systemImage: "number")
                                    .font(.caption2)

                                Label("\(window.state.exportTemplate.rawValue)", systemImage: "doc.text")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Position badge
                        PositionBadge(position: window.position)

                        // Action buttons
                        HStack(spacing: DesignSystem.spacing.sm) {
                            CircularButton(
                                icon: "arrow.up.left.and.arrow.down.right",
                                action: { openWindow(value: window.id) }
                            )
                            .scaleEffect(0.8)

                            CircularButton(
                                icon: "xmark.circle.fill",
                                action: { windowManager.removeWindow(window.id) }
                            )
                            .scaleEffect(0.8)
                            .foregroundStyle(.red)
                        }
                    }
                    .padding(DesignSystem.padding.md)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.md)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                    )
                }
            }
        }
        .frame(maxHeight: 300)
    }

    // MARK: - Helper Functions

    private func createWindow(type: WindowType) {
        let position = WindowPosition(
            x: Double.random(in: -200...200),
            y: Double.random(in: -100...100),
            z: Double.random(in: -50...50),
            width: 600,
            height: 450
        )

        _ = windowManager.createWindow(type, id: nextWindowID, position: position)
        openWindow(value: nextWindowID)
        nextWindowID += 1

        // Reset selection after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            selectedWindowType = nil
        }
    }

    private func exportToJupyter() {
        if let fileURL = windowManager.saveNotebookToFile() {
            print("✅ Workspace saved to: \(fileURL.path)")
        }
    }

    private func createSampleWorkspace() {
        let windowTypes: [WindowType] = [.charts, .spatial, .column, .volume]

        for (index, type) in windowTypes.enumerated() {
            let position = WindowPosition(
                x: Double(index * 150 - 150),
                y: Double(index * 75),
                z: Double(index * 50),
                width: 500,
                height: 400
            )

            _ = windowManager.createWindow(type, id: nextWindowID, position: position)

            switch type {
            case .charts:
                windowManager.updateWindowContent(nextWindowID, content: """
                # Sample Chart
                plt.figure(figsize=(10, 6))
                x = np.linspace(0, 10, 100)
                y = np.sin(x)
                plt.plot(x, y)
                plt.title('Sample Sine Wave')
                plt.show()
                """)
                windowManager.updateWindowTemplate(nextWindowID, template: .matplotlib)

            case .spatial:
                let samplePointCloud = PointCloudDemo.generateSpherePointCloudData(radius: 5.0, points: 500)
                windowManager.updateWindowPointCloud(nextWindowID, pointCloud: samplePointCloud)

            case .column:
                let sampleDataFrame = DataFrameData(
                    columns: ["Name", "Value", "Category"],
                    rows: [
                        ["Sample A", "100", "Type 1"],
                        ["Sample B", "200", "Type 2"],
                        ["Sample C", "150", "Type 1"]
                    ],
                    dtypes: ["Name": "string", "Value": "int", "Category": "string"]
                )
                windowManager.updateWindowDataFrame(nextWindowID, dataFrame: sampleDataFrame)
                windowManager.updateWindowTemplate(nextWindowID, template: .pandas)

            case .model3d:
                let sampleCube = Model3DData.generateCube(size: 3.0)
                windowManager.updateWindowModel3DData(nextWindowID, model3DData: sampleCube)
                windowManager.updateWindowTemplate(nextWindowID, template: .custom)

            case .volume:
                windowManager.updateWindowContent(nextWindowID, content: """
                # Model Performance Metrics
                import numpy as np
                import matplotlib.pyplot as plt
                
                metrics = {
                    'accuracy': 0.95,
                    'precision': 0.92,
                    'recall': 0.89,
                    'f1_score': 0.90
                }
                
                print("Model Performance Metrics:")
                for key, value in metrics.items():
                    print(f"{key}: {value}")
                """)
                windowManager.updateWindowTemplate(nextWindowID, template: .custom)

            case .pointcloud:
                let sampleTorus = PointCloudDemo.generateTorusPointCloudData(majorRadius: 8.0, minorRadius: 3.0, points: 1000)
                windowManager.updateWindowPointCloud(nextWindowID, pointCloud: sampleTorus)
                windowManager.updateWindowTemplate(nextWindowID, template: .custom)
            }

            windowManager.addWindowTag(nextWindowID, tag: "demo")
            openWindow(value: nextWindowID)
            nextWindowID += 1
        }
    }

    private func clearAllWindowsWithConfirmation() {
        let allWindows = windowManager.getAllWindows()
        for window in allWindows {
            windowManager.removeWindow(window.id)
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
        }
    }

    private func descriptionForWindowType(_ type: WindowType) -> String {
        switch type {
        case .charts: return "Visualize data with charts and graphs"
        case .spatial: return "3D spatial data visualization"
        case .column: return "Tabular data exploration"
        case .volume: return "Performance metrics and analytics"
        case .pointcloud: return "Point cloud data visualization"
        case .model3d: return "3D model rendering and interaction"
        }
    }

    private func updateNextWindowID() {
        let currentMaxID = windowManager.getAllWindows().map { $0.id }.max() ?? 0
        nextWindowID = currentMaxID + 1
    }
}

// MARK: - Reusable Components

struct WindowCountIndicator: View {
    let count: Int

    var body: some View {
        Label("\(count)", systemImage: "cube.box")
            .font(.headline)
            .padding(.horizontal, DesignSystem.padding.md)
            .padding(.vertical, DesignSystem.padding.sm)
            .background(Color.accentColor.opacity(0.15))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
    }
}

struct CircularButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.iconSize.md))
                .foregroundStyle(.secondary)
                .frame(width: DesignSystem.buttonHeight.md, height: DesignSystem.buttonHeight.md)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: DesignSystem.spacing.md) {
            IconBadge(icon: icon)

            VStack(alignment: .leading, spacing: DesignSystem.spacing.xs) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

struct IconBadge: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: DesignSystem.iconSize.lg))
            .foregroundStyle(Color.accentColor)
            .frame(width: DesignSystem.iconSize.xl, height: DesignSystem.iconSize.xl)
    }
}

struct PrimaryActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    var style: ActionCardStyle = .secondary

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.iconSize.xl, weight: .medium))
                    .foregroundStyle(style == .prominent ? .white : Color.accentColor)

                VStack(spacing: DesignSystem.spacing.xs) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(style == .prominent ? .white : .primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(style == .prominent ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.cardHeight.md)
            .padding(DesignSystem.padding.lg)
            .background(style == .prominent ? Color.accentColor : Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg))
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
}

struct SecondaryActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var isDestructive: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.iconSize.md))
                    .foregroundStyle(isDestructive ? .red : .secondary)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isDestructive ? .red : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.buttonHeight.lg)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.md))
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
}

struct WindowTypeCard: View {
    let windowType: WindowType
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.spacing.lg) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(isSelected ? 0.2 : 0.15))
                        .frame(width: DesignSystem.buttonHeight.lg, height: DesignSystem.buttonHeight.lg)

                    Image(systemName: iconForWindowType(windowType))
                        .font(.system(size: DesignSystem.iconSize.lg, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)

                VStack(spacing: DesignSystem.spacing.sm) {
                    Text(windowType.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(descriptionForWindowType(windowType))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.cardHeight.lg)
            .padding(DesignSystem.padding.lg)
            .background(Color.secondary.opacity(isSelected ? 0.15 : 0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }

    private func iconForWindowType(_ type: WindowType) -> String {
        switch type {
        case .charts: return "chart.line.uptrend.xyaxis"
        case .spatial: return "cube"
        case .column: return "tablecells"
        case .volume: return "gauge"
        case .pointcloud: return "dot.scope"
        case .model3d: return "cube.transparent"
        }
    }

    private func descriptionForWindowType(_ type: WindowType) -> String {
        switch type {
        case .charts: return "Visualize data with charts and graphs"
        case .spatial: return "3D spatial data visualization"
        case .column: return "Tabular data exploration"
        case .volume: return "Performance metrics and analytics"
        case .pointcloud: return "Point cloud data visualization"
        case .model3d: return "3D model rendering and interaction"
        }
    }
}

struct PositionBadge: View {
    let position: WindowPosition

    var body: some View {
        Text("(\(Int(position.x)), \(Int(position.y)), \(Int(position.z)))")
            .font(.caption2)
            .fontDesign(.monospaced)
            .padding(.horizontal, DesignSystem.padding.sm)
            .padding(.vertical, DesignSystem.padding.xs)
            .background(Color.secondary.opacity(0.2))
            .clipShape(Capsule())
            .foregroundStyle(.secondary)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: DesignSystem.spacing.md) {
            Image(systemName: "rectangle.dashed")
                .font(.system(size: DesignSystem.iconSize.xxl))
                .foregroundStyle(.secondary)

            Text("No Active Windows")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Create a new window to get started")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: DesignSystem.cardHeight.md)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg))
    }
}
struct ExportConfigurationSidebar: View {
    @StateObject private var windowManager = WindowTypeManager.shared
    @State private var selectedWindowID: Int? = nil
    @State private var selectedTemplate: ExportTemplate = .plain
    @State private var customImports = ""
    @State private var newTag = ""
    @State private var windowContent = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            headerView
            windowSelectorSection
            configurationSection
            Spacer()
            exportActionsSection
        }
        .padding()
        .frame(width: 300)
    }

    private var headerView: some View {
        Text("Export Configuration")
            .font(.title2)
            .bold()
    }

    private var windowSelectorSection: some View {
        WindowSelectorView(
            windowManager: windowManager,
            selectedWindowID: $selectedWindowID,
            onWindowSelected: loadWindowConfiguration
        )
    }

    @ViewBuilder
    private var configurationSection: some View {
        if let windowID = selectedWindowID {
            Divider()
            WindowConfigurationView(
                windowID: windowID,
                windowManager: windowManager,
                selectedTemplate: $selectedTemplate,
                customImports: $customImports,
                newTag: $newTag,
                windowContent: $windowContent
            )
        }
    }

    private var exportActionsSection: some View {
        ExportActionsView(windowManager: windowManager)
    }

    private func loadWindowConfiguration(_ window: NewWindowID) {
        selectedTemplate = window.state.exportTemplate
        customImports = window.state.customImports.joined(separator: "\n")
        windowContent = window.state.content
    }
}

// MARK: - Supporting Types

enum ActionCardStyle {
    case prominent
    case secondary
}
