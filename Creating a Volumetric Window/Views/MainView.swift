/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app's main view.
*/

import SwiftUI

struct MainView: View {
    /// The environment value that provides an action for that opens new windows.
    @Environment(\.openWindow) var openWindow

    var body: some View {
        // Display a line of text and
        // open a new SwiftUI volumetric window.
        Text("Volumetric Window Example")
            .onAppear {
                openWindow(id: "VolumetricWindow")
            }
    }
}

#Preview(windowStyle: .automatic) {
    MainView()
}
