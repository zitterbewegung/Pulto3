//
//  EnhancedDataTableContentView.swift
//  Pulto
//
//  Enhanced DataFrame viewer using new unique types to avoid conflicts
//

import SwiftUI
import Charts
import RealityKit
import UniformTypeIdentifiers

// MARK: - Enhanced DataFrame Table View

struct EnhancedDataTableContentView: View {
    let windowID: Int?
    let initialDataFrame: DataFrameData?
    
    @StateObject private var windowManager = WindowTypeManager.shared
    @StateObject private var dataFrame: EnhancedDataFrameModel
    @StateObject private var importer = EnhancedDataFrameImporter()
    
    @State private var selectedCell: (row: Int, col: Int)? = nil
    @State private var hoveredCell: (row: Int, col: Int)? = nil
    @State private var editingCell: (row: Int, col: Int)? = nil
    @State private var editingValue = ""
    @State private var sortColumn: String? = nil
    @State private var sortAscending = true
    @State private var filterText = ""
    @State private var showingImportSheet = false
    @State private var showingColumnDetails = false
    @State private var selectedColumn: EnhancedDataColumn?
    @State private var showingStatistics = false
    @State private var showingHistory = false
    @State private var showingExportOptions = false
    @State private var columnWidths: [String: CGFloat] = [:]
    
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
            let convertedDataFrame = EnhancedDataFrameModel(from: legacyData)
            self._dataFrame = StateObject(wrappedValue: convertedDataFrame)
        } else {
            let sampleDataFrame = EnhancedSampleDataGenerator.generateSalesData()
            self._dataFrame = StateObject(wrappedValue: sampleDataFrame)
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredData: EnhancedDataFrameModel {
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
        }
        .onDisappear {
            saveDataToWindow()
        }
        .sheet(isPresented: $showingImportSheet) {
            EnhancedDataImportSheet(importer: importer) { importedDataFrame in
                dataFrame.columns = importedDataFrame.columns
                dataFrame.name = importedDataFrame.name
                dataFrame.metadata = importedDataFrame.metadata
                initializeColumnWidths()
                saveDataToWindow()
            }
        }
        .sheet(isPresented: $showingChartRecommender) {
            SimpleChartRecommenderSheet(
                csvData: convertDataFrameToCSV(),
                onChartSelected: { recommendation, chartData in
                    selectedChartRecommendation = recommendation
                    openSpatialEditorWithChart(recommendation: recommendation, chartData: chartData)
                    showingChartRecommender = false
                }
            )
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
                TextField("Filter data...", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .focused($isFilterFieldFocused)
                
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
                .buttonStyle(EnhancedDataTableButtonStyle(color: .blue))
                
                Button(action: { showingImportSheet = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(EnhancedDataTableButtonStyle(color: .green))
                
                Button(action: { showingChartRecommender = true }) {
                    Label("Create Chart", systemImage: "chart.xyaxis.line")
                }
                .buttonStyle(EnhancedDataTableButtonStyle(color: .purple))
                
                Button(action: { showingSidebar.toggle() }) {
                    Label("Details", systemImage: showingSidebar ? "sidebar.right" : "sidebar.left")
                }
                .buttonStyle(EnhancedDataTableButtonStyle(color: .orange))
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
    
    // MARK: - Helper Views and Methods
    
    private func columnHeaderView(column: EnhancedDataColumn) -> some View {
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
    }
    
    private func cellView(rowIndex: Int, colIndex: Int, column: EnhancedDataColumn) -> some View {
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
            }
        }
    }
    
    private var statisticsTabView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
            
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
                
                Button(action: exportAsPython) {
                    Label("Export as Python", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
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
    
    private func formatCellValue(_ value: String, column: EnhancedDataColumn) -> String {
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
    
    private func getCellTextColor(value: String, column: EnhancedDataColumn) -> Color {
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
    
    private func getCellAlignment(column: EnhancedDataColumn) -> Alignment {
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
        
        let convertedDataFrame = EnhancedDataFrameModel(from: existingData)
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
        let sampleData = EnhancedSampleDataGenerator.generateSalesData()
        dataFrame.columns = sampleData.columns
        dataFrame.name = sampleData.name
        dataFrame.metadata = sampleData.metadata
        initializeColumnWidths()
        saveDataToWindow()
    }
    
    private func exportAsCSV() {
        let csv = dataFrame.toCSV()
        copyToClipboard(csv)
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
    
    private func getOperationColor(_ type: EnhancedDataFrameOperation.EnhancedOperationType) -> Color {
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
        case .dataImport, .export:
            return .gray.opacity(0.2)
        case .typeChange:
            return .yellow.opacity(0.2)
        }
    }
}

// MARK: - Enhanced Data Import Sheet

struct EnhancedDataImportSheet: View {
    @ObservedObject var importer: EnhancedDataFrameImporter
    let onDataImported: (EnhancedDataFrameModel) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFormat: EnhancedImportFormat = .csv(delimiter: ",")
    @State private var pasteText = ""
    @State private var showingFileImporter = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Import Enhanced Data")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Button(action: { showingFileImporter = true }) {
                    Label("Import from File", systemImage: "doc.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button("Load Sample Data") {
                    let sampleData = EnhancedSampleDataGenerator.generateSalesData()
                    onDataImported(sampleData)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Enhanced Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            Task {
                do {
                    let dataFrame = try await importer.importFromFile(url: url)
                    onDataImported(dataFrame)
                    dismiss()
                } catch {
                    print("Import error: \(error)")
                }
            }
            
        case .failure(let error):
            print("File selection error: \(error)")
        }
    }
}

// MARK: - Simple Chart Recommender Sheet

struct SimpleChartRecommenderSheet: View {
    let csvData: CSVData
    let onChartSelected: (ChartRecommendation, ChartData) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Chart Recommendations")
                .font(.title)
            
            Text("Enhanced DataFrame Chart Integration")
                .foregroundColor(.secondary)
            
            Button("Create Line Chart") {
                let chartData = ChartData(title: "Enhanced DataFrame Chart", chartType: "line")
                onChartSelected(.lineChart, chartData)
            }
            .buttonStyle(.borderedProminent)
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Enhanced Button Style

struct EnhancedDataTableButtonStyle: ButtonStyle {
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
    EnhancedDataTableContentView(windowID: 1)
}