//
//  TemplateView.swift
//  Pulto
//
//  Created by Joshua Herman on 6/19/25.
//  Copyright © 2025 Apple. All rights reserved.
//
//  Template Gallery for importing pre-configured window layouts


import SwiftUI
import Foundation

struct TemplateView: View {
    @State private var selectedCellIndex: Int? = nil
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showImportConfirmation = false
    @State private var templateWindows: [TemplateWindow] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @StateObject private var windowManager = WindowTypeManager.shared
    
    // Template window data structure
    struct TemplateWindow: Identifiable {
        let id = UUID()
        let windowId: Int
        let windowType: String
        let exportTemplate: String
        let tags: [String]
        let position: WindowPosition
        let content: String
        let title: String
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if !templateWindows.isEmpty {
                    templateContentView
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Template Gallery")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import All") {
                        showImportConfirmation = true
                    }
                    .disabled(templateWindows.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task {
            loadTemplateWindows()
        }
        .alert("Import Template", isPresented: $showImportConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Import") {
                importAllWindows()
            }
        } message: {
            Text("This will create \(templateWindows.count) new windows in your workspace.")
        }
    }
    
    // MARK: - Views
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading template...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            
            Text("Failed to Load Template")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                loadTemplateWindows()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Template Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("The template file could not be found.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var templateContentView: some View {
        HStack(spacing: 0) {
            // Left sidebar - window list
            windowListView
                .frame(width: 350)
                .background(Color(.systemBackground).opacity(0.95))
            
            Divider()
            
            // Right side - preview
            if let selectedIndex = selectedCellIndex,
               selectedIndex < templateWindows.count {
                windowPreviewView(templateWindows[selectedIndex])
            } else {
                templateOverviewView
            }
        }
    }
    
    private var windowListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Template Windows")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Label("\(templateWindows.count) windows", systemImage: "square.stack.3d")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            
            Divider()
            
            // Window list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(templateWindows.enumerated()), id: \.element.id) { index, window in
                        TemplateWindowRow(
                            window: window,
                            isSelected: selectedCellIndex == index,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCellIndex = index
                                }
                            }
                        )
                    }
                }
                .padding()
            }
        }
    }
    
    private var templateOverviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Template info
                VStack(alignment: .leading, spacing: 16) {
                    Text("VisionOS Spatial Computing Template")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("A comprehensive template demonstrating spatial data visualization capabilities")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                
                // Metadata
                metadataSection
                
                // Preview grid
                previewGridSection
                
                // Import button
                VStack {
                    Button(action: { showImportConfirmation = true }) {
                        Label("Import All Windows", systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 40)
                    
                    Text("This will create \(templateWindows.count) new windows in your workspace")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 32)
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Template Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            let uniqueTypes = Set(templateWindows.map { $0.windowType }).count
            let uniqueTags = Set(templateWindows.flatMap { $0.tags }).count
            let uniqueTemplates = Set(templateWindows.map { $0.exportTemplate }).count
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                TemplateMetadataCard(
                    icon: "square.stack.3d",
                    title: "Windows",
                    value: "\(templateWindows.count)",
                    color: .blue
                )
                
                TemplateMetadataCard(
                    icon: "tag",
                    title: "Tags",
                    value: "\(uniqueTags)",
                    color: .green
                )
                
                TemplateMetadataCard(
                    icon: "doc.text",
                    title: "Templates",
                    value: "\(uniqueTemplates)",
                    color: .orange
                )
                
                TemplateMetadataCard(
                    icon: "cube",
                    title: "Window Types",
                    value: "\(uniqueTypes)",
                    color: .purple
                )
            }
        }
        .padding(.horizontal, 40)
    }
    
    private var previewGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Window Previews")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal, 40)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(templateWindows) { window in
                        TemplateWindowPreviewCard(window: window) {
                            if let index = templateWindows.firstIndex(where: { $0.id == window.id }) {
                                selectedCellIndex = index
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }

    // Add this function inside TemplateView struct
    private func iconForWindowType(_ type: String) -> String {
        switch type {
        case "Charts":
            return "chart.line.uptrend.xyaxis"
        case "Spatial Editor":
            return "cube"
        case "DataFrame Viewer":
            return "tablecells"
        case "Model Metric Viewer":
            return "gauge"
        default:
            return "square.stack.3d"
        }
    }

    private func windowPreviewView(_ window: TemplateWindow) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(window.windowType, systemImage: iconForWindowType(window.windowType))
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text("Window #\(window.windowId)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Label(window.exportTemplate, systemImage: "doc.text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if !window.tags.isEmpty {
                        HStack {
                            ForEach(window.tags, id: \.self) { tag in
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
                .padding(.horizontal, 40)
                .padding(.top, 32)
                
                Divider()
                    .padding(.horizontal, 40)
                
                // Position info
                positionInfoView(window.position)
                
                // Content preview
                contentPreviewView(window)
                
                // Import button
                Button(action: { importSingleWindow(window) }) {
                    Label("Import This Window", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
            }
        }
    }
    
    private func positionInfoView(_ position: WindowPosition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Position & Size")
                .font(.headline)
            
            HStack(spacing: 24) {
                Label("X: \(Int(position.x))", systemImage: "arrow.left.and.right")
                Label("Y: \(Int(position.y))", systemImage: "arrow.up.and.down")
                Label("Z: \(Int(position.z))", systemImage: "move.3d")
                Spacer()
                Label("\(Int(position.width)) × \(Int(position.height))", systemImage: "aspectratio")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 40)
    }
    
    private func contentPreviewView(_ window: TemplateWindow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Content Preview")
                .font(.headline)
            
            ScrollView {
                Text(window.content)
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
    
    // MARK: - Helper Methods
    
    private func loadTemplateWindows() {
        isLoading = true
        errorMessage = nil
        templateWindows = []
        
        // Create sample template windows based on template.ipynb
        templateWindows = createSampleTemplateWindows()
        
        if let firstWindow = templateWindows.first {
            selectedCellIndex = 0
        }
        
        isLoading = false
    }
    
    private func createSampleTemplateWindows() -> [TemplateWindow] {
        // Use higher IDs to avoid conflicts with manually created windows
        let baseId = 5000
        
        return [
            TemplateWindow(
                windowId: baseId + 1,
                windowType: "Spatial Editor",
                exportTemplate: "Markdown Only",
                tags: ["introduction", "spatial"],
                position: WindowPosition(x: -150, y: 100, z: -50, width: 500, height: 300),
                content: """
                # VisionOS Spatial Computing Notebook
                
                This notebook demonstrates **spatial computing** capabilities with interactive windows and 3D visualizations.
                
                ## Features
                - **Multi-dimensional data visualization**
                - **Spatial window management**
                - **Real-time chart interaction**
                - **Immersive analytics experience**
                
                Welcome to the future of data science!
                """,
                title: "Introduction"
            ),
            TemplateWindow(
                windowId: baseId + 2,
                windowType: "Charts",
                exportTemplate: "Matplotlib Chart",
                tags: ["visualization", "matplotlib", "data"],
                position: WindowPosition(x: 200, y: 50, z: 0, width: 600, height: 450),
                content: """
                # Interactive Data Visualization
                import matplotlib.pyplot as plt
                import numpy as np
                import pandas as pd
                
                # Generate sample data for spatial visualization
                np.random.seed(42)
                x = np.linspace(0, 10, 100)
                y1 = np.sin(x) + np.random.normal(0, 0.1, 100)
                y2 = np.cos(x) + np.random.normal(0, 0.1, 100)
                
                # Create visualization
                fig, ax = plt.subplots(figsize=(10, 6))
                ax.plot(x, y1, 'b-', label='Signal A')
                ax.plot(x, y2, 'r-', label='Signal B')
                ax.legend()
                plt.show()
                """,
                title: "Data Visualization"
            ),
            TemplateWindow(
                windowId: baseId + 3,
                windowType: "DataFrame Viewer",
                exportTemplate: "Pandas DataFrame",
                tags: ["data", "pandas", "analysis"],
                position: WindowPosition(x: -100, y: -150, z: 25, width: 700, height: 400),
                content: """
                # Spatial Data Table Analysis
                import pandas as pd
                import numpy as np
                from datetime import datetime, timedelta
                
                # Create comprehensive spatial dataset
                n_samples = 150
                df = pd.DataFrame({
                    'sensor_id': [f'SENSOR_{i:03d}' for i in range(1, n_samples+1)],
                    'x_coordinate': np.random.uniform(-50, 50, n_samples),
                    'y_coordinate': np.random.uniform(-30, 30, n_samples),
                    'z_coordinate': np.random.uniform(-10, 10, n_samples),
                    'temperature_c': np.random.normal(20, 5, n_samples),
                    'status': np.random.choice(['Active', 'Inactive'], n_samples)
                })
                
                print(df.head())
                """,
                title: "Data Analysis"
            ),
            TemplateWindow(
                windowId: baseId + 4,
                windowType: "Spatial Editor",
                exportTemplate: "Custom Code",
                tags: ["3d", "visualization", "spatial", "interactive"],
                position: WindowPosition(x: 300, y: -100, z: 75, width: 550, height: 450),
                content: """
                # 3D Spatial Visualization and Point Cloud Analysis
                # This window will display an interactive 3D sphere point cloud
                
                import numpy as np
                import plotly.graph_objects as go
                
                # Point cloud will be generated automatically
                # Use the controls to interact with the 3D visualization
                """,
                title: "3D Point Cloud Visualization"
            ),
            TemplateWindow(
                windowId: baseId + 5,
                windowType: "Model Metric Viewer",
                exportTemplate: "NumPy Array",
                tags: ["metrics", "performance", "monitoring"],
                position: WindowPosition(x: -50, y: 200, z: 50, width: 500, height: 350),
                content: """
                # Model Performance Metrics and Real-time Monitoring
                
                ## Current Model Status
                - Accuracy: 0.94
                - Latency: 125ms
                - Throughput: 250 RPS
                
                ## Resource Usage
                - Memory: 512 MB
                - CPU: 35%
                """,
                title: "Performance Metrics"
            )
        ]
    }
    
    private func importAllWindows() {
        for window in templateWindows {
            importWindow(window)
        }
        dismiss()
    }
    
    private func importSingleWindow(_ window: TemplateWindow) {
        importWindow(window)
        dismiss()
    }
    
    // In TemplateView, update the importWindow method:
    private func importWindow(_ window: TemplateWindow) {
        // Map window type string to WindowType enum
        let windowType: WindowType
        switch window.windowType {
        case "Charts":
            windowType = .charts
        case "Spatial Editor":
            windowType = .spatial
        case "DataFrame Viewer":
            windowType = .column
        case "Model Metric Viewer":
            windowType = .volume  // Now this will work
        default:
            windowType = .spatial
        }
        
        // Create state with all properties
        var state = WindowState()
        if let exportTemplate = ExportTemplate(rawValue: window.exportTemplate) {
            state.exportTemplate = exportTemplate
        }
        state.content = window.content
        state.tags = window.tags
        state.lastModified = Date()
        
        // For DataFrame windows, create sample data
        if windowType == .column {
            state.dataFrameData = DataFrameData(
                columns: ["Sensor_ID", "Temperature", "Humidity", "Status"],
                rows: [
                    ["SENSOR_001", "22.5", "45.2", "Active"],
                    ["SENSOR_002", "23.1", "44.8", "Active"],
                    ["SENSOR_003", "21.9", "46.1", "Inactive"],
                    ["SENSOR_004", "22.8", "45.5", "Active"],
                    ["SENSOR_005", "23.3", "44.3", "Maintenance"]
                ],
                dtypes: [
                    "Sensor_ID": "string",
                    "Temperature": "float",
                    "Humidity": "float",
                    "Status": "string"
                ]
            )
        }
        
        // For Spatial windows with point cloud data
        //if windowType == .spatial && window.title.contains("3D") {
        //    state.pointCloudData = PointCloudDemo.generateSpherePointCloudData(radius: 10.0, points: 500)
        //}
        
        // For volume/metric windows
        if windowType == .volume {
            // Add specific data for volume windows
            state.content = """
            # Model Performance Metrics
            # Generated from template
            
            import numpy as np
            import matplotlib.pyplot as plt
            
            # Sample metrics data
            metrics = {
                'accuracy': 0.94,
                'latency_ms': 125,
                'throughput_rps': 250,
                'memory_mb': 512,
                'cpu_percent': 35
            }
            
            print("Model Metrics:")
            for key, value in metrics.items():
                print(f"{key}: {value}")
            """
        }
        
        // Create the window with full configuration
        let newWindow = windowManager.createWindow(windowType, id: window.windowId, position: window.position)
        
        // Update the window state after creation
        windowManager.updateWindowState(window.windowId, state: state)
        
        // Add a small delay before opening to ensure the window is fully registered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            openWindow(value: window.windowId)
        }
    }
}

// MARK: - Supporting Views with Unique Names

struct TemplateWindowRow: View {
    let window: TemplateView.TemplateWindow
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: iconForWindowType(window.windowType))
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .accentColor)
                    .frame(width: 32)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(window.windowType)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .white : .primary)
                    
                    Text(window.exportTemplate)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    /*
                     // Replace Color.tertiary with: if we have other platforms.
                     #if os(macOS)
                     Color(NSColor.tertiaryLabelColor)
                     #elseif os(iOS) || os(watchOS) || os(tvOS)
                     Color(UIColor.tertiaryLabel)
                     #else
                     Color.gray.opacity(0.3)  // fallback for visionOS or other platforms
                     #endif
               */
                    Text("Window #\(window.windowId)")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.6) : Color.gray.opacity(0.3))
                }
                
                Spacer()
                
                // Tags count
                if !window.tags.isEmpty {
                    Label("\(window.tags.count)", systemImage: "tag")
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    private func iconForWindowType(_ type: String) -> String {
        switch type {
        case "Charts":
            return "chart.line.uptrend.xyaxis"
        case "Spatial Editor":
            return "cube"
        case "DataFrame Viewer":
            return "tablecells"
        case "Model Metric Viewer":
            return "gauge"
        default:
            return "square.stack.3d"
        }
    }
}

struct TemplateMetadataCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TemplateWindowPreviewCard: View {
    let window: TemplateView.TemplateWindow
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: iconForWindowType(window.windowType))
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    
                    Spacer()
                    
                    Text("#\(window.windowId)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Window type
                Text(window.windowType)
                    .font(.headline)
                    .lineLimit(1)
                
                // Template
                Text(window.exportTemplate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                // Content preview
                Text(window.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Tags
                if !window.tags.isEmpty {
                    HStack {
                        Image(systemName: "tag")
                            .font(.caption)
                        Text(window.tags.prefix(2).joined(separator: ", "))
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.tertiary)
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
        case "Charts":
            return "chart.line.uptrend.xyaxis"
        case "Spatial Editor":
            return "cube"
        case "DataFrame Viewer":
            return "tablecells"
        case "Model Metric Viewer":
            return "gauge"
        default:
            return "square.stack.3d"
        }
    }
}

// MARK: - Preview
struct TemplateView_Previews: PreviewProvider {
    static var previews: some View {
        TemplateView()
            .frame(width: 1000, height: 700)
    }
}
