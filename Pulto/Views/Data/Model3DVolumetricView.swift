//
//  Model3DVolumetricView.swift
//  Pulto3
//
//  Enhanced with comprehensive controls for visionOS
//

import SwiftUI
import RealityKit
import simd

// MARK: - Enhanced Control Types
enum ViewPreset: String, CaseIterable {
    case front = "Front"
    case back = "Back"
    case left = "Left"
    case right = "Right"
    case top = "Top"
    case bottom = "Bottom"
    case isometric = "Isometric"
}

enum RenderQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case ultra = "Ultra"
}

// MARK: - Enhanced 3-D Model Volumetric Window
struct Model3DVolumetricView: View {

    // ───────── public init ─────────
    let windowID: Int
    let modelData: Model3DData?

    // ───────── view-model & state ─────────
    @StateObject private var vm = VolumetricModelViewModel()
    @State private var rotX: Float = 0
    @State private var rotY: Float = 0
    @State private var rotZ: Float = 0
    @State private var scale: Float = 1
    @State private var positionX: Float = 0
    @State private var positionY: Float = 0
    @State private var positionZ: Float = 0

    // Rendering controls
    @State private var wireframe = false
    @State private var showNormals = false
    @State private var showBoundingBox = false
    @State private var matIndex = 0
    @State private var lightIntensity: Float = 1.0
    @State private var renderQuality: RenderQuality = .medium

    // Animation controls
    @State private var autoRotate = false
    @State private var animationSpeed: Float = 1.0
    @State private var rotationAxis: SIMD3<Float> = [0, 1, 0]

    // UI state
    @State private var showControls = true
    @State private var selectedViewPreset: ViewPreset = .isometric
    @State private var controlsExpanded = false
    @State private var isUSDZ = false
    @State private var showImportSheet = false

    // ───────── body ─────────
    var body: some View {
        ZStack {
            GeometryReader3D { _ in
                RealityView { content, attachments in
                    // One-time scene build
                    let root = Entity(); root.name = "Model3DRoot"

                    if let md = modelData {
                        let e = try? makeModelEntity(from: md)
                        e.map { root.addChild($0) }
                    }
                    addKeyLight(to: root)
                    content.add(root)
                    vm.root = root

                    // Main control panel attachment
                    if let mainPanel = attachments.entity(for: "mainControls") {
                        mainPanel.position = [0.6, -0.1, 0.1]
                        content.add(mainPanel)
                    }

                    // Quick actions panel
                    if let quickPanel = attachments.entity(for: "quickActions") {
                        quickPanel.position = [-0.6, 0.3, 0.1]
                        content.add(quickPanel)
                    }

                    // View presets panel
                    if let viewPanel = attachments.entity(for: "viewPresets") {
                        viewPanel.position = [0.6, 0.3, 0.1]
                        content.add(viewPanel)
                    }

                } update: { _, _ in
                    updateScene()

                    if vm.needsRenderRefresh {
                        updateRenderMode(on: vm.root!)
                        vm.needsRenderRefresh = false
                    }

                } attachments: {
                    // Main control panel
                    Attachment(id: "mainControls") {
                        if showControls {
                            mainControlPanel
                        }
                    }

                    // Quick actions
                    Attachment(id: "quickActions") {
                        if showControls {
                            quickActionsPanel
                        }
                    }

                    // View presets
                    Attachment(id: "viewPresets") {
                        if showControls {
                            viewPresetsPanel
                        }
                    }
                }
            }

            .gesture(
                DragGesture()
                    .targetedToAnyEntity()
                    .onChanged { value in
                        handleDrag(value.gestureValue)
                    }
            )
            .gesture(
                MagnificationGesture()
                    .targetedToAnyEntity()
                    .onChanged { value in
                        scale = max(0.1, min(5.0, Float(value.gestureValue.magnitude)))
                    }
            )

            // Floating toggle for controls visibility
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showControls.toggle()
                        }
                    }) {
                        Image(systemName: showControls ? "eye.slash.fill" : "eye.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.trailing)
                }
                Spacer()
            }
            .padding(.top)
        }
        .task {
            await loadUSDZModel()
            startAutoRotationIfNeeded()
        }
        .sheet(isPresented: $showImportSheet) {
            Model3DImportSheet()
        }
        .onChange(of: wireframe) { _ in vm.needsRenderRefresh = true }
        .onChange(of: showNormals) { _ in vm.needsRenderRefresh = true }
        .onChange(of: showBoundingBox) { _ in vm.needsRenderRefresh = true }
        .onChange(of: matIndex) { _ in vm.needsRenderRefresh = true }
        .onChange(of: lightIntensity) { _ in vm.needsRenderRefresh = true }
        .onChange(of: selectedViewPreset) { newPreset in
            applyViewPreset(newPreset)
        }
        .task {
            // Auto-hide controls after 15 seconds
            try? await Task.sleep(for: .seconds(15))
            withAnimation(.easeOut(duration: 0.5)) {
                showControls = false
            }
        }
    }

    // MARK: - Control Panels

    private var quickActionsPanel: some View {
        VStack(spacing: 8) {
            Button(action: resetAllTransforms) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title2)
                    Text("Reset")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)

            Button(action: { autoRotate.toggle() }) {
                VStack(spacing: 4) {
                    Image(systemName: autoRotate ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                    Text(autoRotate ? "Pause" : "Rotate")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)

            Button(action: takeScreenshot) {
                VStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                    Text("Shot")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)

            Button(action: { showImportSheet = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                    Text("Import")
                        .font(.caption)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }

    private var viewPresetsPanel: some View {
        VStack(spacing: 8) {
            Text("Views")
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(ViewPreset.allCases, id: \.self) { preset in
                    Button(action: { selectedViewPreset = preset }) {
                        Text(preset.rawValue)
                            .font(.caption)
                            .foregroundColor(selectedViewPreset == preset ? .black : .white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedViewPreset == preset ? .white : .clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }

    private var mainControlPanel: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("3D Model Controls")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { controlsExpanded.toggle() }) {
                    Image(systemName: controlsExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white)
                }
            }

            if controlsExpanded {
                ScrollView {
                    VStack(spacing: 16) {
                        // Transform Section
                        controlSection("Transform") {
                            slider("Rotate X",
                                   value: Binding(get: {Double(rotX)}, set: {rotX = Float($0)}),
                                   range: -Double.pi...Double.pi,
                                   format: "%.1f°") { $0 * 180 / Double.pi }

                            slider("Rotate Y",
                                   value: Binding(get: {Double(rotY)}, set: {rotY = Float($0)}),
                                   range: -Double.pi...Double.pi,
                                   format: "%.1f°") { $0 * 180 / Double.pi }

                            slider("Rotate Z",
                                   value: Binding(get: {Double(rotZ)}, set: {rotZ = Float($0)}),
                                   range: -Double.pi...Double.pi,
                                   format: "%.1f°") { $0 * 180 / Double.pi }

                            slider("Scale",
                                   value: Binding(get: {Double(scale)}, set: {scale = Float($0)}),
                                   range: 0.1...3.0,
                                   format: "%.2f") { $0 }

                            slider("Pos X",
                                   value: Binding(get: {Double(positionX)}, set: {positionX = Float($0)}),
                                   range: -2.0...2.0,
                                   format: "%.2f") { $0 }

                            slider("Pos Y",
                                   value: Binding(get: {Double(positionY)}, set: {positionY = Float($0)}),
                                   range: -2.0...2.0,
                                   format: "%.2f") { $0 }

                            slider("Pos Z",
                                   value: Binding(get: {Double(positionZ)}, set: {positionZ = Float($0)}),
                                   range: -2.0...2.0,
                                   format: "%.2f") { $0 }
                        }

                        // Rendering Section
                        controlSection("Rendering") {
                            HStack {
                                Text("Quality")
                                    .foregroundColor(.white)
                                    .frame(width: 60, alignment: .leading)
                                Picker("Quality", selection: $renderQuality) {
                                    ForEach(RenderQuality.allCases, id: \.self) { quality in
                                        Text(quality.rawValue).tag(quality)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            slider("Light",
                                   value: Binding(get: {Double(lightIntensity)}, set: {lightIntensity = Float($0)}),
                                   range: 0.1...3.0,
                                   format: "%.1f") { $0 }

                            if !isUSDZ {
                                Toggle("Wireframe", isOn: $wireframe)
                                    .tint(.blue)
                                    .foregroundColor(.white)

                                Toggle("Show Normals", isOn: $showNormals)
                                    .tint(.green)
                                    .foregroundColor(.white)

                                Toggle("Bounding Box", isOn: $showBoundingBox)
                                    .tint(.orange)
                                    .foregroundColor(.white)
                            }
                        }

                        // Animation Section
                        controlSection("Animation") {
                            HStack {
                                Toggle("Auto Rotate", isOn: $autoRotate)
                                    .tint(.purple)
                                    .foregroundColor(.white)
                            }

                            if autoRotate {
                                slider("Speed",
                                       value: Binding(get: {Double(animationSpeed)}, set: {animationSpeed = Float($0)}),
                                       range: 0.1...3.0,
                                       format: "%.1fx") { $0 }

                                HStack {
                                    Text("Axis")
                                        .foregroundColor(.white)
                                        .frame(width: 60, alignment: .leading)

                                    Button("X") { rotationAxis = [1, 0, 0] }
                                        .buttonStyle(.bordered)
                                        .foregroundColor(rotationAxis == [1, 0, 0] ? .black : .white)

                                    Button("Y") { rotationAxis = [0, 1, 0] }
                                        .buttonStyle(.bordered)
                                        .foregroundColor(rotationAxis == [0, 1, 0] ? .black : .white)

                                    Button("Z") { rotationAxis = [0, 0, 1] }
                                        .buttonStyle(.bordered)
                                        .foregroundColor(rotationAxis == [0, 0, 1] ? .black : .white)
                                }
                            }
                        }

                        // Material Section
                        if let md = modelData, !md.materials.isEmpty, !isUSDZ {
                            controlSection("Materials") {
                                HStack {
                                    Text("Material")
                                        .foregroundColor(.white)
                                        .frame(width: 60, alignment: .leading)
                                    Picker("Material", selection: $matIndex) {
                                        ForEach(md.materials.indices, id: \.self) { index in
                                            Text(md.materials[index].name).tag(index)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .foregroundColor(.white)
                                }
                            }
                        }

                        // Model Info Section
                        if let md = modelData {
                            controlSection("Model Info") {
                                VStack(alignment: .leading, spacing: 4) {
                                    infoRow("Vertices", "\(md.vertices.count)")
                                    infoRow("Faces", "\(md.faces.count)")
                                    infoRow("Type", md.modelType)
                                    infoRow("Materials", "\(md.materials.count)")
                                }
                            }
                        } else if isUSDZ {
                            controlSection("Model Info") {
                                Text("Imported USDZ Model")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }

                        // Actions Section
                        controlSection("Actions") {
                            HStack(spacing: 12) {
                                Button("Export USDZ") {
                                    exportModel()
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Reset All") {
                                    resetAll()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            } else {
                // Collapsed view - show essential controls only
                VStack(spacing: 8) {
                    slider("Rotate Y",
                           value: Binding(get: {Double(rotY)}, set: {rotY = Float($0)}),
                           range: -Double.pi...Double.pi,
                           format: "%.0f°") { $0 * 180 / Double.pi }

                    slider("Scale",
                           value: Binding(get: {Double(scale)}, set: {scale = Float($0)}),
                           range: 0.1...3.0,
                           format: "%.1f") { $0 }

                    if !isUSDZ {
                        HStack(spacing: 16) {
                            Toggle("Wire", isOn: $wireframe)
                                .tint(.blue)
                                .foregroundColor(.white)
                            Toggle("Normals", isOn: $showNormals)
                                .tint(.green)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: controlsExpanded ? 320 : 280)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 10)
    }

    // MARK: - Helper Views

    private func controlSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            content()
        }
    }

    private func slider(_ label: String,
                       value: Binding<Double>,
                       range: ClosedRange<Double>,
                       format: String,
                       transform: @escaping (Double) -> Double) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white)
                .frame(width: 60, alignment: .leading)
            Slider(value: value, in: range)
                .frame(width: 140)
            Text(String(format: format, transform(value.wrappedValue)))
                .font(.caption.monospacedDigit())
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 50, alignment: .trailing)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
        .font(.caption)
    }

    // MARK: - Scene Management

    private func updateScene() {
        guard let root = vm.root else { return }

        root.transform.rotation =
            simd_quatf(angle: rotX, axis: [1,0,0]) *
            simd_quatf(angle: rotY, axis: [0,1,0]) *
            simd_quatf(angle: rotZ, axis: [0,0,1])

        root.scale = [scale, scale, scale]
        root.position = [positionX, positionY, positionZ]

        // Handle auto-rotation
        if autoRotate {
            let rotationSpeed = 0.02 * animationSpeed
            if rotationAxis == [1, 0, 0] {
                rotX += rotationSpeed
            } else if rotationAxis == [0, 1, 0] {
                rotY += rotationSpeed
            } else if rotationAxis == [0, 0, 1] {
                rotZ += rotationSpeed
            }
        }
    }

    private func startAutoRotationIfNeeded() {
        // Setup timer for auto-rotation if needed
    }

    private func handleDrag(_ value: DragGesture.Value) {
        let sensitivity: Float = 0.01
        rotY += Float(value.translation.width) * sensitivity
        rotX += Float(value.translation.height) * sensitivity
    }

    private func applyViewPreset(_ preset: ViewPreset) {
        withAnimation(.easeInOut(duration: 0.5)) {
            switch preset {
            case .front:
                rotX = 0; rotY = 0; rotZ = 0
            case .back:
                rotX = 0; rotY = Float.pi; rotZ = 0
            case .left:
                rotX = 0; rotY = -Float.pi/2; rotZ = 0
            case .right:
                rotX = 0; rotY = Float.pi/2; rotZ = 0
            case .top:
                rotX = -Float.pi/2; rotY = 0; rotZ = 0
            case .bottom:
                rotX = Float.pi/2; rotY = 0; rotZ = 0
            case .isometric:
                rotX = -Float.pi/6; rotY = Float.pi/4; rotZ = 0
            }
        }
    }

    private func resetAllTransforms() {
        withAnimation(.easeInOut(duration: 0.5)) {
            rotX = 0; rotY = 0; rotZ = 0
            scale = 1.0
            positionX = 0; positionY = 0; positionZ = 0
        }
    }

    private func resetAll() {
        resetAllTransforms()
        wireframe = false
        showNormals = false
        showBoundingBox = false
        lightIntensity = 1.0
        autoRotate = false
        animationSpeed = 1.0
        renderQuality = .medium
        matIndex = 0
    }

    private func takeScreenshot() {
        // Implementation for screenshot
        print("Taking screenshot...")
    }

    private func exportModel() {
        // Implementation for model export
        print("Exporting model...")
    }

    // MARK: - Original Methods (preserved from your implementation)

    private func loadUSDZModel() async {
        guard let bookmark = WindowTypeManager.shared.getWindowSafely(for: windowID)?.state.usdzBookmark,
              modelData == nil else { return }
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                let modelEntity = try await Entity(contentsOf: url)
                modelEntity.name = "USDZModel"
                // Center and normalize scale
                let bounds = modelEntity.visualBounds(relativeTo: nil as Entity?)
                modelEntity.position = -bounds.center
                let maxExtent = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
                if maxExtent > 0 {
                    modelEntity.scale *= 0.5 / maxExtent
                }
                vm.root?.addChild(modelEntity)
                isUSDZ = true
            }
        } catch {
            print("Failed to load USDZ: \(error)")
        }
    }

    private func addKeyLight(to root: Entity) {
        let sun = DirectionalLight()
        sun.light.intensity = 2_000 * lightIntensity
        sun.position = [1, 2, 1]
        sun.look(at: .zero, from: sun.position, relativeTo: nil)
        root.addChild(sun)
    }

    @MainActor
    private func makeModelEntity(from d: Model3DData) throws -> Entity {
        let e = Entity(); e.name = "3DModel"

        let verts = d.vertices.map { simd_float3(Float($0.x), Float($0.y), Float($0.z)) }

        // triangulate faces
        var pos:[simd_float3]=[], nrm:[simd_float3]=[]
        var idx:[UInt32]=[]; var vIdx:UInt32 = 0
        for f in d.faces where f.vertices.count >= 3 {
            let vs = f.vertices.map { verts[$0] }
            let n  = normalize(cross(vs[1]-vs[0], vs[2]-vs[0]))
            for i in 1..<vs.count-1 {
                pos += [vs[0], vs[i], vs[i+1]]
                nrm += [n,n,n]
                idx += [vIdx, vIdx+1, vIdx+2]; vIdx += 3
            }
        }

        // Create the mesh contents
        var desc = MeshDescriptor()
        desc.positions = MeshBuffers.Positions(pos)
        desc.normals = MeshBuffers.Normals(nrm)
        desc.primitives = .triangles(idx)

        let mesh = try MeshResource.generate(from: [desc])

        let mat = makeMaterial(for: d)
        let mEnt = ModelEntity(mesh: mesh, materials: [mat])
        mEnt.position = [Float(d.position.x), Float(d.position.y), Float(d.position.z)]
        mEnt.scale    = [Float(d.scale), Float(d.scale), Float(d.scale)]

        // Store positions/normals for later normal-debug rebuild
        mEnt.components.set(PositionsNormalsComponent(positions: pos, normals: nrm))

        e.addChild(mEnt)

        if showNormals { e.addChild(debugNormals(from: pos, nrm)) }
        return e
    }

    private func makeMaterial(for d: Model3DData) -> RealityKit.Material {
        if wireframe {
            var m = SimpleMaterial()
            m.color = .init(tint: .white.withAlphaComponent(0.9))
            m.triangleFillMode = .lines
            return m
        }

        guard d.materials.indices.contains(matIndex) else { return SimpleMaterial() }
        let info = d.materials[matIndex]

        var m = SimpleMaterial()
        m.color     = .init(tint: hexColor(info.color))
        m.metallic  = .float(Float(info.metallic  ?? 0.1))
        m.roughness = .float(Float(info.roughness ?? 0.5))
        return m
    }

    private func updateRenderMode(on root: Entity) {
        guard let md = modelData,
              let model = root.findEntity(named: "3DModel") as? ModelEntity else { return }

        model.model?.materials = [makeMaterial(for: md)]

        // Normal-debug toggle
        if showNormals, model.findEntity(named: "Normals") == nil {
            if let attr = model.components[PositionsNormalsComponent.self] {
                model.addChild(debugNormals(from: attr.positions, attr.normals))
            }
        } else if !showNormals {
            model.findEntity(named:"Normals")?.removeFromParent()
        }

        // Bounding box toggle
        if showBoundingBox, model.findEntity(named: "BoundingBox") == nil {
            model.addChild(createBoundingBox(for: model))
        } else if !showBoundingBox {
            model.findEntity(named: "BoundingBox")?.removeFromParent()
        }

        // Update lighting
        if let light = root.findEntity(named: "DirectionalLight") as? DirectionalLight {
            light.light.intensity = 2000 * lightIntensity
        }
    }

    private func debugNormals(from p:[simd_float3], _ n:[simd_float3]) -> Entity {
        let root = Entity(); root.name = "Normals"
        let len:Float = 0.1, r:Float = 0.001
        let mat = SimpleMaterial(color: .green, isMetallic: false)

        for (start,dir) in zip(p,n) {
            let end = start + dir*len
            let cyl = MeshResource.generateCylinder(height: len, radius: r)
            let e = ModelEntity(mesh: cyl, materials: [mat])
            e.position = (start+end)*0.5
            e.look(at: end, from: start, relativeTo: nil)
            root.addChild(e)
        }
        return root
    }

    private func createBoundingBox(for model: ModelEntity) -> Entity {
        let root = Entity(); root.name = "BoundingBox"
        let bounds = model.visualBounds(relativeTo: nil)

        let wireframeMaterial = SimpleMaterial(color: .orange, isMetallic: false)
        let boxMesh = MeshResource.generateBox(size: bounds.extents)
        let boxEntity = ModelEntity(mesh: boxMesh, materials: [wireframeMaterial])

        // Set wireframe mode
        if var material = boxEntity.model?.materials.first as? SimpleMaterial {
            material.triangleFillMode = .lines
            boxEntity.model?.materials = [material]
        }

        boxEntity.position = bounds.center
        root.addChild(boxEntity)

        return root
    }

    private func hexColor(_ hex:String) -> UIColor {
        var cs = Array(hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex))
        if cs.count == 3 { cs = cs.flatMap { [$0,$0] } }
        guard cs.count == 6,
              let r = UInt8(String(cs[0...1]), radix:16),
              let g = UInt8(String(cs[2...3]), radix:16),
              let b = UInt8(String(cs[4...5]), radix:16)
        else { return .gray }
        return UIColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
    }
}

// MARK: - Components and ViewModels (preserved)

struct PositionsNormalsComponent: Component {
    var positions: [simd_float3]
    var normals:   [simd_float3]
}

final class VolumetricModelViewModel: ObservableObject {
    @Published var root: Entity?
    @Published var needsRenderRefresh = false
}
