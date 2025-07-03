//
//  SpatialEditorView.swift
//  Pulto
//
//  Created by Joshua Herman on 6/19/25.
//  Copyright 2025 Apple. All rights reserved.
//

import SwiftUI
import Charts

// MARK: - Main View
// Enhanced Spatial Editor View with Point Cloud Integration
struct SpatialEditorView: View {
    // MARK: – Immutable inputs
    let windowID: Int?
    let initialPointCloud: PointCloudData?

    // MARK: – State
    @StateObject private var windowManager = WindowTypeManager.shared
    @State private var selectedDemo = 0
    @State private var rotationAngle = 0.0
    @State private var currentPointCloud: PointCloudData
    @State private var showControls = false

    @State private var headerPosition: CGSize = .zero
    @State private var parameterControlsPosition: CGSize = .zero
    @State private var demoSelectorPosition: CGSize = .zero
    @State private var visualizationPosition: CGSize = .zero
    @State private var statisticsPosition: CGSize = .zero
    @State private var exportControlsPosition: CGSize = .zero

    @State private var isDraggingHeader = false
    @State private var isDraggingParameters = false
    @State private var isDraggingDemoSelector = false
    @State private var isDraggingVisualization = false
    @State private var isDraggingStatistics = false
    @State private var isDraggingExportControls = false

    // Point-cloud parameters
    @State private var sphereRadius: Double = 10.0
    @State private var spherePoints: Double = 1000
    @State private var torusMajorRadius: Double = 10.0
    @State private var torusMinorRadius: Double = 3.0
    @State private var torusPoints: Double = 2000
    @State private var waveSize: Double = 20.0
    @State private var waveResolution: Double = 50
    @State private var galaxyArms: Double = 3
    @State private var galaxyPoints: Double = 5000
    @State private var cubeSize: Double = 10.0
    @State private var cubePointsPerFace: Double = 500

    private let demoNames = ["Sphere", "Torus", "Wave Surface", "Spiral Galaxy", "Noisy Cube"]

    // MARK: – Init
    init(windowID: Int? = nil, initialPointCloud: PointCloudData? = nil) {
        // 1.  Initialize stored constants FIRST
        self.windowID = windowID
        self.initialPointCloud = initialPointCloud

        // 2.  Produce a non-optional point cloud
        let cloud = initialPointCloud ?? PointCloudDemo.generateSpherePointCloudData()

        // 3.  Initialize the @State backing store
        _currentPointCloud = State(initialValue: cloud)
    }

    // MARK: – Body
    var body: some View {
        VStack(spacing: 12) {
            headerView

            if showControls {
                VStack(spacing: 12) {
                    parameterControlsView
                    demoSelectorView
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }

            pointCloudVisualizationView

            if showControls {
                VStack(spacing: 12) {
                    statisticsView
                    exportControlsView
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }

            Spacer()
        }
        .padding(16)
        .onKeyPress(.init("h"), phases: .down) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls.toggle()
            }
            return .handled
        }
        .onAppear {
            // If we weren’t given an explicit cloud, try loading from the window
            if initialPointCloud == nil {
                loadPointCloudFromWindow()
            }
            startRotationAnimation()
        }
        .onChange(of: selectedDemo) { _ in
            updatePointCloud()
        }
    }

    // MARK: – Sub-Views
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spatial Point Cloud Editor")
                    .font(.title2).bold()
                if let windowID {
                    Text("Window #\(windowID) • \(currentPointCloud.totalPoints) points")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showControls.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: showControls ? "eye.slash" : "eye")
                    Text(showControls ? "Hide Controls" : "Show Controls")
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    private var parameterControlsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Parameters").font(.subheadline).bold()
            switch selectedDemo {
            case 0: // Sphere
                VStack(alignment: .leading, spacing: 3) {
                    Text("Radius: \(sphereRadius, specifier: "%.1f")").font(.caption)
                    Slider(value: $sphereRadius, in: 5...20) { _ in updatePointCloud() }
                    Text("Points: \(Int(spherePoints))").font(.caption)
                    Slider(value: $spherePoints, in: 100...2000, step: 100) { _ in updatePointCloud() }
                }
            case 1: // Torus
                VStack(alignment: .leading, spacing: 3) {
                    Text("Major Radius: \(torusMajorRadius, specifier: "%.1f")").font(.caption)
                    Slider(value: $torusMajorRadius, in: 5...15) { _ in updatePointCloud() }
                    Text("Minor Radius: \(torusMinorRadius, specifier: "%.1f")").font(.caption)
                    Slider(value: $torusMinorRadius, in: 1...8) { _ in updatePointCloud() }
                    Text("Points: \(Int(torusPoints))").font(.caption)
                    Slider(value: $torusPoints, in: 500...5000, step: 100) { _ in updatePointCloud() }
                }
            case 2: // Wave Surface
                VStack(alignment: .leading, spacing: 3) {
                    Text("Size: \(waveSize, specifier: "%.1f")").font(.caption)
                    Slider(value: $waveSize, in: 10...30) { _ in updatePointCloud() }
                    Text("Resolution: \(Int(waveResolution))").font(.caption)
                    Slider(value: $waveResolution, in: 20...80, step: 10) { _ in updatePointCloud() }
                }
            case 3: // Spiral Galaxy
                VStack(alignment: .leading, spacing: 3) {
                    Text("Arms: \(Int(galaxyArms))").font(.caption)
                    Slider(value: $galaxyArms, in: 2...6, step: 1) { _ in updatePointCloud() }
                    Text("Points: \(Int(galaxyPoints))").font(.caption)
                    Slider(value: $galaxyPoints, in: 1000...10000, step: 500) { _ in updatePointCloud() }
                }
            case 4: // Noisy Cube
                VStack(alignment: .leading, spacing: 3) {
                    Text("Size: \(cubeSize, specifier: "%.1f")").font(.caption)
                    Slider(value: $cubeSize, in: 5...20) { _ in updatePointCloud() }
                    Text("Points per Face: \(Int(cubePointsPerFace))").font(.caption)
                    Slider(value: $cubePointsPerFace, in: 100...1000, step: 50) { _ in updatePointCloud() }
                }
            default:
                EmptyView()
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var demoSelectorView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Point Cloud Type").font(.subheadline).bold()
            Picker("Select Data", selection: $selectedDemo) {
                ForEach(demoNames.indices, id: \.self) { index in
                    Text(demoNames[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    private var pointCloudVisualizationView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 300)

            GeometryReader { _ in
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let scale = min(size.width, size.height) / 40
                    let θ = rotationAngle * .pi / 180

                    for p in currentPointCloud.points {
                        // Y-axis rotation
                        let xR = p.x * cos(θ) - p.z * sin(θ)
                        let zR = p.x * sin(θ) + p.z * cos(θ)
                        // 2-D projection
                        let plotX = center.x + xR * scale
                        let plotY = center.y - p.y * scale
                        // Size + color
                        let sz = 2.0 + (zR + 20) / 20
                        let intensity = p.intensity ?? ((p.z + 10) / 20)
                        let col = Color(hue: 0.6 - intensity * 0.4,
                                        saturation: 0.8,
                                        brightness: 0.9)
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: plotX - sz/2,
                                                   y: plotY - sz/2,
                                                   width: sz,
                                                   height: sz)),
                            with: .color(col.opacity(0.8))
                        )
                    }
                }
            }
            .frame(height: 300)

            if !showControls {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 2) {
                            Text("Controls Hidden")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Press 'H' or tap eye icon")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                        .opacity(0.7)
                    }
                }
                .padding(12)
            }
        }
    }

    private var statisticsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Statistics").font(.subheadline).bold()
            HStack {
                Label("\(currentPointCloud.totalPoints) points", systemImage: "circle.grid.3x3.fill")
                Spacer()
                Label(String(format: "%.1f°", rotationAngle.truncatingRemainder(dividingBy: 360)), systemImage: "rotate.3d")
            }
            .font(.caption2).foregroundColor(.secondary)

            if !currentPointCloud.parameters.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Parameters:").font(.caption2).bold()
                    ForEach(currentPointCloud.parameters.keys.sorted(), id: \.self) { key in
                        Text("\(key): \(currentPointCloud.parameters[key] ?? 0, specifier: "%.1f")")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var exportControlsView: some View {
        VStack(spacing: 8) {
            Text("Export Options").font(.subheadline).bold()
            HStack(spacing: 8) {
                Button(action: saveToWindow) {
                    Label("Save to Window", systemImage: "square.and.arrow.down")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.blue.opacity(0.1)).cornerRadius(6)
                }
                Button(action: exportToJupyter) {
                    Label("Export to Jupyter", systemImage: "doc.text")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.green.opacity(0.1)).cornerRadius(6)
                }
            }
            Button(action: copyPythonCode) {
                Label("Copy Python Code", systemImage: "doc.on.doc")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.orange.opacity(0.1)).cornerRadius(6)
            }
        }
    }

    // MARK: – Helpers
    private func loadPointCloudFromWindow() {
        guard let windowID,
              let saved = windowManager.getWindowPointCloud(for: windowID) else { return }
        currentPointCloud = saved
        if let idx = demoNames.firstIndex(where: { saved.demoType.lowercased().contains($0.lowercased()) }) {
            selectedDemo = idx
        }
    }

    private func updatePointCloud() {
        switch selectedDemo {
        case 0:
            currentPointCloud = PointCloudDemo.generateSpherePointCloudData(
                radius: sphereRadius,
                points: Int(spherePoints))
        case 1:
            currentPointCloud = PointCloudDemo.generateTorusPointCloudData(
                majorRadius: torusMajorRadius,
                minorRadius: torusMinorRadius,
                points: Int(torusPoints))
        case 2:
            currentPointCloud = PointCloudDemo.generateWaveSurfaceData(
                size: waveSize,
                resolution: Int(waveResolution))
        case 3:
            currentPointCloud = PointCloudDemo.generateSpiralGalaxyData(
                arms: Int(galaxyArms),
                points: Int(galaxyPoints))
        case 4:
            currentPointCloud = PointCloudDemo.generateNoisyCubeData(
                size: cubeSize,
                pointsPerFace: Int(cubePointsPerFace))
        default: break
        }
    }

    private func startRotationAnimation() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }

    private func saveToWindow() {
        guard let windowID else { return }
        windowManager.updateWindowPointCloud(windowID, pointCloud: currentPointCloud)
        windowManager.updateWindowContent(windowID, content: currentPointCloud.toPythonCode())
        print(" Point cloud saved to window #\(windowID)")
    }

    private func exportToJupyter() {
        let code = currentPointCloud.toPythonCode()
        let name = "pointcloud_\(currentPointCloud.demoType)_\(Date().timeIntervalSince1970).py"
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = docs.appendingPathComponent(name)
        do {
            try code.write(to: url, atomically: true, encoding: .utf8)
            print(" Exported to: \(url.path)")
        } catch {
            print(" Error: \(error)")
        }
        saveToWindow()
    }

    private func copyPythonCode() {
        let code = currentPointCloud.toPythonCode()
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        print(" Python code copied to clipboard")
        #endif
    }
}

// MARK: – Preview
#Preview {
    SpatialEditorView()
        .frame(width: 800, height: 600)
}
