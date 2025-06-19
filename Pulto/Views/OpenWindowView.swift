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
    //case pointcloud = "Point Cloud Viewer"
    var displayName: String {
        return self.rawValue
    }

    // Jupyter cell type mapping
    var jupyterCellType: String {
        switch self {
        case .charts:
            return "code"
        case .spatial:
            return "spatial"
        case .column:
            return "code"
        //case .pointcloud:
        //    return "code"
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

    // MARK: - Import Methods

    func importFromGenericNotebook(data: Data) throws -> ImportResult {
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw ImportError.invalidJSON
        }

        return try restoreWindowsFromGenericNotebook(json)
    }

    func importFromGenericNotebook(fileURL: URL) throws -> ImportResult {
        let data = try Data(contentsOf: fileURL)
        return try importFromGenericNotebook(data: data)
    }

    func importFromGenericNotebook(jsonString: String) throws -> ImportResult {
        guard let data = jsonString.data(using: .utf8) else {
            throw ImportError.invalidJSON
        }
        return try importFromGenericNotebook(data: data)
    }

    private func restoreWindowsFromGenericNotebook(_ json: [String: Any]) throws -> ImportResult {
        guard let cells = json["cells"] as? [[String: Any]] else {
            throw ImportError.invalidNotebookFormat
        }

        var restoredWindows: [NewWindowID] = []
        var errors: [ImportError] = []
        var idMapping: [Int: Int] = [:]

        let currentMaxID = getAllWindows().map { $0.id }.max() ?? 0
        var nextAvailableID = currentMaxID + 1

        for cellDict in cells {
            do {
                if let windowData = try extractWindowFromGenericCell(cellDict, nextID: nextAvailableID) {
                    if let oldID = extractWindowID(from: cellDict) {
                        idMapping[oldID] = nextAvailableID
                    }

                    restoredWindows.append(windowData)
                    nextAvailableID += 1
                }
            } catch {
                errors.append(error as? ImportError ?? ImportError.cellParsingFailed)
            }
        }

        // Store the restored windows
        for window in restoredWindows {
            windows[window.id] = window
        }

        let visionOSMetadata = extractVisionOSMetadata(from: json)

        return ImportResult(
            restoredWindows: restoredWindows,
            errors: errors,
            originalMetadata: visionOSMetadata,
            idMapping: idMapping
        )
    }

    private func extractWindowFromGenericCell(_ cellDict: [String: Any], nextID: Int) throws -> NewWindowID? {
        guard let metadata = cellDict["metadata"] as? [String: Any],
              let windowTypeString = metadata["window_type"] as? String,
              let windowType = WindowType(rawValue: windowTypeString) else {
            return nil
        }

        // Extract position
        let position = extractPosition(from: metadata)

        // Extract window state
        var state = WindowState()
        if let stateDict = metadata["state"] as? [String: Any] {
            state.isMinimized = stateDict["minimized"] as? Bool ?? false
            state.isMaximized = stateDict["maximized"] as? Bool ?? false
            state.opacity = stateDict["opacity"] as? Double ?? 1.0
        }

        // Extract export template
        if let templateString = metadata["export_template"] as? String,
           let template = ExportTemplate(rawValue: templateString) {
            state.exportTemplate = template
        }

        // Extract tags
        state.tags = metadata["tags"] as? [String] ?? []

        // Extract content from cell source
        if let sourceArray = cellDict["source"] as? [String] {
            state.content = sourceArray.joined(separator: "\n")
        }

        // Parse timestamps
        if let timestamps = metadata["timestamps"] as? [String: String] {
            if let modifiedString = timestamps["modified"],
               let modifiedDate = parseISO8601Date(modifiedString) {
                state.lastModified = modifiedDate
            }
        }

        // Try to extract specialized data
        try extractSpecializedDataFromGeneric(cellDict: cellDict, into: &state, windowType: windowType)

        let window = NewWindowID(
            id: nextID,
            windowType: windowType,
            position: position,
            state: state
        )

        return window
    }

    private func extractPosition(from metadata: [String: Any]) -> WindowPosition {
        guard let positionDict = metadata["position"] as? [String: Any] else {
            return WindowPosition()
        }

        return WindowPosition(
            x: positionDict["x"] as? Double ?? 0,
            y: positionDict["y"] as? Double ?? 0,
            z: positionDict["z"] as? Double ?? 0,
            width: positionDict["width"] as? Double ?? 400,
            height: positionDict["height"] as? Double ?? 300
        )
    }

    private func extractWindowID(from cellDict: [String: Any]) -> Int? {
        guard let metadata = cellDict["metadata"] as? [String: Any] else { return nil }
        return metadata["window_id"] as? Int
    }

    private func extractVisionOSMetadata(from json: [String: Any]) -> VisionOSExportInfo? {
        guard let metadata = json["metadata"] as? [String: Any],
              let visionOSDict = metadata["visionos_export"] as? [String: Any] else {
            return nil
        }

        return VisionOSExportInfo(
            export_date: visionOSDict["export_date"] as? String ?? "",
            total_windows: visionOSDict["total_windows"] as? Int ?? 0,
            window_types: visionOSDict["window_types"] as? [String] ?? [],
            export_templates: visionOSDict["export_templates"] as? [String] ?? [],
            all_tags: visionOSDict["all_tags"] as? [String] ?? []
        )
    }

    private func extractSpecializedDataFromGeneric(cellDict: [String: Any], into state: inout WindowState, windowType: WindowType) throws {
        guard let sourceArray = cellDict["source"] as? [String] else { return }
        let content = sourceArray.joined(separator: "\n")

        switch windowType {
        case .column:
            if let dataFrame = try parseDataFrameFromContent(content) {
                state.dataFrameData = dataFrame
            }

        case .spatial:
            if let pointCloud = try parsePointCloudFromContent(content) {
                state.pointCloudData = pointCloud
            }

        case .charts:
            break
        }
    }

    // MARK: - Analysis Methods

    func analyzeGenericNotebook(fileURL: URL) throws -> NotebookAnalysis {
        let data = try Data(contentsOf: fileURL)
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw ImportError.invalidJSON
        }

        return try analyzeGenericNotebook(json: json)
    }

    func analyzeGenericNotebook(json: [String: Any]) throws -> NotebookAnalysis {
        guard let cells = json["cells"] as? [[String: Any]] else {
            throw ImportError.invalidNotebookFormat
        }

        var windowCells = 0
        var windowTypes: Set<String> = []
        var exportTemplates: Set<String> = []

        for cellDict in cells {
            if let metadata = cellDict["metadata"] as? [String: Any],
               let windowType = metadata["window_type"] as? String {
                windowCells += 1
                windowTypes.insert(windowType)

                if let template = metadata["export_template"] as? String {
                    exportTemplates.insert(template)
                }
            }
        }

        let visionOSMetadata = extractVisionOSMetadata(from: json)

        return NotebookAnalysis(
            totalCells: cells.count,
            windowCells: windowCells,
            windowTypes: Array(windowTypes),
            exportTemplates: Array(exportTemplates),
            metadata: visionOSMetadata
        )
    }

    func validateGenericNotebook(fileURL: URL) throws -> Bool {
        let data = try Data(contentsOf: fileURL)
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return false
        }

        guard json["cells"] != nil, json["metadata"] != nil else {
            return false
        }

        if let metadata = json["metadata"] as? [String: Any] {
            return metadata["visionos_export"] != nil
        }

        return false
    }

    // MARK: - Missing Methods

    func clearAllWindows() {
        windows.removeAll()
        objectWillChange.send()
    }

    // MARK: - Utility Methods

    private func parseDataFrameFromContent(_ content: String) throws -> DataFrameData? {
        let patterns = [
            #"data\s*=\s*\{([^}]+)\}"#,
            #"pd\.DataFrame\(([^)]+)\)"#
        ]

        for pattern in patterns {
            if let match = content.range(of: pattern, options: .regularExpression) {
                return try parseDataFrameFromMatch(String(content[match]))
            }
        }

        return nil
    }

    private func parseDataFrameFromMatch(_ match: String) throws -> DataFrameData? {
        return DataFrameData(
            columns: ["imported_column"],
            rows: [["Data imported from notebook"]],
            dtypes: ["imported_column": "string"]
        )
    }

    private func parsePointCloudFromContent(_ content: String) throws -> PointCloudData? {
        let patterns = [
            #"points_data\s*=\s*\{([^}]+)\}"#,
            #"'x':\s*\[([^\]]+)\]"#,
        ]

        for pattern in patterns {
            if let match = content.range(of: pattern, options: .regularExpression) {
                return try parsePointCloudFromMatch(String(content[match]), fullContent: content)
            }
        }

        return nil
    }

    private func parsePointCloudFromMatch(_ match: String, fullContent: String) throws -> PointCloudData? {
        let titlePattern = #"# (.+)"#
        var title = "Imported Point Cloud"

        if let titleMatch = fullContent.range(of: titlePattern, options: .regularExpression) {
            let titleLine = String(fullContent[titleMatch])
            if let actualTitle = titleLine.components(separatedBy: "# ").last?.trimmingCharacters(in: .whitespaces) {
                title = actualTitle
            }
        }

        var pointCloudData = PointCloudData(
            title: title,
            demoType: "imported"
        )

        pointCloudData.points = [
            PointCloudData.PointData(x: 0, y: 0, z: 0, intensity: 0.5, color: nil)
        ]
        pointCloudData.totalPoints = 1

        return pointCloudData
    }

    private func parseISO8601Date(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }

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
        case .charts:
            return generateNotebookCellContent(for: window)
        case .spatial:
            return generateSpatialCellContent(for: window)
        case .column:
            return generateDataFrameCellContent(for: window)
        //case .pointcloud:
        //    return PointCloudPreview(for: window)
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

/*struct OpenWindowView: View {
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
}*/
struct OpenWindowView: View {
    @State var nextWindowID = 1
    @Environment(\.openWindow) private var openWindow
    @StateObject private var windowManager = WindowTypeManager.shared
    @State private var showExportSidebar = false
    @State private var showImportDialog = false

    // HIG-compliant sizing constants
    private let standardPadding: CGFloat = 20
    private let sectionSpacing: CGFloat = 32
    private let itemSpacing: CGFloat = 16
    private let cornerRadius: CGFloat = 12

    var body: some View {
        HStack(spacing: 0) {
            // Main content with proper sizing
            ScrollView {
                VStack(spacing: sectionSpacing) {
                    // Header section
                    headerSection

                    // Window type selection
                    windowTypeSection

                    // Quick actions section
                    quickActionsSection

                    // Active windows overview
                    if !windowManager.getAllWindows().isEmpty {
                        activeWindowsSection
                    }
                }
                .padding(standardPadding * 2) // Doubled padding
                .frame(minWidth: 800) // Ensure minimum width
            }
            .frame(maxWidth: .infinity)

            // Export configuration sidebar
            if showExportSidebar {
                ExportConfigurationSidebar()
                    .frame(width: 400) // Fixed width for sidebar
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showExportSidebar)
        .frame(minHeight: 800) // Minimum height for the view
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Window Manager")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Create and manage volumetric windows")
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

            // Grid layout for window type buttons
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
                // You can add SF Symbol icons here based on window type
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
            .frame(height: 140) // Fixed height for consistency
            .padding(standardPadding)
        }
        .buttonStyle(.plain)
        .background(.quaternary.opacity(0.5))
        .backgroundStyle(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .hoverEffect()
    }

    // Just update your quickActionsSection to this:
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Actions")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Manage your workspace")
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

            VStack(spacing: itemSpacing) {
                HStack(spacing: itemSpacing) {
                    Button(action: exportToJupyter) {
                        Label("Export to Jupyter", systemImage: "square.and.arrow.up")
                            .font(.body)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: { showImportDialog = true }) {
                        Label("Import Notebook", systemImage: "square.and.arrow.down")
                            .font(.body)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
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
                    // Implement close all functionality
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.red)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(windowManager.getAllWindows()) { window in
                        HStack(spacing: 12) {
                            // Window icon
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

                            // Position badge
                            Text("(\(Int(window.position.x)), \(Int(window.position.y)), \(Int(window.position.z)))")
                                .font(.caption2)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.quaternary)
                                .clipShape(Capsule())
                                .foregroundStyle(.secondary)

                            // Window controls
                            HStack(spacing: 8) {
                                Button(action: {}) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.callout)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .help("Focus Window")

                                Button(action: {}) {
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
            .frame(maxHeight: 400) // Increased from 200
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
            width: 600,  // Increased from 400
            height: 450  // Increased from 300
        )

        _ = windowManager.createWindow(type, id: nextWindowID, position: position)
        openWindow(value: nextWindowID)
        nextWindowID += 1
    }

    private func exportToJupyter() {
        if let fileURL = windowManager.saveNotebookToFile() {
            print("Notebook saved to: \(fileURL.path)")
            // Show success feedback
        }
    }

    private func iconForWindowType(_ type: WindowType) -> String {
        // Map window types to appropriate SF Symbols
        // Update these cases to match your actual WindowType enum cases
        let typeString = String(describing: type).lowercased()

        if typeString.contains("markdown") || typeString.contains("text") {
            return "doc.text"
        } else if typeString.contains("code") {
            return "chevron.left.forwardslash.chevron.right"
        } else if typeString.contains("plot") || typeString.contains("chart") {
            return "chart.line.uptrend.xyaxis"
        } else if typeString.contains("data") || typeString.contains("frame") || typeString.contains("table") {
            return "tablecells"
        } else if typeString.contains("image") || typeString.contains("photo") {
            return "photo"
        } else if typeString.contains("model") || typeString.contains("3d") {
            return "cube"
        } else if typeString.contains("point") || typeString.contains("cloud") {
            return "point.3.connected.trianglepath.dotted"
        } else {
            return "square.stack.3d"
        }
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
                case .charts:
                    WindowChartView()
                
                case .spatial:
                    SpatialEditorView(windowID: id)
                case .column:
                    DataTableContentView(windowID: id)
                //case .pointcloud:
                //    PointCloudPreview(windowID: id)

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
