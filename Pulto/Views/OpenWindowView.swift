import SwiftUI
import Foundation
import Charts
import RealityKit

// ... existing code ...

struct RegularWindowContent: View {
    let window: NewWindowID
    
    var body: some View {
        VStack(spacing: 0) {
            // Regular window header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(window.windowType.displayName) - Window #\(window.id)")
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
                    
                    // Immersive space entry button (temporarily commented out)
                    // ImmersiveSpaceEntryButton()
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground).opacity(0.3))

            Divider()

            // Window content (unchanged from original)
            Group {
                switch window.windowType {
                case .model3d:
                    VStack {
                        if let model3D = window.state.model3DData {
                            VStack(spacing: 20) {
                                Image(systemName: "cube-transparent")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.orange)

                                Text("3D Model: \(model3D.title)")
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Text("\(model3D.vertices.count) vertices, \(model3D.faces.count) faces")
                                    .font(.body)
                                    .foregroundStyle(.secondary)

                                if !window.state.content.isEmpty {
                                    ScrollView {
                                        Text(window.state.content)
                                            .font(.system(.caption, design: .monospaced))
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(.tertiarySystemBackground))
                                            .cornerRadius(8)
                                    }
                                    .frame(maxHeight: 150)
                                }
                            }
                            .padding(40)
                        } else {
                            VStack(spacing: 20) {
                                Image(systemName: "cube-transparent")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.orange)

                                Text("3D Model Viewer")
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Text("3D mesh and model visualization")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(40)
                        }
                    }

                case .charts:
                    VStack {
                        if !window.state.content.isEmpty {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Restored Content:")
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
                            .frame(maxHeight: 200)

                            Divider()
                        }
                    }

                case .spatial:
                    if let pointCloud = window.state.pointCloudData {
                        SpatialEditorView(windowID: window.id, initialPointCloud: pointCloud)
                    } else {
                        SpatialEditorView(windowID: window.id)
                    }

                case .column:
                    if let df = window.state.dataFrameData {
                        DataTableContentView(windowID: window.id, initialDataFrame: df)
                    } else {
                        DataTableContentView(windowID: window.id)   // falls back to saved window or sample
                    }
                case .pointcloud:  
                    VStack {
                        if let pointCloud = window.state.pointCloudData {
                            SpatialEditorView(windowID: window.id, initialPointCloud: pointCloud)
                        } else {
                            VStack(spacing: 20) {
                                Image(systemName: "dot.scope")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.blue)

                                Text("Point Cloud Viewer")
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Text("Import and visualize point cloud data")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(40)
                        }
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
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}