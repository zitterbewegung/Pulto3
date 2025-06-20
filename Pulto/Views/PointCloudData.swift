//
//  PointCloudData.swift
//  Pulto
//
//  Created by Joshua Herman on 6/20/25.
//  Copyright © 2025 Apple. All rights reserved.
//


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
