import SwiftUI
import Charts
import RealityKit
import UniformTypeIdentifiers

// Define the point structures
struct Point2D: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
}

struct ChartPoint3D: Codable, Hashable {
    let x: Float
    let y: Float
    let z: Float

    init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
}

// Observable model for sharing data
@Observable
class ChartModel {
    static let shared = ChartModel()

    var is3D: Bool = false
    var data2D: [Point2D] = []
    var data3D: [ChartPoint3D] = []
}

// The view for importing the file
struct ImportView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var showImporter = false

    var body: some View {
        Button("Import Chart File") {
            showImporter = true
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    print("No URL selected")
                    return
                }
                do {
                    let fileContent = try String(contentsOf: url, encoding: .utf8)
                    let lines = fileContent.components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    var dim: Int? = nil
                    var tempData2D: [Point2D] = []
                    var tempData3D: [ChartPoint3D] = []

                    for line in lines {
                        let valueStrs = line.components(separatedBy: ",")
                        let values = valueStrs.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }

                        if values.isEmpty { continue }

                        if let currentDim = dim {
                            if values.count != currentDim {
                                throw NSError(domain: "Invalid data dimension", code: 1)
                            }
                        } else {
                            dim = values.count
                            if dim != 2 && dim != 3 {
                                throw NSError(domain: "Unsupported dimension", code: 2)
                            }
                        }

                        if dim == 2 {
                            tempData2D.append(Point2D(x: values[0], y: values[1]))
                        } else if dim == 3 {
                            tempData3D.append(ChartPoint3D(x: Float(values[0]), y: Float(values[1]), z: Float(values[2])))
                        }
                    }

                    if let dim = dim, !lines.isEmpty {
                        ChartModel.shared.is3D = dim == 3
                        if dim == 2 {
                            ChartModel.shared.data2D = tempData2D
                        } else {
                            ChartModel.shared.data3D = tempData3D
                        }
                        openWindow(id: "chart")
                    } else {
                        // no data
                    }
                } catch {
                    // Handle error, e.g. show alert
                    print("Error: \(error)")
                }
            case .failure(let error):
                // Handle error
                print("File import failed: \(error)")
            }
        }
    }
}

#Preview {
    ImportView()
}

// The view for displaying the chart
struct ChartDisplayView: View {
    let model = ChartModel.shared

    var body: some View {
        if !model.is3D {
            if model.data2D.isEmpty {
                Text("No data")
            } else {
                Chart(model.data2D) { point in
                    LineMark(
                        x: .value("X", point.x),
                        y: .value("Y", point.y)
                    )
                    .foregroundStyle(.blue)
                }
                .padding()
            }
        } else {
            if model.data3D.isEmpty {
                Text("No data")
            } else {
                RealityView { content in
                    let root = Entity()
                    content.add(root)

                    // Compute min, max for scaling
                    var minX = Double.infinity, minY = Double.infinity, minZ = Double.infinity
                    var maxX = -Double.infinity, maxY = -Double.infinity, maxZ = -Double.infinity
                    for p in model.data3D {
                        minX = min(minX, Double(p.x))
                        maxX = max(maxX, Double(p.x))
                        minY = min(minY, Double(p.y))
                        maxY = max(maxY, Double(p.y))
                        minZ = min(minZ, Double(p.z))
                        maxZ = max(maxZ, Double(p.z))
                    }

                    let rangeX = maxX - minX > 0 ? maxX - minX : 1.0
                    let rangeY = maxY - minY > 0 ? maxY - minY : 1.0
                    let rangeZ = maxZ - minZ > 0 ? maxZ - minZ : 1.0

                    let scale = min(min(1.0 / rangeX, 1.0 / rangeY), 1.0 / rangeZ) * 0.8

                    let offsetX = -1 * (minX + maxX) / 2.0 * scale
                    let offsetY = -1 * (minY + maxY) / 2.0 * scale
                    let offsetZ = -1 * (minZ + maxZ) / 2.0 * scale

                    // Add point spheres
                    for p in model.data3D {
                        let scaledX = Float((Double(p.x) * scale + offsetX))
                        let scaledY = Float((Double(p.y) * scale + offsetY))
                        let scaledZ = Float((Double(p.z) * scale + offsetZ))

                        let sphere = ModelEntity(
                            mesh: .generateSphere(radius: 0.01),
                            materials: [SimpleMaterial(color: .blue, roughness: 0.5, isMetallic: false)]
                        )
                        sphere.position = SIMD3(scaledX, scaledY, scaledZ)
                        root.addChild(sphere)
                    }
                }
            }
        }
    }
}

#Preview {
    ChartDisplayView()
}
