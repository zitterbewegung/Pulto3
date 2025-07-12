import SwiftUI
import RealityKit

struct Model3DVolumetricView: View {
    let windowID: Int
    let modelData: Model3DData
    @EnvironmentObject var windowManager: WindowTypeManager
    @State private var rootEntity = Entity()

    var body: some View {
        RealityView { content in
            content.add(rootEntity)
        }
        .onAppear {
            Task {
                await loadModel()
            }
        }
    }

    @MainActor
    private func loadModel() async {
        // Clear existing children
        rootEntity.children.removeAll()

        // Add ambient lighting (point light for omnidirectional effect)
        let ambientLight = PointLightComponent(color: UIColor.white, intensity: 300, attenuationRadius: 10.0)
        let ambientLightEntity = Entity()
        ambientLightEntity.components.set(ambientLight)
        ambientLightEntity.position = SIMD3<Float>(0, 2, 0)
        rootEntity.addChild(ambientLightEntity)

        // Add directional lighting
        let directionalLight = DirectionalLightComponent(color: UIColor.white, intensity: 500)
        let directionalLightEntity = Entity()
        directionalLightEntity.components.set(directionalLight)
        directionalLightEntity.look(at: SIMD3<Float>(0, 0, 0), from: SIMD3<Float>(2, 2, 2), upVector: SIMD3<Float>(0, 1, 0), relativeTo: nil)
        rootEntity.addChild(directionalLightEntity)

        // Add loading entity
        let loadingEntity = createLoadingEntity()
        rootEntity.addChild(loadingEntity)

        do {
            if modelData.modelType == "usdz" {
                try await loadUSDZModel()
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

            // Remove loading and add info
            loadingEntity.removeFromParent()
            let infoEntity = createInfoEntity()
            rootEntity.addChild(infoEntity)
        } catch {
            loadingEntity.removeFromParent()
            let errorEntity = createErrorEntity(with: error.localizedDescription)
            rootEntity.addChild(errorEntity)
        }
    }

    private func createLoadingEntity() -> Entity {
        let entity = Entity()
        entity.components.set(BillboardComponent())
        entity.position = SIMD3<Float>(0, 0, 0)

        // Loading text
        if let textMesh = try? MeshResource.generateText("Loading 3D Model...", extrusionDepth: 0.005, font: .systemFont(ofSize: 0.05)) {
            let material = SimpleMaterial(color: .white, isMetallic: false)
            let textEntity = ModelEntity(mesh: textMesh, materials: [material])
            textEntity.position = SIMD3<Float>(0, 0.1, 0)
            entity.addChild(textEntity)
        }

        // Spinning sphere as progress indicator
        let spinnerMesh = MeshResource.generateSphere(radius: 0.05)
        let spinnerMaterial = SimpleMaterial(color: .blue, roughness: 0.1, isMetallic: true)
        let spinner = ModelEntity(mesh: spinnerMesh, materials: [spinnerMaterial])
        spinner.position = SIMD3<Float>(0, -0.05, 0)
        entity.addChild(spinner)

        // Animate spinner
        let fromTransform = spinner.transform
        var toTransform = fromTransform
        toTransform.rotation = simd_quatf(angle: Float.pi * 2, axis: SIMD3<Float>(1, 1, 0))
        let animDefinition = FromToByAnimation(
            from: fromTransform,
            to: toTransform,
            duration: 2.0,
            bindTarget: .transform,
            repeatMode: .repeat
        )
        if let anim = try? AnimationResource.generate(with: animDefinition) {
            spinner.playAnimation(anim)
        }

        return entity
    }

    private func createErrorEntity(with message: String) -> Entity {
        let entity = Entity()
        entity.components.set(BillboardComponent())
        entity.position = SIMD3<Float>(0, 0, 0)

        // Error icon (using text as approximation, or use a model if available)
        if let iconMesh = try? MeshResource.generateText("!", extrusionDepth: 0.005, font: .systemFont(ofSize: 0.1)) {
            let material = SimpleMaterial(color: .orange, isMetallic: false)
            let iconEntity = ModelEntity(mesh: iconMesh, materials: [material])
            iconEntity.position = SIMD3<Float>(0, 0.15, 0)
            entity.addChild(iconEntity)
        }

        // Error title
        if let titleMesh = try? MeshResource.generateText("Error loading model:", extrusionDepth: 0.005, font: .systemFont(ofSize: 0.05)) {
            let material = SimpleMaterial(color: .white, isMetallic: false)
            let titleEntity = ModelEntity(mesh: titleMesh, materials: [material])
            titleEntity.position = SIMD3<Float>(0, 0.05, 0)
            entity.addChild(titleEntity)
        }

        // Error message
        if let msgMesh = try? MeshResource.generateText(message, extrusionDepth: 0.005, font: .systemFont(ofSize: 0.03)) {
            let material = SimpleMaterial(color: .gray, isMetallic: false)
            let msgEntity = ModelEntity(mesh: msgMesh, materials: [material])
            msgEntity.position = SIMD3<Float>(0, -0.05, 0)
            entity.addChild(msgEntity)
        }

        return entity
    }

    private func createInfoEntity() -> Entity {
        let entity = Entity()
        entity.components.set(BillboardComponent())
        entity.position = SIMD3<Float>(-0.4, 0.3, 0)  // Approximate top-leading position

        // Title
        if let titleMesh = try? MeshResource.generateText(modelData.title, extrusionDepth: 0.005, font: .systemFont(ofSize: 0.06, weight: .bold)) {
            let material = SimpleMaterial(color: .white, isMetallic: false)
            let titleEntity = ModelEntity(mesh: titleMesh, materials: [material])
            titleEntity.position = SIMD3<Float>(0, 0.15, 0)
            entity.addChild(titleEntity)
        }

        // Vertices and faces (without icons for simplicity)
        if let verticesMesh = try? MeshResource.generateText("\(modelData.vertices.count) vertices", extrusionDepth: 0.005, font: .systemFont(ofSize: 0.03)) {
            let material = SimpleMaterial(color: .white, isMetallic: false)
            let verticesEntity = ModelEntity(mesh: verticesMesh, materials: [material])
            verticesEntity.position = SIMD3<Float>(-0.1, 0.05, 0)
            entity.addChild(verticesEntity)
        }

        if let facesMesh = try? MeshResource.generateText("\(modelData.faces.count) faces", extrusionDepth: 0.005, font: .systemFont(ofSize: 0.03)) {
            let material = SimpleMaterial(color: .white, isMetallic: false)
            let facesEntity = ModelEntity(mesh: facesMesh, materials: [material])
            facesEntity.position = SIMD3<Float>(0.1, 0.05, 0)
            entity.addChild(facesEntity)
        }

        // Type
        if let typeMesh = try? MeshResource.generateText("Type: \(modelData.modelType)", extrusionDepth: 0.005, font: .systemFont(ofSize: 0.03)) {
            let material = SimpleMaterial(color: .gray, isMetallic: false)
            let typeEntity = ModelEntity(mesh: typeMesh, materials: [material])
            typeEntity.position = SIMD3<Float>(0, -0.05, 0)
            entity.addChild(typeEntity)
        }

        return entity
    }

    private func loadUSDZModel() async throws {
        guard let bookmark = windowManager.getWindowSafely(for: windowID)?.state.usdzBookmark else {
            throw NSError(domain: "ModelError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No USDZ file available"])
        }

        var isStale = false
        let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)

        if let url = url, isStale {
            // Recreate bookmark if stale
            let newBookmark = try? url.bookmarkData()
            if let newBookmark {
                windowManager.updateUSDZBookmark(for: windowID, bookmark: newBookmark)
            }
        }

        guard let url = url, url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "SecurityScope", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to access security scoped resource"])
        }

        defer { url.stopAccessingSecurityScopedResource() }

        let modelEntity = try await ModelEntity(contentsOf: url)

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

    private func loadCubeModel() {
        let size = max(0.1, Float(modelData.scale))
        let mesh = MeshResource.generateBox(size: size)

        // Use material from modelData if available, otherwise default
        let color: UIColor = modelData.materials.first.flatMap { UIColor(named: $0.color) } ?? .orange

        let material = SimpleMaterial(color: color, roughness: 0.15, isMetallic: true)
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])

        modelEntity.position = SIMD3<Float>(
            Float(modelData.position.x),
            Float(modelData.position.y),
            Float(modelData.position.z)
        )

        // Add subtle animation
        let fromTransform = modelEntity.transform
        var toTransform = fromTransform
        toTransform.rotation = simd_quatf(angle: Float.pi * 2, axis: SIMD3<Float>(0, 1, 0))

        let rotationDefinition = FromToByAnimation(
            from: fromTransform,
            to: toTransform,
            duration: 4.0,
            bindTarget: .transform,
            repeatMode: .repeat  // Corrected to .repeat for continuous rotation
        )

        if let rotationAnimation = try? AnimationResource.generate(with: rotationDefinition) {
            modelEntity.playAnimation(rotationAnimation)
        }

        rootEntity.addChild(modelEntity)
        print("✅ Loaded cube model with size: \(size)")
    }

    private func loadSphereModel() {
        let radius = max(0.1, Float(modelData.scale))
        let mesh = MeshResource.generateSphere(radius: radius)

        // Use material from modelData if available, otherwise default
        let color: UIColor = modelData.materials.first.flatMap { UIColor(named: $0.color) } ?? .green

        let material = SimpleMaterial(color: color, roughness: 0.1, isMetallic: true)
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])

        modelEntity.position = SIMD3<Float>(
            Float(modelData.position.x),
            Float(modelData.position.y),
            Float(modelData.position.z)
        )

        // Add subtle floating animation
        let fromTransform = Transform.identity
        let toTransform = Transform(translation: SIMD3<Float>(0, 0.2, 0))

        let floatDefinition = FromToByAnimation(
            from: fromTransform,
            to: toTransform,
            duration: 2.0,
            bindTarget: .transform,
            repeatMode: .autoReverse
        )

        if let floatAnimation = try? AnimationResource.generate(with: floatDefinition) {
            modelEntity.playAnimation(floatAnimation)
        }

        rootEntity.addChild(modelEntity)
        print("✅ Loaded sphere model with radius: \(radius)")
    }

    private func loadCustomMesh() throws {
        guard !modelData.vertices.isEmpty, !modelData.faces.isEmpty else {
            throw NSError(domain: "ModelError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No vertices or faces data"])
        }

        var descr = MeshDescriptor()
        let positions = modelData.vertices.map { vertex in
            SIMD3<Float>(Float(vertex.x), Float(vertex.y), Float(vertex.z))
        }
        descr.positions = MeshBuffer(positions)

        // Generate normals if not provided
        if let modelNormals = modelData.normals, !modelNormals.isEmpty {
            let normals = modelNormals.map { normal in
                SIMD3<Float>(Float(normal.x), Float(normal.y), Float(normal.z))
            }
            descr.normals = MeshBuffer(normals)
        }

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
        print("✅ Loaded custom mesh with \(modelData.vertices.count) vertices and \(modelData.faces.count) faces")
    }

    private func loadFallbackModel() {
        let mesh = MeshResource.generateBox(size: 0.5)
        let material = SimpleMaterial(color: .gray, roughness: 0.5, isMetallic: false)
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])

        // Add a text entity to indicate this is a fallback
        if let textMesh = try? MeshResource.generateText("No Model Data", extrusionDepth: 0.05) {
            let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
            textEntity.position = SIMD3<Float>(0, 0.8, 0)
            textEntity.scale = SIMD3<Float>(repeating: 0.3)
            rootEntity.addChild(textEntity)
        }

        rootEntity.addChild(modelEntity)
        print("⚠️ Loaded fallback model")
    }
}
