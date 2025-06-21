#  Creating a volumetric window in visionOS

This app brings the power of Jupyter notebooks to spatial computing, enabling developers, researchers, and designers to prototype and execute immersive 3D and XR applications with live code, visualization, and interaction. Users can write Python code to control spatial scenes, integrate real-time sensor data, visualize 3D models, and manipulate environments directly within a notebook interface. The app supports spatial data libraries, RealityKit and WebXR integration, and live previews of AR/VR content. With modular kernels and a collaborative interface, it transforms spatial computing workflows into an interactive, scriptable, and reproducible development experience, bridging the gap between code and immersive spatial environments.

##  Spatial Data Visualization System Documentation

## Overview

This spatial data visualization system is a macOS application built with Swift, SwiftUI, and RealityKit that enables immersive 3D visualization of tabular, 2D, 3D, and point cloud data. The system serializes volumetric spaces using Jupyter's nbformat (JSON) for data persistence and interoperability.

## Architecture

### Core Technologies
- **Swift & SwiftUI**: Main application framework
- **RealityKit**: 3D rendering and spatial computing
- **Jupyter nbformat**: Data serialization format
- **FastAPI Backend**: Python server for notebook management
- **JSON**: Data exchange format

### Key Design Principles
1. **Window-Based Architecture**: Each visualization is a separate window with its own spatial metadata
2. **Spatial Persistence**: All window positions and orientations are preserved in Jupyter notebooks
3. **Multi-Data Type Support**: Handles various data formats (tabular, 2D charts, 3D visualizations, point clouds)
4. **Interoperability**: Exports to standard Jupyter notebooks for use in other environments

## Core Components

### 1. Spatial Metadata System

```swift
struct SpatialMetadata: Codable {
    var x: Double         // X position in 3D space
    var y: Double         // Y position in 3D space  
    var z: Double         // Z position in 3D space
    var pitch: Double     // Rotation around X axis
    var yaw: Double       // Rotation around Y axis
    var roll: Double      // Rotation around Z axis
}
```

The spatial metadata system manages the 3D positioning and orientation of all windows in the volumetric space.

### 2. Window Type Manager

The `WindowTypeManager` is the central orchestrator that:
- Creates and manages all visualization windows
- Handles export/import to Jupyter notebook format
- Maintains window state and positioning
- Supports multiple window types:
  - **Charts**: 2D/3D data visualizations
  - **Spatial**: 3D point cloud and volumetric data
  - **DataFrame Viewer**: Tabular data display
  - **Model Metric Viewer**: Performance monitoring

### 3. Data Structures

#### Point Cloud Data
```swift
struct PointCloudData: Codable {
    var points: [PointData]
    var title: String
    var xAxisLabel: String
    var yAxisLabel: String
    var zAxisLabel: String
    var totalPoints: Int
    var demoType: String
    var parameters: [String: Double]
}
```

#### Chart Data Point
```swift
struct ChartDataPoint: Codable {
    let x: Double
    let y: Double
    let z: Double?           // Optional for 3D charts
    let category: String?
    let color: String?       // For point cloud visualization
    let intensity: Double?   // For heat mapping
}
```

## Notebook Integration Strategy

### Export Process
1. **Window Serialization**: Each window's content, metadata, and spatial position is serialized
2. **Cell Generation**: Windows are converted to Jupyter notebook cells with appropriate metadata
3. **Metadata Preservation**: All spatial information is stored in cell metadata
4. **Python Code Generation**: Visualization code is generated for Jupyter compatibility

### Import Process
1. **Notebook Parsing**: Jupyter notebooks are parsed to extract window information
2. **Window Recreation**: Windows are recreated with original positions and content
3. **Data Restoration**: Specialized data (point clouds, dataframes) is restored
4. **Spatial Layout**: Original 3D layout is preserved

### Notebook Structure
```json
{
  "cells": [
    {
      "cell_type": "code/markdown",
      "metadata": {
        "window_id": 1001,
        "window_type": "Spatial",
        "export_template": "Custom Code",
        "position": {
          "x": -150.0,
          "y": 100.0,
          "z": -50.0,
          "width": 500.0,
          "height": 300.0
        },
        "state": {
          "minimized": false,
          "maximized": false,
          "opacity": 1.0
        }
      },
      "source": ["# Window content here"],
      "execution_count": null,
      "outputs": []
    }
  ],
  "metadata": {
    "visionos_export": {
      "export_date": "2025-06-17T10:55:00Z",
      "total_windows": 6,
      "window_types": ["Charts", "Spatial", "DataFrame Viewer"],
      "export_templates": ["Matplotlib Chart", "Pandas DataFrame", "Custom Code"]
    }
  }
}
```

## API Integration

### FastAPI Backend Connection
The system communicates with a Python FastAPI server for notebook management:

```swift
class NotebookAPI {
    let baseURL = URL(string: "http://localhost:8000")!
    
    // List available notebooks
    func listNotebooks(completion: @escaping (Result<[String], Error>) -> Void)
    
    // Update spatial metadata for cells
    func updateCellSpatialMetadata(notebookName: String, cellIndex: Int, 
                                  spatial: SpatialMetadata, 
                                  completion: @escaping (Result<String, Error>) -> Void)
}
```

## Visualization Types

### 1. Point Cloud Visualization
- Supports up to millions of points
- Color and intensity mapping
- Interactive 3D rotation and zoom
- Generates Python code for Matplotlib and Plotly

### 2. 3D Charts
- Line, bar, and scatter plots in 3D space
- Spatial positioning for immersive analytics
- Export to standard chart libraries

### 3. Tabular Data
- DataFrame visualization with spatial layout
- Column and row operations
- Export to Pandas DataFrame format

### 4. Volumetric Data
- 3D density visualization
- Isosurface rendering
- Spatial slicing and sectioning

## Data Flow

1. **Data Input** → Swift application receives data
2. **Processing** → Data is processed and prepared for visualization
3. **Rendering** → RealityKit renders 3D visualizations
4. **Interaction** → User manipulates windows in 3D space
5. **Persistence** → Data and layout exported to Jupyter notebook
6. **Sharing** → Notebooks can be shared and reopened

## Export Templates

The system supports multiple export templates for different use cases:

- **Matplotlib Chart**: Standard 2D/3D plotting
- **Pandas DataFrame**: Tabular data analysis
- **Custom Code**: User-defined Python code
- **NumPy Array**: Numerical data export
- **Markdown Only**: Documentation and notes
- **Plotly Interactive**: Interactive 3D visualizations

## Implementation Strategies

### 1. Window State Management

Each window maintains its own state including:
- **Spatial properties**: Position (x, y, z), size (width, height), rotation
- **Visual properties**: Opacity, minimized/maximized state
- **Data properties**: Content, specialized data (DataFrame, PointCloud, etc.)
- **Metadata**: Creation time, last modified, tags, export template

```swift
struct WindowState: Codable {
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
}
```

### 2. Export Template System

The system uses templates to determine how windows are exported to Jupyter:

```swift
enum ExportTemplate: String, Codable {
    case plain = "Plain Text"
    case markdown = "Markdown Only"
    case matplotlib = "Matplotlib Chart"
    case plotly = "Plotly Interactive"
    case pandas = "Pandas DataFrame"
    case numpy = "NumPy Array"
    case custom = "Custom Code"
}
```

Each template generates appropriate Python code for the window content.

### 3. Data Parsing and Reconstruction

When importing notebooks, the system:
1. **Pattern Matching**: Uses regex to identify data structures in Python code
2. **Data Extraction**: Parses values from identified patterns
3. **Object Recreation**: Rebuilds native Swift data structures
4. **Validation**: Ensures data integrity and handles errors gracefully

Example parsing patterns:
```swift
let patterns = [
    #"points_data\s*=\s*\{([^}]+)\}"#,      // Point cloud data
    #"pd\.DataFrame\(([^)]+)\)"#,           // DataFrame creation
    #"metrics\s*=\s*\{([^}]+)\}"#           // Volume metrics
]
```

### 4. Python Code Generation

Each data type can generate its corresponding Python code:

```swift
// Example from PointCloudData
func toPythonCode() -> String {
    var code = """
    import numpy as np
    import matplotlib.pyplot as plt
    from mpl_toolkits.mplot3d import Axes3D
    import plotly.graph_objects as go
    
    # Point cloud data (\(totalPoints) points)
    points_data = {
        'x': [\(points.map { String($0.x) }.joined(separator: ", "))],
        'y': [\(points.map { String($0.y) }.joined(separator: ", "))],
        'z': [\(points.map { String($0.z) }.joined(separator: ", "))]
    }
    """
    // ... additional code generation
    return code
}
```

### 5. Environment Restoration

The system can restore an entire 3D workspace from a notebook:

```swift
struct EnvironmentRestoreResult {
    let importResult: ImportResult
    let openedWindows: [NewWindowID]
    let failedWindows: [NewWindowID]
    
    var isFullySuccessful: Bool {
        return failedWindows.isEmpty && importResult.isSuccessful
    }
}
```

### 6. Error Handling

Comprehensive error handling for robustness:

```swift
enum ImportError: Error {
    case invalidJSON
    case invalidNotebookFormat
    case cellParsingFailed
    case unsupportedWindowType
    case invalidMetadata
    case fileReadError
}
```

## Testing Strategy

### Unit Tests
The system includes comprehensive unit tests for:
- **Notebook parsing**: Validates JSON structure and metadata extraction
- **Round-trip conversion**: Ensures data integrity through export/import cycles
- **Error handling**: Tests edge cases and malformed inputs
- **Data validation**: Verifies bounds and constraints

Example test patterns:
```swift
func testNotebookRoundTrip() throws {
    // Start with sample notebook
    let originalNotebook = try decoder.decode(JupyterNotebook.self, from: originalData)
    
    // Encode back to JSON
    let encodedData = try encoder.encode(originalNotebook)
    
    // Decode again to verify consistency
    let roundTripNotebook = try decoder.decode(JupyterNotebook.self, from: encodedData)
    
    // Verify all properties match
    XCTAssertEqual(originalNotebook.cells.count, roundTripNotebook.cells.count)
}
```

### Integration Tests
- **Window creation and management**
- **Data visualization rendering**
- **Export/import workflows**
- **API communication with FastAPI backend**

## Advanced Features

### 1. Template Windows
Pre-configured window templates for common use cases:
- **Introduction Window**: Markdown documentation
- **Data Visualization**: Matplotlib charts
- **DataFrame Analysis**: Pandas operations
- **3D Point Cloud**: Interactive visualizations
- **Performance Metrics**: Real-time monitoring

### 2. Spatial Layout Preservation
The system preserves:
- **Absolute positions**: Exact 3D coordinates
- **Relative arrangements**: Window relationships
- **View configurations**: Camera angles and zoom
- **Interaction states**: Selected items, filters

### 3. Data Type Detection
Automatic detection of data types from Python code:
- **DataFrames**: Identifies Pandas DataFrame creation patterns
- **NumPy Arrays**: Recognizes array initialization
- **Point Clouds**: Detects 3D coordinate data
- **Chart Data**: Identifies plotting commands

### 4. Incremental Updates
Support for updating specific windows without full re-export:
```swift
func updateCellSpatialMetadata(
    notebookName: String, 
    cellIndex: Int, 
    spatial: SpatialMetadata
)
```

### 5. Performance Optimizations
- **Lazy evaluation**: Data processed only when needed
- **Streaming export**: Large datasets handled efficiently
- **Batch operations**: Multiple windows updated together
- **Cache management**: Frequently accessed data cached

## Security Considerations

### Data Validation
- Input sanitization for imported notebooks
- Bounds checking for spatial coordinates
- Type validation for data structures
- Safe JSON parsing with error handling

### API Security
- CORS configuration for FastAPI backend
- Request validation
- Error message sanitization
- Rate limiting considerations

## Example Code Snippets

### Creating a Point Cloud Window
```swift
// Create point cloud data
var pointCloud = PointCloudData(
    title: "Galaxy Simulation",
    xAxisLabel: "X Position",
    yAxisLabel: "Y Position", 
    zAxisLabel: "Z Position"
)

// Add points
for i in 0..<1000 {
    let theta = Double(i) * 0.1
    let r = sqrt(Double(i)) * 0.5
    pointCloud.points.append(
        PointCloudData.PointData(
            x: r * cos(theta),
            y: r * sin(theta),
            z: Double(i) * 0.01,
            intensity: Double(i) / 1000.0
        )
    )
}

// Update window
windowManager.updateWindowPointCloud(windowId, pointCloud: pointCloud)
```

### Exporting to Jupyter
```swift
// Export current workspace
let notebookJSON = windowManager.exportToJupyterNotebook()

// Save to file
if let fileURL = windowManager.saveNotebookToFile(filename: "my_workspace") {
    print("Saved to: \(fileURL)")
}
```

### Importing from Jupyter
```swift
// Import notebook
let importResult = try windowManager.importFromGenericNotebook(fileURL: notebookURL)

// Check results
print("Restored \(importResult.restoredWindows.count) windows")
if !importResult.errors.isEmpty {
    print("Errors: \(importResult.errors)")
}
```


MIT License

Copyright (c) 2022 Jordi Bruin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

