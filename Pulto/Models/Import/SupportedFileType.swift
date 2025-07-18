//
//  SupportedFileType.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/18/25.
//  Copyright © 2025 Apple. All rights reserved.
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
}

// MARK: - Analysis Structures

protocol AnalysisStructure {}

struct TabularStructure: AnalysisStructure {
    let headers: [String]
    let importcolumnTypes: [String: ImportColumnType]
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
    let dataTypes: [String: ImportColumnType]
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

struct VisualizationRecommendation: Identifiable {
    let id = UUID()
    let type: SpatialVisualizationType
    let priority: Priority
    let confidence: Double
    var reason: String
    let configuration: any VisualizationConfiguration

    enum Priority: Int, Comparable {
        case high = 3
        case medium = 2
        case low = 1

        static func < (lhs: VisualizationRecommendation.Priority, rhs: VisualizationRecommendation.Priority) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
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

struct DataTableConfiguration: VisualizationConfiguration {}
struct ScatterPlotConfiguration: VisualizationConfiguration {}
struct PointCloudConfiguration: VisualizationConfiguration {}
struct HeatmapConfiguration: VisualizationConfiguration {}
struct TimeSeriesConfiguration: VisualizationConfiguration {}
struct NetworkConfiguration: VisualizationConfiguration {}
struct VolumetricConfiguration: VisualizationConfiguration {}
struct CrossSectionConfiguration: VisualizationConfiguration {}
struct LineChartConfiguration: VisualizationConfiguration {}
struct AreaChartConfiguration: VisualizationConfiguration {}
struct MultiLineChartConfiguration: VisualizationConfiguration {}
struct BarChartConfiguration: VisualizationConfiguration {}
struct HistogramConfiguration: VisualizationConfiguration {}
struct CandlestickConfiguration: VisualizationConfiguration {}
struct Surface3DConfiguration: VisualizationConfiguration {}
struct ContourConfiguration: VisualizationConfiguration {}
struct GeospatialConfiguration: VisualizationConfiguration {}
struct SpreadsheetViewerConfiguration: VisualizationConfiguration {}
struct Model3DViewerConfiguration: VisualizationConfiguration {}
struct MaterialEditorConfiguration: VisualizationConfiguration {}
struct AnimationConfiguration: VisualizationConfiguration {}
struct NotebookLayoutConfiguration: VisualizationConfiguration {}
struct JSONViewerConfiguration: VisualizationConfiguration {}
struct SunburstConfiguration: VisualizationConfiguration {}
struct TreemapConfiguration: VisualizationConfiguration {}


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

