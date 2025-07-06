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
        // Primary home window - main interface
        WindowGroup(id: "home") {
            PultoHomeView()
                .environmentObject(windowManager)
                .onOpenURL { url in
                    handleSharedURL(url)
                }
        }
        .windowStyle(.plain)
        .defaultSize(width: 1400, height: 900)
        
        // Spatial workspace window - for data visualization
        WindowGroup(id: "main") {
            EnvironmentView()
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