/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The app's main entry point
*/

import SwiftUI
import RealityKit

@main
struct PultoApp: App {
    @StateObject private var windowTypeManager = WindowTypeManager.shared
    @StateObject private var autoSaveManager = AutoSaveManager.shared

    var body: some SwiftUI.Scene {
        mainWindow
        
        launcherWindow
        
        secondaryWindows
    }
    
    init() {
        setupProjectNotifications()
    }

    private var mainWindow: some SwiftUI.Scene {
        WindowGroup {
            PultoHomeView()
                .onAppear {
                    // Start auto-save system
                    autoSaveManager.startAutoSave()
                }
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
    }
    
    private var launcherWindow: some SwiftUI.Scene {
        WindowGroup(id: "launcher") {
            LauncherView()
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
    }
    
    private var secondaryWindows: some SwiftUI.Scene {
        WindowGroup(for: NewWindowID.ID.self) { $id in
            Group {
                if let id = id {
                    NewWindow(id: id)
                        .onAppear {
                            windowTypeManager.markWindowAsOpened(id)
                        }
                        .onDisappear {
                            windowTypeManager.markWindowAsClosed(id)
                        }
                } else {
                    ContentUnavailableView("Invalid Window", systemImage: "xmark.circle", description: Text("The window ID is invalid"))
                }
            }
        }
    }

    // MARK: - Project Notification Setup
    private func setupProjectNotifications() {
        // Listen for project selection notifications
        NotificationCenter.default.addObserver(
            forName: .projectSelected,
            object: nil,
            queue: .main
        ) { notification in
            if let project = notification.object as? Project {
                // Create 3D content when a project is selected
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    Demo3DCreator.createDemo3DWindowForProject(windowManager: windowTypeManager)
                }
            }
        }
        
        // Listen for project cleared notifications
        NotificationCenter.default.addObserver(
            forName: .projectCleared,
            object: nil,
            queue: .main
        ) { _ in
            // Optionally clean up project-specific windows
            Task { @MainActor in
                WindowTypeManager.shared.cleanupClosedWindows()
            }
        }
    }
}

// MARK: - Demo 3D Creator
@MainActor
class Demo3DCreator {
    static func createDemo3DWindowForProject(windowManager: WindowTypeManager) {
        // Only create 3D demo windows if there's an active project
        guard windowManager.selectedProject != nil else {
            print("No project selected - skipping 3D demo window creation")
            return
        }
        
        createDemo3DWindow(windowManager: windowTypeManager)
    }
    
    private static func createDemo3DWindow(windowManager: WindowTypeManager) {
        // Create a 3D model window
        let modelWindowID = windowManager.getNextWindowID()
        let modelPosition = WindowPosition(x: -200, y: 0, z: -100, width: 800, height: 600)
        let modelWindow = windowManager.createWindow(.model3d, id: modelWindowID, position: modelPosition)
        
        // Create a demo cube
        let demoCube = Model3DData.generateCube(size: 2.0)
        windowManager.updateWindowModel3DData(modelWindowID, model3DData: demoCube)
        windowManager.updateWindowContent(modelWindowID, content: "Demo 3D cube - created for project: \(windowManager.selectedProject?.name ?? "Unknown")")
        windowManager.addWindowTag(modelWindowID, tag: "Demo")
    }
}