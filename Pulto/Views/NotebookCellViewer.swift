//
//  NotebookCellViewer.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/19/25.
//  Copyright Apple. All rights reserved.
//

import SwiftUI
import Foundation

struct NotebookCellViewer: View {
    let notebook: JupyterNotebook
    @State private var selectedCellIndex: Int? = nil
    @State private var showingSpatialData = true
    @State private var showingMetadata = false
    @State private var showingInspector = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar with cell list
            VStack(spacing: 0) {
                // Sidebar header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Cells", systemImage: "list.bullet.rectangle")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(notebook.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial)
                
                Divider()
                
                // Controls section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Display Options")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Show Spatial Data", isOn: $showingSpatialData)
                            .font(.subheadline)
                        
                        Toggle("Show Metadata", isOn: $showingMetadata)
                            .font(.subheadline)
                        
                        Toggle("Show Inspector", isOn: $showingInspector)
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial)
                
                Divider()
                
                // Cell list
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if let cells = notebook.content?.cells {
                            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                                CellListRow(
                                    cell: cell,
                                    index: index,
                                    isSelected: selectedCellIndex == index,
                                    hasSpatialData: hasSpatialData(cell: cell)
                                ) {
                                    selectedCellIndex = index
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 350)
            .background(.regularMaterial)
            
            Divider()
            
            // Main content area
            VStack(spacing: 0) {
                // Content header with toolbar
                HStack {
                    if let selectedIndex = selectedCellIndex,
                       let cells = notebook.content?.cells,
                       selectedIndex < cells.count {
                        let cell = cells[selectedIndex]
                        Label("Cell \(selectedIndex + 1)", systemImage: cellTypeIcon(for: cell.cellType))
                            .font(.headline)
                            .foregroundStyle(cellTypeColor(for: cell.cellType))
                    } else {
                        Label("No Selection", systemImage: "doc.text.magnifyingglass")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button("Export Cell") {
                            // Export functionality
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(selectedCellIndex == nil)
                        
                        Button("Copy Source") {
                            copyCellSource()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(selectedCellIndex == nil)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.regularMaterial)
                
                Divider()
                
                // Main content view
                if let cells = notebook.content?.cells, 
                   let selectedIndex = selectedCellIndex,
                   selectedIndex < cells.count {
                    CellDetailView(
                        cell: cells[selectedIndex],
                        index: selectedIndex,
                        showingSpatialData: showingSpatialData,
                        showingMetadata: showingMetadata
                    )
                } else {
                    VStack(spacing: 24) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 64))
                            .foregroundStyle(.tertiary)
                        
                        VStack(spacing: 8) {
                            Text("No Cell Selected")
                                .font(.title)
                                .fontWeight(.semibold)
                            
                            Text("Select a cell from the sidebar to view its content and metadata.")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // Inspector panel (conditional)
            if showingInspector {
                Divider()
                
                InspectorPanel(
                    notebook: notebook,
                    selectedCellIndex: selectedCellIndex
                )
                .frame(minWidth: 300, idealWidth: 350, maxWidth: 400)
            }
        }
        .navigationTitle("Notebook Viewer")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Inspector") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showingInspector.toggle()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            // Auto-select first cell if available
            if selectedCellIndex == nil, 
               let cells = notebook.content?.cells, 
               !cells.isEmpty {
                selectedCellIndex = 0
            }
        }
    }
    
    private func hasSpatialData(cell: JupyterCell) -> Bool {
        guard let metadata = cell.metadata else { return false }
        return metadata.keys.contains { key in
            key.lowercased().contains("spatial") || key == "spatialData"
        }
    }
    
    private func cellTypeIcon(for cellType: String) -> String {
        switch cellType {
        case "code": return "curlybraces"
        case "markdown": return "doc.richtext"
        case "raw": return "doc.plaintext"
        default: return "doc"
        }
    }
    
    private func cellTypeColor(for cellType: String) -> Color {
        switch cellType {
        case "code": return .blue
        case "markdown": return .green
        case "raw": return .orange
        default: return .secondary
        }
    }
    
    private func copyCellSource() {
        guard let selectedIndex = selectedCellIndex,
              let cells = notebook.content?.cells,
              selectedIndex < cells.count else { return }
        
        let cell = cells[selectedIndex]
        let source = cell.source.joined(separator: "\n")
        
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(source, forType: .string)
        #endif
    }
}

// MARK: - Cell List Row

struct CellListRow: View {
    let cell: JupyterCell
    let index: Int
    let isSelected: Bool
    let hasSpatialData: Bool
    let onTap: () -> Void
    
    private var cellTypeIcon: String {
        switch cell.cellType {
        case "code": return "curlybraces"
        case "markdown": return "doc.richtext"
        case "raw": return "doc.plaintext"
        default: return "doc"
        }
    }
    
    private var cellTypeColor: Color {
        switch cell.cellType {
        case "code": return .blue
        case "markdown": return .green
        case "raw": return .orange
        default: return .secondary
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Cell type indicator
                VStack(spacing: 4) {
                    Image(systemName: cellTypeIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(cellTypeColor)
                        .frame(width: 20, height: 20)
                    
                    if hasSpatialData {
                        Image(systemName: "cube.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.purple)
                    }
                }
                .frame(width: 24)
                
                // Cell content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Cell \(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(cell.cellType.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(cellTypeColor.opacity(0.15))
                            .foregroundStyle(cellTypeColor)
                            .cornerRadius(4)
                    }
                    
                    if !cell.source.isEmpty {
                        let preview = cell.source.joined(separator: " ")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .prefix(60)
                        
                        Text(preview + (preview.count >= 60 ? "…" : ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    if cell.cellType == "code", let executionCount = cell.executionCount {
                        Text("Execution: \(executionCount)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? .blue.opacity(0.15) : .clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? .blue : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cell Detail View

struct CellDetailView: View {
    let cell: JupyterCell
    let index: Int
    let showingSpatialData: Bool
    let showingMetadata: Bool
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Cell source
                CellSourceSection(cell: cell, index: index)
                
                // Cell outputs
                if let outputs = cell.outputs, !outputs.isEmpty {
                    CellOutputsSection(outputs: outputs)
                }
                
                // Spatial data section
                if showingSpatialData {
                    SpatialDataSection(cell: cell)
                }
                
                // Metadata section
                if showingMetadata, let metadata = cell.metadata, !metadata.isEmpty {
                    MetadataSection(metadata: metadata)
                }
            }
            .padding(20)
        }
        .background(.background)
    }
}

// MARK: - Cell Source Section

struct CellSourceSection: View {
    let cell: JupyterCell
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Source Code", systemImage: "doc.text")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if cell.cellType == "code", let executionCount = cell.executionCount {
                    Text("[\(executionCount)]")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }
            }
            
            if !cell.source.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(cell.source.enumerated()), id: \.offset) { lineIndex, line in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(lineIndex + 1)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.quaternary)
                                .frame(minWidth: 24, alignment: .trailing)
                            
                            Text(line.isEmpty ? " " : line)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.separator, lineWidth: 0.5)
                )
            } else {
                Text("Empty cell")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Cell Outputs Section

struct CellOutputsSection: View {
    let outputs: [JupyterCellOutput]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Outputs", systemImage: "terminal")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(Array(outputs.enumerated()), id: \.offset) { outputIndex, output in
                CellOutputCard(output: output, index: outputIndex)
            }
        }
    }
}

// MARK: - Cell Output Card

struct CellOutputCard: View {
    let output: JupyterCellOutput
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Output \(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(output.outputType)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .cornerRadius(6)
            }
            
            if let text = output.text {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(text.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            }
            
            if let data = output.data {
                DataOutputCard(data: data)
            }
            
            if let executionCount = output.executionCount {
                Text("Execution count: \(executionCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator, lineWidth: 0.5)
        )
    }
}

// MARK: - Data Output Card

struct DataOutputCard: View {
    let data: [String: AnyCodable]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            ForEach(Array(data.keys.sorted()), id: \.self) { key in
                VStack(alignment: .leading, spacing: 6) {
                    Text(key)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Group {
                        if key.contains("text/plain") {
                            if let textArray = data[key]?.value as? [String] {
                                ForEach(textArray, id: \.self) { text in
                                    Text(text)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                            } else if let text = data[key]?.value as? String {
                                Text(text)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        } else if key.contains("image/") {
                            Label("Image data (\(key.components(separatedBy: "/").last ?? "unknown"))", 
                                  systemImage: "photo")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        } else {
                            Text(String(describing: data[key]?.value))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(5)
                        }
                    }
                }
                .padding(8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}

// MARK: - Spatial Data Section

struct SpatialDataSection: View {
    let cell: JupyterCell
    
    private var spatialMetadata: [String: Any] {
        guard let metadata = cell.metadata else { return [:] }
        var spatialData: [String: Any] = [:]
        
        for (key, value) in metadata {
            if key.lowercased().contains("spatial") {
                spatialData[key] = value.value
            }
        }
        
        return spatialData
    }
    
    var body: some View {
        if !spatialMetadata.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Spatial Data", systemImage: "cube")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.purple)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(spatialMetadata.keys.sorted()), id: \.self) { key in
                        SpatialDataCard(key: key, value: spatialMetadata[key])
                    }
                }
            }
        }
    }
}

// MARK: - Spatial Data Card

struct SpatialDataCard: View {
    let key: String
    let value: Any?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(key)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.purple)
            
            if let dict = value as? [String: Any] {
                LazyVGrid(columns: [
                    GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading)
                ], spacing: 8) {
                    ForEach(Array(dict.keys.sorted()), id: \.self) { subKey in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(subKey)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            
                            Text(formatValue(dict[subKey]))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            } else {
                Text(formatValue(value))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(16)
        .background(.purple.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.purple.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    private func formatValue(_ value: Any?) -> String {
        guard let value = value else { return "null" }
        
        if let number = value as? NSNumber {
            return number.stringValue
        } else if let string = value as? String {
            return string
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else {
            return String(describing: value)
        }
    }
}

// MARK: - Metadata Section

struct MetadataSection: View {
    let metadata: [String: AnyCodable]
    
    private var nonSpatialMetadata: [String: AnyCodable] {
        return metadata.filter { key, _ in
            !key.lowercased().contains("spatial")
        }
    }
    
    var body: some View {
        if !nonSpatialMetadata.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Metadata", systemImage: "info.circle")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(nonSpatialMetadata.keys.sorted()), id: \.self) { key in
                        NotebookMetadataCard(key: key, value: nonSpatialMetadata[key]?.value)
                    }
                }
            }
        }
    }
}

// MARK: - Notebook Metadata Card

struct NotebookMetadataCard: View {
    let key: String
    let value: Any?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(key)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.blue)
                .frame(minWidth: 100, alignment: .leading)
            
            Text(formatValue(value))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.blue.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    private func formatValue(_ value: Any?) -> String {
        guard let value = value else { return "null" }
        
        if let dict = value as? [String: Any] {
            let json = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
            return json.flatMap { String(data: $0, encoding: .utf8) } ?? String(describing: value)
        } else if let array = value as? [Any] {
            let json = try? JSONSerialization.data(withJSONObject: array, options: .prettyPrinted)
            return json.flatMap { String(data: $0, encoding: .utf8) } ?? String(describing: value)
        } else if let number = value as? NSNumber {
            return number.stringValue
        } else if let string = value as? String {
            return string
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else {
            return String(describing: value)
        }
    }
}

// MARK: - Inspector Panel

struct InspectorPanel: View {
    let notebook: JupyterNotebook
    let selectedCellIndex: Int?
    
    var selectedCell: JupyterCell? {
        guard let index = selectedCellIndex,
              let cells = notebook.content?.cells,
              index < cells.count else { return nil }
        return cells[index]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Inspector header
            HStack {
                Label("Inspector", systemImage: "info.circle")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            
            Divider()
            
            if let cell = selectedCell, let index = selectedCellIndex {
                InspectorContent(cell: cell, index: index, notebook: notebook)
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    
                    VStack(spacing: 8) {
                        Text("No Selection")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Select a cell to view details")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(.regularMaterial)
    }
}

// MARK: - Inspector Content

struct InspectorContent: View {
    let cell: JupyterCell
    let index: Int
    let notebook: JupyterNotebook
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Cell overview
                InspectorSection("Overview") {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "Type", value: cell.cellType.capitalized)
                        InfoRow(label: "Index", value: "\(index + 1)")
                        InfoRow(label: "Lines", value: "\(cell.source.count)")
                        
                        if let executionCount = cell.executionCount {
                            InfoRow(label: "Execution", value: "\(executionCount)")
                        }
                        
                        if let outputs = cell.outputs {
                            InfoRow(label: "Outputs", value: "\(outputs.count)")
                        }
                    }
                }
                
                // Spatial information
                if hasSpatialData {
                    InspectorSection("Spatial") {
                        Text("This cell contains spatial positioning data")
                            .font(.subheadline)
                            .foregroundStyle(.purple)
                    }
                }
                
                // Statistics
                InspectorSection("Statistics") {
                    VStack(alignment: .leading, spacing: 8) {
                        let totalChars = cell.source.joined().count
                        InfoRow(label: "Characters", value: "\(totalChars)")
                        
                        let nonEmptyLines = cell.source.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
                        InfoRow(label: "Code Lines", value: "\(nonEmptyLines)")
                        
                        if let metadata = cell.metadata {
                            InfoRow(label: "Metadata Fields", value: "\(metadata.count)")
                        }
                    }
                }
            }
            .padding(16)
        }
    }
    
    private var hasSpatialData: Bool {
        guard let metadata = cell.metadata else { return false }
        return metadata.keys.contains { key in
            key.lowercased().contains("spatial")
        }
    }
}

// MARK: - Inspector Section

struct InspectorSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            content
                .padding(12)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    // Simplified preview for better performance
    let sampleCells = [
        JupyterCell(
            cellType: "markdown",
            source: ["# Sample Notebook", "This is a demo notebook with spatial data."],
            metadata: ["tags": AnyCodable(["demo"])],
            outputs: nil,
            executionCount: nil
        ),
        JupyterCell(
            cellType: "code",
            source: ["import pandas as pd", "df = pd.read_csv('data.csv')", "df.head()"],
            metadata: [
                "spatialData": AnyCodable([
                    "position": ["x": 1.0, "y": 2.0, "z": 0.0],
                    "visualizationType": "dataTable"
                ])
            ],
            outputs: [
                JupyterCellOutput(
                    outputType: "stream",
                    text: ["Sample output"],
                    data: nil,
                    executionCount: 1
                )
            ],
            executionCount: 1
        )
    ]
    
    let sampleContent = JupyterNotebookContent(
        cells: sampleCells,
        metadata: ["kernelspec": AnyCodable(["name": "python3"])],
        nbformat: 4,
        nbformatMinor: 2
    )
    
    let sampleNotebook = JupyterNotebook(
        name: "sample_notebook.ipynb",
        path: "sample_notebook.ipynb",
        type: "notebook",
        size: 2048,
        lastModified: Date(),
        content: sampleContent
    )
    
    return NotebookCellViewer(notebook: sampleNotebook)
        .frame(width: 1400, height: 900)
}
