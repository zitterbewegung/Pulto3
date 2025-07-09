//
//  WindowTypes.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/8/25.
//  Copyright 2025 Apple. All rights reserved.
//

import Foundation
import SwiftUI
import simd

// MARK: - Core Window Types

enum WindowType: String, CaseIterable, Codable, Hashable {
    case charts = "Charts"
    case spatial = "Spatial Editor"
    case column = "DataFrame Viewer"
    case volume = "Model Metric Viewer"
    case pointcloud = "Point Cloud Viewer"
    case model3d = "3D Model Viewer"

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
        case .model3d:
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

// MARK: - Data Structures

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

    // Static methods for generating primitive shapes
    static func generateSphere(radius: Double, segments: Int) -> Model3DData {
        var model = Model3DData(title: "Generated Sphere", modelType: "sphere")
        
        // Generate vertices for sphere
        let deltaTheta = Double.pi / Double(segments)
        let deltaPhi = 2.0 * Double.pi / Double(segments)
        
        for i in 0...segments {
            let theta = Double(i) * deltaTheta
            for j in 0...segments {
                let phi = Double(j) * deltaPhi
                
                let x = radius * sin(theta) * cos(phi)
                let y = radius * cos(theta)
                let z = radius * sin(theta) * sin(phi)
                
                model.vertices.append(Vertex3D(x: x, y: y, z: z))
            }
        }
        
        // Generate faces
        for i in 0..<segments {
            for j in 0..<segments {
                let first = i * (segments + 1) + j
                let second = first + segments + 1
                
                // First triangle
                model.faces.append(Face3D(vertices: [first, second, first + 1]))
                // Second triangle  
                model.faces.append(Face3D(vertices: [second, second + 1, first + 1]))
            }
        }
        
        // Add default material
        model.materials.append(Material3D(name: "Default", color: "blue"))
        
        return model
    }
    
    static func generateCube(size: Double) -> Model3DData {
        var model = Model3DData(title: "Generated Cube", modelType: "cube")
        
        let half = size / 2.0
        
        // Generate vertices for cube
        model.vertices = [
            Vertex3D(x: -half, y: -half, z: -half), // 0
            Vertex3D(x:  half, y: -half, z: -half), // 1
            Vertex3D(x:  half, y:  half, z: -half), // 2
            Vertex3D(x: -half, y:  half, z: -half), // 3
            Vertex3D(x: -half, y: -half, z:  half), // 4
            Vertex3D(x:  half, y: -half, z:  half), // 5
            Vertex3D(x:  half, y:  half, z:  half), // 6
            Vertex3D(x: -half, y:  half, z:  half)  // 7
        ]
        
        // Generate faces for cube
        model.faces = [
            Face3D(vertices: [0, 1, 2, 3]), // front
            Face3D(vertices: [4, 7, 6, 5]), // back
            Face3D(vertices: [0, 4, 5, 1]), // bottom
            Face3D(vertices: [2, 6, 7, 3]), // top
            Face3D(vertices: [0, 3, 7, 4]), // left
            Face3D(vertices: [1, 5, 6, 2])  // right
        ]
        
        // Add default material
        model.materials.append(Material3D(name: "Default", color: "red"))
        
        return model
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
        for face in faces {
            if len(face) >= 3:  // Valid face
                face_vertices = scaled_vertices[face]
                mesh_faces.append(face_vertices)
        }
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
        
        # Print model statistics
        print(f"3D Model Statistics:")
        print(f"- Title: '\(title)'")
        print(f"- Model Type: '\(modelType)'")
        print(f"- Vertices: {len(vertices)}")
        print(f"- Faces: {len(faces)}")
        print(f"- Scale: {scale}")
        print(f"- Position: [{np.min(scaled_vertices[:, 0]):.2f}, {np.min(scaled_vertices[:, 1]):.2f}, {np.min(scaled_vertices[:, 2]):.2f}]")
        print(f"- Bounding Box:")
        print(f"  X: [{np.min(scaled_vertices[:, 0]):.2f}, {np.max(scaled_vertices[:, 0]):.2f}]")
        print(f"  Y: [{np.min(scaled_vertices[:, 1]):.2f}, {np.max(scaled_vertices[:, 1]):.2f}]")
        print(f"  Z: [{np.min(scaled_vertices[:, 2]):.2f}, {np.max(scaled_vertices[:, 2]):.2f}]")
        """
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

    // Enhanced Pandas code generation
    func toEnhancedPandasCode() -> String {
        guard !columns.isEmpty && !rows.isEmpty else {
            return "# Empty DataFrame\ndf = pd.DataFrame()\nprint('No data available')"
        }

        var code = """
        # Enhanced DataFrame Analysis
        # Generated from VisionOS DataFrame Viewer
        
        import pandas as pd
        import numpy as np
        import matplotlib.pyplot as plt
        import seaborn as sns
        import plotly.express as px
        import plotly.graph_objects as go
        
        # DataFrame data
        data = {
        """

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

        code += """
        # Enhanced DataFrame analysis
        print("DataFrame Analysis Report")
        print("=" * 50)
        print(f"Shape: {df.shape}")
        print(f"Columns: {list(df.columns)}")
        print(f"Data types:")
        print(df.dtypes)
        print("\\nBasic Statistics:")
        print(df.describe(include='all'))
        
        # Missing values analysis
        print("\\nMissing Values:")
        missing_vals = df.isnull().sum()
        if missing_vals.sum() > 0:
            print(missing_vals[missing_vals > 0])
        else:
            print("No missing values found")
        
        # Memory usage
        print("\\nMemory Usage:")
        print(df.memory_usage(deep=True))
        
        # Sample data
        print("\\nFirst 10 rows:")
        print(df.head(10))
        print("\\nLast 5 rows:")
        print(df.tail(5))
        
        # Visualizations
        numeric_cols = df.select_dtypes(include=[np.number]).columns
        
        if len(numeric_cols) > 0:
            print("\\nGenerating visualizations...")
            
            # Correlation heatmap
            if len(numeric_cols) > 1:
                plt.figure(figsize=(10, 8))
                correlation_matrix = df[numeric_cols].corr()
                sns.heatmap(correlation_matrix, annot=True, cmap='coolwarm', center=0)
                plt.title('Correlation Heatmap')
                plt.tight_layout()
                plt.show()
            
            # Distribution plots
            if len(numeric_cols) <= 4:
                fig, axes = plt.subplots(2, 2, figsize=(15, 12))
                axes = axes.flatten()
                
                for i, col in enumerate(numeric_cols):
                    if i < 4:
                        df[col].hist(bins=20, ax=axes[i], alpha=0.7)
                        axes[i].set_title(f'Distribution of {col}')
                        axes[i].set_xlabel(col)
                        axes[i].set_ylabel('Frequency')
                        axes[i].grid(True, alpha=0.3)
                
                # Hide unused subplots
                for i in range(len(numeric_cols), 4):
                    axes[i].set_visible(False)
                    
                plt.tight_layout()
                plt.show()
            
            # Interactive plot with Plotly
            if len(numeric_cols) >= 2:
                fig = px.scatter_matrix(df, dimensions=numeric_cols.tolist()[:5], 
                                      title="Interactive Scatter Matrix")
                fig.show()
        
        # Categorical analysis
        categorical_cols = df.select_dtypes(include=['object']).columns
        if len(categorical_cols) > 0:
            print("\\nCategorical Variables Analysis:")
            for col in categorical_cols:
                print(f"\\n{col}:")
                print(df[col].value_counts().head(10))
                
                # Plot top categories
                if len(df[col].value_counts()) <= 20:
                    plt.figure(figsize=(10, 6))
                    df[col].value_counts().plot(kind='bar')
                    plt.title(f'Distribution of {col}')
                    plt.xlabel(col)
                    plt.ylabel('Count')
                    plt.xticks(rotation=45)
                    plt.tight_layout()
                    plt.show()
        
        # Export options
        print("\\nExport Options:")
        print("# Save to CSV: df.to_csv('dataframe_export.csv', index=False)")
        print("# Save to Excel: df.to_excel('dataframe_export.xlsx', index=False)")
        print("# Save to JSON: df.to_json('dataframe_export.json', orient='records')")
        """

        return code
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
}

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

    // Enhanced Python code generation
    func toEnhancedPythonCode() -> String {
        guard !xData.isEmpty && !yData.isEmpty else {
            return "# Empty chart data\nprint('No chart data available')"
        }

        let xDataString = xData.map { String($0) }.joined(separator: ", ")
        let yDataString = yData.map { String($0) }.joined(separator: ", ")

        return """
        # \(title)
        # Enhanced chart generation from VisionOS Chart Window
        
        import numpy as np
        import matplotlib.pyplot as plt
        import pandas as pd
        import seaborn as sns
        import plotly.graph_objects as go
        import plotly.express as px
        
        # Chart data
        x_data = np.array([\(xDataString)])
        y_data = np.array([\(yDataString)])
        
        # Create DataFrame for easy manipulation
        df = pd.DataFrame({'X': x_data, 'Y': y_data})
        
        # Enhanced matplotlib visualization
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 12))
        
        # Original chart
        \(generateEnhancedPlotCode())
        ax1.set_xlabel('\(xLabel)')
        ax1.set_ylabel('\(yLabel)')
        ax1.set_title('\(title) - Original')
        ax1.grid(True, alpha=0.3)
        
        # Smoothed version
        if len(x_data) > 3:
            from scipy.interpolate import interp1d
            f = interp1d(x_data, y_data, kind='cubic')
            x_smooth = np.linspace(x_data.min(), x_data.max(), 100)
            y_smooth = f(x_smooth)
            ax2.plot(x_smooth, y_smooth, '-', alpha=0.8, linewidth=2)
            ax2.scatter(x_data, y_data, alpha=0.6, s=50, zorder=5)
        else:
            ax2.plot(x_data, y_data, 'o-', alpha=0.8)
        ax2.set_xlabel('\(xLabel)')
        ax2.set_ylabel('\(yLabel)')
        ax2.set_title('\(title) - Smoothed')
        ax2.grid(True, alpha=0.3)
        
        # Statistical analysis
        ax3.hist(y_data, bins=min(20, len(y_data)//2), alpha=0.7, edgecolor='black')
        ax3.set_xlabel('\(yLabel)')
        ax3.set_ylabel('Frequency')
        ax3.set_title('Distribution of \(yLabel)')
        ax3.grid(True, alpha=0.3)
        
        # Trend analysis
        if len(x_data) > 1:
            z = np.polyfit(x_data, y_data, 1)
            p = np.poly1d(z)
            ax4.plot(x_data, y_data, 'o', alpha=0.7)
            ax4.plot(x_data, p(x_data), 'r--', alpha=0.8, linewidth=2)
            ax4.set_xlabel('\(xLabel)')
            ax4.set_ylabel('\(yLabel)')
            ax4.set_title('Trend Analysis')
            ax4.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.show()
        
        # Interactive Plotly visualization
        fig_plotly = go.Figure()
        
        fig_plotly.add_trace(go.Scatter(
            x=x_data,
            y=y_data,
            mode='lines+markers',
            name='\(title)',
            line=dict(width=2),
            marker=dict(size=8)
        ))
        
        fig_plotly.update_layout(
            title='\(title) - Interactive',
            xaxis_title='\(xLabel)',
            yaxis_title='\(yLabel)',
            hovermode='x unified',
            showlegend=True
        )
        
        fig_plotly.show()
        
        # Enhanced data statistics
        print("Enhanced Chart Data Analysis:")
        print("=" * 50)
        print(f"Title: {'\(title)'}") 
        print(f"Chart Type: {'\(chartType)'}")
        print(f"Data points: {len(x_data)}")
        print(f"X range: [{np.min(x_data):.3f}, {np.max(x_data):.3f}]")
        print(f"Y range: [{np.min(y_data):.3f}, {np.max(y_data):.3f}]")
        print(f"Y statistics:")
        print(f"  Mean: {np.mean(y_data):.3f}")
        print(f"  Median: {np.median(y_data):.3f}")
        print(f"  Std Dev: {np.std(y_data):.3f}")
        print(f"  Min: {np.min(y_data):.3f}")
        print(f"  Max: {np.max(y_data):.3f}")
        
        # Correlation analysis
        if len(x_data) > 1:
            correlation = np.corrcoef(x_data, y_data)[0, 1]
            print(f"Correlation coefficient: {correlation:.3f}")
        
        # DataFrame preview
        print("\\nDataFrame Preview:")
        print(df.head(10))
        print("\\nDataFrame Description:")
        print(df.describe())
        """
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

    private func generateEnhancedPlotCode() -> String {
        let colorCode = color != nil ? ", color='\(color!)'" : ""
        let styleCode = style != nil ? ", linestyle='\(style!)'" : ""

        switch chartType.lowercased() {
        case "scatter":
            return "ax1.scatter(x_data, y_data\(colorCode), alpha=0.7, s=50)"
        case "bar":
            return "ax1.bar(x_data, y_data\(colorCode), alpha=0.8)"
        case "line":
            return "ax1.plot(x_data, y_data\(colorCode)\(styleCode), marker='o', markersize=6, linewidth=2)"
        case "area":
            return "ax1.fill_between(x_data, y_data\(colorCode), alpha=0.6)"
        default:
            return "ax1.plot(x_data, y_data\(colorCode)\(styleCode), marker='o', markersize=4)"
        }
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
    var volumeData: VolumeData? = nil
    var chartData: ChartData? = nil
    var model3DData: Model3DData? = nil

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

// MARK: - Window ID Extension
extension NewWindowID {
    typealias ID = Int
}

// MARK: - Spatial Window Management

struct ImmersiveWindowState: Codable, Hashable {
    var isVisible: Bool = true
    var transform: Transform3D = Transform3D()
    var scale: Float = 1.0
    var opacity: Float = 1.0
    var lastInteractionTime: Date = Date()
    var isLocked: Bool = false
    
    struct Transform3D: Codable, Hashable {
        var translation: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
        var rotation: QuaternionData = QuaternionData()
        var scale: SIMD3<Float> = SIMD3<Float>(1, 1, 1)
        
        init() {}
        
        init(translation: SIMD3<Float>, rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), scale: SIMD3<Float> = SIMD3<Float>(1, 1, 1)) {
            self.translation = translation
            self.rotation = QuaternionData(from: rotation)
            self.scale = scale
        }
        
        var simdRotation: simd_quatf {
            return simd_quatf(ix: rotation.x, iy: rotation.y, iz: rotation.z, r: rotation.w)
        }
        
        mutating func setRotation(_ quat: simd_quatf) {
            rotation = QuaternionData(from: quat)
        }
    }
    
    struct QuaternionData: Codable, Hashable {
        var x: Float = 0
        var y: Float = 0
        var z: Float = 0
        var w: Float = 1
        
        init() {}
        
        init(from quaternion: simd_quatf) {
            self.x = quaternion.vector.x
            self.y = quaternion.vector.y
            self.z = quaternion.vector.z
            self.w = quaternion.vector.w
        }
    }
}

class SpatialWindowManager: ObservableObject {
    static let shared = SpatialWindowManager()
    
    @Published private var immersiveWindowStates: [Int: ImmersiveWindowState] = [:]
    @Published var isImmersiveSpaceActive: Bool = false
    @Published var immersiveSpaceLayout: SpatialLayout = .grid
    
    private let persistenceKey = "SpatialWindowManager.ImmersiveStates"
    
    enum SpatialLayout: String, CaseIterable {
        case grid = "Grid"
        case circle = "Circle"
        case line = "Line"
        case free = "Free Form"
    }
    
    private init() {
        loadImmersiveStates()
    }
    
    // MARK: - Immersive Space Control
    
    func enterImmersiveSpace() {
        isImmersiveSpaceActive = true
        print(" Entering immersive space")
    }
    
    func exitImmersiveSpace() {
        isImmersiveSpaceActive = false
        print(" Exiting immersive space")
    }
    
    func toggleImmersiveSpace() {
        if isImmersiveSpaceActive {
            exitImmersiveSpace()
        } else {
            enterImmersiveSpace()
        }
    }
    
    // MARK: - Window State Management
    
    func getImmersiveState(for windowID: Int) -> ImmersiveWindowState {
        return immersiveWindowStates[windowID] ?? ImmersiveWindowState()
    }
    
    func updateImmersiveState(for windowID: Int, state: ImmersiveWindowState) {
        immersiveWindowStates[windowID] = state
        saveImmersiveStates()
        objectWillChange.send()
    }
    
    func setWindowVisibility(windowID: Int, isVisible: Bool) {
        var state = getImmersiveState(for: windowID)
        state.isVisible = isVisible
        state.lastInteractionTime = Date()
        updateImmersiveState(for: windowID, state: state)
    }
    
    func setWindowTransform(windowID: Int, transform: ImmersiveWindowState.Transform3D) {
        var state = getImmersiveState(for: windowID)
        state.transform = transform
        state.lastInteractionTime = Date()
        updateImmersiveState(for: windowID, state: state)
    }
    
    func setWindowScale(windowID: Int, scale: Float) {
        var state = getImmersiveState(for: windowID)
        state.scale = scale
        state.lastInteractionTime = Date()
        updateImmersiveState(for: windowID, state: state)
    }
    
    func setWindowOpacity(windowID: Int, opacity: Float) {
        var state = getImmersiveState(for: windowID)
        state.opacity = opacity
        state.lastInteractionTime = Date()
        updateImmersiveState(for: windowID, state: state)
    }
    
    func toggleWindowLock(windowID: Int) {
        var state = getImmersiveState(for: windowID)
        state.isLocked.toggle()
        updateImmersiveState(for: windowID, state: state)
    }
    
    func arrangeWindowsInLayout(_ layout: SpatialLayout, windowIDs: [Int]) {
        immersiveSpaceLayout = layout
        // Layout arrangement logic would go here
    }
    
    func hideAllWindows() {
        for windowID in immersiveWindowStates.keys {
            setWindowVisibility(windowID: windowID, isVisible: false)
        }
    }
    
    func showAllWindows() {
        for windowID in immersiveWindowStates.keys {
            setWindowVisibility(windowID: windowID, isVisible: true)
        }
    }
    
    func resetAllWindowPositions() {
        let windowIDs = Array(immersiveWindowStates.keys)
        arrangeWindowsInLayout(immersiveSpaceLayout, windowIDs: windowIDs)
    }
    
    // MARK: - Persistence
    
    private func saveImmersiveStates() {
        do {
            let data = try JSONEncoder().encode(immersiveWindowStates)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            print("Failed to save immersive states: \(error)")
        }
    }
    
    private func loadImmersiveStates() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        
        do {
            immersiveWindowStates = try JSONDecoder().decode([Int: ImmersiveWindowState].self, from: data)
        } catch {
            print("Failed to load immersive states: \(error)")
        }
    }
    
    func cleanupStatesForWindows(_ activeWindowIDs: [Int]) {
        let activeSet = Set(activeWindowIDs)
        immersiveWindowStates = immersiveWindowStates.filter { activeSet.contains($0.key) }
        saveImmersiveStates()
    }
}