//
//  ImportSheets.swift
//  Pulto3
//
//  Created by ChatGPT on 2025-07-09
//

import SwiftUI
import UniformTypeIdentifiers
import RealityKit

// MARK: - Point-Cloud Import Sheet
struct PointCloudImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var openImporter = false
    @State private var busy = false
    @State private var importError: FileImportError?

    private let wm = WindowTypeManager.shared            // singleton

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
                     + "columns (and optionally *intensity*).")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button { openImporter = true } label: {
                    Label("Choose File …", systemImage: "folder")
                        .font(.headline)
                        .padding(.horizontal,32).padding(.vertical,12)
                        .background(.purple.opacity(0.15))
                        .cornerRadius(10)
                }
                .disabled(busy)
            }
            .overlay { if busy { ProgressView("Processing…") } }
            .navigationTitle("Import")
            .fileImporter(
                isPresented: $openImporter,
                allowedContentTypes: [.commaSeparatedText, .json],
                allowsMultipleSelection: false
            ) { result in
                guard case let .success(urls) = result, let url = urls.first else {
                    if case let .failure(err) = result {
                        importError = .file(err)
                    }
                    return
                }
                importPointCloud(url)
            }
            .alert("Import Failed",
                   isPresented: Binding(get:{importError != nil},
                                        set:{ _ in importError = nil })) {
                Button("OK",role:.cancel){}
            } message: { Text(importError?.localizedDescription ?? "") }
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() } } }
        }
    }

    private func importPointCloud(_ url: URL) {
        busy = true
        Task.detached(priority: .userInitiated) {
            do {
                let pc = try parsePointCloud(url)
                await MainActor.run {
                    createWindow(for: pc)
                    dismiss()
                }
            } catch {
                await MainActor.run { importError = .file(error) }
            }
            await MainActor.run { busy = false }
        }
    }

    @MainActor
    private func createWindow(for pc: PointCloudData) {
        let newID = wm.getNextWindowID()
        _ = wm.createWindow(.spatial, id: newID)
        wm.updateWindowPointCloud(newID, pointCloud: pc)   // extension below
        wm.markWindowAsOpened(newID)
    }
}

// MARK: - 3-D Model Import Sheet
struct Model3DImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var openImporter = false
    @State private var busy = false
    @State private var importError: FileImportError?

    private let wm = WindowTypeManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "cube.transparent.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.linearGradient(colors: [.orange,.pink],
                                                     startPoint: .topLeading,
                                                     endPoint: .bottomTrailing))

                Text("Import 3-D Model").font(.title2.weight(.semibold))

                Text("Select a **USDZ**, **OBJ**, **STL** or **Model 3-D** file.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button { openImporter = true } label: {
                    Label("Choose File …", systemImage: "folder")
                        .font(.headline)
                        .padding(.horizontal,32).padding(.vertical,12)
                        .background(.orange.opacity(0.15))
                        .cornerRadius(10)
                }
                .disabled(busy)
            }
            .overlay { if busy { ProgressView("Processing…") } }
            .navigationTitle("Import")
            .fileImporter(
                isPresented: $openImporter,
                allowedContentTypes: [.usdz, .model3d, .object, .stl],
                allowsMultipleSelection: false
            ) { result in
                guard case let .success(urls) = result, let url = urls.first else {
                    if case let .failure(err) = result { importError = .file(err) }
                    return
                }
                importModel(url)
            }
            .alert("Import Failed",
                   isPresented: Binding(get:{importError != nil},
                                        set:{ _ in importError = nil })) {
                Button("OK",role:.cancel){}
            } message: { Text(importError?.localizedDescription ?? "") }
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() } } }
        }
    }

    private func importModel(_ url: URL) {
        busy = true
        Task.detached(priority: .userInitiated) {
            do {
                let model = try await parseModel(url)
                await MainActor.run {
                    createWindow(for: model)
                    dismiss()
                }
            } catch { await MainActor.run { importError = .file(error) } }
            await MainActor.run { busy = false }
        }
    }

    @MainActor
    private func createWindow(for model: Model3DData) {
        let newID = wm.getNextWindowID()
        _ = wm.createWindow(.model3d, id: newID)
        wm.updateWindowModel3DData(newID, model3DData: model)
        //wm.updateWindowModel3D(newID, model: model)        // extension below
        wm.markWindowAsOpened(newID)
    }
}

// MARK: - File-import errors
private enum FileImportError: LocalizedError {
    case file(Error), badFormat

    var errorDescription: String? {
        switch self {
        case .file(let err): return err.localizedDescription
        case .badFormat:     return "The selected file isn’t in a supported format."
        }
    }
}

// MARK: - UTType helpers (visionOS SDK lacks these)
private extension UTType {
    static let model3d = UTType(exportedAs: "com.apple.model3d")
    static let object  = UTType(exportedAs: "com.wavefront.obj")
    static let stl     = UTType(exportedAs: "public.stl")
}

// MARK: - Point-cloud parser (CSV / JSON)
private func parsePointCloud(_ url: URL) throws -> PointCloudData {
    let data = try Data(contentsOf: url)

    if url.pathExtension.lowercased() == "json" {
        struct Row: Decodable { var x:Double; var y:Double; var z:Double; var intensity:Double? }
        let rows = try JSONDecoder().decode([Row].self, from: data)
        var pc = PointCloudData(title: url.lastPathComponent, demoType: "json-import")
        pc.points = rows.map { .init(x:$0.x, y:$0.y, z:$0.z, intensity:$0.intensity) }
        pc.totalPoints = pc.points.count
        return pc
    }

    guard let txt = String(data: data, encoding: .utf8) else { throw FileImportError.badFormat }
    var pc = PointCloudData(title: url.lastPathComponent, demoType: "csv-import")
    for line in txt.split(whereSeparator: \.isNewline) {
        let nums = line.split(separator: ",").compactMap { Double($0) }
        guard nums.count >= 3 else { continue }
        pc.points.append(.init(x: nums[0], y: nums[1], z: nums[2],
                               intensity: nums.count > 3 ? nums[3] : nil))
    }
    pc.totalPoints = pc.points.count
    if pc.totalPoints == 0 { throw FileImportError.badFormat }
    return pc
}

// MARK: - Very lightweight model importer
private func parseModel(_ url: URL) async throws -> Model3DData {
    switch url.pathExtension.lowercased() {
    case "usdz":
        return Model3DData(title:url.lastPathComponent, modelType:"usdz")
    case "obj":
        return Model3DData(title:url.lastPathComponent, modelType:"obj")
    case "stl":
        return Model3DData(title:url.lastPathComponent, modelType:"stl")
    default:
        throw FileImportError.badFormat
    }
}

#Preview("Point Cloud Import Sheet") {
    PointCloudImportSheet()
}

#Preview("3D Model Import Sheet") {
    Model3DImportSheet()
}