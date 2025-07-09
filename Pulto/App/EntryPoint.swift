/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The app's main entry point
*/

import SwiftUI


@main
struct EntryPoint: App {
    @StateObject private var windowManager = WindowTypeManager.shared

    /* Helper to apply placement + sizing to each window scene.
    private func configureScene(_ scene: WindowGroup<some View>, row: Int, col: Int) -> some Scene {
        let size = CGSize(width: GridConstants.tileWidth, height: GridConstants.tileHeight)
        return scene
            .windowStyle(.plain)
            .defaultSize(width: size.width, height: size.height)
            .defaultWindowPlacement { _, _ in
                WindowPlacement(positionForCell(row: row, col: col), size: size)
            }
    }*/
    var body: some Scene {
        // Main interface - EnvironmentView as primary entry point
        WindowGroup(id: "main") {
            EnvironmentView()
                .environmentObject(windowManager)
                .onOpenURL { url in
                    handleSharedURL(url)
                }
        }
        .windowStyle(.plain)
        .defaultSize(width: 1400, height: 900)

        // Home window - PultoHomeView as secondary interface
        WindowGroup(id: "home") {
            PultoHomeView()
                .environmentObject(windowManager)
        }
        .windowStyle(.plain)
        .defaultSize(width: 1280, height: 850)



        // Grid launcher (original functionality)
        WindowGroup(id: "launcher") {
            LauncherView()
        }
        .windowStyle(.plain)
        .defaultSize(width: 800, height: 600)

        // Secondary windows - loaded on demand
        Group {
            //WindowGroup("New Window", for: NewWindowID.ID.self) { $id in
            //    NewWindow(id: id ?? 1)
            //}

            WindowGroup(id: "open-project-window") {
                ProjectBrowserView(windowManager: windowManager)
                    .environmentObject(windowManager)
            }
            .windowStyle(.plain)
            .defaultSize(width: 1000, height: 700)

            // TODO: Re-enable when TestFeaturesView compilation is fixed
            // WindowGroup("Test Features", id: "test-features") {
            //     TestFeaturesView()
            // }
            // .windowStyle(.plain)
            // .defaultSize(width: 1000, height: 700)
        }
    }

    private func handleSharedURL(_ url: URL) {
        // Handle CSV files shared from Safari or other apps
        if url.pathExtension.lowercased() == "csv" {
            Task {
                do {
                    let content = try String(contentsOf: url)
                    if let csvData = CSVParser.parse(content) {
                        // Convert CSVData to DataFrameData
                        let dataFrame = DataFrameData(
                            columns: csvData.headers,
                            rows: csvData.rows,
                            dtypes: csvData.columnTypes.enumerated().reduce(into: [String: String]()) { result, item in
                                let (index, type) = item
                                if index < csvData.headers.count {
                                    switch type {
                                    case .numeric:
                                        result[csvData.headers[index]] = "float"
                                    case .categorical:
                                        result[csvData.headers[index]] = "string"
                                    case .date:
                                        result[csvData.headers[index]] = "string"
                                    case .unknown:
                                        result[csvData.headers[index]] = "string"
                                    }
                                }
                            }
                        )

                        // Create a new DataFrame window with the imported data
                        let windowId = windowManager.getNextWindowID()
                        let newWindow = windowManager.createWindow(.column, id: windowId)
                        windowManager.updateWindowDataFrame(newWindow.id, dataFrame: dataFrame)
                        windowManager.markWindowAsOpened(newWindow.id)
                    }
                } catch {
                    print("Error importing shared CSV: \(error)")
                }
            }
        }
    }
}

/*
@main
struct EntryPoint: App {
    @StateObject private var windowManager = WindowTypeManager.shared
    @StateObject private var spatialManager = SpatialWindowManager.shared
    
    var body: some SwiftUI.Scene {
        // Main interface - EnvironmentView as primary entry point
        WindowGroup(id: "main") {
            EnvironmentView()
                .environmentObject(windowManager)
                .environmentObject(spatialManager)
                .onOpenURL { url in
                    handleSharedURL(url)
                }
        }
        .windowStyle(.plain)
        .defaultSize(width: 1400, height: 900)
        /*
        // Immersive Space for 3D window management
        ImmersiveSpace(id: "immersive-workspace") {
            ImmersiveSpaceView()
                .environmentObject(windowManager)
                .environmentObject(spatialManager)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        */
        // Grid launcher (original functionality)
        WindowGroup(id: "launcher") {
            LauncherView()
        }
        .windowStyle(.plain)
        .defaultSize(width: 800, height: 600)
        
        // Secondary windows - loaded on demand
        Group {
            WindowGroup("New Window", for: NewWindowID.ID.self) { $id in
                NewWindow(id: id ?? 1)
                    .environmentObject(windowManager)
                    .environmentObject(spatialManager)
            }

            WindowGroup(id: "open-project-window") {
                ProjectBrowserView(windowManager: windowManager)
                    .environmentObject(windowManager)
                    .environmentObject(spatialManager)
            }
            .windowStyle(.plain)
            .defaultSize(width: 1000, height: 700)
        }
    }
    
    private func handleSharedURL(_ url: URL) {
        // Handle CSV files shared from Safari or other apps
        if url.pathExtension.lowercased() == "csv" {
            Task {
                do {
                    let content = try String(contentsOf: url)
                    if let csvData = CSVParser.parse(content) {
                        // Convert CSVData to DataFrameData
                        let dataFrame = DataFrameData(
                            columns: csvData.headers,
                            rows: csvData.rows,
                            dtypes: csvData.columnTypes.enumerated().reduce(into: [String: String]()) { result, item in
                                let (index, type) = item
                                if index < csvData.headers.count {
                                    switch type {
                                    case .numeric:
                                        result[csvData.headers[index]] = "float"
                                    case .categorical:
                                        result[csvData.headers[index]] = "string"
                                    case .date:
                                        result[csvData.headers[index]] = "string"
                                    case .unknown:
                                        result[csvData.headers[index]] = "string"
                                    }
                                }
                            }
                        )
                        
                        // Create a new DataFrame window with the imported data
                        let windowId = windowManager.getNextWindowID()
                        let newWindow = windowManager.createWindow(.column, id: windowId)
                        windowManager.updateWindowDataFrame(newWindow.id, dataFrame: dataFrame)
                        windowManager.markWindowAsOpened(newWindow.id)
                    }
                } catch {
                    print("Error importing shared CSV: \(error)")
                }
            }
        }
    }
}

// MARK: - Missing Views Implementation
struct ImmersiveSpaceView: View {
    @EnvironmentObject var windowManager: WindowTypeManager
    @EnvironmentObject var spatialManager: SpatialWindowManager
    
    var body: some View {
        RealityView { content in
            setupImmersiveSpace(content: content)
        } update: { content in
            updateImmersiveSpace(content: content)
        }
        .gesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    handleDragGesture(value)
                }
        )
        .onAppear {
            print("🌌 ImmersiveSpace appeared")
        }
        .onDisappear {
            print("🌌 ImmersiveSpace disappeared")
        }
    }

    private func setupImmersiveSpace(content: RealityViewContent) {
        // Add lighting
        let directionalLight = DirectionalLight()
        directionalLight.light.intensity = 1000
        directionalLight.transform.rotation = simd_quatf(
            angle: -Float.pi / 4,
            axis: [1, 0, 0]
        )
        content.add(directionalLight)
        
        // Position windows in 3D space
        positionWindowsIn3DSpace(content: content)
    }
    
    private func updateImmersiveSpace(content: RealityViewContent) {
        // Update window positions and states
        let openWindows = windowManager.getAllWindows(onlyOpen: true)
        
        for window in openWindows {
            let immersiveState = $spatialManager.getImmersiveState(for: window.id)
            
            if immersiveState.isVisible {
                // Update window position and appearance in 3D space
                updateWindowInSpace(window: window, state: immersiveState, content: content)
            }
        }
    }

    private func positionWindowsIn3DSpace(content: RealityViewContent) {
        let openWindows = windowManager.getAllWindows(onlyOpen: true)
        
        for (index, window) in openWindows.enumerated() {
            let position = calculateWindowPosition(for: index, window: window)
            
            // Create a simple representation of the window
            let windowEntity = createWindowEntity(for: window)
            windowEntity.transform.translation = position
            
            content.add(windowEntity)
            
            // Update spatial manager state
            let transform = ImmersiveWindowState.Transform3D(
                translation: position
            )
            var state = spatialManager.getImmersiveState(for: window.id)
            state.transform = transform
            spatialManager.updateImmersiveState(for: window.id, state: state)
        }
    }
    
    private func calculateWindowPosition(for index: Int, window: NewWindowID) -> SIMD3<Float> {
        // Arrange windows in a circular pattern
        let radius: Float = 3.0
        let angleStep = 2.0 * Float.pi / Float(max(1, windowManager.getAllWindows(onlyOpen: true).count))
        let angle = angleStep * Float(index)
        
        let x = radius * cos(angle)
        let z = radius * sin(angle)
        let y = Float(window.position.y) * 0.01 // Convert to reasonable scale
        
        return SIMD3<Float>(x, y, z)
    }
    
    private func createWindowEntity(for window: NewWindowID) -> ModelEntity {
        // Create a simple plane to represent the window
        let mesh = MeshResource.generatePlane(width: 0.4, depth: 0.3)
        
        var material = SimpleMaterial()
        material.color = .init(tint: .white)
        material.metallic = 0.1
        material.roughness = 0.8
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "Window_\(window.id)"
        
        return entity
    }
    
    private func updateWindowInSpace(window: NewWindowID, state: ImmersiveWindowState, content: RealityViewContent) {
        // Find the window entity and update its transform
        if let windowEntity = content.entities.first(where: { $0.name == "Window_\(window.id)" }) {
            windowEntity.transform.translation = state.transform.translation
            windowEntity.transform.rotation = state.transform.simdRotation
            windowEntity.transform.scale = state.transform.scale
            windowEntity.isEnabled = state.isVisible
        }
    }
    
    private func handleDragGesture(_ value: EntityTargetValue<DragGesture.Value>) {
        let entity = value.entity
        let components = entity.name.components(separatedBy: "_")
        
        if let windowIDString = components.last,
           let windowID = Int(windowIDString) {
            
            let translation = value.convert(value.translation3D, from: .local, to: .scene)
            entity.transform.translation += translation
            
            let newTransform = ImmersiveWindowState.Transform3D(
                translation: entity.transform.translation
            )
            var state = spatialManager.getImmersiveState(for: windowID)
            state.transform = newTransform
            state.lastInteractionTime = Date()
            spatialManager.updateImmersiveState(for: windowID, state: state)
        }
    }
}

struct NewWindow: View {
    let id: Int
    @EnvironmentObject var windowManager: WindowTypeManager
    @EnvironmentObject var spatialManager: SpatialWindowManager
    
    var body: some View {
        Group {
            if let window = windowManager.getWindowSafely(for: id) {
                NewWindowContentView(window: window)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Window Not Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Window #\(id) could not be loaded.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Close Window") {
                        windowManager.markWindowAsClosed(id)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            windowManager.markWindowAsOpened(id)
            print("🪟 Window #\(id) opened")
        }
        .onDisappear {
            windowManager.markWindowAsClosed(id)
            print("🪟 Window #\(id) closed")
        }
    }
}

struct NewWindowContentView: View {
    let window: NewWindowID
    @EnvironmentObject var windowManager: WindowTypeManager
    @EnvironmentObject var spatialManager: SpatialWindowManager
    
    var body: some View {
        VStack {
            switch window.windowType {
            case .charts:
                ChartsView()
                
            case .spatial:
                if let pointCloudData = window.state.pointCloudData {
                    SpatialEditorView(windowID: window.id, initialPointCloud: pointCloudData)
                } else {
                    SpatialEditorView(windowID: window.id)
                }
                
            case .column:
                if let dataFrameData = window.state.dataFrameData {
                    DataTableContentView(windowID: window.id)
                } else {
                    DataTableContentView(windowID: window.id)
                }
                
            case .volume:
                if let volumeData = window.state.volumeData {
                    VolumeMetricsView(windowID: window.id, volumeData: volumeData)
                } else {
                    VolumeMetricsView(windowID: window.id)
                }
                
            case .pointcloud:
                if let pointCloudData = window.state.pointCloudData {
                    PointCloudEditorView(windowID: window.id, pointCloudData: pointCloudData)
                } else {
                    PointCloudEditorView(windowID: window.id)
                }
                
            case .model3d:
                if let model3DData = window.state.model3DData {
                    ModelViewerView(windowID: window.id, model3DData: model3DData)
                } else {
                    ModelViewerView(windowID: window.id)
                }
            }
        }
        .navigationTitle(window.windowType.displayName)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Menu {
                    Button("Save to Notebook") {
                        saveWindowToNotebook()
                    }
                    
                    Button("Export Python Code") {
                        exportPythonCode()
                    }
                    
                    Divider()
                    
                    Button("Close Window", role: .destructive) {
                        windowManager.markWindowAsClosed(window.id)
                    }
                } label: {
                    Label("Window Actions", systemImage: "ellipsis.circle")
                }
            }
        }
    }
    
    private func saveWindowToNotebook() {
        // Implement save window to notebook functionality
    }
    
    private func exportPythonCode() {
        // Implement export python code functionality
    }
}

struct VolumeMetricsView: View {
    let windowID: Int
    let volumeData: VolumeData?
    
    init(windowID: Int, volumeData: VolumeData? = nil) {
        self.windowID = windowID
        self.volumeData = volumeData
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gauge")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Volume Metrics")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let volumeData = volumeData {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title: \(volumeData.title)")
                    Text("Category: \(volumeData.category)")
                    Text("Metrics: \(volumeData.metrics.count)")
                }
                .font(.body)
                .foregroundColor(.secondary)
            } else {
                Text("No volume data available")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct PointCloudEditorView: View {
    let windowID: Int
    let pointCloudData: PointCloudData?
    
    init(windowID: Int, pointCloudData: PointCloudData? = nil) {
        self.windowID = windowID
        self.pointCloudData = pointCloudData
    }
    
    var body: some View {
        Group {
            if let pointCloudData = pointCloudData {
                SpatialEditorView(windowID: windowID, initialPointCloud: pointCloudData)
            } else {
                SpatialEditorView(windowID: windowID)
            }
        }
    }
}
*/
