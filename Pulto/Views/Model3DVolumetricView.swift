//
//  Model3DVolumetricView.swift
//  Pulto3
//
//  Created by ChatGPT on 9 Jul 2025.
//

import SwiftUI
import RealityKit
import simd

// MARK: - 3-D Model Volumetric Window
struct Model3DVolumetricView: View {

    // ───────── public init ─────────
    let windowID: Int
    let modelData: Model3DData?

    // ───────── view-model & state ─────────
    @StateObject private var vm = VolumetricModelViewModel()   // ← renamed
    @State private var rotX:  Float = 0
    @State private var rotY:  Float = 0
    @State private var scale: Float = 1
    @State private var wireframe   = false
    @State private var showNormals = false
    @State private var matIndex    = 0
    @State private var isUSDZ      = false  // ← NEW: flag for USDZ-specific handling

    @State private var showImportSheet = false

    // ───────── body ─────────
    var body: some View {
        GeometryReader3D { _ in
            RealityView { content, attachments in
                // One-time scene build
                let root = Entity(); root.name = "Model3DRoot"

                if let md = modelData {
                    let e = try? makeModelEntity(from: md)  // ← Removed unnecessary 'await' (function isn't async)
                    e.map { root.addChild($0) }
                }
                addKeyLight(to: root)
                content.add(root)
                vm.root = root

                // UI panel
                if let panel = attachments.entity(for: "ui") {
                    panel.position = [0, -0.25, 0]  // ← Adjusted position for better visibility
                    content.add(panel)
                }

            } update: { _, _ in
                guard let root = vm.root else { return }

                root.transform.rotation =
                    simd_quatf(angle: rotX, axis: [1,0,0]) *
                    simd_quatf(angle: rotY, axis: [0,1,0])
                root.scale = [scale, scale, scale]

                if vm.needsRenderRefresh {
                    updateRenderMode(on: root)
                    vm.needsRenderRefresh = false
                }

            } attachments: {
                Attachment(id: "ui") { controlPanel }
            }
        }
        .task {
            await loadUSDZModel()  // ← NEW: async load USDZ if available
        }
        .sheet(isPresented: $showImportSheet) { Model3DImportSheet() }
        .onChange(of: wireframe) { _ in vm.needsRenderRefresh = true }
        .onChange(of: showNormals) { _ in vm.needsRenderRefresh = true }
        .onChange(of: matIndex)    { _ in vm.needsRenderRefresh = true }
    }

    // Updated loadUSDZModel in Model3DVolumetricView
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
                    modelEntity.scale *= 0.5 / maxExtent  // Fit to ~0.5 units, adjust as needed
                }
                vm.root?.addChild(modelEntity)
                isUSDZ = true
            }
        } catch {
            print("Failed to load USDZ: \(error)")
        }
    }

    // MARK: control panel
    private var controlPanel: some View {
        VStack(spacing: 12) {
            Text("3-D Model Controls")
                .font(.headline).foregroundColor(.white)

            slider("Rotate X",
                   value: Binding(get:{Double(rotX)}, set:{rotX = Float($0)}),
                   range: -Double.pi...Double.pi)
            slider("Rotate Y",
                   value: Binding(get:{Double(rotY)}, set:{rotY = Float($0)}),
                   range: -Double.pi...Double.pi)
            slider("Scale",
                   value: Binding(get:{Double(scale)}, set:{scale = Float($0)}),
                   range: 0.5...3)                       // ← Float→Double fix

            if !isUSDZ {
                Toggle("Wire-frame",    isOn: $wireframe )
                    .tint(.blue).foregroundColor(.white)
                Toggle("Show Normals", isOn: $showNormals)
                    .tint(.green).foregroundColor(.white)
            }

            if let md = modelData, !md.materials.isEmpty, !isUSDZ {
                Picker("Material", selection: $matIndex) {
                    ForEach(md.materials.indices, id:\.self) {
                        Text(md.materials[$0].name).tag($0)
                    }
                }
                .pickerStyle(.menu).foregroundColor(.white)
            }

            Button {
                showImportSheet = true
            } label: {
                Label("Import Model…", systemImage: "square.and.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20).padding(.vertical, 6)
                    .background(.orange.opacity(0.2))
                    .cornerRadius(8)
            }

            if let md = modelData {
                VStack(alignment: .leading) {
                    Text("Vertices: \(md.vertices.count)")
                    Text("Faces: \(md.faces.count)")
                    Text("Type: \(md.modelType)")
                }
                .font(.caption).foregroundColor(.white.opacity(0.8))
            } else if isUSDZ {
                Text("Imported USDZ Model")
                    .font(.caption).foregroundColor(.white.opacity(0.8))
            }
        }
        .padding().background(.ultraThinMaterial).cornerRadius(12)
    }

    // MARK: scene helpers
    private func addKeyLight(to root: Entity) {
        let sun = DirectionalLight()
        sun.light.intensity = 2_000
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
    private func makeMaterial(for d: Model3DData) -> RealityKit.Material {  // disambiguated
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
        guard let md = modelData,  // ← Added guard to prevent crash if modelData is nil
              let model = root.findEntity(named: "3DModel") as? ModelEntity else { return }

        model.model?.materials = [makeMaterial(for: md)]

        // Normal-debug toggle (add / remove child)
        if showNormals, model.findEntity(named: "Normals") == nil {
            // Use positions & normals we baked earlier (stored via component)
            if let attr = model.components[PositionsNormalsComponent.self] {
                model.addChild(debugNormals(from: attr.positions, attr.normals))
            }
        } else if !showNormals {
            model.findEntity(named:"Normals")?.removeFromParent()
        }
    }

    // MARK: normal lines
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

    // MARK: slider helper
    private func slider(_ label:String, value:Binding<Double>, range:ClosedRange<Double>) -> some View {
        HStack {
            Text(label).foregroundColor(.white).frame(width: 80, alignment:.leading)
            Slider(value: value, in: range).frame(width: 150)
        }
    }

    // MARK: colour helper
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
/// Stores vertex positions & normals so we can rebuild the
/// debug-normal overlay without recalculating geometry.
struct PositionsNormalsComponent: Component {
    var positions: [simd_float3]
    var normals:   [simd_float3]
}

// MARK: - lightweight view-model (renamed to avoid duplicate)
final class VolumetricModelViewModel: ObservableObject {
    @Published var root: Entity?
    @Published var needsRenderRefresh = false
}
