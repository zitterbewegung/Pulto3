import SwiftUI
import SceneKit

// Function to generate and save sample point cloud (call this from a button or onAppear)
func generateSamplePointCloud() {
    // Generate 100 random points on a sphere with varying radius (0.5 to 1.0)
    var points: [SCNVector3] = []
    for _ in 0..<100 {
        let theta = Float(drand48()) * 2 * Float.pi  // Random theta (0 to 2π)
        let u = Float(drand48())  // Random u (0 to 1) for phi calculation
        let phi = acos(1 - 2 * u)  // Uniform distribution on sphere
        let r = 0.5 + Float(drand48()) * 0.5  // Vary radius

        let x = r * sin(phi) * cos(theta)
        let y = r * sin(phi) * sin(theta)
        let z = r * cos(phi)
        
        points.append(SCNVector3(x, y, z))
    }

    // Save to CSV in Documents directory
    var csvString = "x,y,z\n"
    for point in points {
        csvString += "\(point.x),\(point.y),\(point.z)\n"
    }
    if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let csvURL = documentsURL.appendingPathComponent("sphere_point_cloud.csv")
        try? csvString.write(to: csvURL, atomically: true, encoding: .utf8)
        print("CSV saved to: \(csvURL.path)")  // Visible in Xcode console
    }

    // Create SceneKit geometry for point cloud
    let vertexSource = SCNGeometrySource(vertices: points)
    let element = SCNGeometryElement(primitiveType: .points, primitiveCount: points.count, bytesPerIndex: 0)
    let geometry = SCNGeometry(sources: [vertexSource], elements: [element])

    // Set a material for visibility (optional)
    geometry.firstMaterial?.diffuse.contents = UIColor.red
    geometry.firstMaterial?.lightingModel = .constant

    // Create node and scene
    let node = SCNNode(geometry: geometry)
    let scene = SCNScene()
    scene.rootNode.addChildNode(node)

    // Export to USDZ in Documents directory
    if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let usdzURL = documentsURL.appendingPathComponent("sphere_point_cloud.usdz")
        do {
            try scene.write(to: usdzURL, options: nil, delegate: nil, progressHandler: nil)
            print("USDZ saved to: \(usdzURL.path)")
        } catch {
            print("Error exporting USDZ: \(error)")
        }
    }
}