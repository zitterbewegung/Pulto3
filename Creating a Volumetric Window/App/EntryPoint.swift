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
        /// A `WindowGroup` for each newly created window in the app's main view.
        WindowGroup("New Window", for: NewWindowID.ID.self) { $id in
            NewWindow(id: id ?? 1)
        }
        // Configure a window group with a volumetric window.

        WindowGroup() {
            VolumetricWindow()
 
        }
        .windowStyle(.volumetric)
        // Scale the size of the window group relative to the volumetric window's size.
        .defaultSize(
            width: VolumetricWindow.defaultSize,
            height: heightModifier * VolumetricWindow.defaultSize,
            depth: VolumetricWindow.defaultSize,
            in: .meters
        )
    }
}
