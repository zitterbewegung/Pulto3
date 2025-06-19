/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The app's main entry point
*/

import SwiftUI


@main
struct EntryPoint: App {

    var body: some Scene {
        // Primary window - always loaded
        WindowGroup(id: "main") {
            PultoHomeView()
        }
        .defaultSize(width: 1280, height: 850)

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

