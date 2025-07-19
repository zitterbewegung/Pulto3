import SwiftUI
import RealityKit
import UIKit

// MARK: - Charts View
struct ChartsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @State private var selectedVisualizationType: ChartsVisualizationType = .pointCloud
    @State private var showSidebar = true
    @State private var selectedDataset: String? = nil
    @State private var visualizationSettings = VisualizationSettings()
    @State private var showCodeSidebar = false
    @State private var generatedCode = ""

    var body: some View {
        HStack(spacing: 0) {
            NavigationSplitView(
                columnVisibility: .constant(.all),
                sidebar: {
                    if showSidebar {
                        SidebarView(
                            selectedDataset: $selectedDataset,
                            visualizationType: $selectedVisualizationType
                        )
                    }
                },
                content: {
                    VisualizationView(
                        type: selectedVisualizationType,
                        settings: $visualizationSettings
                    )
                    .navigationTitle(selectedVisualizationType.rawValue)
                    .navigationBarTitleDisplayMode(.inline)
                },
                detail: {
                    ControlPanelView(
                        visualizationType: selectedVisualizationType,
                        settings: $visualizationSettings
                    )
                }
            )
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button(action: { showSidebar.toggle() }) {
                        Image(systemName: "sidebar.left")
                    }

                    Picker("Visualization Type", selection: $selectedVisualizationType) {
                        ForEach(ChartsVisualizationType.allCases) { type in
                            Label(type.rawValue, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { showCodeSidebar.toggle() }) {
                        Image(systemName: showCodeSidebar ? "chevron.right" : "chevron.left")
                    }
                    .help("Toggle Code Sidebar")

                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help("Import Data")

                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Export View")

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .help("Close Window")
                    .buttonStyle(.plain)
                    .keyboardShortcut("w", modifiers: .command)
                }
            }

            // Code Sidebar
            if showCodeSidebar {
                CodeSidebarView(code: generatedCode)
                    .frame(width: 400)
                    .transition(.move(edge: .trailing))
            }
        }
        .onAppear {
            generateChartsCode()
        }
        .onChange(of: selectedVisualizationType) { _, _ in
            generateChartsCode()
        }
        .onChange(of: visualizationSettings) { _, _ in
            generateChartsCode()
        }
        .animation(.easeInOut(duration: 0.3), value: showCodeSidebar)
    }

    // Code Sidebar View
    private struct CodeSidebarView: View {
        let code: String
        @State private var showingCopySuccess = false

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Label("Charts Code", systemImage: "chart.bar")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Button(action: copyCode) {
                        Image(systemName: showingCopySuccess ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(showingCopySuccess ? .green : .blue)
                    }
                    .animation(.easeInOut, value: showingCopySuccess)
                }
                .padding()
                .background(.gray)

                Divider()

                // Code content
                ScrollView {
                    Text(code)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(.ultraThinMaterial)
            }
            .background(.regularMaterial)
        }

        private func copyCode() {
            #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
            #else
            UIPasteboard.general.string = code
            #endif

            showingCopySuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showingCopySuccess = false
            }
        }
    }

    // Generate charts code function
    private func generateChartsCode() {
        var code = """
        # Charts Visualization
        # Generated from ChartsView
        # Type: \(selectedVisualizationType.rawValue)
        
        import matplotlib.pyplot as plt
        import numpy as np
        from mpl_toolkits.mplot3d import Axes3D
        import plotly.graph_objects as go
        import plotly.express as px
        
        # Visualization Settings
        settings = {
            'show_grid': \(visualizationSettings.showGrid),
            'show_axes': \(visualizationSettings.showAxes),
            'enable_shadows': \(visualizationSettings.enableShadows),
            'point_size': \(visualizationSettings.pointSize),
            'color_mode': '\(visualizationSettings.colorMode)',
            'quality': '\(visualizationSettings.quality)',
            'progressive_loading': \(visualizationSettings.progressiveLoading)
        }
        
        """

        switch selectedVisualizationType {
        case .twoDimensional:
            code += """
            # 2D Data Visualization
            
            # Create sample heatmap data
            x = np.linspace(-2, 2,20)
            y = np.linspace(-2, 2, 20)
            X, Y = np.meshgrid(x, y)
            Z = np.sin(X * 0.3) * np.cos(Y * 0.3)
            
            # Create heatmap
            fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))
            
            # Heatmap
            im = ax1.imshow(Z, extent=[-2, 2, -2, 2], cmap='viridis', origin='lower')
            ax1.set_title('Temperature Heatmap')
            ax1.set_xlabel('X Position')
            ax1.set_ylabel('Y Position')
            if settings['show_grid']:
                ax1.grid(True, alpha=0.3)
            plt.colorbar(im, ax=ax1)
            
            # Scatter plot
            n_points = 50
            scatter_x = np.random.uniform(-2, 2, n_points)
            scatter_y = np.random.uniform(-2, 2, n_points)
            scatter_z = np.sin(scatter_x * 0.3) * np.cos(scatter_y * 0.3) + np.random.normal(0, 0.1, n_points)
            
            scatter = ax2.scatter(scatter_x, scatter_y, c=scatter_z, s=settings['point_size']*10, 
                                cmap='viridis', alpha=0.7)
            ax2.set_title('Scatter Analysis')
            ax2.set_xlabel('X Position')
            ax2.set_ylabel('Y Position')
            if settings['show_grid']:
                ax2.grid(True, alpha=0.3)
            plt.colorbar(scatter, ax=ax2)
            
            plt.tight_layout()
            plt.show()
            """

        case .threeDimensional:
            code += """
            # 3D Model Visualization
            
            # Create sample 3D objects
            fig = plt.figure(figsize=(12, 10))
            ax = fig.add_subplot(111, projection='3d')
            
            # Central cube
            def draw_cube(ax, center, size):
                # Define the vertices of a cube
                r = [-size/2, size/2]
                X, Y = np.meshgrid(r, r)
                for z in r:
                    ax.plot_surface(X + center[0], Y + center[1], 
                                  np.ones_like(X) * (z + center[2]), alpha=0.6)
                for y in r:
                    ax.plot_surface(X + center[0], np.ones_like(X) * (y + center[1]), 
                                  Y + center[2], alpha=0.6)
                for x in r:
                    ax.plot_surface(np.ones_like(X) * (x + center[0]), X + center[1], 
                                  Y + center[2], alpha=0.6)
            
            # Draw central cube
            draw_cube(ax, [0, 0, 0], 1.0)
            
            # Surrounding spheres
            for i in range(6):
                angle = i * np.pi / 3
                x = np.sin(angle) * 3
                z = np.cos(angle) * 3
                
                # Create sphere
                u = np.linspace(0, 2 * np.pi, 20)
                v = np.linspace(0, np.pi, 20)
                sphere_x = 0.4 * np.outer(np.cos(u), np.sin(v)) + x
                sphere_y = 0.4 * np.outer(np.sin(u), np.sin(v))
                sphere_z = 0.4 * np.outer(np.ones(np.size(u)), np.cos(v)) + z
                
                ax.plot_surface(sphere_x, sphere_y, sphere_z, alpha=0.7)
            
            # Add coordinate axes if enabled
            if settings['show_axes']:
                ax.plot([0, 3], [0, 0], [0, 0], 'r-', linewidth=3, label='X')
                ax.plot([0, 0], [0, 3], [0, 0], 'g-', linewidth=3, label='Y') 
                ax.plot([0, 0], [0, 0], [0, 3], 'b-', linewidth=3, label='Z')
                ax.legend()
            
            ax.set_xlabel('X')
            ax.set_ylabel('Y')
            ax.set_zlabel('Z')
            ax.set_title('3D Model Visualization')
            
            plt.tight_layout()
            plt.show()
            """

        case .pointCloud:
            code += """
            # Point Cloud Visualization
            
            # Generate sample point cloud data (terrain-like)
            x_range = np.arange(-2, 2, 0.1)
            z_range = np.arange(-2, 2, 0.1)
            
            points = []
            for x in x_range:
                for z in z_range:
                    # Create height variation
                    height = (np.sin(x * 2) * np.cos(z * 2) * 0.5 + 
                             np.sin(x * 5) * np.sin(z * 5) * 0.1 + 
                             np.random.uniform(-0.05, 0.05))
                    
                    # Calculate intensity based on height
                    intensity = (height + 1) / 2
                    
                    # Classification based on regions
                    if np.sqrt(x*x + z*z) < 0.5:
                        classification = 0  # Center region
                    elif abs(x) > 1.5 or abs(z) > 1.5:
                        classification = 2  # Outer region
                    else:
                        classification = 1  # Middle region
                    
                    points.append([x, height, z, intensity, classification])
            
            # Add scattered elevated points
            for _ in range(100):
                x = np.random.uniform(-2, 2)
                z = np.random.uniform(-2, 2)
                y = np.random.uniform(0.5, 1.5)
                intensity = np.random.uniform(0.3, 1.0)
                classification = 3
                points.append([x, y, z, intensity, classification])
            
            points = np.array(points)
            
            # Create visualization
            fig = plt.figure(figsize=(15, 10))
            
            # 3D scatter plot
            ax1 = fig.add_subplot(221, projection='3d')
            scatter = ax1.scatter(points[:, 0], points[:, 2], points[:, 1], 
                                c=points[:, 1], s=settings['point_size'], cmap='terrain', alpha=0.6)
            ax1.set_xlabel('X')
            ax1.set_ylabel('Z') 
            ax1.set_zlabel('Height')
            ax1.set_title('3D Point Cloud (Height Colored)')
            plt.colorbar(scatter, ax=ax1, shrink=0.5)
            
            # Intensity view
            ax2 = fig.add_subplot(222, projection='3d')
            scatter2 = ax2.scatter(points[:, 0], points[:, 2], points[:, 1], 
                                 c=points[:, 3], s=settings['point_size'], cmap='viridis', alpha=0.6)
            ax2.set_xlabel('X')
            ax2.set_ylabel('Z')
            ax2.set_zlabel('Height')
            ax2.set_title('Point Cloud (Intensity Colored)')
            plt.colorbar(scatter2, ax=ax2, shrink=0.5)
            
            # Classification view
            ax3 = fig.add_subplot(223, projection='3d')
            colors = ['blue', 'green', 'orange', 'purple']
            for i in range(4):
                mask = points[:, 4] == i
                if np.any(mask):
                    ax3.scatter(points[mask, 0], points[mask, 2], points[mask, 1], 
                              c=colors[i], s=settings['point_size'], alpha=0.7, 
                              label=f'Class {i}')
            ax3.set_xlabel('X')
            ax3.set_ylabel('Z')
            ax3.set_zlabel('Height')
            ax3.set_title('Point Cloud (Classification)')
            ax3.legend()
            
            # Top view (height map)
            ax4 = fig.add_subplot(224)
            terrain_mask = points[:, 4] < 3  # Exclude scattered points
            terrain_points = points[terrain_mask]
            scatter4 = ax4.scatter(terrain_points[:, 0], terrain_points[:, 2], 
                                 c=terrain_points[:, 1], s=settings['point_size']*2, 
                                 cmap='terrain', alpha=0.8)
            ax4.set_xlabel('X')
            ax4.set_ylabel('Z')
            ax4.set_title('Top View (Height Map)')
            ax4.set_aspect('equal')
            if settings['show_grid']:
                ax4.grid(True, alpha=0.3)
            plt.colorbar(scatter4, ax=ax4)
            
            plt.tight_layout()
            plt.show()
            
            # Print statistics
            print("Point Cloud Statistics:")
            print(f"Total points: {len(points)}")
            print(f"Height range: [{np.min(points[:, 1]):.2f}, {np.max(points[:, 1]):.2f}]")
            print(f"X range: [{np.min(points[:, 0]):.2f}, {np.max(points[:, 0]):.2f}]")
            print(f"Z range: [{np.min(points[:, 2]):.2f}, {np.max(points[:, 2]):.2f}]")
            print(f"Intensity range: [{np.min(points[:, 3]):.2f}, {np.max(points[:, 3]):.2f}]")
            # Classification breakdown
            for i in range(4):
                count = np.sum(points[:, 4] == i)
                print(f"Class {i}: {count} points ({count/len(points)*100:.1f}%)")
            """
        }

        code += """
        
        # Export options (uncomment to use)
        # plt.savefig('\(selectedVisualizationType.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))_visualization.png', 
        #             dpi=300, bbox_inches='tight')
        # plt.savefig('\(selectedVisualizationType.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))_visualization.pdf', 
        #             bbox_inches='tight')
        
        print("\\nVisualization complete!")
        print("Settings used:", settings)
        """

        generatedCode = code
    }
}

// MARK: - Visualization Types
enum ChartsVisualizationType: String, CaseIterable, Identifiable {
    case twoDimensional = "2D Data"
    case threeDimensional = "3D Model"
    case pointCloud = "Point Cloud"

    var id: Self { self }

    var iconName: String {
        switch self {
        case .twoDimensional: return "square.grid.2x2"
        case .threeDimensional: return "cube"
        case .pointCloud: return "point.3.connected.trianglepath.dotted"
        }
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @Binding var selectedDataset: String?
    @Binding var visualizationType: ChartsVisualizationType
    @State private var datasets = [
        Dataset(name: "Temperature Heatmap", type: .twoDimensional),
        Dataset(name: "Elevation Map", type: .twoDimensional),
        Dataset(name: "Scatter Analysis", type: .twoDimensional),
        Dataset(name: "City Model", type: .threeDimensional),
        Dataset(name: "Mechanical Part", type: .threeDimensional),
        Dataset(name: "Building Structure", type: .threeDimensional),
        Dataset(name: "LiDAR Scan - Street", type: .pointCloud),
        Dataset(name: "Building Interior", type: .pointCloud),
        Dataset(name: "Terrain Survey", type: .pointCloud),
        Dataset(name: "Archaeological Site", type: .pointCloud)
    ]

    var body: some View {
        List(selection: $selectedDataset) {
            Section("Datasets") {
                ForEach(datasets.filter { $0.type == visualizationType }) { dataset in
                    DatasetRow(dataset: dataset)
                        .tag(dataset.id)
                }
            }

            Section("Layers") {
                LayerRow(name: "Base Layer", isVisible: true)
                LayerRow(name: "Annotations", isVisible: true)
                LayerRow(name: "Measurements", isVisible: false)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Data Browser")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {}) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

// MARK: - Visualization View
struct VisualizationView: View {
    @Environment(\.dismiss) private var dismiss
    let type: ChartsVisualizationType
    @Binding var settings: VisualizationSettings
    @State private var cameraPosition: SIMD3<Float> = [0, 5, 10]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(white: 0.05),
                    Color(white: 0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            switch type {
            case .twoDimensional:
                TwoDimensionalView(settings: settings)
            case .threeDimensional:
                ThreeDimensionalView(settings: settings)
            case .pointCloud:
                PointCloudView(settings: settings)
            }

            // Overlay controls
            VStack {
                HStack {
                    ViewControlsOverlay(settings: $settings)
                    Spacer()

                    // Floating dismiss button for visionOS
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close Window (âW)")
                    .padding()
                }
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Control Panel
struct ControlPanelView: View {
    let visualizationType: ChartsVisualizationType
    @Binding var settings: VisualizationSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Display Settings
                GroupBox("Display") {
                    VStack(alignment: .leading, spacing: 15) {
                        Toggle("Show Grid", isOn: $settings.showGrid)
                        Toggle("Show Axes", isOn: $settings.showAxes)
                        Toggle("Enable Shadows", isOn: $settings.enableShadows)

                        HStack {
                            Text("Point Size")
                            Slider(value: $settings.pointSize, in: 1...10)
                                .frame(width: 150)
                            Text("\(Int(settings.pointSize))")
                                .monospacedDigit()
                        }
                    }
                    .padding(.vertical, 5)
                }

                // Color Settings
                GroupBox("Color") {
                    VStack(alignment: .leading, spacing: 15) {
                        Picker("Color Mode", selection: $settings.colorMode) {
                            Text("Height").tag(ColorMode.height)
                            Text("Intensity").tag(ColorMode.intensity)
                            Text("Classification").tag(ColorMode.classification)
                            Text("RGB").tag(ColorMode.rgb)
                        }
                        .pickerStyle(.segmented)

                        ColorPicker("Base Color", selection: $settings.baseColor)
                    }
                    .padding(.vertical, 5)
                }

                // Performance Settings
                GroupBox("Performance") {
                    VStack(alignment: .leading, spacing: 15) {
                        Picker("Quality", selection: $settings.quality) {
                            Text("Low").tag(Quality.low)
                            Text("Medium").tag(Quality.medium)
                            Text("High").tag(Quality.high)
                        }
                        .pickerStyle(.segmented)

                        Toggle("Progressive Loading", isOn: $settings.progressiveLoading)
                    }
                    .padding(.vertical, 5)
                }

                // Statistics
                GroupBox("Statistics") {
                    VStack(alignment: .leading, spacing: 10) {
                        switch visualizationType {
                        case .twoDimensional:
                            StatRow(label: "Grid Points", value: "400")
                            StatRow(label: "Scatter Points", value: "50")
                            StatRow(label: "Memory", value: "12 MB")
                        case .threeDimensional:
                            StatRow(label: "Vertices", value: "24")
                            StatRow(label: "Objects", value: "7")
                            StatRow(label: "Memory", value: "8 MB")
                        case .pointCloud:
                            StatRow(label: "Points", value: "36")
                            StatRow(label: "Memory", value: "0.1 MB")
                            StatRow(label: "Density", value: "N/A")
                        }
                        StatRow(label: "FPS", value: "60")
                    }
                    .padding(.vertical, 5)
                }
            }
            .padding()
        }
        .frame(minWidth: 300)
        .navigationTitle("Controls")
    }
}

// MARK: - Supporting Views
struct DatasetRow: View {
    let dataset: Dataset

    var body: some View {
        HStack {
            Image(systemName: dataset.type.iconName)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading) {
                Text(dataset.name)
                    .font(.headline)
                Text(formatPointCount(dataset.pointCount))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    func formatPointCount(_ count: Int) -> String {
        switch dataset.type {
        case .twoDimensional:
            return "\(count) cells"
        case .threeDimensional:
            return "\(count) vertices"
        case .pointCloud:
            if count >= 1_000_000 {
                return String(format: "%.1fM points", Double(count) / 1_000_000)
            } else if count >= 1_000 {
                return String(format: "%.1fK points", Double(count) / 1_000)
            } else {
                return "\(count) points"
            }
        }
    }
}

struct LayerRow: View {
    let name: String
    @State var isVisible: Bool
    @State private var isHovered = false

    var body: some View {
        HStack {
            Button(action: { isVisible.toggle() }) {
                Image(systemName: isVisible ? "eye" : "eye.slash")
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.secondary.opacity(isHovered ? 0.15 : 0.05))
            }
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }

            Text(name)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct ViewControlsOverlay: View {
    @Binding var settings: VisualizationSettings
    @State private var hoveredControl: String?

    var body: some View {
        HStack(spacing: 15) {
            ControlButton(icon: "arrow.up.left.and.arrow.down.right", id: "fit", hoveredControl: $hoveredControl) {
                // Fit to view action
            }

            ControlButton(icon: "camera", id: "camera", hoveredControl: $hoveredControl) {
                // Reset camera action
            }

            ControlButton(icon: "ruler", id: "ruler", hoveredControl: $hoveredControl) {
                // Measure action
            }

            ControlButton(icon: "slider.horizontal.3", id: "filters", hoveredControl: $hoveredControl) {
                // Filters action
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

struct ControlButton: View {
    let icon: String
    let id: String
    @Binding var hoveredControl: String?
    let action: () -> Void

    var isHovered: Bool {
        hoveredControl == id
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
                }
                .shadow(color: .black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 4 : 2)
        }
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            hoveredControl = hovering ? id : nil
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
    }
}

// MARK: - Visualization Type Views
struct TwoDimensionalView: View {
    let settings: VisualizationSettings
    @State private var heatmapData: [[Double]] = []

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Draw grid
                if settings.showGrid {
                    let gridSize: CGFloat = 50
                    context.stroke(
                        Path { path in
                            // Vertical lines
                            for x in stride(from: 0, through: size.width, by: gridSize) {
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: size.height))
                            }
                            // Horizontal lines
                            for y in stride(from: 0, through: size.height, by: gridSize) {
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: size.width, y: y))
                            }
                        },
                        with: .color(.gray.opacity(0.2)),
                        lineWidth: 1
                    )
                }

                // Draw axes if enabled
                if settings.showAxes {
                    // X-axis
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: 50, y: size.height - 50))
                            path.addLine(to: CGPoint(x: size.width - 50, y: size.height - 50))
                        },
                        with: .color(.white),
                        lineWidth: 2
                    )

                    // Y-axis
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: 50, y: size.height - 50))
                            path.addLine(to: CGPoint(x: 50, y: 50))
                        },
                        with: .color(.white),
                        lineWidth: 2
                    )

                    // Add axis labels
                    context.draw(Text("X").font(.caption), at: CGPoint(x: size.width - 40, y: size.height - 40))
                    context.draw(Text("Y").font(.caption), at: CGPoint(x: 40, y: 40))
                }

                // Draw sample heatmap data
                let cellWidth = (size.width - 100) / 20
                let cellHeight = (size.height - 100) / 20

                for i in 0..<20 {
                    for j in 0..<20 {
                        let value = sin(Double(i) * 0.3) * cos(Double(j) * 0.3) + 0.5
                        let color = heatmapColor(value: value, baseColor: settings.baseColor)

                        context.fill(
                            Path(CGRect(
                                x: 50 + CGFloat(i) * cellWidth,
                                y: 50 + CGFloat(j) * cellHeight,
                                width: cellWidth - 1,
                                height: cellHeight - 1
                            )),
                            with: .color(color)
                        )
                    }
                }

                // Draw sample scatter points
                let points = generateScatterPoints(count: 50, size: size)
                for point in points {
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: point.x - settings.pointSize,
                            y: point.y - settings.pointSize,
                            width: settings.pointSize * 2,
                            height: settings.pointSize * 2
                        )),
                        with: .color(settings.baseColor)
                    )
                }
            }
        }
    }

    func heatmapColor(value: Double, baseColor: Color) -> Color {
        switch settings.colorMode {
        case .height:
            return baseColor.opacity(value)
        case .intensity:
            let hue = value * 0.7 // From red to blue
            return Color(hue: hue, saturation: 0.8, brightness: 0.9)
        case .classification:
            if value < 0.33 {
                return .blue
            } else if value < 0.66 {
                return .green
            } else {
                return .orange
            }
        case .rgb:
            return baseColor // Not applicable for 2D, fallback
        }
    }

    func generateScatterPoints(count: Int, size: CGSize) -> [CGPoint] {
        var points: [CGPoint] = []
        for _ in 0..<count {
            let x = CGFloat.random(in: 100...(size.width - 100))
            let y = CGFloat.random(in: 100...(size.height - 100))
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }
}

struct ThreeDimensionalView: View {
    let settings: VisualizationSettings
    @State private var rotation: Double = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            RealityView { content in
                // Create a sample 3D scene

                // Add lighting
                let lightEntity = DirectionalLight()
                lightEntity.light.intensity = 10000
                lightEntity.orientation = simd_quatf(angle: -.pi/4, axis: [1, 0, 0])
                content.add(lightEntity)

                // Create base platform
                if settings.showGrid {
                    let platformMesh = MeshResource.generatePlane(width: 5, depth: 5)
                    let platformMaterial = SimpleMaterial(color: .gray.withAlphaComponent(0.3), isMetallic: false)
                    let platform = ModelEntity(mesh: platformMesh, materials: [platformMaterial])
                    platform.position = [0, -1, 0]
                    content.add(platform)
                }

                // Create sample 3D objects
                let baseUIColor = colorToUIColor(settings.baseColor)

                // Central cube
                let cubeMesh = MeshResource.generateBox(size: 0.5)
                let cubeMaterial = SimpleMaterial(color: baseUIColor, roughness: 0.3, isMetallic: true)
                let cube = ModelEntity(mesh: cubeMesh, materials: [cubeMaterial])
                cube.position = [0, 0, 0]
                content.add(cube)

                // Surrounding spheres
                for i in 0..<6 {
                    let angle = Float(i) * .pi / 3
                    let sphereMesh = MeshResource.generateSphere(radius: 0.2)
                    let sphereColor: UIColor = settings.colorMode == .classification ?
                        UIColor(hue: CGFloat(i) / 6.0, saturation: 0.8, brightness: 0.9, alpha: 1.0) : baseUIColor
                    let sphereMaterial = SimpleMaterial(color: sphereColor, roughness: 0.5, isMetallic: false)
                    let sphere = ModelEntity(mesh: sphereMesh, materials: [sphereMaterial])
                    sphere.position = [sin(angle) * 1.5, 0, cos(angle) * 1.5]
                    content.add(sphere)
                }

                // Add coordinate axes if enabled
                if settings.showAxes {
                    // X-axis (red)
                    let xAxisMesh = MeshResource.generateBox(width: 3, height: 0.02, depth: 0.02)
                    let xAxisMaterial = SimpleMaterial(color: .red, isMetallic: false)
                    let xAxis = ModelEntity(mesh: xAxisMesh, materials: [xAxisMaterial])
                    xAxis.position = [1.5, 0, 0]
                    content.add(xAxis)

                    // Y-axis (green)
                    let yAxisMesh = MeshResource.generateBox(width: 0.02, height: 3, depth: 0.02)
                    let yAxisMaterial = SimpleMaterial(color: .green, isMetallic: false)
                    let yAxis = ModelEntity(mesh: yAxisMesh, materials: [yAxisMaterial])
                    yAxis.position = [0, 1.5, 0]
                    content.add(yAxis)

                    // Z-axis (blue)
                    let zAxisMesh = MeshResource.generateBox(width: 0.02, height: 0.02, depth: 3)
                    let zAxisMaterial = SimpleMaterial(color: .blue, isMetallic: false)
                    let zAxis = ModelEntity(mesh: zAxisMesh, materials: [zAxisMaterial])
                    zAxis.position = [0, 0, 1.5]
                    content.add(zAxis)
                }
            } update: { content in
                // Animate rotation
                let time = timeline.date.timeIntervalSinceReferenceDate
                if let cube = content.entities.first(where: { $0.position == [0, 0, 0] }) {
                    cube.orientation = simd_quatf(angle: Float(time * 0.5), axis: [0, 1, 0])
                }
            }
            .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
            .scaleEffect(settings.quality == .high ? 1.2 : settings.quality == .medium ? 1.0 : 0.8)
        }
    }

    func colorToUIColor(_ color: Color) -> UIColor {
        // Convert SwiftUI Color to UIColor for visionOS
        UIColor(color)
    }
}

struct PointCloudView: View {
    let settings: VisualizationSettings
    @State private var pointCloudData: [PointCloudPoint] = []
    @State private var rotation: Angle = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.clear

                // Point cloud visualization using Canvas
                Canvas { context, size in
                    // Generate point cloud data if empty
                    if pointCloudData.isEmpty {
                        pointCloudData = generatePointCloudData()
                    }

                    // Draw grid base if enabled
                    if settings.showGrid {
                        drawPointCloudGrid(context: context, size: size)
                    }

                    // Transform and draw points
                    let centerX = size.width / 2
                    let centerY = size.height / 2
                    let scale: CGFloat = min(size.width, size.height) / 6

                    // Sort points by depth for proper rendering
                    let rotatedPoints = pointCloudData.map { point in
                        rotatePoint(point, angle: rotation.radians)
                    }.sorted { $0.z < $1.z }

                    for point in rotatedPoints {
                        // Project 3D to 2D
                        let projectedX = centerX + (point.x * scale) / (1 + point.z * 0.5)
                        let projectedY = centerY - (point.y * scale) / (1 + point.z * 0.5)

                        // Color based on settings
                        let color = getPointColor(point: point)

                        // Size based on depth
                        let pointSize = settings.pointSize * (1.0 + point.z * 0.3)

                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: projectedX - pointSize / 2,
                                y: projectedY - pointSize / 2,
                                width: pointSize,
                                height: pointSize
                            )),
                            with: .color(color.opacity(0.8 + point.z * 0.2))
                        )
                    }

                    // Draw axes if enabled
                    if settings.showAxes {
                        drawPointCloudAxes(context: context, size: size, rotation: rotation)
                    }
                }

                // Overlay info
                VStack {
                    HStack {
                        Text("Sample Point Cloud")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(pointCloudData.count) points")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                    Spacer()
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    rotation = .degrees(360)
                }
            }
        }
    }

    func generatePointCloudData() -> [PointCloudPoint] {
        let rawData: [[Double]] = [
            [13.32, 12.84, 3.06, 1.0, 255.0, 243.0, 245.0],
            [13.44, 12.84, 3.06, 1.0, 255.0, 244.0, 242.0],
            [13.56, 12.84, 3.024, 0.988235, 252.0, 232.0, 218.0],
            [13.68, 12.84, 3.0, 0.980392, 250.0, 222.0, 199.0],
            [13.8, 12.84, 3.0, 0.980392, 250.0, 222.0, 196.0],
            [13.92, 12.84, 2.94, 0.960784, 245.0, 205.0, 181.0],
            [13.32, 12.96, 3.048, 0.996078, 254.0, 240.0, 240.0],
            [13.44, 12.96, 3.036, 0.992157, 253.0, 232.0, 220.0],
            [13.56, 12.96, 2.976, 0.972549, 248.0, 217.0, 195.0],
            [13.68, 12.96, 2.94, 0.960784, 245.0, 207.0, 182.0],
            [13.8, 12.96, 2.928, 0.956863, 244.0, 199.0, 175.0],
            [13.92, 12.96, 2.916, 0.952941, 243.0, 173.0, 147.0],
            [13.32, 13.08, 3.06, 1.0, 255.0, 236.0, 225.0],
            [13.44, 13.08, 2.976, 0.972549, 248.0, 217.0, 195.0],
            [13.56, 13.08, 2.94, 0.960784, 245.0, 197.0, 168.0],
            [13.68, 13.08, 2.94, 0.960784, 245.0, 185.0, 157.0],
            [13.8, 13.08, 2.916, 0.952941, 243.0, 169.0, 149.0],
            [13.92, 13.08, 2.796, 0.913725, 233.0, 144.0, 121.0],
            [13.32, 13.2, 3.024, 0.988235, 252.0, 228.0, 206.0],
            [13.44, 13.2, 2.928, 0.956863, 244.0, 207.0, 178.0],
            [13.56, 13.2, 2.952, 0.964706, 246.0, 190.0, 155.0],
            [13.68, 13.2, 2.892, 0.945098, 241.0, 161.0, 133.0],
            [13.8, 13.2, 2.856, 0.933333, 238.0, 144.0, 115.0],
            [13.92, 13.2, 2.556, 0.835294, 213.0, 119.0, 99.0],
            [13.32, 13.32, 2.964, 0.968627, 247.0, 215.0, 189.0],
            [13.44, 13.32, 2.916, 0.952941, 243.0, 198.0, 169.0],
            [13.56, 13.32, 2.976, 0.972549, 248.0, 181.0, 148.0],
            [13.68, 13.32, 2.784, 0.909804, 232.0, 144.0, 116.0],
            [13.8, 13.32, 2.664, 0.870588, 222.0, 124.0, 101.0],
_           [13.92, 13.32, 2.484, 0.811765, 207.0, 105.0, 86.0],
            [13.32, 13.44, 2.94, 0.960784, 245.0, 197.0, 166.0],
            [13.44, 13.44, 2.94, 0.960784, 245.0, 191.0, 161.0],
            [13.56, 13.44, 2.952, 0.964706, 246.0, 170.0, 139.0],
            [13.68, 13.44, 2.64, 0.862745, 220.0, 128.0, 104.0],
            [13.8, 13.44, 2.472, 0.807843, 206.0, 110.0, 92.0],
            [13.92, 13.44, 2.412, 0.788235, 201.0, 89.0, 72.0]
        ]

        let count = Double(rawData.count)
        let sumX = rawData.reduce(0.0) { $0 + $1[0] }
        let sumY = rawData.reduce(0.0) { $0 + $1[1] }
        let sumZ = rawData.reduce(0.0) { $0 + $1[2] }
        let meanX = sumX / count
        let meanY = sumY / count
        let meanZ = sumZ / count

        return rawData.map { data in
            PointCloudPoint(
                x: data[0] - meanX,
                y: data[1] - meanY,
                z: data[2] - meanZ,
                intensity: data[3],
                classification: 0,
                red: data[4] / 255.0,
                green: data[5] / 255.0,
                blue: data[6] / 255.0
            )
        }
    }

    func rotatePoint(_ point: PointCloudPoint, angle: Double) -> PointCloudPoint {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)

        return PointCloudPoint(
            x: point.x * cosAngle - point.z * sinAngle,
            y: point.y,
            z: point.x * sinAngle + point.z * cosAngle,
            intensity: point.intensity,
            classification: point.classification,
            red: point.red,
            green: point.green,
            blue: point.blue
        )
    }

    func getPointColor(point: PointCloudPoint) -> Color {
        switch settings.colorMode {
        case .height:
            let normalized = (point.y + 1) / 3
            return Color(hue: 0.7 - normalized * 0.7, saturation: 0.8, brightness: 0.9)
        case .intensity:
            return settings.baseColor.opacity(point.intensity)
        case .classification:
            switch point.classification {
            case 0: return .blue
            case 1: return .green
            case 2: return .orange
            case 3: return .purple
            default: return .gray
            }
        case .rgb:
            return Color(red: point.red, green: point.green, blue: point.blue)
        }
    }

    func drawPointCloudGrid(context: GraphicsContext, size: CGSize) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let gridSize: CGFloat = 50

        for i in -5...5 {
            // Horizontal lines
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: centerX - 250, y: centerY + CGFloat(i) * gridSize))
                    path.addLine(to: CGPoint(x: centerX + 250, y: centerY + CGFloat(i) * gridSize))
                },
                with: .color(.gray.opacity(0.1)),
                lineWidth: 1
            )

            // Vertical lines
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: centerX + CGFloat(i) * gridSize, y: centerY - 250))
                    path.addLine(to: CGPoint(x: centerX + CGFloat(i) * gridSize, y: centerY + 250))
                },
                with: .color(.gray.opacity(0.1)),
                lineWidth: 1
            )
        }
    }

    func drawPointCloudAxes(context: GraphicsContext, size: CGSize, rotation: Angle) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let axisLength: CGFloat = 150

        // Calculate rotated axis endpoints
        let cosAngle = CGFloat(cos(rotation.radians))
        let sinAngle = CGFloat(sin(rotation.radians))

        // X-axis (red)
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: centerX, y: centerY))
                path.addLine(to: CGPoint(
                    x: centerX + axisLength * cosAngle,
                    y: centerY
                ))
            },
            with: .color(.red),
            lineWidth: 2
        )

        // Y-axis (green) â vertical, no rotation
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: centerX, y: centerY))
                path.addLine(to: CGPoint(x: centerX, y: centerY - axisLength))
            },
            with: .color(.green),
            lineWidth: 2
        )

        // Z-axis (blue)
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: centerX, y: centerY))
                path.addLine(to: CGPoint(
                    x: centerX - axisLength * sinAngle,
                    y: centerY + axisLength * cosAngle * 0.5
                ))
            },
            with: .color(.blue),
            lineWidth: 2
        )
    }
}

// Point-cloud point model
struct PointCloudPoint {
    let x: Double
    let y: Double
    let z: Double
    let intensity: Double
    let classification: Int
    let red: Double
    let green: Double
    let blue: Double
}

// MARK: - Data Models
struct Dataset: Identifiable {
    let id = UUID()
    let name: String
    let type: ChartsVisualizationType
    var pointCount: Int {
        switch type {
        case .twoDimensional:
            return Int.random(in: 400...2000)     // Grid cells or scatter points
        case .threeDimensional:
            return Int.random(in: 1000...50000) // Vertices
        case .pointCloud:
            return Int.random(in: 100000...5000000) // Point-cloud points
        }
    }
}

struct VisualizationSettings: Equatable {
    var showGrid = true
    var showAxes = true
    var enableShadows = true
    var pointSize: Double = 3.0
    var colorMode: ColorMode = .height
    var baseColor: Color = .blue
    var quality: Quality = .medium
    var progressiveLoading = true
}

enum ColorMode: Equatable {
    case height, intensity, classification, rgb
}

enum Quality: Equatable {
    case low, medium, high
}

// MARK: - Previews
#Preview("ChartsView", traits: .fixedLayout(width: 1600, height: 900)) {
    ChartsView()
}
