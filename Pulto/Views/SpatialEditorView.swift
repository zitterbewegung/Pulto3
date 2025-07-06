//
//  SpatialEditorView.swift
//  Pulto
//
//  Created by Joshua Herman on 6/19/25.
//  Copyright 2025 Apple. All rights reserved.
//

import SwiftUI
import Charts

///
//  SpatialEditorView.swift
//  Pulto
//
//  Created by Joshua Herman on 6/19/25.
//  Copyright 2025 Apple. All rights reserved.
//

// MARK: - Main View
// Enhanced Spatial Editor View with Point Cloud and Chart Integration
struct SpatialEditorView: View {
    // MARK: – Visualization Types
    enum VisualizationType: Equatable {
        case pointCloud(PointCloudData)
        case chart(ChartVisualizationData)
    }

    struct ChartVisualizationData: Equatable {
        let csvData: CSVData
        var recommendation: ChartRecommendation
        let chartData: ChartData
    }

    // MARK: – Immutable inputs
    let windowID: Int?
    let initialVisualization: VisualizationType?

    // MARK: – State
    @StateObject private var windowManager = WindowTypeManager.shared
    @State private var selectedDemo = 0
    @State private var rotationAngle = 0.0
    @State private var currentVisualization: VisualizationType
    @State private var showControls = false

    @State private var headerPosition: CGSize = .zero
    @State private var parameterControlsPosition: CGSize = .zero
    @State private var demoSelectorPosition: CGSize = .zero
    @State private var visualizationPosition: CGSize = .zero
    @State private var statisticsPosition: CGSize = .zero
    @State private var exportControlsPosition: CGSize = .zero

    @State private var isDraggingHeader = false
    @State private var isDraggingParameters = false
    @State private var isDraggingDemoSelector = false
    @State private var isDraggingVisualization = false
    @State private var isDraggingStatistics = false
    @State private var isDraggingExportControls = false

    // Point-cloud parameters
    @State private var sphereRadius: Double = 10.0
    @State private var spherePoints: Double = 1000
    @State private var torusMajorRadius: Double = 10.0
    @State private var torusMinorRadius: Double = 3.0
    @State private var torusPoints: Double = 2000
    @State private var waveSize: Double = 20.0
    @State private var waveResolution: Double = 50
    @State private var galaxyArms: Double = 3
    @State private var galaxyPoints: Double = 5000
    @State private var cubeSize: Double = 10.0
    @State private var cubePointsPerFace: Double = 500

    // Code sidebar states
    @State private var showCodeSidebar = false
    @State private var generatedCode = ""

    private let demoNames = ["Sphere", "Torus", "Wave Surface", "Spiral Galaxy", "Noisy Cube"]

    // MARK: – Init
    init(windowID: Int? = nil, initialPointCloud: PointCloudData? = nil, initialChart: ChartVisualizationData? = nil) {
        self.windowID = windowID

        if let chart = initialChart {
            self.initialVisualization = .chart(chart)
            _currentVisualization = State(initialValue: .chart(chart))
        } else if let pointCloud = initialPointCloud {
            self.initialVisualization = .pointCloud(pointCloud)
            _currentVisualization = State(initialValue: .pointCloud(pointCloud))
        } else {
            let defaultPointCloud = PointCloudDemo.generateSpherePointCloudData()
            self.initialVisualization = .pointCloud(defaultPointCloud)
            _currentVisualization = State(initialValue: .pointCloud(defaultPointCloud))
        }
    }

    // MARK: – Body
    var body: some View {
        HStack(spacing: 0) {
            // Main Content
            VStack(spacing: 12) {
                headerView

                if showControls {
                    VStack(spacing: 12) {
                        // Toggle between point cloud and chart
                        visualizationTypeSelector

                        switch currentVisualization {
                        case .pointCloud:
                            parameterControlsView
                            demoSelectorView
                        case .chart:
                            chartControlsView
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
                }

                // Main visualization
                switch currentVisualization {
                case .pointCloud:
                    pointCloudVisualizationView
                case .chart(let chartData):
                    chartVisualizationView(chartData: chartData)
                }

                if showControls {
                    VStack(spacing: 12) {
                        statisticsView
                        exportControlsView
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
                }

                Spacer()
            }
            .padding(16)

            // Code Sidebar
            if showCodeSidebar {
                CodeSidebarView(code: generatedCode)
                    .frame(width: 400)
                    .transition(.move(edge: .trailing))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SpatialControlButton(icon: showCodeSidebar ? "chevron.right" : "chevron.left", text: "Code", color: .indigo) {
                    showCodeSidebar.toggle()
                }
            }
        }
        .onKeyPress(.init("h"), phases: .down) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls.toggle()
            }
            return .handled
        }
        .onAppear {
            loadVisualizationFromWindow()
            generateSpatialCode()
            if case .pointCloud = currentVisualization {
                startRotationAnimation()
            }
        }
        .onChange(of: selectedDemo) { _ in
            if case .pointCloud = currentVisualization {
                updatePointCloud()
            }
            generateSpatialCode()
        }
        .onChange(of: currentVisualization) { _, _ in
            generateSpatialCode()
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
                    Label("Spatial Code", systemImage: "cube.transparent")
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
                .background(.regularMaterial)

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

    // Generate spatial code function
    private func generateSpatialCode() {
        switch currentVisualization {
        case .pointCloud(let pointCloud):
            generatedCode = pointCloud.toPythonCode()
        case .chart(let chartData):
            generatedCode = generateChartPythonCode(chartData: chartData)
        }
    }

    // MARK: – Sub-Views
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spatial Visualization Editor")
                    .font(.title2).bold()
                if let windowID {
                    HStack(spacing: 8) {
                        Text("Window #\(windowID)")
                        Text("•")
                        switch currentVisualization {
                        case .pointCloud(let data):
                            Text("\(data.totalPoints) points")
                        case .chart(let data):
                            Text("\(data.chartData.xData.count) data points")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                SpatialControlButton(icon: showCodeSidebar ? "chevron.right" : "chevron.left", text: "Code", color: .indigo) {
                    showCodeSidebar.toggle()
                }

                SpatialControlButton(icon: showControls ? "eye.slash" : "eye", text: showControls ? "Hide Controls" : "Show Controls", color: .blue) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showControls.toggle()
                    }
                }
            }
        }
    }

    // MARK: – New Sub-Views for Chart Support
    private var visualizationTypeSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Visualization Type").font(.subheadline).bold()
            Picker("Type", selection: Binding(
                get: {
                    switch currentVisualization {
                    case .pointCloud: return 0
                    case .chart: return 1
                    }
                },
                set: { newValue in
                    if newValue == 0 {
                        currentVisualization = .pointCloud(PointCloudDemo.generateSpherePointCloudData())
                        startRotationAnimation()
                    } else {
                        // Load chart data from window if available
                        if let windowID = windowID,
                           let chartData = windowManager.getWindowChartData(for: windowID) {
                            // Create dummy CSV data for now
                            let csvData = CSVData(
                                headers: ["X", "Y"],
                                rows: chartData.xData.enumerated().map { ["\($0.element)", "\(chartData.yData[$0.offset])"] },
                                columnTypes: [.numeric, .numeric]
                            )
                            currentVisualization = .chart(ChartVisualizationData(
                                csvData: csvData,
                                recommendation: .lineChart,
                                chartData: chartData
                            ))
                        }
                    }
                }
            )) {
                Text("Point Cloud").tag(0)
                Text("Chart").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    private var chartControlsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Chart Options").font(.subheadline).bold()

            if case .chart(let chartViz) = currentVisualization {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chart Type: \(chartViz.recommendation.name)")
                        .font(.caption)
                    Text("Data Points: \(chartViz.chartData.xData.count)")
                        .font(.caption)
                    Text("X: \(chartViz.chartData.xLabel)")
                        .font(.caption)
                    Text("Y: \(chartViz.chartData.yLabel)")
                        .font(.caption)
                }

                // Chart type selector
                Picker("Chart Type", selection: Binding(
                    get: { chartViz.recommendation },
                    set: { newRecommendation in
                        if case .chart(var viz) = currentVisualization {
                            viz.recommendation = newRecommendation
                            currentVisualization = .chart(viz)
                        }
                    }
                )) {
                    ForEach(ChartRecommendation.allCases, id: \.self) { recommendation in
                        Text(recommendation.name).tag(recommendation)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private func chartVisualizationView(chartData: ChartVisualizationData) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 300)

            // Use the sample chart view from CSVData
            SampleChartView(data: chartData.csvData, recommendation: chartData.recommendation)
                .padding()

            if !showControls {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 2) {
                            Text("Controls Hidden")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Press 'H' or tap eye icon")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                        .opacity(0.7)
                    }
                }
                .padding(12)
            }
        }
    }

    private var parameterControlsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Parameters").font(.subheadline).bold()
            switch selectedDemo {
            case 0: // Sphere
                VStack(alignment: .leading, spacing: 3) {
                    Text("Radius: \(sphereRadius, specifier: "%.1f")").font(.caption)
                    Slider(value: $sphereRadius, in: 5...20) { _ in updatePointCloud() }
                    Text("Points: \(Int(spherePoints))").font(.caption)
                    Slider(value: $spherePoints, in: 100...2000, step: 100) { _ in updatePointCloud() }
                }
            case 1: // Torus
                VStack(alignment: .leading, spacing: 3) {
                    Text("Major Radius: \(torusMajorRadius, specifier: "%.1f")").font(.caption)
                    Slider(value: $torusMajorRadius, in: 5...15) { _ in updatePointCloud() }
                    Text("Minor Radius: \(torusMinorRadius, specifier: "%.1f")").font(.caption)
                    Slider(value: $torusMinorRadius, in: 1...8) { _ in updatePointCloud() }
                    Text("Points: \(Int(torusPoints))").font(.caption)
                    Slider(value: $torusPoints, in: 500...5000, step: 100) { _ in updatePointCloud() }
                }
            case 2: // Wave Surface
                VStack(alignment: .leading, spacing: 3) {
                    Text("Size: \(waveSize, specifier: "%.1f")").font(.caption)
                    Slider(value: $waveSize, in: 10...30) { _ in updatePointCloud() }
                    Text("Resolution: \(Int(waveResolution))").font(.caption)
                    Slider(value: $waveResolution, in: 20...80, step: 10) { _ in updatePointCloud() }
                }
            case 3: // Spiral Galaxy
                VStack(alignment: .leading, spacing: 3) {
                    Text("Arms: \(Int(galaxyArms))").font(.caption)
                    Slider(value: $galaxyArms, in: 2...6, step: 1) { _ in updatePointCloud() }
                    Text("Points: \(Int(galaxyPoints))").font(.caption)
                    Slider(value: $galaxyPoints, in: 1000...10000, step: 500) { _ in updatePointCloud() }
                }
            case 4: // Noisy Cube
                VStack(alignment: .leading, spacing: 3) {
                    Text("Size: \(cubeSize, specifier: "%.1f")").font(.caption)
                    Slider(value: $cubeSize, in: 5...20) { _ in updatePointCloud() }
                    Text("Points per Face: \(Int(cubePointsPerFace))").font(.caption)
                    Slider(value: $cubePointsPerFace, in: 100...1000, step: 50) { _ in updatePointCloud() }
                }
            default:
                EmptyView()
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var demoSelectorView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Point Cloud Type").font(.subheadline).bold()
            Picker("Select Data", selection: $selectedDemo) {
                ForEach(demoNames.indices, id: \.self) { index in
                    Text(demoNames[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    private var pointCloudVisualizationView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 300)

            GeometryReader { _ in
                Canvas { ctx, size in
                    if case .pointCloud(let pointCloud) = currentVisualization {
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        let scale = min(size.width, size.height) / 40
                        let θ = rotationAngle * .pi / 180

                        for p in pointCloud.points {
                            // Y-axis rotation
                            let xR = p.x * cos(θ) - p.z * sin(θ)
                            let zR = p.x * sin(θ) + p.z * cos(θ)
                            // 2-D projection
                            let plotX = center.x + xR * scale
                            let plotY = center.y - p.y * scale
                            // Size + color
                            let sz = 2.0 + (zR + 20) / 20
                            let intensity = p.intensity ?? ((p.z + 10) / 20)
                            let col = Color(hue: 0.6 - intensity * 0.4,
                                            saturation: 0.8,
                                            brightness: 0.9)
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: plotX - sz/2,
                                                       y: plotY - sz/2,
                                                       width: sz,
                                                       height: sz)),
                                with: .color(col.opacity(0.8))
                            )
                        }
                    }
                }
            }
            .frame(height: 300)

            if !showControls {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 2) {
                            Text("Controls Hidden")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Press 'H' or tap eye icon")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                        .opacity(0.7)
                    }
                }
                .padding(12)
            }
        }
    }

    // MARK: – Modified Statistics View
    private var statisticsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Statistics").font(.subheadline).bold()

            switch currentVisualization {
            case .pointCloud(let pointCloud):
                HStack {
                    Label("\(pointCloud.totalPoints) points", systemImage: "circle.grid.3x3.fill")
                    Spacer()
                    Label(String(format: "%.1f°", rotationAngle.truncatingRemainder(dividingBy: 360)), systemImage: "rotate.3d")
                }
                .font(.caption2).foregroundColor(.secondary)

                if !pointCloud.parameters.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Parameters:").font(.caption2).bold()
                        ForEach(pointCloud.parameters.keys.sorted(), id: \.self) { key in
                            Text("\(key): \(pointCloud.parameters[key] ?? 0, specifier: "%.1f")")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }

            case .chart(let chartData):
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Label("\(chartData.chartData.xData.count) data points", systemImage: "chart.dots.scatter")
                        Spacer()
                        Image(systemName: chartData.recommendation.icon)
                            .foregroundColor(.blue)
                    }
                    .font(.caption2).foregroundColor(.secondary)

                    Text("Chart: \(chartData.recommendation.name)")
                        .font(.caption2).bold()
                    Text("X: \(chartData.chartData.xLabel)")
                        .font(.caption2).foregroundColor(.secondary)
                    Text("Y: \(chartData.chartData.yLabel)")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var exportControlsView: some View {
        VStack(spacing: 8) {
            Text("Export Options").font(.subheadline).bold()
            HStack(spacing: 8) {
                ExportButton(title: "Save to Window", icon: "square.and.arrow.down", color: .blue) {
                    saveToWindow()
                }
                ExportButton(title: "Export to Jupyter", icon: "doc.text", color: .green) {
                    exportToJupyter()
                }
            }
            ExportButton(title: "Copy Python Code", icon: "doc.on.doc", color: .orange) {
                copyPythonCode()
            }
        }
    }

    // MARK: – Helpers
    private func loadVisualizationFromWindow() {
        guard let windowID = windowID else { return }

        // Try to load chart data first
        if let chartData = windowManager.getWindowChartData(for: windowID) {
            // Create visualization from chart data
            let csvData = CSVData(
                headers: ["Index", chartData.xLabel, chartData.yLabel],
                rows: chartData.xData.enumerated().map { index, xValue in
                    ["\(index)", "\(xValue)", "\(chartData.yData[index])"]
                },
                columnTypes: [.numeric, .numeric, .numeric]
            )

            // Determine best chart type based on data
            let recommendation: ChartRecommendation = {
                switch chartData.chartType.lowercased() {
                case "line chart": return .lineChart
                case "bar chart": return .barChart
                case "scatter plot": return .scatterPlot
                case "pie chart": return .pieChart
                case "area chart": return .areaChart
                case "histogram": return .histogram
                default: return .lineChart
                }
            }()

            currentVisualization = .chart(ChartVisualizationData(
                csvData: csvData,
                recommendation: recommendation,
                chartData: chartData
            ))
        } else if let pointCloud = windowManager.getWindowPointCloud(for: windowID) {
            // Fall back to point cloud
            currentVisualization = .pointCloud(pointCloud)
            if let idx = demoNames.firstIndex(where: { pointCloud.demoType.lowercased().contains($0.lowercased()) }) {
                selectedDemo = idx
            }
        }
    }

    private func updatePointCloud() {
        switch selectedDemo {
        case 0:
            currentVisualization = .pointCloud(PointCloudDemo.generateSpherePointCloudData(
                radius: sphereRadius,
                points: Int(spherePoints)))
        case 1:
            currentVisualization = .pointCloud(PointCloudDemo.generateTorusPointCloudData(
                majorRadius: torusMajorRadius,
                minorRadius: torusMinorRadius,
                points: Int(torusPoints)))
        case 2:
            currentVisualization = .pointCloud(PointCloudDemo.generateWaveSurfaceData(
                size: waveSize,
                resolution: Int(waveResolution)))
        case 3:
            currentVisualization = .pointCloud(PointCloudDemo.generateSpiralGalaxyData(
                arms: Int(galaxyArms),
                points: Int(galaxyPoints)))
        case 4:
            currentVisualization = .pointCloud(PointCloudDemo.generateNoisyCubeData(
                size: cubeSize,
                pointsPerFace: Int(cubePointsPerFace)))
        default: break
        }
    }

    private func startRotationAnimation() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }

    private func saveToWindow() {
        guard let windowID = windowID else { return }

        switch currentVisualization {
        case .pointCloud(let pointCloud):
            windowManager.updateWindowPointCloud(windowID, pointCloud: pointCloud)
            windowManager.updateWindowContent(windowID, content: pointCloud.toPythonCode())
            print(" Point cloud saved to window #\(windowID)")

        case .chart(let chartData):
            windowManager.updateWindowChartData(windowID, chartData: chartData.chartData)
            let pythonCode = generateChartPythonCode(chartData: chartData)
            windowManager.updateWindowContent(windowID, content: pythonCode)
            print(" Chart saved to window #\(windowID)")
        }
    }

    private func exportToJupyter() {
        let code: String
        let name: String

        switch currentVisualization {
        case .pointCloud(let pointCloud):
            code = pointCloud.toPythonCode()
            name = "pointcloud_\(pointCloud.demoType)_\(Date().timeIntervalSince1970).py"

        case .chart(let chartData):
            code = generateChartPythonCode(chartData: chartData)
            name = "chart_\(chartData.recommendation.name.replacingOccurrences(of: " ", with: "_"))_\(Date().timeIntervalSince1970).py"
        }

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = docs.appendingPathComponent(name)
        do {
            try code.write(to: url, atomically: true, encoding: .utf8)
            print(" Exported to: \(url.path)")
        } catch {
            print(" Error: \(error)")
        }
        saveToWindow()
    }

    private func copyPythonCode() {
        let code: String

        switch currentVisualization {
        case .pointCloud(let pointCloud):
            code = pointCloud.toPythonCode()

        case .chart(let chartData):
            code = generateChartPythonCode(chartData: chartData)
        }

        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        print(" Python code copied to clipboard")
        #endif
    }

    private func generateChartPythonCode(chartData: ChartVisualizationData) -> String {
        var pythonCode = """
        # Chart Visualization
        # Type: \(chartData.recommendation.name)
        # Generated from Spatial Editor
        
        import matplotlib.pyplot as plt
        import numpy as np
        import pandas as pd
        
        # Data
        x_data = \(chartData.chartData.xData)
        y_data = \(chartData.chartData.yData)
        
        # Create figure
        plt.figure(figsize=(10, 6))
        
        """

        switch chartData.recommendation {
        case .lineChart:
            pythonCode += """
            plt.plot(x_data, y_data, marker='o', linewidth=2, markersize=6)
            plt.xlabel('\(chartData.chartData.xLabel)')
            plt.ylabel('\(chartData.chartData.yLabel)')
            """

        case .barChart:
            pythonCode += """
            plt.bar(range(len(y_data)), y_data)
            plt.xlabel('\(chartData.chartData.xLabel)')
            plt.ylabel('\(chartData.chartData.yLabel)')
            plt.xticks(range(len(x_data)), [str(x) for x in x_data], rotation=45)
            """

        case .scatterPlot:
            pythonCode += """
            plt.scatter(x_data, y_data, alpha=0.6, s=50)
            plt.xlabel('\(chartData.chartData.xLabel)')
            plt.ylabel('\(chartData.chartData.yLabel)')
            """

        case .pieChart:
            pythonCode += """
            plt.pie(y_data, labels=[str(x) for x in x_data], autopct='%1.1f%%')
            plt.axis('equal')
            """

        case .areaChart:
            pythonCode += """
            plt.fill_between(range(len(x_data)), y_data, alpha=0.4)
            plt.plot(range(len(x_data)), y_data, linewidth=2)
            plt.xlabel('\(chartData.chartData.xLabel)')
            plt.ylabel('\(chartData.chartData.yLabel)')
            """

        case .histogram:
            pythonCode += """
            plt.hist(y_data, bins=20, alpha=0.7, edgecolor='black')
            plt.xlabel('\(chartData.chartData.yLabel)')
            plt.ylabel('Frequency')
            """
        }

        pythonCode += """
        
        plt.title('\(chartData.chartData.title)')
        plt.grid(True, alpha=0.3)
        plt.tight_layout()
        
        # Display the plot
        plt.show()
        
        # Chart Statistics
        print("Chart Statistics:")
        print("-" * 40)
        print(f"Chart Type: \(chartData.recommendation.name)")
        print(f"Data Points: {len(x_data)}")
        print(f"X Range: [{min(x_data):.2f}, {max(x_data):.2f}]")
        print(f"Y Range: [{min(y_data):.2f}, {max(y_data):.2f}]")
        print(f"Y Mean: {np.mean(y_data):.2f}")
        print(f"Y Std Dev: {np.std(y_data):.2f}")
        
        # Save options (uncomment to use)
        # plt.savefig('chart_\(chartData.recommendation.name.lowercased().replacingOccurrences(of: " ", with: "_")).png', dpi=300, bbox_inches='tight')
        # plt.savefig('chart_\(chartData.recommendation.name.lowercased().replacingOccurrences(of: " ", with: "_")).pdf', bbox_inches='tight')
        """

        return pythonCode
    }
}

// MARK: – Preview
struct SpatialControlButton: View {
    let icon: String
    let text: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(text)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(isHovered ? 0.15 : 0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(color.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
                }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ExportButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(8)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(isHovered ? 0.15 : 0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(color.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
                }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
#Preview {
    SpatialEditorView()
        .frame(width: 800, height: 600)
}