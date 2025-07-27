//
//  VirtualizedDataTable.swift
//  Pulto3
//
//  Created by AI Assistant on [Date]
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import Combine

// MARK: - Virtualized Data Table for Large Datasets

struct VirtualizedDataTable: View {
    let dataFrame: DataFrameData
    let windowID: Int?
    
    // Virtualization parameters
    private let visibleRowCount: Int = 50
    private let bufferRows: Int = 10
    private let rowHeight: CGFloat = 32
    
    @StateObject private var viewModel = VirtualizedDataTableViewModel()
    @StateObject private var chunkManager = DataFrameChunkManager()
    @StateObject private var searchManager = DataTableSearchManager()
    
    @State private var scrollOffset: CGFloat = 0
    @State private var visibleRange: Range<Int> = 0..<50
    @State private var filterText: String = ""
    @State private var sortColumn: String? = nil
    @State private var sortAscending: Bool = true
    @State private var selectedRows: Set<Int> = []
    @State private var columnWidths: [String: CGFloat] = [:]
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbarView
            
            Divider()
            
            // Main virtualized content
            GeometryReader { geometry in
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            // Header row
                            headerRowView
                            
                            // Virtualized data rows
                            ForEach(visibleDataRows.indices, id: \.self) { index in
                                let actualRowIndex = visibleRange.lowerBound + index
                                if actualRowIndex < visibleDataRows.count {
                                    dataRowView(
                                        row: visibleDataRows[index],
                                        rowIndex: actualRowIndex,
                                        isSelected: selectedRows.contains(actualRowIndex)
                                    )
                                }
                            }
                            
                            // Loading indicator for more data
                            if chunkManager.isLoading {
                                loadingRowView
                            }
                        }
                        .background(
                            GeometryReader { scrollGeometry in
                                Color.clear
                                    .onAppear {
                                        updateVisibleRange(scrollGeometry: scrollGeometry, containerGeometry: geometry)
                                    }
                                    .onChange(of: scrollGeometry.frame(in: .named("scroll"))) { _, _ in
                                        updateVisibleRange(scrollGeometry: scrollGeometry, containerGeometry: geometry)
                                    }
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .refreshable {
                        await refreshData()
                    }
                }
            }
            
            Divider()
            
            // Status bar
            statusBarView
        }
        .onAppear {
            setupDataTable()
        }
        .onChange(of: filterText) { _, newValue in
            Task {
                await searchManager.search(newValue, in: dataFrame)
            }
        }
        .task {
            await chunkManager.loadInitialData(dataFrame)
        }
    }
    
    // MARK: - Computed Properties
    
    private var visibleDataRows: [[String]] {
        let filteredData = searchManager.isSearching && !searchManager.searchResults.isEmpty
            ? searchManager.searchResults.compactMap { index in
                index < dataFrame.rows.count ? dataFrame.rows[index] : nil
            }
            : dataFrame.rows
        
        let endIndex = min(visibleRange.upperBound, filteredData.count)
        let startIndex = min(visibleRange.lowerBound, endIndex)
        
        return Array(filteredData[startIndex..<endIndex])
    }
    
    private var totalRowCount: Int {
        return searchManager.isSearching ? searchManager.searchResults.count : dataFrame.rows.count
    }
    
    // MARK: - View Components
    
    private var toolbarView: some View {
        HStack(spacing: 16) {
            // Title and stats
            VStack(alignment: .leading, spacing: 2) {
                Text("DataFrame")
                    .font(.headline)
                
                Text("\(totalRowCount) rows × \(dataFrame.columns.count) columns")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Filter data...", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                
                if !filterText.isEmpty {
                    Button(action: { filterText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Actions
            HStack(spacing: 8) {
                Button("Export") {
                    exportData()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Menu("More") {
                    Button("Select All") { selectAllRows() }
                    Button("Clear Selection") { selectedRows.removeAll() }
                    Divider()
                    Button("Refresh Data") { 
                        Task { await refreshData() }
                    }
                    Button("Reset View") { resetView() }
                }
                .menuStyle(.borderlessButton)
                .controlSize(.small)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
    
    private var headerRowView: some View {
        HStack(spacing: 0) {
            // Row selector
            headerCellView("", width: 50, sortable: false) { }
            
            // Column headers
            ForEach(dataFrame.columns, id: \.self) { column in
                headerCellView(
                    column,
                    width: columnWidths[column] ?? 120,
                    sortable: true
                ) {
                    toggleSort(column: column)
                }
            }
        }
        .background(.regularMaterial)
    }
    
    private func headerCellView(
        _ text: String,
        width: CGFloat,
        sortable: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(text)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                if sortable && sortColumn == text {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                if let dtype = dataFrame.dtypes[text] {
                    Image(systemName: dtypeIcon(dtype))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer(minLength: 0)
            }
            .frame(width: width, height: 30)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .background(.quaternary.opacity(0.3))
        .overlay(
            Rectangle()
                .fill(.separator)
                .frame(width: 0.5),
            alignment: .trailing
        )
        .disabled(!sortable)
    }
    
    private func dataRowView(row: [String], rowIndex: Int, isSelected: Bool) -> some View {
        HStack(spacing: 0) {
            // Row selector
            Button(action: { toggleRowSelection(rowIndex) }) {
                HStack {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    } else {
                        Text("\(rowIndex + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 50, height: rowHeight)
            }
            .buttonStyle(.plain)
            .background(isSelected ? .blue.opacity(0.1) : .clear)
            
            // Data cells
            ForEach(0..<dataFrame.columns.count, id: \.self) { colIndex in
                let value = colIndex < row.count ? row[colIndex] : ""
                let column = dataFrame.columns[colIndex]
                
                dataCellView(
                    value: value,
                    column: column,
                    width: columnWidths[column] ?? 120,
                    isSelected: isSelected
                )
            }
        }
        .background(
            Group {
                if isSelected {
                    Color.accentColor.opacity(0.1)
                } else if rowIndex % 2 == 0 {
                    Color.clear
                } else {
                    Color.primary.opacity(0.03)
                }
            }
        )
        .id("row-\(rowIndex)")
    }
    
    private func dataCellView(
        value: String,
        column: String,
        width: CGFloat,
        isSelected: Bool
    ) -> some View {
        Text(formatCellValue(value, dtype: dataFrame.dtypes[column]))
            .font(.caption)
            .foregroundStyle(isSelected ? .primary : colorForDataType(dataFrame.dtypes[column]))
            .lineLimit(1)
            .frame(width: width, height: rowHeight, alignment: alignmentForDataType(dataFrame.dtypes[column]))
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.05) : Color.clear)
            .overlay(
                Rectangle()
                    .fill(.separator)
                    .frame(width: 0.5),
                alignment: .trailing
            )
    }
    
    private var loadingRowView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("Loading more data...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: rowHeight * 2)
        .frame(maxWidth: .infinity)
    }
    
    private var statusBarView: some View {
        HStack {
            // Selection info
            if !selectedRows.isEmpty {
                Text("\(selectedRows.count) row\(selectedRows.count == 1 ? "" : "s") selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No selection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Performance info
            if chunkManager.isLoading {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 12) {
                    Text("Rows \(visibleRange.lowerBound + 1)-\(min(visibleRange.upperBound, totalRowCount)) of \(totalRowCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if searchManager.isSearching {
                        Label("Filtered", systemImage: "line.3.horizontal.decrease.circle")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
    
    // MARK: - Helper Methods
    
    private func setupDataTable() {
        initializeColumnWidths()
        chunkManager.configure(chunkSize: 1000, maxCachedChunks: 10)
    }
    
    private func initializeColumnWidths() {
        for column in dataFrame.columns {
            let dtype = dataFrame.dtypes[column] ?? "string"
            switch dtype {
            case "int", "float":
                columnWidths[column] = 100
            case "string":
                columnWidths[column] = 150
            case "bool":
                columnWidths[column] = 80
            default:
                columnWidths[column] = 120
            }
        }
    }
    
    private func updateVisibleRange(scrollGeometry: GeometryProxy, containerGeometry: GeometryProxy) {
        let scrollOffset = -scrollGeometry.frame(in: .named("scroll")).minY
        let containerHeight = containerGeometry.size.height
        
        let startRow = max(0, Int(scrollOffset / rowHeight) - bufferRows)
        let visibleRows = Int(containerHeight / rowHeight) + 1
        let endRow = min(totalRowCount, startRow + visibleRows + bufferRows * 2)
        
        let newRange = startRow..<endRow
        if newRange != visibleRange {
            visibleRange = newRange
            
            // Load chunks for visible range
            Task {
                await chunkManager.loadChunksForRange(visibleRange)
            }
        }
    }
    
    private func toggleSort(column: String) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
        
        // Clear filter when sorting
        filterText = ""
        
        Task {
            await chunkManager.sortData(by: column, ascending: sortAscending)
        }
    }
    
    private func toggleRowSelection(_ index: Int) {
        if selectedRows.contains(index) {
            selectedRows.remove(index)
        } else {
            selectedRows.insert(index)
        }
    }
    
    private func selectAllRows() {
        selectedRows = Set(0..<totalRowCount)
    }
    
    private func refreshData() async {
        await chunkManager.refreshData(dataFrame)
        selectedRows.removeAll()
        visibleRange = 0..<min(visibleRowCount, totalRowCount)
    }
    
    private func resetView() {
        filterText = ""
        sortColumn = nil
        sortAscending = true
        selectedRows.removeAll()
        visibleRange = 0..<min(visibleRowCount, totalRowCount)
    }
    
    private func exportData() {
        // Export selected rows or all data
        let rowsToExport = selectedRows.isEmpty ? Array(0..<totalRowCount) : Array(selectedRows)
        
        if let windowID = windowID {
            let exportData = DataFrameData(
                columns: dataFrame.columns,
                rows: rowsToExport.compactMap { index in
                    index < dataFrame.rows.count ? dataFrame.rows[index] : nil
                },
                dtypes: dataFrame.dtypes
            )
            
            WindowTypeManager.shared.updateWindowDataFrame(windowID, dataFrame: exportData)
        }
    }
    
    // MARK: - Formatting Helpers
    
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
    
    private func colorForDataType(_ dtype: String?) -> Color {
        switch dtype?.lowercased() {
        case "int", "float":
            return .blue
        case "bool":
            return .green
        case "date", "datetime":
            return .orange
        default:
            return .primary
        }
    }
    
    private func alignmentForDataType(_ dtype: String?) -> Alignment {
        switch dtype?.lowercased() {
        case "int", "float":
            return .trailing
        case "bool":
            return .center
        default:
            return .leading
        }
    }
    
    private func dtypeIcon(_ dtype: String) -> String {
        switch dtype.lowercased() {
        case "int", "float":
            return "number"
        case "string":
            return "textformat"
        case "bool":
            return "checkmark.square"
        case "date", "datetime":
            return "calendar"
        default:
            return "questionmark"
        }
    }
}

// MARK: - Data Management Classes

@MainActor
class VirtualizedDataTableViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var performanceMetrics = PerformanceMetrics()
    
    struct PerformanceMetrics {
        var renderTime: TimeInterval = 0
        var memoryUsage: Int64 = 0
        var visibleRows: Int = 0
    }
}

class DataFrameChunkManager: ObservableObject {
    @Published var loadedChunks: [Int: DataFrameChunk] = [:]
    @Published var totalRows: Int = 0
    @Published var isLoading = false
    
    private var chunkSize = 1000
    private var maxCachedChunks = 10
    private var baseDataFrame: DataFrameData?
    
    struct DataFrameChunk {
        let index: Int
        let rows: [[String]]
        let startIndex: Int
        let endIndex: Int
        let loadedAt: Date
    }
    
    func configure(chunkSize: Int, maxCachedChunks: Int) {
        self.chunkSize = chunkSize
        self.maxCachedChunks = maxCachedChunks
    }
    
    func loadInitialData(_ dataFrame: DataFrameData) async {
        await MainActor.run {
            self.baseDataFrame = dataFrame
            self.totalRows = dataFrame.rows.count
            self.isLoading = false
        }
        
        // Load first chunk
        await loadChunk(0)
    }
    
    func loadChunk(_ index: Int) async {
        guard let dataFrame = baseDataFrame else { return }
        
        await MainActor.run { isLoading = true }
        
        // Simulate loading delay for large datasets
        if dataFrame.rows.count > 10000 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        let startIndex = index * chunkSize
        let endIndex = min(startIndex + chunkSize, dataFrame.rows.count)
        
        guard startIndex < dataFrame.rows.count else {
            await MainActor.run { isLoading = false }
            return
        }
        
        let chunkRows = Array(dataFrame.rows[startIndex..<endIndex])
        let chunk = DataFrameChunk(
            index: index,
            rows: chunkRows,
            startIndex: startIndex,
            endIndex: endIndex,
            loadedAt: Date()
        )
        
        await MainActor.run {
            loadedChunks[index] = chunk
            cleanupOldChunks()
            isLoading = false
        }
    }
    
    func loadChunksForRange(_ range: Range<Int>) async {
        let startChunk = range.lowerBound / chunkSize
        let endChunk = (range.upperBound - 1) / chunkSize
        
        for chunkIndex in startChunk...endChunk {
            if loadedChunks[chunkIndex] == nil {
                await loadChunk(chunkIndex)
            }
        }
    }
    
    func refreshData(_ dataFrame: DataFrameData) async {
        await MainActor.run {
            loadedChunks.removeAll()
            baseDataFrame = dataFrame
            totalRows = dataFrame.rows.count
        }
        
        await loadChunk(0)
    }
    
    func sortData(by column: String, ascending: Bool) async {
        guard var dataFrame = baseDataFrame else { return }
        
        await MainActor.run { isLoading = true }
        
        // Perform sort operation
        guard let columnIndex = dataFrame.columns.firstIndex(of: column) else {
            await MainActor.run { isLoading = false }
            return
        }
        
        let sortedIndices = dataFrame.rows.indices.sorted { i, j in
            let val1 = i < dataFrame.rows.count && columnIndex < dataFrame.rows[i].count 
                ? dataFrame.rows[i][columnIndex] 
                : ""
            let val2 = j < dataFrame.rows.count && columnIndex < dataFrame.rows[j].count 
                ? dataFrame.rows[j][columnIndex] 
                : ""
            
            if ascending {
                return val1.localizedStandardCompare(val2) == .orderedAscending
            } else {
                return val1.localizedStandardCompare(val2) == .orderedDescending
            }
        }
        
        dataFrame.rows = sortedIndices.map { dataFrame.rows[$0] }
        
        await MainActor.run {
            baseDataFrame = dataFrame
            loadedChunks.removeAll()
            isLoading = false
        }
        
        // Reload first chunk
        await loadChunk(0)
    }
    
    private func cleanupOldChunks() {
        while loadedChunks.count > maxCachedChunks {
            // Remove oldest chunk
            if let oldestChunk = loadedChunks.values.min(by: { $0.loadedAt < $1.loadedAt }) {
                loadedChunks.removeValue(forKey: oldestChunk.index)
            }
        }
    }
}

class DataTableSearchManager: ObservableObject {
    @Published var searchResults: [Int] = []
    @Published var isSearching = false
    
    private var searchTask: Task<Void, Never>?
    
    func search(_ query: String, in dataFrame: DataFrameData) async {
        // Cancel previous search
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            await MainActor.run {
                searchResults = []
                isSearching = false
            }
            return
        }
        
        await MainActor.run {
            isSearching = true
        }
        
        searchTask = Task {
            let results = await performSearch(query: query, dataFrame: dataFrame)
            
            if !Task.isCancelled {
                await MainActor.run {
                    searchResults = results
                    isSearching = true // Keep true to indicate filtered state
                }
            }
        }
        
        await searchTask?.value
    }
    
    private func performSearch(query: String, dataFrame: DataFrameData) async -> [Int] {
        let lowercaseQuery = query.lowercased()
        var results: [Int] = []
        
        for (index, row) in dataFrame.rows.enumerated() {
            if Task.isCancelled { break }
            
            let rowMatches = row.contains { cell in
                cell.lowercased().contains(lowercaseQuery)
            }
            
            if rowMatches {
                results.append(index)
            }
            
            // Yield control periodically for large datasets
            if index % 1000 == 0 {
                await Task.yield()
            }
        }
        
        return results
    }
}

// MARK: - Preview

#Preview {
    let sampleData = DataFrameData(
        columns: ["ID", "Name", "Category", "Value", "Date"],
        rows: (1...10000).map { index in
            [
                "\(index)",
                "Item \(index)",
                ["Electronics", "Books", "Clothing", "Food"].randomElement()!,
                "\(Double.random(in: 10...1000))",
                "2024-01-\(String(format: "%02d", (index % 28) + 1))"
            ]
        },
        dtypes: [
            "ID": "int",
            "Name": "string", 
            "Category": "string",
            "Value": "float",
            "Date": "string"
        ]
    )
    
    VirtualizedDataTable(dataFrame: sampleData, windowID: 1)
        .frame(height: 600)
}