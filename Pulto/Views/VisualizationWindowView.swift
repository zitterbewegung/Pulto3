import SwiftUI
import RealityKit
import UIKit


struct TemplatesContentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @State private var selectedVisualizationType: VisualizationType = .pointCloud
    @State private var showSidebar = true
    @State private var selectedDataset: String? = nil
    @State private var visualizationSettings = VisualizationSettings()

    var body: some View {
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
                    ForEach(VisualizationType.allCases) { type in
                        Label(type.rawValue, systemImage: type.iconName)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }

            ToolbarItemGroup(placement: .primaryAction) {
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
    }
}

// MARK: - Visualization Types
enum VisualizationType: String, CaseIterable, Identifiable {
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
    @Binding var visualizationType: VisualizationType
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
    let type: VisualizationType
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
                TemplatePointCloudView(settings: settings)
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
                    .help("Close Window (⌘W)")
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
    let visualizationType: VisualizationType
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
                            StatRow(label: "Points", value: "16,400")
                            StatRow(label: "Memory", value: "64 MB")
                            StatRow(label: "Density", value: "2.5k/m²")
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

    var body: some View {
        HStack {
            Button(action: { isVisible.toggle() }) {
                Image(systemName: isVisible ? "eye" : "eye.slash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Text(name)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct ViewControlsOverlay: View {
    @Binding var settings: VisualizationSettings

    var body: some View {
        HStack(spacing: 15) {
            Button(action: {}) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("Fit to View")

            Button(action: {}) {
                Image(systemName: "camera")
            }
            .help("Reset Camera")

            Button(action: {}) {
                Image(systemName: "ruler")
            }
            .help("Measure")

            Button(action: {}) {
                Image(systemName: "slider.horizontal.3")
            }
            .help("Filters")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
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
                //lightEntity.light.isRealWorldProxy = true
                //lightEntity.shadow?.isEnabled = settings.enableShadows
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
        return UIColor(color)
    }
}

struct TemplatePointCloudView: View {
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
                                x: projectedX - pointSize/2,
                                y: projectedY - pointSize/2,
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
        var points: [PointCloudPoint] = []

        // Generate a sample terrain-like point cloud
        for x in stride(from: -2.0, to: 2.0, by: 0.1) {
            for z in stride(from: -2.0, to: 2.0, by: 0.1) {
                // Create height variation
                let height = sin(x * 2) * cos(z * 2) * 0.5 +
                           sin(x * 5) * sin(z * 5) * 0.1 +
                           Double.random(in: -0.05...0.05)

                // Calculate intensity based on height
                let intensity = (height + 1) / 2

                // Classification based on regions
                let classification = if sqrt(x*x + z*z) < 0.5 {
                    0 // Center region
                } else if abs(x) > 1.5 || abs(z) > 1.5 {
                    2 // Outer region
                } else {
                    1 // Middle region
                }

                points.append(PointCloudPoint(
                    x: x,
                    y: height,
                    z: z,
                    intensity: intensity,
                    classification: classification
                ))
            }
        }

        // Add some scattered elevated points
        for _ in 0..<100 {
            let x = Double.random(in: -2...2)
            let z = Double.random(in: -2...2)
            let y = Double.random(in: 0.5...1.5)

            points.append(PointCloudPoint(
                x: x,
                y: y,
                z: z,
                intensity: Double.random(in: 0.3...1.0),
                classification: 3
            ))
        }

        return points
    }

    func rotatePoint(_ point: PointCloudPoint, angle: Double) -> PointCloudPoint {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)

        return PointCloudPoint(
            x: point.x * cosAngle - point.z * sinAngle,
            y: point.y,
            z: point.x * sinAngle + point.z * cosAngle,
            intensity: point.intensity,
            classification: point.classification
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

        // Y-axis (green) - vertical, no rotation
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

// Point cloud data structure
struct PointCloudPoint {
    let x: Double
    let y: Double
    let z: Double
    let intensity: Double
    let classification: Int
}

// MARK: - Data Models
struct Dataset: Identifiable {
    let id = UUID()
    let name: String
    let type: VisualizationType
    var pointCount: Int {
        switch type {
        case .twoDimensional:
            return Int.random(in: 400...2000) // Grid cells or scatter points
        case .threeDimensional:
            return Int.random(in: 1000...50000) // Vertices
        case .pointCloud:
            return Int.random(in: 100000...5000000) // Point cloud points
        }
    }
}

struct VisualizationSettings {
    var showGrid = true
    var showAxes = true
    var enableShadows = true
    var pointSize: Double = 3.0
    var colorMode: ColorMode = .height
    var baseColor: Color = .blue
    var quality: Quality = .medium
    var progressiveLoading = true
}

enum ColorMode {
    case height, intensity, classification
}

enum Quality {
    case low, medium, high
}
