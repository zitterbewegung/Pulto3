//
//  NotebookCellViewer.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/19/25.
//  Copyright 2025 Apple. All rights reserved.
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
        NavigationSplitView {
            // Sidebar with cell list
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            
                            Text("Cells")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Text(notebook.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                Divider()
                
                // Controls
                VStack(alignment: .leading, spacing: 12) {
                    Text("Display Options")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("Spatial Data", isOn: $showingSpatialData)
                            Spacer()
                        }
                        
                        HStack {
                            Toggle("Metadata", isOn: $showingMetadata)
                            Spacer()
                        }
                        
                        HStack {
                            Toggle("Inspector", isOn: $showingInspector)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Divider()
                    .padding(.top, 16)
                
                // Cell list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if let cells = notebook.content?.cells {
                            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                                CellListItem(
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
                    .padding(.vertical, 12)
                }
                
                Spacer()
            }
            .frame(minWidth: 280, maxWidth: 320)
            .background(.regularMaterial)
        } detail: {
            // Main content area with inspector
            HStack(spacing: 0) {
                // Main content
                Group {
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
                        // Empty state
                        VStack(spacing: 24) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 64))
                                .foregroundStyle(.tertiary)
                            
                            VStack(spacing: 8) {
                                Text("Select a Cell")
                                    .font(.title)
                                    .fontWeight(.semibold)
                                
                                Text("Choose a cell from the sidebar to view its content and spatial metadata.")
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Inspector panel
                if showingInspector {
                    InspectorView(
                        notebook: notebook,
                        selectedCellIndex: selectedCellIndex
                    )
                    .frame(width: 320)
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .navigationTitle("Notebook Viewer")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingInspector.toggle()
                    }
                }) {
                    Image(systemName: showingInspector ? "sidebar.right" : "sidebar.left")
                        .font(.title3)
                }
            }
        }
        .onAppear {
            // Auto-select first cell if available
            if selectedCellIndex == nil, let cells = notebook.content?.cells, !cells.isEmpty {
                selectedCellIndex = 0
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingInspector)
    }
    
    private func hasSpatialData(cell: JupyterCell) -> Bool {
        guard let metadata = cell.metadata else { return false }
        return metadata.keys.contains { key in
            key.lowercased().contains("spatial") || key == "spatialData"
        }
    }
}

// MARK: - Cell List Item

struct CellListItem: View {
    let cell: JupyterCell
    let index: Int
    let isSelected: Bool
    let hasSpatialData: Bool
    let onTap: () -> Void
    
    private var cellTypeIcon: String {
        switch cell.cellType {
        case "code":
            return "curlybraces"
        case "markdown":
            return "doc.text"
        case "raw":
            return "doc.plaintext"
        default:
            return "doc"
        }
    }
    
    private var cellTypeColor: Color {
        switch cell.cellType {
        case "code":
            return .blue
        case "markdown":
            return .green
        case "raw":
            return .orange
        default:
            return .secondary
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Cell type icon
                VStack {
                    Image(systemName: cellTypeIcon)
                        .font(.title3)
                        .foregroundStyle(cellTypeColor)
                        .frame(width: 24, height: 24)
                    
                    if hasSpatialData {
                        Image(systemName: "cube")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                }
                .frame(width: 32)
                
                // Cell info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Cell \(index + 1)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Text(cell.cellType.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(cellTypeColor.opacity(0.2))
                            .foregroundStyle(cellTypeColor)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    // Preview of cell content
                    if !cell.source.isEmpty {
                        let preview = cell.source.joined(separator: " ")
                            .prefix(50)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        Text(preview + (preview.count >= 50 ? "..." : ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Execution count for code cells
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
            .background(isSelected ? .blue.opacity(0.1) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? .blue : .clear, lineWidth: 1)
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
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: cellTypeIcon)
                            .font(.title2)
                            .foregroundStyle(cellTypeColor)
                        
                        Text("Cell \(index + 1) - \(cell.cellType.capitalized)")
                            .font(.title)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if cell.cellType == "code", let executionCount = cell.executionCount {
                            Text("[\(executionCount)]")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    
                    Divider()
                }
                
                // Cell source content
                VStack(alignment: .leading, spacing: 12) {
                    Text("Source")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if !cell.source.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(cell.source.enumerated()), id: \.offset) { lineIndex, line in
                                HStack(alignment: .top, spacing: 12) {
                                    // Line number
                                    Text("\(lineIndex + 1)")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                        .frame(minWidth: 20, alignment: .trailing)
                                    
                                    // Source line
                                    Text(line.isEmpty ? " " : line)
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("(Empty cell)")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                
                // Cell outputs
                if let outputs = cell.outputs, !outputs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Outputs")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        ForEach(Array(outputs.enumerated()), id: \.offset) { outputIndex, output in
                            CellOutputView(output: output, index: outputIndex)
                        }
                    }
                }
                
                // Spatial data
                if showingSpatialData {
                    SpatialDataView(cell: cell)
                }
                
                // Metadata
                if showingMetadata, let metadata = cell.metadata, !metadata.isEmpty {
                    MetadataView(metadata: metadata)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .background(.ultraThinMaterial)
    }
    
    private var cellTypeIcon: String {
        switch cell.cellType {
        case "code":
            return "curlybraces"
        case "markdown":
            return "doc.text"
        case "raw":
            return "doc.plaintext"
        default:
            return "doc"
        }
    }
    
    private var cellTypeColor: Color {
        switch cell.cellType {
        case "code":
            return .blue
        case "markdown":
            return .green
        case "raw":
            return .orange
        default:
            return .secondary
        }
    }
}

// MARK: - Cell Output View

struct CellOutputView: View {
    let output: JupyterCellOutput
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Output \(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(output.outputType)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.2))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            // Text output
            if let text = output.text {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(text.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Data output
            if let data = output.data {
                DataOutputView(data: data)
            }
            
            // Execution count
            if let executionCount = output.executionCount {
                Text("Execution count: \(executionCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Data Output View

struct DataOutputView: View {
    let data: [String: AnyCodable]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data Output")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ForEach(Array(data.keys.sorted()), id: \.self) { key in
                VStack(alignment: .leading, spacing: 4) {
                    Text(key)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    if key.contains("text/plain") {
                        if let textArray = data[key]?.value as? [String] {
                            ForEach(Array(textArray.enumerated()), id: \.offset) { _, text in
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
                        Text("Image data (\(key.components(separatedBy: "/").last ?? "unknown"))")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    } else {
                        Text(String(describing: data[key]?.value))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(3)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

// MARK: - Spatial Data View

struct SpatialDataView: View {
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
                HStack {
                    Image(systemName: "cube")
                        .foregroundStyle(.purple)
                    Text("Spatial Data")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(spatialMetadata.keys.sorted()), id: \.self) { key in
                        SpatialDataItem(key: key, value: spatialMetadata[key])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.purple.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.purple.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Spatial Data Item

struct SpatialDataItem: View {
    let key: String
    let value: Any?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.purple)
            
            if let dict = value as? [String: Any] {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(dict.keys.sorted()), id: \.self) { subKey in
                        HStack {
                            Text("\(subKey):")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(formatValue(dict[subKey]))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.leading, 12)
            } else {
                Text(formatValue(value))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(.leading, 12)
            }
        }
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

// MARK: - Metadata View

struct MetadataView: View {
    let metadata: [String: AnyCodable]
    
    private var nonSpatialMetadata: [String: AnyCodable] {
        return metadata.filter { key, _ in
            !key.lowercased().contains("spatial")
        }
    }
    
    var body: some View {
        if !nonSpatialMetadata.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("Metadata")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(nonSpatialMetadata.keys.sorted()), id: \.self) { key in
                        MetadataItem(key: key, value: nonSpatialMetadata[key]?.value)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.blue.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Metadata Item

struct MetadataItem: View {
    let key: String
    let value: Any?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(key):")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.blue)
                .frame(minWidth: 80, alignment: .leading)
            
            Text(formatValue(value))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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

// MARK: - Inspector View

struct InspectorView: View {
    let notebook: JupyterNotebook
    let selectedCellIndex: Int?
    
    private var selectedCell: JupyterCell? {
        guard let index = selectedCellIndex,
              let cells = notebook.content?.cells,
              index < cells.count else { return nil }
        return cells[index]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Inspector header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        
                        Text("Inspector")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    if let cell = selectedCell, let index = selectedCellIndex {
                        Text("Cell \(index + 1) - \(cell.cellType.capitalized)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No cell selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
            
            // Inspector content
            ScrollView {
                if let cell = selectedCell {
                    VStack(alignment: .leading, spacing: 20) {
                        // Cell overview
                        CellOverviewSection(cell: cell, index: selectedCellIndex ?? 0)
                        
                        // Spatial positioning
                        SpatialPositioningSection(cell: cell)
                        
                        // Execution details
                        ExecutionDetailsSection(cell: cell)
                        
                        // Output summary
                        OutputSummarySection(cell: cell)
                        
                        // Metadata summary
                        MetadataSummarySection(cell: cell)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                } else {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        
                        VStack(spacing: 8) {
                            Text("No Cell Selected")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Select a cell to view its details in the inspector.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 20)
                }
            }
            
            Spacer()
        }
        .background(.regularMaterial)
    }
}

// MARK: - Inspector Sections

struct CellOverviewSection: View {
    let cell: JupyterCell
    let index: Int
    
    private var cellTypeIcon: String {
        switch cell.cellType {
        case "code": return "curlybraces"
        case "markdown": return "doc.text"
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: cellTypeIcon)
                        .foregroundStyle(cellTypeColor)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(cell.cellType.capitalized)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "number")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Index")
                            .font(.caption)
                            .ForegroundStyle(.secondary)
                        Text("\(index + 1)")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lines")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(cell.source.count)")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
                
                if !cell.source.isEmpty {
                    let totalChars = cell.source.joined().count
                    HStack {
                        Image(systemName: "textformat.size")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Characters")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(totalChars)")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SpatialPositioningSection: View {
    let cell: JupyterCell
    
    private var spatialData: [String: Any]? {
        guard let metadata = cell.metadata else { return nil }
        for (key, value) in metadata {
            if key.lowercased().contains("spatial") {
                return value.value as? [String: Any]
            }
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cube")
                    .foregroundStyle(.purple)
                Text("Spatial Positioning")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            if let spatial = spatialData {
                VStack(alignment: .leading, spacing: 8) {
                    // Position coordinates
                    if let position = spatial["position"] as? [String: Any] {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Position")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.purple)
                            
                            HStack(spacing: 16) {
                                AxisValue(label: "X", value: position["x"])
                                AxisValue(label: "Y", value: position["y"])
                                AxisValue(label: "Z", value: position["z"])
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rotation")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.purple)
                            
                            HStack(spacing: 16) {
                                AxisValue(label: "X", value: position["rotationX"])
                                AxisValue(label: "Y", value: position["rotationY"])
                                AxisValue(label: "Z", value: position["rotationZ"])
                            }
                        }
                    }
                    
                    // Visualization type
                    if let vizType = spatial["visualizationType"] as? String {
                        HStack {
                            Image(systemName: "eye")
                                .foregroundStyle(.purple)
                                .frame(width: 16)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Visualization")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(vizType)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    // Volumetric data
                    if let volumetric = spatial["volumetricData"] as? [String: Any] {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Volumetric Data")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.purple)
                            
                            HStack(spacing: 16) {
                                AxisValue(label: "W", value: volumetric["width"])
                                AxisValue(label: "H", value: volumetric["height"])
                                AxisValue(label: "D", value: volumetric["depth"])
                            }
                            
                            if let modelURL = volumetric["modelURL"] as? String, !modelURL.isEmpty {
                                HStack {
                                    Image(systemName: "link")
                                        .foregroundStyle(.purple)
                                        .frame(width: 16)
                                    
                                    Text("Model URL")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                HStack {
                    Image(systemName: "cube.transparent")
                        .foregroundStyle(.tertiary)
                    Text("No spatial data")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct AxisValue: View {
    let label: String
    let value: Any?
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(formatValue(value))
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .frame(minWidth: 40)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    private func formatValue(_ value: Any?) -> String {
        if let number = value as? NSNumber {
            return String(format: "%.1f", number.doubleValue)
        } else if let double = value as? Double {
            return String(format: "%.1f", double)
        } else if let float = value as? Float {
            return String(format: "%.1f", float)
        }
        return "0.0"
    }
}

struct ExecutionDetailsSection: View {
    let cell: JupyterCell
    
    var body: some View {
        if cell.cellType == "code" {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "play.circle")
                        .foregroundStyle(.green)
                    Text("Execution")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "number.circle")
                            .foregroundStyle(.green)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Execution Count")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(cell.executionCount.map(String.init) ?? "Not executed")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                    }
                    
                    if let outputs = cell.outputs {
                        HStack {
                            Image(systemName: "terminal")
                                .foregroundStyle(.green)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Outputs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(outputs.count)")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct OutputSummarySection: View {
    let cell: JupyterCell
    
    var body: some View {
        if let outputs = cell.outputs, !outputs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.text.below.ecg")
                        .foregroundStyle(.blue)
                    Text("Outputs")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(outputs.enumerated()), id: \.offset) { index, output in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 20, alignment: .leading)
                            
                            Text(output.outputType)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.2))
                                .foregroundStyle(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            
                            Spacer()
                            
                            if let text = output.text {
                                Text("\(text.joined().count) chars")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct MetadataSummarySection: View {
    let cell: JupyterCell
    
    private var metadataCount: Int {
        cell.metadata?.count ?? 0
    }
    
    private var hasImportantMetadata: Bool {
        guard let metadata = cell.metadata else { return false }
        return metadata.keys.contains { key in
            !key.lowercased().contains("spatial") && key != "collapsed" && key != "scrolled"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag")
                    .foregroundStyle(.orange)
                Text("Metadata")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "number.circle")
                        .foregroundStyle(.orange)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Fields")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(metadataCount)")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
                
                if hasImportantMetadata {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.orange)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Has Custom Data")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Yes")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                    }
                } else {
                    HStack {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.tertiary)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Has Custom Data")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("No")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    let sampleCells = [
        // Markdown cell with basic content
        JupyterCell(
            cellType: "markdown",
            source: [
                "# Data Analysis Notebook",
                "",
                "This notebook demonstrates spatial data visualization capabilities.",
                "",
                "## Overview",
                "- Import and process CSV data",
                "- Create interactive visualizations", 
                "- Position charts in 3D space"
            ],
            metadata: [
                "tags": AnyCodable(["intro", "overview"]),
                "collapsed": AnyCodable(false)
            ],
            outputs: nil,
            executionCount: nil
        ),
        
        // Code cell with spatial positioning data
        JupyterCell(
            cellType: "code",
            source: [
                "import pandas as pd",
                "import matplotlib.pyplot as plt",
                "import numpy as np",
                "",
                "# Load the dataset",
                "df = pd.read_csv('sales_data.csv')",
                "print(f\"Dataset shape: {df.shape}\")",
                "print(f\"Columns: {list(df.columns)}\")",
                "",
                "# Display first few rows",
                "df.head()"
            ],
            metadata: [
                "collapsed": AnyCodable(false),
                "scrolled": AnyCodable(false),
                "tags": AnyCodable(["data-loading", "pandas"]),
                "spatialData": AnyCodable([
                    "position": [
                        "x": 1.5,
                        "y": 2.0,
                        "z": 0.5,
                        "rotationX": 0.0,
                        "rotationY": 15.0,
                        "rotationZ": 0.0
                    ],
                    "visualizationType": "dataTable",
                    "volumetricData": [
                        "width": 1.2,
                        "height": 0.8,
                        "depth": 0.3
                    ]
                ])
            ],
            outputs: [
                JupyterCellOutput(
                    outputType: "stream",
                    text: [
                        "Dataset shape: (1000, 5)",
                        "Columns: ['date', 'product', 'sales', 'region', 'category']"
                    ],
                    data: nil,
                    executionCount: 1
                ),
                JupyterCellOutput(
                    outputType: "execute_result",
                    text: nil,
                    data: [
                        "text/plain": AnyCodable([
                            "         date    product  sales region   category",
                            "0  2024-01-01  Widget A    150   North  Electronics",
                            "1  2024-01-02  Widget B    200   South      Tools",
                            "2  2024-01-03  Widget C    175    East  Electronics",
                            "3  2024-01-04  Widget D    300    West      Tools",
                            "4  2024-01-05  Widget E    125   North  Electronics"
                        ]),
                        "text/html": AnyCodable("<div><table>...</table></div>")
                    ],
                    executionCount: 1
                )
            ],
            executionCount: 1
        ),
        
        // Code cell with chart creation and 3D positioning
        JupyterCell(
            cellType: "code",
            source: [
                "# Create sales trend visualization",
                "plt.figure(figsize=(12, 8))",
                "plt.subplot(2, 2, 1)",
                "",
                "# Sales by region",
                "region_sales = df.groupby('region')['sales'].sum()",
                "plt.bar(region_sales.index, region_sales.values)",
                "plt.title('Sales by Region')",
                "plt.xlabel('Region')",
                "plt.ylabel('Total Sales')",
                "",
                "# Sales trend over time",
                "plt.subplot(2, 2, 2)",
                "daily_sales = df.groupby('date')['sales'].sum()",
                "plt.plot(daily_sales.index, daily_sales.values, marker='o')",
                "plt.title('Daily Sales Trend')",
                "plt.xticks(rotation=45)",
                "",
                "plt.tight_layout()",
                "plt.show()"
            ],
            metadata: [
                "tags": AnyCodable(["visualization", "matplotlib"]),
                "spatialData": AnyCodable([
                    "position": [
                        "x": -1.0,
                        "y": 1.5,
                        "z": 1.2,
                        "rotationX": 10.0,
                        "rotationY": -20.0,
                        "rotationZ": 5.0
                    ],
                    "visualizationType": "chart2D",
                    "volumetricData": [
                        "width": 1.8,
                        "height": 1.2,
                        "depth": 0.1
                    ]
                ])
            ],
            outputs: [
                JupyterCellOutput(
                    outputType: "display_data",
                    text: nil,
                    data: [
                        "image/png": AnyCodable("iVBORw0KGgoAAAANSUhEUgAAA..."), // Base64 image data
                        "text/plain": AnyCodable(["<Figure size 1200x800 with 2 Axes>"])
                    ],
                    executionCount: 2
                )
            ],
            executionCount: 2
        ),
        
        // Code cell with 3D point cloud visualization
        JupyterCell(
            cellType: "code",
            source: [
                "# Create 3D point cloud visualization",
                "import plotly.graph_objects as go",
                "from sklearn.decomposition import PCA",
                "",
                "# Prepare data for 3D visualization",
                "# Encode categorical variables",
                "from sklearn.preprocessing import LabelEncoder",
                "",
                "le_product = LabelEncoder()",
                "le_region = LabelEncoder()",
                "le_category = LabelEncoder()",
                "",
                "df_encoded = df.copy()",
                "df_encoded['product_encoded'] = le_product.fit_transform(df['product'])",
                "df_encoded['region_encoded'] = le_region.fit_transform(df['region'])",
                "df_encoded['category_encoded'] = le_category.fit_transform(df['category'])",
                "",
                "# Create 3D scatter plot",
                "fig = go.Figure(data=go.Scatter3d(",
                "    x=df_encoded['product_encoded'],",
                "    y=df_encoded['region_encoded'],", 
                "    z=df_encoded['sales'],",
                "    mode='markers',",
                "    marker=dict(",
                "        size=8,",
                "        color=df_encoded['category_encoded'],",
                "        colorscale='Viridis',",
                "        showscale=True,",
                "        opacity=0.8",
                "    ),",
                "    text=df['product'],",
                "    hovertemplate='<b>%{text}</b><br>' +",
                "                  'Sales: %{z}<br>' +",
                "                  '<extra></extra>'",
                "))",
                "",
                "fig.update_layout(",
                "    title='3D Sales Data Visualization',",
                "    scene=dict(",
                "        xaxis_title='Product',",
                "        yaxis_title='Region',",
                "        zaxis_title='Sales'",
                "    ),",
                "    width=900,",
                "    height=700",
                ")",
                "",
                "fig.show()",
                "print(f'Generated 3D visualization with {len(df)} data points')"
            ],
            metadata: [
                "tags": AnyCodable(["3d-viz", "plotly", "point-cloud"]),
                "spatialData": AnyCodable([
                    "position": [
                        "x": 2.5,
                        "y": 0.0,
                        "z": 2.0,
                        "rotationX": 0.0,
                        "rotationY": 45.0,
                        "rotationZ": 0.0
                    ],
                    "visualizationType": "pointCloud3D",
                    "volumetricData": [
                        "width": 2.0,
                        "height": 1.5,
                        "depth": 1.5,
                        "modelURL": nil,
                        "pointCloudData": "eyJ0eXBlIjoicG9pbnRDbG91ZCIsImRhdGEiOiJiYXNlNjRfZW5jb2RlZF9kYXRhIn0=" // Sample base64
                    ]
                ])
            ],
            outputs: [
                JupyterCellOutput(
                    outputType: "display_data",
                    text: nil,
                    data: [
                        "application/vnd.plotly.v1+json": AnyCodable([
                            "data": [
                                [
                                    "type": "scatter3d",
                                    "mode": "markers"
                                ]
                            ],
                            "layout": [
                                "title": "3D Sales Data Visualization"
                            ]
                        ])
                    ],
                    executionCount: 3
                ),
                JupyterCellOutput(
                    outputType: "stream",
                    text: ["Generated 3D visualization with 1000 data points"],
                    data: nil,
                    executionCount: 3
                )
            ],
            executionCount: 3
        ),
        
        // Raw cell without spatial data
        JupyterCell(
            cellType: "raw",
            source: [
                "Raw data export for external processing:",
                "",
                "Total records: 1000",
                "Date range: 2024-01-01 to 2024-12-31",
                "Regions: North, South, East, West",
                "Categories: Electronics, Tools",
                "",
                "Export format: CSV",
                "Encoding: UTF-8",
                "Delimiter: comma"
            ],
            metadata: [
                "format": AnyCodable("text/plain"),
                "tags": AnyCodable(["raw-data", "export"])
            ],
            outputs: nil,
            executionCount: nil
        ),
        
        // Code cell with volumetric 3D model
        JupyterCell(
            cellType: "code",
            source: [
                "# Load and display 3D model for spatial visualization",
                "import trimesh",
                "import base64",
                "",
                "# Load 3D model (example: sales performance visualization as 3D bars)",
                "model_path = 'sales_3d_model.obj'",
                "",
                "try:",
                "    mesh = trimesh.load(model_path)",
                "    print(f'Loaded 3D model: {mesh.vertices.shape[0]} vertices, {mesh.faces.shape[0]} faces')",
                "    print(f'Bounding box: {mesh.bounds}')",
                "    ",
                "    # Export for spatial rendering",
                "    model_data = {",
                "        'vertices': mesh.vertices.tolist(),",
                "        'faces': mesh.faces.tolist(),",
                "        'bounds': mesh.bounds.tolist(),",
                "        'volume': float(mesh.volume)",
                "    }",
                "    ",
                "    print('Model ready for volumetric display')",
                "    ",
                "except FileNotFoundError:",
                "    print('3D model file not found - using procedural geometry')",
                "    # Create simple procedural 3D bars for demo",
                "    print('Generated procedural 3D visualization')"
            ],
            metadata: [
                "tags": AnyCodable(["3d-model", "volumetric", "trimesh"]),
                "spatialData": AnyCodable([
                    "position": [
                        "x": 0.0,
                        "y": -1.5,
                        "z": 1.8,
                        "rotationX": 15.0,
                        "rotationY": 0.0,
                        "rotationZ": -10.0
                    ],
                    "visualizationType": "volumetric3D",
                    "volumetricData": [
                        "width": 1.5,
                        "height": 2.0,
                        "depth": 1.0,
                        "modelURL": "file:///path/to/sales_3d_model.obj",
                        "pointCloudData": nil
                    ]
                ])
            ],
            outputs: [
                JupyterCellOutput(
                    outputType: "stream",
                    text: [
                        "3D model file not found - using procedural geometry",
                        "Generated procedural 3D visualization"
                    ],
                    data: nil,
                    executionCount: 4
                ),
                JupyterCellOutput(
                    outputType: "display_data",
                    text: nil,
                    data: [
                        "application/vnd.pulto.spatial+json": AnyCodable([
                            "type": "model3d",
                            "data": "eyJ2ZXJ0aWNlcyI6W10sImZhY2VzIjpbXX0=", // Base64 encoded model
                            "metadata": [
                                "format": "obj",
                                "volumetric": true
                            ]
                        ])
                    ],
                    executionCount: 4
                )
            ],
            executionCount: 4
        ),
        
        // Final markdown summary cell
        JupyterCell(
            cellType: "markdown",
            source: [
                "## Summary",
                "",
                "This notebook demonstrated spatial data visualization with the following views:",
                "",
                "1. **Data Table** - Located at position (1.5, 2.0, 0.5) with 15° Y rotation",
                "2. **2D Charts** - Multiple charts at (-1.0, 1.5, 1.2) with custom orientation", 
                "3. **3D Point Cloud** - Interactive 3D scatter at (2.5, 0.0, 2.0) with 45° Y rotation",
                "4. **Volumetric Model** - 3D model visualization at (0.0, -1.5, 1.8)",
                "",
                "### Spatial Layout",
                "All visualizations are positioned in 3D space for immersive exploration in visionOS.",
                "",
                "### Next Steps",
                "- Adjust spatial positions for optimal viewing",
                "- Add more interactive elements",
                "- Export to spatial workspace"
            ],
            metadata: [
                "tags": AnyCodable(["summary", "conclusion"]),
                "collapsed": AnyCodable(false)
            ],
            outputs: nil,
            executionCount: nil
        )
    ]
    
    // Create notebook content with comprehensive metadata
    let sampleContent = JupyterNotebookContent(
        cells: sampleCells,
        metadata: [
            "kernelspec": AnyCodable([
                "display_name": "Python 3 (Spatial)",
                "language": "python", 
                "name": "python3-spatial"
            ]),
            "language_info": AnyCodable([
                "name": "python",
                "version": "3.11.0",
                "codemirror_mode": [
                    "name": "ipython",
                    "version": 3
                ]
            ]),
            "pulto_spatial": AnyCodable([
                "version": "1.0",
                "spatial_cells": 4,
                "export_date": "2024-01-15T10:30:00Z",
                "workspace_bounds": [
                    "min_x": -2.0,
                    "max_x": 3.0,
                    "min_y": -2.0, 
                    "max_y": 3.0,
                    "min_z": 0.0,
                    "max_z": 2.5
                ]
            ]),
            "authors": AnyCodable(["Data Science Team"]),
            "title": AnyCodable("Spatial Data Analysis Demo"),
            "description": AnyCodable("Comprehensive demonstration of spatial data visualization capabilities")
        ],
        nbformat: 4,
        nbformatMinor: 5
    )
    
    // Create the complete notebook
    let sampleNotebook = JupyterNotebook(
        name: "spatial_analysis_demo.ipynb",
        path: "notebooks/spatial_analysis_demo.ipynb",
        type: "notebook",
        size: 45678, // ~45KB
        lastModified: Calendar.current.date(byAdding: .hour, value: -2, to: Date()), // 2 hours ago
        content: sampleContent
    )
    
    return NotebookCellViewer(notebook: sampleNotebook)
        .frame(width: 1400, height: 900)
        .previewDisplayName("Notebook Cell Viewer - Full Demo")
}

#Preview("Minimal Notebook") {
    // Simpler preview with just a few cells
    let minimalCells = [
        JupyterCell(
            cellType: "markdown", 
            source: ["# Quick Demo", "Simple notebook example"],
            metadata: nil,
            outputs: nil,
            executionCount: nil
        ),
        JupyterCell(
            cellType: "code",
            source: ["print('Hello, spatial world!')", "x = 42"],
            metadata: [
                "spatialData": AnyCodable([
                    "position": ["x": 0.0, "y": 0.0, "z": 0.0, "rotationX": 0.0, "rotationY": 0.0, "rotationZ": 0.0],
                    "visualizationType": "simple"
                ])
            ],
            outputs: [
                JupyterCellOutput(
                    outputType: "stream",
                    text: ["Hello, spatial world!"],
                    data: nil,
                    executionCount: 1
                )
            ],
            executionCount: 1
        )
    ]
    
    let minimalContent = JupyterNotebookContent(
        cells: minimalCells,
        metadata: ["kernelspec": AnyCodable(["name": "python3"])],
        nbformat: 4,
        nbformatMinor: 2
    )
    
    let minimalNotebook = JupyterNotebook(
        name: "quick_demo.ipynb",
        path: "quick_demo.ipynb", 
        type: "notebook",
        size: 1234,
        lastModified: Date(),
        content: minimalContent
    )
    
    return NotebookCellViewer(notebook: minimalNotebook)
        .frame(width: 1200, height: 700)
        .previewDisplayName("Minimal Demo")
}

#Preview("Empty Notebook") {
    // Preview with empty notebook to test empty states
    let emptyContent = JupyterNotebookContent(
        cells: [],
        metadata: [:],
        nbformat: 4,
        nbformatMinor: 2
    )
    
    let emptyNotebook = JupyterNotebook(
        name: "empty.ipynb",
        path: "empty.ipynb",
        type: "notebook", 
        size: 100,
        lastModified: Date(),
        content: emptyContent
    )
    
    return NotebookCellViewer(notebook: emptyNotebook)
        .frame(width: 1000, height: 600)
        .previewDisplayName("Empty Notebook")
}
