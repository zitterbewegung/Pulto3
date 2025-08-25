//
//  Model3DExportManager.swift
//  Pulto3
//

import SwiftUI
import RealityKit
import UniformTypeIdentifiers
import UIKit
import SceneKit
import ModelIO

class Model3DExportManager: ObservableObject {

    @Published var showUSDZExporter: Bool = false
    @Published var usdzDocument: USDZDocument?

    @Published var showScreenshotExporter: Bool = false
    @Published var screenshotDocument: PNGDocument?

    func exportUSDZGeometryUVOnly(originalURL: URL, nodeTransform: simd_float4x4? = nil) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            var didStart = false
            if originalURL.isFileURL {
                didStart = originalURL.startAccessingSecurityScopedResource()
            }
            defer {
                if didStart { originalURL.stopAccessingSecurityScopedResource() }
            }

            let asset = MDLAsset(url: originalURL)

            for i in 0..<asset.count {
                if let obj = asset.object(at: i) as? MDLObject {
                    self.stripMaterialsKeepUV(obj)
                }
            }

            if let m = nodeTransform {
                for i in 0..<asset.count {
                    if let obj = asset.object(at: i) as? MDLObject {
                        self.applyTransform(obj, matrix: m)
                    }
                }
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Pulto_GeoUV_\(UUID().uuidString).usdz")
            try? FileManager.default.removeItem(at: tempURL)

            do {
                try asset.export(to: tempURL)
                if let data = try? Data(contentsOf: tempURL) {
                    await MainActor.run {
                        self.usdzDocument = USDZDocument(data: data)
                        self.showUSDZExporter = true
                    }
                } else {
                    print("Failed to read exported USDZ data")
                }
            } catch {
                print("Failed to export Geo+UV USDZ: \(error)")
            }

        }
    }

    private func stripMaterialsKeepUV(_ object: MDLObject) {
        if let mesh = object as? MDLMesh {
            if let submeshes = mesh.submeshes as? [MDLSubmesh] {
                for sub in submeshes {
                    sub.material = nil
                }
            }
        }
        if let children = object.children.objects as? [MDLObject] {
            for child in children {
                stripMaterialsKeepUV(child)
            }
        }
    }

    private func applyTransform(_ object: MDLObject, matrix: simd_float4x4) {
        if let existing = object.transform as? MDLTransform {
            let current = existing.matrix
            existing.matrix = matrix_multiply(matrix, current)
            object.transform = existing
        } else {
            let t = MDLTransform()
            t.matrix = matrix
            object.transform = t
        }
        if let children = object.children.objects as? [MDLObject] {
            for child in children {
                applyTransform(child, matrix: matrix)
            }
        }
    }

    func takeScreenshot(root: Entity?) async {
        guard let root = root else { return }

        let scnScene = SCNScene()
        if let scnNode = convertToSCNNode(entity: root) {
            scnScene.rootNode.addChildNode(scnNode)
        }

        // Compute bounds to fit camera
        let (minBounds, maxBounds) = scnScene.rootNode.boundingBox
        let center = SCNVector3(
            (minBounds.x + maxBounds.x) / 2,
            (minBounds.y + maxBounds.y) / 2,
            (minBounds.z + maxBounds.z) / 2
        )
        let extent = SCNVector3(
            maxBounds.x - minBounds.x,
            maxBounds.y - minBounds.y,
            maxBounds.z - minBounds.z
        )
        let maxExtent = max(extent.x, max(extent.y, extent.z))

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(center.x, center.y, center.z + maxExtent * 1.5)
        cameraNode.look(at: center)

        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 1024, height: 1024))
        view.scene = scnScene
        view.pointOfView = cameraNode
        view.backgroundColor = UIColor.clear

        let image = view.snapshot()
        guard let pngData = image.pngData() else { return }

        DispatchQueue.main.async {
            self.screenshotDocument = PNGDocument(data: pngData)
            self.showScreenshotExporter = true
        }
    }

    func exportModel(
        root: Entity?,
        modelData: Model3DData?,
        isUSDZ: Bool,
        windowID: Int,
        materialProvider: @escaping (Model3DData) -> RealityKit.Material,
        originalUSDZURL: URL? = nil
    ) async {
        guard let root = root else { return }

        let modelName = isUSDZ ? "USDZModel" : "3DModel"
        guard let modelEntity = root.findEntity(named: modelName) else { return }

        if !isUSDZ, let modelData = modelData, let modelEnt = modelEntity as? ModelEntity {
            var updatedMaterials = modelEnt.model?.materials ?? []
            updatedMaterials = [materialProvider(modelData)]
            modelEnt.model?.materials = updatedMaterials
        }

        do {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("Model_\(windowID).usdz")

            if isUSDZ, let originalURL = originalUSDZURL {
                if originalURL.startAccessingSecurityScopedResource() {
                    defer { originalURL.stopAccessingSecurityScopedResource() }
                    try FileManager.default.copyItem(at: originalURL, to: fileURL)
                } else {
                    throw NSError(domain: "Access denied", code: 1)
                }
            } else {
                let scnScene = SCNScene()
                if let scnNode = convertToSCNNode(entity: modelEntity) {
                    scnScene.rootNode.addChildNode(scnNode)
                }
                try scnScene.write(to: fileURL, options: nil, delegate: nil, progressHandler: nil)
            }

            let usdzData = try Data(contentsOf: fileURL)

            DispatchQueue.main.async {
                self.usdzDocument = USDZDocument(data: usdzData)
                self.showUSDZExporter = true
            }
        } catch {
            print("Failed to export model: \(error)")
        }
    }

    private func convertToSCNNode(entity: Entity) -> SCNNode? {
        let node = SCNNode()
        node.transform = SCNMatrix4(entity.transform.matrix)

        if let modelEntity = entity as? ModelEntity {
            if let mesh = modelEntity.model?.mesh {
                if let geometry = convertMeshToSCNGeometry(mesh: mesh),
                   let material = modelEntity.model?.materials.first {
                    let scnMaterial = convertMaterial(material)
                    geometry.materials = [scnMaterial]
                    node.geometry = geometry
                }
            }
        }

        for child in entity.children {
            if let childNode = convertToSCNNode(entity: child) {
                node.addChildNode(childNode)
            }
        }

        return node
    }

    private func convertMeshToSCNGeometry(mesh: MeshResource) -> SCNGeometry? {
        var sources: [SCNGeometrySource] = []
        var elements: [SCNGeometryElement] = []

        let contents = mesh.contents
        for model in contents.models {
            for part in model.parts {
                // Positions
                let positionsArray = Array(part.positions.elements)
                //let positionSource = SCNGeometrySource(vertices: positionsArray)
                //sources.append(positionSource)

                // Normals
                if let normals = part.normals {
                    let normalsArray = Array(normals.elements)
                    //let normalSource = SCNGeometrySource(normals: normalsArray)
                    //sources.append(normalSource)
                }

                // Triangle Indices
                if let indices = part.triangleIndices {
                    let indicesArray = Array(indices.elements)
                    let element = SCNGeometryElement(indices: indicesArray, primitiveType: .triangles)
                    elements.append(element)
                }
            }
        }

        guard !sources.isEmpty, !elements.isEmpty else { return nil }

        return SCNGeometry(sources: sources, elements: elements)
    }

    private func convertMaterial(_ material: RealityKit.Material) -> SCNMaterial {
        let scnMaterial = SCNMaterial()
        if let simple = material as? SimpleMaterial {
            scnMaterial.diffuse.contents = simple.color.tint
        } else if let pbr = material as? PhysicallyBasedMaterial {
            scnMaterial.lightingModel = .physicallyBased
            scnMaterial.diffuse.contents = pbr.baseColor.tint
        }
        return scnMaterial
    }
}

// MARK: - Documents

struct USDZDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.usdz] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        if let d = configuration.file.regularFileContents {
            data = d
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct PNGDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        if let d = configuration.file.regularFileContents {
            data = d
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - View Extension for Export UI

extension View {
    func withModel3DExportUI(_ exportManager: Model3DExportManager) -> some View {
        modifier(Model3DExportModifier(exportManager: exportManager))
    }
}

struct Model3DExportModifier: ViewModifier {
    @ObservedObject var exportManager: Model3DExportManager

    func body(content: Content) -> some View {
        content
            .fileExporter(
                isPresented: $exportManager.showUSDZExporter,
                document: exportManager.usdzDocument,
                contentType: .usdz,
                defaultFilename: "Model.usdz"
            ) { result in
                if case .success = result {
                    print("USDZ exported successfully")
                } else {
                    print("USDZ export failed")
                }
                exportManager.usdzDocument = nil
            }
            .fileExporter(
                isPresented: $exportManager.showScreenshotExporter,
                document: exportManager.screenshotDocument,
                contentType: .png,
                defaultFilename: "Screenshot.png"
            ) { result in
                if case .success = result {
                    print("Screenshot exported successfully")
                } else {
                    print("Screenshot export failed")
                }
                exportManager.screenshotDocument = nil
            }
    }
}