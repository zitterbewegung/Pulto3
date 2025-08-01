//
//  ChartDocuments.swift
//  Pulto3
//
//  Created by AI Assistant on 1/29/25.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Text File Document
struct TextFileDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.pythonScript, .plainText]
    
    var content: String
    
    init(content: String = "") {
        self.content = content
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        content = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}

// MARK: - Image File Document
struct ImageFileDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.png, .jpeg]
    
    let chartBuilder: ChartBuilder
    
    init(chartBuilder: ChartBuilder) {
        self.chartBuilder = chartBuilder
    }
    
    init(configuration: ReadConfiguration) throws {
        // For reading, we'd need to reconstruct the chart builder
        // For now, create an empty one
        self.chartBuilder = ChartBuilder()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Generate a simple image representation
        // In a real implementation, you'd render the chart to an image
        let placeholder = "Chart Image Placeholder"
        let data = placeholder.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}

// MARK: - Python Script UTType Extension
extension UTType {
    static let pythonScript = UTType(filenameExtension: "py") ?? .plainText
}