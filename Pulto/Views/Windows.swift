//
//  NewWindowID.swift
//  UnderstandingVisionos
//
//  Created by Joshua Herman on 5/25/25.
//

import SwiftUI
import Foundation

enum WindowType: String, CaseIterable, Codable, Hashable {
    case notebook = "Notebook Chart"
    case spatial = "Spatial Editor"
    case column = "DataFrame Viewer"
    //case pointcloud = "Point Cloud View"
    var displayName: String {
        return self.rawValue
    }

    // Jupyter cell type mapping
    var jupyterCellType: String {
        switch self {
        case .notebook:
            return "code"
        case .spatial:
            return "markdown"
        case .column:
            return "code"
        //case .pointcloud:
        //    return "pointcloud"
        }
    }
}

struct WindowPosition: Codable, Hashable {
    var x: Double
    var y: Double
    var z: Double
    var width: Double
    var height: Double
    var depth: Double?

    init(x: Double = 0, y: Double = 0, z: Double = 0,
         width: Double = 400, height: Double = 300, depth: Double? = nil) {
        self.x = x
        self.y = y
        self.z = z
        self.width = width
        self.height = height
        self.depth = depth
    }
}

struct WindowState: Codable, Hashable {
    var isMinimized: Bool = false
    var isMaximized: Bool = false
    var opacity: Double = 1.0
    var lastModified: Date = Date()
    var content: String = ""

    init(isMinimized: Bool = false, isMaximized: Bool = false,
         opacity: Double = 1.0, content: String = "") {
        self.isMinimized = isMinimized
        self.isMaximized = isMaximized
        self.opacity = opacity
        self.content = content
        self.lastModified = Date()
    }
}

struct NewWindowID: Identifiable, Codable, Hashable {
    /// The unique identifier for the window.
    var id: Int
    /// The type of window to create
    var windowType: WindowType
    /// Position and size information
    var position: WindowPosition
    /// Window state information
    var state: WindowState
    /// Creation timestamp
    var createdAt: Date

    init(id: Int, windowType: WindowType,
         position: WindowPosition = WindowPosition(),
         state: WindowState = WindowState()) {
        self.id = id
        self.windowType = windowType
        self.position = position
        self.state = state
        self.createdAt = Date()
    }
}

// Enhanced window manager with export capabilities
class WindowTypeManager: ObservableObject {
    static let shared = WindowTypeManager()

    @Published private var windows: [Int: NewWindowID] = [:]

    private init() {}

    func createWindow(_ type: WindowType, id: Int, position: WindowPosition = WindowPosition()) -> NewWindowID {
        let window = NewWindowID(id: id, windowType: type, position: position)
        windows[id] = window
        return window
    }

    func getWindow(for id: Int) -> NewWindowID? {
        return windows[id]
    }

    func getType(for id: Int) -> WindowType {
        return windows[id]?.windowType ?? .spatial
    }

    func updateWindowPosition(_ id: Int, position: WindowPosition) {
        windows[id]?.position = position
    }

    func updateWindowState(_ id: Int, state: WindowState) {
        windows[id]?.state = state
    }

    func updateWindowContent(_ id: Int, content: String) {
        windows[id]?.state.content = content
        windows[id]?.state.lastModified = Date()
    }

    func getAllWindows() -> [NewWindowID] {
        return Array(windows.values).sorted { $0.id < $1.id }
    }

    func removeWindow(_ id: Int) {
        windows.removeValue(forKey: id)
    }

    // MARK: - Jupyter Export Functions

    func exportToJupyterNotebook() -> String {
        let notebook = createJupyterNotebook()
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: notebook, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            print("Error creating JSON: \(error)")
            return "{}"
        }
    }

    private func createJupyterNotebook() -> [String: Any] {
        let cells = getAllWindows().map { window in
            createJupyterCell(from: window)
        }

        let metadata: [String: Any] = [
            "kernelspec": [
                "display_name": "Python 3",
                "language": "python",
                "name": "python3"
            ],
            "language_info": [
                "name": "python",
                "version": "3.8.0"
            ],
            "visionos_export": [
                "export_date": ISO8601DateFormatter().string(from: Date()),
                "total_windows": windows.count,
                "window_types": Array(Set(windows.values.map { $0.windowType.rawValue }))
            ]
        ]

        return [
            "cells": cells,
            "metadata": metadata,
            "nbformat": 4,
            "nbformat_minor": 4
        ]
    }

    private func createJupyterCell(from window: NewWindowID) -> [String: Any] {
        var cell: [String: Any] = [
            "cell_type": window.windowType.jupyterCellType,
            "metadata": [
                "window_id": window.id,
                "window_type": window.windowType.rawValue,
                "position": [
                    "x": window.position.x,
                    "y": window.position.y,
                    "z": window.position.z,
                    "width": window.position.width,
                    "height": window.position.height
                ],
                "state": [
                    "minimized": window.state.isMinimized,
                    "maximized": window.state.isMaximized,
                    "opacity": window.state.opacity
                ],
                "timestamps": [
                    "created": ISO8601DateFormatter().string(from: window.createdAt),
                    "modified": ISO8601DateFormatter().string(from: window.state.lastModified)
                ]
            ]
        ]

        // Add content based on window type
        let source = generateCellContent(for: window)
        cell["source"] = [source]

        // Add execution count for code cells
        if window.windowType.jupyterCellType == "code" {
            cell["execution_count"] = NSNull()
            cell["outputs"] = []
        }

        return cell
    }

    private func generateCellContent(for window: NewWindowID) -> String {
        switch window.windowType {
        //case .pointcloud:
        //    return generateNotebookCellContent(for: window)
        case .notebook:
            return generateNotebookCellContent(for: window)
        case .spatial:
            return generateSpatialCellContent(for: window)
        case .column:
            return generateDataFrameCellContent(for: window)
        }
    }

    private func generateNotebookCellContent(for window: NewWindowID) -> String {
        let baseContent = """
        # Notebook Chart Window #\(window.id)
        # Created: \(DateFormatter.localizedString(from: window.createdAt, dateStyle: .short, timeStyle: .short))
        # Position: (\(window.position.x), \(window.position.y), \(window.position.z))
        
        import matplotlib.pyplot as plt
        import numpy as np
        
        # Chart configuration from VisionOS window
        fig, ax = plt.subplots(figsize=(\(window.position.width/50), \(window.position.height/50)))
        
        """

        return window.state.content.isEmpty ? baseContent : baseContent + "\n" + window.state.content
    }

    private func generateSpatialCellContent(for window: NewWindowID) -> String {
        let content = """
        # Spatial Editor Window #\(window.id)
        
        **Position:** (\(window.position.x), \(window.position.y), \(window.position.z))  
        **Size:** \(window.position.width) × \(window.position.height)  
        **Created:** \(DateFormatter.localizedString(from: window.createdAt, dateStyle: .short, timeStyle: .short))  
        **Last Modified:** \(DateFormatter.localizedString(from: window.state.lastModified, dateStyle: .short, timeStyle: .short))
        
        ## Spatial Content
        
        """

        return window.state.content.isEmpty ? content + "*No content available*" : content + window.state.content
    }

    private func generateDataFrameCellContent(for window: NewWindowID) -> String {
        let baseContent = """
        # DataFrame Viewer Window #\(window.id)
        # Created: \(DateFormatter.localizedString(from: window.createdAt, dateStyle: .short, timeStyle: .short))
        # Position: (\(window.position.x), \(window.position.y), \(window.position.z))
        
        import pandas as pd
        import numpy as np
        
        # DataFrame configuration from VisionOS window
        # Window size: \(window.position.width) × \(window.position.height)
        
        """

        return window.state.content.isEmpty ? baseContent : baseContent + "\n" + window.state.content
    }

    // MARK: - File Export

    func saveNotebookToFile(filename: String = "visionos_workspace") -> URL? {
        let notebook = exportToJupyterNotebook()

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory,
                                                                in: .userDomainMask).first else {
            return nil
        }

        let fileURL = documentsDirectory.appendingPathComponent("\(filename).ipynb")

        do {
            try notebook.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error saving notebook: \(error)")
            return nil
        }
    }
}

struct OpenWindowView: View {
    @State var nextWindowID = 1
    @Environment(\.openWindow) private var openWindow
    @StateObject private var windowManager = WindowTypeManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose Window Type")
                .font(.title2)
                .padding()

            // Create buttons for each window type
            ForEach(WindowType.allCases, id: \.self) { windowType in
                Button("Open \(windowType.displayName) Window") {
                    // Create and store the complete window configuration
                    let position = WindowPosition(
                        x: Double.random(in: -200...200),
                        y: Double.random(in: -100...100),
                        z: Double.random(in: -50...50),
                        width: 400,
                        height: 300
                    )

                    _ = windowManager.createWindow(windowType, id: nextWindowID, position: position)
                    openWindow(value: nextWindowID)
                    nextWindowID += 1
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            Divider()

            // Export controls
            VStack(spacing: 10) {
                Text("Export Options")
                    .font(.headline)

                Button("Export to Jupyter Notebook") {
                    if let fileURL = windowManager.saveNotebookToFile() {
                        print("Notebook saved to: \(fileURL.path)")
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)

                Button("Copy Notebook JSON") {
                    let notebookJSON = windowManager.exportToJupyterNotebook()
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(notebookJSON, forType: .string)
                    #endif
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Window management
            if !windowManager.getAllWindows().isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 5) {
                    Text("Active Windows (\(windowManager.getAllWindows().count))")
                        .font(.headline)

                    ForEach(windowManager.getAllWindows()) { window in
                        HStack {
                            Text("\(window.windowType.displayName) #\(window.id)")
                            Spacer()
                            Text("(\(Int(window.position.x)), \(Int(window.position.y)), \(Int(window.position.z)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
    }
}

struct NewWindow: View {
    let id: Int
    @StateObject private var windowTypeManager = WindowTypeManager.shared
    @State private var windowContent = ""

    var body: some View {
        if let window = windowTypeManager.getWindow(for: id) {
            VStack {
                HStack {
                    Text("\(window.windowType.displayName) - Window #\(id)")
                        .font(.title2)
                    Spacer()
                    Text("Pos: (\(Int(window.position.x)), \(Int(window.position.y)), \(Int(window.position.z)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()

                // Display the appropriate view based on window type
                switch window.windowType {
                case .notebook:
                    NotebookChartsView()
                case .spatial:
                    SpatialEditorView()
                case .column:
                    DataTableContentView()
                //case .pointcloud: break
                //    PointCloudView(points: [SIMD3<Float>], colors: <#[SIMD4<Float>]#>, title: <#String#>)
                }

                // Content editor for export
                VStack(alignment: .leading) {
                    Text("Window Content (for export):")
                        .font(.caption)
                    TextEditor(text: $windowContent)
                        .frame(height: 60)
                        .border(Color.gray.opacity(0.3))
                        .onChange(of: windowContent) { newValue in
                            windowTypeManager.updateWindowContent(id, content: newValue)
                        }
                }
                .padding()
            }
        } else {
            Text("Window #\(id) not found")
                .font(.title2)
                .padding()
        }
    }
}

/* Placeholder views - replace with your actual implementations
struct NotebookChartsView: View {
    var body: some View {
        Text("Notebook Charts Content")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.blue.opacity(0.1))
    }
}

struct SpatialEditorView: View {
    var body: some View {
        Text("Spatial Editor Content")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.green.opacity(0.1))
    }
}

struct DataTableContentView: View {
    var body: some View {
        Text("DataFrame Viewer Content")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.orange.opacity(0.1))
    }
}
*/
