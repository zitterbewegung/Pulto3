/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app's main entry point
*/

import SwiftUI

@main
struct EntryPoint: App {
    /// The multiplier for the height of the volumetric window.
    let heightModifier: CGFloat = 0.25

    var body: some Scene {
        WindowGroup {
            MainView()
        }

        // Configure a window group with a volumetric window.
        WindowGroup(id: "VolumetricWindow") {
            VolumetricWindow()
        }
        .windowStyle(.volumetric)
        // Scale the size of window group relative to the volumetric window's size.
        .defaultSize(
            width: VolumetricWindow.size,
            height: heightModifier * VolumetricWindow.size,
            depth: VolumetricWindow.size,
            in: .meters
        )
    }
}
