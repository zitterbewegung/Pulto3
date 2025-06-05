/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The app's main entry point
*/

import SwiftUI

@main
struct EntryPoint: App {
    let heightModifier: CGFloat = 0.25

    var body: some Scene {
        // Make this the default/main window group
        WindowGroup(id: "main") {
            PultoHomeView()
        }
        .defaultSize(width: 1280, height: 900) // Add explicit sizing

        WindowGroup("New Window", for: NewWindowID.ID.self) { $id in
            NewWindow(id: id ?? 1)
        }

        WindowGroup("Volumetric") {
            VolumetricWindow()
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1280, height: 720)

        // Move OpenWindowView to a separate group
        // Add this new WindowGroup for the volumetric view
        WindowGroup(id: "open-project-window") {
            OpenWindowView()
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 600, height: 400, depth: 300, in: .millimeters)
    }
}
/*
#Preview {
    #PreviewLayout(width: 800, height: 600) {
        EntryPoint().body
    }
}
*/
