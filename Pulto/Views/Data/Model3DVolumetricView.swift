import SwiftUI
import RealityKit

struct Model3DVolumetricView: View {
    let windowID: Int
    let modelData: Model3DData
    @EnvironmentObject var windowManager: WindowTypeManager
    @State private var rootEntity = Entity()
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        RealityView { content in
            content.add(rootEntity)
        }
        .overlay(alignment: .center) {
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading 3D Model...")
                        .font(.headline)
                        .padding(.top)
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
            } else if let error = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Error loading model:")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
            }
        }
        .overlay(alignment: .topLeading) {
            if !isLoading && errorMessage == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text(modelData.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack {
                        Label("\(modelData.vertices.count) vertices", systemImage: "point.3.connected.trianglepath.dotted")
                        Label("\(modelData.faces.count) faces", systemImage: "square.grid.3x3")
                    }
                    .font(.caption)

                    Text("Type: \(modelData.modelType)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
                .padding()
            }
        }
        .onAppear {
            if modelData.modelType == "usdz" {
                if let textMesh = try? MeshResource.generateText("Loading USDZ...") {
                    let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
                    let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
                    rootEntity.addChild(textEntity)
                }
            }
        }
        .task {
            await loadModel()
        }
    }
    
    @MainActor
    private func loadModel() async {
        isLoading = true
        errorMessage = nil
        
        // Clear existing children
        rootEntity.children.removeAll()

        // Add lighting
        let light = PointLight()
        light.light.intensity = 1000
        light.position = SIMD3<Float>(0, 1, 1)
        rootEntity.addChild(light)

        do {
            if modelData.modelType == "usdz" {
                await loadUSDZModel()
            } else if modelData.modelType == "cube" {
                loadCubeModel()
            } else if modelData.modelType == "sphere" {
                loadSphereModel()
            } else if !modelData.vertices.isEmpty && !modelData.faces.isEmpty {
                try loadCustomMesh()
            } else {
                // Fallback to a simple cube if no data
                loadFallbackModel()
            }
            
            isLoading = false
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func loadUSDZModel() async {
        guard let bookmark = windowManager.getWindowSafely(for: windowID)?.state.usdzBookmark else {
            await MainActor.run {
                errorMessage = "No USDZ file available"
            }
            return
        }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)

            if isStale {
                // Recreate bookmark if stale
                let newBookmark = try url.bookmarkData()
                await MainActor.run {
                    windowManager.updateUSDZBookmark(for: windowID, bookmark: newBookmark)
                }
            }

            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "SecurityScope", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to access security scoped resource"])
            }
            
            defer { url.stopAccessingSecurityScopedResource() }

            let modelEntity = try await ModelEntity(contentsOf: url)

            await MainActor.run {
                // Apply transformations from modelData
                modelEntity.scale = SIMD3<Float>(repeating: Float(modelData.scale))
                modelEntity.position = SIMD3<Float>(
                    Float(modelData.position.x),
                    Float(modelData.position.y),
                    Float(modelData.position.z)
                )

                // Apply rotation if needed
                modelEntity.orientation = simd_quatf(
                    angle: Float(modelData.rotation.x * .pi / 180),
                    axis: SIMD3<Float>(1, 0, 0)
                ) * simd_quatf(
                    angle: Float(modelData.rotation.y * .pi / 180),
                    axis: SIMD3<Float>(0, 1, 0)
                ) * simd_quatf(
                    angle: Float(modelData.rotation.z * .pi / 180),
                    axis: SIMD3<Float>(0, 0, 1)
                )

                rootEntity.addChild(modelEntity)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load USDZ: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadCubeModel() {
        let mesh = MeshResource.generateBox(size: Float(modelData.scale))
        let material = SimpleMaterial(color: .orange, roughness: 0.5, isMetallic: true)
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])

        modelEntity.position = SIMD3<Float>(
            Float(modelData.position.x),
            Float(modelData.position.y),
            Float(modelData.position.z)
        )

        rootEntity.addChild(modelEntity)
    }
    
    private func loadSphereModel() {
        let mesh = MeshResource.generateSphere(radius: Float(modelData.scale))
        let material = SimpleMaterial(color: .green, roughness: 0.3, isMetallic: true)
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])

        modelEntity.position = SIMD3<Float>(
            Float(modelData.position.x),
            Float(modelData.position.y),
            Float(modelData.position.z)
        )

        rootEntity.addChild(modelEntity)
    }
    
    private func loadCustomMesh() throws {
        var descr = MeshDescriptor()
        let positions = modelData.vertices.map { vertex in
            SIMD3<Float>(Float(vertex.x), Float(vertex.y), Float(vertex.z))
        }
        descr.positions = MeshBuffer(positions)

        let material = SimpleMaterial(color: .blue, roughness: 0.5, isMetallic: false)

        var triangles: [UInt32] = []
        for face in modelData.faces {
            if face.vertices.count >= 3 {
                for i in 1..<(face.vertices.count - 1) {
                    triangles.append(UInt32(face.vertices[0]))
                    triangles.append(UInt32(face.vertices[i]))
                    triangles.append(UInt32(face.vertices[i + 1]))
                }
            }
        }

        descr.primitives = .triangles(triangles)

        let mesh = try MeshResource.generate(from: [descr])
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        modelEntity.scale = SIMD3<Float>(repeating: Float(modelData.scale))
        modelEntity.position = SIMD3<Float>(
            Float(modelData.position.x),
            Float(modelData.position.y),
            Float(modelData.position.z)
        )

        rootEntity.addChild(modelEntity)
    }
    
    private func loadFallbackModel() {
        let mesh = MeshResource.generateBox(size: 1.0)
        let material = SimpleMaterial(color: .gray, roughness: 0.5, isMetallic: false)
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        
        // Add a text entity to indicate this is a fallback
        if let textMesh = try? MeshResource.generateText("No Model Data", extrusionDepth: 0.1) {
            let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
            textEntity.position = SIMD3<Float>(0, 1.5, 0)
            textEntity.scale = SIMD3<Float>(repeating: 0.5)
            rootEntity.addChild(textEntity)
        }

        rootEntity.addChild(modelEntity)
    }
}