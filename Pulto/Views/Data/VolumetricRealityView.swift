struct VolumetricRealityView: View {
    @EnvironmentObject var modelManager: ModelManager
    @State private var loadedEntity: Entity?
    @State private var isLoading = true
    
    var body: some View {
        RealityView { content in
            // Setup scene
            setupScene(content: content)
            
        } update: { content in
            // Update when model changes
            if let modelURL = modelManager.modelURL {
                Task {
                    await loadModel(url: modelURL, content: content)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if isLoading {
                ProgressView("Loading Model...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
    }
    
    private func setupScene(content: RealityViewContent) {
        // Add lighting
        let lightEntity = Entity()
        lightEntity.components.set(DirectionalLightComponent(
            color: .white,
            intensity: 5000,
            isRealWorldProxy: true
        ))
        lightEntity.transform.rotation = simd_quatf(angle: -.pi/4, axis: [1, 0, 0])
        content.add(lightEntity)
    }
    
    @MainActor
    private func loadModel(url: URL, content: RealityViewContent) async {
        isLoading = true
        
        // Remove previous model
        if let existing = loadedEntity {
            content.remove(existing)
        }
        
        do {
            // Load the model
            let entity = try await Entity(contentsOf: url)
            
            // Calculate bounds and scale appropriately
            let bounds = entity.visualBounds(relativeTo: nil)
            let maxDimension = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
            let targetSize: Float = 0.3 // 30cm target size
            let scale = targetSize / maxDimension
            
            entity.scale = [scale, scale, scale]
            entity.position = [0, 0, 0]
            
            // Add interaction components
            entity.components.set(InputTargetComponent())
            entity.components.set(CollisionComponent(shapes: [.generateConvex(from: entity)]))
            
            content.add(entity)
            loadedEntity = entity
            
        } catch {
            print("Failed to load model: \(error)")
        }
        
        isLoading = false
    }
}