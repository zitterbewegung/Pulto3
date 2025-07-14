//
//  Model3DImportView.swift
//  Pulto3
//
//  Enhanced 3D Model Import with comprehensive format support
//

import SwiftUI
import RealityKit
import UniformTypeIdentifiers
import SceneKit

struct Model3DImportView: View {
    @Binding var isPresented: Bool
    @ObservedObject var windowManager: WindowTypeManager
    @Environment(\.openWindow) private var openWindow
    
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
    @State private var importProgress: Double = 0.0
    @State private var processingStatus: String = ""
    @State private var selectedPosition: WindowPosition = WindowPosition(
        x: 0, y: 0, z: -100, width: 800, height: 600
    )
    
    enum ImportMode: String, CaseIterable {
        case file = "Local Files"
        case url = "URL"
        case generate = "Generate"
        case samples = "Sample Models"
        
        var icon: String {
            switch self {
            case .file: return "doc.on.doc"
            case .url: return "link"
            case .generate: return "wand.and.stars"
            case .samples: return "cube.transparent"
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
                    sampleModelsView.tag(ImportMode.samples)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                if isLoading {
                    loadingView
                }
                
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
            allowedContentTypes: Model3DImporter.supportedTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cube.transparent.fill")
                .font(.system(size: 50))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
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
        ScrollView {
            VStack(spacing: 20) {
                Text("Select 3D Model Files")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    Text("Supported formats:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(Model3DImporter.SupportedFormat.allCases) { format in
                            formatBadge(format)
                        }
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
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
    }
    
    // MARK: - URL Import View
    
    private var urlImportView: some View {
        ScrollView {
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
                
                VStack(spacing: 12) {
                    Button("Load Model") {
                        Task {
                            await loadModelFromURL()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(modelURL.isEmpty || isLoading)
                    .controlSize(.large)
                    
                    Text("Example URLs:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        sampleURLButton("Apple TV USDZ", "https://developer.apple.com/augmented-reality/quick-look/models/cupandsaucer/cup_saucer_set.usdz")
                        sampleURLButton("Toy Robot USDZ", "https://developer.apple.com/augmented-reality/quick-look/models/toyrobot/toy_robot_vintage.usdz")
                    }
                    .font(.caption)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Generate Model View
    
    private var generateModelView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Generate 3D Model")
                    .font(.headline)
                
                Text("Create procedural 3D models")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    generateButton("Sphere", "sphere.fill", .blue) { generateSphere() }
                    generateButton("Cube", "cube.fill", .orange) { generateCube() }
                    generateButton("Cylinder", "cylinder.fill", .green) { 
                        previewModel = Model3DData.generateCylinder(radius: 1.0, height: 2.0, segments: 24)
                        modelTitle = "Generated Cylinder"
                        modelDescription = "Procedurally generated cylinder"
                    }
                    generateButton("Torus", "circle.fill", .purple) { generateTorus() }
                    generateButton("Pyramid", "triangle.fill", .red) { generatePyramid() }
                    generateButton("Complex", "gear", .pink) { generateComplexShape() }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Sample Models View
    
    private var sampleModelsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Sample Models")
                    .font(.headline)
                
                Text("Pre-built models for testing and demonstration")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    sampleModelCard("Stanford Bunny", "rabbit.fill", .brown, "Classic test model") {
                        generateStanfordBunny()
                    }
                    sampleModelCard("Utah Teapot", "cup.and.saucer.fill", .blue, "Traditional 3D reference") {
                        generateUtahTeapot()
                    }
                    sampleModelCard("Suzanne", "face.smiling", .orange, "Blender's mascot") {
                        generateSuzanne()
                    }
                    sampleModelCard("Stanford Dragon", "lizard.fill", .green, "High-poly model") {
                        generateStanfordDragon()
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView(value: importProgress, total: 1.0)
                .progressViewStyle(.linear)
                .frame(width: 200)
            
            Text(processingStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                                    .lineLimit(1)
                                
                                HStack {
                                    Text("File Size: \(file.formattedSize)")
                                    Text("Format: \(file.url.pathExtension.uppercased())")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Preview") {
                                loadModelPreview(file)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(isLoading)
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
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Model Preview View
    
    private func modelPreviewView(_ model: Model3DData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Model Preview", systemImage: "viewfinder")
                .font(.headline)
            
            HStack {
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
                    
                    if !model.materials.isEmpty {
                        Text("Materials: \(model.materials.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // 3D Preview
                RealityView { content in
                    if let previewEntity = createPreviewEntity(from: model) {
                        content.add(previewEntity)
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.quaternary, lineWidth: 1)
                )
            }
        }
        .padding()
        .background(.regularMaterial)
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
            
            Button("Clear") {
                errorMessage = nil
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.regularMaterial)
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
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Views
    
    private func formatBadge(_ format: Model3DImporter.SupportedFormat) -> some View {
        Text(format.rawValue.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(format.color.opacity(0.2))
            .foregroundStyle(format.color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private func sampleURLButton(_ title: String, _ url: String) -> some View {
        Button(title) {
            modelURL = url
        }
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
    }
    
    private func generateButton(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
    
    private func sampleModelCard(_ title: String, _ icon: String, _ color: Color, _ description: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
    
    // MARK: - Helper Methods
    
    private func createPreviewEntity(from model: Model3DData) -> Entity? {
        let entity = Entity()
        
        // Create a simple preview based on model type
        switch model.modelType.lowercased() {
        case "sphere":
            let mesh = MeshResource.generateSphere(radius: 0.05)
            let material = SimpleMaterial(color: .blue, isMetallic: false)
            let modelEntity = ModelEntity(mesh: mesh, materials: [material])
            entity.addChild(modelEntity)
        case "cube":
            let mesh = MeshResource.generateBox(size: 0.08)
            let material = SimpleMaterial(color: .orange, isMetallic: false)
            let modelEntity = ModelEntity(mesh: mesh, materials: [material])
            entity.addChild(modelEntity)
        default:
            // Default sphere for other models
            let mesh = MeshResource.generateSphere(radius: 0.05)
            let material = SimpleMaterial(color: .gray, isMetallic: false)
            let modelEntity = ModelEntity(mesh: mesh, materials: [material])
            entity.addChild(modelEntity)
        }
        
        return entity
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedFiles = urls.compactMap { url in
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey])
                    let name = resourceValues.name ?? url.lastPathComponent
                    let size = Int64(resourceValues.fileSize ?? 0)
                    return ModelFile(url: url, name: name, size: size)
                } catch {
                    return nil
                }
            }
            if let first = selectedFiles.first {
                loadModelPreview(first)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    private func loadModelFromURL() async {
        isLoading = true
        processingStatus = "Downloading model..."
        importProgress = 0.2
        errorMessage = nil
        
        defer {
            Task { @MainActor in
                isLoading = false
                processingStatus = ""
                importProgress = 0.0
            }
        }
        
        do {
            guard let url = URL(string: modelURL) else {
                throw Model3DImporter.ImportError.invalidURL
            }
            
            await MainActor.run {
                processingStatus = "Processing model..."
                importProgress = 0.6
            }
            
            let model3D = try await Model3DImporter.importFromURL(url) { progress in
                Task { @MainActor in
                    importProgress = progress
                }
            }
            
            await MainActor.run {
                previewModel = model3D
                modelTitle = url.lastPathComponent
                processingStatus = "Complete!"
                importProgress = 1.0
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func loadModelPreview(_ file: ModelFile) {
        guard !isLoading else { return }
        
        Task {
            isLoading = true
            processingStatus = "Loading \(file.name)..."
            importProgress = 0.3
            
            do {
                let model3D = try await Model3DImporter.importFromFile(file) { progress in
                    Task { @MainActor in
                        importProgress = progress
                    }
                }
                
                await MainActor.run {
                    previewModel = model3D
                    modelTitle = file.name
                    errorMessage = nil
                    processingStatus = "Complete!"
                    importProgress = 1.0
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            
            await MainActor.run {
                isLoading = false
                processingStatus = ""
                importProgress = 0.0
            }
        }
    }
    
    // MARK: - Generation Methods
    
    private func generateSphere() {
        previewModel = Model3DData.generateSphere(radius: 2.0, segments: 32)
        modelTitle = "Generated Sphere"
        modelDescription = "Procedurally generated sphere with 32 segments"
    }
    
    private func generateCube() {
        previewModel = Model3DData.generateCube(size: 2.0)
        modelTitle = "Generated Cube"
        modelDescription = "Procedurally generated cube with 2.0 unit sides"
    }
    
    private func generateTorus() {
        previewModel = Model3DData.generateTorus(majorRadius: 2.0, minorRadius: 0.5, segments: 24)
        modelTitle = "Generated Torus"
        modelDescription = "Procedurally generated torus (donut shape)"
    }
    
    private func generatePyramid() {
        previewModel = Model3DData.generatePyramid(baseSize: 2.0, height: 2.0)
        modelTitle = "Generated Pyramid"
        modelDescription = "Procedurally generated pyramid"
    }
    
    private func generateComplexShape() {
        previewModel = Model3DData.generateComplexShape()
        modelTitle = "Generated Complex Shape"
        modelDescription = "Procedurally generated complex geometric shape"
    }
    
    private func generateStanfordBunny() {
        previewModel = Model3DData.generateStanfordBunny()
        modelTitle = "Stanford Bunny"
        modelDescription = "Classic computer graphics test model"
    }
    
    private func generateUtahTeapot() {
        previewModel = Model3DData.generateUtahTeapot()
        modelTitle = "Utah Teapot"
        modelDescription = "Traditional 3D graphics reference model"
    }
    
    private func generateSuzanne() {
        previewModel = Model3DData.generateSuzanne()
        modelTitle = "Suzanne"
        modelDescription = "Blender's monkey mascot"
    }
    
    private func generateStanfordDragon() {
        previewModel = Model3DData.generateStanfordDragon()
        modelTitle = "Stanford Dragon"
        modelDescription = "High-polygon test model"
    }
    
    private func createModelWindow() {
        guard let model3D = previewModel else { return }
        
        Task { @MainActor in
            let manager = windowManager
            let windowID = manager.getNextWindowID()
            
            if createAsVolumetric {
                await createVolumetricWindow(model3D, windowID: windowID)
            } else {
                createRegularWindow(model3D, windowID: windowID)
            }
            
            isPresented = false
        }
    }
    
    @MainActor
    private func createVolumetricWindow(_ model3D: Model3DData, windowID: Int) async {
        let manager = windowManager
        _ = manager.createWindow(.model3d, id: windowID, position: selectedPosition)
        manager.updateWindowModel3DData(windowID, model3DData: model3D)
        manager.updateWindowContent(windowID, content: modelDescription)
        manager.addWindowTag(windowID, tag: "Imported-3D")
        manager.markWindowAsOpened(windowID)
        
        // Open volumetric window
        openWindow(id: "volumetric-model3d", value: windowID)
    }
    
    @MainActor
    private func createRegularWindow(_ model3D: Model3DData, windowID: Int) {
        let manager = windowManager
        _ = manager.createWindow(.model3d, id: windowID, position: selectedPosition)
        manager.updateWindowModel3DData(windowID, model3DData: model3D)
        manager.updateWindowContent(windowID, content: modelDescription)
        manager.addWindowTag(windowID, tag: "Imported-3D")
        manager.markWindowAsOpened(windowID)
        
        // Open regular window
        openWindow(value: windowID)
    }
}

// MARK: - Preview

#Preview {
    Model3DImportView(
        isPresented: .constant(true),
        windowManager: WindowTypeManager.shared
    )
}