import Foundation
import SwiftUI

// MARK: - Jupyter Notebook Structure
// Renamed to avoid namespace collisions with other libraries.

struct PultoJupyterNotebook: Codable {
    var cells: [PultoCell]
    var metadata: PultoNotebookMetadata
    var nbformat: Int
    var nbformat_minor: Int
}

enum PultoCell: Codable {
    case code(PultoCodeCell)
    case markdown(PultoMarkdownCell)

    enum CodingKeys: String, CodingKey {
        case cell_type
    }
 
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .cell_type)
        switch type {
        case "code":
            self = .code(try PultoCodeCell(from: decoder))
        case "markdown":
            self = .markdown(try PultoMarkdownCell(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .cell_type, in: container, debugDescription: "Invalid cell type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .code(let codeCell):
            try container.encode(codeCell)
        case .markdown(let markdownCell):
            try container.encode(markdownCell)
        }
    }
    
    var pultoMetadata: PultoWindowMetadata? {
        switch self {
        case .code(let cell):
            return cell.metadata.pulto
        case .markdown:
            return nil
        }
    }
}

struct PultoCodeCell: Codable {
    var cell_type: String = "code"
    var execution_count: Int?
    var metadata: PultoCellMetadata
    var outputs: [PultoOutput]
    var source: String

    init(source: String, metadata: PultoCellMetadata, outputs: [PultoOutput] = [], execution_count: Int? = nil) {
        self.source = source
        self.metadata = metadata
        self.outputs = outputs
        self.execution_count = execution_count
    }
}

struct PultoMarkdownCell: Codable {
    var cell_type: String = "markdown"
    var metadata: PultoCellMetadata
    var source: String
}

// MARK: - Metadata Structures

struct PultoNotebookMetadata: Codable {
    var pulto_workspace: PultoWorkspaceMetadata?
}

struct PultoWorkspaceMetadata: Codable, Hashable {
    var id: UUID
    var name: String
    var description: String
    var category: WorkspaceCategory
    var tags: [String]
    var schemaVersion: String
}

struct PultoCellMetadata: Codable {
    var pulto: PultoWindowMetadata?
}

struct PultoWindowMetadata: Codable {
    var window_type: String
    var position: WindowPosition
    var state: WindowState
}

// MARK: - Cell Output

struct PultoOutput: Codable {
    // Defines the structure for cell outputs (e.g., text, images)
    // For now, we don't need to decode complex outputs.
}
