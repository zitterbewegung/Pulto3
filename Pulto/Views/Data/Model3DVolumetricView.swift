import SwiftUI
import RealityKit

struct Model3DVolumetricView: View {
    let windowID: Int
    let modelData: Model3DData
    @EnvironmentObject var windowManager: WindowTypeManager
    @State private var rootEntity = Entity()
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var modelEntity: Entity?
    @State private var autoRotate = true
    @State private var showWireframe = false
    @State private var modelScale: Float = 1.0

    var body: some View {
        VStack(spacing: 0) {
            controlsView
            
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
                        Text("Error:")
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
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard let model = modelEntity else { return }
                        let rotationY = Float(value.translation.width * 0.01)
                        let rotationX = Float(value.translation.height * 0.01)
                        model.transform.rotation = simd_quatf(angle: rotationY, axis: [0, 1, 0]) * simd_quatf(angle: rotationX, axis: [1, 0, 0])
                    }
            )
        }
        .task {
            await loadModel()
        }
        .onChange(of: modelScale) { _, newScale in
            updateModelScale(newScale)
        }
        .onChange(of: autoRotate) { _, shouldRotate in
            toggleAutoRotation(shouldRotate)
        }
    }
    
    private var controlsView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(modelData.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 16) {
                        Label("\(modelData.vertices.count)", systemImage: "point.3.connected.trianglepath.dotted")
                        Label("\(modelData.faces.count)", systemImage: "square.grid.3x3")
                        Label(modelData.modelType.uppercased(), systemImage: "cube.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 8) {
                        Button(action: { autoRotate.toggle() }) {
                            Image(systemName: autoRotate ? "pause.circle" : "play.circle")
                                .foregroundColor(autoRotate ? .orange : .blue)
                        }
                        .help("Toggle auto-rotation")
                        
                        Button(action: { showWireframe.toggle() }) {
                            Image(systemName: showWireframe ? "square.grid.3x3" : "cube.fill")
                                .foregroundColor(showWireframe ? .purple : .blue)
                        }
                        .help("Toggle wireframe")
                    }
                    
                    HStack(spacing: 8) {
                        Label("Scale", systemImage: "plus.magnifyingglass")
                            .font(.caption2)
                        Slider(value: $modelScale, in: 0.1...3.0, step: 0.1)
                            .frame(width: 100)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
    }
    
    @MainActor
    private func loadModel() async {
        isLoading = true
        errorMessage = nil
        
        rootEntity.children.removeAll()

        setupLighting()

        do {
            if modelData.modelType == "usdz" {
                await loadUSDZModel()
            } else {
                loadProceduralModel()
            }
            
            await finalizeModelSetup()
            
            isLoading = false
        } catch {
            print("Error loading model: \(error)")
            errorMessage = "Failed to load model: \(error.localizedDescription)"
            loadFallbackModel()
            isLoading = false
        }
    }
    
    private func setupLighting() {
        let ambientLight = Entity()
        ambientLight.components.set(DirectionalLightComponent(
            color: .white,
            intensity: 500
        ))
        ambientLight.position = SIMD3<Float>(0, 5, 5)
        ambientLight.look(at: SIMD3<Float>(0, 0, 0), from: ambientLight.position, relativeTo: nil)
        rootEntity.addChild(ambientLight)
        
        let fillLight = Entity()
        fillLight.components.set(DirectionalLightComponent(
            color: .white,
            intensity: 300
        ))
        fillLight.position = SIMD3<Float>(-3, 2, 3)
        fillLight.look(at: SIMD3<Float>(0, 0, 0), from: fillLight.position, relativeTo: nil)
        rootEntity.addChild(fillLight)
        
        let pointLight = Entity()
        pointLight.components.set(PointLightComponent(
            color: .white,
            intensity: 1000
        ))
        pointLight.position = SIMD3<Float>(2, 2, 2)
        rootEntity.addChild(pointLight)
    }
    
    private func loadUSDZModel() async {
        guard let bookmark = windowManager.getWindowSafely(for: windowID)?.state.usdzBookmark else {
            await MainActor.run {
                print("No USDZ bookmark available, loading procedural model")
                loadProceduralModel()
            }
            return
        }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
            
            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "SecurityScope", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to access security scoped resource"])
            }
            
            defer { url.stopAccessingSecurityScopedResource() }

            let loadedEntity = try await ModelEntity(contentsOf: url)
            
            await MainActor.run {
                let container = Entity()
                container.addChild(loadedEntity)
                
                container.scale = SIMD3<Float>(repeating: 2.0)
                container.position = SIMD3<Float>(0, 0, 0)
                
                rootEntity.addChild(container)
                modelEntity = container
                
                print("Successfully loaded USDZ model: \(url.lastPathComponent)")
            }
        } catch {
            await MainActor.run {
                print("Failed to load USDZ model: \(error)")
                loadProceduralModel()
            }
        }
    }
    
    private func loadProceduralModel() {
        let container = Entity()
        
        if modelData.modelType == "cube" {
            let mesh = MeshResource.generateBox(size: 2.0)
            let material = SimpleMaterial(color: .orange, roughness: 0.3, isMetallic: true)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            container.addChild(entity)
            
        } else if modelData.modelType == "sphere" {
            let mesh = MeshResource.generateSphere(radius: 1.5)
            let material = SimpleMaterial(color: .green, roughness: 0.3, isMetallic: true)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            container.addChild(entity)
            
        } else if !modelData.vertices.isEmpty && !modelData.faces.isEmpty {
            if let customEntity = createCustomMeshEntity() {
                container.addChild(customEntity)
            } else {
                createDecoratedFallback(in: container)
            }
        } else {
            createDecoratedFallback(in: container)
        }
        
        container.position = SIMD3<Float>(0, 0, 0)
        rootEntity.addChild(container)
        modelEntity = container
        
        print("Loaded procedural model of type: \(modelData.modelType)")
    }
    
    private func createCustomMeshEntity() -> ModelEntity? {
        do {
            var descr = MeshDescriptor()
            
            let positions = modelData.vertices.map { vertex in
                SIMD3<Float>(Float(vertex.x), Float(vertex.y), Float(vertex.z))
            }
            descr.positions = MeshBuffer(positions)
            
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
            
            if !triangles.isEmpty {
                descr.primitives = .triangles(triangles)
                
                let normalMesh = try MeshResource.generate(from: [descr])
                let material = SimpleMaterial(color: .cyan, roughness: 0.4, isMetallic: false)
                let entity = ModelEntity(mesh: normalMesh, materials: [material])
                
                entity.scale = SIMD3<Float>(repeating: 2.0)
                
                return entity
            }
        } catch {
            print("Failed to create custom mesh: \(error)")
        }
        
        return nil
    }
    
    private func createDecoratedFallback(in container: Entity) {
        let mainMesh = MeshResource.generateBox(size: 1.5)
        let mainMaterial = SimpleMaterial(color: .blue, roughness: 0.3, isMetallic: true)
        let mainEntity = ModelEntity(mesh: mainMesh, materials: [mainMaterial])
        container.addChild(mainEntity)
        
        for i in 0..<6 {
            let angle = Float(i) * .pi / 3
            let smallMesh = MeshResource.generateBox(size: 0.3)
            let smallMaterial = SimpleMaterial(color: .orange, roughness: 0.3, isMetallic: true)
            let smallEntity = ModelEntity(mesh: smallMesh, materials: [smallMaterial])
            
            let radius: Float = 2.0
            smallEntity.position = SIMD3<Float>(
                radius * cos(angle),
                0,
                radius * sin(angle)
            )
            container.addChild(smallEntity)
        }
        
        if let textMesh = try? MeshResource.generateText(modelData.title, extrusionDepth: 0.1) {
            let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
            textEntity.position = SIMD3<Float>(0, 2.5, 0)
            textEntity.scale = SIMD3<Float>(repeating: 0.2)
            container.addChild(textEntity)
        }
    }
    
    private func loadFallbackModel() {
        let container = Entity()
        
        let mesh = MeshResource.generateSphere(radius: 1.0)
        let material = SimpleMaterial(color: .red, roughness: 0.5, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        container.addChild(entity)
        
        if let textMesh = try? MeshResource.generateText("Error Loading Model", extrusionDepth: 0.1) {
            let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
            textEntity.position = SIMD3<Float>(0, 1.5, 0)
            textEntity.scale = SIMD3<Float>(repeating: 0.15)
            container.addChild(textEntity)
        }
        
        rootEntity.addChild(container)
        modelEntity = container
    }
    
    private func finalizeModelSetup() async {
        guard let model = modelEntity else { return }
        
        updateModelScale(modelScale)
        
        if autoRotate {
            toggleAutoRotation(true)
        }
        
        model.components.set(InputTargetComponent())
        
        let bounds = model.visualBounds(relativeTo: nil)
        let size = bounds.max - bounds.min
        let collisionShape = ShapeResource.generateBox(size: size)
        model.components.set(CollisionComponent(shapes: [collisionShape]))
        
        print("Model setup finalized - Model should now be visible")
    }
    
    private func updateModelScale(_ scale: Float) {
        guard let model = modelEntity else { return }
        model.scale = SIMD3<Float>(repeating: scale)
    }
    
    private func toggleAutoRotation(_ enabled: Bool) {
        guard let model = modelEntity else { return }
        
        if enabled {
            let rotationAnimation = FromToByAnimation(
                name: "autoRotation",
                from: Transform(rotation: simd_quatf(angle: 0, axis: [0, 1, 0])),
                to: Transform(rotation: simd_quatf(angle: .pi * 2, axis: [0, 1, 0])),
                duration: 8.0,
                timing: .linear,
                isAdditive: false
            )
            
            if let animation = try? AnimationResource.generate(with: rotationAnimation) {
                model.playAnimation(animation.repeat())
            }
        } else {
            model.stopAllAnimations()
        }
    }
}