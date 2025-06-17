import RealityKit

class PointCloudEntity: Entity {
    func loadPointCloud(from url: URL) async throws {
        let pointData = try await PointCloudLoader.load(url)
        
        // Use Metal for efficient rendering
        let mesh = try await MeshResource.generatePointCloud(
            points: pointData.positions,
            colors: pointData.colors
        )
        
        let material = UnlitMaterial(color: .white)
        self.components[ModelComponent.self] = ModelComponent(
            mesh: mesh,
            materials: [material]
        )
    }
}
