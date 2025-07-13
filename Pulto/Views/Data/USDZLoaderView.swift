import SwiftUI
import RealityKit
import UniformTypeIdentifiers
import ModelIO
import SceneKit

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
        case url = "URL/Path"
        case generate = "Generate"
        
        var icon: String {
            switch self {
            case .file: return "folder"
            case .url: return "link"
            case .generate: return "plus.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            headerView
            
            Picker("Import Mode", selection: $importMode) {
                ForEach(ImportMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            Group {
                switch importMode {
                case .file:
                    fileImportView
                case .url:
                    urlImportView
                case .generate:
                    generateModelView
                }
            }
            .frame(minHeight: 200)
            
            if let error = errorMessage {
                errorView(error)
            }
            
            if importSuccess {
                successView
            }
            
            if let preview = previewModel {
                modelPreviewView(preview)
            }
            
            Spacer()
            
            actionButtonsView
        }
        .padding()
        .frame(width: 600, height: 700)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: Model3DImporter.supportedContentTypes,
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
                
                Text("Support for USDZ, USD, glTF, OBJ, FBX, STL, PLY, DAE and more")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Format support indicator
            VStack(spacing: 8) {
                Text("Supported Formats:")
                    .font(.caption)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 4) {
                    ForEach(Model3DImporter.SupportedFormat.allCases, id: \.self) { format in
                        Text(format.rawValue.uppercased())
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(format.isNativelySupported ? .green.opacity(0.2) : .orange.opacity(0.2))
                            .foregroundStyle(format.isNativelySupported ? .green : .orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .padding()
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Quick status indicator
            if let preview = previewModel {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Model loaded: \(preview.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.top)
    }
    
    // MARK: - File Import View
    
    private var fileImportView: some View {
        VStack(spacing: 20) {
            Text("Select 3D Model Files")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Supported formats:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(Model3DImporter.SupportedFormat.allCases, id: \.self) { format in
                        HStack(spacing: 4) {
                            Image(systemName: format.isNativelySupported ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                                .foregroundStyle(format.isNativelySupported ? .green : .orange)
                                .font(.caption)
                            
                            Text(".\(format.rawValue)")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            if !format.isNativelySupported {
                                Text("(convert)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Load from URL or File Path:")
                .font(.callout)
                .fontWeight(.medium)
            
            HStack {
                TextField("https://example.com/model.usdz or file:///path/to/model.obj", text: $modelURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button("Paste") {
                    if let clipboardString = getClipboardContent() {
                        modelURL = clipboardString
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
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
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading and analyzing model...")
                        .font(.subheadline)
                }
                .padding()
            }
            
            Text("Supported formats: USDZ, USD, glTF, GLB, OBJ, FBX, STL, PLY, DAE")
                .font(.caption2)
                .foregroundStyle(.secondary)
                
            // Quick access buttons for common files
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Access:")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Button("Load Pluto Model (Bundle)") {
                    modelURL = getPultoFilePath()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top)
        }
        .padding()
    }
    
    // MARK: - Generate Model View
    
    private var generateModelView: some View {
        VStack(spacing: 20) {
            Text("Generate 3D Model")
                .font(.headline)
            
            Text("Create procedural 3D models for testing and visualization")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                Button("Sphere") { 
                    generateSphere() 
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Cube") { 
                    generateCube() 
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Torus") { 
                    generateComplexModel() 
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Icosphere") {
                    generateIcosphere()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Cylinder") {
                    generateCylinder()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Pyramid") {
                    generatePyramid()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding()
    }
    
    // MARK: - Selected Files View
    
    private var selectedFilesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Files:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            ForEach(selectedFiles) { file in
                HStack {
                    let format = Model3DImporter.getFormatInfo(for: file.url)
                    Image(systemName: format.icon)
                        .foregroundStyle(format.isNativelySupported ? .green : .orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.name)
                            .font(.subheadline)
                        Text(file.formattedSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if !format.isNativelySupported {
                            Text("Will be converted to 3D representation")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Remove") {
                        selectedFiles.removeAll { $0.id == file.id }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Model Preview View
    
    private func modelPreviewView(_ model: Model3DData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Preview")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Title:")
                            .fontWeight(.medium)
                        TextField("Enter model title", text: $modelTitle)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Text("Type: \(model.modelType.uppercased())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("Vertices: \(model.vertices.count)")
                        Spacer()
                        Text("Faces: \(model.faces.count)")
                        Spacer()
                        Text("Materials: \(model.materials.count)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 3D preview representation
                VStack {
                    RealityView { content in
                        let sphere = ModelEntity(mesh: .generateSphere(radius: 0.08))
                        var material = SimpleMaterial()
                        material.color = .init(tint: .blue)
                        sphere.model?.materials = [material]
                        content.add(sphere)
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    
                    Text("Preview")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
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
            
            if error.contains("not found") || error.contains("fileNotFound") {
                VStack(spacing: 8) {
                    Text("Troubleshooting Tips:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Make sure the file path is correct")
                        Text("• Try using the file browser instead")
                        Text("• For non-USDZ files, conversion will be attempted")
                        Text("• For URLs, ensure the file is publicly accessible")
                        Text("• Check that the file format is supported")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
                
            HStack(spacing: 12) {
                Button("Try File Browser") {
                    errorMessage = nil
                    showingFilePicker = true
                }
                .buttonStyle(.bordered)
                
                Button("Dismiss") {
                    errorMessage = nil
                }
                .buttonStyle(.bordered)
            }
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
        .background(.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            Button("Cancel") {
                isPresented = false
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            if let _ = previewModel {
                Button("Import & View in 3D") {
                    importAndOpenVolumetric()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
    
    // MARK: - File Handling
    
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
            
            let model3D: Model3DData
            
            if url.isFileURL {
                let fileManager = FileManager.default
                guard fileManager.fileExists(atPath: url.path) else {
                    throw ModelImportError.fileNotFound
                }
                
                let fileSize = try fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
                let file = ModelFile(url: url, name: url.lastPathComponent, size: fileSize)
                model3D = try await Model3DImporter.createModel3DFromFile(file)
            } else {
                model3D = try await downloadAndCreateModel(from: url)
            }
            
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
    
    private func downloadAndCreateModel(from url: URL) async throws -> Model3DData {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw ModelImportError.invalidURL
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension)
        
        try data.write(to: tempURL)
        
        let file = ModelFile(url: tempURL, name: url.lastPathComponent, size: Int64(data.count))
        
        let model = try await Model3DImporter.createModel3DFromFile(file)
        
        try? FileManager.default.removeItem(at: tempURL)
        
        return model
    }
    
    private func loadModelPreview(_ file: ModelFile) {
        Task {
            do {
                let model3D = try await Model3DImporter.createModel3DFromFile(file)
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
    
    private func generateIcosphere() {
        previewModel = Model3DData.generateIcosphere(radius: 2.0, subdivisions: 2)
        modelTitle = "Generated Icosphere"
        errorMessage = nil
    }
    
    private func generateCylinder() {
        previewModel = Model3DData.generateCylinder(radius: 1.0, height: 3.0, segments: 16)
        modelTitle = "Generated Cylinder"
        errorMessage = nil
    }
    
    private func generatePyramid() {
        previewModel = Model3DData.generatePyramid(size: 2.0)
        modelTitle = "Generated Pyramid"
        errorMessage = nil
    }
    
    private func generateComplexModel() {
        var model = Model3DData(title: "Torus", modelType: "generated")
        
        let majorRadius = 2.0
        let minorRadius = 0.8
        let majorSegments = 24
        let minorSegments = 12
        
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
        
        for i in 0..<majorSegments {
            for j in 0..<minorSegments {
                let current = i * minorSegments + j
                let next = i * minorSegments + (j + 1) % minorSegments
                let nextMajor = ((i + 1) % majorSegments) * minorSegments + j
                let nextBoth = ((i + 1) % majorSegments) * minorSegments + (j + 1) % minorSegments
                
                model.faces.append(Model3DData.Face3D(vertices: [current, next, nextBoth], materialIndex: 0))
                model.faces.append(Model3DData.Face3D(vertices: [current, nextBoth, nextMajor], materialIndex: 0))
            }
        }
        
        model.materials = [
            Model3DData.Material3D(name: "torus_material", color: "purple", metallic: 0.2, roughness: 0.3, transparency: 0.0)
        ]
        
        previewModel = model
        modelTitle = "Generated Torus"
        errorMessage = nil
    }
    
    private func saveModelToWindow(_ model: Model3DData) {
        var updatedModel = model
        updatedModel.title = modelTitle.isEmpty ? model.title : modelTitle
        
        windowManager.updateWindowModel3D(windowID, modelData: updatedModel)
        windowManager.updateWindowContent(windowID, content: modelDescription)
        windowManager.addWindowTag(windowID, tag: "Imported-3D")
        
        importSuccess = true
        
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
        
        isPresented = false
        
        openWindow(id: "volumetric-model3d", value: windowID)
    }
    
    // MARK: - Helper Methods
    
    private func localPultoFileExists() -> Bool {
        return FileManager.default.fileExists(atPath: getPultoFilePath())
    }
    
    private func getPultoFilePath() -> String {
        if let bundlePath = Bundle.main.path(forResource: "Pluto_1_2374", ofType: "usdz") {
            return "file://\(bundlePath)"
        }
        // Fallback to project path
        return "file:///Users/\(NSUserName())/Projects/Pulto3/Pulto/Resources/Pluto_1_2374.usdz"
    }
    
    private func getClipboardContent() -> String? {
        #if os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #else
        return UIPasteboard.general.string
        #endif
    }
}

// MARK: - Preview
struct USDZLoaderView_Previews: PreviewProvider {
    static var previews: some View {
        USDZLoaderView(
            isPresented: .constant(true),
            windowID: 1,
            windowManager: WindowTypeManager.shared
        )
    }
}