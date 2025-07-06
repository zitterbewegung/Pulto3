import RealityKit
import Foundation

// MARK: - Custom ECS Components for Data Visualization

public struct DataPointComponent: Component {
    public var value: Double
    public var category: String
    public var timestamp: Date
    public var isSelected: Bool = false
    public var originalData: [String: Any]
    
    public init(value: Double, category: String, timestamp: Date, originalData: [String: Any] = [:]) {
        self.value = value
        self.category = category
        self.timestamp = timestamp
        self.originalData = originalData
    }
}

public struct DataVisualizationMetadata: Component {
    public var datasetId: UUID
    public var visualizationType: VisualizationType
    public var scaleFactor: Float
    public var colorScheme: ColorScheme
    
    public enum VisualizationType {
        case scatter3D
        case pointCloud
        case heatmap
        case volumetric
    }
    
    public enum ColorScheme {
        case rainbow
        case thermal
        case categorical
        case custom([SIMD4<Float>])
    }
}

public struct InteractionComponent: Component {
    public var isHoverable: Bool = true
    public var isSelectable: Bool = true
    public var onHover: ((Entity) -> Void)?
    public var onSelect: ((Entity) -> Void)?
    
    public init(isHoverable: Bool = true, isSelectable: Bool = true) {
        self.isHoverable = isHoverable
        self.isSelectable = isSelectable
    }
}

// MARK: - ECS System for Data Visualization

public struct DataVisualizationSystem: System {
    static let query = EntityQuery(where: .has(DataPointComponent.self))
    
    public init(scene: RealityKit.Scene) {}
    
    public func update(context: SceneUpdateContext) {
        context.entities(matching: Self.query, updatingSystemWhen: .rendering).forEach { entity in
            updateDataPointVisualization(entity: entity, context: context)
        }
    }
    
    private func updateDataPointVisualization(entity: Entity, context: SceneUpdateContext) {
        guard let dataComponent = entity.components[DataPointComponent.self],
              let metadata = entity.components[DataVisualizationMetadata.self] else { return }
        
        // Update visualization based on data changes
        updateScale(entity: entity, value: dataComponent.value, metadata: metadata)
        updateColor(entity: entity, category: dataComponent.category, metadata: metadata)
        updateSelection(entity: entity, isSelected: dataComponent.isSelected)
    }
    
    private func updateScale(entity: Entity, value: Double, metadata: DataVisualizationMetadata) {
        let scale = Float(value) * metadata.scaleFactor
        entity.transform.scale = SIMD3<Float>(repeating: max(0.01, scale))
    }
    
    private func updateColor(entity: Entity, category: String, metadata: DataVisualizationMetadata) {
        // Update material color based on category and color scheme
        if var modelComponent = entity.components[ModelComponent.self] {
            // Update material properties
            // This would need to be implemented based on your specific material setup
        }
    }
    
    private func updateSelection(entity: Entity, isSelected: Bool) {
        // Add selection highlight
        if isSelected {
            // Add highlight material or outline
        }
    }
}
