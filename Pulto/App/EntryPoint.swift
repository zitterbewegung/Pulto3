/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The app's main entry point
*/

import SwiftUI


@main
struct EntryPoint: App {
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
        // Primary window - always loaded
        WindowGroup(id: "main") {
            PultoHomeView()
        }
        .defaultSize(width: 1280, height: 850)
        // Root controller that lets the person launch the grid.
        WindowGroup {
            LauncherView()
        }
        .windowStyle(.plain)
        .defaultSize(width: 500, height: 300)
        /*
        // --- 3 × 3 Grid ----------------------------------------------------
        configureScene(WindowGroup(id: "grid-0-0") { GridTileView(row: 0, col: 0) }, row: 0, col: 0)
        configureScene(WindowGroup(id: "grid-0-1") { GridTileView(row: 0, col: 1) }, row: 0, col: 1)
        configureScene(WindowGroup(id: "grid-0-2") { GridTileView(row: 0, col: 2) }, row: 0, col: 2)

        configureScene(WindowGroup(id: "grid-1-0") { GridTileView(row: 1, col: 0) }, row: 1, col: 0)
        configureScene(WindowGroup(id: "grid-1-1") { GridTileView(row: 1, col: 1) }, row: 1, col: 1)
        configureScene(WindowGroup(id: "grid-1-2") { GridTileView(row: 1, col: 2) }, row: 1, col: 2)

        configureScene(WindowGroup(id: "grid-2-0") { GridTileView(row: 2, col: 0) }, row: 2, col: 0)
        configureScene(WindowGroup(id: "grid-2-1") { GridTileView(row: 2, col: 1) }, row: 2, col: 1)
        configureScene(WindowGroup(id: "grid-2-2") { GridTileView(row: 2, col: 2) }, row: 2, col: 2)
      */
        // Secondary windows - loaded on demand
        Group {
            WindowGroup("New Window", for: NewWindowID.ID.self) { $id in
                NewWindow(id: id ?? 1)
            }

            //WindowGroup("Volumetric") {
            //    VolumetricWindow()
            //}
            //.windowStyle(.volumetric)
            //.defaultSize(width: 1280, height: 720)

            WindowGroup(id: "open-project-window") {
                OpenWindowView()
            }
            .windowStyle(.volumetric)
            .defaultSize(width: 1200, height: 400, depth: 100, in: .millimeters)

        }



        }
}

