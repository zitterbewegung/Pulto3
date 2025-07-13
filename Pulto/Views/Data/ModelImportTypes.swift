//
//  ModelImportTypes.swift
//  Pulto3
//
//  Created by Assistant on 1/13/25.
//

import Foundation
import UniformTypeIdentifiers

// MARK: - Supporting Types for Model Import

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
    case invalidURL, unsupportedFormat, fileNotFound, parsingFailed, conversionRequired
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The provided URL is not valid."
        case .unsupportedFormat: return "The model format is not supported."
        case .fileNotFound: return "Could not locate that file."
        case .parsingFailed: return "Failed to parse the model file."
        case .conversionRequired: return "This format requires conversion to USDZ for optimal display."
        }
    }
}

// MARK: - Model3DData Extensions for Additional Generators

extension Model3DData {
    
    // MARK: - Advanced Generators
    
    static func generateIcosphere(radius: Double = 2.0, subdivisions: Int = 2) -> Model3DData {
        var model = Model3DData(title: "Icosphere", modelType: "generated")
        
        let t = (1.0 + sqrt(5.0)) / 2.0
        
        // Initial icosahedron vertices
        let baseVertices = [
            Vertex3D(x: -1, y: t, z: 0),
            Vertex3D(x: 1, y: t, z: 0),
            Vertex3D(x: -1, y: -t, z: 0),
            Vertex3D(x: 1, y: -t, z: 0),
            Vertex3D(x: 0, y: -1, z: t),
            Vertex3D(x: 0, y: 1, z: t),
            Vertex3D(x: 0, y: -1, z: -t),
            Vertex3D(x: 0, y: 1, z: -t),
            Vertex3D(x: t, y: 0, z: -1),
            Vertex3D(x: t, y: 0, z: 1),
            Vertex3D(x: -t, y: 0, z: -1),
            Vertex3D(x: -t, y: 0, z: 1)
        ]
        
        // Normalize and scale
        model.vertices = baseVertices.map { vertex in
            let length = sqrt(vertex.x * vertex.x + vertex.y * vertex.y + vertex.z * vertex.z)
            return Vertex3D(
                x: vertex.x / length * radius,
                y: vertex.y / length * radius,
                z: vertex.z / length * radius
            )
        }
        
        // Initial faces
        let baseFaces = [
            [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
            [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
            [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
            [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
        ]
        
        model.faces = baseFaces.map { Face3D(vertices: $0, materialIndex: 0) }
        
        model.materials = [
            Material3D(name: "icosphere", color: "cyan", metallic: 0.3, roughness: 0.4, transparency: 0.0)
        ]
        
        return model
    }
    
    static func generateCylinder(radius: Double = 1.0, height: Double = 3.0, segments: Int = 16) -> Model3DData {
        var model = Model3DData(title: "Cylinder", modelType: "generated")
        
        // Bottom center
        model.vertices.append(Vertex3D(x: 0, y: -height/2, z: 0))
        
        // Bottom circle
        for i in 0..<segments {
            let angle = Double(i) * 2.0 * .pi / Double(segments)
            let x = radius * cos(angle)
            let z = radius * sin(angle)
            model.vertices.append(Vertex3D(x: x, y: -height/2, z: z))
        }
        
        // Top center
        model.vertices.append(Vertex3D(x: 0, y: height/2, z: 0))
        
        // Top circle
        for i in 0..<segments {
            let angle = Double(i) * 2.0 * .pi / Double(segments)
            let x = radius * cos(angle)
            let z = radius * sin(angle)
            model.vertices.append(Vertex3D(x: x, y: height/2, z: z))
        }
        
        // Bottom face
        for i in 0..<segments {
            let next = (i + 1) % segments
            model.faces.append(Face3D(vertices: [0, i + 1, next + 1], materialIndex: 0))
        }
        
        // Side faces
        for i in 0..<segments {
            let bottom1 = i + 1
            let bottom2 = (i + 1) % segments + 1
            let top1 = segments + 2 + i
            let top2 = segments + 2 + (i + 1) % segments
            
            model.faces.append(Face3D(vertices: [bottom1, bottom2, top2], materialIndex: 0))
            model.faces.append(Face3D(vertices: [bottom1, top2, top1], materialIndex: 0))
        }
        
        // Top face
        for i in 0..<segments {
            let next = (i + 1) % segments
            model.faces.append(Face3D(vertices: [segments + 1, segments + 2 + next, segments + 2 + i], materialIndex: 0))
        }
        
        model.materials = [
            Material3D(name: "cylinder", color: "yellow", metallic: 0.2, roughness: 0.5, transparency: 0.0)
        ]
        
        return model
    }
    
    static func generatePyramid(size: Double = 2.0) -> Model3DData {
        var model = Model3DData(title: "Pyramid", modelType: "generated")
        
        let halfSize = size / 2.0
        let height = size * 0.8
        
        // Base vertices
        model.vertices = [
            Vertex3D(x: -halfSize, y: -height/2, z: -halfSize),
            Vertex3D(x: halfSize, y: -height/2, z: -halfSize),
            Vertex3D(x: halfSize, y: -height/2, z: halfSize),
            Vertex3D(x: -halfSize, y: -height/2, z: halfSize),
            Vertex3D(x: 0, y: height/2, z: 0) // Apex
        ]
        
        // Base face
        model.faces.append(Face3D(vertices: [0, 1, 2, 3], materialIndex: 0))
        
        // Side faces
        model.faces.append(Face3D(vertices: [0, 4, 1], materialIndex: 0))
        model.faces.append(Face3D(vertices: [1, 4, 2], materialIndex: 0))
        model.faces.append(Face3D(vertices: [2, 4, 3], materialIndex: 0))
        model.faces.append(Face3D(vertices: [3, 4, 0], materialIndex: 0))
        
        model.materials = [
            Material3D(name: "pyramid", color: "purple", metallic: 0.1, roughness: 0.6, transparency: 0.0)
        ]
        
        return model
    }
    
    static func generateComplexCharacter(name: String) -> Model3DData {
        var model = Model3DData(title: name, modelType: "fbx")
        
        // Create a simplified humanoid figure
        // Head
        let headVertices = generateSphere(radius: 0.5, segments: 8).vertices.map { vertex in
            Vertex3D(x: vertex.x, y: vertex.y + 2.0, z: vertex.z)
        }
        model.vertices.append(contentsOf: headVertices)
        
        // Body (stretched cube)
        let bodyVertices = [
            Vertex3D(x: -0.5, y: 0.5, z: -0.3),
            Vertex3D(x: 0.5, y: 0.5, z: -0.3),
            Vertex3D(x: 0.5, y: 1.5, z: -0.3),
            Vertex3D(x: -0.5, y: 1.5, z: -0.3),
            Vertex3D(x: -0.5, y: 0.5, z: 0.3),
            Vertex3D(x: 0.5, y: 0.5, z: 0.3),
            Vertex3D(x: 0.5, y: 1.5, z: 0.3),
            Vertex3D(x: -0.5, y: 1.5, z: 0.3)
        ]
        model.vertices.append(contentsOf: bodyVertices)
        
        // Generate faces for all parts
        let headFaces = generateSphere(radius: 0.5, segments: 8).faces.map { face in
            Face3D(vertices: face.vertices, materialIndex: 0)
        }
        model.faces.append(contentsOf: headFaces)
        
        // Body faces
        let bodyStartIndex = headVertices.count
        let bodyFaces = [
            [0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1],
            [2, 6, 7, 3], [0, 3, 7, 4], [1, 5, 6, 2]
        ].map { face in
            Face3D(vertices: face.map { $0 + bodyStartIndex }, materialIndex: 1)
        }
        model.faces.append(contentsOf: bodyFaces)
        
        model.materials = [
            Material3D(name: "skin", color: "peach", metallic: 0.0, roughness: 0.7, transparency: 0.0),
            Material3D(name: "clothing", color: "blue", metallic: 0.0, roughness: 0.8, transparency: 0.0)
        ]
        
        return model
    }
    
    static func generateArchitecturalModel(name: String) -> Model3DData {
        var model = Model3DData(title: name, modelType: "dae")
        
        // Create a simple building structure
        let floorHeight = 3.0
        let buildingWidth = 4.0
        let buildingDepth = 3.0
        
        // Foundation
        let foundationVertices = [
            Vertex3D(x: -buildingWidth/2, y: 0, z: -buildingDepth/2),
            Vertex3D(x: buildingWidth/2, y: 0, z: -buildingDepth/2),
            Vertex3D(x: buildingWidth/2, y: 0, z: buildingDepth/2),
            Vertex3D(x: -buildingWidth/2, y: 0, z: buildingDepth/2),
            Vertex3D(x: -buildingWidth/2, y: floorHeight, z: -buildingDepth/2),
            Vertex3D(x: buildingWidth/2, y: floorHeight, z: -buildingDepth/2),
            Vertex3D(x: buildingWidth/2, y: floorHeight, z: buildingDepth/2),
            Vertex3D(x: -buildingWidth/2, y: floorHeight, z: buildingDepth/2)
        ]
        model.vertices.append(contentsOf: foundationVertices)
        
        // Roof vertices
        let roofVertices = [
            Vertex3D(x: -buildingWidth/2, y: floorHeight + 1.5, z: -buildingDepth/2),
            Vertex3D(x: buildingWidth/2, y: floorHeight + 1.5, z: -buildingDepth/2),
            Vertex3D(x: buildingWidth/2, y: floorHeight + 1.5, z: buildingDepth/2),
            Vertex3D(x: -buildingWidth/2, y: floorHeight + 1.5, z: buildingDepth/2),
            Vertex3D(x: 0, y: floorHeight + 2.5, z: 0) // Roof peak
        ]
        model.vertices.append(contentsOf: roofVertices)
        
        // Building faces
        let buildingFaces = [
            [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7] // Walls
        ]
        
        for face in buildingFaces {
            model.faces.append(Face3D(vertices: face, materialIndex: 0))
        }
        
        // Roof faces
        let roofStartIndex = foundationVertices.count
        let roofFaces = [
            [0, 1, 4], [1, 2, 4], [2, 3, 4], [3, 0, 4] // Triangular roof faces
        ].map { face in
            Face3D(vertices: face.map { $0 + roofStartIndex }, materialIndex: 1)
        }
        model.faces.append(contentsOf: roofFaces)
        
        model.materials = [
            Material3D(name: "wall", color: "lightgray", metallic: 0.0, roughness: 0.8, transparency: 0.0),
            Material3D(name: "roof", color: "darkred", metallic: 0.0, roughness: 0.9, transparency: 0.0)
        ]
        
        return model
    }
    
    static func generateInteractiveModel(name: String) -> Model3DData {
        var model = Model3DData(title: name, modelType: "x3d")
        
        // Create an interactive-style model with multiple connected components
        let centerSphere = generateSphere(radius: 1.0, segments: 12)
        model.vertices.append(contentsOf: centerSphere.vertices)
        model.faces.append(contentsOf: centerSphere.faces)
        
        // Add orbiting smaller spheres
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3.0
            let orbitRadius = 2.5
            let x = orbitRadius * cos(angle)
            let z = orbitRadius * sin(angle)
            
            let orbitSphere = generateSphere(radius: 0.3, segments: 8).vertices.map { vertex in
                Vertex3D(x: vertex.x + x, y: vertex.y, z: vertex.z + z)
            }
            
            let startIndex = model.vertices.count
            model.vertices.append(contentsOf: orbitSphere)
            
            let orbitFaces = generateSphere(radius: 0.3, segments: 8).faces.map { face in
                Face3D(vertices: face.vertices.map { $0 + startIndex }, materialIndex: 1)
            }
            model.faces.append(contentsOf: orbitFaces)
        }
        
        model.materials = [
            Material3D(name: "center", color: "gold", metallic: 0.8, roughness: 0.2, transparency: 0.0),
            Material3D(name: "orbiter", color: "silver", metallic: 0.6, roughness: 0.3, transparency: 0.0)
        ]
        
        return model
    }
    
    static func generateMechanicalPart(name: String) -> Model3DData {
        var model = Model3DData(title: name, modelType: "3mf")
        
        // Create a gear-like mechanical part
        let centerRadius = 1.0
        let toothRadius = 1.3
        let thickness = 0.5
        let toothCount = 12
        
        // Center hub vertices (top and bottom)
        for layer in 0...1 {
            let y = Double(layer) * thickness - thickness/2
            
            // Center points
            model.vertices.append(Vertex3D(x: 0, y: y, z: 0))
            
            // Inner circle
            for i in 0..<toothCount {
                let angle = Double(i) * 2.0 * .pi / Double(toothCount)
                let x = centerRadius * cos(angle)
                let z = centerRadius * sin(angle)
                model.vertices.append(Vertex3D(x: x, y: y, z: z))
            }
            
            // Outer teeth
            for i in 0..<toothCount {
                let angle = Double(i) * 2.0 * .pi / Double(toothCount)
                let x = toothRadius * cos(angle)
                let z = toothRadius * sin(angle)
                model.vertices.append(Vertex3D(x: x, y: y, z: z))
            }
        }
        
        // Generate faces for the gear
        let pointsPerLayer = 1 + toothCount * 2
        
        // Top and bottom faces
        for layer in 0...1 {
            let layerStart = layer * pointsPerLayer
            
            // Inner hub faces
            for i in 0..<toothCount {
                let next = (i + 1) % toothCount
                if layer == 0 {
                    model.faces.append(Face3D(vertices: [layerStart, layerStart + 1 + i, layerStart + 1 + next], materialIndex: 0))
                } else {
                    model.faces.append(Face3D(vertices: [layerStart, layerStart + 1 + next, layerStart + 1 + i], materialIndex: 0))
                }
            }
        }
        
        model.materials = [
            Material3D(name: "steel", color: "silver", metallic: 0.9, roughness: 0.1, transparency: 0.0)
        ]
        
        return model
    }
    
    static func generateSceneGraphModel(name: String) -> Model3DData {
        var model = Model3DData(title: name, modelType: "scn")
        
        // Create a hierarchical scene representation
        // Root node (cube) - use existing generateCube method
        let rootCube = generateCube(size: 1.0)
        model.vertices.append(contentsOf: rootCube.vertices)
        model.faces.append(contentsOf: rootCube.faces)
        
        // Child nodes (smaller cubes at different positions)
        let childPositions = [
            (2.0, 1.0, 0.0),
            (-2.0, 1.0, 0.0),
            (0.0, 1.0, 2.0),
            (0.0, 1.0, -2.0)
        ]
        
        for (index, position) in childPositions.enumerated() {
            let childCube = generateCube(size: 0.5).vertices.map { vertex in
                Vertex3D(x: vertex.x + position.0, y: vertex.y + position.1, z: vertex.z + position.2)
            }
            
            let startIndex = model.vertices.count
            model.vertices.append(contentsOf: childCube)
            
            let childFaces = generateCube(size: 0.5).faces.map { face in
                Face3D(vertices: face.vertices.map { $0 + startIndex }, materialIndex: 1)
            }
            model.faces.append(contentsOf: childFaces)
        }
        
        model.materials = [
            Material3D(name: "root_node", color: "red", metallic: 0.2, roughness: 0.6, transparency: 0.0),
            Material3D(name: "child_node", color: "green", metallic: 0.2, roughness: 0.6, transparency: 0.0)
        ]
        
        return model
    }
    
    static func generateSphere(radius: Double, segments: Int) -> Model3DData {
        var model = Model3DData(title: "Sphere", modelType: "generated")
        
        let vertices: [Vertex3D] = []
        let faces: [Face3D] = []
        
        model.vertices = vertices
        model.faces = faces
        model.materials = [
            Material3D(name: "sphere_material", color: "blue", metallic: 0.5, roughness: 0.7, transparency: 0.0)
        ]
        
        return model
    }
    
    static func generateCube(size: Double) -> Model3DData {
        var model = Model3DData(title: "Cube", modelType: "generated")
        
        let vertices: [Vertex3D] = []
        let faces: [Face3D] = []
        
        model.vertices = vertices
        model.faces = faces
        model.materials = [
            Material3D(name: "cube_material", color: "black", metallic: 0.2, roughness: 0.8, transparency: 0.0)
        ]
        
        return model
    }
}