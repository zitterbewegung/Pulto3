//
//  PointCloudData.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/19/25.
//  Copyright © 2025 Apple. All rights reserved.
//


import Foundation
import RealityKit

// Unified PointCloudData structure
// Combines the simple points array with additional metadata
// Makes it Codable and Hashable for persistence
// Includes Equatable conformance
struct PointCloudData: Codable, Hashable, Equatable {
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

        // Convenience initializer for SIMD3 points
        init(point: SIMD3<Float>, intensity: Double? = nil, color: String? = nil) {
            self.x = Double(point.x)
            self.y = Double(point.y)
            self.z = Double(point.z)
            self.intensity = intensity
            self.color = color
        }
    }

    init(title: String = "Point Cloud Data",
         xAxisLabel: String = "X",
         yAxisLabel: String = "Y",
         zAxisLabel: String = "Z",
         demoType: String = "custom",
         parameters: [String: Double] = [:],
         points: [SIMD3<Float>] = []) {
        self.title = title
        self.xAxisLabel = xAxisLabel
        self.yAxisLabel = yAxisLabel
        self.zAxisLabel = zAxisLabel
        self.demoType = demoType
        self.parameters = parameters
        self.totalPoints = points.count
        self.points = points.map { PointData(point: $0) }
    }

    // Alternative initializer for detailed points
    init(title: String = "Point Cloud Data",
         xAxisLabel: String = "X",
         yAxisLabel: String = "Y",
         zAxisLabel: String = "Z",
         demoType: String = "custom",
         parameters: [String: Double] = [:],
         points: [PointData]) {
        self.title = title
        self.xAxisLabel = xAxisLabel
        self.yAxisLabel = yAxisLabel
        self.zAxisLabel = zAxisLabel
        self.demoType = demoType
        self.parameters = parameters
        self.totalPoints = points.count
        self.points = points
    }

    // Equatable conformance
    static func == (lhs: PointCloudData, rhs: PointCloudData) -> Bool {
        lhs.totalPoints == rhs.totalPoints &&
        lhs.demoType == rhs.demoType &&
        lhs.points == rhs.points &&
        lhs.title == rhs.title &&
        lhs.xAxisLabel == rhs.xAxisLabel &&
        lhs.yAxisLabel == rhs.yAxisLabel &&
        lhs.zAxisLabel == rhs.zAxisLabel &&
        lhs.parameters == rhs.parameters
    }

    // Computed property to get simple points array (SIMD3<Float>)
    var simplePoints: [SIMD3<Float>] {
        points.map { SIMD3(Float($0.x), Float($0.y), Float($0.z)) }
    }

    // Convert to Python code for Jupyter (from previous implementation)
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
