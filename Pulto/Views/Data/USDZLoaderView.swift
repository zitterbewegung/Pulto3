import SwiftUI
import RealityKit
import UniformTypeIdentifiers

struct USDZLoaderView: View {
    @Binding var isPresented: Bool
    let windowID: Int
    @ObservedObject var windowManager: WindowTypeManager
    @Environment(\.openWindow) private var openWindow
    
    @State private var importMode: ImportMode = .file
    @State private var selectedFiles: [ModelFile] = []
    @State private var modelURL: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingFilePicker = false
    @State private var previewModel: Model3DData?
    @State private var modelTitle: String = ""
    @State private var modelDescription: String = ""
    @State private var importSuccess = false
    
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
                
                if importSuccess {
                    successView
                }
                
                Spacer()
                
                actionButtonsView
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
                    Button("Import & Open Volumetric") {
                        importAndOpenVolumetric()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(previewModel == nil || isLoading)
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
                
                Text("Load USDZ files or generate 3D models for volumetric display")
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
            
            Text("Supported formats: USDZ, Reality files, and other compatible formats")
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
            .disabled(modelURL.isEmpty || isLoading)
            .controlSize(.large)
            
            if isLoading {
                ProgressView("Loading...")
                    .padding()
            }
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
                Button("Generate Sphere") { 
                    generateSphere() 
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Generate Cube") { 
                    generateCube() 
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Generate Complex Model") { 
                    generateComplexModel() 
                }
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
                HStack {
                    Text("Title:")
                        .fontWeight(.medium)
                    TextField("Enter model title", text: $modelTitle)
                        .textFieldStyle(.roundedBorder)
                }
                
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
            
            // Simple 3D preview
            RealityView { content in
                let sphere = ModelEntity(mesh: .generateSphere(radius: 0.1))
                var material = SimpleMaterial()
                material.color = .init(tint: .blue)
                sphere.model?.materials = [material]
                content.add(sphere)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
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
                
            Button("Dismiss") {
                errorMessage = nil
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Success View
    
    private var successView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            
            Text("Import Successful!")
                .font(.headline)
            
            Text("Your 3D model has been imported and is ready for volumetric display.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            if let model = previewModel {
                Button("Save Model to Window") {
                    saveModelToWindow(model)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                
                Button("Import & Open Volumetric View") {
                    importAndOpenVolumetric()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(isLoading)
            }
        }
        .padding()
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
            guard let url = URL(string: modelURL) else { 
                throw ModelImportError.invalidURL 
            }
            
            let model3D = try await createModel3DFromURL(url)
            await MainActor.run { 
                previewModel = model3D
                modelTitle = url.lastPathComponent
            }
        } catch {
            await MainActor.run { 
                errorMessage = error.localizedDescription 
            }
        }
    }
    
    private func loadModelPreview(_ file: ModelFile) {
        Task {
            do {
                let model3D = try await createModel3DFromFile(file)
                await MainActor.run { 
                    previewModel = model3D
                    modelTitle = file.name
                }
            } catch {
                await MainActor.run { 
                    errorMessage = error.localizedDescription 
                }
            }
        }
    }
    
    private func generateSphere() {
        previewModel = Model3DData.generateSphere(radius: 2.0, segments: 32)
        modelTitle = "Generated Sphere"
        errorMessage = nil
    }
    
    private func generateCube() {
        previewModel = Model3DData.generateCube(size: 2.0)
        modelTitle = "Generated Cube"
        errorMessage = nil
    }
    
    private func generateComplexModel() {
        // Generate a more complex model (e.g., a torus-like shape)
        var model = Model3DData(title: "Complex Model", modelType: "generated")
        
        // Generate vertices for a simple torus
        let majorRadius = 2.0
        let minorRadius = 0.8
        let majorSegments = 16
        let minorSegments = 8
        
        for i in 0..<majorSegments {
            let majorAngle = Double(i) * 2.0 * .pi / Double(majorSegments)
            for j in 0..<minorSegments {
                let minorAngle = Double(j) * 2.0 * .pi / Double(minorSegments)
                
                let x = (majorRadius + minorRadius * cos(minorAngle)) * cos(majorAngle)
                let y = minorRadius * sin(minorAngle)
                let z = (majorRadius + minorRadius * cos(minorAngle)) * sin(majorAngle)
                
                model.vertices.append(Model3DData.Vertex3D(x: x, y: y, z: z))
            }
        }
        
        // Generate faces
        for i in 0..<majorSegments {
            for j in 0..<minorSegments {
                let current = i * minorSegments + j
                let next = i * minorSegments + (j + 1) % minorSegments
                let nextMajor = ((i + 1) % majorSegments) * minorSegments + j
                let nextBoth = ((i + 1) % majorSegments) * minorSegments + (j + 1) % minorSegments
                
                model.faces.append(Model3DData.Face3D(vertices: [current, next, nextBoth, nextMajor], materialIndex: 0))
            }
        }
        
        model.materials = [
            Model3DData.Material3D(name: "default", color: "purple", metallic: 0.2, roughness: 0.3, transparency: 0.0)
        ]
        
        previewModel = model
        modelTitle = "Generated Torus"
        errorMessage = nil
    }
    
    private func saveModelToWindow(_ model: Model3DData) {
        // Update the window with the model data
        var updatedModel = model
        updatedModel.title = modelTitle.isEmpty ? model.title : modelTitle
        
        windowManager.updateWindowModel3D(windowID, modelData: updatedModel)
        windowManager.updateWindowContent(windowID, content: modelDescription)
        windowManager.addWindowTag(windowID, tag: "Imported-3D")
        
        importSuccess = true
        
        // Save USDZ bookmark if we have a file
        if let file = selectedFiles.first {
            Task {
                do {
                    let bookmark = try file.url.bookmarkData()
                    await MainActor.run {
                        windowManager.updateUSDZBookmark(for: windowID, bookmark: bookmark)
                    }
                } catch {
                    print("Failed to create bookmark: \(error)")
                }
            }
        }
    }
    
    private func importAndOpenVolumetric() {
        guard let model = previewModel else { return }
        
        saveModelToWindow(model)
        
        // Close this import view
        isPresented = false
        
        // Open the volumetric window
        openWindow(id: "volumetric-model3d", value: windowID)
    }
    
    private func createModel3DFromURL(_ url: URL) async throws -> Model3DData {
        // Create a placeholder model from URL
        // In a real implementation, you would download and parse the file
        var model = Model3DData(title: url.lastPathComponent, modelType: "usdz")
        
        // Add some basic geometry as placeholder
        model.vertices = [
            Model3DData.Vertex3D(x: -1, y: -1, z: -1),
            Model3DData.Vertex3D(x: 1, y: -1, z: -1),
            Model3DData.Vertex3D(x: 1, y: 1, z: -1),
            Model3DData.Vertex3D(x: -1, y: 1, z: -1)
        ]
        model.faces = [
            Model3DData.Face3D(vertices: [0, 1, 2, 3], materialIndex: 0)
        ]
        model.materials = [
            Model3DData.Material3D(name: "default", color: "blue", metallic: 0.1, roughness: 0.5, transparency: 0.0)
        ]
        
        return model
    }
    
    private func createModel3DFromFile(_ file: ModelFile) async throws -> Model3DData {
        // Create model data from file
        // In a real implementation, you would parse the actual file
        var model = Model3DData(title: file.name, modelType: file.url.pathExtension.lowercased())
        
        // Add placeholder geometry
        model.vertices = [
            Model3DData.Vertex3D(x: -1, y: -1, z: -1),
            Model3DData.Vertex3D(x: 1, y: -1, z: -1),
            Model3DData.Vertex3D(x: 1, y: 1, z: -1),
            Model3DData.Vertex3D(x: -1, y: 1, z: -1),
            Model3DData.Vertex3D(x: -1, y: -1, z: 1),
            Model3DData.Vertex3D(x: 1, y: -1, z: 1),
            Model3DData.Vertex3D(x: 1, y: 1, z: 1),
            Model3DData.Vertex3D(x: -1, y: 1, z: 1)
        ]
        
        // Create cube faces
        model.faces = [
            Model3DData.Face3D(vertices: [0, 1, 2, 3], materialIndex: 0), // front
            Model3DData.Face3D(vertices: [4, 7, 6, 5], materialIndex: 0), // back
            Model3DData.Face3D(vertices: [0, 4, 5, 1], materialIndex: 0), // bottom
            Model3DData.Face3D(vertices: [2, 6, 7, 3], materialIndex: 0), // top
            Model3DData.Face3D(vertices: [0, 3, 7, 4], materialIndex: 0), // left
            Model3DData.Face3D(vertices: [1, 5, 6, 2], materialIndex: 0)  // right
        ]
        
        model.materials = [
            Model3DData.Material3D(name: "default", color: "orange", metallic: 0.2, roughness: 0.4, transparency: 0.0)
        ]
        
        return model
    }
}

// MARK: - Supporting Types

struct ModelFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

enum ModelImportError: LocalizedError {
    case invalidURL, unsupportedFormat, fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The provided URL is not valid."
        case .unsupportedFormat: return "The model format is not supported."
        case .fileNotFound: return "Could not locate that file."
        }
    }
}

// MARK: - Preview

#Preview {
    USDZLoaderView(
        isPresented: .constant(true),
        windowID: 1,
        windowManager: WindowTypeManager.shared
    )
}