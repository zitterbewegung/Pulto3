import SwiftUI
import RealityKit
import Charts

/// A data structure to represent a single point in our 3D spatial data.
/// It conforms to Identifiable so we can easily use it in SwiftUI lists and charts.
struct SpatialDataPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let z: Double
    let value: Double // Represents some measurement at this point (e.g., temperature, density)
}

/// A view that presents the main spatial data visualization window.
struct VisualizationWindowView: View {
    
    // State to manage the presentation of the window.
    @Environment(\.dismiss) var dismiss
    
    // Sample data for the point cloud visualization.
    // In a real application, this would be loaded from an external source.
    @State private var pointCloudData: [SpatialDataPoint] = [
        .init(x: 0.1, y: 0.2, z: 0.3, value: 15.5),
        .init(x: 0.4, y: 0.5, z: 0.1, value: 20.2),
        .init(x: 0.7, y: 0.8, z: 0.6, value: 12.8),
        .init(x: 0.2, y: 0.3, z: 0.8, value: 25.0),
        .init(x: 0.5, y: 0.6, z: 0.4, value: 18.7),
        .init(x: 0.8, y: 0.1, z: 0.9, value: 30.1),
        .init(x: 0.3, y: 0.7, z: 0.2, value: 22.5),
        .init(x: 0.6, y: 0.9, z: 0.5, value: 10.3),
        .init(x: 0.9, y: 0.4, z: 0.7, value: 28.9),
    ]
    
    // State to hold the currently selected data point for inspection.
    @State private var selectedDataPoint: SpatialDataPoint?
    
    var body: some View {
        VStack(spacing: 20) {
            // MARK: - Header and Dismiss Button
            HStack {
                Text("Volumetric Data Inspector")
                    .font(.largeTitle)
                Spacer()
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .padding(12)
                        .background(.regularMaterial, in: Circle())
                }
            }
            .padding(.horizontal)
            
            // MARK: - Main Content Layout
            HStack(spacing: 20) {
                // MARK: - 3D Volumetric View Placeholder
                VStack {
                    Text("Volumetric Space")
                        .font(.headline)
                    
                    // This RealityView serves as a placeholder for your 3D content.
                    // You would replace the simple cube with your actual 3D model or point cloud rendering.
                    RealityView { content in
                        let model = ModelEntity(
                            mesh: .generateBox(size: 0.3, cornerRadius: 0.03),
                            materials: [SimpleMaterial(color: .cyan, isMetallic: true)]
                        )
                        model.position = [0, 0, -0.5]
                        content.add(model)
                    }
                    .frame(width: 400, height: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.secondary, lineWidth: 1)
                    )
                }
                
                // MARK: - Data Inspection Panel
                VStack(alignment: .leading, spacing: 15) {
                    Text("Associated Data")
                        .font(.headline)
                    
                    // MARK: - Data Chart
                    // This chart visualizes the 'value' of each data point.
                    // Tapping on a bar will select that data point for inspection.
                    Chart(pointCloudData) { point in
                        BarMark(
                            x: .value("Position (X)", point.x),
                            y: .value("Measurement", point.value)
                        )
                        .foregroundStyle(by: .value("Position (Y)", point.y))
                        .annotation(position: .top) {
                             if selectedDataPoint?.id == point.id {
                                 Text(String(format: "%.1f", point.value))
                                     .font(.caption)
                                     .foregroundColor(.secondary)
                             }
                         }
                    }
                    .chartXAxisLabel("X Coordinate")
                    .chartYAxisLabel("Data Value")
                    .frame(height: 200)
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .onTapGesture { location in
                                    guard let (x, _) = proxy.value(at: location, as: (Double, Double).self) else {
                                        return
                                    }
                                    // Find the closest point in the data to where the user tapped.
                                    selectedDataPoint = pointCloudData.min(by: { abs($0.x - x) < abs($1.x - x) })
                                }
                        }
                    }

                    
                    // MARK: - Inspector Details
                    if let selectedDataPoint {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Inspector")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Divider()
                            HStack {
                                Text("Coordinates (X, Y, Z):")
                                    .fontWeight(.bold)
                                Spacer()
                                Text(String(format: "%.2f, %.2f, %.2f", selectedDataPoint.x, selectedDataPoint.y, selectedDataPoint.z))
                            }
                            HStack {
                                Text("Value:")
                                    .fontWeight(.bold)
                                Spacer()
                                Text(String(format: "%.2f", selectedDataPoint.value))
                                    .foregroundStyle(.cyan)
                            }
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        
                    } else {
                        ContentUnavailableView("No Point Selected", systemImage: "chart.bar.xaxis.ascending", description: Text("Tap a bar in the chart to inspect a data point."))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .padding()
        .frame(width: 900, height: 550)
        .glassBackgroundEffect()
    }
}
/*
/// The main App definition for the visionOS application.
@main
struct SpatialDataApp: App {
    
    // Environment value to control windows.
    @Environment(\.openWindow) var openWindow

    var body: some Scene {
        // The primary window that opens when the app launches.
        WindowGroup {
            VStack(spacing: 20) {
                Text("Spatial Data Visualization System")
                    .font(.largeTitle)
                
                // This button now correctly opens the secondary visualization window.
                Button("Show Visualization") {
                    openWindow(id: "visualization-window")
                }
            }
            .padding()
        }

        // Defines the secondary window for data visualization.
        // This window is dismissible by default system controls and our custom button.
        WindowGroup(id: "visualization-window") {
            VisualizationWindowView()
        }
    }
}
*/
// MARK: - Xcode Preview
// This macro allows you to preview the VisualizationWindowView directly in Xcode.
#Preview(windowStyle: .automatic) {
    VisualizationWindowView()
}
