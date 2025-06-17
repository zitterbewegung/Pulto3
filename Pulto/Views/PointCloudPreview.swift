// MARK: - Enhanced Point Cloud Viewer following Apple HIG
struct PointCloudPreview: View {
    @State private var selectedDemo = 0
    @State private var rotationAngle = 0.0
    @State private var isRotating = true
    @State private var pointSize: Double = 1.0
    @State private var showStats = true
    @State private var projectionType = ProjectionType.perspective
    
    enum ProjectionType: String, CaseIterable {
        case orthographic = "Orthographic"
        case perspective = "Perspective"
        
        var icon: String {
            switch self {
            case .orthographic: return "square.grid.3x3"
            case .perspective: return "cube"
            }
        }
    }

    let demoNames = ["Sphere", "Torus", "Wave Surface", "Spiral Galaxy", "Noisy Cube"]

    var currentPointCloud: [(x: Double, y: Double, z: Double, intensity: Double?)] {
        switch selectedDemo {
        case 0:
            return PointCloudDemo.generateSpherePointCloud(radius: 10, points: 500)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: nil) }
        case 1:
            return PointCloudDemo.generateTorusPointCloud(majorRadius: 10, minorRadius: 3, points: 800)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: $0.intensity) }
        case 2:
            return PointCloudDemo.generateWaveSurface(size: 20, resolution: 30)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: $0.intensity) }
        case 3:
            return PointCloudDemo.generateSpiralGalaxy(arms: 3, points: 1000)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: $0.intensity) }
        case 4:
            return PointCloudDemo.generateNoisyCube(size: 10, pointsPerFace: 200)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: nil) }
        default:
            return []
        }
    }
    
    // Computed statistics
    var pointCloudBounds: (min: (x: Double, y: Double, z: Double), max: (x: Double, y: Double, z: Double)) {
        guard !currentPointCloud.isEmpty else {
            return (min: (0, 0, 0), max: (0, 0, 0))
        }
        
        var minX = Double.infinity, minY = Double.infinity, minZ = Double.infinity
        var maxX = -Double.infinity, maxY = -Double.infinity, maxZ = -Double.infinity
        
        for point in currentPointCloud {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            minZ = min(minZ, point.z)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
            maxZ = max(maxZ, point.z)
        }
        
        return (min: (minX, minY, minZ), max: (maxX, maxY, maxZ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbarView
            
            // Main content area
            HStack(spacing: 0) {
                // Visualization
                visualizationView
                
                // Sidebar
                if showStats {
                    sidebarView
                }
            }
            
            // Status bar
            statusBarView
        }
        .background(Color(white: 0.95))
    }
    
    private var toolbarView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Title
                VStack(alignment: .leading, spacing: 2) {
                    Text("Point Cloud Viewer")
                        .font(.headline)
                    Text("\(currentPointCloud.count) points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Dataset selector
                Picker("Dataset", selection: $selectedDemo) {
                    ForEach(0..<demoNames.count, id: \.self) { index in
                        Text(demoNames[index]).tag(index)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 180)
                
                // View controls
                HStack(spacing: 12) {
                    // Projection type
                    Picker("Projection", selection: $projectionType) {
                        ForEach(ProjectionType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 200)
                    
                    Divider()
                        .frame(height: 20)
                    
                    // Playback controls
                    Button(action: { isRotating.toggle() }) {
                        Image(systemName: isRotating ? "pause.fill" : "play.fill")
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(isRotating ? "Pause rotation" : "Resume rotation")
                    
                    Button(action: { rotationAngle = 0 }) {
                        Image(systemName: "gobackward")
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Reset rotation")
                    
                    Divider()
                        .frame(height: 20)
                    
                    // Toggle stats
                    Button(action: { withAnimation { showStats.toggle() } }) {
                        Image(systemName: showStats ? "sidebar.right" : "sidebar.left")
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Toggle statistics panel")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            Divider()
        }
        .background(Color(white: 0.98))
    }
    
    private var visualizationView: some View {
        ZStack {
            // Background with grid pattern
            GeometryReader { geometry in
                Canvas { context, size in
                    // Grid background
                    let gridSpacing: CGFloat = 50
                    context.stroke(
                        Path { path in
                            // Vertical lines
                            for x in stride(from: 0, through: size.width, by: gridSpacing) {
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: size.height))
                            }
                            // Horizontal lines
                            for y in stride(from: 0, through: size.height, by: gridSpacing) {
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: size.width, y: y))
                            }
                        },
                        with: .color(.gray.opacity(0.1)),
                        lineWidth: 0.5
                    )
                }
                .background(Color.white)
                
                // Point cloud rendering
                Canvas { context, size in
                    let centerX = size.width / 2
                    let centerY = size.height / 2
                    let scale = min(size.width, size.height) / 40
                    
                    // Calculate rotation
                    let angleRad = rotationAngle * .pi / 180
                    let cosAngle = cos(angleRad)
                    let sinAngle = sin(angleRad)
                    
                    // Sort points by depth for proper rendering
                    let sortedPoints = currentPointCloud.sorted { point1, point2 in
                        let z1 = point1.x * sinAngle + point1.z * cosAngle
                        let z2 = point2.x * sinAngle + point2.z * cosAngle
                        return z1 < z2
                    }
                    
                    for point in sortedPoints {
                        // 3D rotation around Y axis
                        let rotatedX = point.x * cosAngle - point.z * sinAngle
                        let rotatedZ = point.x * sinAngle + point.z * cosAngle
                        
                        // Projection
                        let projectedX: CGFloat
                        let projectedY: CGFloat
                        let depthScale: CGFloat
                        
                        switch projectionType {
                        case .orthographic:
                            projectedX = centerX + rotatedX * scale
                            projectedY = centerY - point.y * scale
                            depthScale = 1.0
                        case .perspective:
                            let perspectiveFactor = 1.0 / (1.0 + rotatedZ / 50.0)
                            projectedX = centerX + rotatedX * scale * perspectiveFactor
                            projectedY = centerY - point.y * scale * perspectiveFactor
                            depthScale = perspectiveFactor
                        }
                        
                        // Point size based on depth and user setting
                        let baseSize = 2.0 * pointSize
                        let finalSize = baseSize * (0.5 + depthScale * 0.5)
                        
                        // Color based on intensity or depth
                        let intensity = point.intensity ?? ((rotatedZ + 20) / 40)
                        let hue = 0.55 + intensity * 0.15 // Blue to purple gradient
                        let brightness = 0.4 + depthScale * 0.6
                        let color = Color(hue: hue, saturation: 0.7, brightness: brightness)
                        
                        // Draw point with subtle shadow
                        context.drawLayer { ctx in
                            // Shadow
                            ctx.fill(
                                Path(ellipseIn: CGRect(
                                    x: projectedX - finalSize/2 + 1,
                                    y: projectedY - finalSize/2 + 1,
                                    width: finalSize,
                                    height: finalSize
                                )),
                                with: .color(.black.opacity(0.1))
                            )
                            
                            // Point
                            ctx.fill(
                                Path(ellipseIn: CGRect(
                                    x: projectedX - finalSize/2,
                                    y: projectedY - finalSize/2,
                                    width: finalSize,
                                    height: finalSize
                                )),
                                with: .color(color)
                            )
                        }
                    }
                    
                    // Draw axes
                    drawAxes(context: context, size: size, centerX: centerX, centerY: centerY, scale: scale, angleRad: angleRad)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .padding()
            
            // Controls overlay
            VStack {
                HStack {
                    Spacer()
                    
                    // Point size control
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Point Size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $pointSize, in: 0.5...3.0)
                            .frame(width: 120)
                    }
                    .padding(8)
                    .background(.regularMaterial)
                    .cornerRadius(6)
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            startRotation()
        }
    }
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Statistics")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(white: 0.98))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Dataset info
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Dataset", systemImage: "cube.box")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(demoNames[selectedDemo])
                                .font(.body)
                                .fontWeight(.medium)
                            
                            HStack {
                                Label("\(currentPointCloud.count)", systemImage: "circle.grid.3x3")
                                    .font(.caption)
                                Spacer()
                                Text("points")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Bounds info
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Bounds", systemImage: "cube.transparent")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            let bounds = pointCloudBounds
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("X:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 20)
                                    Text(String(format: "%.1f to %.1f", bounds.min.x, bounds.max.x))
                                        .font(.caption.monospacedDigit())
                                }
                                
                                HStack {
                                    Text("Y:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 20)
                                    Text(String(format: "%.1f to %.1f", bounds.min.y, bounds.max.y))
                                        .font(.caption.monospacedDigit())
                                }
                                
                                HStack {
                                    Text("Z:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 20)
                                    Text(String(format: "%.1f to %.1f", bounds.min.z, bounds.max.z))
                                        .font(.caption.monospacedDigit())
                                }
                            }
                        }
                    }
                    
                    // Rotation info
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Rotation", systemImage: "rotate.3d")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text(String(format: "%.1f°", rotationAngle.truncatingRemainder(dividingBy: 360)))
                                    .font(.title2.monospacedDigit())
                                Spacer()
                                Text(isRotating ? "Rotating" : "Paused")
                                    .font(.caption)
                                    .foregroundColor(isRotating ? .green : .orange)
                            }
                        }
                    }
                    
                    // Export section
                    GroupBox {
                        VStack(spacing: 8) {
                            Label("Export Options", systemImage: "square.and.arrow.up")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button(action: exportToJupyter) {
                                Label("Export to Jupyter", systemImage: "doc.text")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: exportCurrentView) {
                                Label("Export Current View", systemImage: "camera")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 280)
        .background(Color(white: 0.97))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1),
            alignment: .leading
        )
    }
    
    private var statusBarView: some View {
        HStack(spacing: 16) {
            // Rotation angle
            HStack(spacing: 4) {
                Image(systemName: "rotate.3d")
                    .font(.caption)
                Text(String(format: "%.1f°", rotationAngle.truncatingRemainder(dividingBy: 360)))
                    .font(.caption.monospacedDigit())
            }
            .foregroundColor(.secondary)
            
            Divider()
                .frame(height: 12)
            
            // Point count
            HStack(spacing: 4) {
                Image(systemName: "circle.grid.3x3")
                    .font(.caption)
                Text("\(currentPointCloud.count) points")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
            Divider()
                .frame(height: 12)
            
            // Projection type
            HStack(spacing: 4) {
                Image(systemName: projectionType.icon)
                    .font(.caption)
                Text(projectionType.rawValue)
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
            Spacer()
            
            // Memory usage (simulated)
            HStack(spacing: 4) {
                Image(systemName: "memorychip")
                    .font(.caption)
                Text("\(currentPointCloud.count * 32 / 1024) KB")
                    .font(.caption.monospacedDigit())
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(white: 0.96))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1),
            alignment: .top
        )
    }
    
    // Helper functions
    private func drawAxes(context: GraphicsContext, size: CGSize, centerX: CGFloat, centerY: CGFloat, scale: CGFloat, angleRad: Double) {
        let axisLength: CGFloat = 15
        let cosAngle = cos(angleRad)
        let sinAngle = sin(angleRad)
        
        // X axis (red)
        let xEndRotated = axisLength * cosAngle
        let xEndZ = axisLength * sinAngle
        let xPerspective = projectionType == .perspective ? 1.0 / (1.0 + xEndZ / 50.0) : 1.0
        
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: centerX, y: centerY))
                path.addLine(to: CGPoint(x: centerX + xEndRotated * scale * xPerspective, y: centerY))
            },
            with: .color(.red.opacity(0.6)),
            lineWidth: 2
        )
        
        // Y axis (green)
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: centerX, y: centerY))
                path.addLine(to: CGPoint(x: centerX, y: centerY - axisLength * scale))
            },
            with: .color(.green.opacity(0.6)),
            lineWidth: 2
        )
        
        // Z axis (blue)
        let zEndRotated = -axisLength * sinAngle
        let zEndZ = axisLength * cosAngle
        let zPerspective = projectionType == .perspective ? 1.0 / (1.0 + zEndZ / 50.0) : 1.0
        
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: centerX, y: centerY))
                path.addLine(to: CGPoint(x: centerX + zEndRotated * scale * zPerspective, y: centerY))
            },
            with: .color(.blue.opacity(0.6)),
            lineWidth: 2
        )
    }
    
    private func startRotation() {
        if isRotating {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
    
    private func exportToJupyter() {
        PointCloudDemo.runAllDemos()
        print("✅ Exported all demos to Python files!")
    }
    
    private func exportCurrentView() {
        print("📸 Exporting current view...")
        // Implementation for exporting current view
    }
}