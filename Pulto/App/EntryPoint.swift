/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The app's main entry point
*/

import SwiftUI
import RealityKit

@main
struct EntryPoint: App {
    @StateObject private var windowManager = WindowTypeManager.shared

    // MARK: Scene graph
    @SceneBuilder
    var body: some SwiftUI.Scene {
        mainWindow
        launcherWindow
        secondaryWindows
        #if os(visionOS)
        volumetricWindows
        immersiveWorkspace
        #endif
    }

    // MARK: - 2-D Scenes
    private var mainWindow: some SwiftUI.Scene {
        WindowGroup(id: "main") {
            EnvironmentView()
                .environmentObject(windowManager)
                .onOpenURL(perform: handleSharedURL(_:))
                .onAppear {
                    // Automatically create a 3D model window on app start for demo purposes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        createDemo3DWindow()
                    }
                }
        }
        .windowStyle(.plain)
        .defaultSize(width: 1_400, height: 900)
    }

    private var launcherWindow: some SwiftUI.Scene {
        WindowGroup(id: "launcher") {
            LauncherView()
        }
        .windowStyle(.plain)
        .defaultSize(width: 800, height: 600)
    }

    @SceneBuilder
    private var secondaryWindows: some SwiftUI.Scene {
        WindowGroup(for: NewWindowID.ID.self) { $id in
            if let id = id {
                NewWindow(id: id)
            }
        }

        WindowGroup(id: "open-project-window") {
            ProjectBrowserView(windowManager: windowManager)
                .environmentObject(windowManager)
        }
        .windowStyle(.plain)
        .defaultSize(width: 1_000, height: 700)
    }

    // MARK: - visionOS-only Scenes
    #if os(visionOS)
    @SceneBuilder
    private var volumetricWindows: some SwiftUI.Scene {
        // Point-cloud volume
        WindowGroup(id: "volumetric-pointcloud", for: Int.self) { $id in
            if
                let id = id,
                let win = windowManager.getWindow(for: id),
                let pointCloudData = win.state.pointCloudData
            {
                PointCloudVolumetricView(
                    windowID: id,
                    pointCloudData: pointCloudData
                )
                .environmentObject(windowManager)
            } else {
                EmptyView()
            }
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.4, height: 0.4, depth: 0.4, in: .meters)

        // 3-D model volume

        WindowGroup(id: "volumetric-model3d", for: Int.self) { $id in
            if let id = id, let win = windowManager.getWindow(for: id) {
                if let modelData = win.state.model3DData {
                    // Case 1: We have parsed model data
                    Model3DVolumetricView(
                        windowID: id,
                        modelData: modelData
                    )
                    .environmentObject(windowManager)
                } else if let usdzBookmark = win.state.usdzBookmark {
                    // Case 2: We have a USDZ file bookmark - create a placeholder model and show it
                    let placeholderModel = Model3DData(
                        title: "USDZ Model",
                        modelType: "usdz",
                        scale: 1.0
                    )
                    Model3DVolumetricView(
                        windowID: id,
                        modelData: placeholderModel
                    )
                    .environmentObject(windowManager)
                } else {
                    // Case 3: No model data available - create a default cube
                    let defaultCube = Model3DData.generateCube(size: 2.0)
                    Model3DVolumetricView(
                        windowID: id,
                        modelData: defaultCube
                    )
                    .environmentObject(windowManager)
                }
            } else {
                // Error case - still show a default cube
                let errorCube = Model3DData.generateCube(size: 2.0)
                Model3DVolumetricView(
                    windowID: 999, // dummy window ID
                    modelData: errorCube
                )
                .environmentObject(windowManager)
            }
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 15, height: 15, depth: 15, in: .meters)

        // 3-D chart volume
        WindowGroup(id: "volumetric-chart3d", for: Int.self) { $id in
            if
                let id = id,
                let win = windowManager.getWindow(for: id),
                let chartData = win.state.chart3DData
            {
                Chart3DVolumetricView(
                    windowID: id,
                    chartData: chartData
                )
                .environmentObject(windowManager)
            } else {
                EmptyView()
            }
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.4, height: 0.4, depth: 0.4, in: .meters)
    }

    private var immersiveWorkspace: some SwiftUI.Scene {
        ImmersiveSpace(id: "immersive-workspace") {
            ImmersiveWorkspaceView()
                .environmentObject(windowManager)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
    #endif

    // MARK: - Demo 3D Window Creation
    @MainActor
    private func createDemo3DWindow() {
        // Create a 3D model window
        let modelWindowID = windowManager.getNextWindowID()
        let modelPosition = WindowPosition(x: -200, y: 0, z: -100, width: 800, height: 600)
        let modelWindow = windowManager.createWindow(.model3d, id: modelWindowID, position: modelPosition)
        
        // Try to load the Pulto USDZ file first, fallback to demo cube
        if let pultoModel = loadPultoUSDZModel() {
            windowManager.updateWindowModel3DData(modelWindowID, model3DData: pultoModel)
            windowManager.updateWindowContent(modelWindowID, content: "Pulto USDZ model - automatically loaded from Resources")
            windowManager.addWindowTag(modelWindowID, tag: "Pulto-USDZ")
        } else {
            // Create a demo cube as fallback
            let demoCube = Model3DData.generateCube(size: 2.0)
            windowManager.updateWindowModel3DData(modelWindowID, model3DData: demoCube)
            windowManager.updateWindowContent(modelWindowID, content: "Demo 3D cube - automatically created on app launch")
            windowManager.addWindowTag(modelWindowID, tag: "Demo")
        }
        
        // Create a 3D chart window
        let chartWindowID = windowManager.getNextWindowID()
        let chartPosition = WindowPosition(x: 200, y: 0, z: -100, width: 800, height: 600)
        let chartWindow = windowManager.createWindow(.charts, id: chartWindowID, position: chartPosition)
        
        // Create demo 3D chart data
        let demo3DChart = Chart3DData.generateWave()
        windowManager.updateWindowChart3DData(chartWindowID, chart3DData: demo3DChart)
        windowManager.updateWindowContent(chartWindowID, content: "Demo 3D wave chart - automatically created on app launch")
        windowManager.addWindowTag(chartWindowID, tag: "Demo-Chart3D")
        
        // Open the volumetric windows
        #if os(visionOS)
        openWindow(id: "volumetric-model3d", value: modelWindowID)
        
        // Delay the chart window slightly so they don't overlap
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            openWindow(id: "volumetric-chart3d", value: chartWindowID)
        }
        #endif
    }
    
    private func loadPultoUSDZModel() -> Model3DData? {
        // Try to find and load the Pulto USDZ file
        guard let bundlePath = Bundle.main.path(forResource: "Pluto_1_2374", ofType: "usdz") else {
            print("Pulto USDZ file not found in bundle")
            return nil
        }
        
        let fileURL = URL(fileURLWithPath: bundlePath)
        
        do {
            let fileSize = try FileManager.default.attributesOfItem(atPath: bundlePath)[.size] as? Int64 ?? 0
            print("Found Pulto USDZ file: \(bundlePath) (\(fileSize) bytes)")
            
            // Create a model representation for the USDZ file
            // Since we can't directly parse USDZ, we'll create a placeholder that represents it
            var model = Model3DData(title: "Pulto Model", modelType: "usdz")
            
            // Create a sophisticated sphere to represent the Pulto planet
            let radius = 2.0
            let segments = 32 // High detail for the planet
            
            // Generate vertices for a detailed sphere
            for i in 0...segments {
                let phi = Double(i) * .pi / Double(segments)
                for j in 0..<(segments * 2) {
                    let theta = Double(j) * 2.0 * .pi / Double(segments * 2)
                    
                    // Add some surface variation to make it more planet-like
                    let variation = 0.1 * sin(phi * 3) * cos(theta * 4)
                    let actualRadius = radius + variation
                    
                    let x = actualRadius * sin(phi) * cos(theta)
                    let y = actualRadius * cos(phi)
                    let z = actualRadius * sin(phi) * sin(theta)
                    
                    model.vertices.append(Model3DData.Vertex3D(x: x, y: y, z: z))
                }
            }
            
            // Generate faces for the sphere
            for i in 0..<segments {
                for j in 0..<(segments * 2) {
                    let current = i * (segments * 2) + j
                    let next = i * (segments * 2) + (j + 1) % (segments * 2)
                    let currentNext = (i + 1) * (segments * 2) + j
                    let nextNext = (i + 1) * (segments * 2) + (j + 1) % (segments * 2)
                    
                    if i < segments {
                        // Create triangular faces for better detail
                        model.faces.append(Model3DData.Face3D(vertices: [current, next, nextNext], materialIndex: 0))
                        model.faces.append(Model3DData.Face3D(vertices: [current, nextNext, currentNext], materialIndex: 0))
                    }
                }
            }
            
            // Create materials that represent Pulto's appearance
            model.materials = [
                Model3DData.Material3D(
                    name: "pulto_surface", 
                    color: "teal", 
                    metallic: 0.3, 
                    roughness: 0.7, 
                    transparency: 0.0
                )
            ]
            
            return model
            
        } catch {
            print("Error accessing Pulto USDZ file: \(error)")
            return nil
        }
    }
    
    @Environment(\.openWindow) private var openWindow

    // MARK: - Shared-file handler
    private func handleSharedURL(_ url: URL) {
        guard url.pathExtension.lowercased() == "csv" else { return }

        Task {
            do {
                let text = try String(contentsOf: url)
                guard let csv = CSVParser.parse(text) else { return }

                let dtypes = Dictionary(uniqueKeysWithValues: zip(
                    csv.headers,
                    csv.columnTypes.map { type -> String in
                        switch type {
                        case .numeric:     return "float"
                        case .categorical: return "string"
                        case .date:        return "string"
                        case .unknown:     return "string"
                        }
                    }
                ))

                let frame = DataFrameData(
                    columns: csv.headers,
                    rows:    csv.rows,
                    dtypes:  dtypes
                )

                let id  = windowManager.getNextWindowID()
                let win = windowManager.createWindow(.column, id: id)
                windowManager.updateWindowDataFrame(win.id, dataFrame: frame)
                windowManager.markWindowAsOpened(win.id)

            } catch {
                print("Error importing shared CSV: \(error)")
            }
        }
    }

}