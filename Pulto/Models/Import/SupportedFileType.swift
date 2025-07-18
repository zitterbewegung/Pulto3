//
//  SupportedFileType.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/18/25.
//  Copyright © 2025 Apple. All rights reserved.
//


//
//  FileAnalysisTypes.swift
//  Pulto3
//
//  Data structures and types for file analysis system
//

import Foundation
import SwiftUI

// MARK: - File Types

enum SupportedFileType: String, CaseIterable {
    case csv = "csv"
    case tsv = "tsv"
    case json = "json"
    case xlsx = "xlsx"
    case las = "las"
    case ipynb = "ipynb"
    case usdz = "usdz"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .csv: return "CSV"
        case .tsv: return "TSV"
        case .json: return "JSON"
        case .xlsx: return "Excel"
        case .las: return "LiDAR"
        case .ipynb: return "Jupyter Notebook"
        case .usdz: return "USDZ 3D Model"
        case .unknown: return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .csv, .tsv: return "tablecells"
        case .json: return "curlybraces"
        case .xlsx: return "tablecells.badge.ellipsis"
        case .las: return "circle.grid.3x3.fill"
        case .ipynb: return "doc.text.magnifyingglass"
        case .usdz: return "cube"
        case .unknown: return "doc"
        }
    }
}

// MARK: - Data Types

enum DataType {
    case tabular
    case tabularWithCoordinates
    case pointCloud
    case timeSeries
    case networkData
    case geospatial
    case spreadsheet
    case model3D
    case notebook
    case matrix
    case hierarchical
    case structured
    case unknown
}

// MARK: - Column Types

enum ImportColumnType {
    case numeric
    case categorical
    case date
    case boolean
    case unknown
}

// MARK: - Data Patterns

enum DataPattern: Hashable {
    case timeSeries
    case hierarchical
    case network
    case spatial
    case highCardinality
    case sparseData
    case correlatedColumns
}

// MARK: - Analysis Results

struct FileAnalysisResult {
    let fileURL: URL
    let fileType: SupportedFileType
    let analysis: DataAnalysisResult
    let suggestions: [VisualizationRecommendation]
}

struct DataAnalysisResult {
    let dataType: DataType
    let structure: AnalysisStructure
    let metadata: [String: Any]
    let suggestions: [String]
}

// MARK: - Analysis Structures

protocol AnalysisStructure {}

struct TabularStructure: AnalysisStructure {
    let headers: [String]
    let columnTypes: [String: ColumnType]
    let rowCount: Int
    let patterns: Set<DataPattern>
    let coordinateColumns: [String]
    let timeColumns: [String]
}

struct PointCloudStructure: AnalysisStructure {
    let pointCount: Int
    let bounds: PointCloudBounds
    let hasIntensity: Bool
    let hasColor: Bool
    let hasClassification: Bool
    let hasGPSTime: Bool
    let averageDensity: Double
    let pointFormat: Int
}

struct PointCloudBounds {
    var minX: Double = .infinity
    var maxX: Double = -.infinity
    var minY: Double = .infinity
    var maxY: Double = -.infinity
    var minZ: Double = .infinity
    var maxZ: Double = -.infinity
    
    mutating func updateWith(x: Double, y: Double, z: Double) {
        minX = min(minX, x)
        maxX = max(maxX, x)
        minY = min(minY, y)
        maxY = max(maxY, y)
        minZ = min(minZ, z)
        maxZ = max(maxZ, z)
    }
}

struct JSONStructure: AnalysisStructure {
    var maxDepth: Int = 0
    var objectCount: Int = 0
    var arrayCount: Int = 0
    var hasCoordinates: Bool = false
    var hasTimestamps: Bool = false
    var hasNodes: Bool = false
    var hasEdges: Bool = false
    var isArrayOfObjects: Bool = false
    var isNumericData: Bool = false
    var hasNestedArrays: Bool = false
}

struct SpreadsheetStructure: AnalysisStructure {
    let sheets: [SheetAnalysis]
}

struct SheetAnalysis {
    let name: String
    let rowCount: Int
    let columnCount: Int
    let hasHeaders: Bool
    let dataTypes: [ColumnType]
}

struct Model3DStructure: AnalysisStructure {
    let format: String
    let hasTextures: Bool
    let hasMaterials: Bool
    let hasAnimations: Bool
    let vertexCount: Int
    let faceCount: Int
}

struct NotebookStructure: AnalysisStructure {
    let cellCount: Int
    let extractedData: [ExtractedNotebookData]
    let visualizationCode: [VisualizationCodeBlock]
}

struct ExtractedNotebookData {
    let variableName: String
    let dataType: NotebookDataType
    let shape: (Int, Int)?
    
    enum NotebookDataType {
        case dataFrame
        case array
        case pointCloud
    }
}

struct VisualizationCodeBlock {
    let type: ImportVisualizationType
    let library: String
    let dataVariables: [String]
}

enum ImportVisualizationType {
    case scatter2D
    case scatter3D
    case line
    case bar
    case histogram
    case heatmap
    case surface3D
    case contour
    case box
    case violin
    case network
    case tree
}

// MARK: - Visualization Recommendations

struct VisualizationRecommendation {
    let type: SpatialVisualizationType
    let priority: Priority
    let confidence: Double
    var reason: String
    let configuration: VisualizationConfiguration
    
    enum Priority: Int {
        case high = 3
        case medium = 2
        case low = 1
    }
}

enum SpatialVisualizationType {
    // Basic
    case dataTable
    case jsonTreeViewer
    
    // 2D Charts
    case scatterPlot2D
    case lineChart
    case multiLineChart
    case barChart
    case areaChart
    case histogram
    case boxPlot
    case violinPlot
    case candlestick
    
    // 3D Visualizations
    case scatterPlot3D
    case surface3D
    case contourPlot
    case pointCloud3D
    case volumetric
    case crossSection
    
    // Specialized
    case heatmap
    case densityHeatMap
    case spatialNetwork
    case forceDirectedGraph
    case hierarchicalLayout
    case sunburst
    case treemap
    case geospatialMap
    case timeSeriesPath
    
    // Model & Notebook
    case model3DViewer
    case materialEditor
    case animationTimeline
    case notebookSpatialLayout
    case cellFlowVisualization
    case multiSheetViewer
    
    var windowType: WindowType {
        switch self {
        case .dataTable, .multiSheetViewer:
            return .column
        case .scatterPlot2D, .lineChart, .multiLineChart, .barChart, .areaChart,
             .histogram, .boxPlot, .violinPlot, .candlestick, .heatmap:
            return .charts
        case .scatterPlot3D, .surface3D, .contourPlot, .densityHeatMap,
             .spatialNetwork, .forceDirectedGraph, .hierarchicalLayout,
             .sunburst, .treemap, .geospatialMap, .timeSeriesPath:
            return .spatial
        case .pointCloud3D, .volumetric, .crossSection:
            return .pointcloud
        case .model3DViewer, .materialEditor, .animationTimeline:
            return .model3d
        case .jsonTreeViewer, .notebookSpatialLayout, .cellFlowVisualization:
            return .spatial
        }
    }
}

// MARK: - Visualization Configurations

protocol VisualizationConfiguration {}

struct EmptyConfiguration: VisualizationConfiguration {}

struct DataTableConfiguration: VisualizationConfiguration {
    var pageSize: Int = 50
    var enableSorting: Bool = true
    var enableFiltering: Bool = true
}

struct ScatterPlotConfiguration: VisualizationConfiguration {
    let dimensions: Int
    var suggestedAxes: [String] = []
    var enableColorMapping: Bool = true
}

struct PointCloudConfiguration: VisualizationConfiguration {
    var estimatedPoints: Int = 0
    var coordinateColumns: [String] = []
    var hasIntensity: Bool = false
    var hasColor: Bool = false
    var hasClassification: Bool = false
    var enableLOD: Bool = true
}

struct HeatmapConfiguration: VisualizationConfiguration {
    var colorScale: String = "viridis"
    var enableInterpolation: Bool = true
}

struct TimeSeriesConfiguration: VisualizationConfiguration {
    var timeColumn: String = ""
    var spatialColumns: [String] = []
    var animationSpeed: Double = 1.0
}

struct NetworkConfiguration: VisualizationConfiguration {
    var layoutAlgorithm: String = "force-directed"
    var enable3D: Bool = true
}

struct ForceDirectedConfiguration: VisualizationConfiguration {
    var chargeStrength: Double = -30
    var linkDistance: Double = 30
}

struct HierarchicalConfiguration: VisualizationConfiguration {
    var orientation: String = "vertical"
    var nodeSpacing: Double = 20
}

struct VolumetricConfiguration: VisualizationConfiguration {
    var renderMode: String = "points"
    var enableInteraction: Bool = true
}

struct CrossSectionConfiguration: VisualizationConfiguration {
    var axis: String = "z"
    var sliceCount: Int = 10
}

struct LineChartConfiguration: VisualizationConfiguration {
    var enableSmoothing: Bool = false
    var showDataPoints: Bool = true
}

struct AreaChartConfiguration: VisualizationConfiguration {
    var stackMode: String = "normal"
    var transparency: Double = 0.7
}

struct MultiLineChartConfiguration: VisualizationConfiguration {
    var maxLines: Int = 10
    var enableLegend: Bool = true
}

struct BarChartConfiguration: VisualizationConfiguration {
    var orientation: String = "vertical"
    var groupMode: String = "grouped"
}

struct HistogramConfiguration: VisualizationConfiguration {
    var binCount: Int = 30
    var enableDensityCurve: Bool = false
}

struct CandlestickConfiguration: VisualizationConfiguration {
    var upColor: String = "green"
    var downColor: String = "red"
}

struct Surface3DConfiguration: VisualizationConfiguration {
    var colorMap: String = "viridis"
    var enableWireframe: Bool = false
}

struct ContourConfiguration: VisualizationConfiguration {
    var levelCount: Int = 10
    var enableLabels: Bool = true
}

struct GeospatialConfiguration: VisualizationConfiguration {
    var mapStyle: String = "satellite"
    var enableClustering: Bool = true
}

struct SpreadsheetViewerConfiguration: VisualizationConfiguration {
    let sheetNames: [String]
    var activeSheet: Int = 0
}

struct Model3DViewerConfiguration: VisualizationConfiguration {
    var enableWireframe: Bool = false
    var enableBoundingBox: Bool = false
}

struct MaterialEditorConfiguration: VisualizationConfiguration {
    var enableRealTimePreview: Bool = true
}

struct AnimationConfiguration: VisualizationConfiguration {
    var playbackSpeed: Double = 1.0
    var enableLooping: Bool = true
}

struct NotebookLayoutConfiguration: VisualizationConfiguration {
    var layoutStyle: String = "flow"
    var cellSpacing: Double = 20
}

struct JSONViewerConfiguration: VisualizationConfiguration {
    var expandDepth: Int = 2
    var enableSearch: Bool = true
}

struct SunburstConfiguration: VisualizationConfiguration {
    var startAngle: Double = 0
    var enableZoom: Bool = true
}

struct TreemapConfiguration: VisualizationConfiguration {
    var algorithm: String = "squarify"
    var enableTooltips: Bool = true
}

// MARK: - LAS File Support

struct LASHeader {
    let versionMajor: UInt8
    let versionMinor: UInt8
    let systemIdentifier: String
    let generatingSoftware: String
    let fileCreationDayOfYear: UInt16
    let fileCreationYear: UInt16
    let headerSize: UInt16
    let offsetToPointData: UInt32
    let numberOfVariableLengthRecords: UInt32
    let pointDataFormatID: UInt8
    let pointDataRecordLength: UInt16
    let numberOfPointRecords: UInt32
    let scaleX: Double
    let scaleY: Double
    let scaleZ: Double
    let offsetX: Double
    let offsetY: Double
    let offsetZ: Double
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double
    let minZ: Double
    let maxZ: Double
}

struct LASPoint {
    let x: Double
    let y: Double
    let z: Double
    let intensity: UInt16
    let classification: UInt8
    let red: UInt16
    let green: UInt16
    let blue: UInt16
    let gpsTime: Double
}

// MARK: - Errors

enum FileAnalysisError: LocalizedError {
    case unsupportedFormat
    case encodingError
    case emptyFile
    case invalidNotebookFormat
    case parsingError(String)
    case invalidLASFile(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported file format"
        case .encodingError:
            return "Unable to decode file contents"
        case .emptyFile:
            return "File is empty"
        case .invalidNotebookFormat:
            return "Invalid Jupyter notebook format"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        case .invalidLASFile(let message):
            return "Invalid LAS file: \(message)"
        }
    }
}
