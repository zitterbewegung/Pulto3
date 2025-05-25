//
//  NotebookWindows.swift
//  Volumetric Window
//
//  Created by Joshua Herman on 5/25/25.
//  Copyright © 2025 Apple. All rights reserved.
//
/*
import SwiftUI


struct NotebookNewWindowID: Identifiable {
    /// The unique identifier for the window.
    var id: Int
}

struct NotebookNewWindowIDOpenWindowView: View {
    /// The `id` value that the main view uses to identify the SwiftUI window.
    @State var notebooknextWindowID = NewWindowID(id: 1)


    /// The environment value for getting an `OpenWindowAction` instance.
    @Environment(\.openWindow) private var notebookopenWindow


    var body: some View {
        // Create a button in the center of the window that
        // launches a new SwiftUI window.
        Button("Open a new Notebook window") {
            // Open a new window with the assigned ID.
            notebookopenWindow(value: notebooknextWindowID.id)


            // Increment the `id` value of the `nextWindowID` by 1.
            notebooknextWindowID.id += 1
        }
    }
}


struct notebookNewWindow: View {
    /// Acts as the main identifier for the new view.
    let id: Int

    var body: some View {
        // Create a text view that displays
        // the window's `id` value.
        VStack{
            Text("New window number \(id)")
            NotebookChartsView()

        }
    }
}
*/
