//  Enhanced NewWindowID.swift with Point Cloud Integration
//  UnderstandingVisionos
//
//  Created by Joshua Herman on 5/25/25.
//

import SwiftUI
import Foundation
import Charts

// ─────────────────────────────────────────────────────────────
// MARK: - Window metadata
// ─────────────────────────────────────────────────────────────

enum WindowType: String, CaseIterable, Codable, Hashable {
    case charts      = "Charts"
    case spatial     = "Spatial Editor"
    case column      = "DataFrame Viewer"
    case volume      = "Model Metric Viewer"
    case pointcloud  = "Point Cloud Viewer"
    case model3d     = "3D Model Viewer"

    var displayName: String { rawValue }

    var jupyterCellType: String {
        switch self {
        case .charts, .column, .volume, .pointcloud, .model3d: "code"
        case .spatial: "spatial"
        }
    }
}

struct WindowPosition: Codable, Hashable, Equatable {
    var x, y, z: Double
    var width, height: Double
    var depth: Double?

    init(x: Double = 0, y: Double = 0, z: Double = 0,
         width: Double = 400, height: Double = 300, depth: Double? = nil) {
        (self.x, self.y, self.z) = (x, y, z)
        (self.width, self.height) = (width, height)
        self.depth = depth
    }

    static func == (lhs: WindowPosition, rhs: WindowPosition) -> Bool {
        return lhs.x == rhs.x &&
               lhs.y == rhs.y &&
               lhs.z == rhs.z &&
               lhs.width == rhs.width &&
               lhs.height == rhs.height &&
               lhs.depth == rhs.depth
    }
}

enum ExportTemplate: String, CaseIterable, Codable, Hashable {
    case plain, matplotlib, pandas, numpy, plotly, seaborn, custom, markdown

    var defaultImports: [String] {
        switch self {
        case .plain      : []
        case .matplotlib : ["import matplotlib.pyplot as plt", "import numpy as np"]
        case .pandas     : ["import pandas as pd", "import numpy as np"]
        case .numpy      : ["import numpy as np"]
        case .plotly     : ["import plotly.graph_objects as go",
                            "import plotly.express as px", "import pandas as pd"]
        case .seaborn    : ["import seaborn as sns", "import matplotlib.pyplot as plt",
                            "import pandas as pd"]
        case .custom, .markdown: []
        }
    }

    var defaultContent: String {
        switch self {
        case .plain: "# Add your code here"
        case .matplotlib: """
            # Create figure and axis
            fig, ax = plt.subplots(figsize=(10, 6))

            # Your plotting code here
            # ax.plot(x, y)

            plt.show()
            """
        case .pandas: """
            # Create or load your DataFrame
            # df = pd.read_csv('your_file.csv')
            # df = pd.DataFrame({'col1': [1, 2, 3], 'col2': [4, 5, 6]})

            # Display DataFrame info
            # print(df.head())
            # print(df.describe())
            """
        case .numpy: """
            # Create numpy arrays
            # arr = np.array([1, 2, 3, 4, 5])

            # Your numpy operations here
            """
        case .plotly: """
            # Create interactive plot
            # fig = go.Figure()
            # fig.add_trace(go.Scatter(x=[1, 2, 3, 4], y=[10, 11, 12, 13]))
            # fig.show()
            """
        case .seaborn: """
            # Set style
            sns.set_style("whitegrid")

            # Create statistical plot
            # sns.scatterplot(data=df, x='col1', y='col2')
            # plt.show()
            """
        case .custom:   "# Add your custom code here"
        case .markdown: "Add your markdown content here"
        }
    }
}

// MARK: - Point Cloud Data Structure

struct PointCloudData: Codable, Hashable {
    var title: String
    var xAxisLabel: String
    var yAxisLabel: String
    var zAxisLabel: String
    var demoType: String
    var parameters: [String: Double]
    var totalPoints: Int
    var points: [PointData]

    struct PointData: Codable, Hashable {
        var x: Double
        var y: Double
        var z: Double
        var intensity: Double?
        var color: String?

        init(x: Double, y: Double, z: Double, intensity: Double? = nil, color: String? = nil) {
            self.x = x
            self.y = y
            self.z = z
            self.intensity = intensity
            self.color = color
        }
    }

    init(title: String = "Point Cloud Data",
         xAxisLabel: String = "X",
         yAxisLabel: String = "Y",
         zAxisLabel: String = "Z",
         demoType: String = "custom",
         parameters: [String: Double] = [:]) {
        self.title = title
        self.xAxisLabel = xAxisLabel
        self.yAxisLabel = yAxisLabel
        self.zAxisLabel = zAxisLabel
        self.demoType = demoType
        self.parameters = parameters
        self.totalPoints = 0
        self.points = []
    }

    // Convert to Python code for Jupyter
    func toPythonCode() -> String {
        guard !points.isEmpty else {
            return "# Empty point cloud\nprint('No point cloud data available')"
        }

        let xPoints = points.map { String($0.x) }.joined(separator: ", ")
        let yPoints = points.map { String($0.y) }.joined(separator: ", ")
        let zPoints = points.map { String($0.z) }.joined(separator: ", ")

        var intensityString = ""
        let hasIntensity = points.contains { $0.intensity != nil }
        if hasIntensity {
            let intensities = points.map { String($0.intensity ?? 0.0) }.joined(separator: ", ")
            intensityString = """
            
            # Point intensities
            intensities = np.array([\(intensities)])
            """
        }

        return """
        # \(title)
        # Generated from VisionOS Point Cloud Viewer
        # Demo Type: \(demoType)
        
        import numpy as np
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d import Axes3D
        import plotly.graph_objects as go
        import plotly.express as px
        
        # Point cloud data (\(totalPoints) points)
        x_points = np.array([\(xPoints)])
        y_points = np.array([\(yPoints)])
        z_points = np.array([\(zPoints)])\(intensityString)
        
        # Parameters: \(parameters.map { key, value in "\(key): \(value)" }.joined(separator: ", "))
        
        # Matplotlib 3D scatter plot
        fig = plt.figure(figsize=(12, 10))
        ax = fig.add_subplot(111, projection='3d')
        
        \(hasIntensity ? "scatter = ax.scatter(x_points, y_points, z_points, c=intensities, cmap='viridis', alpha=0.7)" : "scatter = ax.scatter(x_points, y_points, z_points, alpha=0.7)")
        
        ax.set_xlabel('\(xAxisLabel)')
        ax.set_ylabel('\(yAxisLabel)')
        ax.set_zlabel('\(zAxisLabel)')
        ax.set_title('\(title)')
        
        \(hasIntensity ? "plt.colorbar(scatter)" : "")
        plt.tight_layout()
        plt.show()
        
        # Plotly interactive 3D plot
        fig_plotly = go.Figure()
        
        fig_plotly.add_trace(go.Scatter3d(
            x=x_points,
            y=y_points,
            z=z_points,
            mode='markers',
            marker=dict(
                size=3,
                \(hasIntensity ? "color=intensities,\n                colorscale='Viridis'," : "color='blue',")
                opacity=0.8
            ),
            name='\(title)'
        ))
        
        fig_plotly.update_layout(
            title='\(title)',
            scene=dict(
                xaxis_title='\(xAxisLabel)',
                yaxis_title='\(yAxisLabel)',
                zaxis_title='\(zAxisLabel)'
            ),
            width=800,
            height=600
        )
        
        fig_plotly.show()
        
        # Print statistics
        print(f"Point Cloud Statistics:")
        print(f"- Title: '\(title)'")
        print(f"- Demo Type: '\(demoType)'")
        print(f"- Total Points: {len(x_points)}")
        print(f"- X Range: [{np.min(x_points):.2f}, {np.max(x_points):.2f}]")
        print(f"- Y Range: [{np.min(y_points):.2f}, {np.max(y_points):.2f}]")
        print(f"- Z Range: [{np.min(z_points):.2f}, {np.max(z_points):.2f}]")
        \(hasIntensity ? "print(f\"- Intensity Range: [{np.min(intensities):.2f}, {np.max(intensities):.2f}]\")" : "")
        """
    }
}

// Add this structure after PointCloudData
struct VolumeData: Codable, Hashable {
    var metrics: [String: Double]
    var title: String
    var category: String
    var timestamp: Date
    var unit: String?

    init(title: String = "Volume Metrics",
         category: String = "performance",
         metrics: [String: Double] = [:],
         unit: String? = nil) {
        self.title = title
        self.category = category
        self.metrics = metrics
        self.timestamp = Date()
        self.unit = unit
    }

    // Convert to Python code for Jupyter
    func toPythonCode() -> String {
        guard !metrics.isEmpty else {
            return "# Empty volume data\nprint('No volume data available')"
        }

        let metricsDict = metrics.map { "\"\($0.key)\": \($0.value)" }.joined(separator: ",\n    ")

        return """
        # \(title)
        # Generated from VisionOS Volume Window
        # Category: \(category)
        
        import matplotlib.pyplot as plt
        import numpy as np
        import pandas as pd
        from datetime import datetime
        
        # Volume metrics data
        metrics = {
            \(metricsDict)
        }
        
        # Create DataFrame for easy manipulation
        df_metrics = pd.DataFrame(list(metrics.items()), columns=['Metric', 'Value'])
        
        # Display metrics
        print("Volume Metrics Summary:")
        print("-" * 40)
        for metric, value in metrics.items():
            unit_str = "\(unit ?? "")"
            print(f"{metric:20}: {value:10.3f} {unit_str}")
        
        # Create visualization
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))
        
        # Bar chart
        ax1.bar(df_metrics['Metric'], df_metrics['Value'])
        ax1.set_title('\(title) - Bar Chart')
        ax1.tick_params(axis='x', rotation=45)
        
        # Pie chart (for positive values only)
        positive_metrics = {k: v for k, v in metrics.items() if v > 0}
        if positive_metrics:
            ax2.pie(positive_metrics.values(), labels=positive_metrics.keys(), autopct='%1.1f%%')
            ax2.set_title('\(title) - Distribution')
        else:
            ax2.text(0.5, 0.5, 'No positive values\\nfor pie chart', 
                    ha='center', va='center', transform=ax2.transAxes)
            ax2.set_title('Distribution (N/A)')
        
        plt.tight_layout()
        plt.show()
        
        # Statistics
        print(f"\\nStatistics:")
        print(f"Total metrics: {len(metrics)}")
        print(f"Average value: {np.mean(list(metrics.values())):.3f}")
        print(f"Max value: {max(metrics.values()):.3f}")
        print(f"Min value: {min(metrics.values()):.3f}")
        """
    }
}

// Add this structure after VolumeData
struct ChartData: Codable, Hashable {
    var xData: [Double]
    var yData: [Double]
    var chartType: String
    var title: String
    var xLabel: String
    var yLabel: String
    var color: String?
    var style: String?

    init(title: String = "Chart Data",
         chartType: String = "line",
         xLabel: String = "X",
         yLabel: String = "Y",
         xData: [Double] = [],
         yData: [Double] = [],
         color: String? = nil,
         style: String? = nil) {
        self.title = title
        self.chartType = chartType
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.xData = xData
        self.yData = yData
        self.color = color
        self.style = style
    }

    // Convert to Python code for Jupyter
    func toPythonCode() -> String {
        guard !xData.isEmpty && !yData.isEmpty else {
            return "# Empty chart data\nprint('No chart data available')"
        }

        let xDataString = xData.map { String($0) }.joined(separator: ", ")
        let yDataString = yData.map { String($0) }.joined(separator: ", ")

        return """
        # \(title)
        # Generated from VisionOS Chart Window
        
        import numpy as np
        import matplotlib.pyplot as plt
        import pandas as pd
        
        # Chart data
        x_data = np.array([\(xDataString)])
        y_data = np.array([\(yDataString)])
        
        # Create the chart
        fig, ax = plt.subplots(figsize=(10, 6))
        
        \(generatePlotCode())
        
        ax.set_xlabel('\(xLabel)')
        ax.set_ylabel('\(yLabel)')
        ax.set_title('\(title)')
        ax.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.show()
        
        # Data statistics
        print("Chart Data Statistics:")
        print("-" * 30)
        print(f"Data points: {len(x_data)}")
        print(f"X range: [{np.min(x_data):.3f}, {np.max(x_data):.3f}]")
        print(f"Y range: [{np.min(y_data):.3f}, {np.max(y_data):.3f}]")
        print(f"Y mean: {np.mean(y_data):.3f}")
        print(f"Y std: {np.std(y_data):.3f}")
        
        # Create DataFrame for further analysis
        df = pd.DataFrame({'X': x_data, 'Y': y_data})
        print("\\nDataFrame Preview:")
        print(df.head())
        """
    }

    private func generatePlotCode() -> String {
        let colorCode = color != nil ? ", color='\(color!)'" : ""
        let styleCode = style != nil ? ", linestyle='\(style!)'" : ""

        switch chartType.lowercased() {
        case "scatter":
            return "ax.scatter(x_data, y_data\(colorCode), alpha=0.7)"
        case "bar":
            return "ax.bar(x_data, y_data\(colorCode))"
        case "line":
            return "ax.plot(x_data, y_data\(colorCode)\(styleCode), marker='o', markersize=4)"
        case "area":
            return "ax.fill_between(x_data, y_data\(colorCode), alpha=0.6)"
        default:
            return "ax.plot(x_data, y_data\(colorCode)\(styleCode))"
        }
    }

    func toEnhancedPythonCode() -> String {
        let xDataStr = xData.map { String($0) }.joined(separator: ", ")
        let yDataStr = yData.map { String($0) }.joined(separator: ", ")

        let colorStr = color ?? "blue"
        let styleStr = style ?? "solid"

        return """
        # Chart Window - \(title)
        # Chart Type: \(chartType)
        # X Range: [\(xDataStr)]
        # Y Range: [\(yDataStr)]
        # Color: \(colorStr)
        # Style: \(styleStr)
        
        import matplotlib.pyplot as plt
        import numpy as np
        
        # Chart data from VisionOS
        x_data = [\(xDataStr)]
        y_data = [\(yDataStr)]
        
        # Create the plot
        plt.figure(figsize=(10, 6))
        
        \(generatePlotCode())
        
        plt.title('\(title)')
        plt.xlabel('\(xLabel)')
        plt.ylabel('\(yLabel)')
        plt.grid(True, alpha=0.3)
        plt.tight_layout()
        plt.show()
        
        # Display data summary
        print(f"Chart: \(title)")
        print(f"Type: \(chartType)")
        print(f"Data points: {len(x_data)}")
        print(f"X range: [{min(x_data):.2f}, {max(x_data):.2f}]")
        print(f"Y range: [{min(y_data):.2f}, {max(y_data):.2f}]")
        """
    }

}

// Add this structure after ChartData
struct Model3DData: Codable, Hashable {
    var vertices: [Vertex3D]
    var faces: [Face3D]
    var normals: [Normal3D]?
    var textures: [TextureCoord]?
    var materials: [Material3D]
    var title: String
    var modelType: String
    var scale: Double
    var position: Position3D
    var rotation: Rotation3D

    struct Vertex3D: Codable, Hashable {
        var x: Double
        var y: Double
        var z: Double
    }

    struct Face3D: Codable, Hashable {
        var vertices: [Int]  // indices into vertex array
        var materialIndex: Int?
    }

    struct Normal3D: Codable, Hashable {
        var x: Double
        var y: Double
        var z: Double
    }

    struct TextureCoord: Codable, Hashable {
        var u: Double
        var v: Double
    }

    struct Material3D: Codable, Hashable {
        var name: String
        var color: String
        var metallic: Double?
        var roughness: Double?
        var transparency: Double?
    }

    struct Position3D: Codable, Hashable {
        var x: Double
        var y: Double
        var z: Double

        init(x: Double = 0, y: Double = 0, z: Double = 0) {
            self.x = x
            self.y = y
            self.z = z
        }
    }

    struct Rotation3D: Codable, Hashable {
        var x: Double
        var y: Double
        var z: Double

        init(x: Double = 0, y: Double = 0, z: Double = 0) {
            self.x = x
            self.y = y
            self.z = z
        }
    }

    init(title: String = "3D Model",
         modelType: String = "mesh",
         scale: Double = 1.0,
         position: Position3D = Position3D(),
         rotation: Rotation3D = Rotation3D()) {
        self.vertices = []
        self.faces = []
        self.normals = []
        self.textures = []
        self.materials = []
        self.title = title
        self.modelType = modelType
        self.scale = scale
        self.position = position
        self.rotation = rotation
    }

    // Convert to Python code for Jupyter
    func toPythonCode() -> String {
        guard !vertices.isEmpty else {
            return "# Empty 3D model\nprint('No 3D model data available')"
        }

        let verticesString = vertices.map { "[\($0.x), \($0.y), \($0.z)]" }.joined(separator: ",\n    ")
        let facesString = faces.map { "[\($0.vertices.map { String($0) }.joined(separator: ", "))]" }.joined(separator: ",\n    ")

        return """
        # \(title)
        # Generated from VisionOS 3D Model Viewer
        
        import numpy as np
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d import Axes3D
        import plotly.graph_objects as go
        from mpl_toolkits.mplot3d.art3d import Poly3DCollection
        import plotly.express as px
        
        # 3D Model data (\(vertices.count) vertices, \(faces.count) faces)
        vertices = np.array([
            \(verticesString)
        ])
        
        faces = [
            \(facesString)
        ]
        
        # Apply transformations
        scale = \(scale)
        position = np.array([\(position.x), \(position.y), \(position.z)])
        
        # Scale and translate vertices
        scaled_vertices = vertices * scale + position
        
        # Matplotlib 3D visualization
        fig = plt.figure(figsize=(12, 10))
        ax = fig.add_subplot(111, projection='3d')
        
        # Create mesh
        mesh_faces = []
        for face in faces:
            if len(face) >= 3:  // Valid face
                face_vertices = scaled_vertices[face]
                mesh_faces.append(face_vertices)
        mesh_collection = Poly3DCollection(mesh_faces, alpha=0.7, facecolor='lightblue', edgecolor='black')
        ax.add_collection3d(mesh_collection)
        
        # Plot vertices as points
        ax.scatter(scaled_vertices[:, 0], scaled_vertices[:, 1], scaled_vertices[:, 2], 
                  c='red', s=20, alpha=0.8)
        
        # Set labels and title
        ax.set_xlabel('X')
        ax.set_ylabel('Y')
        ax.set_zlabel('Z')
        ax.set_title('\(title)')
        
        # Set equal aspect ratio
        max_range = np.array([scaled_vertices[:,0].max()-scaled_vertices[:,0].min(),
                             scaled_vertices[:,1].max()-scaled_vertices[:,1].min(),
                             scaled_vertices[:,2].max()-scaled_vertices[:,2].min()]).max() / 2.0
        
        mid_x = (scaled_vertices[:,0].max()+scaled_vertices[:,0].min()) * 0.5
        mid_y = (scaled_vertices[:,1].max()+scaled_vertices[:,1].min()) * 0.5
        mid_z = (scaled_vertices[:,2].max()+scaled_vertices[:,2].min()) * 0.5
        
        ax.set_xlim(mid_x - max_range, mid_x + max_range)
        ax.set_ylim(mid_y - max_range, mid_y + max_range)
        ax.set_zlim(mid_z - max_range, mid_z + max_range)
        
        plt.tight_layout()
        plt.show()
        
        # Plotly interactive 3D visualization
        fig_plotly = go.Figure()
        
        # Add mesh
        if len(faces) > 0 and len(vertices) > 0:
            # Convert faces to plotly format
            i_coords = []
            j_coords = []
            k_coords = []
            
            for face in faces:
                if len(face) >= 3:
                    # Convert to triangles if needed
                    for i in range(1, len(face) - 1):
                        i_coords.append(face[0])
                        j_coords.append(face[i])
                        k_coords.append(face[i + 1])
            
            fig_plotly.add_trace(go.Mesh3d(
                x=scaled_vertices[:, 0],
                y=scaled_vertices[:, 1],
                z=scaled_vertices[:, 2],
                i=i_coords,
                j=j_coords,
                k=k_coords,
                opacity=0.8,
                color='lightblue',
                name='\(title)'
            ))
        
        # Add vertices as scatter
        fig_plotly.add_trace(go.Scatter3d(
            x=scaled_vertices[:, 0],
            y=scaled_vertices[:, 1],
            z=scaled_vertices[:, 2],
            mode='markers',
            marker=dict(size=3, color='red'),
            name='Vertices'
        ))
        
        fig_plotly.update_layout(
            title='\(title)',
            scene=dict(
                xaxis_title='X',
                yaxis_title='Y',
                zaxis_title='Z',
                aspectmode='cube'
            ),
            width=800,
            height=600
        )
        
        fig_plotly.show()
        
        # Print model statistics
        print(f"3D Model Statistics:")
        print(f"- Title: '\(title)'")
        print(f"- Model Type: '\(modelType)'")
        print(f"- Vertices: {len(vertices)}")
        print(f"- Faces: {len(faces)}")
        print(f"- Scale: {scale}")
        print(f"- Position: [{position[0]:.2f}, {position[1]:.2f}, {position[2]:.2f}]")
        print(f"- Bounding Box:")
        print(f"  X: [{np.min(scaled_vertices[:, 0]):.2f}, {np.max(scaled_vertices[:, 0]):.2f}]")
        print(f"  Y: [{np.min(scaled_vertices[:, 1]):.2f}, {np.max(scaled_vertices[:, 1]):.2f}]")
        print(f"  Z: [{np.min(scaled_vertices[:, 2]):.2f}, {np.max(scaled_vertices[:, 2]):.2f}]")
        """
    }

    // Helper method to generate basic shapes
    static func generateCube(size: Double = 2.0) -> Model3DData {
        let halfSize = size / 2.0

        let vertices = [
            Vertex3D(x: -halfSize, y: -halfSize, z: -halfSize), // 0
            Vertex3D(x:  halfSize, y: -halfSize, z: -halfSize), // 1
            Vertex3D(x:  halfSize, y:  halfSize, z: -halfSize), // 2
            Vertex3D(x: -halfSize, y:  halfSize, z: -halfSize), // 3
            Vertex3D(x: -halfSize, y: -halfSize, z:  halfSize), // 4
            Vertex3D(x:  halfSize, y: -halfSize, z:  halfSize), // 5
            Vertex3D(x:  halfSize, y:  halfSize, z:  halfSize), // 6
            Vertex3D(x: -halfSize, y:  halfSize, z:  halfSize)  // 7
        ]

        let faces = [
            Face3D(vertices: [0, 1, 2, 3], materialIndex: 0), // bottom
            Face3D(vertices: [4, 7, 6, 5], materialIndex: 0), // top
            Face3D(vertices: [0, 4, 5, 1], materialIndex: 0), // front
            Face3D(vertices: [2, 6, 7, 3], materialIndex: 0), // back
            Face3D(vertices: [0, 3, 7, 4], materialIndex: 0), // left
            Face3D(vertices: [1, 5, 6, 2], materialIndex: 0)  // right
        ]

        let materials = [
            Material3D(name: "default", color: "blue", metallic: 0.1, roughness: 0.5, transparency: 0.0)
        ]

        var model = Model3DData(title: "Cube (\(size)x\(size)x\(size))", modelType: "cube")
        model.vertices = vertices
        model.faces = faces
        model.materials = materials

        return model
    }

    static func generateSphere(radius: Double = 1.0, segments: Int = 16) -> Model3DData {
        var vertices: [Vertex3D] = []
        var faces: [Face3D] = []

        // Generate vertices
        for i in 0...segments {
            let phi = Double(i) * .pi / Double(segments)
            for j in 0..<(segments * 2) {
                let theta = Double(j) * 2.0 * .pi / Double(segments * 2)

                let x = radius * sin(phi) * cos(theta)
                let y = radius * cos(phi)
                let z = radius * sin(phi) * sin(theta)

                vertices.append(Vertex3D(x: x, y: y, z: z))
            }
        }

        // Generate faces
        for i in 0..<segments {
            for j in 0..<(segments * 2) {
                let current = i * (segments * 2) + j
                let next = i * (segments * 2) + (j + 1) % (segments * 2)
                let currentNext = (i + 1) * (segments * 2) + j
                let nextNext = (i + 1) * (segments * 2) + (j + 1) % (segments * 2)

                if i < segments {
                    faces.append(Face3D(vertices: [current, next, nextNext, currentNext], materialIndex: 0))
                }
            }
        }

        let materials = [
            Material3D(name: "default", color: "green", metallic: 0.2, roughness: 0.3, transparency: 0.0)
        ]

        var model = Model3DData(title: "Sphere (r=\(radius))", modelType: "sphere")
        model.vertices = vertices
        model.faces = faces
        model.materials = materials

        return model
    }
}

struct WindowState: Codable, Hashable {
    let id: Int = Int()
    var isMinimized: Bool = false
    var isMaximized: Bool = false
    var opacity: Double = 1.0
    var lastModified: Date = Date()
    var content: String = ""
    var exportTemplate: ExportTemplate = .plain
    var customImports: [String] = []
    var tags: [String] = []
    var dataFrameData: DataFrameData? = nil
    var pointCloudData: PointCloudData? = nil
    var volumeData: VolumeData? = nil
    var chartData: ChartData? = nil
    var model3DData: Model3DData? = nil
    var usdzBookmark: Data? = nil
    var pointCloudBookmark: Data? = nil
    var chart3DData: Chart3DData?

    init(isMinimized: Bool = false, isMaximized: Bool = false,
         opacity: Double = 1.0, content: String = "",
         exportTemplate: ExportTemplate = .plain) {
        self.isMinimized = isMinimized
        self.isMaximized = isMaximized
        self.opacity = opacity
        self.content = content
        self.exportTemplate = exportTemplate
        self.lastModified = Date()
    }
}


struct DataFrameData: Codable, Hashable {
    var columns: [String]
    var rows: [[String]]
    var dtypes: [String: String] // column name to data type mapping
    var shapeRows: Int // instead of tuple
    var shapeColumns: Int // instead of tuple

    // Computed property for convenient access
    var shape: (Int, Int) {
        return (shapeRows, shapeColumns)
    }

    init(columns: [String] = [], rows: [[String]] = [], dtypes: [String: String] = [:]) {
        self.columns = columns
        self.rows = rows
        self.dtypes = dtypes
        self.shapeRows = rows.count
        self.shapeColumns = columns.count
    }

    // Helper methods
    func toPandasCode() -> String {
        guard !columns.isEmpty && !rows.isEmpty else {
            return "# Empty DataFrame\ndf = pd.DataFrame()"
        }

        var code = "# DataFrame data\ndata = {\n"

        for (colIndex, column) in columns.enumerated() {
            let columnData = rows.map { $0.count > colIndex ? $0[colIndex] : "" }
            let formattedData = columnData.map { "'\($0)'" }.joined(separator: ", ")
            code += "    '\(column)': [\(formattedData)],\n"
        }

        code += "}\n\n"
        code += "df = pd.DataFrame(data)\n\n"

        // Add data type conversions if specified
        if !dtypes.isEmpty {
            code += "# Convert data types\n"
            for (column, dtype) in dtypes {
                switch dtype.lowercased() {
                case "int", "integer":
                    code += "df['\(column)'] = pd.to_numeric(df['\(column)'], errors='coerce').astype('Int64')\n"
                case "float", "numeric":
                    code += "df['\(column)'] = pd.to_numeric(df['\(column)'], errors='coerce')\n"
                case "datetime", "date":
                    code += "df['\(column)'] = pd.to_datetime(df['\(column)'], errors='coerce')\n"
                case "bool", "boolean":
                    code += "df['\(column)'] = df['\(column)'].astype('boolean')\n"
                default:
                    code += "# \(column): \(dtype)\n"
                }
            }
            code += "\n"
        }

        code += "print(f\"DataFrame shape: {df.shape}\")\nprint(df.head())\nprint(df.info())"

        return code
    }

    func toCSVString() -> String {
        guard !columns.isEmpty else { return "" }

        var csv = columns.joined(separator: ",") + "\n"
        for row in rows {
            let paddedRow = row + Array(repeating: "", count: max(0, columns.count - row.count))
            csv += paddedRow.prefix(columns.count).joined(separator: ",") + "\n"
        }
        return csv
    }

    func toEnhancedPandasCode() -> String {
        let columnsStr = columns.map { "'\($0)'" }.joined(separator: ", ")

        // Create the data dictionary
        var dataDict: [String] = []
        for (index, column) in columns.enumerated() {
            let columnValues = rows.map { row in
                index < row.count ? row[index] : ""
            }

            // Format values based on data type
            let dtype = dtypes[column] ?? "string"
            let formattedValues: [String]

            switch dtype {
            case "int":
                formattedValues = columnValues.map { Int($0) != nil ? $0 : "0" }
            case "float":
                formattedValues = columnValues.map { Double($0) != nil ? $0 : "0.0" }
            default: // string
                formattedValues = columnValues.map { "'\($0)'" }
            }

            let valuesStr = formattedValues.joined(separator: ", ")
            dataDict.append("    '\(column)': [\(valuesStr)]")
        }

        let dataDictStr = "{\n\(dataDict.joined(separator: ",\n"))\n}"

        // Generate dtypes dictionary
        let dtypesStr = dtypes.map { "'\($0.key)': '\($0.value)'" }.joined(separator: ", ")

        return """
        # DataFrame Window - \(columns.count) columns, \(rows.count) rows
        # DataFrame Columns: [\(columnsStr)]
        # DataFrame Types: {\(dtypesStr)}
        # DataFrame Rows: \(formatRowsForComment())
        
        import pandas as pd
        import numpy as np
        
        # DataFrame data from VisionOS
        data = \(dataDictStr)
        
        # Create DataFrame
        df = pd.DataFrame(data)
        
        # Set data types
        \(generateDtypeConversions())
        
        # Display DataFrame info
        print("DataFrame Summary:")
        print(f"Shape: {df.shape}")
        print(f"Columns: {list(df.columns)}")
        print("\\nData types:")
        print(df.dtypes)
        print("\\nFirst 10 rows:")
        print(df.head(10))
        print("\\nStatistical summary:")
        print(df.describe(include='all'))
        
        # Display the full DataFrame
        df
        """
    }

    private func formatRowsForComment() -> String {
        let formattedRows = rows.prefix(5).map { row in
            let quotedRow = row.map { "'\($0)'" }.joined(separator: ", ")
            return "[\(quotedRow)]"
        }
        let rowsStr = formattedRows.joined(separator: ", ")
        let suffix = rows.count > 5 ? ", ..." : ""
        return "[\(rowsStr)\(suffix)]"
    }

    private func generateDtypeConversions() -> String {
        var conversions: [String] = []

        for (column, dtype) in dtypes {
            switch dtype {
            case "int":
                conversions.append("df['\(column)'] = pd.to_numeric(df['\(column)'], errors='coerce').astype('Int64')")
            case "float":
                conversions.append("df['\(column)'] = pd.to_numeric(df['\(column)'], errors='coerce')")
            case "bool":
                conversions.append("df['\(column)'] = df['\(column)'].astype('bool')")
            default: // string
                conversions.append("df['\(column)'] = df['\(column)'].astype('string')")
            }
        }

        return conversions.joined(separator: "\n")
    }
}

struct NewWindowID: Identifiable, Codable, Hashable {
    /// The unique identifier for the window.
    var id: Int
    /// The type of window to create
    var windowType: WindowType
    /// Position and size information
    var position: WindowPosition
    /// Window state information
    var state: WindowState
    /// Creation timestamp
    var createdAt: Date

    init(id: Int, windowType: WindowType,
         position: WindowPosition = WindowPosition(),
         state: WindowState = WindowState()) {
        self.id = id
        self.windowType = windowType
        self.position = position
        self.state = state
        self.createdAt = Date()
    }
}

// Point Cloud Demo Integration
class PointCloudDemo {

    // MARK: - Demo Functions

    /// Generate a simple sphere point cloud
    static func generateSpherePointCloud(radius: Double = 10.0, points: Int = 1000) -> [(x: Double, y: Double, z: Double)] {
        var pointCloud: [(x: Double, y: Double, z: Double)] = []

        for _ in 0..<points {
            // Random angles
            let theta = Double.random(in: 0...(2 * .pi))
            let phi = Double.random(in: 0...(.pi))

            // Convert spherical to Cartesian coordinates
            let x = radius * sin(phi) * cos(theta)
            let y = radius * sin(phi) * sin(theta)
            let z = radius * cos(phi)

            pointCloud.append((x: x, y: y, z: z))
        }

        return pointCloud
    }

    /// Generate a torus (donut) point cloud
    static func generateTorusPointCloud(majorRadius: Double = 10.0, minorRadius: Double = 3.0, points: Int = 2000) -> [(x: Double, y: Double, z: Double, color: String?, intensity: Double?)] {
        var pointCloud: [(x: Double, y: Double, z: Double, color: String?, intensity: Double?)] = []

        for _ in 0..<points {
            let u = Double.random(in: 0...(2 * .pi))
            let v = Double.random(in: 0...(2 * .pi))

            let x = (majorRadius + minorRadius * cos(v)) * cos(u)
            let y = (majorRadius + minorRadius * cos(v)) * sin(u)
            let z = minorRadius * sin(v)

            // Calculate intensity based on height (z-coordinate)
            let intensity = (z + minorRadius) / (2 * minorRadius)

            pointCloud.append((x: x, y: y, z: z, color: nil, intensity: intensity))
        }

        return pointCloud
    }

    /// Generate a wave surface point cloud
    static func generateWaveSurface(size: Double = 20.0, resolution: Int = 50) -> [(x: Double, y: Double, z: Double, color: String?, intensity: Double?)] {
        var pointCloud: [(x: Double, y: Double, z: Double, color: String?, intensity: Double?)] = []

        let step = size / Double(resolution)

        for i in 0..<resolution {
            for j in 0..<resolution {
                let x = -size/2 + Double(i) * step
                let y = -size/2 + Double(j) * step

                // Wave equation: z = A * sin(kx * x) * sin(ky * y)
                let z = 3.0 * sin(0.3 * x) * sin(0.3 * y)

                // Intensity based on height
                let intensity = (z + 3.0) / 6.0

                pointCloud.append((x: x, y: y, z: z, color: nil, intensity: intensity))
            }
        }

        return pointCloud
    }

    /// Generate a spiral galaxy point cloud
    static func generateSpiralGalaxy(arms: Int = 3, points: Int = 5000) -> [(x: Double, y: Double, z: Double, color: String?, intensity: Double?)] {
        var pointCloud: [(x: Double, y: Double, z: Double, color: String?, intensity: Double?)] = []

        for i in 0..<points {
            let armIndex = i % arms
            let armAngle = (2.0 * .pi * Double(armIndex)) / Double(arms)

            // Distance from center
            let r = Double.random(in: 1...20)

            // Spiral angle
            let theta = armAngle + (r * 0.3)

            // Add some randomness
            let spread = 2.0 / (1.0 + r * 0.1)
            let xOffset = Double.random(in: -spread...spread)
            let yOffset = Double.random(in: -spread...spread)

            let x = r * cos(theta) + xOffset
            let y = r * sin(theta) + yOffset
            let z = Double.random(in: -1...1) * (1.0 / (1.0 + r * 0.1))

            // Intensity decreases with distance from center
            let intensity = 1.0 / (1.0 + r * 0.05)

            pointCloud.append((x: x, y: y, z: z, color: nil, intensity: intensity))
        }

        return pointCloud
    }

    /// Generate a cube with noise
    static func generateNoisyCube(size: Double = 10.0, pointsPerFace: Int = 500) -> [(x: Double, y: Double, z: Double)] {
        var pointCloud: [(x: Double, y: Double, z: Double)] = []
        let halfSize = size / 2.0
        let noiseLevel = 0.5

        // Generate points for each face
        for _ in 0..<pointsPerFace {
            // Top face
            pointCloud.append((
                x: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel),
                y: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel),
                z: halfSize + Double.random(in: -noiseLevel...noiseLevel)
            ))

            // Bottom face
            pointCloud.append((
                x: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel),
                y: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel),
                z: -halfSize + Double.random(in: -noiseLevel...noiseLevel)
            ))

            // Front face
            pointCloud.append((
                x: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel),
                y: halfSize + Double.random(in: -noiseLevel...noiseLevel),
                z: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel)
            ))

            // Back face
            pointCloud.append((
                x: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel),
                y: -halfSize + Double.random(in: -noiseLevel...noiseLevel),
                z: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel)
            ))

            // Right face
            pointCloud.append((
                x: halfSize + Double.random(in: -noiseLevel...noiseLevel),
                y: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel),
                z: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel)
            ))

            // Left face
            pointCloud.append((
                x: -halfSize + Double.random(in: -noiseLevel...noiseLevel),
                y: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel),
                z: Double.random(in: -halfSize...halfSize) + Double.random(in: -noiseLevel...noiseLevel)
            ))
        }

        return pointCloud
    }

    // Enhanced generation methods that return PointCloudData
    static func generateSpherePointCloudData(radius: Double = 10.0, points: Int = 1000) -> PointCloudData {
        let spherePoints = generateSpherePointCloud(radius: radius, points: points)

        var pointCloudData = PointCloudData(
            title: "Sphere Point Cloud (\(points) points)",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "sphere",
            parameters: ["radius": radius, "points": Double(points)]
        )

        pointCloudData.points = spherePoints.map { point in
            PointCloudData.PointData(x: point.x, y: point.y, z: point.z, intensity: nil, color: nil)
        }
        pointCloudData.totalPoints = spherePoints.count

        return pointCloudData
    }

    static func generateTorusPointCloudData(majorRadius: Double = 10.0, minorRadius: Double = 3.0, points: Int = 2000) -> PointCloudData {
        let torusPoints = generateTorusPointCloud(majorRadius: majorRadius, minorRadius: minorRadius, points: points)

        var pointCloudData = PointCloudData(
            title: "Torus Point Cloud (\(points) points)",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "torus",
            parameters: ["majorRadius": majorRadius, "minorRadius": minorRadius, "points": Double(points)]
        )

        pointCloudData.points = torusPoints.map { point in
            PointCloudData.PointData(x: point.x, y: point.y, z: point.z, intensity: point.intensity, color: point.color)
        }
        pointCloudData.totalPoints = torusPoints.count

        return pointCloudData
    }

    static func generateWaveSurfaceData(size: Double = 20.0, resolution: Int = 50) -> PointCloudData {
        let wavePoints = generateWaveSurface(size: size, resolution: resolution)

        var pointCloudData = PointCloudData(
            title: "Wave Surface (\(resolution)×\(resolution) points)",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Height",
            demoType: "wave",
            parameters: ["size": size, "resolution": Double(resolution)]
        )

        pointCloudData.points = wavePoints.map { point in
            PointCloudData.PointData(x: point.x, y: point.y, z: point.z, intensity: point.intensity, color: point.color)
        }
        pointCloudData.totalPoints = wavePoints.count

        return pointCloudData
    }

    static func generateSpiralGalaxyData(arms: Int = 3, points: Int = 5000) -> PointCloudData {
        let galaxyPoints = generateSpiralGalaxy(arms: arms, points: points)

        var pointCloudData = PointCloudData(
            title: "Spiral Galaxy (\(arms) arms, \(points) points)",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "galaxy",
            parameters: ["arms": Double(arms), "points": Double(points)]
        )

        pointCloudData.points = galaxyPoints.map { point in
            PointCloudData.PointData(x: point.x, y: point.y, z: point.z, intensity: point.intensity, color: point.color)
        }
        pointCloudData.totalPoints = galaxyPoints.count

        return pointCloudData
    }

    static func generateNoisyCubeData(size: Double = 10.0, pointsPerFace: Int = 500) -> PointCloudData {
        let cubePoints = generateNoisyCube(size: size, pointsPerFace: pointsPerFace)

        var pointCloudData = PointCloudData(
            title: "Noisy Cube (\(pointsPerFace * 6) points)",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "cube",
            parameters: ["size": size, "pointsPerFace": Double(pointsPerFace)]
        )

        pointCloudData.points = cubePoints.map { point in
            PointCloudData.PointData(x: point.x, y: point.y, z: point.z, intensity: nil, color: nil)
        }
        pointCloudData.totalPoints = cubePoints.count

        return pointCloudData
    }

    // MARK: - Demo Execution

    static func runAllDemos() {
        print("🎯 Point Cloud Demo Starting...\n")

        // Demo 1: Simple Sphere
        print("1️⃣ Generating Sphere Point Cloud...")
        let sphereData = generateSpherePointCloudData(radius: 10.0, points: 1000)
        let sphereCode = sphereData.toPythonCode()
        saveJupyterCode(sphereCode, to: "sphere_pointcloud.py")
        print("✅ Sphere point cloud saved to sphere_pointcloud.py\n")

        // Demo 2: Torus with Intensity
        print("2️⃣ Generating Torus Point Cloud with Intensity...")
        let torusData = generateTorusPointCloudData(majorRadius: 10.0, minorRadius: 3.0, points: 2000)
        let torusCode = torusData.toPythonCode()
        saveJupyterCode(torusCode, to: "torus_pointcloud.py")
        print("✅ Torus point cloud saved to torus_pointcloud.py\n")

        // Demo 3: Wave Surface
        print("3️⃣ Generating Wave Surface...")
        let waveData = generateWaveSurfaceData(size: 20.0, resolution: 50)
        let waveCode = waveData.toPythonCode()
        saveJupyterCode(waveCode, to: "wave_pointcloud.py")
        print("✅ Wave surface saved to wave_pointcloud.py\n")

        // Demo 4: Spiral Galaxy
        print("4️⃣ Generating Spiral Galaxy...")
        let galaxyData = generateSpiralGalaxyData(arms: 3, points: 5000)
        let galaxyCode = galaxyData.toPythonCode()
        saveJupyterCode(galaxyCode, to: "galaxy_pointcloud.py")
        print("✅ Galaxy point cloud saved\n")

        // Demo 5: Noisy Cube
        print("5️⃣ Generating Noisy Cube...")
        let cubeData = generateNoisyCubeData(size: 10.0, pointsPerFace: 500)
        let cubeCode = cubeData.toPythonCode()
        saveJupyterCode(cubeCode, to: "cube_pointcloud.py")
        print("✅ Noisy cube saved to cube_pointcloud.py\n")

        // Generate a combined demo notebook
        print("📓 Generating Jupyter Notebook with all demos...")
        generateCombinedNotebook()

        print("🎉 Demo Complete! Generated files:")
        print("   - sphere_pointcloud.py")
        print("   - torus_pointcloud.py")
        print("   - wave_pointcloud.py")
        print("   - galaxy_pointcloud.py")
        print("   - cube_pointcloud.py")
        print("   - pointcloud_demo_notebook.py")
        print("\n💡 Tip: Run these .py files in Jupyter Notebook to see the visualizations!")
    }

    static func generateCombinedNotebook() {
        let notebookCode = """
        # Point Cloud Visualization Demo
        # Generated by Swift ChartDataExtractor
        
        import numpy as np
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d import Axes3D
        import plotly.graph_objects as go
        from plotly.subplots import make_subplots
        from mpl_toolkits.mplot3d.art3d import Poly3DCollection
        import plotly.express as px
        
        # Create a figure with multiple subplots
        fig = plt.figure(figsize=(20, 16))
        
        # You can run each demo separately by copying the generated Python files
        # This is a combined view showing the variety of point clouds you can create
        
        print("Point Cloud Visualization Demo")
        print("==============================")
        print("This notebook demonstrates various types of point clouds:")
        print("1. Sphere - Basic 3D shape")
        print("2. Torus - Shape with intensity mapping")
        print("3. Wave Surface - Mathematical function visualization")
        print("4. Spiral Galaxy - Complex pattern with intensity")
        print("5. Noisy Cube - Shape with added noise")
        print("")
        print("Run each individual .py file for detailed visualizations!")
        
        # Quick stats summary
        datasets = [
            ("Sphere", 1000, "Basic geometric shape"),
            ("Torus", 2000, "Donut shape with height-based coloring"),
            ("Wave Surface", 2500, "Mathematical sin wave surface"),
            ("Spiral Galaxy", 5000, "3-arm spiral with distance-based intensity"),
            ("Noisy Cube", 3000, "Cube faces with random noise")
        ]
        
        print("\\nDataset Summary:")
        print("-" * 60)
        for name, points, description in datasets:
            print(f"{name:15} | {points:6} points | {description}")
        
        # Create DataFrame for further analysis
        df = pd.DataFrame({
            'Dataset': [name for name, _, _ in datasets],
            'Points': [points for _, points, _ in datasets],
            'Description': [description for _, _, description in datasets]
        })
        
        print("\\nDataFrame Preview:")
        print(df.head())
        """

        saveJupyterCode(notebookCode, to: "pointcloud_demo_notebook.py")
    }

    static func saveJupyterCode(_ code: String, to filename: String) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return
        }

        let fileURL = documentsDirectory.appendingPathComponent(filename)

        do {
            try code.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Saved: \(fileURL.path)")
        } catch {
            print("❌ Error saving \(filename): \(error)")
        }
    }
}

// Break down the sidebar into smaller components
struct WindowSelectorView: View {
    @ObservedObject var windowManager: WindowTypeManager
    @Binding var selectedWindowID: Int?
    let onWindowSelected: (NewWindowID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Window")
                .font(.headline)

            if windowManager.getAllWindows().isEmpty {
                Text("No windows available")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                windowListView
            }
        }
    }

    private var windowListView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(windowManager.getAllWindows()) { window in
                    WindowRowView(
                        window: window,
                        isSelected: selectedWindowID == window.id,
                        onTap: {
                            selectedWindowID = window.id
                            onWindowSelected(window)
                        }
                    )
                }
            }
        }
        .frame(maxHeight: 150)
    }
}

struct WindowRowView: View {
    let window: NewWindowID
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                windowInfoView
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var windowInfoView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(window.windowType.displayName) #\(window.id)")
                .font(.subheadline)
                .bold()
            Text("\(window.state.exportTemplate.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
            if !window.state.tags.isEmpty {
                Text("Tags: \(window.state.tags.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
}

struct WindowConfigurationView: View {
    let windowID: Int
    @ObservedObject var windowManager: WindowTypeManager
    @Binding var selectedTemplate: ExportTemplate
    @Binding var customImports: String
    @Binding var newTag: String
    @Binding var windowContent: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Window #\(windowID) Configuration")
                .font(.headline)

            templateSectionView
            tagsSectionView
            importsSectionView
            contentSectionView
            templatePreviewView
        }
    }

    private var templateSectionView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Export Template")
                .font(.subheadline)
                .bold()
            Picker("Template", selection: $selectedTemplate) {
                ForEach(ExportTemplate.allCases, id: \.self) { template in
                    Text(template.rawValue).tag(template)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedTemplate) { newValue in
                windowManager.updateWindowTemplate(windowID, template: newValue)
            }
        }
    }

    private var tagsSectionView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tags")
                .font(.subheadline)
                .bold()

            HStack {
                TextField("Add tag", text: $newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Add") {
                    if !newTag.isEmpty {
                        windowManager.addWindowTag(windowID, tag: newTag)
                        newTag = ""
                    }
                }
                .disabled(newTag.isEmpty)
            }

            existingTagsView
        }
    }

    @ViewBuilder
    private var existingTagsView: some View {
        if let window = windowManager.getWindow(for: windowID), !window.state.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(window.state.tags, id: \.self) { tag in
                        Text(tag)
                            .padding(.horizontal, 6)
                            //.padding(.vertical: 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                            .font(.caption)
                    }
                }
            }
        }
    }

    private var importsSectionView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Custom Imports")
                .font(.subheadline)
                .bold()
            Text("One import per line")
                .font(.caption)
                .foregroundColor(.secondary)
            TextEditor(text: $customImports)
                .frame(height: 60)
                .border(Color.gray.opacity(0.3))
                .font(.system(.caption, design: .monospaced))
                .onChange(of: customImports) { newValue in
                    let imports = newValue.components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    windowManager.updateWindowImports(windowID, imports: imports)
                }
        }
    }

    private var contentSectionView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Window Content")
                .font(.subheadline)
                .bold()
            TextEditor(text: $windowContent)
                .frame(height: 100)
                .border(Color.gray.opacity(0.3))
                .font(.system(.caption, design: .monospaced))
                .onChange(of: windowContent) { newValue in
                    windowManager.updateWindowContent(windowID, content: newValue)
                }
        }
    }

    @ViewBuilder
    private var templatePreviewView: some View {
        if selectedTemplate != .plain,
           let window = windowManager.getWindow(for: windowID),
           window.state.content.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Template Preview")
                    .font(.subheadline)
                    .bold()
                ScrollView {
                    Text(selectedTemplate.defaultContent)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
                .frame(height: 80)
                .padding(6)
            }
        }
    }
}

struct ExportActionsView: View {
    @ObservedObject var windowManager: WindowTypeManager

    var body: some View {
        VStack(spacing: 8) {
            Divider()

            Text("Export Actions")
                .font(.headline)

            Button("Export to Jupyter Notebook") {
                    if let fileURL = windowManager.saveNotebookToFile() {
                        print("Notebook saved to: \(fileURL.path)")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)

            Button("Copy Notebook JSON") {
                let notebookJSON = windowManager.exportToJupyterNotebook()
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(notebookJSON, forType: .string)
                #endif
            }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct NewWindow: View {
    let id: Int
    @StateObject private var windowTypeManager = WindowTypeManager.shared
    @Environment(\.openWindow) private var openWindow   // ← NEW: visionOS-safe window opener
    @State var showFileImporter = false  // ← For USDZ import
    @State var showPointCloudImporter = false  // ← NEW: For point cloud import

    var body: some View {
        if let window = windowTypeManager.getWindowSafely(for: id) {
            VStack(spacing: 0) {
                // Window header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(window.windowType.displayName) - Window #\(id)")
                            .font(.title2)
                            .fontWeight(.semibold)

                        if !window.state.tags.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "tag")
                                    .font(.caption)
                                Text(window.state.tags.joined(separator: ", "))
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Pos: (\(Int(window.position.x)), \(Int(window.position.y)), \(Int(window.position.z)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Template: \(window.state.exportTemplate.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.blue)

                        if !window.state.content.isEmpty {
                            Text("Has Content")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground).opacity(0.3))

                Divider()

                // Display the appropriate view based on window type with restored data
                Group {
                    switch window.windowType {
                    // ───────────── 3-D MODEL ─────────────
                    case .model3d:
                        VStack {
                            Spacer()
                            // For the demo buttons:
                            Button {
                                // Generate a demo cube
                                let cubeModel = Model3DData.generateCube(size: 2.0)

                                // Convert to Python code and store as content
                                let pythonCode = cubeModel.toPythonCode()
                                windowTypeManager.updateWindowContent(id, content: pythonCode)

                                // Store a marker that this is 3D content
                                windowTypeManager.addWindowTag(id, tag: "3D-Cube")
                            } label: {
                                Label("Demo: Cube", systemImage: "cube")
                                    .font(.headline)
                                    .padding()
                                    .background(.green.opacity(0.2))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            VStack(spacing: 20) {
                                Image(systemName: "cube.transparent.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.linearGradient(
                                        colors: [.orange, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))

                                Text("3D Model Viewer")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)

                                if let model3D = window.state.model3DData {
                                    VStack(spacing: 12) {
                                        Text(model3D.title)
                                            .font(.title2)
                                            .foregroundStyle(.secondary)

                                        HStack(spacing: 40) {
                                            VStack {
                                                Text("\(model3D.vertices.count)")
                                                    .font(.title)
                                                    .fontWeight(.semibold)
                                                Text("Vertices")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            VStack {
                                                Text("\(model3D.faces.count)")
                                                    .font(.title)
                                                    .fontWeight(.semibold)
                                                Text("Faces")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            VStack {
                                                Text(model3D.modelType)
                                                    .font(.title)
                                                    .fontWeight(.semibold)
                                                Text("Type")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(.top)
                                    }
                                } else if window.state.usdzBookmark != nil {
                                    Text("Imported USDZ Model")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                }

                                Text("This content is displayed in a volumetric window")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.top)

                                Button {
                                    // Open the volumetric window (visionOS-safe)
                                    openWindow(id: "volumetric-model3d", value: id)
                                } label: {
                                    Label("Open Volumetric View", systemImage: "view.3d")
                                        .font(.headline)
                                        .padding()
                                        .background(.orange.opacity(0.2))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showFileImporter = true
                                } label: {
                                    Label("Import USDZ Model", systemImage: "square.and.arrow.down")
                                        .font(.headline)
                                        .padding()
                                        .background(.blue.opacity(0.2))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(40)

                            Spacer()
                        }
                        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.usdz], allowsMultipleSelection: false) { result in
                            if let url = try? result.get().first {
                                Task {
                                    do {
                                        // Save the bookmark
                                        let bookmark = try url.bookmarkData()
                                        windowTypeManager.updateUSDZBookmark(for: id, bookmark: bookmark)

                                        // For now, create a placeholder Model3DData
                                        // In a real app, you would parse the USDZ file here
                                        let placeholderModel = Model3DData(
                                            title: url.lastPathComponent,
                                            modelType: "usdz",
                                            scale: 1.0
                                        )

                                        // Update the model data so the volumetric window can display it
                                        windowTypeManager.updateWindowModel3D(id, modelData: placeholderModel)

                                    } catch {
                                        print("Failed to import USDZ: \(error)")
                                    }
                                }
                            }
                        }
                    // ───────────── POINT CLOUD ─────────────
                    case .pointcloud:
                        VStack {
                            Spacer()

                            VStack(spacing: 20) {
                                Image(systemName: "dot.scope")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.linearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))

                                Text("Point Cloud Viewer")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)

                                if let pointCloud = window.state.pointCloudData {
                                    VStack(spacing: 12) {
                                        Text(pointCloud.title)
                                            .font(.title2)
                                            .foregroundStyle(.secondary)

                                        HStack(spacing: 40) {
                                            VStack {
                                                Text("\(pointCloud.totalPoints)")
                                                    .font(.title)
                                                    .fontWeight(.semibold)
                                                Text("Points")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            VStack {
                                                Text(pointCloud.demoType)
                                                    .font(.title)
                                                    .fontWeight(.semibold)
                                                Text("Type")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(.top)
                                    }
                                } else if window.state.pointCloudBookmark != nil {
                                    Text("Imported Point Cloud")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                }

                                Text("This content is displayed in a volumetric window")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.top)

                                Button {
                                    // Open the volumetric window (visionOS-safe)
                                    openWindow(id: "volumetric-pointcloud", value: id)
                                } label: {
                                    Label("Open Volumetric View", systemImage: "view.3d")
                                        .font(.headline)
                                        .padding()
                                        .background(.purple.opacity(0.2))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showPointCloudImporter = true
                                } label: {
                                    Label("Import Point Cloud", systemImage: "square.and.arrow.down")
                                        .font(.headline)
                                        .padding()
                                        .background(.green.opacity(0.2))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(40)

                            Spacer()
                        }
                        .fileImporter(isPresented: $showPointCloudImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
                            if let url = try? result.get().first, ["ply", "pcd", "xyz", "csv"].contains(url.pathExtension.lowercased()) {
                                Task {
                                    do {
                                        let bookmark = try url.bookmarkData(options: .minimalBookmark)
                                        windowTypeManager.updatePointCloudBookmark(for: id, bookmark: bookmark)
                                    } catch {
                                        print("Failed to import point cloud: \(error)")
                                    }
                                }
                            } else {
                                print("Unsupported file type")
                            }
                        }

                    // ───────────── CHARTS ─────────────
                    case .charts:
                        VStack {
                            if !window.state.content.isEmpty {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Restored Content:")
                                            .font(.headline)

                                        Text(window.state.content)
                                            .font(.system(.caption, design: .monospaced))
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(.tertiarySystemBackground))
                                            .cornerRadius(8)
                                    }
                                    .padding()
                                }
                                .frame(maxHeight: 200)

                                Divider()
                            }

                            WindowChartView()
                        }

                    // ───────────── SPATIAL EDITOR ─────────────
                    case .spatial:
                        //if let pointCloud = window.state.pointCloudData {
                        //    SpatialEditorView(windowID: id, initialPointCloud: pointCloud)
                        //} else {
                        SpatialEditorView(windowID: id)
                        //}

                    // ───────────── DATAFRAME ─────────────
                    case .column:
                        if let df = window.state.dataFrameData {
                            DataTableContentView(windowID: id, initialDataFrame: df)
                        } else {
                            DataTableContentView(windowID: id)
                        }

                    // ───────────── VOLUME METRICS ─────────────
                    case .volume:
                        VStack {
                            if !window.state.content.isEmpty {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Model Metrics:")
                                            .font(.headline)

                                        Text(window.state.content)
                                            .font(.system(.caption, design: .monospaced))
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(.tertiarySystemBackground))
                                            .cornerRadius(8)
                                    }
                                    .padding()
                                }
                            } else {
                                VStack(spacing: 20) {
                                    Image(systemName: "gauge")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.blue)

                                    Text("Model Metrics Viewer")
                                        .font(.title2)
                                        .fontWeight(.semibold)

                                    Text("Performance metrics and monitoring dashboard")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(40)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear {
                windowTypeManager.markWindowAsOpened(id)
            }
            .onDisappear {
                windowTypeManager.markWindowAsClosed(id)
            }
        } else {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)

                Text("Window #\(id) Unavailable")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("This window may have been closed or removed from the workspace.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Cleanup Closed Windows") {
                    windowTypeManager.cleanupClosedWindows()
                }
                .buttonStyle(.bordered)
            }
            .padding(40)
            .onAppear {
                windowTypeManager.markWindowAsClosed(id)
            }
        }
    }
}

// MARK: - Preview Provider


#Preview("Spatial Editor") {
    SpatialEditorView()
}