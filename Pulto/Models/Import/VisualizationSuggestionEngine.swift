//
//  VisualizationSuggestionEngine.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/18/25.
//  Copyright © 2025 Apple. All rights reserved.
//



import Foundation
import SwiftUI

// MARK: - Visualization Suggestion Engine

class VisualizationSuggestionEngine {

    func suggestVisualizations(for analysis: DataAnalysisResult) -> [VisualizationRecommendation] {
        var recommendations: [VisualizationRecommendation] = []

        switch analysis.dataType {
        case .tabular:
            recommendations.append(contentsOf: suggestTabularVisualizations(analysis))

        case .tabularWithCoordinates:
            recommendations.append(contentsOf: suggestCoordinateVisualizations(analysis))

        case .pointCloud:
            recommendations.append(contentsOf: suggestPointCloudVisualizations(analysis))

        case .timeSeries:
            recommendations.append(contentsOf: suggestTimeSeriesVisualizations(analysis))

        case .networkData:
            recommendations.append(contentsOf: suggestNetworkVisualizations(analysis))

        case .geospatial:
            recommendations.append(contentsOf: suggestGeospatialVisualizations(analysis))

        case .spreadsheet:
            recommendations.append(contentsOf: suggestSpreadsheetVisualizations(analysis))

        case .model3D:
            recommendations.append(contentsOf: suggest3DModelVisualizations(analysis))

        case .notebook:
            recommendations.append(contentsOf: suggestNotebookVisualizations(analysis))

        case .matrix:
            recommendations.append(contentsOf: suggestMatrixVisualizations(analysis))

        case .hierarchical:
            recommendations.append(contentsOf: suggestHierarchicalVisualizations(analysis))

        case .structured, .unknown:
            recommendations.append(contentsOf: suggestGenericVisualizations(analysis))
        }

        // Sort by priority
        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }

    // MARK: - Specific Visualization Suggestions

    private func suggestTabularVisualizations(_ analysis: DataAnalysisResult) -> [VisualizationRecommendation] {
        var recommendations: [VisualizationRecommendation] = []

        // Always suggest data table for tabular data
        recommendations.append(VisualizationRecommendation(
            type: .dataTable,
            priority: .high,
            confidence: 1.0,
            reason: "View and explore your tabular data in an interactive table",
            configuration: DataTableConfiguration()
        ))

        if let structure = analysis.structure as? TabularStructure {
            let numericColumns = structure.columnTypes.filter { $0.value == .numeric }.count
            let categoricalColumns = structure.columnTypes.filter { $0.value == .categorical }.count

            // Suggest scatter plot if we have 2+ numeric columns
            if numericColumns >= 2 {
                recommendations.append(VisualizationRecommendation(
                    type: .scatterPlot2D,
                    priority: .medium,
                    confidence: 0.8,
                    reason: "Explore relationships between numeric variables",
                    configuration: ScatterPlotConfiguration(
                        dimensions: 2,
                        suggestedAxes: Array((structure.columnTypes.filter { $0.value == .numeric }.keys).prefix(2))
                    )
                ))
            }

            // Suggest bar chart if we have categorical and numeric data
            if categoricalColumns > 0 && numericColumns > 0 {
                recommendations.append(VisualizationRecommendation(
                    type: .barChart,
                    priority: .medium,
                    confidence: 0.7,
                    reason: "Compare values across categories",
                    configuration: BarChartConfiguration()
                ))
            }

            // Suggest histogram for numeric columns
            if numericColumns > 0 {
                recommendations.append(VisualizationRecommendation(
                    type: .histogram,
                    priority: .low,
                    confidence: 0.6,
                    reason: "Analyze distribution of numeric values",
                    configuration: HistogramConfiguration()
                ))
            }
        }

        return recommendations
    }

    private func suggestCoordinateVisualizations(_ analysis: DataAnalysisResult) -> [VisualizationRecommendation] {
        var recommendations: [VisualizationRecommendation] = []

        if let structure = analysis.structure as? TabularStructure {
            let coordCount = structure.coordinateColumns.count

            if coordCount >= 3 {
                // 3D scatter plot for 3D coordinates
                recommendations.append(VisualizationRecommendation(
                    type: .scatterPlot3D,
                    priority: .high,
                    confidence: 0.95,
                    reason: "Visualize 3D spatial data in an interactive 3D scatter plot",
                    configuration: ScatterPlotConfiguration(
                        dimensions: 3,
                        suggestedAxes: Array(structure.coordinateColumns.prefix(3))
                    )
                ))

                // Also suggest point cloud for dense 3D data
                if structure.rowCount > 1000 {
                    recommendations.append(VisualizationRecommendation(
                        type: .pointCloud3D,
                        priority: .high,
                        confidence: 0.9,
                        reason: "Visualize dense 3D data as an optimized point cloud",
                        configuration: PointCloudConfiguration(
                            estimatedPoints: structure.rowCount,
                            coordinateColumns: structure.coordinateColumns
                        )
                    ))
                }
            } else if coordCount == 2 {
                // 2D scatter plot for 2D coordinates
                recommendations.append(VisualizationRecommendation(
                    type: .scatterPlot2D,
                    priority: .high,
                    confidence: 0.9,
                    reason: "Visualize 2D spatial data",
                    configuration: ScatterPlotConfiguration(
                        dimensions: 2,
                        suggestedAxes: structure.coordinateColumns
                    )
                ))

                // Suggest heatmap for dense 2D data
                if structure.rowCount > 5000 {
                    recommendations.append(VisualizationRecommendation(
                        type: .densityHeatMap,
                        priority: .medium,
                        confidence: 0.7,
                        reason: "Visualize density patterns in your 2D spatial data",
                        configuration: HeatmapConfiguration()
                    ))
                }
            }

            // If we have time data, suggest animated visualization
            if !structure.timeColumns.isEmpty {
                recommendations.append(VisualizationRecommendation(
                    type: .timeSeriesPath,
                    priority: .medium,
                    confidence: 0.8,
                    reason: "Animate spatial data changes over time",
                    configuration: TimeSeriesConfiguration(
                        timeColumn: structure.timeColumns.first!,
                        spatialColumns: structure.coordinateColumns
                    )
                ))
            }
        }

        // Always include data table as an option
        recommendations.append(VisualizationRecommendation(
            type: .dataTable,
            priority: .low,
            confidence: 0.5,
            reason: "View raw coordinate data in tabular form",
            configuration: DataTableConfiguration()
        ))

        return recommendations
    }

    private func suggestPointCloudVisualizations(_ analysis: DataAnalysisResult) -> [VisualizationRecommendation] {
        var recommendations: [VisualizationRecommendation] = []

        if let structure = analysis.structure as? PointCloudStructure {
            // Primary point cloud visualization
            recommendations.append(VisualizationRecommendation(
                type: .pointCloud3D,
                priority: .high,
                confidence: 1.0,
                reason: "View your LiDAR/point cloud data in full 3D",
                configuration: PointCloudConfiguration(
                    estimatedPoints: structure.pointCount,
                    hasIntensity: structure.hasIntensity,
                    hasColor: structure.hasColor,
                    hasClassification: structure.hasClassification
                )
            ))

            // Volumetric view for dense point clouds
            if structure.pointCount > 10000 {
                recommendations.append(VisualizationRecommendation(
                    type: .volumetric,
                    priority: .medium,
                    confidence: 0.8,
                    reason: "Experience your point cloud in immersive volumetric space",
                    configuration: VolumetricConfiguration()
                ))
            }

            // Density analysis
            if structure.averageDensity > 0 {
                recommendations.append(VisualizationRecommendation(
                    type: .densityHeatMap,
                    priority: .medium,
                    confidence: 0.7,
                    reason: "Analyze point density distribution",
                    configuration: HeatmapConfiguration()
                ))
            }

            // Cross-section view
            recommendations.append(VisualizationRecommendation(
                type: .crossSection,
                priority: .low,
                confidence: 0.6,
                reason: "Examine cross-sections of your point cloud",
                configuration: CrossSectionConfiguration()
            ))

            // GPS timeline if available
            if structure.hasGPSTime {
                recommendations.append(VisualizationRecommendation(
                    type: .timeSeriesPath,
                    priority: .medium,
                    confidence: 0.8,
                    reason: "Visualize GPS time progression through the scan",
                    configuration: TimeSeriesConfiguration()
                ))
            }
        }

        return recommendations
    }

    private func suggestTimeSeriesVisualizations(_ analysis: DataAnalysisResult) -> [VisualizationRecommendation] {
        var recommendations: [VisualizationRecommendation] = []

        // Line chart for time series
        recommendations.append(VisualizationRecommendation(
            type: .lineChart,
            priority: .high,
            confidence: 0.9,
            reason: "Track changes over time with a line chart",
            configuration: LineChartConfiguration()
        ))

        // Area chart for cumulative view
        recommendations.append(VisualizationRecommendation(
            type: .areaChart,
            priority: .medium,
            confidence: 0.7,
            reason: "Visualize cumulative trends over time",
            configuration: AreaChartConfiguration()
        ))

        if let structure = analysis.structure as? TabularStructure {
            // Multi-line chart if multiple numeric columns
            let numericColumns = structure.columnTypes.filter { $0.value == .numeric }.count
            if numericColumns > 1 {
                recommendations.append(VisualizationRecommendation(
                    type: .multiLineChart,
                    priority: .medium,
                    confidence: 0.8,
                    reason: "Compare multiple time series simultaneously",
                    configuration: MultiLineChartConfiguration()
                ))
            }

            // Candlestick if we have OHLC data
            let headers = Set(structure.headers.map { $0.lowercased() })
            if headers.contains("open") && headers.contains("high") &&
               headers.contains("low") && headers.contains("close") {
                recommendations.append(VisualizationRecommendation(
                    type: .candlestick,
                    priority: .high,
                    confidence: 0.95,
                    reason: "Visualize financial OHLC data",
                    configuration: CandlestickConfiguration()
                ))
            }
        }

        return recommendations
    }

    private func suggestNetworkVisualizations(_ analysis: DataAnalysisResult) -> [VisualizationRecommendation] {
        var recommendations: [VisualizationRecommendation] = []

        // Primary network visualization
        recommendations.append(VisualizationRecommendation(
            type: .spatialNetwork,
            priority: .high,
            confidence: 0.9,
            reason: "Visualize network relationships in 3D space",
            configuration: NetworkConfiguration()
        ))

        // Force-directed layout
        recommendations.append(VisualizationRecommendation(
            type: .forceDirectedGraph,
            priority: .medium,
            confidence: 0.8,
            reason: "Explore network structure with physics-based layout",
            configuration: ForceDirectedConfiguration()
        ))

        // Hierarchical layout if detected
        if case .hierarchical = analysis.dataType {
            recommendations.append(VisualizationRecommendation(
                type: .hierarchicalLayout,
                priority: .high,
                confidence: 0.85,
                reason: "View hierarchical relationships in your data",
                configuration: HierarchicalConfiguration()
            ))
        }

        return recommendations
    }

    private func suggestGeospatialVisualizations(_ analysis: DataAnalysisResult) -> [VisualizationRecommendation] {
        var recommendations: [VisualizationRecommendation] = []

        // 3D globe visualization
        recommendations.append(VisualizationRecommendation(
            type: .geospatialMap,
            priority: .high,
            confidence: 0.9,
            reason: "Visualize geographic data on a 3D globe",
            configuration: GeospatialConfiguration()
        ))

        // Heat map overlay
        recommendations.append(VisualizationRecommendation(
            type: .densityHeatMap,
            priority: .medium,
            confidence: 0.7,
            reason: "Show density patterns on geographic regions",
            configuration: HeatmapConfiguration()
        ))

        return recommendations
    }

    private func suggestSpreadsheetVisualizations(_ analysis: DataAnalysisResult) -> [VisualizationRecommendation] {
        var recommendations: [VisualizationRecommendation] = []

        if let structure = analysis.structure as? SpreadsheetStructure {
            // Suggest multi-sheet viewer
            if structure.sheets.count > 1 {
                recommendations.append(VisualizationRecommendation(
                    type: .multiSheetViewer,
                    priority: .high,
                    confidence: 0.9,
                    reason: "Navigate between multiple sheets in your workbook",
                    configuration: SpreadsheetViewerConfiguration(
                        sheetNames: structure.sheets.map { $0.name }
                    )
                ))
            }

            // Analyze each sheet and aggregate suggestions
            for sheet in structure.sheets {
                // Create a pseudo-analysis for each sheet
                let sheetAnalysis = DataAnalysisResult(
                    dataType: .tabular,
                    structure: TabularStructure(
                        headers: [], // Would be populated from actual sheet data
                        columnTypes: [:],
                        rowCount: sheet.rowCount,
                        patterns: [],
                        coordinateColumns: [],
                        timeColumns: []
                    ),
                    metadata: ["sheetName": sheet.name],
                    suggestions: []
                )

                // Get suggestions for this sheet
                let sheetSuggestions = suggestTabularVisualizations(sheetAnalysis)
                recommendations.append(contentsOf: sheetSuggestions.map { suggestion in
                    var modified = suggestion
                    modified.reason = "\(sheet.name): \(suggestion.reason)"
                    return modified
                })
            }
        }

        return recommendations
    }

    private func suggest3DModelVisualizations(_ analysis: DataAnalysisResult) -> [VisualizationRecommendation] {
        var recommendations: [VisualizationRecommendation] = []

        // Primary 3D model viewer
        recommendations.append(VisualizationRecommendation(
            type: .model3DViewer,
            priority: .high,
            confidence: 1.0,
            reason: "View and interact with your 3D model",
            configuration: Model3DViewerConfiguration()
        ))

        // Volumetric view for AR/VR
        recommendations.append(VisualizationRecommendation(
            type: .volumetric,
            priority: .medium,
            confidence: 0.8,
            reason: "Experience your 3D model in spatial computing",
            configuration: VolumetricConfiguration()
        ))

        if let structure = analysis.structure as? Model3DStructure {
            // Suggest material editor if materials present
            if structure.hasMaterials {
                recommendations.append(VisualizationRecommendation(
                    type: .materialEditor,
                    priority: .low,
                    confidence: 0.6,
                    reason: "Edit and preview model materials",
                    configuration: MaterialEditorConfiguration()
                ))
            }

            // Suggest animation viewer if animations present
            if structure.hasAnimations {
                recommendations.append(VisualizationRecommendation(
                    type: .animationTimeline,
                    priority: .medium,
                    confidence: 0.7,
                    reason: "Control and preview model animations",
                    configuration: AnimationConfiguration()
                ))
            }
        }

        return recommendations
    }

    private func suggestNotebookVisualizations(_ analysis: DataAnalysisResult) -> [VisualizationRecommendation] {
        var recommendations: [VisualizationRecommendation] = []

        if let structure = analysis.structure as? NotebookStructure {
            // Create a spatial notebook layout
            recommendations.append(VisualizationRecommendation(
                type: .notebookSpatialLayout,
                priority: .high,
                confidence: 0.8,
                reason: "View notebook cells in spatial arrangement",
                configuration: NotebookLayoutConfiguration()
            ))

            // Suggest visualizations based on extracted data
            for data in structure.extractedData {
                switch data.dataType {
                case .dataFrame:
                    recommendations.append(VisualizationRecommendation(
                        type: .dataTable,
                        priority: .medium,
                        confidence: 0.7,
                        reason: "View DataFrame '\(data.variableName)' as interactive table",
                        configuration: DataTableConfiguration()
                    ))

                case .array:
                    if let shape = data.shape, shape.1 >= 2 {
                        recommendations.append(VisualizationRecommendation(
                            type: .scatterPlot2D,
                            priority: .medium,
                            confidence: 0.6,
                            reason: "Visualize array '\(data.variableName)' as scatter plot",
                            configuration: ScatterPlotConfiguration(dimensions: 2)
                        ))
                    }

                case .pointCloud:
                    recommendations.append(VisualizationRecommendation(
                        type: .pointCloud3D,
                        priority: .high,
                        confidence: 0.8,
                        reason: "Visualize '\(data.variableName)' as 3D point cloud",
                        configuration: PointCloudConfiguration()
                    ))
                }
            }

            // Suggest native versions of notebook visualizations
            for vizCode in structure.visualizationCode {
                let nativeType = mapNotebookVizToNative(vizCode.type)
                recommendations.append(VisualizationRecommendation(
                    type: nativeType,
                    priority: .medium,
                    confidence: 0.7,
                    reason: "Native visionOS version of \(vizCode.library) \(vizCode.type)",
                    configuration: EmptyConfiguration()
                ))
            }
        }

        return recommendations
    }

    private func suggestMatrixVisualizations(_ analysis: DataAnalysisResult) -> [VisualizationRecommendation] {
        var recommendations: [VisualizationRecommendation] = []

        // Heatmap for matrix data
        recommendations.append(VisualizationRecommendation(
            type: .heatmap,
            priority: .high,
            confidence: 0.9,
            reason: "Visualize matrix values as a color-coded heatmap",
            configuration: HeatmapConfiguration()
        ))

        // 3D surface plot
        recommendations.append(VisualizationRecommendation(
            type: .surface3D,
            priority: .medium,
            confidence: 0.8,
            reason: "View matrix as 3D surface",
            configuration: Surface3DConfiguration()
        ))

        // Contour plot
        recommendations.append(VisualizationRecommendation(
            type: .contourPlot,
            priority: .low,
            confidence: 0.6,
            reason: "Show matrix contour lines",
            configuration: ContourConfiguration()
        ))

        return recommendations
    }

    private func suggestHierarchicalVisualizations(_ analysis: DataAnalysisResult) -> [VisualizationRecommendation] {
        var recommendations: [VisualizationRecommendation] = []

        // Tree visualization
        recommendations.append(VisualizationRecommendation(
            type: .hierarchicalLayout,
            priority: .high,
            confidence: 0.9,
            reason: "Visualize hierarchical relationships as a tree",
            configuration: HierarchicalConfiguration()
        ))

        // Sunburst chart
        recommendations.append(VisualizationRecommendation(
            type: .sunburst,
            priority: .medium,
            confidence: 0.7,
            reason: "Show hierarchy as interactive sunburst diagram",
            configuration: SunburstConfiguration()
        ))

        // Treemap
        recommendations.append(VisualizationRecommendation(
            type: .treemap,
            priority: .medium,
            confidence: 0.7,
            reason: "Visualize hierarchical data with size proportions",
            configuration: TreemapConfiguration()
        ))

        return recommendations
    }

    private func suggestGenericVisualizations(_ analysis: DataAnalysisResult) -> [VisualizationRecommendation] {
        var recommendations: [VisualizationRecommendation] = []

        // Basic data table
        recommendations.append(VisualizationRecommendation(
            type: .dataTable,
            priority: .medium,
            confidence: 0.5,
            reason: "Explore your data in tabular format",
            configuration: DataTableConfiguration()
        ))

        // JSON tree viewer for structured data
        if analysis.dataType == .structured {
            recommendations.append(VisualizationRecommendation(
                type: .jsonTreeViewer,
                priority: .medium,
                confidence: 0.6,
                reason: "Navigate structured data hierarchy",
                configuration: JSONViewerConfiguration()
            ))
        }

        return recommendations
    }

    // MARK: - Helper Functions

    private func mapNotebookVizToNative(_ notebookType: ImportVisualizationType) -> SpatialVisualizationType {
        switch notebookType {
        case .scatter2D: return .scatterPlot2D
        case .scatter3D: return .scatterPlot3D
        case .line: return .lineChart
        case .bar: return .barChart
        case .histogram: return .histogram
        case .heatmap: return .heatmap
        case .surface3D: return .surface3D
        case .contour: return .contourPlot
        case .box: return .boxPlot
        case .violin: return .violinPlot
        case .network: return .spatialNetwork
        case .tree: return .hierarchicalLayout
        }
    }
}
