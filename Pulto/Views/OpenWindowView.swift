//  Enhanced NewWindowID.swift with Point Cloud Integration
//  UnderstandingVisionos
//
//  Created by Joshua Herman on 5/25/25.
//

import SwiftUI
import Foundation
import Charts

enum WindowType: String, CaseIterable, Codable, Hashable {
    case notebook = "Notebook Chart"
    case spatial = "Spatial Editor"
    case column = "DataFrame Viewer"

    var displayName: String {
        return self.rawValue
    }

    // Jupyter cell type mapping
    var jupyterCellType: String {
        switch self {
        case .notebook:
            return "code"
        case .spatial:
            return "spatial"
        case .column:
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

// New PointCloudData structure for Codable support
struct PointCloudData: Codable, Hashable {
    var points: [PointData]
    var title: String
    var xAxisLabel: String
    var yAxisLabel: String
    var zAxisLabel: String
    var totalPoints: Int
    var demoType: String
    var parameters: [String: Double]

    struct PointData: Codable, Hashable {
        var x: Double
        var y: Double
        var z: Double
        var intensity: Double?
        var color: String?
    }

    init(title: String = "Point Cloud",
         xAxisLabel: String = "X",
         yAxisLabel: String = "Y",
         zAxisLabel: String = "Z",
         demoType: String = "sphere",
         parameters: [String: Double] = [:]) {
        self.points = []
        self.title = title
        self.xAxisLabel = xAxisLabel
        self.yAxisLabel = yAxisLabel
        self.zAxisLabel = zAxisLabel
        self.totalPoints = 0
        self.demoType = demoType
        self.parameters = parameters
    }

    // Convert to Python code for Jupyter
    func toPythonCode() -> String {
        guard !points.isEmpty else {
            return "# Empty point cloud\nprint('No point cloud data available')"
        }

        var code = """
        # \(title)
        # Generated from VisionOS Spatial Editor
        
        import numpy as np
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d import Axes3D
        import plotly.graph_objects as go
        import plotly.express as px
        
        # Point cloud data (\(totalPoints) points)
        points_data = {
            'x': [\(points.map { String($0.x) }.joined(separator: ", "))],
            'y': [\(points.map { String($0.y) }.joined(separator: ", "))],
            'z': [\(points.map { String($0.z) }.joined(separator: ", "))]
        }
        
        """

        // Add intensity data if available
        if points.first?.intensity != nil {
            let intensities = points.map { $0.intensity ?? 0.0 }
            code += "points_data['intensity'] = [\(intensities.map { String($0) }.joined(separator: ", "))]\n\n"
        }

        code += """
        # Convert to numpy arrays
        x_data = np.array(points_data['x'])
        y_data = np.array(points_data['y'])
        z_data = np.array(points_data['z'])
        
        # Matplotlib 3D visualization
        fig = plt.figure(figsize=(12, 8))
        ax = fig.add_subplot(111, projection='3d')
        
        """

        if points.first?.intensity != nil {
            code += """
            intensity_data = np.array(points_data['intensity'])
            scatter = ax.scatter(x_data, y_data, z_data, c=intensity_data, 
                               cmap='viridis', alpha=0.6, s=20)
            plt.colorbar(scatter, ax=ax, label='Intensity')
            """
        } else {
            code += """
            ax.scatter(x_data, y_data, z_data, alpha=0.6, s=20, c='blue')
            """
        }

        code += """
        
        ax.set_xlabel('\(xAxisLabel)')
        ax.set_ylabel('\(yAxisLabel)')
        ax.set_zlabel('\(zAxisLabel)')
        ax.set_title('\(title)')
        
        # Make the plot look better
        ax.grid(True)
        plt.tight_layout()
        plt.show()
        
        # Interactive Plotly visualization
        fig_plotly = go.Figure()
        
        """

        if points.first?.intensity != nil {
            code += """
            fig_plotly.add_trace(go.Scatter3d(
                x=x_data, y=y_data, z=z_data,
                mode='markers',
                marker=dict(
                    size=3,
                    color=intensity_data,
                    colorscale='Viridis',
                    showscale=True,
                    colorbar=dict(title="Intensity")
                ),
                name='\(title)'
            ))
            """
        } else {
            code += """
            fig_plotly.add_trace(go.Scatter3d(
                x=x_data, y=y_data, z=z_data,
                mode='markers',
                marker=dict(size=3, color='blue'),
                name='\(title)'
            ))
            """
        }

        code += """
        
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
        print(f"- Total points: {len(x_data)}")
        print(f"- X range: [{np.min(x_data):.2f}, {np.max(x_data):.2f}]")
        print(f"- Y range: [{np.min(y_data):.2f}, {np.max(y_data):.2f}]")
        print(f"- Z range: [{np.min(z_data):.2f}, {np.max(z_data):.2f}]")
        """

        if points.first?.intensity != nil {
            code += """
            if 'intensity' in points_data:
                print(f"- Intensity range: [{np.min(intensity_data):.2f}, {np.max(intensity_data):.2f}]")
            """
        }

        return code
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
    var pointCloudData: PointCloudData? = nil // New field for point cloud data

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

// Enhanced window manager with export capabilities
class WindowTypeManager: ObservableObject {
    static let shared = WindowTypeManager()

    @Published private var windows: [Int: NewWindowID] = [:]

    private init() {}

    func createWindow(_ type: WindowType, id: Int, position: WindowPosition = WindowPosition()) -> NewWindowID {
        let window = NewWindowID(id: id, windowType: type, position: position)
        windows[id] = window
        return window
    }

    func getWindow(for id: Int) -> NewWindowID? {
        return windows[id]
    }

    func getType(for id: Int) -> WindowType {
        return windows[id]?.windowType ?? .spatial
    }

    func updateWindowPosition(_ id: Int, position: WindowPosition) {
        windows[id]?.position = position
    }

    func updateWindowState(_ id: Int, state: WindowState) {
        windows[id]?.state = state
    }

    func updateWindowContent(_ id: Int, content: String) {
        windows[id]?.state.content = content
        windows[id]?.state.lastModified = Date()
    }

    func updateWindowTemplate(_ id: Int, template: ExportTemplate) {
        windows[id]?.state.exportTemplate = template
        windows[id]?.state.lastModified = Date()
    }

    func updateWindowImports(_ id: Int, imports: [String]) {
        windows[id]?.state.customImports = imports
        windows[id]?.state.lastModified = Date()
    }

    func addWindowTag(_ id: Int, tag: String) {
        if windows[id]?.state.tags.contains(tag) == false {
            windows[id]?.state.tags.append(tag)
            windows[id]?.state.lastModified = Date()
        }
    }

    func updateWindowDataFrame(_ id: Int, dataFrame: DataFrameData) {
        windows[id]?.state.dataFrameData = dataFrame
        windows[id]?.state.lastModified = Date()

        // Auto-set template to pandas if not already set and this is a DataFrame window
        if let window = windows[id], window.windowType == .column && window.state.exportTemplate == .plain {
            windows[id]?.state.exportTemplate = .pandas
        }
    }

    func getWindowDataFrame(for id: Int) -> DataFrameData? {
        return windows[id]?.state.dataFrameData
    }

    // New point cloud methods
    func updateWindowPointCloud(_ id: Int, pointCloud: PointCloudData) {
        windows[id]?.state.pointCloudData = pointCloud
        windows[id]?.state.lastModified = Date()

        // Auto-set template to custom if not already set
        if let window = windows[id], window.windowType == .spatial && window.state.exportTemplate == .plain {
            windows[id]?.state.exportTemplate = .custom
        }
    }

    func getWindowPointCloud(for id: Int) -> PointCloudData? {
        return windows[id]?.state.pointCloudData
    }

    func getAllWindows() -> [NewWindowID] {
        return Array(windows.values).sorted { $0.id < $1.id }
    }

    func removeWindow(_ id: Int) {
        windows.removeValue(forKey: id)
    }

    // MARK: - Jupyter Export Functions

    func exportToJupyterNotebook() -> String {
        let notebook = createJupyterNotebook()
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: notebook, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            print("Error creating JSON: \(error)")
            return "{}"
        }
    }

    private func createJupyterNotebook() -> [String: Any] {
        let cells = getAllWindows().map { window in
            createJupyterCell(from: window)
        }

        let metadata: [String: Any] = [
            "kernelspec": [
                "display_name": "Python 3",
                "language": "python",
                "name": "python3"
            ],
            "language_info": [
                "name": "python",
                "version": "3.8.0"
            ],
            "visionos_export": [
                "export_date": ISO8601DateFormatter().string(from: Date()),
                "total_windows": windows.count,
                "window_types": Array(Set(windows.values.map { $0.windowType.rawValue })),
                "export_templates": Array(Set(windows.values.map { $0.state.exportTemplate.rawValue })),
                "all_tags": Array(Set(windows.values.flatMap { $0.state.tags }))
            ]
        ]

        return [
            "cells": cells,
            "metadata": metadata,
            "nbformat": 4,
            "nbformat_minor": 4
        ]
    }

    private func createJupyterCell(from window: NewWindowID) -> [String: Any] {
        let cellType = window.state.exportTemplate == .markdown ? "markdown" : "code"

        var cell: [String: Any] = [
            "cell_type": cellType,
            "metadata": [
                "window_id": window.id,
                "window_type": window.windowType.rawValue,
                "export_template": window.state.exportTemplate.rawValue,
                "tags": window.state.tags,
                "position": [
                    "x": window.position.x,
                    "y": window.position.y,
                    "z": window.position.z,
                    "width": window.position.width,
                    "height": window.position.height
                ],
                "state": [
                    "minimized": window.state.isMinimized,
                    "maximized": window.state.isMaximized,
                    "opacity": window.state.opacity
                ],
                "timestamps": [
                    "created": ISO8601DateFormatter().string(from: window.createdAt),
                    "modified": ISO8601DateFormatter().string(from: window.state.lastModified)
                ]
            ]
        ]

        // Add content based on template configuration
        let source = generateCellContent(for: window)
        cell["source"] = source.components(separatedBy: .newlines)

        // Add execution count for code cells
        if cellType == "code" {
            cell["execution_count"] = NSNull()
            cell["outputs"] = []
        }

        return cell
    }

    private func generateCellContent(for window: NewWindowID) -> String {
        switch window.windowType {
        case .notebook:
            return generateNotebookCellContent(for: window)
        case .spatial:
            return generateSpatialCellContent(for: window)
        case .column:
            return generateDataFrameCellContent(for: window)
        }
    }

    private func generateNotebookCellContent(for window: NewWindowID) -> String {
        let baseContent = """
        # Notebook Chart Window #\(window.id)
        # Created: \(DateFormatter.localizedString(from: window.createdAt, dateStyle: .short, timeStyle: .short))
        # Position: (\(window.position.x), \(window.position.y), \(window.position.z))
        
        import matplotlib.pyplot as plt
        import numpy as np
        
        # Chart configuration from VisionOS window
        fig, ax = plt.subplots(figsize=(\(window.position.width/50), \(window.position.height/50)))
        
        """

        return window.state.content.isEmpty ? baseContent : baseContent + "\n" + window.state.content
    }

    private func generateSpatialCellContent(for window: NewWindowID) -> String {
        if let pointCloudData = window.state.pointCloudData {
            return pointCloudData.toPythonCode()
        }

        let content = """
        # Spatial Editor Window #\(window.id)
        
        **Position:** (\(window.position.x), \(window.position.y), \(window.position.z))  
        **Size:** \(window.position.width) × \(window.position.height)  
        **Created:** \(DateFormatter.localizedString(from: window.createdAt, dateStyle: .short, timeStyle: .short))  
        **Last Modified:** \(DateFormatter.localizedString(from: window.state.lastModified, dateStyle: .short, timeStyle: .short))
        
        ## Spatial Content
        
        """

        return window.state.content.isEmpty ? content + "*No content available*" : content + window.state.content
    }

    private func generateDataFrameCellContent(for window: NewWindowID) -> String {
        let baseContent = """
        # DataFrame Viewer Window #\(window.id)
        # Created: \(DateFormatter.localizedString(from: window.createdAt, dateStyle: .short, timeStyle: .short))
        # Position: (\(window.position.x), \(window.position.y), \(window.position.z))
        
        import pandas as pd
        import numpy as np
        
        # DataFrame configuration from VisionOS window
        # Window size: \(window.position.width) × \(window.position.height)
        
        """

        return window.state.content.isEmpty ? baseContent : baseContent + "\n" + window.state.content
    }

    // MARK: - File Export

    func saveNotebookToFile(filename: String = "visionos_workspace") -> URL? {
        let notebook = exportToJupyterNotebook()

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory,
                                                                in: .userDomainMask).first else {
            return nil
        }

        let fileURL = documentsDirectory.appendingPathComponent("\(filename).ipynb")

        do {
            try notebook.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error saving notebook: \(error)")
            return nil
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

struct OpenWindowView: View {
    @State var nextWindowID = 1
    @Environment(\.openWindow) private var openWindow
    @StateObject private var windowManager = WindowTypeManager.shared
    @State private var showExportSidebar = false

    var body: some View {
        HStack(spacing: 0) {
            // Main content
            VStack(spacing: 20) {
                Text("Choose Window Type")
                    .font(.title2)
                    .padding()

                // Create buttons for each window type
                ForEach(WindowType.allCases, id: \.self) { windowType in
                    Button("Open \(windowType.displayName) Window") {
                        // Create and store the complete window configuration
                        let position = WindowPosition(
                            x: Double.random(in: -200...200),
                            y: Double.random(in: -100...100),
                            z: Double.random(in: -50...50),
                            width: 400,
                            height: 300
                        )

                        _ = windowManager.createWindow(windowType, id: nextWindowID, position: position)
                        openWindow(value: nextWindowID)
                        nextWindowID += 1
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }

                Divider()

                // Quick actions
                VStack(spacing: 10) {
                    HStack {
                        Text("Quick Actions")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            showExportSidebar.toggle()
                        }) {
                            Image(systemName: showExportSidebar ? "sidebar.right" : "sidebar.left")
                            Text(showExportSidebar ? "Hide Config" : "Show Config")
                        }
                    }

                    Button("Export All to Jupyter") {
                        if let fileURL = windowManager.saveNotebookToFile() {
                            print("Notebook saved to: \(fileURL.path)")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }

                // Window overview
                if !windowManager.getAllWindows().isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Active Windows (\(windowManager.getAllWindows().count))")
                            .font(.headline)

                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(windowManager.getAllWindows()) { window in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("\(window.windowType.displayName) #\(window.id)")
                                                .font(.subheadline)
                                            Text("\(window.state.exportTemplate.rawValue)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text("(\(Int(window.position.x)), \(Int(window.position.y)), \(Int(window.position.z)))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(4)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)

            // Export configuration sidebar
            if showExportSidebar {
                ExportConfigurationSidebar()
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showExportSidebar)
    }
}

struct NewWindow: View {
    let id: Int
    @StateObject private var windowTypeManager = WindowTypeManager.shared

    var body: some View {
        if let window = windowTypeManager.getWindow(for: id) {
            VStack {
                HStack {
                    Text("\(window.windowType.displayName) - Window #\(id)")
                        .font(.title2)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Pos: (\(Int(window.position.x)), \(Int(window.position.y)), \(Int(window.position.z)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Template: \(window.state.exportTemplate.rawValue)")
                            .font(.caption)
                            .foregroundColor(.blue)
                        if !window.state.tags.isEmpty {
                            Text("Tags: \(window.state.tags.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding()

                // Display the appropriate view based on window type
                switch window.windowType {
                case .notebook:
                    NotebookChartsView()
                case .spatial:
                    SpatialEditorView(windowID: id)
                case .column:
                    DataTableContentView(windowID: id)
                }

                Spacer()
            }
        } else {
            Text("Window #\(id) not found")
                .font(.title2)
                .padding()
        }
    }
}

// Enhanced DataFrame viewer with data editing capabilities
struct DataTableContentView: View {
    let windowID: Int?
    @StateObject private var windowManager = WindowTypeManager.shared
    @State private var sampleData = DataFrameData(
        columns: ["Name", "Age", "City", "Salary"],
        rows: [
            ["Alice", "28", "New York", "75000"],
            ["Bob", "35", "San Francisco", "95000"],
            ["Charlie", "42", "Austin", "68000"],
            ["Diana", "31", "Seattle", "82000"]
        ],
        dtypes: ["Name": "string", "Age": "int", "City": "string", "Salary": "float"]
    )
    @State private var editingData = false

    init(windowID: Int? = nil) {
        self.windowID = windowID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerView

            if editingData {
                dataEditorView
            } else {
                dataDisplayView
            }

            controlsView
        }
        .padding()
        .onAppear {
            loadDataFromWindow()
        }
    }

    private var headerView: some View {
        HStack {
            Text("DataFrame Viewer")
                .font(.headline)
            Spacer()
            Text("Shape: \(sampleData.shapeRows) × \(sampleData.shapeColumns)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var dataDisplayView: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 1) {
                    ForEach(sampleData.columns, id: \.self) { column in
                        Text(column)
                            .font(.caption)
                            .bold()
                            .padding(6)
                            .frame(minWidth: 80)
                            .background(Color.blue.opacity(0.1))
                            .border(Color.gray.opacity(0.3), width: 0.5)
                    }
                }

                // Data rows
                ForEach(0..<min(sampleData.rows.count, 10), id: \.self) { rowIndex in
                    HStack(spacing: 1) {
                        ForEach(0..<sampleData.columns.count, id: \.self) { colIndex in
                            let value = rowIndex < sampleData.rows.count && colIndex < sampleData.rows[rowIndex].count
                                ? sampleData.rows[rowIndex][colIndex]
                                : ""
                            Text(value)
                                .font(.caption)
                                .padding(6)
                                .frame(minWidth: 80)
                                .background(Color.white)
                                .border(Color.gray.opacity(0.3), width: 0.5)
                        }
                    }
                }

                if sampleData.rows.count > 10 {
                    Text("... and \(sampleData.rows.count - 10) more rows")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .frame(maxHeight: 200)
        .border(Color.gray.opacity(0.3))
    }

    private var dataEditorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Edit DataFrame Data")
                .font(.subheadline)
                .bold()

            Text("Paste CSV data or edit manually:")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: .constant(sampleData.toCSVString()))
                .frame(height: 150)
                .border(Color.gray.opacity(0.3))
                .font(.system(.caption, design: .monospaced))
        }
    }

    private var controlsView: some View {
        HStack {
            Button(editingData ? "Save Data" : "Edit Data") {
                if editingData {
                    saveDataToWindow()
                }
                editingData.toggle()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(6)

            Button("Load Sample Data") {
                loadSampleData()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.1))
            .cornerRadius(6)

            Spacer()

            Button("Export DataFrame") {
                saveDataToWindow()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(6)
        }
    }

    private func loadDataFromWindow() {
        guard let windowID = windowID,
              let existingData = windowManager.getWindowDataFrame(for: windowID) else {
            return
        }
        sampleData = existingData
    }

    private func saveDataToWindow() {
        guard let windowID = windowID else { return }
        windowManager.updateWindowDataFrame(windowID, dataFrame: sampleData)
    }

    private func loadSampleData() {
        sampleData = DataFrameData(
            columns: ["Product", "Category", "Price", "Quantity", "Revenue"],
            rows: [
                ["iPhone 15", "Electronics", "999.00", "150", "149850.00"],
                ["MacBook Pro", "Electronics", "2399.00", "75", "179925.00"],
                ["AirPods Pro", "Electronics", "249.00", "300", "74700.00"],
                ["iPad Air", "Electronics", "599.00", "120", "71880.00"],
                ["Apple Watch", "Electronics", "399.00", "200", "79800.00"]
            ],
            dtypes: ["Product": "string", "Category": "string", "Price": "float", "Quantity": "int", "Revenue": "float"]
        )

        if let windowID = windowID {
            saveDataToWindow()
        }
    }
}

// MARK: - SwiftUI Preview for Point Cloud
struct PointCloudPreview: View {
    @State private var selectedDemo = 0
    @State private var rotationAngle = 0.0

    let demoNames = ["Sphere", "Torus", "Wave Surface", "Spiral Galaxy", "Noisy Cube"]

    var currentPointCloud: [(x: Double, y: Double, z: Double, intensity: Double?)] {
        switch selectedDemo {
        case 0:
            return PointCloudDemo.generateSpherePointCloud(radius: 10, points: 500)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: nil) }
        case 1:
            return PointCloudDemo.generateTorusPointCloud(majorRadius: 10, minorRadius: 3, points: 800)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: $0.intensity) }
        case 2:
            return PointCloudDemo.generateWaveSurface(size: 20, resolution: 30)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: $0.intensity) }
        case 3:
            return PointCloudDemo.generateSpiralGalaxy(arms: 3, points: 1000)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: $0.intensity) }
        case 4:
            return PointCloudDemo.generateNoisyCube(size: 10, pointsPerFace: 200)
                .map { (x: $0.x, y: $0.y, z: $0.z, intensity: nil) }
        default:
            return []
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Demo selector
            Picker("Select Data", selection: $selectedDemo) {
                ForEach(0..<demoNames.count, id: \.self) { index in
                    Text(demoNames[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            // 3D visualization using 2D projection
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 400)

                // Point cloud visualization
                GeometryReader { geometry in
                    Canvas { context, size in
                        let centerX = size.width / 2
                        let centerY = size.height / 2
                        let scale = min(size.width, size.height) / 40

                        // Apply rotation
                        let angle = rotationAngle * .pi / 180

                        for point in currentPointCloud {
                            // Simple 3D rotation around Y axis
                            let rotatedX = point.x * cos(angle) - point.z * sin(angle)
                            let rotatedZ = point.x * sin(angle) + point.z * cos(angle)

                            // Project to 2D (simple orthographic projection)
                            let projectedX = centerX + rotatedX * scale
                            let projectedY = centerY - point.y * scale

                            // Size based on Z depth
                            let pointSize = 2.0 + (rotatedZ + 20) / 20

                            // Color based on intensity or Z depth
                            let intensity = point.intensity ?? ((point.z + 10) / 20)
                            let color = Color(
                                hue: 0.6 - intensity * 0.4,
                                saturation: 0.8,
                                brightness: 0.9
                            )

                            context.fill(
                                Path(ellipseIn: CGRect(
                                    x: projectedX - pointSize/2,
                                    y: projectedY - pointSize/2,
                                    width: pointSize,
                                    height: pointSize
                                )),
                                with: .color(color.opacity(0.8))
                            )
                        }
                    }
                }
                .frame(height: 400)
                .onAppear {
                    // Auto-rotate animation
                    withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
            }
            .padding()

            // Stats
            VStack(alignment: .leading, spacing: 8) {
                Text("Statistics")
                    .font(.headline)

                HStack {
                    Label("\(currentPointCloud.count) points", systemImage: "circle.grid.3x3.fill")
                    Spacer()
                    Label(String(format: "%.1f°", rotationAngle.truncatingRemainder(dividingBy: 360)), systemImage: "rotate.3d")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)

            // Export button
            Button(action: {
                PointCloudDemo.runAllDemos()
                print("✅ Exported all demos to Python files!")
            }) {
                Label("Export to Jupyter", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical)
    }
}

// MARK: - Preview Provider
#Preview("Main Interface") {
    OpenWindowView()
}

//#Preview("Point Cloud Preview") {
//  PointCloudPreview()
//}

#Preview("Spatial Editor") {
    SpatialEditorView()
}
