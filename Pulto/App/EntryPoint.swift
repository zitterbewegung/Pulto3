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

    private var secondaryWindows: some SwiftUI.Scene {
        Group {
            WindowGroup(for: NewWindowID.ID.self) { $id in
                if let id = id {
                    NewWindow(id: id)
                }
            }

            WindowGroup(id: "open-project-window") {
                ProjectBrowserView(windowManager: windowManager)   // ← added argument
                    .environmentObject(windowManager)
            }
            .windowStyle(.plain)
            .defaultSize(width: 1_000, height: 700)
        }
    }

    // MARK: - visionOS-only Scenes
    #if os(visionOS)
    private var volumetricWindows: some SwiftUI.Scene {
        Group {
            // Point-cloud volume
            WindowGroup(id: "volumetric-pointcloud", for: Int.self) { $id in
                if
                    let id = id,
                    let win = windowManager.getWindow(for: id)
                {
                    PointCloudVolumetricView(
                        windowID: id,
                        pointCloudData: win.state.pointCloudData ?? generateDefaultPointCloud()
                    )
                    .frame(width: 400, height: 400)
                    .environmentObject(windowManager)
                }
            }
            .windowStyle(.volumetric)
            .defaultSize(width: 0.4, height: 0.4, depth: 0.4, in: .meters)

            // 3-D model volume
            WindowGroup(id: "volumetric-model3d", for: Int.self) { $id in
                if
                    let id = id,
                    let win = windowManager.getWindow(for: id)
                {
                    Model3DVolumetricView(
                        windowID: id,
                        modelData: win.state.model3DData ?? generateDefault3DModel()
                    )
                    .frame(width: 400, height: 400)
                    .environmentObject(windowManager)
                }
            }
            .windowStyle(.volumetric)
            .defaultSize(width: 0.4, height: 0.4, depth: 0.4, in: .meters)
        }
    }

    private var immersiveWorkspace: some SwiftUI.Scene {
        ImmersiveSpace(id: "immersive-workspace") {
            ImmersiveWorkspaceView()
                .environmentObject(windowManager)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
    #endif

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

    // MARK: - Demo data
    private func generateDefaultPointCloud() -> PointCloudData {
        PointCloudDemo.generateSpherePointCloudData(radius: 10, points: 1_000)
    }

    private func generateDefault3DModel() -> Model3DData {
        Model3DData.generateTestPyramid()
    }
}



/*
@main
struct EntryPoint: App {
    @StateObject private var windowManager = WindowTypeManager.shared

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
            }

            WindowGroup(id: "open-project-window") {
                ProjectBrowserView(windowManager: windowManager)
                    .environmentObject(windowManager)
            }
            .windowStyle(.plain)
            .defaultSize(width: 1000, height: 700)
        }

        // Volumetric Windows for 3D content
        #if os(visionOS)
        Group {
            // Volumetric window for Point Cloud
            WindowGroup(id: "volumetric-pointcloud", for: Int.self) { $windowID in
                if let windowID = windowID,
                   let window = windowManager.getWindow(for: windowID) {
                    PointCloudVolumetricView(
                        windowID: windowID,
                        pointCloudData: window.state.pointCloudData ?? generateDefaultPointCloud()
                    )
                    .frame(width: 400, height: 400)
                    .environmentObject(windowManager)
                }
            }
            .windowStyle(.volumetric)
            .defaultSize(width: 0.4, height: 0.4, depth: 0.4, in: .meters)

            // Volumetric window for 3D Model
            WindowGroup(id: "volumetric-model3d", for: Int.self) { $windowID in
                if let windowID = windowID,
                   let window = windowManager.getWindow(for: windowID) {
                    Model3DVolumetricView(
                        windowID: windowID,
                        modelData: window.state.model3DData ?? generateDefault3DModel()
                    )
                    .frame(width: 400, height: 400)
                    .environmentObject(windowManager)
                }
            }
            .windowStyle(.volumetric)
            .defaultSize(width: 0.4, height: 0.4, depth: 0.4, in: .meters)
        }

        // Optional: ImmersiveSpace for full immersive experience
        ImmersiveSpace(id: "immersive-workspace") {
            ImmersiveWorkspaceView()
                .environmentObject(windowManager)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        #endif
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

    // Default data generators
    private func generateDefaultPointCloud() -> PointCloudData {
        return PointCloudDemo.generateSpherePointCloudData(radius: 10.0, points: 1000)
    }

    private func generateDefault3DModel() -> Model3DData {
        return Model3DData.generateTestPyramid()
    }
}



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
            }

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

*/
