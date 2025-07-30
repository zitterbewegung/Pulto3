//
//  JupyterNotebook.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/19/25.
//  Copyright © 2025 Apple. All rights reserved.
//
import Foundation
import SwiftUI

// MARK: - Jupyter Notebook Format Structures

struct JupyterNotebookImport: Codable {
    var cells: [JupyterCellImport]
    var metadata: JupyterMetadataImport
    var nbformat: Int
    var nbformat_minor: Int
    
    init() {
        self.cells = []
        self.metadata = JupyterMetadataImport()
        self.nbformat = 4
        self.nbformat_minor = 2
    }
}

struct JupyterCellImport: Codable {
    var cell_type: String
    var metadata: CellMetadataImport
    var source: [String]
    var outputs: [JupyterOutputImport]?
    var execution_count: Int?
    
    init(type: String, source: [String]) {
        self.cell_type = type
        self.metadata = CellMetadataImport()
        self.source = source
        self.outputs = type == "code" ? [] : nil
        self.execution_count = type == "code" ? 1 : nil
    }
}

struct CellMetadataImport: Codable {
    var collapsed: Bool?
    var scrolled: Bool?
    var tags: [String]?
    var spatialData: SpatialCellData?
    
    init() {
        self.collapsed = false
        self.scrolled = false
        self.tags = []
        self.spatialData = nil
    }
}

struct SpatialCellData: Codable {
    var position: SpatialPosition
    var visualizationType: String
    var volumetricData: VolumetricData?
    
    struct SpatialPosition: Codable {
        var x: Double
        var y: Double
        var z: Double
        var rotationX: Double
        var rotationY: Double
        var rotationZ: Double
    }
    
    struct VolumetricData: Codable {
        var width: Double
        var height: Double
        var depth: Double
        var modelURL: String?
        var pointCloudData: String? // Base64 encoded
    }
}

struct JupyterOutputImport: Codable {
    var output_type: String
    var data: OutputDataImport?
    var text: [String]?
    var name: String?
    var execution_count: Int?
    
    struct OutputDataImport: Codable {
        var text_plain: [String]?
        var image_png: String?
        var image_svg: String?
        var application_json: AnyCodableImport?
        var spatial_volumetric: SpatialVolumetricOutput?
        
        enum CodingKeys: String, CodingKey {
            case text_plain = "text/plain"
            case image_png = "image/png"
            case image_svg = "image/svg+xml"
            case application_json = "application/json"
            case spatial_volumetric = "application/vnd.pulto.spatial+json"
        }
    }
}

struct SpatialVolumetricOutput: Codable {
    var type: String // "pointcloud", "model3d", "volumetric"
    var data: String // Base64 encoded data
    var metadata: [String: AnyCodableImport]
}

struct JupyterMetadataImport: Codable {
    var kernelspec: KernelSpec?
    var language_info: LanguageInfo?
    var spatialVisualization: SpatialVisualizationMetadata?
    
    init() {
        self.kernelspec = KernelSpec()
        self.language_info = LanguageInfo()
        self.spatialVisualization = nil
    }
}

struct KernelSpec: Codable {
    var display_name: String
    var language: String
    var name: String
    
    init() {
        self.display_name = "Python 3"
        self.language = "python"
        self.name = "python3"
    }
}

struct LanguageInfo: Codable {
    var name: String
    var version: String
    
    init() {
        self.name = "python"
        self.version = "3.9.0"
    }
}

struct SpatialVisualizationMetadata: Codable {
    var enabled: Bool
    var defaultVisualizationType: String
    var volumetricSettings: VolumetricSettings
    
    struct VolumetricSettings: Codable {
        var defaultScale: Double
        var enableInteraction: Bool
        var renderQuality: String // "low", "medium", "high"
    }
}

// MARK: - AnyCodable for flexible JSON encoding/decoding

struct AnyCodableImport: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodableImport].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodableImport].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodableImport($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodableImport($0) })
        default:
            throw EncodingError.invalidValue(value, .init(codingPath: [], debugDescription: "Cannot encode value"))
        }
    }
}