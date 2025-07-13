//
//  Model3DImportView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/9/25.
//  Copyright 2025 Apple. All rights reserved.
//

import SwiftUI
import RealityKit
import UniformTypeIdentifiers

struct Model3DImportView: View {
    @Binding var isPresented: Bool
    @ObservedObject var windowManager: WindowTypeManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var importMode: ImportMode = .file
    @State private var selectedFiles: [ModelFile] = []
    @State private var modelURL: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingFilePicker = false
    @State private var previewModel: Model3DData?
    @State private var createAsVolumetric = true
    @State private var modelTitle: String = ""
    @State private var modelDescription: String = ""
    @State private var selectedPosition: WindowPosition = WindowPosition(
        x: 0, y: 0, z: -100, width: 800, height: 600
    )

    enum ImportMode: String, CaseIterable {
        case file = "Local Files"
        case url = "URL"
        case generate = "Generate"

        var icon: String {
            switch self {
            case .file: return "doc.on.doc"
            case .url: return "link"
            case .generate: return "wand.and.stars"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView

                Picker("Import Mode", selection: $importMode) {
                    ForEach(ImportMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                TabView(selection: $importMode) {
                    fileImportView.tag(ImportMode.file)
                    urlImportView.tag(ImportMode.url)
                    generateModelView.tag(ImportMode.generate)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                if let preview = previewModel {
                    modelPreviewView(preview)
                }

                if let error = errorMessage {
                    errorView(error)
                }

                Spacer()

                createModelWindowView
            }
            .navigationTitle("Import 3D Model")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(createAsVolumetric ? "Create Volumetric" : "Create Window") {
                        createModelWindow()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(previewModel == nil || modelTitle.isEmpty)
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.usdz, .realityFile, UTType.data],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cube.transparent.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)

            VStack(spacing: 4) {
                Text("Import 3D Model")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create volumetric windows with interactive 3D models")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top)
    }

    // MARK: - File Import View

    private var fileImportView: some View {
        VStack(spacing: 20) {
            Text("Select 3D Model Files")
                .font(.headline)

            Text("Supported formats: USDZ, Reality, and other compatible files")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Choose Files") {
                showingFilePicker = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if !selectedFiles.isEmpty {
                selectedFilesView
            }
        }
        .padding()
    }

    // MARK: - URL Import View

    private var urlImportView: some View {
        VStack(spacing: 20) {
            Text("Load from URL")
                .font(.headline)

            Text("Enter a URL to a 3D model file")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("Model URL:")
                    .font(.callout)
                    .fontWeight(.medium)

                TextField("https://example.com/model.usdz", text: $modelURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            Button("Load Model") {
                Task {
                    await loadModelFromURL()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(modelURL.isEmpty)
            .controlSize(.large)
        }
        .padding()
    }

    // MARK: - Generate Model View

    private var generateModelView: some View {
        VStack(spacing: 20) {
            Text("Generate 3D Model")
                .font(.headline)

            Text("Create procedural 3D models")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button("Generate Sphere") { generateSphere() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                Button("Generate Cube") { generateCube() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
        .padding()
    }

    // MARK: - Selected Files View

    private var selectedFilesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Files:")
                .font(.headline)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(selectedFiles) { file in
                        HStack {
                            Image(systemName: "cube.transparent")
                                .foregroundStyle(.blue)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(.body)
                                    .fontWeight(.medium)

                                Text(file.formattedSize)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Preview") {
                                loadModelPreview(file)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(8)
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Model Preview View

    private func modelPreviewView(_ model: Model3DData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Model Preview", systemImage: "viewfinder")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title: \(model.title)")
                    .font(.body)
                    .fontWeight(.medium)

                Text("Type: \(model.modelType)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Vertices: \(model.vertices.count)")
                    Spacer()
                    Text("Faces: \(model.faces.count)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            RealityView { content in
                let sphere = ModelEntity(mesh: .generateSphere(radius: 0.1))
                content.add(sphere)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Import Error")
                .font(.headline)

            Text(error)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Create Model Window View

    private var createModelWindowView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Model Details")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Title:")
                        .font(.callout)
                        .fontWeight(.medium)

                    TextField("Enter model title", text: $modelTitle)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Description:")
                        .font(.callout)
                        .fontWeight(.medium)

                    TextField("Enter model description", text: $modelDescription)
                        .textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Window Configuration")
                    .font(.headline)

                Toggle("Create as Volumetric Window", isOn: $createAsVolumetric)
                    .toggleStyle(.switch)

                HStack {
                    Image(systemName: createAsVolumetric ? "cube.fill" : "rectangle.on.rectangle")
                        .foregroundStyle(createAsVolumetric ? .blue : .secondary)

                    Text(createAsVolumetric ?
                         "Model will be displayed in an immersive 3D space" :
                         "Model will be displayed in a regular window")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 20)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Methods

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedFiles = urls.compactMap { url in
                guard let rv = try? url.resourceValues(forKeys: [.fileSizeKey, .nameKey]) else { return nil }
                return ModelFile(url: url, name: rv.name ?? url.lastPathComponent, size: Int64(rv.fileSize ?? 0))
            }
            if let first = selectedFiles.first {
                loadModelPreview(first)
            }
        case .failure(let err):
            errorMessage = err.localizedDescription
        }
    }

    private func loadModelFromURL() async {
        isLoading = true
        errorMessage = nil
        defer { Task { @MainActor in isLoading = false } }
        do {
            guard let url = URL(string: modelURL) else { throw ModelImportError.invalidURL }
            let model3D = try await createModel3DFromURL(url)
            await MainActor.run { previewModel = model3D; modelTitle = url.lastPathComponent }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func loadModelPreview(_ file: ModelFile) {
        Task {
            do {
                let model3D = try await createModel3DFromFile(file)
                await MainActor.run { previewModel = model3D; modelTitle = file.name }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func generateSphere() {
        previewModel = Model3DData.generateSphere(radius: 2.0, segments: 32)
        modelTitle     = "Generated Sphere"
    }

    private func generateCube() {
        previewModel = Model3DData.generateCube(size: 2.0)
        modelTitle   = "Generated Cube"
    }

    private func createModelWindow() {
        guard let model3D = previewModel else { return }
        Task { @MainActor in
            let manager = windowManager
            let windowID = manager.getNextWindowID()
            if createAsVolumetric {
                await createVolumetricWindow(model3D)
            } else {
                createRegularWindow(model3D)
            }
            isPresented = false
        }
    }

    @MainActor
    private func createVolumetricWindow(_ model3D: Model3DData) async {
        let manager = windowManager
        let windowID = manager.getNextWindowID()
        _ = manager.createWindow(.model3d, id: windowID, position: selectedPosition)
        manager.updateWindowModel3DData(windowID, model3DData: model3D)
        manager.updateWindowContent(windowID, content: modelDescription)
        openWindow(value: windowID)
        await openImmersiveSpace(id: "model3d-\(windowID)")
    }

    @MainActor
    private func createRegularWindow(_ model3D: Model3DData) {
        let manager = windowManager
        let windowID = manager.getNextWindowID()
        _ = manager.createWindow(.model3d, id: windowID, position: selectedPosition)
        manager.updateWindowModel3DData(windowID, model3DData: model3D)
        manager.updateWindowContent(windowID, content: modelDescription)
        openWindow(value: windowID)
    }

    private func createModel3DFromURL(_ url: URL) async throws -> Model3DData {
        Model3DData(title: url.lastPathComponent, modelType: "imported")
    }

    private func createModel3DFromFile(_ file: ModelFile) async throws -> Model3DData {
        Model3DData(title: file.name, modelType: "imported")
    }
}

// MARK: - Preview

#Preview {
    Model3DImportView(
        isPresented: .constant(true),
        windowManager: WindowTypeManager.shared
    )
}