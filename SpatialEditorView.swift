// Enhanced Spatial Editor View with Point Cloud Integration
struct SpatialEditorView: View {
    let windowID: Int?
    let initialPointCloud: PointCloudData?
    // your @State property
    @StateObject private var windowManager = WindowTypeManager.shared
    @State private var selectedDemo = 0
    @State private var rotationAngle = 0.0
    @State private var currentPointCloud: PointCloudData

    // Point cloud parameters
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

    let demoNames = ["Sphere", "Torus", "Wave Surface", "Spiral Galaxy", "Noisy Cube"]

    init(windowID: Int? = nil) {
        self.windowID = windowID
        // unwrap or supply default
        let cloud = initialPointCloud
            ?? PointCloudDemo.generateSpherePointCloudData()
        // initialize the @State backing store
        self._currentPointCloud = State(initialValue: cloud)
        // Use provided initialPointCloud, or default to a sphere demo
        _currentPointCloud = State(
            initialValue: initialPointCloud
                ?? PointCloudDemo.generateSpherePointCloudData()
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            headerView
            parameterControlsView
            demoSelectorView
            pointCloudVisualizationView
            statisticsView
            exportControlsView
            Spacer()
        }
        .padding()
        .onAppear {
            loadPointCloudFromWindow()
            startRotationAnimation()
        }
        .onChange(of: selectedDemo) { _ in
            updatePointCloud()
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Spatial Point Cloud Editor")
                .font(.title2)
                .bold()
            if let windowID = windowID {
                Text("Window #\(windowID) • \(currentPointCloud.totalPoints) points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var parameterControlsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Parameters")
                .font(.headline)

            switch selectedDemo {
            case 0: // Sphere
                VStack(alignment: .leading, spacing: 4) {
                    Text("Radius: \(sphereRadius, specifier: "%.1f")")
                    Slider(value: $sphereRadius, in: 5...20) { _ in updatePointCloud() }
                    Text("Points: \(Int(spherePoints))")
                    Slider(value: $spherePoints, in: 100...2000, step: 100) { _ in updatePointCloud() }
                }

            case 1: // Torus
                VStack(alignment: .leading, spacing: 4) {
                    Text("Major Radius: \(torusMajorRadius, specifier: "%.1f")")
                    Slider(value: $torusMajorRadius, in: 5...15) { _ in updatePointCloud() }
                    Text("Minor Radius: \(torusMinorRadius, specifier: "%.1f")")
                    Slider(value: $torusMinorRadius, in: 1...8) { _ in updatePointCloud() }
                    Text("Points: \(Int(torusPoints))")
                    Slider(value: $torusPoints, in: 500...5000, step: 100) { _ in updatePointCloud() }
                }

            case 2: // Wave Surface
                VStack(alignment: .leading, spacing: 4) {
                    Text("Size: \(waveSize, specifier: "%.1f")")
                    Slider(value: $waveSize, in: 10...30) { _ in updatePointCloud() }
                    Text("Resolution: \(Int(waveResolution))")
                    Slider(value: $waveResolution, in: 20...80, step: 10) { _ in updatePointCloud() }
                }

            case 3: // Spiral Galaxy
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arms: \(Int(galaxyArms))")
                    Slider(value: $galaxyArms, in: 2...6, step: 1) { _ in updatePointCloud() }
                    Text("Points: \(Int(galaxyPoints))")
                    Slider(value: $galaxyPoints, in: 1000...10000, step: 500) { _ in updatePointCloud() }
                }

            case 4: // Noisy Cube
                VStack(alignment: .leading, spacing: 4) {
                    Text("Size: \(cubeSize, specifier: "%.1f")")
                    Slider(value: $cubeSize, in: 5...20) { _ in updatePointCloud() }
                    Text("Points per Face: \(Int(cubePointsPerFace))")
                    Slider(value: $cubePointsPerFace, in: 100...1000, step: 50) { _ in updatePointCloud() }
                }

            default:
                EmptyView()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var demoSelectorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Point Cloud Type")
                .font(.headline)

            Picker("Select Data", selection: $selectedDemo) {
                ForEach(0..<demoNames.count, id: \.self) { index in
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
                .frame(height: 400)

            GeometryReader { geometry in
                Canvas { context, size in
                    let centerX = size.width / 2
                    let centerY = size.height / 2
                    let scale = min(size.width, size.height) / 40
                    let angle = rotationAngle * .pi / 180

                    for point in currentPointCloud.points {
                        // 3D rotation around Y axis
                        let rotatedX = point.x * cos(angle) - point.z * sin(angle)
                        let rotatedZ = point.x * sin(angle) + point.z * cos(angle)

                        // Project to 2D
                        let projectedX = centerX + rotatedX * scale
                        let projectedY = centerY - point.y * scale

                        // Size based on Z depth
                        let pointSize = 2.0 + (rotatedZ + 20) / 20

                        // Color based on intensity or Z depth
                        let intensity = point.intensity ?? ((point.z + 10) / 20)
                        let color = Color(
                            hue: 0.6 - intensity * 0.4,
                            saturation: 0.8,
                            brightness: 0.9
                        )

                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: projectedX - pointSize/2,
                                y: projectedY - pointSize/2,
                                width: pointSize,
                                height: pointSize
                            )),
                            with: .color(color.opacity(0.8))
                        )
                    }
                }
            }
            .frame(height: 400)
        }
    }

    private var statisticsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.headline)

            HStack {
                Label("\(currentPointCloud.totalPoints) points", systemImage: "circle.grid.3x3.fill")
                Spacer()
                Label(String(format: "%.1f°", rotationAngle.truncatingRemainder(dividingBy: 360)), systemImage: "rotate.3d")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            if !currentPointCloud.parameters.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Parameters:")
                        .font(.caption)
                        .bold()
                    ForEach(Array(currentPointCloud.parameters.keys.sorted()), id: \.self) { key in
                        Text("\(key): \(currentPointCloud.parameters[key] ?? 0, specifier: "%.1f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var exportControlsView: some View {
        VStack(spacing: 12) {
            Text("Export Options")
                .font(.headline)

            HStack(spacing: 12) {
                Button(action: {
                    saveToWindow()
                }) {
                    Label("Save to Window", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }

                Button(action: {
                    exportToJupyter()
                }) {
                    Label("Export to Jupyter", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            Button(action: {
                copyPythonCode()
            }) {
                Label("Copy Python Code", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Helper Methods

    private func loadPointCloudFromWindow() {
        guard let windowID = windowID,
              let existingPointCloud = windowManager.getWindowPointCloud(for: windowID) else {
            return
        }
        currentPointCloud = existingPointCloud

        // Set demo selector based on saved data
        if let demoIndex = demoNames.firstIndex(where: { $0.lowercased().contains(existingPointCloud.demoType) }) {
            selectedDemo = demoIndex
        }
    }

    private func updatePointCloud() {
        switch selectedDemo {
        case 0:
            currentPointCloud = PointCloudDemo.generateSpherePointCloudData(
                radius: sphereRadius,
                points: Int(spherePoints)
            )
        case 1:
            currentPointCloud = PointCloudDemo.generateTorusPointCloudData(
                majorRadius: torusMajorRadius,
                minorRadius: torusMinorRadius,
                points: Int(torusPoints)
            )
        case 2:
            currentPointCloud = PointCloudDemo.generateWaveSurfaceData(
                size: waveSize,
                resolution: Int(waveResolution)
            )
        case 3:
            currentPointCloud = PointCloudDemo.generateSpiralGalaxyData(
                arms: Int(galaxyArms),
                points: Int(galaxyPoints)
            )
        case 4:
            currentPointCloud = PointCloudDemo.generateNoisyCubeData(
                size: cubeSize,
                pointsPerFace: Int(cubePointsPerFace)
            )
        default:
            break
        }
    }

    private func startRotationAnimation() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }

    private func saveToWindow() {
        guard let windowID = windowID else { return }
        windowManager.updateWindowPointCloud(windowID, pointCloud: currentPointCloud)
        windowManager.updateWindowContent(windowID, content: currentPointCloud.toPythonCode())
        print("✅ Point cloud saved to window #\(windowID)")
    }

    private func exportToJupyter() {
        let pythonCode = currentPointCloud.toPythonCode()
        let filename = "pointcloud_\(currentPointCloud.demoType)_\(Date().timeIntervalSince1970)"

        // Save to file
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let fileURL = documentsDirectory.appendingPathComponent("\(filename).py")

        do {
            try pythonCode.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Point cloud exported to: \(fileURL.path)")
        } catch {
            print("❌ Error saving file: \(error)")
        }

        // Also save to window if we have a window ID
        saveToWindow()
    }

    private func copyPythonCode() {
        let pythonCode = currentPointCloud.toPythonCode()

        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pythonCode, forType: .string)
        print("✅ Python code copied to clipboard")
        #endif
    }
    
}
