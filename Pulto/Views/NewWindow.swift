import SwiftUI
import RealityKit
import Charts

struct NewWindow: View {
    let id: Int
    @StateObject private var windowTypeManager = WindowTypeManager.shared
    @Environment(\.openWindow) private var openWindow   // visionOS-safe window opener
    @State var showFileImporter = false  // For USDZ import
    @State var showPointCloudImporter = false  // For point cloud import

    var body: some View {
        if let window = windowTypeManager.getWindowSafely(for: id) {
            VStack(spacing: 0) {
                // Window header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(window.windowType.displayName) - Window #\(id) (\(window.windowType.rawValue))")
                            .font(.title2)
                            .fontWeight(.semibold)

                        if !window.state.tags.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "tag")
                                    .font(.caption)
                                Text(window.state.tags.joined(separator: ", "))
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Pos: (\(Int(window.position.x)), \(Int(window.position.y)), \(Int(window.position.z)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Template: \(window.state.exportTemplate.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.blue)

                        if !window.state.content.isEmpty {
                            Text("Has Content")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground).opacity(0.3))

                Divider()

                // Display the appropriate view based on window type with restored data
                Group {
                    switch window.windowType {
                    case .charts:
                        ChartGeneratorView(windowID: id)
                            .environmentObject(windowTypeManager)

                    case .spatial:
                        SpatialEditorView(windowID: id)

                    case .column:
                        if let df = window.state.dataFrameData {
                            DataTableContentView(windowID: id, initialDataFrame: df)
                        } else {
                            DataTableContentView(windowID: id)
                        }

                    case .volume:
                        VStack {
                            if !window.state.content.isEmpty {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Model Metrics:")
                                            .font(.headline)

                                        Text(window.state.content)
                                            .font(.system(.caption, design: .monospaced))
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(.tertiarySystemBackground))
                                            .cornerRadius(8)
                                    }
                                    .padding()
                                }
                            } else {
                                VStack(spacing: 20) {
                                    Image(systemName: "gauge")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.blue)

                                    Text("Model Metrics Viewer")
                                        .font(.title2)
                                        .fontWeight(.semibold)

                                    Text("Performance metrics and monitoring dashboard")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(40)
                            }
                        }

                    case .pointcloud:
                        VStack {
                            Spacer()

                            VStack(spacing: 20) {
                                Image(systemName: "dot.scope")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.linearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))

                                Text("Point Cloud Viewer")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)

                                if let pointCloud = window.state.pointCloudData {
                                    VStack(spacing: 12) {
                                        Text(pointCloud.title)
                                            .font(.title2)
                                            .foregroundStyle(.secondary)

                                        HStack(spacing: 40) {
                                            VStack {
                                                Text("\(pointCloud.totalPoints)")
                                                    .font(.title)
                                                    .fontWeight(.semibold)
                                                Text("Points")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            VStack {
                                                 Text(pointCloud.demoType)
                                                    .font(.title)
                                                    .fontWeight(.semibold)
                                                Text("Type")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(.top)
                                    }
                                } else if window.state.pointCloudBookmark != nil {
                                    Text("Imported Point Cloud")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                }

                                Text("This content is displayed in a volumetric window")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.top)

                                Button {
                                    // Open the volumetric window (visionOS-safe)
                                    openWindow(id: "volumetric-pointclouddemo", value: id)
                                } label: {
                                    Label("Open Point Cloud View", systemImage: "view.3d")
                                        .font(.headline)
                                        .padding()
                                        .background(.purple.opacity(0.2))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showPointCloudImporter = true
                                } label: {
                                    Label("Import Point Cloud", systemImage: "square.and.arrow.down")
                                        .font(.headline)
                                        .padding()
                                        .background(.green.opacity(0.2))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(40)

                            Spacer()
                        }
                        .fileImporter(isPresented: $showPointCloudImporter, allowedContentTypes: [
                            .commaSeparatedText,  // CSV
                            UTType(filenameExtension: "ply") ?? .data,  // PLY
                            UTType(filenameExtension: "pcd") ?? .data,  // PCD
                            UTType(filenameExtension: "xyz") ?? .data   // XYZ
                        ], allowsMultipleSelection: false) { result in
                            switch result {
                            case .success(let urls):
                                if let url = urls.first {
                                    let supportedExtensions = ["ply", "pcd", "xyz", "csv"]
                                    if supportedExtensions.contains(url.pathExtension.lowercased()) {
                                        Task {
                                            // Load the point cloud data directly (no bookmark needed, access granted here)
                                            let loadedPoints = PointCloudDemo.loadPointCloud(from: url)

                                            // Create PointCloudData
                                            var pointCloudData = PointCloudData(
                                                title: "Imported Point Cloud: \(url.lastPathComponent)",
                                                demoType: "imported",
                                                parameters: ["file": 1.0] // Placeholder
                                            )
                                            pointCloudData.points = loadedPoints
                                            pointCloudData.totalPoints = loadedPoints.count

                                            // Update the window with the data
                                            windowTypeManager.updateWindowPointCloud(id, pointCloud: pointCloudData)

                                            // Automatically open the volumetric view with the loaded data
                                            openWindow(id: "volumetric-pointclouddemo", value: id)

                                            print("Successfully imported point cloud: \(url.lastPathComponent)")
                                        }
                                    } else {
                                        print("Unsupported file type: \(url.pathExtension)")
                                    }
                                }
                            case .failure(let error):
                                print("Error importing point cloud: \(error.localizedDescription)")
                            }
                        }

                    case .model3d:
                        VStack {
                            Spacer()
                            // For the demo buttons:
                            Button {
                                // Generate a demo cube
                                let cubeModel = Model3DData.generateCube(size: 2.0)

                                // Convert to Python code and store as content
                                let pythonCode = cubeModel.toPythonCode()
                                windowTypeManager.updateWindowContent(id, content: pythonCode)

                                // Store a marker that this is 3D content
                                windowTypeManager.addWindowTag(id, tag: "3D-Cube")
                            } label: {
                                Label("Demo: Cube", systemImage: "cube")
                                    .font(.headline)
                                    .padding()
                                    .background(.green.opacity(0.2))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            VStack(spacing: 20) {
                                Image(systemName: "cube.transparent.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.linearGradient(
                                        colors: [.orange, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))

                                Text("3D Model Viewer")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)

                                if let model3D = window.state.model3DData {
                                    VStack(spacing: 12) {
                                        Text(model3D.title)
                                            .font(.title2)
                                            .foregroundStyle(.secondary)

                                        HStack(spacing: 40) {
                                            VStack {
                                                Text("\(model3D.vertices.count)")
                                                    .font(.title)
                                                    .fontWeight(.semibold)
                                                Text("Vertices")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            VStack {
                                                Text("\(model3D.faces.count)")
                                                    .font(.title)
                                                    .fontWeight(.semibold)
                                                Text("Faces")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            VStack {
                                                 Text(model3D.modelType)
                                                    .font(.title)
                                                    .fontWeight(.semibold)
                                                Text("Type")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(.top)
                                    }
                                } else if window.state.usdzBookmark != nil {
                                    Text("Imported USDZ Model")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                }

                                Text("This content is displayed in a volumetric window")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.top)

                                Button {
                                    // Open the volumetric window (visionOS-safe)
                                    openWindow(id: "volumetric-model3d", value: id)
                                } label: {
                                    Label("Open Volumetric View", systemImage: "view.3d")
                                        .font(.headline)
                                        .padding()
                                        .background(.orange.opacity(0.2))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showFileImporter = true
                                } label: {
                                    Label("Import USDZ Model", systemImage: "square.and.arrow.down")
                                        .font(.headline)
                                        .padding()
                                        .background(.blue.opacity(0.2))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(40)

                            Spacer()
                        }
                        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.usdz], allowsMultipleSelection: false) { result in
                            if let url = try? result.get().first {
                                Task {
                                    do {
                                        // Save the bookmark
                                        let bookmark = try url.bookmarkData()
                                        windowTypeManager.updateUSDZBookmark(for: id, bookmark: bookmark)

                                        // For now, create a placeholder Model3DData
                                        // In a real app, you would parse the USDZ file here
                                        let placeholderModel = Model3DData(
                                            title: url.lastPathComponent,
                                            modelType: "usdz",
                                            scale: 1.0
                                        )

                                        // Update the model data so the volumetric window can display it
                                        windowTypeManager.updateWindowModel3D(id, modelData: placeholderModel)

                                    } catch {
                                        print("Failed to import USDZ: \(error)")
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear {
                windowTypeManager.markWindowAsOpened(id)
            }
            .onDisappear {
                windowTypeManager.markWindowAsClosed(id)
            }
        } else {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)

                Text("Window #\(id) Unavailable")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("This window may have been closed or removed from the workspace.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Cleanup Closed Windows") {
                    windowTypeManager.cleanupClosedWindows()
                }
                .buttonStyle(.bordered)
            }
            .padding(40)
            .onAppear {
                windowTypeManager.markWindowAsClosed(id)
            }
        }
    }
}

#Preview {
    NewWindow(id: 1)
}