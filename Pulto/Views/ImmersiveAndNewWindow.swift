//
//  ImmersiveSpaceView.swift
//  Pulto
//
//  Created by Assistant on 12/29/2024.
//

import SwiftUI
import RealityKit

struct ImmersiveSpaceView: View {
    @EnvironmentObject var windowManager: WindowTypeManager
    @EnvironmentObject var spatialManager: SpatialWindowManager
    
    var body: some View {
        RealityView { content in
            setupImmersiveSpace(content: content)
        } update: { content in
            updateImmersiveSpace(content: content)
        }
        .gesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    handleDragGesture(value)
                }
        )
        .onAppear {
            print("🌐 ImmersiveSpace appeared")
        }
        .onDisappear {
            print("🌐 ImmersiveSpace disappeared")
        }
    }
    
    private func setupImmersiveSpace(content: RealityViewContent) {
        // Add lighting
        let directionalLight = DirectionalLight()
        directionalLight.light.intensity = 1000
        directionalLight.transform.rotation = simd_quatf(
            angle: -Float.pi / 4,
            axis: [1, 0, 0]
        )
        content.add(directionalLight)
        
        // Add ambient light
        let ambientLight = AmbientLight()
        ambientLight.light.intensity = 300
        content.add(ambientLight)
        
        // Position windows in 3D space
        positionWindowsIn3DSpace(content: content)
    }
    
    private func updateImmersiveSpace(content: RealityViewContent) {
        // Update window positions and states
        let openWindows = windowManager.getAllWindows(onlyOpen: true)
        
        for window in openWindows {
            let immersiveState = spatialManager.getImmersiveState(for: window.id)
            
            if immersiveState.isVisible {
                // Update window position and appearance in 3D space
                updateWindowInSpace(window: window, state: immersiveState, content: content)
            }
        }
    }
    
    private func positionWindowsIn3DSpace(content: RealityViewContent) {
        let openWindows = windowManager.getAllWindows(onlyOpen: true)
        
        for (index, window) in openWindows.enumerated() {
            let position = calculateWindowPosition(for: index, window: window)
            
            // Create a simple representation of the window
            let windowEntity = createWindowEntity(for: window)
            windowEntity.transform.translation = position
            
            content.add(windowEntity)
            
            // Update spatial manager state
            let transform = ImmersiveWindowState.Transform3D(
                translation: position
            )
            var state = spatialManager.getImmersiveState(for: window.id)
            state.transform = transform
            spatialManager.updateImmersiveState(for: window.id, state: state)
        }
    }
    
    private func calculateWindowPosition(for index: Int, window: NewWindowID) -> SIMD3<Float> {
        // Arrange windows in a circular pattern
        let radius: Float = 3.0
        let angleStep = 2.0 * Float.pi / Float(max(1, windowManager.getAllWindows(onlyOpen: true).count))
        let angle = angleStep * Float(index)
        
        let x = radius * cos(angle)
        let z = radius * sin(angle)
        let y = Float(window.position.y) * 0.01 // Convert to reasonable scale
        
        return SIMD3<Float>(x, y, z)
    }
    
    private func createWindowEntity(for window: NewWindowID) -> ModelEntity {
        // Create a simple plane to represent the window
        let mesh = MeshResource.generatePlane(width: 0.4, depth: 0.3)
        
        var material = SimpleMaterial()
        material.color = SimpleMaterial.Color.white
        material.metallic = 0.1
        material.roughness = 0.8
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "Window_\(window.id)"
        
        return entity
    }
    
    private func updateWindowInSpace(window: NewWindowID, state: ImmersiveWindowState, content: RealityViewContent) {
        // Find the window entity and update its transform
        if let windowEntity = content.entities.first(where: { $0.name == "Window_\(window.id)" }) {
            windowEntity.transform.translation = state.transform.translation
            windowEntity.transform.rotation = state.transform.simdRotation
            windowEntity.transform.scale = state.transform.scale
            windowEntity.isEnabled = state.isVisible
        }
    }
    
    private func handleDragGesture(_ value: EntityTargetValue<DragGesture.Value>) {
        // Handle window dragging in 3D space
        if let entity = value.entity,
           let windowIDString = entity.name?.components(separatedBy: "_").last,
           let windowID = Int(windowIDString) {
            
            let translation = value.convert(value.translation3D, from: .local, to: .scene)
            entity.transform.translation += translation
            
            // Update the spatial manager state
            let newTransform = ImmersiveWindowState.Transform3D(
                translation: entity.transform.translation
            )
            var state = spatialManager.getImmersiveState(for: windowID)
            state.transform = newTransform
            state.lastInteractionTime = Date()
            spatialManager.updateImmersiveState(for: windowID, state: state)
        }
    }
}

#Preview {
    ImmersiveSpaceView()
        .environmentObject(WindowTypeManager.shared)
        .environmentObject(SpatialWindowManager.shared)
}//
//  NewWindow.swift
//  Pulto
//
//  Created by Assistant on 12/29/2024.
//

import SwiftUI

struct NewWindow: View {
    let id: Int
    @EnvironmentObject var windowManager: WindowTypeManager
    @EnvironmentObject var spatialManager: SpatialWindowManager
    
    var body: some View {
        Group {
            if let window = windowManager.getWindowSafely(for: id) {
                WindowContentView(window: window)
            } else {
                // Fallback view when window is not found
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Window Not Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Window #\(id) could not be loaded.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Close Window") {
                        // Close this window since it's invalid
                        windowManager.markWindowAsClosed(id)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            windowManager.markWindowAsOpened(id)
            print("🪟 Window #\(id) opened")
        }
        .onDisappear {
            windowManager.markWindowAsClosed(id)
            print("🪟 Window #\(id) closed")
        }
    }
}

struct WindowContentView: View {
    let window: NewWindowID
    @EnvironmentObject var windowManager: WindowTypeManager
    @EnvironmentObject var spatialManager: SpatialWindowManager
    
    var body: some View {
        Group {
            switch window.windowType {
            case .charts:
                if let chartData = window.state.chartData {
                    ChartsView(windowID: window.id, chartData: chartData)
                } else {
                    ChartsView(windowID: window.id)
                }
                
            case .spatial:
                if let pointCloudData = window.state.pointCloudData {
                    SpatialEditorView(windowID: window.id, initialPointCloud: pointCloudData)
                } else {
                    SpatialEditorView(windowID: window.id)
                }
                
            case .column:
                if let dataFrameData = window.state.dataFrameData {
                    DataTableContentView(windowID: window.id, dataFrame: dataFrameData)
                } else {
                    DataTableContentView(windowID: window.id)
                }
                
            case .volume:
                if let volumeData = window.state.volumeData {
                    VolumeMetricsView(windowID: window.id, volumeData: volumeData)
                } else {
                    VolumeMetricsView(windowID: window.id)
                }
                
            case .pointcloud:
                if let pointCloudData = window.state.pointCloudData {
                    PointCloudView(windowID: window.id, pointCloudData: pointCloudData)
                } else {
                    PointCloudView(windowID: window.id)
                }
                
            case .model3d:
                if let model3DData = window.state.model3DData {
                    ModelViewerView(windowID: window.id, model3DData: model3DData)
                } else {
                    ModelViewerView(windowID: window.id)
                }
            }
        }
        .navigationTitle(window.windowType.displayName)
        .navigationSubtitle("Window #\(window.id)")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Save to Notebook") {
                        // Save window content to notebook
                        saveWindowToNotebook()
                    }
                    
                    Button("Export Python Code") {
                        // Export window content as Python code
                        exportPythonCode()
                    }
                    
                    Divider()
                    
                    Button("Close Window", role: .destructive) {
                        windowManager.markWindowAsClosed(window.id)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    private func saveWindowToNotebook() {
        // Implementation for saving to notebook
        print("📝 Saving window #\(window.id) to notebook")
    }
    
    private func exportPythonCode() {
        // Implementation for exporting Python code
        print("🐍 Exporting Python code for window #\(window.id)")
        
        let code = generatePythonCode()
        
        // Copy to clipboard (simplified)
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        print("Code copied to clipboard")
        #endif
    }
    
    private func generatePythonCode() -> String {
        switch window.windowType {
        case .charts:
            return window.state.chartData?.toEnhancedPythonCode() ?? "# No chart data available"
        case .spatial, .pointcloud:
            return window.state.pointCloudData?.toPythonCode() ?? "# No point cloud data available"
        case .column:
            return window.state.dataFrameData?.toEnhancedPandasCode() ?? "# No DataFrame data available"
        case .volume:
            return window.state.volumeData?.toPythonCode() ?? "# No volume data available"
        case .model3d:
            return window.state.model3DData?.toPythonCode() ?? "# No 3D model data available"
        }
    }
}

// MARK: - Placeholder Views for Missing Components

struct VolumeMetricsView: View {
    let windowID: Int
    let volumeData: VolumeData?
    
    init(windowID: Int, volumeData: VolumeData? = nil) {
        self.windowID = windowID
        self.volumeData = volumeData
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gauge")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Volume Metrics")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let volumeData = volumeData {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title: \(volumeData.title)")
                    Text("Category: \(volumeData.category)")
                    Text("Metrics: \(volumeData.metrics.count)")
                }
                .font(.body)
                .foregroundColor(.secondary)
            } else {
                Text("No volume data available")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct PointCloudView: View {
    let windowID: Int
    let pointCloudData: PointCloudData?
    
    init(windowID: Int, pointCloudData: PointCloudData? = nil) {
        self.windowID = windowID
        self.pointCloudData = pointCloudData
    }
    
    var body: some View {
        Group {
            if let pointCloudData = pointCloudData {
                SpatialEditorView(windowID: windowID, initialPointCloud: pointCloudData)
            } else {
                SpatialEditorView(windowID: windowID)
            }
        }
    }
}

struct ModelViewerView: View {
    let windowID: Int
    let model3DData: Model3DData?
    
    init(windowID: Int, model3DData: Model3DData? = nil) {
        self.windowID = windowID
        self.model3DData = model3DData
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("3D Model Viewer")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let model3DData = model3DData {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title: \(model3DData.title)")
                    Text("Type: \(model3DData.modelType)")
                    Text("Vertices: \(model3DData.vertices.count)")
                    Text("Faces: \(model3DData.faces.count)")
                }
                .font(.body)
                .foregroundColor(.secondary)
            } else {
                Text("No 3D model data available")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    NewWindow(id: 1)
        .environmentObject(WindowTypeManager.shared)
        .environmentObject(SpatialWindowManager.shared)
}