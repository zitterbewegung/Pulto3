//  Enhanced NewWindowID.swift with Point Cloud Integration
//  UnderstandingVisionos
//
//  Created by Joshua Herman on 5/25/25.
//

import SwiftUI
import Foundation
import Charts

enum WindowType: String, CaseIterable, Codable, Hashable {
    case charts = "Charts"
    case spatial = "Spatial Editor"
    case column = "DataFrame Viewer"
    case volume = "Model Metric Viewer"
    case pointcloud = "Point Cloud Viewer"
    case model3d = "3D Model Viewer"  // Add this new case

    var displayName: String {
        return self.rawValue
    }

    var jupyterCellType: String {
        switch self {
        case .charts:
            return "code"
        case .spatial:
            return "spatial"
        case .column:
            return "code"
        case .volume:
            return "code"
        case .pointcloud:
            return "code"
        case .model3d:  // Add this case
            return "code"
        }
    }
}

struct WindowPosition: Codable, Hashable {
    var x: Double
    var y: Double
    var z: Double
    var width: Double
    var height: Double
    var depth: Double?

    init(x: Double = 0, y: Double = 0, z: Double = 0,
         width: Double = 400, height: Double = 300, depth: Double? = nil) {
        self.x = x
        self.y = y
        self.z = z
        self.width = width
        self.height = height
        self.depth = depth
    }
}

enum ExportTemplate: String, CaseIterable, Codable {
    case plain = "Plain Text"
    case matplotlib = "Matplotlib Chart"
    case pandas = "Pandas DataFrame"
    case numpy = "NumPy Array"
    case plotly = "Plotly Interactive"
    case seaborn = "Seaborn Statistical"
    case custom = "Custom Code"
    case markdown = "Markdown Only"

    var defaultImports: [String] {
        switch self {
        case .plain:
            return []
        case .matplotlib:
            return ["import matplotlib.pyplot as plt", "import numpy as np"]
        case .pandas:
            return ["import pandas as pd", "import numpy as np"]
        case .numpy:
            return ["import numpy as np"]
        case .plotly:
            return ["import plotly.graph_objects as go", "import plotly.express as px", "import pandas as pd"]
        case .seaborn:
            return ["import seaborn as sns", "import matplotlib.pyplot as plt", "import pandas as pd"]
        case .custom:
            return []
        case .markdown:
            return []
        }
    }

    var defaultContent: String {
        switch self {
        case .plain:
            return "# Add your code here"
        case .matplotlib:
            return """
            # Create figure and axis
            fig, ax = plt.subplots(figsize=(10, 6))
            
            # Your plotting code here
            # ax.plot(x, y)
            
            plt.show()
            """
        case .pandas:
            return """
            # Create or load your DataFrame
            # df = pd.read_csv('your_file.csv')
            # df = pd.DataFrame({'col1': [1, 2, 3], 'col2': [4, 5, 6]})
            
            # Display DataFrame info
            # print(df.head())
            # print(df.describe())
            """
        case .numpy:
            return """
            # Create numpy arrays
            # arr = np.array([1, 2, 3, 4, 5])
            
            # Your numpy operations here
            """
        case .plotly:
            return """
            # Create interactive plot
            # fig = go.Figure()
            # fig.add_trace(go.Scatter(x=[1, 2, 3, 4], y=[10, 11, 12, 13]))
            # fig.show()
            """
        case .seaborn:
            return """
            # Set style
            sns.set_style("whitegrid")
            
            # Create statistical plot
            # sns.scatterplot(data=df, x='col1', y='col2')
            # plt.show()
            """
        case .custom:
            return "# Add your custom code here"
        case .markdown:
            return "Add your markdown content here"
        }
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
        
        import matplotlib.pyplot as plt
        import numpy as np
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
        from mpl_toolkits.mplot3d.art3d import Poly3DCollection
        import plotly.graph_objects as go
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
            if len(face) >= 3:  # Valid face
                face_vertices = scaled_vertices[face]
                mesh_faces.append(face_vertices)
        
        if mesh_faces:
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
    var volumeData: VolumeData? = nil        // Add this
    var chartData: ChartData? = nil          // Add this
    var model3DData: Model3DData? = nil  // Add this

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
        
        import json
        import matplotlib.pyplot as plt
        import pandas as pd
        import numpy as np
        from mpl_toolkits.mplot3d import Axes3D
        import plotly.graph_objects as go
        from plotly.subplots import make_subplots
        
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
                            .padding(.vertical, 2)
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
                }
                .frame(height: 80)
                .padding(6)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
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

struct ExportConfigurationSidebar: View {
    @StateObject private var windowManager = WindowTypeManager.shared
    @State private var selectedWindowID: Int? = nil
    @State private var selectedTemplate: ExportTemplate = .plain
    @State private var customImports = ""
    @State private var newTag = ""
    @State private var windowContent = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            headerView
            windowSelectorSection
            configurationSection
            Spacer()
            exportActionsSection
        }
        .padding()
        .frame(width: 300)
    }

    private var headerView: some View {
        Text("Export Configuration")
            .font(.title2)
            .bold()
    }

    private var windowSelectorSection: some View {
        WindowSelectorView(
            windowManager: windowManager,
            selectedWindowID: $selectedWindowID,
            onWindowSelected: loadWindowConfiguration
        )
    }

    @ViewBuilder
    private var configurationSection: some View {
        if let windowID = selectedWindowID {
            Divider()
            WindowConfigurationView(
                windowID: windowID,
                windowManager: windowManager,
                selectedTemplate: $selectedTemplate,
                customImports: $customImports,
                newTag: $newTag,
                windowContent: $windowContent
            )
        }
    }

    private var exportActionsSection: some View {
        ExportActionsView(windowManager: windowManager)
    }

    private func loadWindowConfiguration(_ window: NewWindowID) {
        selectedTemplate = window.state.exportTemplate
        customImports = window.state.customImports.joined(separator: "\n")
        windowContent = window.state.content
    }
}

// MARK: - Updated OpenWindowView with Environment Restoration

struct OpenWindowView: View {
    @State var nextWindowID = 1
    @Environment(\.openWindow) private var openWindow
    @StateObject private var windowManager = WindowTypeManager.shared
    @State private var showExportSidebar = false
    @State private var showImportDialog = false
    @State private var showTemplateGallery = false

    // HIG-compliant sizing constants - ADD THESE
    private let standardPadding: CGFloat = 20
    private let sectionSpacing: CGFloat = 32
    private let itemSpacing: CGFloat = 16
    private let cornerRadius: CGFloat = 12

    var body: some View {
        HStack(spacing: 0) {
            // Main content
            ScrollView {
                VStack(spacing: sectionSpacing) {
                    headerSection
                    windowTypeSection
                    quickActionsSection

                    if !windowManager.getAllWindows().isEmpty {
                        activeWindowsSection
                    }
                }
                .padding(standardPadding * 2)
                .frame(minWidth: 800)
            }
            .frame(maxWidth: .infinity)

            // Export configuration sidebar
            if showExportSidebar {
                ExportConfigurationSidebar()
                    .frame(width: 400)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showExportSidebar)
        .frame(minHeight: 800)
        .sheet(isPresented: $showImportDialog) {
            NotebookImportDialog(
                isPresented: $showImportDialog,
                windowManager: windowManager
            )
        }
        .sheet(isPresented: $showTemplateGallery) {
            TemplateView()
                .frame(minWidth: 1000, minHeight: 700)
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("VisionOS Workspace")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Create and manage volumetric windows in 3D space")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, itemSpacing)
    }

    private var windowTypeSection: some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            Text("Create New Window")
                .font(.title2)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: itemSpacing),
                GridItem(.flexible(), spacing: itemSpacing)
            ], spacing: itemSpacing) {
                ForEach(WindowType.allCases, id: \.self) { windowType in
                    windowTypeButton(for: windowType)
                }
            }
        }
        .padding(standardPadding)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private func windowTypeButton(for windowType: WindowType) -> some View {
        Button(action: {
            createWindow(type: windowType)
        }) {
            VStack(spacing: 12) {
                Image(systemName: iconForWindowType(windowType))
                    .font(.system(size: 40))
                    .fontWeight(.light)
                    .foregroundStyle(.tint)

                Text(windowType.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Tap to create")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .padding(standardPadding)
        }
        .buttonStyle(.plain)
        .background(.quaternary.opacity(0.5))
        .backgroundStyle(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .hoverEffect()
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workspace Management")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Save, load, and manage your 3D workspace")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: { showExportSidebar.toggle() }) {
                    Label(
                        showExportSidebar ? "Hide Configuration" : "Show Configuration",
                        systemImage: showExportSidebar ? "sidebar.trailing" : "sidebar.leading"
                    )
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            // Primary Actions - Save and Restore
            VStack(spacing: itemSpacing) {
                HStack(spacing: itemSpacing) {
                    Button(action: exportToJupyter) {
                        VStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)

                            VStack(spacing: 4) {
                                Text("Save Workspace")
                                    .font(.headline)
                                Text("Export current state")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: { showTemplateGallery = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "cube.box.fill")
                                .font(.title2)

                            VStack(spacing: 4) {
                                Text("Template Gallery")
                                    .font(.headline)
                                Text("Load pre-built workspace")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                // Secondary Actions
                HStack(spacing: itemSpacing) {
                    Button(action: { showImportDialog = true }) {
                        Label("Import Notebook", systemImage: "square.and.arrow.down")
                            .font(.body)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button(action: createSampleWorkspace) {
                        Label("Create Demo", systemImage: "doc.badge.plus")
                            .font(.body)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button(action: clearAllWindowsWithConfirmation) {
                        Label("Clear All", systemImage: "trash")
                            .font(.body)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .foregroundStyle(.red)
                }
            }
        }
        .padding(standardPadding)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var activeWindowsSection: some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Windows")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("\(windowManager.getAllWindows().count) window\(windowManager.getAllWindows().count == 1 ? "" : "s") open")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Close All") {
                    clearAllWindowsWithConfirmation()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.red)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(windowManager.getAllWindows()) { window in
                        HStack(spacing: 12) {
                            Image(systemName: iconForWindowType(window.windowType))
                                .font(.title3)
                                .foregroundStyle(.tint)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(window.windowType.displayName)")
                                    .font(.headline)

                                HStack(spacing: 8) {
                                    Label("ID: #\(window.id)", systemImage: "number")
                                        .font(.caption)

                                    Label("\(window.state.exportTemplate.rawValue)", systemImage: "doc.text")
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("(\(Int(window.position.x)), \(Int(window.position.y)), \(Int(window.position.z)))")
                                .font(.caption2)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.quaternary)
                                .clipShape(Capsule())
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                Button(action: {
                                    openWindow(value: window.id)
                                }) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.callout)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .help("Focus Window")

                                Button(action: {
                                    windowManager.removeWindow(window.id)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.callout)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .help("Close Window")
                            }
                        }
                        .padding(12)
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(maxHeight: 400)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(standardPadding)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    // MARK: - Helper Functions

    private func createWindow(type: WindowType) {
        let position = WindowPosition(
            x: Double.random(in: -200...200),
            y: Double.random(in: -100...100),
            z: Double.random(in: -50...50),
            width: 600,
            height: 450
        )

        _ = windowManager.createWindow(type, id: nextWindowID, position: position)
        openWindow(value: nextWindowID)
        nextWindowID += 1
    }

    private func exportToJupyter() {
        if let fileURL = windowManager.saveNotebookToFile() {
            print("✅ Workspace saved to: \(fileURL.path)")
        }
    }

    private func createSampleWorkspace() {
        let windowTypes: [WindowType] = [.charts, .spatial, .column, .volume]  // Add .volume here

        for (index, type) in windowTypes.enumerated() {
            let position = WindowPosition(
                x: Double(index * 150 - 150),
                y: Double(index * 75),
                z: Double(index * 50),
                width: 500,
                height: 400
            )

            _ = windowManager.createWindow(type, id: nextWindowID, position: position)

            switch type {
            case .charts:
                windowManager.updateWindowContent(nextWindowID, content: """
                # Sample Chart
                plt.figure(figsize=(10, 6))
                x = np.linspace(0, 10, 100)
                y = np.sin(x)
                plt.plot(x, y)
                plt.title('Sample Sine Wave')
                plt.show()
                """)
                windowManager.updateWindowTemplate(nextWindowID, template: .matplotlib)

            case .spatial:
                let samplePointCloud = PointCloudDemo.generateSpherePointCloudData(radius: 5.0, points: 500)
                windowManager.updateWindowPointCloud(nextWindowID, pointCloud: samplePointCloud)

            case .column:
                let sampleDataFrame = DataFrameData(
                    columns: ["Name", "Value", "Category"],
                    rows: [
                        ["Sample A", "100", "Type 1"],
                        ["Sample B", "200", "Type 2"],
                        ["Sample C", "150", "Type 1"]
                    ],
                    dtypes: ["Name": "string", "Value": "int", "Category": "string"]
                )
                windowManager.updateWindowDataFrame(nextWindowID, dataFrame: sampleDataFrame)
                windowManager.updateWindowTemplate(nextWindowID, template: .pandas)
            case .model3d:  // Add this case
                let sampleCube = Model3DData.generateCube(size: 3.0)
                windowManager.updateWindowModel3DData(nextWindowID, model3DData: sampleCube)
                windowManager.updateWindowTemplate(nextWindowID, template: .custom)
            case .volume:  // Add this case
                windowManager.updateWindowContent(nextWindowID, content: """
                # Model Performance Metrics
                import numpy as np
                import matplotlib.pyplot as plt
                
                # Sample metrics data
                metrics = {
                    'accuracy': 0.95,
                    'precision': 0.92,
                    'recall': 0.89,
                    'f1_score': 0.90,
                    'latency_ms': 120,
                    'throughput_rps': 300,
                    'memory_usage_mb': 512,
                    'cpu_usage_percent': 45
                }
                
                print("Model Performance Metrics:")
                for key, value in metrics.items():
                    print(f"{key}: {value}")
                
                # Create a simple metrics visualization
                fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))
                
                # Performance metrics
                perf_metrics = ['accuracy', 'precision', 'recall', 'f1_score']
                perf_values = [metrics[m] for m in perf_metrics]
                ax1.bar(perf_metrics, perf_values)
                ax1.set_title('Model Performance')
                ax1.set_ylim(0, 1)
                
                # System metrics
                sys_metrics = ['latency_ms', 'throughput_rps', 'memory_usage_mb', 'cpu_usage_percent']
                sys_values = [metrics[m] for m in sys_metrics]
                ax2.bar(sys_metrics, sys_values)
                ax2.set_title('System Metrics')
                
                plt.tight_layout()
                plt.show()
                """)
                windowManager.updateWindowTemplate(nextWindowID, template: .custom)
            case .pointcloud:  // Add this case
                    let sampleTorus = PointCloudDemo.generateTorusPointCloudData(majorRadius: 8.0, minorRadius: 3.0, points: 1000)
                    windowManager.updateWindowPointCloud(nextWindowID, pointCloud: sampleTorus)
                    windowManager.updateWindowTemplate(nextWindowID, template: .custom)

            }

            windowManager.addWindowTag(nextWindowID, tag: "demo")
            openWindow(value: nextWindowID)
            nextWindowID += 1
        }
    }

    private func clearAllWindowsWithConfirmation() {
        let allWindows = windowManager.getAllWindows()
        for window in allWindows {
            windowManager.removeWindow(window.id)
        }
    }

    private func iconForWindowType(_ type: WindowType) -> String {
        switch type {
        case .charts:
            return "chart.line.uptrend.xyaxis"
        case .spatial:
            return "cube"
        case .column:
            return "tablecells"
        case .volume:
            return "gauge"
        case .pointcloud:
            return "dot.scope"
        case .model3d:  // Add this case
            return "cube.transparent"
        }
    }

    private func updateNextWindowID() {
        let currentMaxID = windowManager.getAllWindows().map { $0.id }.max() ?? 0
        nextWindowID = currentMaxID + 1
    }
}


// Replace the NewWindow struct in OpenWindowView.swift with this updated version:

struct NewWindow: View {
    let id: Int
    @StateObject private var windowTypeManager = WindowTypeManager.shared

    var body: some View {
        if let window = windowTypeManager.getWindow(for: id) {
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

                    case .model3d:  // Add this case
                        VStack {
                            if let model3D = window.state.model3DData {
                                // You could create a Model3DView here, or for now show info
                                VStack(spacing: 20) {
                                    Image(systemName: "cube.transparent")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.orange)

                                    Text("3D Model: \(model3D.title)")
                                        .font(.title2)
                                        .fontWeight(.semibold)

                                    Text("\(model3D.vertices.count) vertices, \(model3D.faces.count) faces")
                                        .font(.body)
                                        .foregroundStyle(.secondary)

                                    if !window.state.content.isEmpty {
                                        ScrollView {
                                            Text(window.state.content)
                                                .font(.system(.caption, design: .monospaced))
                                                .padding(8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color(.tertiarySystemBackground))
                                                .cornerRadius(8)
                                        }
                                        .frame(maxHeight: 150)
                                    }
                                }
                                .padding(40)
                            } else {
                                VStack(spacing: 20) {
                                    Image(systemName: "cube.transparent")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.orange)

                                    Text("3D Model Viewer")
                                        .font(.title2)
                                        .fontWeight(.semibold)

                                    Text("3D mesh and model visualization")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(40)
                            }
                        }

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

                    case .spatial:
                        // Use the initializer with point cloud data if available
                        if let pointCloud = window.state.pointCloudData {
                            SpatialEditorView(windowID: id, initialPointCloud: pointCloud)
                        } else {
                            SpatialEditorView(windowID: id)
                        }

                    case .column:
                        // Use the initializer with DataFrame data if available
                        if let df = window.state.dataFrameData {
                            DataTableContentView(windowID: id, initialDataFrame: df)
                        } else {
                            DataTableContentView(windowID: id)   // falls back to saved window or sample
                        }
                    case .pointcloud:  // Add this case
                        VStack {
                            if let pointCloud = window.state.pointCloudData {
                                SpatialEditorView(windowID: id, initialPointCloud: pointCloud)
                            } else {
                                VStack(spacing: 20) {
                                    Image(systemName: "dot.scope")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.purple)

                                    Text("Point Cloud Viewer")
                                        .font(.title2)
                                        .fontWeight(.semibold)

                                    Text("3D point cloud visualization and analysis")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(40)
                            }
                        }

                    case .volume:  // NEW: Handle volume windows
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
        } else {
            // Window not found
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)

                Text("Window #\(id) not found")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("This window may have been closed or not properly initialized.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Check Window Manager") {
                    print("=== Window Manager Debug ===")
                    print("Looking for window ID: \(id)")
                    print("All windows:")
                    for window in windowTypeManager.getAllWindows() {
                        print("  - Window #\(window.id): \(window.windowType.rawValue)")
                    }
                    print("========================")
                }
                .buttonStyle(.bordered)
            }
            .padding(40)
        }
    }
}


// MARK: - Preview Provider
#Preview("Main Interface") {
    OpenWindowView()
}

/*#Preview("Point Cloud Preview") {
  PointCloudPreview()
}*/

#Preview("Spatial Editor") {
    SpatialEditorView()
}
