//
//  SpatialDataTypes.swift
//  Pulto
//
//  Supporting types for spatial data visualization
//

import Foundation
import RealityKit

// MARK: - Supporting Types for Spatial Data Visualization

enum SpatialDataType: String, CaseIterable {
    case pointCloud = "pointCloud"
    case volumetric = "volumetric"
    case mesh = "mesh"
    case voxel = "voxel"
    case notebook = "notebook"
}

struct SpatialDataItem {
    let dataType: SpatialDataType
    let rawData: Data
    let dimensions: SIMD3<Float>
    let pointCount: Int
    let metadata: [String: Any]

    init(dataType: SpatialDataType, rawData: Data = Data(), dimensions: SIMD3<Float> = SIMD3<Float>(1, 1, 1), pointCount: Int = 100, metadata: [String: Any] = [:]) {
        self.dataType = dataType
        self.rawData = rawData
        self.dimensions = dimensions
        self.pointCount = pointCount
        self.metadata = metadata
    }
}

struct PointCloudVisualizationData {
    let points: [SIMD3<Float>]
    let colors: [SIMD3<Float>]?
    let center: SIMD3<Float>

    init(points: [SIMD3<Float>], colors: [SIMD3<Float>]? = nil) {
        self.points = points
        self.colors = colors

        // Calculate center
        let sum = points.reduce(SIMD3<Float>(0, 0, 0)) { $0 + $1 }
        self.center = sum / Float(points.count)
    }
}