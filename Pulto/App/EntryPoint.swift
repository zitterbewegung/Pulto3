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
                    // Case 2: We have a USDZ file bookmark - create Model3DData from it
                    Model3DVolumetricView(
                        windowID: id,
                        modelData: Model3DData(
                            title: "Imported USDZ Model",
                            modelType: "usdz",
                            scale: 1.0
                        )
                    )
                    .environmentObject(windowManager)
                } else {
                    // Case 3: No model data available
                    VStack {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 100))
                            .foregroundStyle(.gray)
                        Text("No 3D model loaded")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("Create a demo model or import a USDZ file")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                Text("Error in loading window state")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.8, height: 0.8, depth: 0.8, in: .meters)

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
