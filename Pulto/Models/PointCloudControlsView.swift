// PointCloudControlsView.swift
// Point Cloud UI Controls and Parameter Adjustment

import SwiftUI

// MARK: - Point Cloud Controls View
struct PointCloudControlsView: View {
    @Binding var pointCloudData: PointCloudData?
    let windowID: Int?
    let onPointCloudGenerated: (PointCloudData) -> Void
    
    @State private var selectedDemoType = "sphere"
    @State private var showingImporter = false
    @State private var showingExportSheet = false
    
    // Sphere parameters
    @State private var sphereRadius: Double = 10.0
    @State private var spherePoints: Double = 1000
    
    // Torus parameters
    @State private var torusMajorRadius: Double = 10.0
    @State private var torusMinorRadius: Double = 3.0
    @State private var torusPoints: Double = 2000
    
    // Wave parameters
    @State private var waveSize: Double = 20.0
    @State private var waveResolution: Double = 50
    
    // Galaxy parameters
    @State private var galaxyArms: Double = 3
    @State private var galaxyPoints: Double = 5000
    
    // Cube parameters
    @State private var cubeSize: Double = 10.0
    @State private var cubePointsPerFace: Double = 500

    var body: some View {
        VStack(spacing: 16) {
            headerSection
            demoTypeSelector
            parameterControls
            actionButtons
            pointCloudInfo
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showingExportSheet) {
            PointCloudExportSheet(pointCloudData: pointCloudData)
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        HStack {
            Label("Point Cloud Generator", systemImage: "dot.scope")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            if pointCloudData != nil {
                Button(action: { showingExportSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.blue)
                }
            }
        }
    }
    
    private var demoTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Demo Type")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Picker("Demo Type", selection: $selectedDemoType) {
                ForEach(PointCloudGenerator.getAllDemoTypes(), id: \.self) { type in
                    Text(type.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    @ViewBuilder
    private var parameterControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parameters")
                .font(.subheadline)
                .fontWeight(.medium)
            
            switch selectedDemoType {
            case "sphere":
                sphereParameterControls
            case "torus":
                torusParameterControls
            case "wave":
                waveParameterControls
            case "galaxy":
                galaxyParameterControls
            case "cube":
                cubeParameterControls
            default:
                EmptyView()
            }
        }
    }
    
    private var sphereParameterControls: some View {
        VStack(spacing: 8) {
            ParameterSlider(
                title: "Radius",
                value: $sphereRadius,
                range: 1...50,
                format: "%.1f"
            )
            
            ParameterSlider(
                title: "Points",
                value: $spherePoints,
                range: 100...10000,
                format: "%.0f"
            )
        }
    }
    
    private var torusParameterControls: some View {
        VStack(spacing: 8) {
            ParameterSlider(
                title: "Major Radius",
                value: $torusMajorRadius,
                range: 5...30,
                format: "%.1f"
            )
            
            ParameterSlider(
                title: "Minor Radius",
                value: $torusMinorRadius,
                range: 1...10,
                format: "%.1f"
            )
            
            ParameterSlider(
                title: "Points",
                value: $torusPoints,
                range: 500...15000,
                format: "%.0f"
            )
        }
    }
    
    private var waveParameterControls: some View {
        VStack(spacing: 8) {
            ParameterSlider(
                title: "Size",
                value: $waveSize,
                range: 10...100,
                format: "%.1f"
            )
            
            ParameterSlider(
                title: "Resolution",
                value: $waveResolution,
                range: 20...200,
                format: "%.0f"
            )
        }
    }
    
    private var galaxyParameterControls: some View {
        VStack(spacing: 8) {
            ParameterSlider(
                title: "Arms",
                value: $galaxyArms,
                range: 2...8,
                format: "%.0f"
            )
            
            ParameterSlider(
                title: "Points",
                value: $galaxyPoints,
                range: 1000...20000,
                format: "%.0f"
            )
        }
    }
    
    private var cubeParameterControls: some View {
        VStack(spacing: 8) {
            ParameterSlider(
                title: "Size",
                value: $cubeSize,
                range: 5...50,
                format: "%.1f"
            )
            
            ParameterSlider(
                title: "Points per Face",
                value: $cubePointsPerFace,
                range: 100...2000,
                format: "%.0f"
            )
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button(action: generatePointCloud) {
                Label("Generate Point Cloud", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            HStack(spacing: 8) {
                Button(action: { showingImporter = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: clearPointCloud) {
                    Label("Clear", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(pointCloudData == nil)
            }
        }
    }
    
    @ViewBuilder
    private var pointCloudInfo: some View {
        if let data = pointCloudData {
            VStack(alignment: .leading, spacing: 6) {
                Divider()
                
                Text("Current Point Cloud")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text(data.title)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Type: \(data.demoType)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("\(data.totalPoints) points")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("3D Coordinates")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
    
    // MARK: - Actions
    
    private func generatePointCloud() {
        let parameters: [String: Any]
        
        switch selectedDemoType {
        case "sphere":
            parameters = [
                "radius": sphereRadius,
                "points": Int(spherePoints)
            ]
        case "torus":
            parameters = [
                "majorRadius": torusMajorRadius,
                "minorRadius": torusMinorRadius,
                "points": Int(torusPoints)
            ]
        case "wave":
            parameters = [
                "size": waveSize,
                "resolution": Int(waveResolution)
            ]
        case "galaxy":
            parameters = [
                "arms": Int(galaxyArms),
                "points": Int(galaxyPoints)
            ]
        case "cube":
            parameters = [
                "size": cubeSize,
                "pointsPerFace": Int(cubePointsPerFace)
            ]
        default:
            parameters = [:]
        }
        
        if let generatedData = PointCloudGenerator.generatePointCloudData(type: selectedDemoType, parameters: parameters) {
            pointCloudData = generatedData
            onPointCloudGenerated(generatedData)
            
            // Update window manager if windowID is provided
            if let windowID = windowID {
                WindowTypeManager.shared.updateWindowPointCloudData(windowID, pointCloudData: generatedData)
                WindowTypeManager.shared.updateWindowContent(windowID, content: generatedData.toPythonCode())
                WindowTypeManager.shared.addWindowTag(windowID, tag: "PointCloud-\(selectedDemoType)")
            }
        }
    }
    
    private func clearPointCloud() {
        pointCloudData = nil
        
        if let windowID = windowID {
            WindowTypeManager.shared.updateWindowPointCloudData(windowID, pointCloudData: nil)
            WindowTypeManager.shared.updateWindowContent(windowID, content: "")
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // TODO: Implement point cloud file parsing (PLY, PCD, XYZ, etc.)
            print("Importing point cloud from: \(url.path)")
            
        case .failure(let error):
            print("Failed to import file: \(error)")
        }
    }
}

// MARK: - Parameter Slider Component
struct ParameterSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text(String(format: format, value))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            
            Slider(value: $value, in: range)
                .tint(.blue)
        }
    }
}

// MARK: - Point Cloud Export Sheet
struct PointCloudExportSheet: View {
    let pointCloudData: PointCloudData?
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let data = pointCloudData {
                    VStack(spacing: 16) {
                        Image(systemName: "dot.scope")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        
                        Text(data.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 40) {
                            VStack {
                                Text("\(data.totalPoints)")
                                    .font(.title)
                                    .fontWeight(.semibold)
                                Text("Points")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            VStack {
                                Text(data.demoType)
                                    .font(.title)
                                    .fontWeight(.semibold)
                                Text("Type")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top)
                    }
                    
                    Divider()
                    
                    VStack(spacing: 12) {
                        exportButton(
                            title: "Export Python Code",
                            icon: "doc.text",
                            action: { exportPythonCode(data) }
                        )
                        
                        exportButton(
                            title: "Save to Files",
                            icon: "folder",
                            action: { saveToFiles(data) }
                        )
                        
                        exportButton(
                            title: "Copy to Clipboard",
                            icon: "doc.on.doc",
                            action: { copyToClipboard(data) }
                        )
                    }
                } else {
                    Text("No point cloud data available")
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export Point Cloud")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
    
    private func exportPythonCode(_ data: PointCloudData) {
        let pythonCode = data.toPythonCode()
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pythonCode, forType: .string)
        #else
        UIPasteboard.general.string = pythonCode
        #endif
    }
    
    private func saveToFiles(_ data: PointCloudData) {
        let filename = "\(data.title.replacingOccurrences(of: " ", with: "_")).py"
        _ = PointCloudGenerator.savePointCloudToFile(data, filename: filename)
    }
    
    private func copyToClipboard(_ data: PointCloudData) {
        let jsonData = try? JSONEncoder().encode(data)
        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(jsonString, forType: .string)
        #else
        UIPasteboard.general.string = jsonString
        #endif
    }
}