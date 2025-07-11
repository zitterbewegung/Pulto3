//
//  Chart3DView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/10/25.
//  Copyright © 2025 Apple. All rights reserved.
//


import SwiftUI
import RealityKit
import Foundation

struct Chart3DView: View {
    let dataURL: URL?  // Optional URL for the JSON data (defaults to iCloud or bundle)

    var body: some View {
        RealityView { content in
            if let chartEntity = await load3DChart() {
                content.add(chartEntity)
            }
        }
        .frame(width: 400, height: 300)  // Adjust size per instance
        .background(Color.gray.opacity(0.2))  // Optional styling for visibility
    }

    func load3DChart() async -> Entity? {
        let chartEntity = Entity()

        // Use provided dataURL or fallback to default iCloud/bundle path
        let url = dataURL ??
                  FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/chart_data.json") ??
                  Bundle.main.url(forResource: "chart_data", withExtension: "json")

        guard let url = url else {
            print("Failed to find JSON file")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let json = try JSONDecoder().decode(Chart3DData.self, from: data)

            // Create spheres for each data point
            for point in json.points {
                let sphere = MeshResource.generateSphere(radius: 0.02)
                let material = SimpleMaterial(color: .blue, isMetallic: false)
                let pointEntity = ModelEntity(mesh: sphere, materials: [material])
                pointEntity.position = SIMD3<Float>(point.x, point.y, point.z)
                chartEntity.addChild(pointEntity)
            }

            // Add axes for reference
            chartEntity.addChild(createAxis(color: .red, direction: .x))
            chartEntity.addChild(createAxis(color: .green, direction: .y))
            chartEntity.addChild(createAxis(color: .blue, direction: .z))

            // Enable interactions
            chartEntity.components.set(InputTargetComponent())
            chartEntity.components.set(CollisionComponent(shapes: [.generateBox(width: 1, height: 1, depth: 1)]))

            return chartEntity
        } catch {
            print("Error loading data: \(error)")
            return nil
        }
    }

    func createAxis(color: UIColor, direction: AxisDirection) -> Entity {
        let axis = Entity()
        let mesh = MeshResource.generateBox(width: direction == .x ? 1.0 : 0.01,
                                            height: direction == .y ? 1.0 : 0.01,
                                            depth: direction == .z ? 1.0 : 0.01)
        let material = SimpleMaterial(color: color, isMetallic: false)
        let axisModel = ModelEntity(mesh: mesh, materials: [material])
        axisModel.position = SIMD3<Float>(direction == .x ? 0.5 : 0,
                                          direction == .y ? 0.5 : 0,
                                          direction == .z ? 0.5 : 0)
        axis.addChild(axisModel)
        return axis
    }

    enum AxisDirection {
        case x, y, z
    }
}

// MARK: - Chart3D Support

struct Chart3DData: Codable, Equatable, Hashable {
    let points: [Point3D]

    static func == (lhs: Chart3DData, rhs: Chart3DData) -> Bool {
        lhs.points == rhs.points
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(points)
    }

    static func defaultData() -> Chart3DData {
        var points: [Point3D] = []
        for _ in 0..<50 {
            let x = Float.random(in: 0..<1)
            let y = Float.random(in: 0..<1)
            let z = Float(sin(x * 2 * .pi) + cos(y * 2 * .pi))
            points.append(Point3D(x: x, y: y, z: z))
        }
        return Chart3DData(points: points)
    }
}

struct Point3D: Codable, Hashable {
    let x: Float
    let y: Float
    let z: Float
}

struct Chart3DVolumetricView: View {
    let windowID: Int
    let chartData: Chart3DData

    var body: some View {
        RealityView { content in
            if let chartEntity = create3DChartEntity() {
                content.add(chartEntity)
            }
        }
        .frame(width: 400, height: 300)  // Adjust size as needed
        .background(Color.gray.opacity(0.2))  // Optional styling
    }

    private func create3DChartEntity() -> Entity? {
        let chartEntity = Entity()

        // Create spheres for each data point
        for point in chartData.points {
            let sphere = MeshResource.generateSphere(radius: 0.02)
            let material = SimpleMaterial(color: .blue, isMetallic: false)
            let pointEntity = ModelEntity(mesh: sphere, materials: [material])
            pointEntity.position = SIMD3<Float>(point.x, point.y, point.z)
            chartEntity.addChild(pointEntity)
        }

        // Add axes for reference
        chartEntity.addChild(createAxis(color: .red, direction: .x))
        chartEntity.addChild(createAxis(color: .green, direction: .y))
        chartEntity.addChild(createAxis(color: .blue, direction: .z))

        // Enable interactions
        chartEntity.components.set(InputTargetComponent())
        chartEntity.components.set(CollisionComponent(shapes: [.generateBox(width: 1, height: 1, depth: 1)]))

        return chartEntity
    }

    private func createAxis(color: UIColor, direction: AxisDirection) -> Entity {
        let axis = Entity()
        let mesh = MeshResource.generateBox(width: direction == .x ? 1.0 : 0.01,
                                            height: direction == .y ? 1.0 : 0.01,
                                            depth: direction == .z ? 1.0 : 0.01)
        let material = SimpleMaterial(color: color, isMetallic: false)
        let axisModel = ModelEntity(mesh: mesh, materials: [material])
        axisModel.position = SIMD3<Float>(direction == .x ? 0.5 : 0,
                                          direction == .y ? 0.5 : 0,
                                          direction == .z ? 0.5 : 0)
        axis.addChild(axisModel)
        return axis
    }

    private enum AxisDirection {
        case x, y, z
    }
}

// MARK: - SwiftUI Preview

private extension URL {
    /// Writes a tiny three-point JSON file the first time it’s called,
    /// then returns its URL. Replace with your own resource if you like.
    static func previewSampleChartDataURL() -> URL {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("sample_chart_data.json")
        if !FileManager.default.fileExists(atPath: tmp.path) {
            let sampleJSON = """
            {
              "points": [
                { "x": 0.0, "y": 0.0, "z": 0.0 },
                { "x": 0.3, "y": 0.5, "z": 0.2 },
                { "x": 0.6, "y": 0.8, "z": 0.4 }
              ]
            }
            """
            try? Data(sampleJSON.utf8).write(to: tmp)
        }
        return tmp
    }
}

#Preview("Sample 3-D Chart", traits: .fixedLayout(width: 400, height: 300)) {
    Chart3DView(dataURL: .previewSampleChartDataURL())
        .glassBackgroundEffect()   // optional translucent frame
        .padding()
}
