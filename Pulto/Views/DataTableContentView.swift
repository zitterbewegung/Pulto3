//
//  DataTableContentView.swift
//  Pulto
//
//  Created by Joshua Herman on 6/16/25.
//  Copyright © 2025 Apple. All rights reserved.
//
import SwiftUI

// Enhanced DataFrame viewer with spreadsheet-like appearance - Cross-platform version
struct DataTableContentView: View {

    let windowID: Int?
    let initialDataFrame: DataFrameData?

    // use an existing frame, a window-saved frame, or fall back to a sample
    init(windowID: Int? = nil, initialDataFrame: DataFrameData? = nil) {
        self.windowID = windowID
        self.initialDataFrame = initialDataFrame
        let seed = initialDataFrame ?? Self.defaultSample()
        _sampleData = State(initialValue: seed)
    }

    @StateObject private var windowManager = WindowTypeManager.shared
    @State private var sampleData = DataFrameData(
        columns: ["Name", "Age", "City", "Salary"],
        rows: [
            ["Alice", "28", "New York", "75000"],
            ["Bob", "35", "San Francisco", "95000"],
            ["Charlie", "42", "Austin", "68000"],
            ["Diana", "31", "Seattle", "82000"]
        ],
        dtypes: ["Name": "string", "Age": "int", "City": "string", "Salary": "float"]
    )
    @State private var editingData = false
    @State private var selectedCell: (row: Int, col: Int)? = nil
    @State private var hoveredCell: (row: Int, col: Int)? = nil
    @State private var sortColumn: String? = nil
    @State private var sortAscending = true

    // Column widths
    @State private var columnWidths: [String: CGFloat] = [:]

    // Platform-specific colors
    #if os(macOS)
    let backgroundColor = Color(NSColor.controlBackgroundColor)
    let windowBackgroundColor = Color(NSColor.windowBackgroundColor)
    let textBackgroundColor = Color(NSColor.textBackgroundColor)
    let separatorColor = Color(NSColor.separatorColor)
    let gridColor = Color(NSColor.gridColor)
    let alternatingRowColor = Color(NSColor.alternatingContentBackgroundColors[1])
    let selectedContentColor = Color(NSColor.selectedContentBackgroundColor)
    #else
    let backgroundColor = Color(UIColor.systemGroupedBackground)
    let windowBackgroundColor = Color(UIColor.systemBackground)
    let textBackgroundColor = Color(UIColor.systemBackground)
    let separatorColor = Color(UIColor.separator)
    let gridColor = Color(UIColor.systemGray5)
    let alternatingRowColor = Color(UIColor.secondarySystemBackground)
    let selectedContentColor = Color(UIColor.systemGray3)
    #endif

    // Static method to provide default sample data
    static func defaultSample() -> DataFrameData {
        return DataFrameData(
            columns: ["Name", "Age", "City", "Salary"],
            rows: [
                ["Alice", "28", "New York", "75000"],
                ["Bob", "35", "San Francisco", "95000"],
                ["Charlie", "42", "Austin", "68000"],
                ["Diana", "31", "Seattle", "82000"]
            ],
            dtypes: ["Name": "string", "Age": "int", "City": "string", "Salary": "float"]
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbarView

            // Main content
            if editingData {
                dataEditorView
            } else {
                spreadsheetView
            }

            // Status bar
            statusBarView
        }
        .background(backgroundColor)
        .onAppear {
            loadDataFromWindow()
            initializeColumnWidths()
        }
    }

    // ... rest of your methods remain the same

    private var toolbarView: some View {
        HStack(spacing: 16) {
            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text("DataFrame")
                    .font(.headline)
                Text("\(sampleData.shapeRows) rows × \(sampleData.shapeColumns) columns")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                Button(action: { loadSampleData() }) {
                    Label("Sample Data", systemImage: "doc.text")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)

                Button(action: { editingData.toggle() }) {
                    Label(editingData ? "Done" : "Edit", systemImage: editingData ? "checkmark.circle" : "pencil")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)

                Button(action: { saveDataToWindow() }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(windowBackgroundColor)
    }

    private var spreadsheetView: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                // Column headers
                HStack(spacing: 0) {
                    // Row number header
                    Text("#")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                        .padding(.vertical, 8)
                        .background(gridColor.opacity(0.1))
                        .overlay(
                            Rectangle()
                                .stroke(separatorColor, lineWidth: 0.5)
                        )

                    // Column headers
                    ForEach(sampleData.columns, id: \.self) { column in
                        columnHeaderView(column: column)
                    }
                }

                // Data rows
                ForEach(0..<sampleData.rows.count, id: \.self) { rowIndex in
                    HStack(spacing: 0) {
                        // Row number
                        Text("\(rowIndex + 1)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                            .padding(.vertical, 8)
                            .background(gridColor.opacity(0.1))
                            .overlay(
                                Rectangle()
                                    .stroke(separatorColor, lineWidth: 0.5)
                            )

                        // Data cells
                        ForEach(0..<sampleData.columns.count, id: \.self) { colIndex in
                            cellView(rowIndex: rowIndex, colIndex: colIndex)
                        }
                    }
                    .background(rowIndex % 2 == 0 ? Color.clear : alternatingRowColor)
                }
            }
        }
        .background(textBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(separatorColor, lineWidth: 1)
        )
        .padding()
    }

    private func columnHeaderView(column: String) -> some View {
        HStack(spacing: 4) {
            Text(column)
                .font(.system(.caption))
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer(minLength: 0)

            // Sort indicator
            if sortColumn == column {
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            // Data type indicator
            if let dtype = sampleData.dtypes[column] {
                Image(systemName: dtypeIcon(dtype))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(width: columnWidths[column] ?? 120)
        .background(gridColor.opacity(0.1))
        .overlay(
            Rectangle()
                .stroke(separatorColor, lineWidth: 0.5)
        )
        .onTapGesture {
            toggleSort(column: column)
        }
    }

    private func cellView(rowIndex: Int, colIndex: Int) -> some View {
        let value = rowIndex < sampleData.rows.count && colIndex < sampleData.rows[rowIndex].count
            ? sampleData.rows[rowIndex][colIndex]
            : ""
        let column = sampleData.columns[colIndex]
        let isSelected = selectedCell?.row == rowIndex && selectedCell?.col == colIndex
        let isHovered = hoveredCell?.row == rowIndex && hoveredCell?.col == colIndex

        return Text(formatCellValue(value, dtype: sampleData.dtypes[column]))
            .font(.system(.body, design: .monospaced))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(width: columnWidths[column] ?? 120, alignment: cellAlignment(for: sampleData.dtypes[column]))
            .background(
                Group {
                    if isSelected {
                        Color.accentColor.opacity(0.2)
                    } else if isHovered {
                        selectedContentColor.opacity(0.1)
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                Rectangle()
                    .stroke(
                        isSelected ? Color.accentColor : separatorColor,
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
            .onTapGesture {
                selectedCell = (row: rowIndex, col: colIndex)
            }
            .onHover { hovering in
                if hovering {
                    hoveredCell = (row: rowIndex, col: colIndex)
                } else if hoveredCell?.row == rowIndex && hoveredCell?.col == colIndex {
                    hoveredCell = nil
                }
            }
    }

    private var dataEditorView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pencil.line")
                    .foregroundColor(.secondary)
                Text("Edit DataFrame")
                    .font(.headline)
            }

            Text("Paste CSV data below:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: .constant(toCSVString()))
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(textBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(separatorColor, lineWidth: 1)
                )
        }
        .padding()
    }

    private var statusBarView: some View {
        HStack {
            if let selected = selectedCell {
                Label(
                    "Cell: \(sampleData.columns[selected.col]):\(selected.row + 1)",
                    systemImage: "square.dashed"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                Text("Click a cell to select")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let selected = selectedCell {
                let value = sampleData.rows[selected.row][selected.col]
                Text("Value: \(value)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(windowBackgroundColor)
        .overlay(
            Rectangle()
                .fill(separatorColor)
                .frame(height: 0.5),
            alignment: .top
        )
    }

    // Helper functions
    private func initializeColumnWidths() {
        for column in sampleData.columns {
            let dtype = sampleData.dtypes[column] ?? "string"
            switch dtype {
            case "int", "float":
                columnWidths[column] = 100
            case "string":
                columnWidths[column] = 150
            default:
                columnWidths[column] = 120
            }
        }
    }

    private func dtypeIcon(_ dtype: String) -> String {
        switch dtype {
        case "int", "float":
            return "number"
        case "string":
            return "textformat"
        case "bool":
            return "checkmark.square"
        default:
            return "questionmark"
        }
    }

    private func cellAlignment(for dtype: String?) -> Alignment {
        switch dtype {
        case "int", "float":
            return .trailing
        default:
            return .leading
        }
    }

    private func formatCellValue(_ value: String, dtype: String?) -> String {
        guard let dtype = dtype else { return value }

        switch dtype {
        case "float":
            if let number = Double(value) {
                return String(format: "%.2f", number)
            }
        case "int":
            if let number = Int(value) {
                return NumberFormatter.localizedString(from: NSNumber(value: number), number: .decimal)
            }
        default:
            break
        }

        return value
    }

    private func toggleSort(column: String) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
        // Implement sorting logic here
    }

    private func loadDataFromWindow() {
        guard let windowID = windowID,
              let existingData = windowManager.getWindowDataFrame(for: windowID) else {
            return
        }
        sampleData = existingData
    }

    private func saveDataToWindow() {
        guard let windowID = windowID else { return }
        windowManager.updateWindowDataFrame(windowID, dataFrame: sampleData)
    }

    private func loadSampleData() {
        sampleData = DataFrameData(
            columns: ["Product", "Category", "Price", "Quantity", "Revenue"],
            rows: [
                ["iPhone 15", "Electronics", "999.00", "150", "149850.00"],
                ["MacBook Pro", "Electronics", "2399.00", "75", "179925.00"],
                ["AirPods Pro", "Electronics", "249.00", "300", "74700.00"],
                ["iPad Air", "Electronics", "599.00", "120", "71880.00"],
                ["Apple Watch", "Electronics", "399.00", "200", "79800.00"]
            ],
            dtypes: ["Product": "string", "Category": "string", "Price": "float", "Quantity": "int", "Revenue": "float"]
        )
        initializeColumnWidths()

        if let windowID = windowID {
            saveDataToWindow()
        }
    }

    // Helper method to convert to CSV string (if not already defined elsewhere)
    private func toCSVString() -> String {
        var csv = sampleData.columns.joined(separator: ",") + "\n"
        for row in sampleData.rows {
            csv += row.joined(separator: ",") + "\n"
        }
        return csv
    }
}
