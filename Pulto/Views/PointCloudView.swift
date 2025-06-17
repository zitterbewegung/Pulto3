import SwiftUI
import Charts

// MARK: - Data Models

struct ToyShape: Identifiable {
    var color: String
    var type: String
    var count: Double
    var id = UUID()
}

let stackedBarData: [ToyShape] = [
    .init(color: "Green", type: "Cube", count: 2),
    .init(color: "Green", type: "Sphere", count: 0),
    .init(color: "Green", type: "Pyramid", count: 1),
    .init(color: "Purple", type: "Cube", count: 1),
    .init(color: "Purple", type: "Sphere", count: 1),
    .init(color: "Purple", type: "Pyramid", count: 1),
    .init(color: "Pink", type: "Cube", count: 1),
    .init(color: "Pink", type: "Sphere", count: 2),
    .init(color: "Pink", type: "Pyramid", count: 0),
    .init(color: "Yellow", type: "Cube", count: 1),
    .init(color: "Yellow", type: "Sphere", count: 1),
    .init(color: "Yellow", type: "Pyramid", count: 2)
]

// MARK: - Window Model

struct SpatialWindow: Identifiable {
    let id = UUID()
    var title: String
    var offset: CGSize
    var rotation: Angle
    var isVisible: Bool
    var color: Color
    var contentType: WindowContentType

    enum WindowContentType {
        case chart
        case text(String)
        case custom
    }
}

// MARK: - ViewModel

@MainActor
class ChartViewModel: ObservableObject {
    // Grid Configuration
    @Published var gridColumns: Int = 3
    @Published var gridRows: Int = 3

    // Windows Array
    @Published var windows: [SpatialWindow] = []

    // Control Window States
    @Published var controlOffset: CGSize = CGSize(width: 0, height: 0)
    @Published var controlRotation: Angle = .degrees(0)

    // Window Dimensions and Settings
    let windowWidth: CGFloat = 300
    let windowHeight: CGFloat = 200
    let gridSpacing: CGFloat = 20
    let animationDuration: Double = 0.5

    // Grid Layout Mode
    @Published var isGridMode: Bool = true

    init() {
        setupDefaultWindows()
        loadWindowStates()
    }

    // MARK: - Setup Functions

    func setupDefaultWindows() {
        let colors: [Color] = [.blue, .red, .green, .purple, .orange, .pink, .yellow, .mint, .teal]
        let totalWindows = gridColumns * gridRows

        for i in 0..<totalWindows {
            let window = SpatialWindow(
                title: "Window \(i + 1)",
                offset: calculateGridPosition(for: i),
                rotation: .degrees(0),
                isVisible: false,
                color: colors[i % colors.count].opacity(0.8),
                contentType: i % 3 == 0 ? .chart : .text("Content for Window \(i + 1)")
            )
            windows.append(window)
        }
    }

    func calculateGridPosition(for index: Int) -> CGSize {
        let row = index / gridColumns
        let col = index % gridColumns

        let totalWidth = CGFloat(gridColumns) * windowWidth + CGFloat(gridColumns - 1) * gridSpacing
        let totalHeight = CGFloat(gridRows) * windowHeight + CGFloat(gridRows - 1) * gridSpacing

        let startX = -totalWidth / 2 + windowWidth / 2
        let startY = -totalHeight / 2 + windowHeight / 2

        let x = startX + CGFloat(col) * (windowWidth + gridSpacing)
        let y = startY + CGFloat(row) * (windowHeight + gridSpacing)

        return CGSize(width: x, height: y)
    }

    // MARK: - Control Functions

    func toggleWindow(at index: Int) {
        guard index < windows.count else { return }

        withAnimation(.easeInOut(duration: animationDuration)) {
            windows[index].isVisible.toggle()

            if isGridMode && windows[index].isVisible {
                windows[index].offset = calculateGridPosition(for: index)
            }
        }
        saveWindowStates()
    }

    func showAllWindows() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            for i in 0..<windows.count {
                windows[i].isVisible = true
                if isGridMode {
                    windows[i].offset = calculateGridPosition(for: i)
                }
            }
        }
        saveWindowStates()
    }

    func hideAllWindows() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            for i in 0..<windows.count {
                windows[i].isVisible = false
            }
        }
        saveWindowStates()
    }

    func arrangeInGrid() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            isGridMode = true
            for i in 0..<windows.count {
                windows[i].offset = calculateGridPosition(for: i)
                windows[i].rotation = .degrees(0)
            }
        }
        saveWindowStates()
    }

    func randomizePositions() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            isGridMode = false
            for i in 0..<windows.count {
                windows[i].offset = CGSize(
                    width: CGFloat.random(in: -300...300),
                    height: CGFloat.random(in: -300...300)
                )
                windows[i].rotation = .degrees(Double.random(in: -45...45))
            }
        }
        saveWindowStates()
    }

    func updateWindowPosition(at index: Int, offset: CGSize) {
        guard index < windows.count else { return }
        windows[index].offset = offset
        isGridMode = false
        saveWindowStates()
    }

    func updateWindowRotation(at index: Int, rotation: Angle) {
        guard index < windows.count else { return }
        windows[index].rotation = rotation
        saveWindowStates()
    }

    // MARK: - State Persistence

    func loadWindowStates() {
        // Load control window state
        let controlOffsetWidth = UserDefaults.standard.object(forKey: "controlOffsetWidth") as? CGFloat ?? 0
        let controlOffsetHeight = UserDefaults.standard.object(forKey: "controlOffsetHeight") as? CGFloat ?? 0
        controlOffset = CGSize(width: controlOffsetWidth, height: controlOffsetHeight)

        let controlRotationValue = UserDefaults.standard.double(forKey: "controlRotation")
        controlRotation = .degrees(controlRotationValue)

        // Load grid mode
        isGridMode = UserDefaults.standard.object(forKey: "isGridMode") as? Bool ?? true

        // Load window states
        if let savedWindowsData = UserDefaults.standard.data(forKey: "windowStates") {
            do {
                let savedStates = try JSONDecoder().decode([ChartWindowState].self, from: savedWindowsData)
                for (index, state) in savedStates.enumerated() {
                    if index < windows.count {
                        windows[index].offset = CGSize(width: state.offsetWidth, height: state.offsetHeight)
                        windows[index].rotation = .degrees(state.rotation)
                        windows[index].isVisible = state.isVisible
                    }
                }
            } catch {
                print("Failed to decode window states: \(error)")
            }
        }
    }

    func saveWindowStates() {
        // Save control window state
        UserDefaults.standard.set(controlOffset.width, forKey: "controlOffsetWidth")
        UserDefaults.standard.set(controlOffset.height, forKey: "controlOffsetHeight")
        UserDefaults.standard.set(controlRotation.degrees, forKey: "controlRotation")

        // Save grid mode
        UserDefaults.standard.set(isGridMode, forKey: "isGridMode")

        // Save window states
        let states = windows.map { window in
            ChartWindowState(
                offsetWidth: window.offset.width,
                offsetHeight: window.offset.height,
                rotation: window.rotation.degrees,
                isVisible: window.isVisible
            )
        }

        if let encoded = try? JSONEncoder().encode(states) {
            UserDefaults.standard.set(encoded, forKey: "windowStates")
        }
    }

    // MARK: - Debug Functions

    func resetAll() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            isGridMode = true
            for i in 0..<windows.count {
                windows[i].offset = calculateGridPosition(for: i)
                windows[i].rotation = .degrees(0)
                windows[i].isVisible = false
            }
            controlOffset = .zero
            controlRotation = .degrees(0)
        }
        saveWindowStates()
    }
}

// MARK: - Codable State for Persistence

struct ChartWindowState: Codable {
    let offsetWidth: CGFloat
    let offsetHeight: CGFloat
    let rotation: Double
    let isVisible: Bool
}

// MARK: - Main View

// Enhanced Spatial Editor View with Point Cloud Integration
struct SpatialEditorView: View {
    let windowID: Int?
    @StateObject private var windowManager = WindowTypeManager.shared
    @State private var selectedDemo = 0
    @State private var rotationAngle = 0.0
    @State private var currentPointCloud: PointCloudData = PointCloudDemo.generateSpherePointCloudData()

    // Point cloud parameters
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

    let demoNames = ["Sphere", "Torus", "Wave Surface", "Spiral Galaxy", "Noisy Cube"]

    init(windowID: Int? = nil) {
        self.windowID = windowID
    }

    var body: some View {
        VStack(spacing: 20) {
            headerView
            parameterControlsView
            demoSelectorView
            pointCloudVisualizationView
            statisticsView
            exportControlsView
            Spacer()
        }
        .padding()
        .onAppear {
            loadPointCloudFromWindow()
            startRotationAnimation()
        }
        .onChange(of: selectedDemo) { _ in
            updatePointCloud()
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Spatial Point Cloud Editor")
                .font(.title2)
                .bold()
            if let windowID = windowID {
                Text("Window #\(windowID) • \(currentPointCloud.totalPoints) points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var parameterControlsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Parameters")
                .font(.headline)

            switch selectedDemo {
            case 0: // Sphere
                VStack(alignment: .leading, spacing: 4) {
                    Text("Radius: \(sphereRadius, specifier: "%.1f")")
                    Slider(value: $sphereRadius, in: 5...20) { _ in updatePointCloud() }
                    Text("Points: \(Int(spherePoints))")
                    Slider(value: $spherePoints, in: 100...2000, step: 100) { _ in updatePointCloud() }
                }

            case 1: // Torus
                VStack(alignment: .leading, spacing: 4) {
                    Text("Major Radius: \(torusMajorRadius, specifier: "%.1f")")
                    Slider(value: $torusMajorRadius, in: 5...15) { _ in updatePointCloud() }
                    Text("Minor Radius: \(torusMinorRadius, specifier: "%.1f")")
                    Slider(value: $torusMinorRadius, in: 1...8) { _ in updatePointCloud() }
                    Text("Points: \(Int(torusPoints))")
                    Slider(value: $torusPoints, in: 500...5000, step: 100) { _ in updatePointCloud() }
                }

            case 2: // Wave Surface
                VStack(alignment: .leading, spacing: 4) {
                    Text("Size: \(waveSize, specifier: "%.1f")")
                    Slider(value: $waveSize, in: 10...30) { _ in updatePointCloud() }
                    Text("Resolution: \(Int(waveResolution))")
                    Slider(value: $waveResolution, in: 20...80, step: 10) { _ in updatePointCloud() }
                }

            case 3: // Spiral Galaxy
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arms: \(Int(galaxyArms))")
                    Slider(value: $galaxyArms, in: 2...6, step: 1) { _ in updatePointCloud() }
                    Text("Points: \(Int(galaxyPoints))")
                    Slider(value: $galaxyPoints, in: 1000...10000, step: 500) { _ in updatePointCloud() }
                }

            case 4: // Noisy Cube
                VStack(alignment: .leading, spacing: 4) {
                    Text("Size: \(cubeSize, specifier: "%.1f")")
                    Slider(value: $cubeSize, in: 5...20) { _ in updatePointCloud() }
                    Text("Points per Face: \(Int(cubePointsPerFace))")
                    Slider(value: $cubePointsPerFace, in: 100...1000, step: 50) { _ in updatePointCloud() }
                }

            default:
                EmptyView()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var demoSelectorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Point Cloud Type")
                .font(.headline)

            Picker("Select Data", selection: $selectedDemo) {
                ForEach(0..<demoNames.count, id: \.self) { index in
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
                .frame(height: 400)

            GeometryReader { geometry in
                Canvas { context, size in
                    let centerX = size.width / 2
                    let centerY = size.height / 2
                    let scale = min(size.width, size.height) / 40
                    let angle = rotationAngle * .pi / 180

                    for point in currentPointCloud.points {
                        // 3D rotation around Y axis
                        let rotatedX = point.x * cos(angle) - point.z * sin(angle)
                        let rotatedZ = point.x * sin(angle) + point.z * cos(angle)

                        // Project to 2D
                        let projectedX = centerX + rotatedX * scale
                        let projectedY = centerY - point.y * scale

                        // Size based on Z depth
                        let pointSize = 2.0 + (rotatedZ + 20) / 20

                        // Color based on intensity or Z depth
                        let intensity = point.intensity ?? ((point.z + 10) / 20)
                        let color = Color(
                            hue: 0.6 - intensity * 0.4,
                            saturation: 0.8,
                            brightness: 0.9
                        )

                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: projectedX - pointSize/2,
                                y: projectedY - pointSize/2,
                                width: pointSize,
                                height: pointSize
                            )),
                            with: .color(color.opacity(0.8))
                        )
                    }
                }
            }
            .frame(height: 400)
        }
    }

    private var statisticsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.headline)

            HStack {
                Label("\(currentPointCloud.totalPoints) points", systemImage: "circle.grid.3x3.fill")
                Spacer()
                Label(String(format: "%.1f°", rotationAngle.truncatingRemainder(dividingBy: 360)), systemImage: "rotate.3d")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            if !currentPointCloud.parameters.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Parameters:")
                        .font(.caption)
                        .bold()
                    ForEach(Array(currentPointCloud.parameters.keys.sorted()), id: \.self) { key in
                        Text("\(key): \(currentPointCloud.parameters[key] ?? 0, specifier: "%.1f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var exportControlsView: some View {
        VStack(spacing: 12) {
            Text("Export Options")
                .font(.headline)

            HStack(spacing: 12) {
                Button(action: {
                    saveToWindow()
                }) {
                    Label("Save to Window", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }

                Button(action: {
                    exportToJupyter()
                }) {
                    Label("Export to Jupyter", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            Button(action: {
                copyPythonCode()
            }) {
                Label("Copy Python Code", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Helper Methods

    private func loadPointCloudFromWindow() {
        guard let windowID = windowID,
              let existingPointCloud = windowManager.getWindowPointCloud(for: windowID) else {
            return
        }
        currentPointCloud = existingPointCloud

        // Set demo selector based on saved data
        if let demoIndex = demoNames.firstIndex(where: { $0.lowercased().contains(existingPointCloud.demoType) }) {
            selectedDemo = demoIndex
        }
    }

    private func updatePointCloud() {
        switch selectedDemo {
        case 0:
            currentPointCloud = PointCloudDemo.generateSpherePointCloudData(
                radius: sphereRadius,
                points: Int(spherePoints)
            )
        case 1:
            currentPointCloud = PointCloudDemo.generateTorusPointCloudData(
                majorRadius: torusMajorRadius,
                minorRadius: torusMinorRadius,
                points: Int(torusPoints)
            )
        case 2:
            currentPointCloud = PointCloudDemo.generateWaveSurfaceData(
                size: waveSize,
                resolution: Int(waveResolution)
            )
        case 3:
            currentPointCloud = PointCloudDemo.generateSpiralGalaxyData(
                arms: Int(galaxyArms),
                points: Int(galaxyPoints)
            )
        case 4:
            currentPointCloud = PointCloudDemo.generateNoisyCubeData(
                size: cubeSize,
                pointsPerFace: Int(cubePointsPerFace)
            )
        default:
            break
        }
    }

    private func startRotationAnimation() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }

    private func saveToWindow() {
        guard let windowID = windowID else { return }
        windowManager.updateWindowPointCloud(windowID, pointCloud: currentPointCloud)
        windowManager.updateWindowContent(windowID, content: currentPointCloud.toPythonCode())
        print("✅ Point cloud saved to window #\(windowID)")
    }

    private func exportToJupyter() {
        let pythonCode = currentPointCloud.toPythonCode()
        let filename = "pointcloud_\(currentPointCloud.demoType)_\(Date().timeIntervalSince1970)"

        // Save to file
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let fileURL = documentsDirectory.appendingPathComponent("\(filename).py")

        do {
            try pythonCode.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Point cloud exported to: \(fileURL.path)")
        } catch {
            print("❌ Error saving file: \(error)")
        }

        // Also save to window if we have a window ID
        saveToWindow()
    }

    private func copyPythonCode() {
        let pythonCode = currentPointCloud.toPythonCode()

        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pythonCode, forType: .string)
        print("✅ Python code copied to clipboard")
        #endif
    }
}

// MARK: - Draggable Window Component

struct DraggableWindow: View {
    let window: SpatialWindow
    let index: Int
    let viewModel: ChartViewModel
    let draggingOffset: CGSize
    let onDragChanged: (CGSize) -> Void

    var body: some View {
        WindowContentView(window: window)
            .frame(width: viewModel.windowWidth, height: viewModel.windowHeight)
            .background(window.color)
            .cornerRadius(15)
            .shadow(radius: 5)
            .offset(
                x: window.offset.width + draggingOffset.width,
                y: window.offset.height + draggingOffset.height
            )
            .rotationEffect(window.rotation)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        onDragChanged(gesture.translation)
                    }
                    .onEnded { gesture in
                        let newOffset = CGSize(
                            width: window.offset.width + gesture.translation.width,
                            height: window.offset.height + gesture.translation.height
                        )
                        viewModel.updateWindowPosition(at: index, offset: newOffset)
                        onDragChanged(.zero)
                    }
            )
            .simultaneousGesture(
                RotationGesture()
                    .onChanged { angle in
                        viewModel.updateWindowRotation(at: index, rotation: angle)
                    }
            )
    }
}

// MARK: - Window Content View

struct WindowContentView: View {
    let window: SpatialWindow

    var body: some View {
        VStack {
            Text(window.title)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top)

            switch window.contentType {
            case .chart:
                Chart {
                    ForEach(stackedBarData) { shape in
                        BarMark(
                            x: .value("Shape Type", shape.type),
                            y: .value("Total Count", shape.count)
                        )
                        .foregroundStyle(by: .value("Shape Color", shape.color))
                    }
                }
                .padding()

            case .text(let content):
                Text(content)
                    .foregroundColor(.white)
                    .padding()

            case .custom:
                // Add custom content here
                Image(systemName: "star.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            }

            Spacer()
        }
    }
}

// MARK: - Control Window View

struct ControlWindowView: View {
    @ObservedObject var viewModel: ChartViewModel

    var body: some View {
        VStack(spacing: 15) {
            Text("Control Panel")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)

            Divider()

            // Grid Controls
            VStack(spacing: 10) {
                Text("Grid Layout")
                    .font(.headline)

                HStack(spacing: 20) {
                    Button(action: viewModel.arrangeInGrid) {
                        Label("Arrange Grid", systemImage: "square.grid.3x3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: viewModel.randomizePositions) {
                        Label("Randomize", systemImage: "shuffle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)

            Divider()

            // Batch Controls
            VStack(spacing: 10) {
                Text("Window Controls")
                    .font(.headline)

                HStack(spacing: 20) {
                    Button(action: viewModel.showAllWindows) {
                        Text("Show All")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button(action: viewModel.hideAllWindows) {
                        Text("Hide All")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(.horizontal)

            Divider()

            // Individual Window Controls
            ScrollView {
                VStack(spacing: 8) {
                    Text("Individual Windows")
                        .font(.headline)
                        .padding(.bottom, 5)

                    ForEach(Array(viewModel.windows.enumerated()), id: \.element.id) { index, window in
                        HStack {
                            Circle()
                                .fill(window.color)
                                .frame(width: 10, height: 10)

                            Text(window.title)
                                .font(.subheadline)

                            Spacer()

                            Button(action: {
                                viewModel.toggleWindow(at: index)
                            }) {
                                Text(window.isVisible ? "Hide" : "Show")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(window.isVisible ? Color.red : Color.green)
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .frame(maxHeight: 200)

            Divider()

            // Reset Button
            Button(action: viewModel.resetAll) {
                Label("Reset All", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical)
    }
}



// MARK: - ViewModel

@MainActor
class FlatViewModel: ObservableObject {
    // Grid Configuration
    @Published var gridColumns: Int = 3
    @Published var gridRows: Int = 3

    // Windows Array
    @Published var windows: [SpatialWindow] = []

    // Control Window States
    @Published var controlOffset: CGSize = CGSize(width: 0, height: 0)
    @Published var controlRotation: Angle = .degrees(0)

    // Window Dimensions and Settings
    let windowWidth: CGFloat = 300
    let windowHeight: CGFloat = 200
    let gridSpacing: CGFloat = 20
    let animationDuration: Double = 0.5

    // Grid Layout Mode
    @Published var isGridMode: Bool = true

    init() {
        setupDefaultWindows()
        loadWindowStates()
    }

    // MARK: - Setup Functions

    func setupDefaultWindows() {
        let colors: [Color] = [.blue, .red, .green, .purple, .orange, .pink, .yellow, .mint, .teal]
        let totalWindows = gridColumns * gridRows

        for i in 0..<totalWindows {
            let window = SpatialWindow(
                title: "Window \(i + 1)",
                offset: calculateGridPosition(for: i),
                rotation: .degrees(0),
                isVisible: false,
                color: colors[i % colors.count].opacity(0.8),
                contentType: i % 3 == 0 ? .chart : .text("Content for Window \(i + 1)")
            )
            windows.append(window)
        }
    }

    func calculateGridPosition(for index: Int) -> CGSize {
        let row = index / gridColumns
        let col = index % gridColumns

        let totalWidth = CGFloat(gridColumns) * windowWidth + CGFloat(gridColumns - 1) * gridSpacing
        let totalHeight = CGFloat(gridRows) * windowHeight + CGFloat(gridRows - 1) * gridSpacing

        let startX = -totalWidth / 2 + windowWidth / 2
        let startY = -totalHeight / 2 + windowHeight / 2

        let x = startX + CGFloat(col) * (windowWidth + gridSpacing)
        let y = startY + CGFloat(row) * (windowHeight + gridSpacing)

        return CGSize(width: x, height: y)
    }

    // MARK: - Control Functions

    func toggleWindow(at index: Int) {
        guard index < windows.count else { return }

        withAnimation(.easeInOut(duration: animationDuration)) {
            windows[index].isVisible.toggle()

            if isGridMode && windows[index].isVisible {
                windows[index].offset = calculateGridPosition(for: index)
            }
        }
        saveWindowStates()
    }

    func showAllWindows() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            for i in 0..<windows.count {
                windows[i].isVisible = true
                if isGridMode {
                    windows[i].offset = calculateGridPosition(for: i)
                }
            }
        }
        saveWindowStates()
    }

    func hideAllWindows() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            for i in 0..<windows.count {
                windows[i].isVisible = false
            }
        }
        saveWindowStates()
    }

    func arrangeInGrid() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            isGridMode = true
            for i in 0..<windows.count {
                windows[i].offset = calculateGridPosition(for: i)
                windows[i].rotation = .degrees(0)
            }
        }
        saveWindowStates()
    }

    func randomizePositions() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            isGridMode = false
            for i in 0..<windows.count {
                windows[i].offset = CGSize(
                    width: CGFloat.random(in: -300...300),
                    height: CGFloat.random(in: -300...300)
                )
                windows[i].rotation = .degrees(Double.random(in: -45...45))
            }
        }
        saveWindowStates()
    }

    func updateWindowPosition(at index: Int, offset: CGSize) {
        guard index < windows.count else { return }
        windows[index].offset = offset
        isGridMode = false
        saveWindowStates()
    }

    func updateWindowRotation(at index: Int, rotation: Angle) {
        guard index < windows.count else { return }
        windows[index].rotation = rotation
        saveWindowStates()
    }

    // MARK: - State Persistence

    func loadWindowStates() {
        // Load control window state
        let controlOffsetWidth = UserDefaults.standard.object(forKey: "controlOffsetWidth") as? CGFloat ?? 0
        let controlOffsetHeight = UserDefaults.standard.object(forKey: "controlOffsetHeight") as? CGFloat ?? 0
        controlOffset = CGSize(width: controlOffsetWidth, height: controlOffsetHeight)

        let controlRotationValue = UserDefaults.standard.double(forKey: "controlRotation")
        controlRotation = .degrees(controlRotationValue)

        // Load grid mode
        isGridMode = UserDefaults.standard.object(forKey: "isGridMode") as? Bool ?? true

        // Load window states
        if let savedWindowsData = UserDefaults.standard.data(forKey: "windowStates") {
            do {
                let savedStates = try JSONDecoder().decode([ChartWindowState].self, from: savedWindowsData)
                for (index, state) in savedStates.enumerated() {
                    if index < windows.count {
                        windows[index].offset = CGSize(width: state.offsetWidth, height: state.offsetHeight)
                        windows[index].rotation = .degrees(state.rotation)
                        windows[index].isVisible = state.isVisible
                    }
                }
            } catch {
                print("Failed to decode window states: \(error)")
            }
        }
    }

    func saveWindowStates() {
        // Save control window state
        UserDefaults.standard.set(controlOffset.width, forKey: "controlOffsetWidth")
        UserDefaults.standard.set(controlOffset.height, forKey: "controlOffsetHeight")
        UserDefaults.standard.set(controlRotation.degrees, forKey: "controlRotation")

        // Save grid mode
        UserDefaults.standard.set(isGridMode, forKey: "isGridMode")

        // Save window states
        let states = windows.map { window in
            ChartWindowState(
                offsetWidth: window.offset.width,
                offsetHeight: window.offset.height,
                rotation: window.rotation.degrees,
                isVisible: window.isVisible
            )
        }

        if let encoded = try? JSONEncoder().encode(states) {
            UserDefaults.standard.set(encoded, forKey: "windowStates")
        }
    }

    // MARK: - Debug Functions

    func resetAll() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            isGridMode = true
            for i in 0..<windows.count {
                windows[i].offset = calculateGridPosition(for: i)
                windows[i].rotation = .degrees(0)
                windows[i].isVisible = false
            }
            controlOffset = .zero
            controlRotation = .degrees(0)
        }
        saveWindowStates()
    }
}


// MARK: - Preview Provider
#Preview {
    SpatialEditorView()
        .frame(width: 1200, height: 800)
}
