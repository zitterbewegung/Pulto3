//
//  DataTableContentView.swift
//  Pulto
//
//  Enhanced DataFrame viewer with spreadsheet-like functionality
//

import SwiftUI
import Charts
import RealityKit
import UniformTypeIdentifiers

// Enhanced DataFrame viewer with spreadsheet-like appearance - Cross-platform version
struct DataTableContentView: View {
    let windowID: Int?
    let initialDataFrame: DataFrameData?
    
    @StateObject private var windowManager = WindowTypeManager.shared
    @StateObject private var dataFrame: DataFrameModel
    @StateObject private var importer = DataFrameImporter()
    @StateObject private var streamingImporter = StreamingDataFrameImporter()
    @Environment(\.openWindow) private var openWindow
    
    @State private var selectedCell: (row: Int, col: Int)? = nil
    @State private var hoveredCell: (row: Int, col: Int)? = nil
    @State private var editingCell: (row: Int, col: Int)? = nil
    @State private var editingValue = ""
    @State private var sortColumn: String? = nil
    @State private var sortAscending = true
    @State private var filterText = ""
    @State private var showingImportSheet = false
    @State private var showingColumnDetails = false
    @State private var selectedColumn: DataColumn?
    @State private var showingStatistics = false
    @State private var showingHistory = false
    @State private var showingExportOptions = false
    @State private var columnWidths: [String: CGFloat] = [:]
    @State private var hasPresentedInitialImport = false
    @State private var showingUSDZImporter = false
    
    // Streaming state
    @State private var isStreamingActive = false
    @State private var streamingEndpoint = ""
    @State private var streamingFormat: ImportFormat = .csv(delimiter: ",")
    @State private var streamingInterval: Double = 5.0
    @State private var showingStreamingSheet = false
    @State private var streamingError: String? = nil
    
    @FocusState private var isFilterFieldFocused: Bool
    @FocusState private var isCellEditing: Bool
    
    // Chart integration
    @State private var showingChartRecommender = false
    @State private var selectedChartRecommendation: ChartRecommendation?
    
    // UI State
    @State private var showingSidebar = false
    @State private var selectedSidebarTab: SidebarTab = .columns
    
    enum SidebarTab: String, CaseIterable {
        case columns = "Columns"
        case statistics = "Statistics"
        case history = "History"
        case export = "Export"
        
        var icon: String {
            switch self {
            case .columns: return "tablecells"
            case .statistics: return "chart.bar"
            case .history: return "clock"
            case .export: return "square.and.arrow.up"
            }
        }
    }
    
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
    let backgroundColor = Color.primary.opacity(0.05)
    let windowBackgroundColor = Color.primary.opacity(0.02)
    let textBackgroundColor = Color.primary.opacity(0.02)
    let separatorColor = Color.primary.opacity(0.2)
    let gridColor = Color.primary.opacity(0.1)
    let alternatingRowColor = Color.primary.opacity(0.03)
    let selectedContentColor = Color.primary.opacity(0.15)
    #endif
    
    // MARK: - Initialization
    
    init(windowID: Int? = nil, initialDataFrame: DataFrameData? = nil) {
        self.windowID = windowID
        self.initialDataFrame = initialDataFrame
        
        // Convert legacy data or create new DataFrame
        if let legacyData = initialDataFrame {
            let convertedDataFrame = DataFrameModel(from: legacyData)
            self._dataFrame = StateObject(wrappedValue: convertedDataFrame)
        } else {
            let sampleDataFrame = SampleDataGenerator.generateSalesData()
            self._dataFrame = StateObject(wrappedValue: sampleDataFrame)
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredData: DataFrameModel {
        if filterText.isEmpty {
            return dataFrame
        }
        
        return dataFrame.filter { rowIndex in
            for column in dataFrame.columns {
                if rowIndex < column.values.count {
                    let value = column.values[rowIndex]
                    if value.localizedCaseInsensitiveContains(filterText) {
                        return true
                    }
                }
            }
            return false
        }
    }
    
    // MARK: - Main Body
    
    var body: some View {
        HStack(spacing: 0) {
            // Main DataFrame Content
            VStack(spacing: 0) {
                // Toolbar
                toolbarView
                
                // Main spreadsheet view
                spreadsheetView
                
                // Status bar
                statusBarView
            }
            .background(backgroundColor)
            
            // Sidebar
            if showingSidebar {
                sidebarView
                    .frame(width: 300)
                    .transition(.move(edge: .trailing))
            }
        }
        .onAppear {
            loadDataFromWindow()
            initializeColumnWidths()
            
            // Present import sheet automatically on first creation if no data is present
            if !hasPresentedInitialImport {
                hasPresentedInitialImport = true
                if let windowID = windowID {
                    if let win = windowManager.getWindow(for: windowID) {
                        if win.state.dataFrameData == nil {
                            DispatchQueue.main.async {
                                showingImportSheet = true
                            }
                        }
                    } else {
                        // If window not found in manager, still offer import on first open
                        if initialDataFrame == nil {
                            DispatchQueue.main.async {
                                showingImportSheet = true
                            }
                        }
                    }
                } else {
                    // No window ID (preview or ad-hoc) — show if no initial data provided
                    if initialDataFrame == nil {
                        DispatchQueue.main.async {
                            showingImportSheet = true
                        }
                    }
                }
            }
        }
        .onDisappear {
            saveDataToWindow()
            streamingImporter.stopAllStreaming()
        }
        .sheet(isPresented: $showingImportSheet) {
            DataImportSheet(importer: importer) { importedDataFrame in
                dataFrame.columns = importedDataFrame.columns
                dataFrame.name = importedDataFrame.name
                dataFrame.metadata = importedDataFrame.metadata
                initializeColumnWidths()
                saveDataToWindow()
            }
        }
        .sheet(isPresented: $showingStreamingSheet) {
            StreamingSheet(
                isStreamingActive: $isStreamingActive,
                endpoint: $streamingEndpoint,
                format: $streamingFormat,
                interval: $streamingInterval,
                onStartStreaming: startStreaming,
                onStopStreaming: stopStreaming
            )
        }
        .sheet(isPresented: $showingChartRecommender) {
            ChartRecommenderSheet(
                csvData: convertDataFrameToCSV(),
                onChartSelected: { recommendation, chartData in
                    selectedChartRecommendation = recommendation
                    openSpatialEditorWithChart(recommendation: recommendation, chartData: chartData)
                    showingChartRecommender = false
                }
            )
        }
        .fileImporter(
            isPresented: $showingUSDZImporter,
            allowedContentTypes: [.usdz],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task { @MainActor in
                        do {
                            let id = windowManager.getNextWindowID()
                            let position = WindowPosition(x: 100, y: 100, z: 0, width: 800, height: 600)
                            _ = windowManager.createWindow(.model3d, id: id, position: position)

                            // Create a security-scoped bookmark for the USDZ file
                            let bookmark = try url.bookmarkData(options: .minimalBookmark)
                            windowManager.updateUSDZBookmark(for: id, bookmark: bookmark)

                            // Optionally set a placeholder model for immediate UI feedback
                            let placeholderModel = Model3DData(title: url.lastPathComponent, modelType: "usdz", scale: 1.0)
                            windowManager.updateWindowModel3D(id, modelData: placeholderModel)

                            windowManager.markWindowAsOpened(id)
                            #if os(visionOS)
                            openWindow(id: "volumetric-model3d", value: id)
                            #endif
                        } catch {
                            print("USDZ import failed: \(error)")
                        }
                    }
                }
            case .failure(let error):
                print("USDZ file import error: \(error)")
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingSidebar)
    }
    
    // MARK: - Toolbar
    
    private var toolbarView: some View {
        HStack(spacing: 16) {
            // Title and info
            VStack(alignment: .leading, spacing: 2) {
                Text(dataFrame.name)
                    .font(.headline)
                Text("\(filteredData.rowCount) rows × \(filteredData.columnCount) columns")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Filter field
            HStack(spacing: 8) {
                Button(action: {
                    isFilterFieldFocused = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        if filterText.isEmpty {
                            Text("Filter data...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                TextField("Filter data...", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .focused($isFilterFieldFocused)
                    .onSubmit {
                        isFilterFieldFocused = false
                    }
                
                if !filterText.isEmpty {
                    Button(action: {
                        filterText = ""
                        isFilterFieldFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: { loadSampleData() }) {
                    Label("Sample Data", systemImage: "doc.text")
                }
                .buttonStyle(DataTableButtonStyle(color: .blue))
                
                Button(action: { showingImportSheet = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(DataTableButtonStyle(color: .green))
                
                Button(action: { showingStreamingSheet = true }) {
                    Label("Stream Data", systemImage: isStreamingActive ? "pause.circle" : "play.circle")
                }
                .buttonStyle(DataTableButtonStyle(color: isStreamingActive ? .red : .orange))
                .alert("Streaming Error", isPresented: .constant(streamingError != nil)) {
                    Button("OK") { streamingError = nil }
                } message: {
                    Text(streamingError ?? "Unknown error")
                }
                
                Button(action: { showingChartRecommender = true }) {
                    Label("Create Chart", systemImage: "chart.xyaxis.line")
                }
                .buttonStyle(DataTableButtonStyle(color: .purple))
                
                Button(action: { showingUSDZImporter = true }) {
                    Label("Import USDZ", systemImage: "cube")
                }
                .buttonStyle(DataTableButtonStyle(color: .red))
                
                Button(action: { showingSidebar.toggle() }) {
                    Label("Details", systemImage: showingSidebar ? "sidebar.right" : "sidebar.left")
                }
                .buttonStyle(DataTableButtonStyle(color: .orange))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(windowBackgroundColor)
    }
    
    // MARK: - Spreadsheet View
    
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
                    ForEach(filteredData.columns, id: \.id) { column in
                        columnHeaderView(column: column)
                    }
                }
                
                // Data rows
                ForEach(0..<filteredData.rowCount, id: \.self) { rowIndex in
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
                        ForEach(Array(filteredData.columns.enumerated()), id: \.element.id) { colIndex, column in
                            cellView(rowIndex: rowIndex, colIndex: colIndex, column: column)
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
    
    // MARK: - Column Header View
    
    private func columnHeaderView(column: DataColumn) -> some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(column.name)
                    .font(.system(.caption))
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(column.dataType.displayName)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 0)
            
            // Sort indicator
            if sortColumn == column.name {
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            // Data type icon
            Image(systemName: column.dataType.icon)
                .font(.system(size: 10))
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(width: columnWidths[column.name] ?? 120)
        .background(gridColor.opacity(0.1))
        .overlay(
            Rectangle()
                .stroke(separatorColor, lineWidth: 0.5)
        )
        .onTapGesture {
            toggleSort(column: column.name)
        }
        .contextMenu {
            Button("Column Details") {
                selectedColumn = column
                showingColumnDetails = true
            }
            Button("Sort Ascending") {
                sortColumn = column.name
                sortAscending = true
                dataFrame.sort(byColumn: column.name, ascending: true)
            }
            Button("Sort Descending") {
                sortColumn = column.name
                sortAscending = false
                dataFrame.sort(byColumn: column.name, ascending: false)
            }
            Divider()
            Button("Insert Column Before") {
                insertColumnBefore(column.name)
            }
            Button("Insert Column After") {
                insertColumnAfter(column.name)
            }
            Button("Delete Column", role: .destructive) {
                deleteColumn(column.name)
            }
        }
    }
    
    // MARK: - Cell View
    
    private func cellView(rowIndex: Int, colIndex: Int, column: DataColumn) -> some View {
        let value = rowIndex < column.values.count ? column.values[rowIndex] : ""
        let isSelected = selectedCell?.row == rowIndex && selectedCell?.col == colIndex
        let isHovered = hoveredCell?.row == rowIndex && hoveredCell?.col == colIndex
        let isEditing = editingCell?.row == rowIndex && editingCell?.col == colIndex
        
        return Group {
            if isEditing {
                TextField("", text: $editingValue)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($isCellEditing)
                    .onSubmit {
                        commitCellEdit(rowIndex: rowIndex, columnIndex: colIndex)
                    }
                    .onAppear {
                        editingValue = value
                        isCellEditing = true
                    }
            } else {
                Text(formatCellValue(value, column: column))
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .foregroundColor(getCellTextColor(value: value, column: column))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(width: columnWidths[column.name] ?? 120, alignment: getCellAlignment(column: column))
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
        .onTapGesture(count: 2) {
            startCellEditing(rowIndex: rowIndex, columnIndex: colIndex)
        }
        .onHover { hovering in
            if hovering {
                hoveredCell = (row: rowIndex, col: colIndex)
            } else if hoveredCell?.row == rowIndex && hoveredCell?.col == colIndex {
                hoveredCell = nil
            }
        }
        .contextMenu {
            Button("Edit Cell") {
                startCellEditing(rowIndex: rowIndex, columnIndex: colIndex)
            }
            Button("Copy Value") {
                copyToClipboard(value)
            }
            Divider()
            Button("Insert Row Above") {
                dataFrame.insertRow(at: rowIndex)
            }
            Button("Insert Row Below") {
                dataFrame.insertRow(at: rowIndex + 1)
            }
            Button("Delete Row", role: .destructive) {
                dataFrame.removeRow(at: rowIndex)
            }
        }
    }
    
    // MARK: - Sidebar View
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Sidebar tabs
            HStack(spacing: 0) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Button(action: { selectedSidebarTab = tab }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.caption)
                            Text(tab.rawValue)
                                .font(.caption2)
                        }
                        .foregroundColor(selectedSidebarTab == tab ? .blue : .secondary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .background(selectedSidebarTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                }
            }
            .background(separatorColor.opacity(0.5))
            
            Divider()
            
            // Sidebar content
            ScrollView {
                switch selectedSidebarTab {
                case .columns:
                    columnsTabView
                case .statistics:
                    statisticsTabView
                case .history:
                    historyTabView
                case .export:
                    exportTabView
                }
            }
            .padding()
        }
        .background(windowBackgroundColor)
        .overlay(
            Rectangle()
                .fill(separatorColor)
                .frame(width: 0.5),
            alignment: .leading
        )
    }
    
    // MARK: - Sidebar Tab Views
    
    private var columnsTabView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Columns")
                .font(.headline)
            
            ForEach(dataFrame.columns, id: \.id) { column in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: column.dataType.icon)
                            .foregroundColor(.blue)
                        Text(column.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        if !column.isValid {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Text(column.dataType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !column.metadata.description.isEmpty {
                        Text(column.metadata.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    let stats = column.statistics
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unique: \(stats.uniqueCount) | Null: \(stats.nullCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if let mean = stats.mean {
                            Text("Mean: \(String(format: "%.2f", mean))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                .onTapGesture {
                    selectedColumn = column
                    showingColumnDetails = true
                }
            }
        }
    }
    
    private var statisticsTabView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
            
            // Overall DataFrame stats
            VStack(alignment: .leading, spacing: 8) {
                Text("DataFrame Overview")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("Shape:")
                    Spacer()
                    Text("\(dataFrame.rowCount) × \(dataFrame.columnCount)")
                }
                
                HStack {
                    Text("Memory:")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: Int64(dataFrame.metadata.memoryUsage), countStyle: .memory))
                }
                
                HStack {
                    Text("Created:")
                    Spacer()
                    Text(dataFrame.metadata.created, style: .date)
                }
            }
            .padding(8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(6)
            
            // Column type distribution
            VStack(alignment: .leading, spacing: 8) {
                Text("Column Types")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                let typeGroups = Dictionary(grouping: dataFrame.columns) { $0.dataType }
                ForEach(Array(typeGroups.keys.sorted(by: { $0.displayName < $1.displayName })), id: \.self) { dataType in
                    HStack {
                        Image(systemName: dataType.icon)
                            .foregroundColor(.blue)
                        Text(dataType.displayName)
                        Spacer()
                        Text("\(typeGroups[dataType]?.count ?? 0)")
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(8)
            .background(Color.green.opacity(0.1))
            .cornerRadius(6)
        }
    }
    
    private var historyTabView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Operation History")
                .font(.headline)
            
            if dataFrame.history.isEmpty {
                Text("No operations recorded")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(dataFrame.history.suffix(20).reversed(), id: \.id) { operation in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(operation.type.rawValue.capitalized)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(getOperationColor(operation.type))
                                .cornerRadius(4)
                            
                            Spacer()
                            
                            Text(operation.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(operation.description)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .padding(6)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(4)
                }
            }
        }
    }
    
    private var exportTabView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Options")
                .font(.headline)
            
            VStack(spacing: 8) {
                Button(action: exportAsCSV) {
                    Label("Export as CSV", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: exportAsTSV) {
                    Label("Export as TSV", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: exportAsJSON) {
                    Label("Export as JSON", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: exportAsPython) {
                    Label("Export as Python", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Stats")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Total cells: \(dataFrame.rowCount * dataFrame.columnCount)")
                    .font(.caption)
                
                Text("Non-empty cells: \(getNonEmptyCellCount())")
                    .font(.caption)
                
                Text("Completion: \(String(format: "%.1f%%", getCompletionPercentage()))")
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Status Bar
    
    private var statusBarView: some View {
        HStack {
            if let cell = selectedCell {
                let columnName = dataFrame.columns[cell.col].name
                Label(
                    "Cell: \(columnName)[\(cell.row + 1)]",
                    systemImage: "square.dashed"
                )
                .font(.caption)
                .foregroundColor(.secondary)
                
                if let value = dataFrame.getValue(row: cell.row, column: cell.col) {
                    Text("• \(value)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Select a cell to view details")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Import progress
            if importer.isImporting {
                HStack(spacing: 8) {
                    ProgressView(value: importer.importProgress)
                        .frame(width: 100)
                    Text(importer.importStatus)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Filter status
            if !filterText.isEmpty {
                Text("Filtered: \(filteredData.rowCount) of \(dataFrame.rowCount) rows")
                    .font(.caption)
                    .foregroundColor(.blue)
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
    
    // MARK: - Helper Functions
    
    private func initializeColumnWidths() {
        for column in dataFrame.columns {
            switch column.dataType {
            case .integer, .double:
                columnWidths[column.name] = 100
            case .boolean:
                columnWidths[column.name] = 80
            case .date:
                columnWidths[column.name] = 120
            case .string, .categorical:
                columnWidths[column.name] = 150
            }
        }
    }
    
    private func formatCellValue(_ value: String, column: DataColumn) -> String {
        guard !value.isEmpty else { return "" }
        
        switch column.dataType {
        case .double:
            if let number = Double(value) {
                return String(format: "%.2f", number)
            }
        case .integer:
            if let number = Int(value) {
                return NumberFormatter.localizedString(from: NSNumber(value: number), number: .decimal)
            }
        case .boolean:
            return value.lowercased() == "true" ? "✓" : "✗"
        case .date:
            if let date = ISO8601DateFormatter().date(from: value) {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                return formatter.string(from: date)
            }
        default:
            break
        }
        
        return value
    }
    
    private func getCellTextColor(value: String, column: DataColumn) -> Color {
        if value.isEmpty {
            return .secondary
        }
        
        switch column.dataType {
        case .integer, .double:
            return .primary
        case .boolean:
            return value.lowercased() == "true" ? .green : .red
        case .date:
            return .blue
        default:
            return .primary
        }
    }
    
    private func getCellAlignment(column: DataColumn) -> Alignment {
        switch column.dataType {
        case .integer, .double:
            return .trailing
        case .boolean:
            return .center
        default:
            return .leading
        }
    }
    
    private func toggleSort(column: String) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
        
        dataFrame.sort(byColumn: column, ascending: sortAscending)
        filterText = "" // Clear filter when sorting
    }
    
    private func startCellEditing(rowIndex: Int, columnIndex: Int) {
        editingCell = (row: rowIndex, col: columnIndex)
        if let value = dataFrame.getValue(row: rowIndex, column: columnIndex) {
            editingValue = value
        }
    }
    
    private func commitCellEdit(rowIndex: Int, columnIndex: Int) {
        dataFrame.setValue(editingValue, row: rowIndex, column: columnIndex)
        editingCell = nil
        editingValue = ""
        isCellEditing = false
        saveDataToWindow()
    }
    
    private func loadDataFromWindow() {
        guard let windowID = windowID,
              let window = windowManager.getWindow(for: windowID),
              let existingData = window.state.dataFrameData else {
            return
        }
        
        let convertedDataFrame = DataFrameModel(from: existingData)
        dataFrame.columns = convertedDataFrame.columns
        dataFrame.name = convertedDataFrame.name
        dataFrame.metadata = convertedDataFrame.metadata
    }
    
    private func saveDataToWindow() {
        guard let windowID = windowID else { return }
        let legacyData = dataFrame.toLegacyDataFrameData()
        windowManager.updateWindowDataFrame(windowID, dataFrame: legacyData)
    }
    
    private func loadSampleData() {
        let sampleData = SampleDataGenerator.generateSalesData()
        dataFrame.columns = sampleData.columns
        dataFrame.name = sampleData.name
        dataFrame.metadata = sampleData.metadata
        initializeColumnWidths()
        saveDataToWindow()
    }
    
    // MARK: - Column Operations
    
    private func insertColumnBefore(_ columnName: String) {
        guard let index = dataFrame.columns.firstIndex(where: { $0.name == columnName }) else { return }
        let newColumn = DataColumn(name: "New Column", dataType: .string, values: Array(repeating: "", count: dataFrame.rowCount))
        dataFrame.insertColumn(newColumn, at: index)
    }
    
    private func insertColumnAfter(_ columnName: String) {
        guard let index = dataFrame.columns.firstIndex(where: { $0.name == columnName }) else { return }
        let newColumn = DataColumn(name: "New Column", dataType: .string, values: Array(repeating: "", count: dataFrame.rowCount))
        dataFrame.insertColumn(newColumn, at: index + 1)
    }
    
    private func deleteColumn(_ columnName: String) {
        guard let index = dataFrame.columns.firstIndex(where: { $0.name == columnName }) else { return }
        dataFrame.removeColumn(at: index)
    }
    
    // MARK: - Export Functions
    
    private func exportAsCSV() {
        let csv = dataFrame.toCSV()
        copyToClipboard(csv)
    }
    
    private func exportAsTSV() {
        let tsv = dataFrame.toCSV(delimiter: "\t")
        copyToClipboard(tsv)
    }
    
    private func exportAsJSON() {
        // Convert to JSON format
        var jsonData: [[String: Any]] = []
        for rowIndex in 0..<dataFrame.rowCount {
            var rowDict: [String: Any] = [:]
            for column in dataFrame.columns {
                if rowIndex < column.values.count {
                    let value = column.values[rowIndex]
                    switch column.dataType {
                    case .integer:
                        rowDict[column.name] = Int(value) ?? 0
                    case .double:
                        rowDict[column.name] = Double(value) ?? 0.0
                    case .boolean:
                        rowDict[column.name] = value.lowercased() == "true"
                    default:
                        rowDict[column.name] = value
                    }
                }
            }
            jsonData.append(rowDict)
        }
        
        if let jsonDataObj = try? JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted),
           let jsonString = String(data: jsonDataObj, encoding: .utf8) {
            copyToClipboard(jsonString)
        }
    }
    
    private func exportAsPython() {
        let pythonCode = dataFrame.toPythonCode()
        copyToClipboard(pythonCode)
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
    
    // MARK: - Chart Integration
    
    private func convertDataFrameToCSV() -> CSVData {
        let headers = dataFrame.columns.map { $0.name }
        let rows = (0..<dataFrame.rowCount).map { rowIndex in
            dataFrame.columns.map { column in
                rowIndex < column.values.count ? column.values[rowIndex] : ""
            }
        }
        
        let columnTypes: [ColumnType] = dataFrame.columns.map { column in
            switch column.dataType {
            case .integer, .double:
                return .numeric
            case .date:
                return .date
            case .categorical:
                return .categorical
            default:
                return .categorical
            }
        }
        
        return CSVData(headers: headers, rows: rows, columnTypes: columnTypes)
    }
    
    private func openSpatialEditorWithChart(recommendation: ChartRecommendation, chartData: ChartData) {
        guard let windowID = windowID else { return }
        windowManager.updateWindowChartData(windowID, chartData: chartData)
        print("Chart data saved to window \(windowID) for spatial visualization")
    }
    
    // MARK: - Statistics Helpers
    
    private func getNonEmptyCellCount() -> Int {
        return dataFrame.columns.reduce(0) { total, column in
            total + column.values.filter { !$0.isEmpty }.count
        }
    }
    
    private func getCompletionPercentage() -> Double {
        let totalCells = dataFrame.rowCount * dataFrame.columnCount
        guard totalCells > 0 else { return 0 }
        return Double(getNonEmptyCellCount()) / Double(totalCells) * 100.0
    }
    
    private func getOperationColor(_ type: DataFrameOperation.OperationType) -> Color {
        switch type {
        case .insert:
            return .green.opacity(0.2)
        case .delete:
            return .red.opacity(0.2)
        case .update:
            return .blue.opacity(0.2)
        case .sort:
            return .orange.opacity(0.2)
        case .filter:
            return .purple.opacity(0.2)
        case .importData, .export:
            return .gray.opacity(0.2)
        case .typeChange:
            return .yellow.opacity(0.2)
        }
    }
    
    // MARK: - Streaming Functions
    
    private func startStreaming() {
        guard !streamingEndpoint.isEmpty else {
            streamingError = "Please enter a valid endpoint URL"
            return
        }
        
        streamingImporter.startStreaming(
            from: streamingEndpoint,
            format: streamingFormat,
            interval: streamingInterval,
            dataFrame: dataFrame
        ) { progress, status in
            Task { @MainActor in
                // Update UI with progress if needed
            }
        } onError: { error in
            Task { @MainActor in
                streamingError = error.localizedDescription
                isStreamingActive = false
            }
        }
        
        isStreamingActive = true
    }
    
    private func stopStreaming() {
        streamingImporter.stopStreaming(for: streamingEndpoint)
        isStreamingActive = false
    }
}

// MARK: - Enhanced Data Import Sheet

struct DataImportSheet: View {
    @ObservedObject var importer: DataFrameImporter
    let onDataImported: (DataFrameModel) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFormat: ImportFormat = .csv(delimiter: ",")
    @State private var pasteText = ""
    @State private var showingFilePicker = false
    @State private var importConfiguration = ImportConfiguration()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Import Data")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Import CSV, TSV, JSON, or paste data directly")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Import options
                VStack(alignment: .leading, spacing: 16) {
                    // File import
                    Button(action: { showingFilePicker = true }) {
                        Label("Import from File", systemImage: "doc.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                    
                    // Paste data
                    /*
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Or paste data directly:")
                            .font(.headline)
                        
                        // Format picker
                        Picker("Format", selection: $selectedFormat) {
                            Text("CSV (comma)").tag(ImportFormat.csv(delimiter: ","))
                            Text("TSV (tab)").tag(ImportFormat.csv(delimiter: "\t"))
                            Text("JSON").tag(ImportFormat.json)
                        }
                        .pickerStyle(.segmented)
                        
                        TextEditor(text: $pasteText)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        
                        Button("Import from Text") {
                            Task {
                                do {
                                    let dataFrame = try await importer.importFromText(pasteText, format: selectedFormat)
                                    onDataImported(dataFrame)
                                    dismiss()
                                } catch {
                                    print("Import error: \(error)")
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(pasteText.isEmpty)
                    }
                    
                    Divider()
                    */
                    // Sample data
                    /*VStack(alignment: .leading, spacing: 8) {
                        Text("Or use sample data:")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            Button("Sales Data") {
                                let sampleData = SampleDataGenerator.generateSalesData()
                                onDataImported(sampleData)
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Weather Data") {
                                let sampleData = SampleDataGenerator.generateWeatherData()
                                onDataImported(sampleData)
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                        }
                    }*/
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        importer.cancelImport()
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .json, .plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    handleFileImport(url)
                }
            case .failure(let error):
                print("File import error: \(error)")
            }
        }
    }
    
    private func handleFileImport(_ url: URL) {
        Task {
            do {
                let dataFrame = try await importer.importFromFile(url: url)
                await MainActor.run {
                    onDataImported(dataFrame)
                    dismiss()
                }
            } catch {
                print("Import error: \(error)")
            }
        }
    }
}

struct ChartRecommenderSheet: View {
    let csvData: CSVData
    let onChartSelected: (ChartRecommendation, ChartData) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var recommendations: [ChartScore] = []
    @State private var selectedRecommendation: ChartRecommendation?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerView
                recommendationsList
                actionButtons
            }
            .navigationBarHidden(true)
            .onAppear {
                loadRecommendations()
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Chart Recommendations")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Based on your data structure")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var recommendationsList: some View {
        List(recommendations, id: \.recommendation) { score in
            recommendationRow(score)
        }
    }
    
    private func recommendationRow(_ score: ChartScore) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(score.recommendation.name)
                    .font(.headline)
                Text(score.reasoning)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(Int(score.score * 100))%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            if selectedRecommendation == score.recommendation {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedRecommendation = score.recommendation
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
            
            Button("Create Chart") {
                createChart()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedRecommendation == nil)
        }
        .padding()
    }
    
    private func loadRecommendations() {
        recommendations = ChartRecommender.recommend(for: csvData)
        selectedRecommendation = recommendations.first?.recommendation
    }
    
    private func createChart() {
        guard let selected = selectedRecommendation else { return }
        let chartData = createChartData(from: csvData, recommendation: selected)
        onChartSelected(selected, chartData)
    }
    
    private func createChartData(from csvData: CSVData, recommendation: ChartRecommendation) -> ChartData {
        // Simple implementation
        let xData = Array(0..<csvData.rows.count).map { Double($0) }
        let yData = Array(0..<csvData.rows.count).map { _ in Double.random(in: 0...100) }
        
        return ChartData(
            title: "Chart from DataFrame",
            chartType: recommendation.name.lowercased(),
            xLabel: "Index",
            yLabel: "Value",
            xData: xData,
            yData: yData
        )
    }
}

struct StreamingSheet: View {
    @Binding var isStreamingActive: Bool
    @Binding var endpoint: String
    @Binding var format: ImportFormat
    @Binding var interval: Double
    
    let onStartStreaming: () -> Void
    let onStopStreaming: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: isStreamingActive ? "pause.circle" : "play.circle")
                        .font(.system(size: 50))
                        .foregroundColor(isStreamingActive ? .red : .green)
                    
                    Text(isStreamingActive ? "Streaming Active" : "Stream Data")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Connect to a live data endpoint")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Configuration
                VStack(alignment: .leading, spacing: 16) {
                    // Endpoint URL
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Endpoint URL")
                            .font(.headline)
                        
                        TextField("https://api.example.com/data", text: $endpoint)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // Format selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Data Format")
                            .font(.headline)
                        
                        Picker("Format", selection: $format) {
                            Text("CSV (comma)").tag(ImportFormat.csv(delimiter: ","))
                            Text("TSV (tab)").tag(ImportFormat.csv(delimiter: "\t"))
                            Text("JSON").tag(ImportFormat.json)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Update interval
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Update Interval")
                            .font(.headline)
                        
                        HStack {
                            Slider(value: $interval, in: 1...60, step: 1)
                            Text("\(Int(interval))s")
                                .frame(width: 40)
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    if isStreamingActive {
                        Button("Stop Streaming") {
                            onStopStreaming()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else {
                        Button("Start Streaming") {
                            onStartStreaming()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
            }
            .padding()
            .navigationTitle("Stream Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Custom Button Style

struct DataTableButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(configuration.isPressed ? 0.3 : 0.1))
            .foregroundColor(color)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    DataTableContentView(windowID: 1)
}

