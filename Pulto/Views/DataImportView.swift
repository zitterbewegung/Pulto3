//
//  DataItem.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/3/25.
//  Copyright 2025 Apple. All rights reserved.
//


import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import RealityKit
import Combine

// MARK: - Enhanced Data Models for visionOS compatibility
@Model
final class DataItem {
    var id: UUID
    var title: String
    var subtitle: String
    var value: Double
    var status: String
    var timestamp: Date
    var spatialDataItem: SpatialDataImportItem?

    init(title: String, subtitle: String, value: Double, status: String, spatialDataItem: SpatialDataImportItem? = nil) {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.status = status
        self.timestamp = Date()
        self.spatialDataItem = spatialDataItem
    }
}

@Model
final class SpatialDataImportItem {
    var id: UUID
    var dataType: SpatialDataImportType
    var dimensions: SIMD3<Float>
    var pointCount: Int
    var rawData: Data
    var metadata: Data?

    enum SpatialDataImportType: String, Codable {
        case pointCloud = "pointCloud"
        case volumetric = "volumetric"
        case mesh = "mesh"
        case voxel = "voxel"
        case notebook = "notebook"
    }

    init(dataType: SpatialDataImportType, dimensions: SIMD3<Float>, pointCount: Int, rawData: Data) {
        self.id = UUID()
        self.dataType = dataType
        self.dimensions = dimensions
        self.pointCount = pointCount
        self.rawData = rawData
    }
}

@Model
final class VolumetricDataItem {
    var id: UUID
    var cellIndex: Int
    var cellType: String
    var content: Data
    var outputs: Data?
    var metadata: Data?
    var visualization: VisualizationMetadata?

    init(cellIndex: Int, cellType: String, content: Data) {
        self.id = UUID()
        self.cellIndex = cellIndex
        self.cellType = cellType
        self.content = content
    }
}

@Model
final class VisualizationMetadata {
    var id: UUID
    var visualizationType: String
    var colorMap: String
    var scale: SIMD3<Float>
    var rotation: SIMD3<Float>
    var opacity: Float

    init(visualizationType: String, colorMap: String = "viridis") {
        self.id = UUID()
        self.visualizationType = visualizationType
        self.colorMap = colorMap
        self.scale = SIMD3<Float>(1, 1, 1)
        self.rotation = SIMD3<Float>(0, 0, 0)
        self.opacity = 1.0
    }
}

// MARK: - Import Data Structures
struct ImportedRow {
    let data: [String: String]
    let spatialDataItem: SpatialDataImportItem?

    init(data: [String: String], spatialDataItem: SpatialDataImportItem? = nil) {
        self.data = data
        self.spatialDataItem = spatialDataItem
    }

    func toDataItem() -> DataItem? {
        let title = data["title"] ?? data["name"] ?? data["item"] ?? data["product"] ?? "Imported Item"
        let subtitle = data["subtitle"] ?? data["description"] ?? data["details"] ?? data["category"] ?? "No description"

        let valueString = data["value"] ?? data["price"] ?? data["amount"] ?? data["cost"] ?? data["revenue"] ?? "0"
        let value = Double(valueString.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0

        let status = data["status"] ?? data["state"] ?? data["condition"] ?? "Active"

        return DataItem(title: title, subtitle: subtitle, value: value, status: status, spatialDataItem: spatialDataItem)
    }
}

// MARK: - Point Cloud Data Structure for Import
struct PointCloudImportData {
    var points: [SIMD3<Float>]
    var colors: [SIMD3<Float>]?
    var normals: [SIMD3<Float>]?
    var intensities: [Float]?

    var bounds: (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard !points.isEmpty else {
            return (SIMD3<Float>(0, 0, 0), SIMD3<Float>(0, 0, 0))
        }

        var minBound = points[0]
        var maxBound = points[0]

        for point in points {
            minBound = min(minBound, point)
            maxBound = max(maxBound, point)
        }

        return (minBound, maxBound)
    }

    var center: SIMD3<Float> {
        let b = bounds
        return (b.min + b.max) / 2
    }

    var dimensions: SIMD3<Float> {
        let b = bounds
        return b.max - b.min
    }
}

// MARK: - RealityKit Preview Component for visionOS
struct SpatialDataPreview: View {
    let spatialDataItem: SpatialDataImportItem
    @State private var cameraTransform = Transform()
    @State private var scale: Float = 1.0

    var body: some View {
        RealityKitView(spatialDataItem: spatialDataItem, cameraTransform: $cameraTransform, scale: $scale)
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Text("3D Preview")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial)
                        .cornerRadius(4)

                    // Controls
                    VStack(spacing: 4) {
                        Button(action: { scale *= 1.2 }) {
                            Image(systemName: "plus.magnifyingglass")
                        }
                        Button(action: { scale *= 0.8 }) {
                            Image(systemName: "minus.magnifyingglass")
                        }
                        Button(action: { resetCamera() }) {
                            Image(systemName: "arrow.uturn.backward")
                        }
                    }
                    .buttonStyle(.borderless)
                    .padding(4)
                    .background(.regularMaterial)
                    .cornerRadius(6)
                }
                .padding()
            }
    }

    private func resetCamera() {
        cameraTransform = Transform()
        scale = 1.0
    }
}

struct RealityKitView: View {
    let spatialDataItem: SpatialDataImportItem
    @Binding var cameraTransform: Transform
    @Binding var scale: Float

    var body: some View {
        RealityView { content in
            // Create visualization based on data type
            if let entity = createVisualization(from: spatialDataItem) {
                content.add(entity)
            }
        } update: { content in
            // Update scale and transforms
            for entity in content.entities {
                entity.scale = SIMD3<Float>(repeating: scale)
            }
        }
    }

    private func createVisualization(from spatialDataItem: SpatialDataImportItem) -> Entity? {
        switch spatialDataItem.dataType {
        case .pointCloud:
            return createPointCloudEntity(from: spatialDataItem)
        case .volumetric:
            return createVolumetricEntity(from: spatialDataItem)
        case .mesh:
            return createMeshEntity(from: spatialDataItem)
        case .voxel:
            return createVoxelEntity(from: spatialDataItem)
        case .notebook:
            return createNotebookVisualization(from: spatialDataItem)
        }
    }

    private func createPointCloudEntity(from spatialDataItem: SpatialDataImportItem) -> Entity? {
        // Parse point cloud data
        guard let pointCloud = parsePointCloudData(spatialDataItem.rawData) else { return nil }

        let entity = Entity()

        // Create small spheres for each point (simplified for preview)
        let maxPoints = min(pointCloud.points.count, 1000) // Limit for performance
        let pointSize: Float = 0.01

        for i in 0..<maxPoints {
            let point = pointCloud.points[i]
            
            let mesh = MeshResource.generateSphere(radius: pointSize)
            var material = SimpleMaterial()
            
            if let colors = pointCloud.colors, i < colors.count {
                let color = colors[i]
                material.color = .init(tint: UIColor(
                    red: CGFloat(color.x),
                    green: CGFloat(color.y),
                    blue: CGFloat(color.z),
                    alpha: 1.0
                ))
            } else {
                material.color = .init(tint: .systemBlue)
            }

            let sphere = ModelEntity(mesh: mesh, materials: [material])
            sphere.position = point
            entity.addChild(sphere)
        }

        // Center the point cloud
        entity.position = -pointCloud.center

        return entity
    }

    private func createVolumetricEntity(from spatialDataItem: SpatialDataImportItem) -> Entity? {
        // Create a bounding box visualization for volumetric data
        let entity = Entity()

        let dimensions = spatialDataItem.dimensions
        let mesh = MeshResource.generateBox(size: dimensions)
        var material = SimpleMaterial()
        material.color = .init(tint: UIColor.systemBlue.withAlphaComponent(0.3))

        let box = ModelEntity(mesh: mesh, materials: [material])
        entity.addChild(box)
        return entity
    }

    private func createMeshEntity(from spatialDataItem: SpatialDataImportItem) -> Entity? {
        // Placeholder for mesh visualization
        let entity = Entity()
        let mesh = MeshResource.generateSphere(radius: 0.5)
        var material = SimpleMaterial()
        material.color = .init(tint: .systemGreen)
        material.metallic = 1.0
        
        let meshEntity = ModelEntity(mesh: mesh, materials: [material])
        entity.addChild(meshEntity)
        return entity
    }

    private func createVoxelEntity(from spatialDataItem: SpatialDataImportItem) -> Entity? {
        // Create voxel grid visualization
        let entity = Entity()

        // For now, show a grid of cubes
        let gridSize = 5
        let voxelSize: Float = 0.1
        let spacing: Float = 0.15

        for x in 0..<gridSize {
            for y in 0..<gridSize {
                for z in 0..<gridSize {
                    let mesh = MeshResource.generateBox(size: voxelSize)
                    var material = SimpleMaterial()
                    
                    let intensity = Float(x + y + z) / Float(gridSize * 3)
                    material.color = .init(tint: UIColor(hue: CGFloat(intensity), saturation: 0.8, brightness: 0.9, alpha: 0.8))

                    let voxel = ModelEntity(mesh: mesh, materials: [material])
                    voxel.position = SIMD3<Float>(
                        Float(x - gridSize/2) * spacing,
                        Float(y - gridSize/2) * spacing,
                        Float(z - gridSize/2) * spacing
                    )

                    entity.addChild(voxel)
                }
            }
        }

        return entity
    }

    private func createNotebookVisualization(from spatialDataItem: SpatialDataImportItem) -> Entity? {
        // Create a 3D representation of notebook cells
        let entity = Entity()

        let cellHeight: Float = 0.1
        let cellSpacing: Float = 0.02
        let maxCells = min(spatialDataItem.pointCount, 10)

        for i in 0..<maxCells {
            let mesh = MeshResource.generateBox(size: [1, cellHeight, 0.5])
            var material = SimpleMaterial()
            
            let hue = Float(i) / Float(maxCells)
            material.color = .init(tint: UIColor(hue: CGFloat(hue), saturation: 0.7, brightness: 0.9, alpha: 0.9))

            let cell = ModelEntity(mesh: mesh, materials: [material])
            cell.position.y = Float(i) * (cellHeight + cellSpacing)

            entity.addChild(cell)
        }

        return entity
    }

    private func parsePointCloudData(_ data: Data) -> PointCloudImportData? {
        // Simple parser - would need to be extended for actual formats
        // This is a placeholder that generates random points for demonstration
        var pointCloud = PointCloudImportData(points: [], colors: [])

        let pointCount = min(data.count / 12, 1000) // Assume 12 bytes per point (3 floats)

        for _ in 0..<pointCount {
            let point = SIMD3<Float>(
                Float.random(in: -1...1),
                Float.random(in: -1...1),
                Float.random(in: -1...1)
            )
            pointCloud.points.append(point)

            let color = SIMD3<Float>(
                Float.random(in: 0...1),
                Float.random(in: 0...1),
                Float.random(in: 0...1)
            )
            pointCloud.colors?.append(color)
        }

        return pointCloud
    }
}

// MARK: - visionOS Compatible Document Picker
struct VisionOSDocumentPicker: View {
    @Binding var isPresented: Bool
    let allowedContentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onCompletion: (Result<[URL], Error>) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                
                Text("Select File")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Choose a file to import")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Button("Browse Files") {
                    // In a real implementation, this would open the system file picker
                    // For now, we'll simulate with a sample file
                    let sampleURL = URL(fileURLWithPath: "/tmp/sample.csv")
                    onCompletion(.success([sampleURL]))
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .navigationTitle("Import File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onCompletion(.failure(CocoaError(.userCancelled)))
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Import Formats
enum ImportFormat: String, CaseIterable {
    case csv = "CSV"
    case json = "JSON"
    case tsv = "TSV"
    case ply = "PLY"
    case pcd = "PCD"
    case xyz = "XYZ"
    case obj = "OBJ"
    case auto = "Auto-detect"

    var fileExtensions: [String] {
        switch self {
        case .csv: return ["csv"]
        case .json: return ["json", "ipynb", "nb"]
        case .tsv: return ["tsv", "txt"]
        case .ply: return ["ply"]
        case .pcd: return ["pcd"]
        case .xyz: return ["xyz", "pts"]
        case .obj: return ["obj"]
        case .auto: return ["csv", "json", "tsv", "txt", "ply", "pcd", "xyz", "pts", "obj", "ipynb", "nb"]
        }
    }

    var isSpatialFormat: Bool {
        switch self {
        case .ply, .pcd, .xyz, .obj:
            return true
        default:
            return false
        }
    }
}

enum DataImportError: LocalizedError {
    case fileNotFound
    case invalidFormat(String)
    case emptyFile
    case parseError(String)
    case noValidData
    case unsupportedSpatialFormat

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .invalidFormat(let message):
            return "Invalid format: \(message)"
        case .emptyFile:
            return "File is empty"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .noValidData:
            return "No valid data found in file"
        case .unsupportedSpatialFormat:
            return "Unsupported spatial data format"
        }
    }
}

// MARK: - Enhanced Data Import View
struct DataImportView: View {
    let modelContext: ModelContext
    @State private var urlText = ""
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var showDocumentPicker = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var importedFileName = ""
    @State private var selectedImportMethod: ImportMethod = .file
    @State private var selectedFormat: ImportFormat = .auto
    @State private var importedCount = 0
    @State private var hasHeader = true
    @State private var delimiter = ","
    @State private var previewData: [ImportedRow] = []
    @State private var showPreview = false
    @State private var volumetricData: VolumetricData?
    @State private var spatialDataPreview: SpatialDataImportItem?
    @State private var showSpatialPreview = false
    @Environment(\.dismiss) private var dismiss

    enum ImportMethod: String, CaseIterable {
        case url = "URL"
        case file = "File"

        var icon: String {
            switch self {
            case .url: return "link"
            case .file: return "doc"
            }
        }
    }

    struct VolumetricData {
        let cells: [[String: Any]]
        let metadata: [String: Any]
        let kernelspec: [String: Any]?
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                        .symbolRenderingMode(.hierarchical)

                    Text("Import Data")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Import tabular, 2D/3D, and point cloud data")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("Supports CSV, JSON, Jupyter notebooks, PLY, PCD, XYZ, and OBJ formats")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 20)

                // Import Method Selection
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 20) {
                        ForEach(ImportMethod.allCases, id: \.self) { method in
                            ImportMethodButton(
                                method: method,
                                isSelected: selectedImportMethod == method
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedImportMethod = method
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 600)

                // Format Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("File Format")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ImportFormat.allCases, id: \.self) { format in
                                FormatButton(format: format, isSelected: selectedFormat == format) {
                                    selectedFormat = format
                                }
                            }
                        }
                    }

                    if selectedFormat == .csv || selectedFormat == .tsv {
                        HStack {
                            Toggle("First row contains headers", isOn: $hasHeader)
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: 600)

                // Import Interface
                Group {
                    if selectedImportMethod == .url {
                        URLImportSection(
                            urlText: $urlText,
                            isImporting: $isImporting,
                            onImport: importFromURL
                        )
                    } else {
                        FileImportSection(
                            importedFileName: $importedFileName,
                            isImporting: $isImporting,
                            onImport: { showDocumentPicker = true }
                        )
                    }
                }
                .frame(maxWidth: 600)

                // Progress Indicator
                if isImporting {
                    VStack(spacing: 16) {
                        ProgressView(value: importProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 300)

                        Text("Processing data... (\(Int(importProgress * 100))%)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Preview sections
                if showSpatialPreview, let spatialData = spatialDataPreview {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "cube.transparent")
                                .font(.title2)
                            Text("Spatial Data Preview")
                                .font(.headline)
                            Spacer()
                            Text("\(spatialData.pointCount) points")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        SpatialDataPreview(spatialDataItem: spatialData)
                            .frame(height: 300)
                            .background(.regularMaterial)
                            .cornerRadius(12)
                    }
                    .padding()
                    .background(.quaternary)
                    .cornerRadius(16)
                }

                if showPreview && !previewData.isEmpty && !isImporting {
                    previewSection
                }

                // Volumetric data indicator
                if volumetricData != nil && !isImporting {
                    VStack(spacing: 8) {
                        Image(systemName: "cube.transparent")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        Text("Jupyter notebook data detected")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(volumetricData!.cells.count) cells found")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Success indicator
                if importedCount > 0 && !isImporting {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Successfully imported \(importedCount) items")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding()
                    .background(.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()
            }
            .padding(.horizontal, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if importedCount > 0 && !isImporting {
                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            VisionOSDocumentPicker(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [
                    .json,
                    .text,
                    .xml,
                    .commaSeparatedText,
                    .tabSeparatedText,
                    .plainText,
                    UTType(filenameExtension: "ipynb") ?? .json,
                    UTType(filenameExtension: "nb") ?? .json,
                    UTType(filenameExtension: "ply") ?? .data,
                    UTType(filenameExtension: "pcd") ?? .data,
                    UTType(filenameExtension: "xyz") ?? .data,
                    UTType(filenameExtension: "pts") ?? .data,
                    UTType(filenameExtension: "obj") ?? .data
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
        .alert("Import Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.headline)
                Spacer()
                Button("Import All") {
                    confirmImport()
                }
                .buttonStyle(.borderedProminent)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(0..<min(5, previewData.count), id: \.self) { index in
                        let row = previewData[index]
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                if let title = row.data["title"] ?? row.data["name"] ?? row.data.values.first {
                                    Text(title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                HStack(spacing: 12) {
                                    Text("\(row.data.count) fields")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if row.spatialDataItem != nil {
                                        Label("Has 3D data", systemImage: "cube.transparent")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            Spacer()
                            if let valueString = row.data["value"] ?? row.data["price"] ?? row.data["amount"],
                               let value = Double(valueString) {
                                Text(value, format: .currency(code: "USD"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(.regularMaterial)
                        .cornerRadius(8)
                    }

                    if previewData.count > 5 {
                        Text("... and \(previewData.count - 5) more rows")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
    }

    private func importFromURL() {
        guard !urlText.isEmpty else {
            showError(message: "Please enter a valid URL")
            return
        }

        guard let url = URL(string: urlText) else {
            showError(message: "Invalid URL format")
            return
        }

        performImport(from: url)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                showError(message: "No file selected")
                return
            }

            importedFileName = url.lastPathComponent
            performImport(from: url)

        case .failure(let error):
            showError(message: error.localizedDescription)
        }
    }

    private func performImport(from url: URL) {
        isImporting = true
        importProgress = 0
        importedCount = 0
        previewData = []
        showPreview = false
        showSpatialPreview = false
        volumetricData = nil
        spatialDataPreview = nil

        Task {
            do {
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                await updateProgress(0.1)

                // Check if it's a spatial data format
                let format = selectedFormat == .auto ? detectFormat(from: url) : selectedFormat

                if format.isSpatialFormat {
                    try await importSpatialData(from: url, format: format)
                } else {
                    // Read file content for text-based formats
                    let content = try String(contentsOf: url, encoding: .utf8)

                    guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw DataImportError.emptyFile
                    }

                    await updateProgress(0.3)

                    // Check if it's a Jupyter notebook
                    if url.pathExtension.lowercased() == "ipynb" || isJupyterNotebook(content) {
                        try await parseJupyterNotebook(content)
                        return
                    }

                    // Parse content
                    let rows = try parseContent(content, format: format)

                    await updateProgress(0.6)

                    guard !rows.isEmpty else {
                        throw DataImportError.noValidData
                    }

                    await MainActor.run {
                        previewData = rows
                        showPreview = true
                        isImporting = false
                        importProgress = 1.0
                    }
                }

            } catch {
                await MainActor.run {
                    isImporting = false
                    showError(message: error.localizedDescription)
                }
            }
        }
    }

    private func importSpatialData(from url: URL, format: ImportFormat) async throws {
        let data = try Data(contentsOf: url)

        await updateProgress(0.3)

        let spatialData: SpatialDataImportItem

        switch format {
        case .ply:
            spatialData = try await parsePLY(data)
        case .pcd:
            spatialData = try await parsePCD(data)
        case .xyz:
            spatialData = try await parseXYZ(data)
        case .obj:
            spatialData = try await parseOBJ(data)
        default:
            throw DataImportError.unsupportedSpatialFormat
        }

        await updateProgress(0.8)

        await MainActor.run {
            spatialDataPreview = spatialData
            showSpatialPreview = true

            // Create a preview data item
            let importedRow = ImportedRow(
                data: [
                    "title": url.lastPathComponent,
                    "subtitle": "3D \(format.rawValue) file",
                    "value": String(spatialData.pointCount),
                    "status": "Imported"
                ],
                spatialDataItem: spatialData
            )
            previewData = [importedRow]
            showPreview = true

            isImporting = false
            importProgress = 1.0
        }
    }

    private func parsePLY(_ data: Data) async throws -> SpatialDataImportItem {
        // Simplified PLY parser - would need full implementation
        let pointCount = data.count / 12 // Rough estimate

        return SpatialDataImportItem(
            dataType: .pointCloud,
            dimensions: SIMD3<Float>(1, 1, 1),
            pointCount: pointCount,
            rawData: data
        )
    }

    private func parsePCD(_ data: Data) async throws -> SpatialDataImportItem {
        // Simplified PCD parser
        let pointCount = data.count / 16 // Rough estimate

        return SpatialDataImportItem(
            dataType: .pointCloud,
            dimensions: SIMD3<Float>(1, 1, 1),
            pointCount: pointCount,
            rawData: data
        )
    }

    private func parseXYZ(_ data: Data) async throws -> SpatialDataImportItem {
        // Parse XYZ format (text-based point cloud)
        guard let content = String(data: data, encoding: .utf8) else {
            throw DataImportError.parseError("Unable to read XYZ file")
        }

        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        return SpatialDataImportItem(
            dataType: .pointCloud,
            dimensions: SIMD3<Float>(1, 1, 1),
            pointCount: lines.count,
            rawData: data
        )
    }

    private func parseOBJ(_ data: Data) async throws -> SpatialDataImportItem {
        // Simplified OBJ parser
        guard let content = String(data: data, encoding: .utf8) else {
            throw DataImportError.parseError("Unable to read OBJ file")
        }

        let vertexCount = content.components(separatedBy: "\n")
            .filter { $0.starts(with: "v ") }
            .count

        return SpatialDataImportItem(
            dataType: .mesh,
            dimensions: SIMD3<Float>(1, 1, 1),
            pointCount: vertexCount,
            rawData: data
        )
    }

    private func isJupyterNotebook(_ content: String) -> Bool {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        return json["cells"] != nil && json["metadata"] != nil
    }

    private func parseJupyterNotebook(_ content: String) async throws {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cells = json["cells"] as? [[String: Any]] else {
            throw DataImportError.invalidFormat("Invalid Jupyter notebook format")
        }

        await updateProgress(0.5)

        var extractedData: [ImportedRow] = []
        var volumetricCells: [VolumetricDataItem] = []

        for (index, cell) in cells.enumerated() {
            if let cellType = cell["cell_type"] as? String {
                let cellData = try JSONSerialization.data(withJSONObject: cell)
                let volumetricCell = VolumetricDataItem(
                    cellIndex: index,
                    cellType: cellType,
                    content: cellData
                )

                if cellType == "code", let outputs = cell["outputs"] as? [[String: Any]] {
                    volumetricCell.outputs = try? JSONSerialization.data(withJSONObject: outputs)

                    // Look for visualization metadata
                    if let metadata = cell["metadata"] as? [String: Any],
                       let vizType = metadata["visualization_type"] as? String {
                        volumetricCell.visualization = VisualizationMetadata(visualizationType: vizType)
                    }

                    // Extract data from outputs
                    for output in outputs {
                        if let data = output["data"] as? [String: Any] {
                            if let textData = data["text/plain"] as? [String] {
                                for line in textData {
                                    if let row = parseDataLine(line) {
                                        extractedData.append(row)
                                    }
                                }
                            } else if let jsonData = data["application/json"] {
                                if let jsonArray = jsonData as? [[String: Any]] {
                                    for item in jsonArray {
                                        var rowData: [String: String] = [:]
                                        for (key, value) in item {
                                            rowData[key.lowercased()] = String(describing: value)
                                        }

                                        // Check if this contains spatial data
                                        if let spatialType = item["spatial_type"] as? String,
                                           let spatialDataRaw = item["spatial_data"] as? [String: Any] {
                                            let spatialData = try createSpatialDataFromJSON(spatialDataRaw, type: spatialType)
                                            extractedData.append(ImportedRow(data: rowData, spatialDataItem: spatialData))
                                        } else {
                                            extractedData.append(ImportedRow(data: rowData))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                volumetricCells.append(volumetricCell)
            }

            let progress = 0.5 + (0.4 * Double(index + 1) / Double(cells.count))
            await updateProgress(progress)
        }

        await MainActor.run {
            volumetricData = VolumetricData(
                cells: cells,
                metadata: json["metadata"] as? [String: Any] ?? [:],
                kernelspec: json["kernelspec"] as? [String: Any]
            )

            // Store volumetric cells in the model context
            for cell in volumetricCells {
                modelContext.insert(cell)
            }

            if !extractedData.isEmpty {
                previewData = extractedData
                showPreview = true
            }

            // If any spatial data was found, show the first one
            if let firstSpatialData = extractedData.first(where: { $0.spatialDataItem != nil })?.spatialDataItem {
                spatialDataPreview = firstSpatialData
                showSpatialPreview = true
            }

            isImporting = false
            importProgress = 1.0
        }
    }

    private func createSpatialDataFromJSON(_ json: [String: Any], type: String) throws -> SpatialDataImportItem {
        let dataType: SpatialDataImportItem.SpatialDataImportType
        switch type.lowercased() {
        case "pointcloud": dataType = .pointCloud
        case "volumetric": dataType = .volumetric
        case "mesh": dataType = .mesh
        case "voxel": dataType = .voxel
        default: dataType = .volumetric
        }

        let dimensions = SIMD3<Float>(
            Float(json["width"] as? Double ?? 1.0),
            Float(json["height"] as? Double ?? 1.0),
            Float(json["depth"] as? Double ?? 1.0)
        )

        let pointCount = json["point_count"] as? Int ?? 0
        let rawData = try JSONSerialization.data(withJSONObject: json)

        return SpatialDataImportItem(
            dataType: dataType,
            dimensions: dimensions,
            pointCount: pointCount,
            rawData: rawData
        )
    }

    private func parseDataLine(_ line: String) -> ImportedRow? {
        let components = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count >= 2 else { return nil }

        var data: [String: String] = [:]
        data["title"] = components[0]
        if components.count > 1 {
            data["value"] = components[1]
        }
        if components.count > 2 {
            data["status"] = components[2]
        }

        return ImportedRow(data: data)
    }

    private func confirmImport() {
        isImporting = true

        Task {
            await updateProgress(0.7)

            for (index, row) in previewData.enumerated() {
                if let dataItem = row.toDataItem() {
                    await MainActor.run {
                        modelContext.insert(dataItem)

                        // Also save any associated spatial data
                        if let spatialData = row.spatialDataItem {
                            modelContext.insert(spatialData)
                        }

                        importedCount += 1
                    }
                }

                let progress = 0.7 + (0.3 * Double(index + 1) / Double(previewData.count))
                await updateProgress(progress)
            }

            await MainActor.run {
                isImporting = false
                showPreview = false
                showSpatialPreview = false
                importProgress = 1.0
            }
        }
    }

    private func updateProgress(_ value: Double) async {
        await MainActor.run {
            importProgress = value
        }
    }

    private func detectFormat(from url: URL) -> ImportFormat {
        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "json", "ipynb", "nb":
            return .json
        case "tsv", "txt":
            return .tsv
        case "csv":
            return .csv
        case "ply":
            return .ply
        case "pcd":
            return .pcd
        case "xyz", "pts":
            return .xyz
        case "obj":
            return .obj
        default:
            return .csv
        }
    }

    private func parseContent(_ content: String, format: ImportFormat) throws -> [ImportedRow] {
        switch format {
        case .json:
            return try parseJSON(content)
        case .csv:
            return try parseCSV(content, delimiter: ",")
        case .tsv:
            return try parseCSV(content, delimiter: "\t")
        default:
            throw DataImportError.invalidFormat("Format not supported for text parsing")
        }
    }

    private func parseJSON(_ content: String) throws -> [ImportedRow] {
        guard let data = content.data(using: .utf8) else {
            throw DataImportError.parseError("Unable to convert content to data")
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)

            if let array = jsonObject as? [[String: Any]] {
                return try parseJSONArray(array)
            } else if let dict = jsonObject as? [String: Any] {
                return try parseJSONArray([dict])
            } else {
                throw DataImportError.invalidFormat("Unsupported JSON structure")
            }
        } catch {
            throw DataImportError.parseError("Invalid JSON: \(error.localizedDescription)")
        }
    }

    private func parseJSONArray(_ array: [[String: Any]]) throws -> [ImportedRow] {
        return array.compactMap { object in
            var data: [String: String] = [:]
            for (key, value) in object {
                data[key.lowercased()] = String(describing: value)
            }
            return ImportedRow(data: data)
        }
    }

    private func parseCSV(_ content: String, delimiter: String) throws -> [ImportedRow] {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            throw DataImportError.emptyFile
        }

        let parsedRows = lines.map { line in
            parseCSVLine(line, delimiter: delimiter)
        }

        let headers: [String]
        let dataRows: [[String]]

        if hasHeader && parsedRows.count > 1 {
            headers = parsedRows[0].map { $0.lowercased() }
            dataRows = Array(parsedRows[1...])
        } else {
            let columnCount = parsedRows.first?.count ?? 0
            headers = (0..<columnCount).map { "column_\($0 + 1)" }
            dataRows = parsedRows
        }

        return dataRows.compactMap { row in
            var data: [String: String] = [:]
            for (index, value) in row.enumerated() {
                if index < headers.count {
                    data[headers[index]] = value
                }
            }
            return ImportedRow(data: data)
        }
    }

    private func parseCSVLine(_ line: String, delimiter: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]

            if char == "\"" {
                if inQuotes && i < line.index(before: line.endIndex) && line[line.index(after: i)] == "\"" {
                    current.append("\"")
                    i = line.index(i, offsetBy: 2)
                    continue
                } else {
                    inQuotes.toggle()
                }
            } else if String(char) == delimiter && !inQuotes {
                result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(char)
            }

            i = line.index(after: i)
        }

        result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return result
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Supporting Views
struct ImportMethodButton: View {
    let method: DataImportView.ImportMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: method.icon)
                    .font(.system(size: 32))
                    .symbolRenderingMode(.hierarchical)

                Text(method.rawValue)
                    .font(.headline)
            }
            .frame(width: 140, height: 100)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? Color.accentColor : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct FormatButton: View {
    let format: ImportFormat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if format.isSpatialFormat {
                    Image(systemName: "cube.transparent")
                        .font(.caption)
                }
                Text(format.rawValue)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? Color.accentColor : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct URLImportSection: View {
    @Binding var urlText: String
    @Binding var isImporting: Bool
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter URL")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack {
                TextField("https://example.com/data.json", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isImporting)

                Button(action: onImport) {
                    Label("Import", systemImage: "arrow.down.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlText.isEmpty || isImporting)
            }

            Text("Supported formats: JSON, CSV, TSV, PLY, PCD, XYZ, OBJ")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct FileImportSection: View {
    @Binding var importedFileName: String
    @Binding var isImporting: Bool
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            if importedFileName.isEmpty {
                Text("No file selected")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    Text("Selected File")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(importedFileName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Button(action: onImport) {
                Label("Choose File", systemImage: "folder")
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isImporting)

            Text("Supported: Tabular (CSV, JSON), 3D (PLY, PCD, XYZ, OBJ), Notebooks (Jupyter)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
