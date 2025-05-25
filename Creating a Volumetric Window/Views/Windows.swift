//
//  NewWindowID.swift
//  UnderstandingVisionos
//
//  Created by Joshua Herman on 5/25/25.
//


import SwiftUI


struct NewWindowID: Identifiable {
    /// The unique identifier for the window.
    var id: Int
}

struct OpenWindowView: View {
    /// The `id` value that the main view uses to identify the SwiftUI window.
    @State var nextWindowID = NewWindowID(id: 1)


    /// The environment value for getting an `OpenWindowAction` instance.
    @Environment(\.openWindow) private var openWindow


    var body: some View {
        // Create a button in the center of the window that
        // launches a new SwiftUI window.
        Button("Open a new window") {
            // Open a new window with the assigned ID.
            openWindow(value: nextWindowID.id)


            // Increment the `id` value of the `nextWindowID` by 1.
            nextWindowID.id += 1
        }
    }
}

import SwiftUI


struct NewWindow: View {
    /// Acts as the main identifier for the new view.
    let id: Int

    var body: some View {
        // Create a text view that displays
        // the window's `id` value.
        Text("New window number \(id)")
    }
}
/*import SwiftUI


@main
struct EntryPoint: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        /// A `WindowGroup` for each newly created window in the app's main view.
        WindowGroup("New Window", for: NewWindowID.ID.self) { $id in
            NewWindow(id: id ?? 1)
        }
    }
}
*/ 
