//
//  NewWindowID.swift
//  UnderstandingVisionos
//
//  Created by Joshua Herman on 5/25/25.
//

import SwiftUI

enum WindowType: String, CaseIterable, Codable, Hashable {
    case notebook = "Notebook Chart"
    case spatial = "Spatial Editor"

    var displayName: String {
        return self.rawValue
    }
}

struct NewWindowID: Identifiable, Codable, Hashable {
    /// The unique identifier for the window.
    var id: Int
    /// The type of window to create
    var windowType: WindowType
}

// Global storage for window types (since we can only pass Int IDs)
class WindowTypeManager: ObservableObject {
    static let shared = WindowTypeManager()
    @Published private var windowTypes: [Int: WindowType] = [:]

    private init() {}

    func setType(_ type: WindowType, for id: Int) {
        windowTypes[id] = type
    }

    func getType(for id: Int) -> WindowType {
        return windowTypes[id] ?? .spatial // Default to spatial if not found
    }
}

struct OpenWindowView: View {
    /// The `id` value that the main view uses to identify the SwiftUI window.
    @State var nextWindowID = 1

    /// The environment value for getting an `OpenWindowAction` instance.
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack {

            VStack(spacing: 20) {

                Text("Choose Window Type")
                    .font(.title2)
                    .padding()

                // Create buttons for each window type
                ForEach(WindowType.allCases, id: \.self) { windowType in
                    Button("Open \(windowType.displayName) Window") {
                        // Store the window type for this ID
                        WindowTypeManager.shared.setType(windowType, for: nextWindowID)

                        // Open window with just the ID (compatible with your existing setup)
                        openWindow(value: nextWindowID)

                        // Increment the `id` value for the next window
                        nextWindowID += 1
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
  
        }

    }
}

struct NewWindow: View {
    /// Acts as the main identifier for the new view.
    let id: Int
    @StateObject private var windowTypeManager = WindowTypeManager.shared

    var body: some View {
        let windowType = windowTypeManager.getType(for: id)

        VStack{
            Text("\(windowType.displayName) - Window #\(id)")
                .font(.title2)
                .padding()

            // Display the appropriate view based on window type
            switch windowType {
                case .notebook:
                    NotebookChartsView()
                case .spatial:
                    SpatialEditorView()

            }
            
        }
    }
}



/*
// Your existing App structure will work as-is:
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
*/
