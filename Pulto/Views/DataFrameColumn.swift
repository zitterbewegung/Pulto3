//
//  DataFrameView.swift
//  Volumetric Window
//
//  Created by Joshua Herman on 5/25/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import Foundation

// MARK: - Data Models

struct DataFrameColumn {
    let name: String
    let type: DataType
    var width: CGFloat = 120
    var isVisible: Bool = true
    
    enum DataType: String, CaseIterable {
        case string = "Text"
        case number = "Number"
        case date = "Date"
        case boolean = "Boolean"
        
        var icon: String {
            switch self {
            case .string: return "textformat"
            case .number: return "number"
            case .date: return "calendar"
            case .boolean: return "checkmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .string: return .blue
            case .number: return .green
            case .date: return .orange
            case .boolean: return .purple
            }
        }
    }
}

struct DataFrameRow {
    let id = UUID()
    var values: [String: Any]
    var isSelected: Bool = false
}

// MARK: - Main DataFrameView

struct DataFrameView: View {
    @State private var columns: [DataFrameColumn] = []
    @State private var rows: [DataFrameRow] = []
    @State private var filteredRows: [DataFrameRow] = []
    @State private var searchText: String = ""
    @State private var sortColumn: String? = nil
    @State private var sortAscending: Bool = true
    @State private var selectedRows: Set<UUID> = []
    @State private var showingColumnSettings = false
    @State private var isLoading = false
    @State private var showingSidebar = true
    @State private var currentPage = 0
    @State private var rowsPerPage = 50
    
    private var totalPages: Int {
        max(1, Int(ceil(Double(filteredRows.count) / Double(rowsPerPage))))
    }
    
    private var displayedRows: [DataFrameRow] {
        let startIndex = currentPage * rowsPerPage
        let endIndex = min(startIndex + rowsPerPage, filteredRows.count)
        return Array(filteredRows[startIndex..<endIndex])
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            sidebarView
        } detail: {
            // Main Content
            VStack(spacing: 0) {
                // Header
                headerView
                
                Divider()
                
                if isLoading {
                    loadingView
                } else if rows.isEmpty {
                    emptyStateView
                } else {
                    // Data Table
                    dataTableView
                }
                
                // Footer with pagination
                if !filteredRows.isEmpty {
                    footerView
                }
            }
            .background(.ultraThinMaterial)
            .navigationTitle("DataFrame")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            loadSampleData()
        }
        .sheet(isPresented: $showingColumnSettings) {
            columnSettingsView
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "tablecells")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    
                    Text("DataFrame")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search data...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onChange(of: searchText) { _, newValue in
                            filterData()
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
            
            // Data Info Section
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Data Overview")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Rows:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(filteredRows.count)")
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Columns:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(columns.filter(\.isVisible).count)/\(columns.count)")
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Selected:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(selectedRows.count)")
                                .fontWeight(.medium)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                
                // Column Types
                VStack(alignment: .leading, spacing: 8) {
                    Text("Column Types")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    ForEach(DataFrameColumn.DataType.allCases, id: \.self) { type in
                        let count = columns.filter { $0.type == type }.count
                        if count > 0 {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundStyle(type.color)
                                Text(type.rawValue)
                                    .font(.body)
                                Spacer()
                                Text("\(count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                
                // Actions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Actions")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Button(action: { showingColumnSettings = true }) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(.blue)
                            Text("Column Settings")
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: exportData) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.green)
                            Text("Export Data")
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Spacer()
        }
        .frame(minWidth: 280, maxWidth: 320)
        .background(.regularMaterial)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            // Sort indicator
            if let sortColumn = sortColumn {
                HStack(spacing: 4) {
                    Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("Sorted by \(sortColumn)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
            
            Spacer()
            
            // View controls
            HStack(spacing: 12) {
                Button(action: { showingColumnSettings = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                
                Button(action: clearSelection) {
                    Image(systemName: "clear")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(selectedRows.isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Data Table
    
    private var dataTableView: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                // Header Row
                HStack(spacing: 0) {
                    // Selection column
                    Button(action: toggleSelectAll) {
                        Image(systemName: selectedRows.count == displayedRows.count ? "checkmark.square.fill" : "square")
                            .foregroundStyle(selectedRows.count == displayedRows.count ? .blue : .secondary)
                    }
                    .frame(width: 40)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    
                    // Data columns
                    ForEach(columns.filter(\.isVisible), id: \.name) { column in
                        Button(action: { sortBy(column: column.name) }) {
                            HStack {
                                Image(systemName: column.type.icon)
                                    .font(.caption)
                                    .foregroundStyle(column.type.color)
                                
                                Text(column.name)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                
                                if sortColumn == column.name {
                                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .frame(width: column.width)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(.regularMaterial)
                        .overlay(
                            Rectangle()
                                .fill(.separator)
                                .frame(width: 1)
                                .frame(maxHeight: .infinity),
                            alignment: .trailing
                        )
                    }
                }
                .overlay(
                    Rectangle()
                        .fill(.separator)
                        .frame(height: 1),
                    alignment: .bottom
                )
                
                // Data Rows
                ForEach(Array(displayedRows.enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: 0) {
                        // Selection checkbox
                        Button(action: { toggleRowSelection(row.id) }) {
                            Image(systemName: selectedRows.contains(row.id) ? "checkmark.square.fill" : "square")
                                .foregroundStyle(selectedRows.contains(row.id) ? .blue : .secondary)
                        }
                        .frame(width: 40)
                        .padding(.vertical, 10)
                        .background(index % 2 == 0 ? .clear : .quaternary.opacity(0.3))
                        
                        // Data cells
                        ForEach(columns.filter(\.isVisible), id: \.name) { column in
                            Text(formatCellValue(row.values[column.name], type: column.type))
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(width: column.width)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(index % 2 == 0 ? .clear : .quaternary.opacity(0.3))
                                .overlay(
                                    Rectangle()
                                        .fill(.separator)
                                        .frame(width: 1)
                                        .frame(maxHeight: .infinity),
                                    alignment: .trailing
                                )
                        }
                    }
                    .overlay(
                        Rectangle()
                            .fill(.separator.opacity(0.5))
                            .frame(height: 1),
                        alignment: .bottom
                    )
                }
            }
        }
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            Text("\(filteredRows.count) rows")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Pagination
            HStack(spacing: 8) {
                Button(action: { currentPage = max(0, currentPage - 1) }) {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                }
                .disabled(currentPage == 0)
                
                Text("Page \(currentPage + 1) of \(totalPages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button(action: { currentPage = min(totalPages - 1, currentPage + 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .disabled(currentPage >= totalPages - 1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .fill(.separator)
                .frame(height: 1),
            alignment: .top
        )
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "tablecells.badge.ellipsis")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text("No Data Available")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("Load a dataset to view and analyze your data in this interactive table.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)
            
            Button("Load Sample Data") {
                loadSampleData()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Loading State
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading data...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Column Settings Sheet
    
    private var columnSettingsView: some View {
        NavigationView {
            List {
                ForEach(columns.indices, id: \.self) { index in
                    HStack {
                        Image(systemName: columns[index].type.icon)
                            .foregroundStyle(columns[index].type.color)
                        
                        VStack(alignment: .leading) {
                            Text(columns[index].name)
                                .fontWeight(.medium)
                            Text(columns[index].type.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $columns[index].isVisible)
                    }
                }
            }
            .navigationTitle("Column Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingColumnSettings = false
                        filterData()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadSampleData() {
        isLoading = true
        
        // Simulate loading delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Sample columns
            columns = [
                DataFrameColumn(name: "ID", type: .number, width: 80),
                DataFrameColumn(name: "Name", type: .string, width: 150),
                DataFrameColumn(name: "Age", type: .number, width: 80),
                DataFrameColumn(name: "Email", type: .string, width: 200),
                DataFrameColumn(name: "Active", type: .boolean, width: 80),
                DataFrameColumn(name: "Created", type: .date, width: 120),
                DataFrameColumn(name: "Revenue", type: .number, width: 100)
            ]
            
            // Sample data
            let sampleNames = ["Alice Johnson", "Bob Smith", "Carol Davis", "David Wilson", "Eva Brown", "Frank Miller", "Grace Lee", "Henry Taylor", "Ivy Chen", "Jack Anderson"]
            let domains = ["gmail.com", "yahoo.com", "outlook.com", "company.com"]
            
            rows = (1...100).map { i in
                let name = sampleNames[i % sampleNames.count]
                let firstName = name.components(separatedBy: " ").first?.lowercased() ?? "user"
                let domain = domains[i % domains.count]
                
                return DataFrameRow(values: [
                    "ID": i,
                    "Name": name,
                    "Age": Int.random(in: 22...65),
                    "Email": "\(firstName)\(i)@\(domain)",
                    "Active": Bool.random(),
                    "Created": Calendar.current.date(byAdding: .day, value: -Int.random(in: 0...365), to: Date()) ?? Date(),
                    "Revenue": Double.random(in: 1000...50000)
                ])
            }
            
            filteredRows = rows
            isLoading = false
        }
    }
    
    private func filterData() {
        if searchText.isEmpty {
            filteredRows = rows
        } else {
            filteredRows = rows.filter { row in
                row.values.values.contains { value in
                    String(describing: value).localizedCaseInsensitiveContains(searchText)
                }
            }
        }
        currentPage = 0
        applySorting()
    }
    
    private func sortBy(column: String) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
        applySorting()
    }
    
    private func applySorting() {
        guard let sortColumn = sortColumn else { return }
        
        filteredRows.sort { row1, row2 in
            let value1 = row1.values[sortColumn]
            let value2 = row2.values[sortColumn]
            
            let comparison: Bool
            
            if let num1 = value1 as? Double, let num2 = value2 as? Double {
                comparison = num1 < num2
            } else if let int1 = value1 as? Int, let int2 = value2 as? Int {
                comparison = int1 < int2
            } else if let date1 = value1 as? Date, let date2 = value2 as? Date {
                comparison = date1 < date2
            } else if let bool1 = value1 as? Bool, let bool2 = value2 as? Bool {
                comparison = !bool1 && bool2
            } else {
                let str1 = String(describing: value1 ?? "")
                let str2 = String(describing: value2 ?? "")
                comparison = str1 < str2
            }
            
            return sortAscending ? comparison : !comparison
        }
    }
    
    private func formatCellValue(_ value: Any?, type: DataFrameColumn.DataType) -> String {
        guard let value = value else { return "" }
        
        switch type {
        case .number:
            if let double = value as? Double {
                return String(format: "%.2f", double)
            } else if let int = value as? Int {
                return "\(int)"
            }
        case .date:
            if let date = value as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                return formatter.string(from: date)
            }
        case .boolean:
            if let bool = value as? Bool {
                return bool ? "✓" : "✗"
            }
        case .string:
            return String(describing: value)
        }
        
        return String(describing: value)
    }
    
    private func toggleRowSelection(_ id: UUID) {
        if selectedRows.contains(id) {
            selectedRows.remove(id)
        } else {
            selectedRows.insert(id)
        }
    }
    
    private func toggleSelectAll() {
        if selectedRows.count == displayedRows.count {
            selectedRows.removeAll()
        } else {
            selectedRows = Set(displayedRows.map(\.id))
        }
    }
    
    private func clearSelection() {
        selectedRows.removeAll()
    }
    
    private func exportData() {
        // Export functionality would go here
        print("Exporting \(selectedRows.count) selected rows")
    }
}

#Preview {
    DataFrameView()
}
