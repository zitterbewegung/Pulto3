//
//  ImportSheets.swift
//  Pulto3
//
//  Created by ChatGPT on 2025-07-09.
//  Two drop-in sheets: PointCloudImportSheet and Model3DImportSheet
//

import SwiftUI
import UniformTypeIdentifiers
import RealityKit

// MARK: - Point-Cloud Import Sheet
struct PointCloudImportSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showImporter = false
    @State private var importError : ImportError?
    @State private var isProcessing = false

    private let windowManager = WindowTypeManager.shared   // singleton

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "dot.scope")
                    .font(.system(size: 60))
                    .foregroundStyle(.linearGradient(colors: [.purple,.blue],
                                                     startPoint: .topLeading,
                                                     endPoint: .bottomTrailing))

                Text("Import Point Cloud")
                    .font(.title2.weight(.semibold))

                Text("Select a **CSV** or **JSON** file that contains *x, y, z* "
                     + "columns (optionally *intensity*).")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    showImporter = true
                } label: {
                    Label("Choose File …", systemImage: "folder")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(.purple.opacity(0.15))
                        .cornerRadius(10)
                }
                .disabled(isProcessing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if isProcessing { ProgressView("Processing…").progressViewStyle(.circular) }
            }
            .navigationTitle("Import")
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.commaSeparatedText, .json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls) where urls.first != nil:
                    importFile(urls.first!)
                case .success:
                    break
                case .failure(let err):
                    importError = .fileError(err)
                }
            }
            .alert("Import Failed",
                   isPresented: Binding<Bool>(
                    get: { importError != nil },
                    set: { _ in importError = nil })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError?.localizedDescription ?? "Unknown error.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: – Import Logic
    private func importFile(_ url: URL) {
        isProcessing = true
        Task.detached(priority: .userInitiated) {
            do {
                let pc = try parsePointCloud(from: url)
                await MainActor.run {
                    createPointCloudWindow(with: pc)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    importError = .fileError(error)
                }
            }
            await MainActor.run { isProcessing = false }
        }
    }

    @MainActor
    private func createPointCloudWindow(with pc: PointCloudData) {
        let newID   = windowManager.getNextWindowID()
        _ = windowManager.createWindow(.pointcloud, id: newID)              // ☎️ TODO adjust if needed
        windowManager.updateWindowPointCloud(newID, data: pc)               // ☎️ TODO adjust if needed
        windowManager.markWindowAsOpened(newID)
    }
}

// MARK: - 3-D Model Import Sheet
struct Model3DImportSheet: View {
    @Environment(\.dismiss)           private var dismiss
    @State    private var showImport  = false
    @State    private var isProcessing = false
    @State    private var importError : ImportError?

    private let windowManager = WindowTypeManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "cube.transparent.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.linearGradient(colors: [.orange,.pink],
                                                     startPoint: .topLeading,
                                                     endPoint: .bottomTrailing))

                Text("Import 3-D Model")
                    .font(.title2.weight(.semibold))

                Text("Select a **USDZ**, **OBJ**, **STL** or **Model 3-D** file.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    showImport = true
                } label: {
                    Label("Choose File …", systemImage: "folder")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(.orange.opacity(0.15))
                        .cornerRadius(10)
                }
                .disabled(isProcessing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if isProcessing { ProgressView("Processing…").progressViewStyle(.circular) }
            }
            .navigationTitle("Import")
            .fileImporter(
                isPresented: $showImport,
                allowedContentTypes: [.usdz, .model3d, .object, .stl],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls) where urls.first != nil:
                    importFile(urls.first!)
                case .success:
                    break
                case .failure(let err):
                    importError = .fileError(err)
                }
            }
            .alert("Import Failed",
                   isPresented: Binding<Bool>(
                    get: { importError != nil },
                    set: { _ in importError = nil })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError?.localizedDescription ?? "Unknown error.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func importFile(_ url: URL) {
        isProcessing = true
        Task.detached(priority: .userInitiated) {
            do {
                let model = try await parseModel3D(from: url)
                await MainActor.run {
                    createModelWindow(with: model)
                    dismiss()
                }
            } catch {
                await MainActor.run { importError = .fileError(error) }
            }
            await MainActor.run { isProcessing = false }
        }
    }

    @MainActor
    private func createModelWindow(with model: Model3DData) {
        let newID = windowManager.getNextWindowID()
        _ = windowManager.createWindow(.model3d, id: newID)                 // ☎️ TODO adjust if needed
        windowManager.updateWindowModel3D(newID, data: model)               // ☎️ TODO adjust if needed
        windowManager.markWindowAsOpened(newID)
    }
}

// MARK: - Import Helpers & Errors

private enum ImportError: LocalizedError {
    case fileError(Error), badFormat

    var errorDescription: String? {
        switch self {
        case .fileError(let err): return err.localizedDescription
        case .badFormat:          return "The selected file is not in a supported format."
        }
    }
}

// Point-cloud CSV/JSON parser (very simple – extend as needed)
private func parsePointCloud(from url: URL) throws -> PointCloudData {
    let data = try Data(contentsOf: url)

    if url.pathExtension.lowercased() == "json" {
        // Expecting an array of { "x": …, "y": …, "z": …, "intensity": … }
        struct J: Decodable { var x: Double; var y: Double; var z: Double; var intensity: Double? }
        let decoded = try JSONDecoder().decode([J].self, from: data)
        var pc = PointCloudData(title: url.lastPathComponent, demoType: "import-json")
        pc.points = decoded.map { .init(x:$0.x, y:$0.y, z:$0.z, intensity:$0.intensity) }
        pc.totalPoints = pc.points.count
        return pc
    }

    // CSV: x,y,z,(intensity)
    guard let txt = String(data: data, encoding: .utf8) else { throw ImportError.badFormat }
    var pc = PointCloudData(title: url.lastPathComponent, demoType: "import-csv")
    for line in txt.split(whereSeparator: \.isNewline) {
        let parts = line.split(separator: ",").map { Double($0) ?? 0 }
        guard parts.count >= 3 else { continue }
        pc.points.append(.init(x: parts[0], y: parts[1], z: parts[2],
                               intensity: parts.count > 3 ? parts[3] : nil))
    }
    pc.totalPoints = pc.points.count
    if pc.totalPoints == 0 { throw ImportError.badFormat }
    return pc
}

// Very lightweight OBJ / STL / USDZ → Model3DData converter.
// For real projects you’d use ModelIO or RealityKit’s loader.
private func parseModel3D(from url: URL) async throws -> Model3DData {
    switch url.pathExtension.lowercased() {
    case "usdz":
        return try await loadUSDZ(at: url)
    case "obj":
        return try loadOBJ(at: url)
    case "stl":
        return try loadSTL(at: url)
    default:
        throw ImportError.badFormat
    }
}

// USDZ: use RealityKit (async)
private func loadUSDZ(at url: URL) async throws -> Model3DData {
    let entity = try await Entity(contentsOf: url)
    let (verts, faces) = entity.flattenedGeometry()
    var md = Model3DData(title: url.lastPathComponent, modelType: "usd")
    md.vertices = verts
    md.faces    = faces
    return md
}

// OBJ: naïve text parser (triangles only)
private func loadOBJ(at url: URL) throws -> Model3DData {
    let txt = try String(contentsOf: url)
    var v: [Model3DData.Vertex3D] = []
    var f: [Model3DData.Face3D]   = []

    for line in txt.split(whereSeparator: \.isNewline) {
        let parts = line.split(separator: " ")
        if parts.first == "v", parts.count >= 4 {
            v.append(.init(x: Double(parts[1])!, y: Double(parts[2])!, z: Double(parts[3])!))
        } else if parts.first == "f", parts.count >= 4 {
            let idx = parts[1...3].compactMap { Int($0.split(separator: "/")[0])! - 1 }
            if idx.count == 3 { f.append(.init(vertices: idx, materialIndex: nil)) }
        }
    }
    guard !v.isEmpty, !f.isEmpty else { throw ImportError.badFormat }
    var m = Model3DData(title: url.lastPathComponent, modelType: "obj")
    m.vertices = v; m.faces = f
    return m
}

// STL: ASCII only (triangles)
private func loadSTL(at url: URL) throws -> Model3DData {
    let txt = try String(contentsOf: url)
    var v:[Model3DData.Vertex3D] = []
    var f:[Model3DData.Face3D]   = []
    for line in txt.split(whereSeparator: \.isNewline) where line.contains("vertex") {
        let p = line.split(whereSeparator: \.isWhitespace)
        guard p.count == 4 else { continue }
        v.append(.init(x: Double(p[1])!, y: Double(p[2])!, z: Double(p[3])!))
    }
    for i in stride(from: 0, to: v.count, by: 3) where i+2 < v.count {
        f.append(.init(vertices: [i, i+1, i+2], materialIndex:nil))
    }
    guard !v.isEmpty else { throw ImportError.badFormat }
    var m = Model3DData(title: url.lastPathComponent, modelType: "stl")
    m.vertices = v; m.faces = f
    return m
}

// MARK: - Entity → flattened geometry helper
private extension Entity {
    func flattenedGeometry() -> ([Model3DData.Vertex3D],[Model3DData.Face3D]) {
        var verts:[Model3DData.Vertex3D] = []; var faces:[Model3DData.Face3D] = []
        recurse(self, &verts, &faces)
        return (verts, faces)

        func recurse(_ e: Entity,_ v: inout [Model3DData.Vertex3D],_ f: inout [Model3DData.Face3D]) {
            if let me = e as? ModelEntity,
               let mesh = me.model?.mesh,
               let buf  = try? mesh.generateModelDescriptor().positions {
                let startIndex = v.count
                v += buf.map { .init(x: Double($0.x), y: Double($0.y), z: Double($0.z)) }
                if let facesIdx = mesh.triangleIndices {
                    for i in stride(from: 0, to: facesIdx.count, by: 3) {
                        f.append(.init(vertices: [
                            startIndex + Int(facesIdx[i]),
                            startIndex + Int(facesIdx[i+1]),
                            startIndex + Int(facesIdx[i+2])], materialIndex:nil))
                    }
                }
            }
            for child in e.children { recurse(child, &v, &f) }
        }
    }
}

// MARK: - Preview
#Preview("Import Sheets") {
    VStack(spacing: 40) {
        Button("Show Point Cloud Import") {
            SheetPreviewHelper.show(PointCloudImportSheet())
        }
        Button("Show 3-D Model Import") {
            SheetPreviewHelper.show(Model3DImportSheet())
        }
    }
}

// Bare-bones sheet presenter for Xcode previews
private enum SheetPreviewHelper {
    static func show<Sheet:View>(_ sheet: Sheet) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let win   = scene.windows.first,
              let root  = win.rootViewController else { return }
        let vc = UIHostingController(rootView: sheet)
        root.present(vc, animated: true)
    }
}