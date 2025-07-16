//
//  SpatialEditorView.swift
//  Pulto
//
//  Enhanced with all visualization types
//

import SwiftUI
import Charts
import RealityKit

// MARK: - Conditional Equatable Extensions
// Only add these if the types don't already conform to Equatable

#if !os(visionOS) // Adjust this based on your platform needs
// Add Equatable conformance for data types that might be missing
extension Point3D: Equatable {
    static func == (lhs: Point3D, rhs: Point3D) -> Bool {
        lhs.x == rhs.x &&
        lhs.y == rhs.y &&
        lhs.z == rhs.z
    }
}

extension Vertex3D: Equatable {
    static func == (lhs: Vertex3D, rhs: Vertex3D) -> Bool {
        lhs.x == rhs.x &&
        lhs.y == rhs.y &&
        lhs.z == rhs.z
    }
}

extension Face3D: Equatable {
    static func == (lhs: Face3D, rhs: Face3D) -> Bool {
        lhs.vertices == rhs.vertices &&
        lhs.materialIndex == rhs.materialIndex
    }
}

extension Material3D: Equatable {
    static func == (lhs: Material3D, rhs: Material3D) -> Bool {
        lhs.name == rhs.name &&
        lhs.color == rhs.color &&
        lhs.metallic == rhs.metallic &&
        lhs.roughness == rhs.roughness
    }
}

extension PointCloudPoint: Equatable {
    static func == (lhs: PointCloudPoint, rhs: PointCloudPoint) -> Bool {
        lhs.x == rhs.x &&
        lhs.y == rhs.y &&
        lhs.z == rhs.z &&
        lhs.intensity == rhs.intensity
    }
}

extension PointCloudData: Equatable {
    static func == (lhs: PointCloudData, rhs: PointCloudData) -> Bool {
        lhs.totalPoints == rhs.totalPoints &&
        lhs.demoType == rhs.demoType &&
        lhs.points.count == rhs.points.count
    }
}

extension ChartData: Equatable {
    static func == (lhs: ChartData, rhs: ChartData) -> Bool {
        lhs.title == rhs.title &&
        lhs.chartType == rhs.chartType &&
        lhs.xLabel == rhs.xLabel &&
        lhs.yLabel == rhs.yLabel &&
        lhs.xData == rhs.xData &&
        lhs.yData == rhs.yData
    }
}

extension ChartRecommendation: Equatable {}

extension ColumnType: Equatable {
    static func == (lhs: ColumnType, rhs: ColumnType) -> Bool {
        switch (lhs, rhs) {
        case (.numeric, .numeric), (.categorical, .categorical), (.date, .date), (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
}

extension CSVData: Equatable {
    static func == (lhs: CSVData, rhs: CSVData) -> Bool {
        lhs.headers == rhs.headers &&
        lhs.rows == rhs.rows &&
        lhs.columnTypes == rhs.columnTypes
    }
}

extension Model3DData: Equatable {
    static func == (lhs: Model3DData, rhs: Model3DData) -> Bool {
        lhs.title == rhs.title &&
        lhs.modelType == rhs.modelType &&
        lhs.vertices.count == rhs.vertices.count &&
        lhs.faces.count == rhs.faces.count
    }
}

extension DataFrameData: Equatable {
    static func == (lhs: DataFrameData, rhs: DataFrameData) -> Bool {
        lhs.columns == rhs.columns &&
        lhs.rows == rhs.rows &&
        lhs.dtypes == rhs.dtypes
    }
}

// Add Equatable conformance for SpatialDataItem
extension SpatialDataItem: Equatable {
    static func == (lhs: SpatialDataItem, rhs: SpatialDataItem) -> Bool {
        lhs.dataType == rhs.dataType &&
        lhs.pointCount == rhs.pointCount &&
        lhs.dimensions == rhs.dimensions
    }
}
#endif

// MARK: - Enhanced Main View
struct SpatialEditorView: View {
    // MARK: – Enhanced Visualization Types
    enum VisualizationType: String, CaseIterable, Identifiable {
        case pointCloud = "Point Cloud"
        case chart2D = "2D Chart"
        case chart3D = "3D Chart"
        case dataTable = "Data Table"
        case model3D = "3D Model"
        case volumetric = "Volumetric"
        case notebook = "Notebook"
        case spatial = "Spatial Data"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .pointCloud: return "circle.grid.3x3.fill"
            case .chart2D: return "chart.xyaxis.line"
            case .chart3D: return "cube.transparent"
            case .dataTable: return "tablecells"
            case .model3D: return "cube.fill"
            case .volumetric: return "cube.transparent.fill"
            case .notebook: return "doc.text"
            case .spatial: return "location.square"
            }
        }

        var description: String {
            switch self {
            case .pointCloud: return "Visualize point cloud data in 3D space"
            case .chart2D: return "Create 2D charts from tabular data"
            case .chart3D: return "Generate 3D charts and surfaces"
            case .dataTable: return "View and edit tabular data"
            case .model3D: return "Import and view 3D models"
            case .volumetric: return "Create volumetric visualizations"
            case .notebook: return "Jupyter notebook integration"
            case .spatial: return "Spatial data visualization"
            }
        }
    }

    // MARK: – Visualization Data Wrappers
    enum VisualizationData: Equatable {
        case pointCloud(PointCloudData)
        case chart2D(ChartVisualizationData)
        case chart3D(Chart3DData)
        case dataTable(DataFrameData)
        case model3D(Model3DData)
        case volumetric(VolumetricData)
        case notebook(NotebookData)
        case spatial(SpatialDataItem)

        static func == (lhs: VisualizationData, rhs: VisualizationData) -> Bool {
            switch (lhs, rhs) {
            case (.pointCloud(let l), .pointCloud(let r)): return l == r
            case (.chart2D(let l), .chart2D(let r)): return l == r
            case (.chart3D(let l), .chart3D(let r)): return l == r
            case (.dataTable(let l), .dataTable(let r)): return l == r
            case (.model3D(let l), .model3D(let r)): return l == r
            case (.volumetric(let l), .volumetric(let r)): return l == r
            case (.notebook(let l), .notebook(let r)): return l == r
            //case (.spatial(let l), .spatial(let r)): return l == r
            default: return false
            }
        }
    }

    struct ChartVisualizationData: Equatable {
        let csvData: CSVData
        var recommendation: ChartRecommendation
        let chartData: ChartData
    }

    struct VolumetricData: Equatable {
        let id: String
        let title: String
        let data: Data?

        static func == (lhs: VolumetricData, rhs: VolumetricData) -> Bool {
            lhs.id == rhs.id && lhs.title == rhs.title
        }
    }

    struct NotebookData: Equatable {
        var cells: [String]
        let metadata: [String: String]
    }

    // MARK: – Properties
    let windowID: Int?
    let initialVisualization: VisualizationData?

    @StateObject private var windowManager = WindowTypeManager.shared
    @State private var selectedVisualizationType: VisualizationType = .pointCloud
    @State private var currentVisualization: VisualizationData
    @State private var showControls = false
    @State private var showImportSheet = false
    @State private var showCodeSidebar = false
    @State private var generatedCode = ""

    // Animation states
    @State private var rotationAngle = 0.0

    // Demo selector for different types
    @State private var selectedDemo = 0
    @State private var demoNames: [String] = []

    // MARK: – Init
    init(windowID: Int? = nil, initialVisualization: VisualizationData? = nil) {
        self.windowID = windowID
        self.initialVisualization = initialVisualization

        // Set initial visualization
        if let initial = initialVisualization {
            _currentVisualization = State(initialValue: initial)

            // Set the correct type based on initial data
            switch initial {
            case .pointCloud: _selectedVisualizationType = State(initialValue: .pointCloud)
            case .chart2D: _selectedVisualizationType = State(initialValue: .chart2D)
            case .chart3D: _selectedVisualizationType = State(initialValue: .chart3D)
            case .dataTable: _selectedVisualizationType = State(initialValue: .dataTable)
            case .model3D: _selectedVisualizationType = State(initialValue: .model3D)
            case .volumetric: _selectedVisualizationType = State(initialValue: .volumetric)
            case .notebook: _selectedVisualizationType = State(initialValue: .notebook)
            case .spatial: _selectedVisualizationType = State(initialValue: .spatial)
            }
        } else {
            let defaultPointCloud = PointCloudDemo.generateSpherePointCloudData()
            _currentVisualization = State(initialValue: .pointCloud(defaultPointCloud))
        }
    }

    // MARK: – Body
    var body: some View {
        HStack(spacing: 0) {
            // Main Content
            VStack(spacing: 12) {
                //headerView

                if showControls {
                    VStack(spacing: 12) {
                        //visualizationTypeSelectorEnhanced
                        controlsForCurrentType
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
                }

                // Main visualization
                visualizationContent

                if showControls {
                    VStack(spacing: 12) {
                        //statisticsView
                        //exportControlsView
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
                HStack(spacing: 8) {
                    Button(action: { showImportSheet = true }) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title3)
                    }

                    Button(action: { showCodeSidebar.toggle() }) {
                        Image(systemName: showCodeSidebar ? "chevron.right" : "chevron.left")
                            .font(.title3)
                    }
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
            generateCode()
            updateDemoNames()
        }
        .onChange(of: selectedVisualizationType) { _, newType in
            switchToVisualizationType(newType)
        }
        .onChange(of: currentVisualization) { _, _ in
            generateCode()
        }
        .sheet(isPresented: $showImportSheet) {
            UniversalImportSheet(
                currentType: selectedVisualizationType,
                onDataImported: { visualizationData in
                    currentVisualization = visualizationData
                    showImportSheet = false
                }
            )
        }
        .animation(.easeInOut(duration: 0.3), value: showCodeSidebar)
    }

    // MARK: - Enhanced Visualization Type Selector
    private var visualizationTypeSelectorEnhanced: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visualization Type")
                .font(.subheadline)
                .bold()

            // Grid of visualization types
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(VisualizationType.allCases) { type in
                    VisualizationTypeCard(
                        type: type,
                        isSelected: selectedVisualizationType == type,
                        action: {
                            selectedVisualizationType = type
                        }
                    )
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Visualization Type Card
    private struct VisualizationTypeCard: View {
        let type: VisualizationType
        let isSelected: Bool
        let action: () -> Void
        @State private var isHovered = false

        var body: some View {
            Button(action: action) {
                VStack(spacing: 6) {
                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .blue)

                    Text(type.rawValue)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? .white : .primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .padding(8)
            }
            .buttonStyle(.plain)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? Color.blue : (isHovered ? Color.blue.opacity(0.5) : Color.clear),
                                lineWidth: 2
                            )
                    }
            }
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }

    // MARK: - Controls for Current Type
    @ViewBuilder
    private var controlsForCurrentType: some View {
        switch selectedVisualizationType {
        case .pointCloud:
            pointCloudControls

        case .chart2D:
            chart2DControls

        case .chart3D:
            chart3DControls

        case .dataTable:
            dataTableControls

        case .model3D:
            model3DControls

        case .volumetric:
            volumetricControls

        case .notebook:
            notebookControls

        case .spatial:
            spatialDataControls
        }
    }

    // MARK: - Visualization Content
    @ViewBuilder
    private var visualizationContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 400)

            switch currentVisualization {
            case .pointCloud(let data):
                pointCloudVisualizationView(data: data)

            case .chart2D(let data):
                chart2DVisualizationView(data: data)

            case .chart3D(let data):
                chart3DVisualizationView(data: data)

            case .dataTable(let data):
                dataTableVisualizationView(data: data)

            case .model3D(let data):
                model3DVisualizationView(data: data)

            case .volumetric(let data):
                volumetricVisualizationView(data: data)

            case .notebook(let data):
                notebookVisualizationView(data: data)

            case .spatial(let data):
                spatialVisualizationView(data: data)
            }

            // Hidden controls hint
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

    // MARK: - Individual Control Views

    private var pointCloudControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Point cloud specific controls (parameters, demo selector, etc.)
            // This is already implemented in your original code
            Text("Point Cloud Controls")
                .font(.subheadline).bold()

            // Add demo selector
            Picker("Demo", selection: $selectedDemo) {
                ForEach(demoNames.indices, id: \.self) { index in
                    Text(demoNames[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var chart2DControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2D Chart Controls")
                .font(.subheadline).bold()

            if case .chart2D(let chartViz) = currentVisualization {
                // Chart type selector
                Picker("Chart Type", selection: Binding(
                    get: { chartViz.recommendation },
                    set: { newRecommendation in
                        if case .chart2D(var viz) = currentVisualization {
                            viz.recommendation = newRecommendation
                            currentVisualization = .chart2D(viz)
                        }
                    }
                )) {
                    ForEach(ChartRecommendation.allCases, id: \.self) { recommendation in
                        Text(recommendation.name).tag(recommendation)
                    }
                }
                .pickerStyle(MenuPickerStyle())

                // Data info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Data Points: \(chartViz.chartData.xData.count)")
                        .font(.caption)
                    Text("X: \(chartViz.chartData.xLabel)")
                        .font(.caption)
                    Text("Y: \(chartViz.chartData.yLabel)")
                        .font(.caption)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var chart3DControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3D Chart Controls")
                .font(.subheadline).bold()

            Button("Generate Sample 3D Data") {
                currentVisualization = .chart3D(Chart3DData.defaultData())
            }
            .buttonStyle(.bordered)

            if case .chart3D(let data) = currentVisualization {
                Text("Points: \(data.points.count)")
                    .font(.caption)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var dataTableControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Table Controls")
                .font(.subheadline).bold()

            if case .dataTable(let data) = currentVisualization {
                HStack {
                    Text("Rows: \(data.rows.count)")
                    Text("Columns: \(data.columns.count)")
                }
                .font(.caption)

                Button("Load Sample Data") {
                    loadSampleDataTable()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var model3DControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3D Model Controls")
                .font(.subheadline).bold()

            HStack(spacing: 8) {
                Button("Load Sphere") {
                    loadSample3DModel(type: "sphere")
                }
                .buttonStyle(.bordered)

                Button("Load Cube") {
                    loadSample3DModel(type: "cube")
                }
                .buttonStyle(.bordered)

                Button("Load Torus") {
                    loadSample3DModel(type: "torus")
                }
                .buttonStyle(.bordered)
            }

            if case .model3D(let model) = currentVisualization {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Type: \(model.modelType)")
                        .font(.caption)
                    Text("Vertices: \(model.vertices.count)")
                        .font(.caption)
                    Text("Faces: \(model.faces.count)")
                        .font(.caption)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var volumetricControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Volumetric Controls")
                .font(.subheadline).bold()

            Button("Generate Volumetric Data") {
                loadSampleVolumetricData()
            }
            .buttonStyle(.bordered)

            Text("Volumetric rendering for immersive spaces")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var notebookControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notebook Controls")
                .font(.subheadline).bold()

            Button("Create New Cell") {
                if case .notebook(var data) = currentVisualization {
                    data.cells.append("# New cell\nprint('Hello from Spatial Editor')")
                    currentVisualization = .notebook(data)
                }
            }
            .buttonStyle(.bordered)

            if case .notebook(let data) = currentVisualization {
                Text("Cells: \(data.cells.count)")
                    .font(.caption)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var spatialDataControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spatial Data Controls")
                .font(.subheadline).bold()

            if case .spatial(let item) = currentVisualization {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Type: \(item.dataType.rawValue)")
                        .font(.caption)
                    Text("Points: \(item.pointCount)")
                        .font(.caption)
                    Text("Dimensions: \(String(format: "%.1f x %.1f x %.1f", item.dimensions.x, item.dimensions.y, item.dimensions.z))")
                        .font(.caption)
                }
            }

            Button("Load Sample Spatial Data") {
                loadSampleSpatialData()
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Individual Visualization Views

    private func pointCloudVisualizationView(data: PointCloudData) -> some View {
        // Your existing point cloud visualization
        GeometryReader { _ in
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let scale = min(size.width, size.height) / 40
                let θ = rotationAngle * .pi / 180

                for p in data.points {
                    let xR = p.x * cos(θ) - p.z * sin(θ)
                    let zR = p.x * sin(θ) + p.z * cos(θ)
                    let plotX = center.x + xR * scale
                    let plotY = center.y - p.y * scale
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
        .onAppear {
            startRotationAnimation()
        }
    }

    private func chart2DVisualizationView(data: ChartVisualizationData) -> some View {
        SampleChartView(data: data.csvData, recommendation: data.recommendation)
            .padding()
    }

    private func chart3DVisualizationView(data: Chart3DData) -> some View {
        VStack {
            Image(systemName: "cube.transparent")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("3D Chart Visualization")
                .font(.headline)

            Text("\(data.points.count) points")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func dataTableVisualizationView(data: DataFrameData) -> some View {
        VStack(spacing: 0) {
            // Simple table preview
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    // Headers
                    HStack(spacing: 0) {
                        ForEach(data.columns, id: \.self) { column in
                            Text(column)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(8)
                                .frame(width: 100)
                                .background(Color.gray.opacity(0.2))
                                .border(Color.gray.opacity(0.3), width: 0.5)
                        }
                    }

                    // Rows (show first 5)
                    ForEach(data.rows.prefix(5).indices, id: \.self) { rowIndex in
                        HStack(spacing: 0) {
                            ForEach(data.columns.indices, id: \.self) { colIndex in
                                Text(rowIndex < data.rows.count && colIndex < data.rows[rowIndex].count
                                     ? data.rows[rowIndex][colIndex]
                                     : "")
                                    .font(.caption)
                                    .padding(8)
                                    .frame(width: 100)
                                    .border(Color.gray.opacity(0.3), width: 0.5)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 200)

            Text("Showing \(min(5, data.rows.count)) of \(data.rows.count) rows")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
    }

    private func model3DVisualizationView(data: Model3DData) -> some View {
        VStack {
            // Simple 3D preview
            Image(systemName: "cube.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .rotationEffect(.degrees(rotationAngle))

            Text(data.title)
                .font(.headline)

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Type: \(data.modelType)")
                    Text("Vertices: \(data.vertices.count)")
                    Text("Faces: \(data.faces.count)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .onAppear {
            startRotationAnimation()
        }
    }

    private func volumetricVisualizationView(data: VolumetricData) -> some View {
        VStack {
            Image(systemName: "cube.transparent.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            Text(data.title)
                .font(.headline)

            Text("Volumetric visualization")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func notebookVisualizationView(data: NotebookData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(data.cells.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("[\(index + 1)]")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        Text(data.cells[index])
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            .padding()
        }
    }

    private func spatialVisualizationView(data: SpatialDataItem) -> some View {
        VStack {
            Image(systemName: "location.square.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Spatial Data: \(data.dataType.rawValue)")
                .font(.headline)

            VStack(alignment: .leading) {
                Text("Points: \(data.pointCount)")
                Text("Dimensions: \(String(format: "%.1f x %.1f x %.1f", data.dimensions.x, data.dimensions.y, data.dimensions.z))")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Helper Methods

    private func switchToVisualizationType(_ type: VisualizationType) {
        switch type {
        case .pointCloud:
            currentVisualization = .pointCloud(PointCloudDemo.generateSpherePointCloudData())

        case .chart2D:
            let sampleCSV = CSVData(
                headers: ["X", "Y"],
                rows: (0..<10).map { ["\($0)", "\($0 * $0)"] },
                columnTypes: [.numeric, .numeric]
            )
            let chartData = ChartData(
                title: "Sample 2D Chart",
                chartType: "Line Chart",
                xLabel: "X",
                yLabel: "Y",
                xData: Array(0..<10).map { Double($0) },
                yData: Array(0..<10).map { Double($0 * $0) },
                color: "blue",
                style: "solid"
            )
            currentVisualization = .chart2D(ChartVisualizationData(
                csvData: sampleCSV,
                recommendation: .lineChart,
                chartData: chartData
            ))

        case .chart3D:
            currentVisualization = .chart3D(Chart3DData.defaultData())

        case .dataTable:
            loadSampleDataTable()

        case .model3D:
            loadSample3DModel(type: "sphere")

        case .volumetric:
            loadSampleVolumetricData()

        case .notebook:
            currentVisualization = .notebook(NotebookData(
                cells: ["# Sample Notebook\nprint('Hello from Spatial Editor')"],
                metadata: ["kernel": "python3", "created": Date().description]
            ))

        case .spatial:
            loadSampleSpatialData()
        }

        updateDemoNames()
    }

    private func updateDemoNames() {
        switch selectedVisualizationType {
        case .pointCloud:
            demoNames = ["Sphere", "Torus", "Wave Surface", "Spiral Galaxy", "Noisy Cube"]
        case .chart2D:
            demoNames = ["Line", "Bar", "Scatter", "Pie", "Area"]
        case .chart3D:
            demoNames = ["Surface", "Scatter3D", "Mesh", "Contour"]
        case .model3D:
            demoNames = ["Sphere", "Cube", "Cylinder", "Torus", "Pyramid"]
        default:
            demoNames = []
        }
    }

    private func loadSampleDataTable() {
        let sampleData = DataFrameData(
            columns: ["Name", "Age", "City", "Salary"],
            rows: [
                ["Alice", "28", "New York", "75000"],
                ["Bob", "35", "San Francisco", "95000"],
                ["Charlie", "42", "Austin", "68000"],
                ["Diana", "31", "Seattle", "82000"]
            ],
            dataTypes: ["Name": "string", "Age": "int", "City": "string", "Salary": "float"]
        )
        currentVisualization = .dataTable(sampleData)
    }

    private func loadSample3DModel(type: String) {
        let model: Model3DData
        switch type {
        case "sphere":
            model = Model3DData(title: "Sphere Model", modelType: "sphere")
        case "cube":
            model = Model3DData(title: "Cube Model", modelType: "cube")
        case "torus":
            model = Model3DData.generateTestTorus()
        default:
            model = Model3DData.generateTestPyramid()
        }
        currentVisualization = .model3D(model)
    }

    private func loadSampleVolumetricData() {
        currentVisualization = .volumetric(VolumetricData(
            id: UUID().uuidString,
            title: "Sample Volumetric Data",
            data: nil
        ))
    }

    private func loadSampleSpatialData() {
        currentVisualization = .spatial(SpatialDataItem(
            dataType: .pointCloud,
            rawData: Data(),
            dimensions: SIMD3<Float>(10, 10, 10),
            pointCount: 1000,
            metadata: ["source": "spatial_editor", "created": Date().description]
        ))
    }

    private func startRotationAnimation() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }

    private func generateCode() {
        switch currentVisualization {
        case .pointCloud(let data):
            generatedCode = data.toPythonCode()

        case .chart2D(let data):
            generatedCode = generateChart2DPythonCode(data: data)

        case .chart3D(let data):
            generatedCode = generate3DChartPythonCode(data: data)

        case .dataTable(let data):
            generatedCode = generateDataTablePythonCode(data: data)

        case .model3D(let data):
            generatedCode = generate3DModelPythonCode(data: data)

        case .volumetric(let data):
            generatedCode = generateVolumetricPythonCode(data: data)

        case .notebook(let data):
            generatedCode = generateNotebookPythonCode(data: data)

        case .spatial(let data):
            generatedCode = generateSpatialPythonCode(data: data)
        }
    }

    // MARK: - Code Generation Methods

    private func generateChart2DPythonCode(data: ChartVisualizationData) -> String {
        return """
        # 2D Chart Visualization
        # Type: \(data.recommendation.name)
        
        import matplotlib.pyplot as plt
        import numpy as np
        
        # Data
        x_data = \(data.chartData.xData)
        y_data = \(data.chartData.yData)
        
        # Create figure
        plt.figure(figsize=(10, 6))
        
        # Plot based on chart type
        \(getPlotCode(for: data.recommendation, xLabel: data.chartData.xLabel, yLabel: data.chartData.yLabel))
        
        plt.title('\(data.chartData.title)')
        plt.grid(True, alpha=0.3)
        plt.tight_layout()
        plt.show()
        """
    }

    private func generate3DChartPythonCode(data: Chart3DData) -> String {
        return """
        # 3D Chart Visualization
        
        import numpy as np
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d import Axes3D
        
        # Data points
        points = \(data.points.map { [$0.x, $0.y, $0.z] })
        
        fig = plt.figure(figsize=(10, 8))
        ax = fig.add_subplot(111, projection='3d')
        
        # Extract coordinates
        x = [p[0] for p in points]
        y = [p[1] for p in points]
        z = [p[2] for p in points]
        
        # Create scatter plot
        ax.scatter(x, y, z, c=z, cmap='viridis', marker='o')
        
        ax.set_xlabel('X')
        ax.set_ylabel('Y')
        ax.set_zlabel('Z')
        ax.set_title('3D Chart Visualization')
        
        plt.show()
        """
    }

    private func generateDataTablePythonCode(data: DataFrameData) -> String {
        return """
        # Data Table Visualization
        
        import pandas as pd
        import matplotlib.pyplot as plt
        
        # Create DataFrame
        columns = \(data.columns)
        rows = \(data.rows)
        
        df = pd.DataFrame(rows, columns=columns)
        
        # Display info
        print("DataFrame Shape:", df.shape)
        print("\\nColumn Types:")
        print(df.dtypes)
        print("\\nFirst 5 rows:")
        print(df.head())
        
        # Basic statistics for numeric columns
        print("\\nStatistics:")
        print(df.describe())
        
        # Visualize numeric columns
        numeric_cols = df.select_dtypes(include=['number']).columns
        if len(numeric_cols) > 0:
            df[numeric_cols].plot(kind='bar', figsize=(10, 6))
            plt.title('Data Table Visualization')
            plt.xticks(rotation=45)
            plt.tight_layout()
            plt.show()
        """
    }

    private func generate3DModelPythonCode(data: Model3DData) -> String {
        return """
        # 3D Model Visualization
        # Model: \(data.title)
        # Type: \(data.modelType)
        
        import numpy as np
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d import Axes3D
        from mpl_toolkits.mplot3d.art3d import Poly3DCollection
        
        # Model data
        vertices = \(data.vertices.map { [$0.x, $0.y, $0.z] })
        faces = \(data.faces.map { $0.vertices })
        
        fig = plt.figure(figsize=(10, 8))
        ax = fig.add_subplot(111, projection='3d')
        
        # Create polygon collection
        if vertices and faces:
            poly3d = []
            for face in faces:
                poly3d.append([vertices[i] for i in face if i < len(vertices)])
            
            poly_collection = Poly3DCollection(poly3d, alpha=0.7, facecolor='cyan', edgecolor='black')
            ax.add_collection3d(poly_collection)
            
            # Set axis limits
            all_coords = np.array(vertices)
            ax.set_xlim(all_coords[:, 0].min(), all_coords[:, 0].max())
            ax.set_ylim(all_coords[:, 1].min(), all_coords[:, 1].max())
            ax.set_zlim(all_coords[:, 2].min(), all_coords[:, 2].max())
        
        ax.set_xlabel('X')
        ax.set_ylabel('Y')
        ax.set_zlabel('Z')
        ax.set_title('\(data.title)')
        
        plt.show()
        """
    }

    private func generateVolumetricPythonCode(data: VolumetricData) -> String {
        return """
        # Volumetric Visualization
        # Title: \(data.title)
        
        import numpy as np
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d import Axes3D
        
        # Generate sample volumetric data
        x = np.linspace(-2, 2, 30)
        y = np.linspace(-2, 2, 30)
        z = np.linspace(-2, 2, 30)
        X, Y, Z = np.meshgrid(x, y, z)
        
        # Create a scalar field (example: sphere)
        values = X**2 + Y**2 + Z**2
        
        # Visualize isosurface
        fig = plt.figure(figsize=(10, 8))
        ax = fig.add_subplot(111, projection='3d')
        
        # Sample points on the isosurface
        threshold = 2.0
        mask = values < threshold
        points = np.column_stack((X[mask], Y[mask], Z[mask]))
        
        if len(points) > 0:
            ax.scatter(points[:, 0], points[:, 1], points[:, 2], 
                      c=points[:, 2], cmap='viridis', alpha=0.3, s=1)
        
        ax.set_xlabel('X')
        ax.set_ylabel('Y')
        ax.set_zlabel('Z')
        ax.set_title('Volumetric Visualization: \(data.title)')
        
        plt.show()
        """
    }

    private func generateNotebookPythonCode(data: NotebookData) -> String {
        let cells = data.cells.enumerated().map { index, cell in
            """
            # In[\(index + 1)]:
            \(cell)
            
            """
        }.joined()

        return """
        # Jupyter Notebook Export
        # Generated from Spatial Editor
        # Metadata: \(data.metadata)
        
        \(cells)
        
        # End of notebook
        """
    }

    private func generateSpatialPythonCode(data: SpatialDataItem) -> String {
        return """
        # Spatial Data Visualization
        # Type: \(data.dataType.rawValue)
        # Points: \(data.pointCount)
        
        import numpy as np
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d import Axes3D
        
        # Spatial dimensions
        dimensions = \([data.dimensions.x, data.dimensions.y, data.dimensions.z])
        
        # Generate random spatial data for visualization
        num_points = \(data.pointCount)
        points = np.random.rand(num_points, 3) * dimensions
        
        fig = plt.figure(figsize=(10, 8))
        ax = fig.add_subplot(111, projection='3d')
        
        # Visualize spatial data
        scatter = ax.scatter(points[:, 0], points[:, 1], points[:, 2],
                           c=points[:, 2], cmap='viridis', alpha=0.6)
        
        ax.set_xlabel('X')
        ax.set_ylabel('Y')
        ax.set_zlabel('Z')
        ax.set_title('Spatial Data: \(data.dataType.rawValue)')
        
        # Add colorbar
        plt.colorbar(scatter, ax=ax, label='Z value')
        
        # Set axis limits based on dimensions
        ax.set_xlim(0, dimensions[0])
        ax.set_ylim(0, dimensions[1])
        ax.set_zlim(0, dimensions[2])
        
        plt.show()
        
        # Metadata
        metadata = \(data.metadata)
        print("Spatial Data Metadata:")
        for key, value in metadata.items():
            print(f"  {key}: {value}")
        """
    }

    private func getPlotCode(for recommendation: ChartRecommendation, xLabel: String, yLabel: String) -> String {
        switch recommendation {
        case .lineChart:
            return """
            plt.plot(x_data, y_data, marker='o', linewidth=2, markersize=6)
            plt.xlabel('\(xLabel)')
            plt.ylabel('\(yLabel)')
            """
        case .barChart:
            return """
            plt.bar(range(len(y_data)), y_data)
            plt.xlabel('\(xLabel)')
            plt.ylabel('\(yLabel)')
            plt.xticks(range(len(x_data)), [str(x) for x in x_data], rotation=45)
            """
        case .scatterPlot:
            return """
            plt.scatter(x_data, y_data, alpha=0.6, s=50)
            plt.xlabel('\(xLabel)')
            plt.ylabel('\(yLabel)')
            """
        case .pieChart:
            return """
            plt.pie(y_data, labels=[str(x) for x in x_data], autopct='%1.1f%%')
            plt.axis('equal')
            """
        case .areaChart:
            return """
            plt.fill_between(range(len(x_data)), y_data, alpha=0.4)
            plt.plot(range(len(x_data)), y_data, linewidth=2)
            plt.xlabel('\(xLabel)')
            plt.ylabel('\(yLabel)')
            """
        case .histogram:
            return """
            plt.hist(y_data, bins=20, alpha=0.7, edgecolor='black')
            plt.xlabel('\(yLabel)')
            plt.ylabel('Frequency')
            """
        }
    }

    // MARK: - Window Management

    private func loadVisualizationFromWindow() {
        guard let windowID = windowID else { return }

        // Try to load appropriate data based on what's stored in the window
        if let chartData = windowManager.getWindowChartData(for: windowID) {
            // Load 2D chart data
            let csvData = CSVData(
                headers: ["Index", chartData.xLabel, chartData.yLabel],
                rows: chartData.xData.enumerated().map { index, xValue in
                    ["\(index)", "\(xValue)", "\(chartData.yData[index])"]
                },
                columnTypes: [.numeric, .numeric, .numeric]
            )

            currentVisualization = .chart2D(ChartVisualizationData(
                csvData: csvData,
                recommendation: .lineChart,
                chartData: chartData
            ))
            selectedVisualizationType = .chart2D

        } else if let pointCloud = windowManager.getWindowPointCloud(for: windowID) {
            currentVisualization = .pointCloud(pointCloud)
            selectedVisualizationType = .pointCloud

        } else if let dataFrame = windowManager.getWindowDataFrame(for: windowID) {
            currentVisualization = .dataTable(dataFrame)
            selectedVisualizationType = .dataTable

        } else if let window = windowManager.getWindowSafely(for: windowID),
                  let model3D = window.state.model3DData {
            currentVisualization = .model3D(model3D)
            selectedVisualizationType = .model3D
        }
    }

    // MARK: - Statistics View (Enhanced)
    private var statisticsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Statistics").font(.subheadline).bold()

            switch currentVisualization {
            case .pointCloud(let data):
                pointCloudStatistics(data: data)

            case .chart2D(let data):
                chart2DStatistics(data: data)

            case .chart3D(let data):
                chart3DStatistics(data: data)

            case .dataTable(let data):
                dataTableStatistics(data: data)

            case .model3D(let data):
                model3DStatistics(data: data)

            case .volumetric(let data):
                volumetricStatistics(data: data)

            case .notebook(let data):
                notebookStatistics(data: data)

            case .spatial(let data):
                spatialStatistics(data: data)
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func pointCloudStatistics(data: PointCloudData) -> some View {
        HStack {
            Label("\(data.totalPoints) points", systemImage: "circle.grid.3x3.fill")
            Spacer()
            Label(String(format: "%.1f°", rotationAngle.truncatingRemainder(dividingBy: 360)), systemImage: "rotate.3d")
        }
        .font(.caption2).foregroundColor(.secondary)
    }

    @ViewBuilder
    private func chart2DStatistics(data: ChartVisualizationData) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Label("\(data.chartData.xData.count) data points", systemImage: "chart.dots.scatter")
                Spacer()
                Image(systemName: data.recommendation.icon)
                    .foregroundColor(.blue)
            }
            .font(.caption2).foregroundColor(.secondary)

            Text("Chart: \(data.recommendation.name)")
                .font(.caption2).bold()
        }
    }

    @ViewBuilder
    private func chart3DStatistics(data: Chart3DData) -> some View {
        HStack {
            Label("\(data.points.count) 3D points", systemImage: "cube.transparent")
            Spacer()
        }
        .font(.caption2).foregroundColor(.secondary)
    }

    @ViewBuilder
    private func dataTableStatistics(data: DataFrameData) -> some View {
        HStack {
            Label("\(data.rows.count) × \(data.columns.count)", systemImage: "tablecells")
            Spacer()
            Text("\(data.dataTypes?.count ?? 0) typed columns")
        }
        .font(.caption2).foregroundColor(.secondary)
    }

    @ViewBuilder
    private func model3DStatistics(data: Model3DData) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Label("\(data.vertices.count) vertices", systemImage: "cube.fill")
                Spacer()
                Text("\(data.faces.count) faces")
            }
            Text("Type: \(data.modelType)")
        }
        .font(.caption2).foregroundColor(.secondary)
    }

    @ViewBuilder
    private func volumetricStatistics(data: VolumetricData) -> some View {
        HStack {
            Label(data.title, systemImage: "cube.transparent.fill")
            Spacer()
        }
        .font(.caption2).foregroundColor(.secondary)
    }

    @ViewBuilder
    private func notebookStatistics(data: NotebookData) -> some View {
        HStack {
            Label("\(data.cells.count) cells", systemImage: "doc.text")
            Spacer()
            Text("Python kernel")
        }
        .font(.caption2).foregroundColor(.secondary)
    }

    @ViewBuilder
    private func spatialStatistics(data: SpatialDataItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Label("\(data.pointCount) points", systemImage: "location.square")
                Spacer()
                Text(data.dataType.rawValue)
            }
            Text("Size: \(String(format: "%.1f × %.1f × %.1f", data.dimensions.x, data.dimensions.y, data.dimensions.z))")
        }
        .font(.caption2).foregroundColor(.secondary)
    }

    // Existing components remain the same...
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spatial Visualization Editor")
                    .font(.title2).bold()
                if let windowID {
                    HStack(spacing: 8) {
                        Text("Window #\(windowID)")
                        Text("•")
                        Text(selectedVisualizationType.rawValue)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                SpatialControlButton(icon: showCodeSidebar ? "chevron.right" : "chevron.left", text: "Code", color: Color.indigo) {
                    showCodeSidebar.toggle()
                }

                SpatialControlButton(icon: showControls ? "eye.slash" : "eye", text: showControls ? "Hide Controls" : "Show Controls", color: Color.blue) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showControls.toggle()
                    }
                }
            }
        }
    }

    private var exportControlsView: some View {
        VStack(spacing: 8) {
            Text("Export Options").font(.subheadline).bold()
            HStack(spacing: 8) {
                ExportButton(title: "Save to Window", icon: "square.and.arrow.down", color: Color.blue) {
                    saveToWindow()
                }
                ExportButton(title: "Export to Jupyter", icon: "doc.text", color: Color.green) {
                    exportToJupyter()
                }
            }
            ExportButton(title: "Copy Python Code", icon: "doc.on.doc", color: Color.orange) {
                copyPythonCode()
            }
        }
    }

    private func saveToWindow() {
        guard let windowID = windowID else { return }

        // Save current visualization to window manager
        // Implementation depends on your window manager's API
        print("💾 Visualization saved to window #\(windowID)")
    }

    private func exportToJupyter() {
        // Export current visualization as Jupyter notebook
        print("📓 Exported to Jupyter notebook")
    }

    private func copyPythonCode() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(generatedCode, forType: .string)
        print("📋 Python code copied to clipboard")
        #endif
    }
}

// MARK: - Universal Import Sheet
struct UniversalImportSheet: View {
    let currentType: SpatialEditorView.VisualizationType
    let onDataImported: (SpatialEditorView.VisualizationData) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Import \(currentType.rawValue) Data")
                    .font(.largeTitle)
                    .bold()

                Image(systemName: currentType.icon)
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text(currentType.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Import options based on type
                importOptionsForType

                Spacer()
            }
            .padding()
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var importOptionsForType: some View {
        VStack(spacing: 16) {
            Button(action: loadSampleData) {
                Label("Load Sample Data", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button(action: importFromFile) {
                Label("Import from File", systemImage: "doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if currentType == .dataTable || currentType == .chart2D {
                Button(action: importFromCSV) {
                    Label("Import CSV", systemImage: "tablecells")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if currentType == .model3D || currentType == .volumetric {
                Button(action: importFrom3DFile) {
                    Label("Import 3D Model", systemImage: "cube")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal)
    }

    private func loadSampleData() {
        // Load sample data based on current type
        dismiss()
    }

    private func importFromFile() {
        // Show file importer
        dismiss()
    }

    private func importFromCSV() {
        // Show CSV importer
        dismiss()
    }

    private func importFrom3DFile() {
        // Show 3D model importer
        dismiss()
    }
}

// MARK: - Code Sidebar (reuse existing implementation)
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

// MARK: - Preview
#Preview {
    SpatialEditorView()
        .frame(width: 900, height: 700)
}

// MARK: - Supporting Components
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
#Preview{
    SpatialEditorView()
}
