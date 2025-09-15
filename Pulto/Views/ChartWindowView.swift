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



// MARK: - Previews
#Preview("Control Panel") {
    ControlWindowView(viewModel: ChartViewModel())
        .frame(width: 400, height: 600)
}

#Preview("Draggable Window") {
    let vm = ChartViewModel()
    // Ensure at least one window is visible for the preview
    if !vm.windows.isEmpty {
        vm.windows[0].isVisible = true
    }
    return ZStack {
        if vm.windows.indices.contains(0) {
            DraggableWindow(
                window: vm.windows[0],
                index: 0,
                viewModel: vm,
                draggingOffset: .zero,
                onDragChanged: { _ in }
            )
        }
    }
    .frame(width: 500, height: 400)
}

#Preview("Windows Grid") {
    struct GridPreview: View {
        @StateObject var vm = ChartViewModel()
        var body: some View {
            ZStack {
                ForEach(Array(vm.windows.enumerated()), id: \.element.id) { index, window in
                    if window.isVisible {
                        DraggableWindow(
                            window: window,
                            index: index,
                            viewModel: vm,
                            draggingOffset: .zero,
                            onDragChanged: { _ in }
                        )
                    }
                }
            }
            .onAppear {
                // Show the first 3 windows in a grid for preview
                for i in 0..<min(3, vm.windows.count) {
                    vm.windows[i].isVisible = true
                    vm.windows[i].offset = vm.calculateGridPosition(for: i)
                    vm.windows[i].rotation = .degrees(0)
                }
            }
        }
    }
    return GridPreview()
        .frame(width: 1200, height: 800)
}
