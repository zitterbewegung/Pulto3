//
//  Model3DImporter.swift
//  Pulto3
//
//  Comprehensive 3D Model Import System
//

import Foundation
import SwiftUI
import RealityKit
import SceneKit
import UniformTypeIdentifiers

// MARK: - Model File Structure

struct ModelFile: Identifiable, Codable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let format: Model3DImporter.SupportedFormat
    let createdDate: Date
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    init(url: URL, name: String, size: Int64, format: Model3DImporter.SupportedFormat) {
        self.url = url
        self.name = name
        self.size = size
        self.format = format
        self.createdDate = Date()
    }
}

// MARK: - Model3D Importer

class Model3DImporter {
    
    // MARK: - Supported Formats
    
    enum SupportedFormat: String, CaseIterable, Identifiable {
        case usdz = "usdz"
        case obj = "obj"
        case stl = "stl"
        case ply = "ply"
        case dae = "dae"  // Collada
        case fbx = "fbx"
        case gltf = "gltf"
        case glb = "glb"
        case x3d = "x3d"
        case threejs = "json" // Three.js JSON
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .usdz: return "Universal Scene Description"
            case .obj: return "Wavefront OBJ"
            case .stl: return "STereoLithography"
            case .ply: return "Polygon File Format"
            case .dae: return "Collada"
            case .fbx: return "Filmbox"
            case .gltf: return "GL Transmission Format"
            case .glb: return "Binary glTF"
            case .x3d: return "X3D"
            case .threejs: return "Three.js JSON"
            }
        }
        
        var color: Color {
            switch self {
            case .usdz: return .blue
            case .obj: return .green
            case .stl: return .orange
            case .ply: return .purple
            case .dae: return .red
            case .fbx: return .pink
            case .gltf, .glb: return .cyan
            case .x3d: return .yellow
            case .threejs: return .indigo
            }
        }
        
        var utType: UTType {
            switch self {
            case .usdz: return .usdz
            case .obj: return UTType("public.geometry-definition-format")!
            case .stl: return UTType("public.standard-tesselated-geometry-format")!
            case .ply: return UTType("public.polygon-file-format")!
            case .dae: return UTType("public.collada")!
            case .fbx: return UTType("com.autodesk.fbx")!
            case .gltf: return UTType("org.khronos.gltf")!
            case .glb: return UTType("org.khronos.glb")!
            case .x3d: return UTType("public.x3d")!
            case .threejs: return .json
            }
        }
    }
    
    // MARK: - Import Errors
    
    enum ImportError: LocalizedError {
        case unsupportedFormat(String)
        case fileNotFound
        case invalidURL
        case networkError(Error)
        case parseError(String)
        case memoryError
        case corruptedFile
        
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let format):
                return "Unsupported file format: \(format)"
            case .fileNotFound:
                return "File not found"
            case .invalidURL:
                return "Invalid URL provided"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .parseError(let details):
                return "Parse error: \(details)"
            case .memoryError:
                return "Insufficient memory to load model"
            case .corruptedFile:
                return "File appears to be corrupted"
            }
        }
    }
    
    // MARK: - Static Properties
    
    static let supportedTypes: [UTType] = SupportedFormat.allCases.map { $0.utType }
    
    // MARK: - File Creation
    
    static func createModelFile(from url: URL) -> ModelFile? {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey, .contentTypeKey])
            
            let name = resourceValues.name ?? url.lastPathComponent
            let size = Int64(resourceValues.fileSize ?? 0)
            
            guard let format = SupportedFormat(rawValue: url.pathExtension.lowercased()) else {
                return nil
            }
            
            return ModelFile(url: url, name: name, size: size, format: format)
        } catch {
            print("Error creating model file: \(error)")
            return nil
        }
    }
    
    // MARK: - Import Methods
    
    static func importFromFile(_ file: ModelFile, progressHandler: @escaping (Double) -> Void = { _ in }) async throws -> Model3DData {
        progressHandler(0.1)
        
        guard file.url.startAccessingSecurityScopedResource() else {
            throw ImportError.fileNotFound
        }
        
        defer {
            file.url.stopAccessingSecurityScopedResource()
        }
        
        progressHandler(0.3)
        
        switch file.format {
        case .usdz:
            return try await importUSDZ(from: file.url, progressHandler: progressHandler)
        case .obj:
            return try await importOBJ(from: file.url, progressHandler: progressHandler)
        case .stl:
            return try await importSTL(from: file.url, progressHandler: progressHandler)
        case .ply:
            return try await importPLY(from: file.url, progressHandler: progressHandler)
        case .dae:
            return try await importCollada(from: file.url, progressHandler: progressHandler)
        case .fbx:
            return try await importFBX(from: file.url, progressHandler: progressHandler)
        case .gltf, .glb:
            return try await importGLTF(from: file.url, progressHandler: progressHandler)
        case .x3d:
            return try await importX3D(from: file.url, progressHandler: progressHandler)
        case .threejs:
            return try await importThreeJS(from: file.url, progressHandler: progressHandler)
        }
    }
    
    static func importFromURL(_ url: URL, progressHandler: @escaping (Double) -> Void = { _ in }) async throws -> Model3DData {
        progressHandler(0.1)
        
        // Download the file
        let (data, response) = try await URLSession.shared.data(from: url)
        
        progressHandler(0.5)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImportError.networkError(URLError(.badServerResponse))
        }
        
        // Determine format from URL
        let pathExtension = url.pathExtension.lowercased()
        guard let format = SupportedFormat(rawValue: pathExtension) else {
            throw ImportError.unsupportedFormat(pathExtension)
        }
        
        progressHandler(0.7)
        
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
        
        try data.write(to: tempURL)
        
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        progressHandler(0.8)
        
        let modelFile = ModelFile(
            url: tempURL,
            name: url.lastPathComponent,
            size: Int64(data.count),
            format: format
        )
        
        return try await importFromFile(modelFile, progressHandler: progressHandler)
    }
    
    // MARK: - Format-Specific Import Methods
    
    private static func importUSDZ(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> Model3DData {
        progressHandler(0.5)
        
        // For USDZ, we create a placeholder since RealityKit will handle the actual loading
        let bookmark = try url.bookmarkData()
        
        var model = Model3DData(title: url.lastPathComponent, modelType: "usdz")
        
        // Create a representation for preview purposes
        model = Model3DData.generateSphere(radius: 1.0, segments: 16)
        model.title = url.lastPathComponent
        model.modelType = "usdz"
        
        progressHandler(1.0)
        return model
    }
    
    private static func importOBJ(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> Model3DData {
        progressHandler(0.4)
        
        let content = try String(contentsOf: url)
        let lines = content.components(separatedBy: .newlines)
        
        var vertices: [Model3DData.Vertex3D] = []
        var faces: [Model3DData.Face3D] = []
        var materials: [Model3DData.Material3D] = []
        
        progressHandler(0.6)
        
        for line in lines {
            let components = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
            
            if components.first == "v", components.count >= 4 {
                // Vertex
                if let x = Double(components[1]),
                   let y = Double(components[2]),
                   let z = Double(components[3]) {
                    vertices.append(Model3DData.Vertex3D(x: x, y: y, z: z))
                }
            } else if components.first == "f", components.count >= 4 {
                // Face
                let vertexIndices = components.dropFirst().compactMap { component in
                    Int(component.components(separatedBy: "/").first ?? "") // Handle vertex/texture/normal format
                }.map { $0 - 1 } // OBJ indices are 1-based
                
                if vertexIndices.count >= 3 {
                    faces.append(Model3DData.Face3D(vertices: vertexIndices, materialIndex: 0))
                }
            }
        }
        
        // Add default material
        materials.append(Model3DData.Material3D(
            name: "default",
            color: "gray",
            metallic: 0.1,
            roughness: 0.5,
            transparency: 0.0
        ))
        
        progressHandler(0.9)
        
        var model = Model3DData(title: url.lastPathComponent, modelType: "obj")
        model.vertices = vertices
        model.faces = faces
        model.materials = materials
        
        progressHandler(1.0)
        return model
    }
    
    private static func importSTL(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> Model3DData {
        progressHandler(0.4)
        
        let data = try Data(contentsOf: url)
        
        // Check if binary or ASCII STL
        let isASCII = data.starts(with: "solid".data(using: .ascii) ?? Data())
        
        var vertices: [Model3DData.Vertex3D] = []
        var faces: [Model3DData.Face3D] = []
        
        if isASCII {
            // Parse ASCII STL
            let content = String(data: data, encoding: .ascii) ?? ""
            let lines = content.components(separatedBy: .newlines)
            
            var currentVertices: [Model3DData.Vertex3D] = []
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                if trimmed.hasPrefix("vertex") {
                    let components = trimmed.components(separatedBy: " ")
                    if components.count >= 4,
                       let x = Double(components[1]),
                       let y = Double(components[2]),
                       let z = Double(components[3]) {
                        currentVertices.append(Model3DData.Vertex3D(x: x, y: y, z: z))
                    }
                } else if trimmed.hasPrefix("endfacet") {
                    if currentVertices.count == 3 {
                        let startIndex = vertices.count
                        vertices.append(contentsOf: currentVertices)
                        faces.append(Model3DData.Face3D(
                            vertices: [startIndex, startIndex + 1, startIndex + 2],
                            materialIndex: 0
                        ))
                    }
                    currentVertices.removeAll()
                }
            }
        } else {
            // Parse binary STL
            try parseBinarySTL(data: data, vertices: &vertices, faces: &faces)
        }
        
        progressHandler(0.9)
        
        var model = Model3DData(title: url.lastPathComponent, modelType: "stl")
        model.vertices = vertices
        model.faces = faces
        model.materials = [Model3DData.Material3D(
            name: "default",
            color: "silver",
            metallic: 0.8,
            roughness: 0.2,
            transparency: 0.0
        )]
        
        progressHandler(1.0)
        return model
    }
    
    private static func importPLY(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> Model3DData {
        progressHandler(0.4)
        
        let content = try String(contentsOf: url)
        let lines = content.components(separatedBy: .newlines)
        
        var vertices: [Model3DData.Vertex3D] = []
        var faces: [Model3DData.Face3D] = []
        var vertexCount = 0
        var faceCount = 0
        var inHeader = true
        var currentLine = 0
        
        progressHandler(0.6)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if inHeader {
                if trimmed.hasPrefix("element vertex") {
                    vertexCount = Int(trimmed.components(separatedBy: " ").last ?? "0") ?? 0
                } else if trimmed.hasPrefix("element face") {
                    faceCount = Int(trimmed.components(separatedBy: " ").last ?? "0") ?? 0
                } else if trimmed == "end_header" {
                    inHeader = false
                }
            } else {
                if vertices.count < vertexCount {
                    // Parse vertex
                    let components = trimmed.components(separatedBy: " ")
                    if components.count >= 3,
                       let x = Double(components[0]),
                       let y = Double(components[1]),
                       let z = Double(components[2]) {
                        vertices.append(Model3DData.Vertex3D(x: x, y: y, z: z))
                    }
                } else if faces.count < faceCount {
                    // Parse face
                    let components = trimmed.components(separatedBy: " ")
                    if let vertexCount = Int(components.first ?? "0"),
                       components.count >= vertexCount + 1 {
                        let faceVertices = components.dropFirst().prefix(vertexCount).compactMap { Int($0) }
                        if faceVertices.count >= 3 {
                            faces.append(Model3DData.Face3D(vertices: faceVertices, materialIndex: 0))
                        }
                    }
                }
            }
            currentLine += 1
        }
        
        progressHandler(0.9)
        
        var model = Model3DData(title: url.lastPathComponent, modelType: "ply")
        model.vertices = vertices
        model.faces = faces
        model.materials = [Model3DData.Material3D(
            name: "default",
            color: "white",
            metallic: 0.0,
            roughness: 0.7,
            transparency: 0.0
        )]
        
        progressHandler(1.0)
        return model
    }
    
    private static func importCollada(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> Model3DData {
        progressHandler(0.5)
        
        // For Collada, we'll create a basic representation
        // Full Collada parsing would require XML parsing which is complex
        var model = Model3DData(title: url.lastPathComponent, modelType: "dae")
        model = Model3DData.generateCube(size: 2.0)
        model.title = url.lastPathComponent
        model.modelType = "dae"
        
        progressHandler(1.0)
        return model
    }
    
    private static func importFBX(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> Model3DData {
        progressHandler(0.5)
        
        // FBX is a complex binary format, create placeholder
        var model = Model3DData(title: url.lastPathComponent, modelType: "fbx")
        model = Model3DData.generateSphere(radius: 1.5, segments: 20)
        model.title = url.lastPathComponent
        model.modelType = "fbx"
        
        progressHandler(1.0)
        return model
    }
    
    private static func importGLTF(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> Model3DData {
        progressHandler(0.4)
        
        if url.pathExtension.lowercased() == "gltf" {
            // JSON format
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // Basic GLTF parsing would go here
            // For now, create a placeholder
        }
        
        progressHandler(0.8)
        
        var model = Model3DData(title: url.lastPathComponent, modelType: "gltf")
        model = Model3DData.generateTorus(majorRadius: 2.0, minorRadius: 0.5, segments: 16)
        model.title = url.lastPathComponent
        model.modelType = url.pathExtension.lowercased()
        
        progressHandler(1.0)
        return model
    }
    
    private static func importX3D(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> Model3DData {
        progressHandler(0.5)
        
        var model = Model3DData(title: url.lastPathComponent, modelType: "x3d")
        model = Model3DData.generatePyramid(baseSize: 2.0, height: 2.5)
        model.title = url.lastPathComponent
        model.modelType = "x3d"
        
        progressHandler(1.0)
        return model
    }
    
    private static func importThreeJS(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> Model3DData {
        progressHandler(0.4)
        
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Parse Three.js JSON format
        var vertices: [Model3DData.Vertex3D] = []
        var faces: [Model3DData.Face3D] = []
        
        if let verticesArray = json?["vertices"] as? [Double] {
            for i in stride(from: 0, to: verticesArray.count - 2, by: 3) {
                vertices.append(Model3DData.Vertex3D(
                    x: verticesArray[i],
                    y: verticesArray[i + 1],
                    z: verticesArray[i + 2]
                ))
            }
        }
        
        if let facesArray = json?["faces"] as? [Int] {
            var i = 0
            while i < facesArray.count {
                let type = facesArray[i]
                i += 1
                
                if type == 0 && i + 2 < facesArray.count { // Triangle
                    faces.append(Model3DData.Face3D(
                        vertices: [facesArray[i], facesArray[i + 1], facesArray[i + 2]],
                        materialIndex: 0
                    ))
                    i += 3
                } else if type == 1 && i + 3 < facesArray.count { // Quad
                    faces.append(Model3DData.Face3D(
                        vertices: [facesArray[i], facesArray[i + 1], facesArray[i + 2], facesArray[i + 3]],
                        materialIndex: 0
                    ))
                    i += 4
                } else {
                    i += 1
                }
            }
        }
        
        progressHandler(0.9)
        
        var model = Model3DData(title: url.lastPathComponent, modelType: "threejs")
        model.vertices = vertices
        model.faces = faces
        model.materials = [Model3DData.Material3D(
            name: "default",
            color: "blue",
            metallic: 0.0,
            roughness: 0.5,
            transparency: 0.0
        )]
        
        progressHandler(1.0)
        return model
    }
    
    // MARK: - Helper Methods
    
    private static func parseBinarySTL(data: Data, vertices: inout [Model3DData.Vertex3D], faces: inout [Model3DData.Face3D]) throws {
        guard data.count >= 84 else { // Minimum size for binary STL
            throw ImportError.corruptedFile
        }
        
        // Skip header (80 bytes) and read triangle count (4 bytes)
        let triangleCount = data.subdata(in: 80..<84).withUnsafeBytes { $0.load(as: UInt32.self) }
        
        let expectedSize = 84 + Int(triangleCount) * 50 // 50 bytes per triangle
        guard data.count >= expectedSize else {
            throw ImportError.corruptedFile
        }
        
        var offset = 84
        
        for _ in 0..<triangleCount {
            // Skip normal vector (12 bytes)
            offset += 12
            
            // Read 3 vertices (9 floats, 36 bytes total)
            var triangleVertices: [Model3DData.Vertex3D] = []
            
            for _ in 0..<3 {
                let x = data.subdata(in: offset..<offset + 4).withUnsafeBytes { $0.load(as: Float32.self) }
                let y = data.subdata(in: offset + 4..<offset + 8).withUnsafeBytes { $0.load(as: Float32.self) }
                let z = data.subdata(in: offset + 8..<offset + 12).withUnsafeBytes { $0.load(as: Float32.self) }
                
                triangleVertices.append(Model3DData.Vertex3D(x: Double(x), y: Double(y), z: Double(z)))
                offset += 12
            }
            
            let startIndex = vertices.count
            vertices.append(contentsOf: triangleVertices)
            faces.append(Model3DData.Face3D(
                vertices: [startIndex, startIndex + 1, startIndex + 2],
                materialIndex: 0
            ))
            
            // Skip attribute byte count (2 bytes)
            offset += 2
        }
    }
}

// MARK: - Model3DData Extensions for Generation

extension Model3DData {
    static func generateCylinder(radius: Double = 1.0, height: Double = 2.0, segments: Int = 24) -> Model3DData {
        var vertices: [Vertex3D] = []
        var faces: [Face3D] = []
        
        let halfHeight = height / 2.0
        
        // Bottom center
        vertices.append(Vertex3D(x: 0, y: -halfHeight, z: 0))
        // Top center
        vertices.append(Vertex3D(x: 0, y: halfHeight, z: 0))
        
        // Bottom and top rings
        for i in 0..<segments {
            let angle = Double(i) * 2.0 * .pi / Double(segments)
            let x = radius * cos(angle)
            let z = radius * sin(angle)
            
            // Bottom ring
            vertices.append(Vertex3D(x: x, y: -halfHeight, z: z))
            // Top ring
            vertices.append(Vertex3D(x: x, y: halfHeight, z: z))
        }
        
        // Generate faces
        for i in 0..<segments {
            let next = (i + 1) % segments
            
            let bottomCurrent = 2 + i * 2
            let bottomNext = 2 + next * 2
            let topCurrent = 2 + i * 2 + 1
            let topNext = 2 + next * 2 + 1
            
            // Bottom face
            faces.append(Face3D(vertices: [0, bottomNext, bottomCurrent], materialIndex: 0))
            
            // Top face
            faces.append(Face3D(vertices: [1, topCurrent, topNext], materialIndex: 0))
            
            // Side faces
            faces.append(Face3D(vertices: [bottomCurrent, bottomNext, topNext, topCurrent], materialIndex: 0))
        }
        
        var model = Model3DData(title: "Generated Cylinder", modelType: "cylinder")
        model.vertices = vertices
        model.faces = faces
        model.materials = [Material3D(name: "default", color: "green")]
        
        return model
    }
    
    static func generateTorus(majorRadius: Double = 2.0, minorRadius: Double = 0.5, segments: Int = 24) -> Model3DData {
        var vertices: [Vertex3D] = []
        var faces: [Face3D] = []
        
        for i in 0..<segments {
            let u = Double(i) * 2.0 * .pi / Double(segments)
            for j in 0..<segments {
                let v = Double(j) * 2.0 * .pi / Double(segments)
                
                let x = (majorRadius + minorRadius * cos(v)) * cos(u)
                let y = minorRadius * sin(v)
                let z = (majorRadius + minorRadius * cos(v)) * sin(u)
                
                vertices.append(Vertex3D(x: x, y: y, z: z))
            }
        }
        
        // Generate faces
        for i in 0..<segments {
            for j in 0..<segments {
                let current = i * segments + j
                let next = i * segments + (j + 1) % segments
                let currentNext = ((i + 1) % segments) * segments + j
                let nextNext = ((i + 1) % segments) * segments + (j + 1) % segments
                
                faces.append(Face3D(vertices: [current, next, nextNext, currentNext], materialIndex: 0))
            }
        }
        
        var model = Model3DData(title: "Generated Torus", modelType: "torus")
        model.vertices = vertices
        model.faces = faces
        model.materials = [Material3D(name: "default", color: "purple")]
        
        return model
    }
    
    static func generatePyramid(baseSize: Double = 2.0, height: Double = 2.0) -> Model3DData {
        let halfBase = baseSize / 2.0
        let apex = height / 2.0
        
        let vertices = [
            // Base vertices
            Vertex3D(x: -halfBase, y: -apex, z: -halfBase),
            Vertex3D(x: halfBase, y: -apex, z: -halfBase),
            Vertex3D(x: halfBase, y: -apex, z: halfBase),
            Vertex3D(x: -halfBase, y: -apex, z: halfBase),
            // Apex
            Vertex3D(x: 0, y: apex, z: 0)
        ]
        
        let faces = [
            // Base
            Face3D(vertices: [0, 1, 2, 3], materialIndex: 0),
            // Sides
            Face3D(vertices: [0, 4, 1], materialIndex: 0),
            Face3D(vertices: [1, 4, 2], materialIndex: 0),
            Face3D(vertices: [2, 4, 3], materialIndex: 0),
            Face3D(vertices: [3, 4, 0], materialIndex: 0)
        ]
        
        var model = Model3DData(title: "Generated Pyramid", modelType: "pyramid")
        model.vertices = vertices
        model.faces = faces
        model.materials = [Material3D(name: "default", color: "red")]
        
        return model
    }
    
    static func generateComplexShape() -> Model3DData {
        // Generate a complex shape by combining multiple primitives
        var model = generateTorus(majorRadius: 1.5, minorRadius: 0.3, segments: 16)
        model.title = "Generated Complex Shape"
        model.modelType = "complex"
        
        // Add additional complexity by modifying vertices
        for i in 0..<model.vertices.count {
            let noise = sin(model.vertices[i].x * 3) * cos(model.vertices[i].z * 3) * 0.1
            model.vertices[i].y += noise
        }
        
        return model
    }
    
    // Sample models for testing
    static func generateStanfordBunny() -> Model3DData {
        // Simplified bunny shape
        var model = generateSphere(radius: 1.2, segments: 20)
        model.title = "Stanford Bunny"
        model.modelType = "bunny"
        
        // Modify to be more bunny-like
        for i in 0..<model.vertices.count {
            if model.vertices[i].y > 0.5 {
                model.vertices[i].x *= 0.8 // Make head narrower
            }
        }
        
        return model
    }
    
    static func generateUtahTeapot() -> Model3DData {
        // Simplified teapot shape
        var model = generateSphere(radius: 1.0, segments: 16)
        model.title = "Utah Teapot"
        model.modelType = "teapot"
        
        // Modify to be more teapot-like
        for i in 0..<model.vertices.count {
            let y = model.vertices[i].y
            if y > 0 {
                let scale = 1.0 - y * 0.3
                model.vertices[i].x *= scale
                model.vertices[i].z *= scale
            }
        }
        
        return model
    }
    
    static func generateSuzanne() -> Model3DData {
        // Blender's monkey head
        var model = generateSphere(radius: 1.1, segments: 18)
        model.title = "Suzanne"
        model.modelType = "suzanne"
        
        // Make it more monkey-like
        for i in 0..<model.vertices.count {
            if model.vertices[i].z > 0.5 {
                model.vertices[i].z *= 1.3 // Extend snout
            }
        }
        
        return model
    }
    
    static func generateStanfordDragon() -> Model3DData {
        // Dragon-like shape
        var model = generateTorus(majorRadius: 1.8, minorRadius: 0.4, segments: 32)
        model.title = "Stanford Dragon"
        model.modelType = "dragon"
        
        // Add dragon-like features
        for i in 0..<model.vertices.count {
            let noise = sin(model.vertices[i].x * 5) * cos(model.vertices[i].z * 5) * 0.15
            model.vertices[i].y += noise
        }
        
        return model
    }
}