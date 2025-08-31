//
//  EnhancedDataFrameTypes.swift
//  Pulto
//
//  New enhanced DataFrame types to avoid conflicts with existing implementations
//

import Foundation
import SwiftUI
import Combine

// MARK: - Enhanced DataFrame Data Structure

struct EnhancedDataFrameData: Codable, Hashable {
    var columns: [String]
    var rows: [[String]]
    var dtypes: [String: String]
    var metadata: EnhancedDataFrameMetadata
    
    var shapeRows: Int { rows.count }
    var shapeColumns: Int { columns.count }
    var shape: (Int, Int) { (shapeRows, shapeColumns) }
    var isEmpty: Bool { rows.isEmpty || columns.isEmpty }
    
    init(columns: [String] = [], rows: [[String]] = [], dtypes: [String: String] = [:], metadata: EnhancedDataFrameMetadata = EnhancedDataFrameMetadata()) {
        self.columns = columns
        self.rows = rows
        self.dtypes = dtypes
        self.metadata = metadata
    }
    
    // MARK: - Hashable conformance
    static func == (lhs: EnhancedDataFrameData, rhs: EnhancedDataFrameData) -> Bool {
        return lhs.columns == rhs.columns && 
               lhs.rows == rhs.rows && 
               lhs.dtypes == rhs.dtypes
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(columns)
        hasher.combine(rows)
        hasher.combine(dtypes)
    }
    
    // MARK: - Conversion Methods
    
    func toDataFrameModel() -> EnhancedDataFrameModel {
        return EnhancedDataFrameModel(from: self)
    }
    
    static func from(_ dataFrameModel: EnhancedDataFrameModel) -> EnhancedDataFrameData {
        return dataFrameModel.toEnhancedDataFrameData()
    }
    
    // Convert to legacy format for compatibility
    func toLegacyDataFrameData() -> DataFrameData {
        return DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
    }
    
    static func fromLegacy(_ legacy: DataFrameData) -> EnhancedDataFrameData {
        return EnhancedDataFrameData(
            columns: legacy.columns,
            rows: legacy.rows,
            dtypes: legacy.dtypes
        )
    }
    
    // MARK: - Export Methods
    
    func toPandasCode() -> String {
        return toDataFrameModel().toPythonCode()
    }
    
    func toCSVString() -> String {
        return toDataFrameModel().toCSV()
    }
}

// MARK: - Enhanced DataFrame Model

class EnhancedDataFrameModel: ObservableObject, Codable {
    @Published var name: String
    @Published var columns: [EnhancedDataColumn]
    @Published var metadata: EnhancedDataFrameMetadata
    @Published var history: [EnhancedDataFrameOperation] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    // Computed properties
    var rowCount: Int { columns.first?.values.count ?? 0 }
    var columnCount: Int { columns.count }
    var shape: (rows: Int, columns: Int) { (rowCount, columnCount) }
    var isEmpty: Bool { rowCount == 0 || columnCount == 0 }
    
    // MARK: - Initialization
    
    init(name: String = "Enhanced DataFrame", columns: [EnhancedDataColumn] = [], metadata: EnhancedDataFrameMetadata = EnhancedDataFrameMetadata()) {
        self.name = name
        self.columns = columns
        self.metadata = metadata
        setupValidation()
    }
    
    convenience init(from legacyData: DataFrameData) {
        self.init(name: "Converted DataFrame")
        
        for (index, columnName) in legacyData.columns.enumerated() {
            let columnValues = legacyData.rows.map { row in
                index < row.count ? row[index] : ""
            }
            
            let dataType: EnhancedDataType
            if let dtypeString = legacyData.dtypes[columnName] {
                switch dtypeString.lowercased() {
                case "int", "integer":
                    dataType = .integer
                case "float", "double", "numeric":
                    dataType = .double
                case "bool", "boolean":
                    dataType = .boolean
                case "date", "datetime":
                    dataType = .date
                case "category", "categorical":
                    dataType = .categorical
                default:
                    dataType = .string
                }
            } else {
                dataType = EnhancedDataTypeConverter.inferType(from: columnValues)
            }
            
            let column = EnhancedDataColumn(name: columnName, dataType: dataType, values: columnValues)
            columns.append(column)
        }
    }
    
    convenience init(from enhancedData: EnhancedDataFrameData) {
        self.init(name: "Enhanced DataFrame", metadata: enhancedData.metadata)
        
        for (index, columnName) in enhancedData.columns.enumerated() {
            let columnValues = enhancedData.rows.map { row in
                index < row.count ? row[index] : ""
            }
            
            let dataType: EnhancedDataType
            if let dtypeString = enhancedData.dtypes[columnName] {
                switch dtypeString.lowercased() {
                case "int", "integer":
                    dataType = .integer
                case "float", "double", "numeric":
                    dataType = .double
                case "bool", "boolean":
                    dataType = .boolean
                case "date", "datetime":
                    dataType = .date
                case "category", "categorical":
                    dataType = .categorical
                default:
                    dataType = .string
                }
            } else {
                dataType = EnhancedDataTypeConverter.inferType(from: columnValues)
            }
            
            let column = EnhancedDataColumn(name: columnName, dataType: dataType, values: columnValues)
            columns.append(column)
        }
    }
    
    // MARK: - Export Functions (moved from extension)
    
    func toCSV(delimiter: String = ",") -> String {
        guard !columns.isEmpty else { return "" }
        
        var csv = columns.map { $0.name }.joined(separator: delimiter) + "\n"
        
        for rowIndex in 0..<rowCount {
            let rowValues = columns.map { column in
                rowIndex < column.values.count ? column.values[rowIndex] : ""
            }
            csv += rowValues.joined(separator: delimiter) + "\n"
        }
        
        return csv
    }
    
    func toPythonCode() -> String {
        guard !columns.isEmpty else {
            return "import pandas as pd\n\n# Empty DataFrame\ndf = pd.DataFrame()\nprint(df)"
        }
        
        var code = "import pandas as pd\nimport numpy as np\nfrom datetime import datetime\n\n"
        code += "# Enhanced DataFrame: \(name)\n"
        code += "# Shape: \(rowCount) rows × \(columnCount) columns\n"
        code += "# Created: \(metadata.created)\n\n"
        
        // Create data dictionary
        code += "data = {\n"
        for (index, column) in columns.enumerated() {
            let columnData = column.values.map { value in
                switch column.dataType {
                case .string, .categorical, .date:
                    return "'\(value)'"
                case .integer, .double:
                    return value.isEmpty ? "np.nan" : value
                case .boolean:
                    return value.lowercased() == "true" ? "True" : "False"
                }
            }.joined(separator: ", ")
            
            code += "    '\(column.name)': [\(columnData)]"
            code += index == columns.count - 1 ? "\n" : ",\n"
        }
        code += "}\n\n"
        
        // Create DataFrame
        code += "df = pd.DataFrame(data)\n\n"
        
        // Set data types
        code += "# Set appropriate data types\n"
        for column in columns {
            switch column.dataType {
            case .integer:
                code += "df['\(column.name)'] = pd.to_numeric(df['\(column.name)'], errors='coerce').astype('Int64')\n"
            case .double:
                code += "df['\(column.name)'] = pd.to_numeric(df['\(column.name)'], errors='coerce')\n"
            case .boolean:
                code += "df['\(column.name)'] = df['\(column.name)'].astype('boolean')\n"
            case .date:
                code += "df['\(column.name)'] = pd.to_datetime(df['\(column.name)'], errors='coerce')\n"
            case .categorical:
                code += "df['\(column.name)'] = df['\(column.name)'].astype('category')\n"
            case .string:
                code += "df['\(column.name)'] = df['\(column.name)'].astype('string')\n"
            }
        }
        
        code += "\n# Display DataFrame info\n"
        code += "print(f\"Enhanced DataFrame Shape: {df.shape}\")\n"
        code += "print(f\"Data Types:\")\n"
        code += "print(df.dtypes)\n"
        code += "print(f\"\\nFirst 10 rows:\")\n"
        code += "print(df.head(10))\n"
        code += "print(f\"\\nStatistical Summary:\")\n"
        code += "print(df.describe(include='all'))\n\n"
        code += "# The Enhanced DataFrame is now ready for analysis\n"
        code += "df"
        
        return code
    }
    
    // MARK: - Data Access
    
    func getValue(row: Int, column: Int) -> String? {
        guard column < columns.count, row < columns[column].values.count else { return nil }
        return columns[column].values[row]
    }
    
    func setValue(_ value: String, row: Int, column: Int) {
        guard column < columns.count, row < columns[column].values.count else { return }
        let oldValue = columns[column].values[row]
        columns[column].values[row] = value
        
        recordOperation(.update, description: "Updated cell [\(row), \(column)] from '\(oldValue)' to '\(value)'")
    }
    
    func getColumn(named name: String) -> EnhancedDataColumn? {
        return columns.first { $0.name == name }
    }
    
    func getColumnIndex(named name: String) -> Int? {
        return columns.firstIndex { $0.name == name }
    }
    
    // MARK: - Data Manipulation
    
    func addColumn(_ column: EnhancedDataColumn) {
        var newColumn = column
        // Ensure the column has the right number of rows
        if newColumn.values.count < rowCount {
            newColumn.values.append(contentsOf: Array(repeating: newColumn.dataType.defaultValue, count: rowCount - newColumn.values.count))
        }
        columns.append(newColumn)
        recordOperation(.insert, description: "Added column '\(column.name)'")
    }
    
    func insertColumn(_ column: EnhancedDataColumn, at index: Int) {
        var newColumn = column
        // Ensure the column has the right number of rows
        if newColumn.values.count < rowCount {
            newColumn.values.append(contentsOf: Array(repeating: newColumn.dataType.defaultValue, count: rowCount - newColumn.values.count))
        }
        columns.insert(newColumn, at: min(index, columns.count))
        recordOperation(.insert, description: "Inserted column '\(column.name)' at index \(index)")
    }
    
    func removeColumn(at index: Int) {
        guard index < columns.count else { return }
        let columnName = columns[index].name
        columns.remove(at: index)
        recordOperation(.delete, description: "Removed column '\(columnName)'")
    }
    
    func addRow(values: [String] = []) {
        let newRowValues = values.isEmpty ? columns.map { $0.dataType.defaultValue } : values
        
        for (index, column) in columns.enumerated() {
            let value = index < newRowValues.count ? newRowValues[index] : column.dataType.defaultValue
            columns[index].values.append(value)
        }
        recordOperation(.insert, description: "Added new row")
    }
    
    func insertRow(at rowIndex: Int, values: [String] = []) {
        let insertIndex = min(rowIndex, rowCount)
        let newRowValues = values.isEmpty ? columns.map { $0.dataType.defaultValue } : values
        
        for (index, column) in columns.enumerated() {
            let value = index < newRowValues.count ? newRowValues[index] : column.dataType.defaultValue
            columns[index].values.insert(value, at: insertIndex)
        }
        recordOperation(.insert, description: "Inserted row at index \(insertIndex)")
    }
    
    func removeRow(at index: Int) {
        guard index < rowCount else { return }
        
        for columnIndex in columns.indices {
            columns[columnIndex].values.remove(at: index)
        }
        recordOperation(.delete, description: "Removed row at index \(index)")
    }
    
    // MARK: - Sorting
    
    func sort(byColumn columnName: String, ascending: Bool = true) {
        guard let columnIndex = getColumnIndex(named: columnName) else { return }
        
        let column = columns[columnIndex]
        let indices = Array(0..<rowCount)
        
        let sortedIndices: [Int]
        
        switch column.dataType {
        case .integer:
            sortedIndices = indices.sorted { i, j in
                let val1 = Int(columns[columnIndex].values[i]) ?? 0
                let val2 = Int(columns[columnIndex].values[j]) ?? 0
                return ascending ? val1 < val2 : val1 > val2
            }
        case .double:
            sortedIndices = indices.sorted { i, j in
                let val1 = Double(columns[columnIndex].values[i]) ?? 0.0
                let val2 = Double(columns[columnIndex].values[j]) ?? 0.0
                return ascending ? val1 < val2 : val1 > val2
            }
        case .date:
            let formatter = ISO8601DateFormatter()
            sortedIndices = indices.sorted { i, j in
                let val1 = formatter.date(from: columns[columnIndex].values[i]) ?? Date.distantPast
                let val2 = formatter.date(from: columns[columnIndex].values[j]) ?? Date.distantPast
                return ascending ? val1 < val2 : val1 > val2
            }
        default:
            sortedIndices = indices.sorted { i, j in
                let val1 = columns[columnIndex].values[i]
                let val2 = columns[columnIndex].values[j]
                return ascending ? val1 < val2 : val1 > val2
            }
        }
        
        // Reorder all columns based on sorted indices
        for columnIdx in columns.indices {
            columns[columnIdx].values = sortedIndices.map { columns[columnIdx].values[$0] }
        }
        
        recordOperation(.sort, description: "Sorted by column '\(columnName)' (\(ascending ? "ascending" : "descending"))")
    }
    
    // MARK: - Filtering
    
    func filter(predicate: (Int) -> Bool) -> EnhancedDataFrameModel {
        let filteredDataFrame = EnhancedDataFrameModel(name: "\(name) (filtered)")
        
        for column in columns {
            var newColumn = column
            newColumn.values = []
            
            for (index, _) in column.values.enumerated() {
                if predicate(index) {
                    newColumn.values.append(column.values[index])
                }
            }
            
            filteredDataFrame.columns.append(newColumn)
        }
        
        return filteredDataFrame
    }
    
    // MARK: - Codable Support
    
    enum CodingKeys: String, CodingKey {
        case name, columns, metadata, history
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.columns = try container.decode([EnhancedDataColumn].self, forKey: .columns)
        self.metadata = try container.decode(EnhancedDataFrameMetadata.self, forKey: .metadata)
        self.history = try container.decodeIfPresent([EnhancedDataFrameOperation].self, forKey: .history) ?? []
        setupValidation()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(columns, forKey: .columns)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(history, forKey: .history)
    }
    
    // MARK: - Private Setup
    
    private func setupValidation() {
        $columns
            .sink { [weak self] _ in
                self?.validateDataConsistency()
            }
            .store(in: &cancellables)
    }
    
    private func validateDataConsistency() {
        let expectedRowCount = rowCount
        for column in columns {
            if column.values.count != expectedRowCount {
            }
        }
        updateMetadata()
    }
    
    private func updateMetadata() {
        metadata.lastModified = Date()
        metadata.rowCount = rowCount
        metadata.columnCount = columnCount
        metadata.memoryUsage = estimateMemoryUsage()
    }
    
    private func estimateMemoryUsage() -> Int {
        return columns.reduce(0) { total, column in
            total + column.values.reduce(0) { $0 + $1.count * 8 }
        }
    }
    
    // MARK: - Conversion Methods
    
    func toEnhancedDataFrameData() -> EnhancedDataFrameData {
        let columnNames = columns.map { $0.name }
        let rows = (0..<rowCount).map { rowIndex in
            columns.map { column in
                rowIndex < column.values.count ? column.values[rowIndex] : ""
            }
        }
        let dtypes = columns.reduce(into: [String: String]()) { result, column in
            result[column.name] = column.dataType.rawValue
        }
        
        return EnhancedDataFrameData(columns: columnNames, rows: rows, dtypes: dtypes, metadata: metadata)
    }
    
    func toLegacyDataFrameData() -> DataFrameData {
        let columnNames = columns.map { $0.name }
        let rows = (0..<rowCount).map { rowIndex in
            columns.map { column in
                rowIndex < column.values.count ? column.values[rowIndex] : ""
            }
        }
        let dtypes = columns.reduce(into: [String: String]()) { result, column in
            result[column.name] = column.dataType.rawValue
        }
        
        return DataFrameData(columns: columnNames, rows: rows, dtypes: dtypes)
    }
    
    // MARK: - Operation Recording
    
    private func recordOperation(_ type: EnhancedDataFrameOperation.EnhancedOperationType, description: String, parameters: [String: String] = [:]) {
        let operation = EnhancedDataFrameOperation(
            timestamp: Date(),
            type: type,
            description: description,
            parameters: parameters
        )
        history.append(operation)
        
        // Keep only last 100 operations to prevent memory bloat
        if history.count > 100 {
            history.removeFirst(history.count - 100)
        }
    }
}

// MARK: - Enhanced Data Column

struct EnhancedDataColumn: Codable, Identifiable {
    let id = UUID()
    var name: String
    var dataType: EnhancedDataType
    var values: [String]
    var metadata: EnhancedColumnMetadata
    
    init(name: String, dataType: EnhancedDataType = .string, values: [String] = [], metadata: EnhancedColumnMetadata = EnhancedColumnMetadata()) {
        self.name = name
        self.dataType = dataType
        self.values = values
        self.metadata = metadata
    }
    
    // Statistics
    var statistics: EnhancedColumnStatistics {
        EnhancedColumnStatistics.compute(for: self)
    }
    
    // Validation
    var isValid: Bool {
        switch dataType {
        case .integer:
            return values.allSatisfy { Int($0) != nil || $0.isEmpty }
        case .double:
            return values.allSatisfy { Double($0) != nil || $0.isEmpty }
        case .boolean:
            return values.allSatisfy { 
                $0.lowercased() == "true" || $0.lowercased() == "false" || $0.isEmpty
            }
        case .date:
            let formatter = ISO8601DateFormatter()
            return values.allSatisfy { formatter.date(from: $0) != nil || $0.isEmpty }
        case .string, .categorical:
            return true
        }
    }
    
    // Type conversion
    func converted(to newType: EnhancedDataType) -> EnhancedDataColumn {
        var newColumn = self
        newColumn.dataType = newType
        newColumn.values = values.map { EnhancedDataTypeConverter.convert($0, from: dataType, to: newType) }
        return newColumn
    }
    
    // MARK: - Codable conformance
    enum CodingKeys: String, CodingKey {
        case name, dataType, values, metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.dataType = try container.decode(EnhancedDataType.self, forKey: .dataType)
        self.values = try container.decode([String].self, forKey: .values)
        self.metadata = try container.decode(EnhancedColumnMetadata.self, forKey: .metadata)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(dataType, forKey: .dataType)
        try container.encode(values, forKey: .values)
        try container.encode(metadata, forKey: .metadata)
    }
}

// Hashable conformance for EnhancedDataColumn
extension EnhancedDataColumn: Hashable {
    static func == (lhs: EnhancedDataColumn, rhs: EnhancedDataColumn) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Enhanced Data Types

enum EnhancedDataType: String, CaseIterable, Codable {
    case string = "string"
    case integer = "int"
    case double = "float"
    case boolean = "bool"
    case date = "date"
    case categorical = "category"
    
    var displayName: String {
        switch self {
        case .string: return "Text"
        case .integer: return "Integer"
        case .double: return "Number"
        case .boolean: return "Boolean"
        case .date: return "Date"
        case .categorical: return "Category"
        }
    }
    
    var icon: String {
        switch self {
        case .string: return "textformat"
        case .integer, .double: return "number"
        case .boolean: return "checkmark.square"
        case .date: return "calendar"
        case .categorical: return "list.bullet"
        }
    }
    
    var defaultValue: String {
        switch self {
        case .string, .categorical: return ""
        case .integer: return "0"
        case .double: return "0.0"
        case .boolean: return "false"
        case .date: return ISO8601DateFormatter().string(from: Date())
        }
    }
}

// MARK: - Enhanced Metadata Models

struct EnhancedDataFrameMetadata: Codable, Hashable {
    var created: Date = Date()
    var lastModified: Date = Date()
    var source: String?
    var encoding: String = "UTF-8"
    var delimiter: String?
    var hasHeaders: Bool = true
    var rowCount: Int = 0
    var columnCount: Int = 0
    var memoryUsage: Int = 0
    var tags: [String] = []
    var notes: String = ""
    
    // Hashable conformance
    static func == (lhs: EnhancedDataFrameMetadata, rhs: EnhancedDataFrameMetadata) -> Bool {
        return lhs.source == rhs.source &&
               lhs.encoding == rhs.encoding &&
               lhs.delimiter == rhs.delimiter &&
               lhs.hasHeaders == rhs.hasHeaders &&
               lhs.rowCount == rhs.rowCount &&
               lhs.columnCount == rhs.columnCount &&
               lhs.tags == rhs.tags &&
               lhs.notes == rhs.notes
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(source)
        hasher.combine(encoding)
        hasher.combine(delimiter)
        hasher.combine(hasHeaders)
        hasher.combine(rowCount)
        hasher.combine(columnCount)
        hasher.combine(tags)
        hasher.combine(notes)
    }
}

struct EnhancedColumnMetadata: Codable, Hashable {
    var description: String = ""
    var unit: String?
    var format: String?
    var nullable: Bool = true
    var unique: Bool = false
    var primaryKey: Bool = false
    var foreignKey: String?
    var categories: [String] = []
    var range: (min: Double?, max: Double?) = (nil, nil)
    
    // Hashable conformance
    static func == (lhs: EnhancedColumnMetadata, rhs: EnhancedColumnMetadata) -> Bool {
        return lhs.description == rhs.description &&
               lhs.unit == rhs.unit &&
               lhs.format == rhs.format &&
               lhs.nullable == rhs.nullable &&
               lhs.unique == rhs.unique &&
               lhs.primaryKey == rhs.primaryKey &&
               lhs.foreignKey == rhs.foreignKey &&
               lhs.categories == rhs.categories
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(description)
        hasher.combine(unit)
        hasher.combine(format)
        hasher.combine(nullable)
        hasher.combine(unique)
        hasher.combine(primaryKey)
        hasher.combine(foreignKey)
        hasher.combine(categories)
    }
    
    enum CodingKeys: String, CodingKey {
        case description, unit, format, nullable, unique, primaryKey, foreignKey, categories
    }
    
    init(description: String = "", unit: String? = nil, format: String? = nil, nullable: Bool = true, unique: Bool = false, primaryKey: Bool = false, foreignKey: String? = nil, categories: [String] = []) {
        self.description = description
        self.unit = unit
        self.format = format
        self.nullable = nullable
        self.unique = unique
        self.primaryKey = primaryKey
        self.foreignKey = foreignKey
        self.categories = categories
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.unit = try container.decodeIfPresent(String.self, forKey: .unit)
        self.format = try container.decodeIfPresent(String.self, forKey: .format)
        self.nullable = try container.decodeIfPresent(Bool.self, forKey: .nullable) ?? true
        self.unique = try container.decodeIfPresent(Bool.self, forKey: .unique) ?? false
        self.primaryKey = try container.decodeIfPresent(Bool.self, forKey: .primaryKey) ?? false
        self.foreignKey = try container.decodeIfPresent(String.self, forKey: .foreignKey)
        self.categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encodeIfPresent(format, forKey: .format)
        try container.encode(nullable, forKey: .nullable)
        try container.encode(unique, forKey: .unique)
        try container.encode(primaryKey, forKey: .primaryKey)
        try container.encodeIfPresent(foreignKey, forKey: .foreignKey)
        try container.encode(categories, forKey: .categories)
    }
}

// MARK: - Enhanced Statistics

struct EnhancedColumnStatistics {
    let nullCount: Int
    let uniqueCount: Int
    let mean: Double?
    let median: Double?
    let mode: String?
    let standardDeviation: Double?
    let min: String?
    let max: String?
    let quartiles: (q1: Double?, q2: Double?, q3: Double?)?
    
    static func compute(for column: EnhancedDataColumn) -> EnhancedColumnStatistics {
        let nonEmptyValues = column.values.filter { !$0.isEmpty }
        let nullCount = column.values.count - nonEmptyValues.count
        let uniqueCount = Set(nonEmptyValues).count
        
        var mean: Double?
        var median: Double?
        var standardDeviation: Double?
        var quartiles: (q1: Double?, q2: Double?, q3: Double?)?
        
        // Compute numeric statistics if possible
        if column.dataType == .integer || column.dataType == .double {
            let numericValues = nonEmptyValues.compactMap { Double($0) }
            if !numericValues.isEmpty {
                mean = numericValues.reduce(0, +) / Double(numericValues.count)
                
                let sorted = numericValues.sorted()
                let count = sorted.count
                if count % 2 == 0 {
                    median = (sorted[count/2 - 1] + sorted[count/2]) / 2.0
                } else {
                    median = sorted[count/2]
                }
                
                if let meanValue = mean {
                    let variance = numericValues.reduce(0) { $0 + pow($1 - meanValue, 2) } / Double(numericValues.count)
                    standardDeviation = sqrt(variance)
                }
                
                // Quartiles
                let q1Index = count / 4
                let q3Index = 3 * count / 4
                quartiles = (
                    q1: count > 3 ? sorted[q1Index] : nil,
                    q2: median,
                    q3: count > 3 ? sorted[q3Index] : nil
                )
            }
        }
        
        // Mode (most frequent value)
        let frequency = Dictionary(grouping: nonEmptyValues) { $0 }.mapValues { $0.count }
        let mode = frequency.max(by: { $0.value < $1.value })?.key
        
        // Min/Max
        let min = nonEmptyValues.min()
        let max = nonEmptyValues.max()
        
        return EnhancedColumnStatistics(
            nullCount: nullCount,
            uniqueCount: uniqueCount,
            mean: mean,
            median: median,
            mode: mode,
            standardDeviation: standardDeviation,
            min: min,
            max: max,
            quartiles: quartiles
        )
    }
}

// MARK: - Enhanced Operation History

struct EnhancedDataFrameOperation: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: EnhancedOperationType
    let description: String
    let parameters: [String: String]
    
    enum EnhancedOperationType: String, Codable {
        case insert, delete, update, sort, filter, dataImport, export, typeChange
    }
    
    enum CodingKeys: String, CodingKey {
        case timestamp, type, description, parameters
    }
    
    init(timestamp: Date, type: EnhancedOperationType, description: String, parameters: [String: String]) {
        self.timestamp = timestamp
        self.type = type
        self.description = description
        self.parameters = parameters
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.type = try container.decode(EnhancedOperationType.self, forKey: .type)
        self.description = try container.decode(String.self, forKey: .description)
        self.parameters = try container.decode([String: String].self, forKey: .parameters)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(type, forKey: .type)
        try container.encode(description, forKey: .description)
        try container.encode(parameters, forKey: .parameters)
    }
}

// MARK: - Enhanced Data Type Converter

struct EnhancedDataTypeConverter {
    static func convert(_ value: String, from sourceType: EnhancedDataType, to targetType: EnhancedDataType) -> String {
        if value.isEmpty { return targetType.defaultValue }
        if sourceType == targetType { return value }
        
        switch (sourceType, targetType) {
        case (.string, .integer):
            return String(Int(value) ?? 0)
        case (.string, .double):
            return String(Double(value) ?? 0.0)
        case (.string, .boolean):
            return value.lowercased() == "true" || value == "1" ? "true" : "false"
        case (.integer, .double):
            return String(Double(value) ?? 0.0)
        case (.integer, .string), (.double, .string), (.boolean, .string), (.date, .string), (.categorical, .string):
            return value
        case (.double, .integer):
            return String(Int(Double(value) ?? 0))
        case (.boolean, .integer):
            return value.lowercased() == "true" ? "1" : "0"
        case (.boolean, .double):
            return value.lowercased() == "true" ? "1.0" : "0.0"
        case (_, .categorical):
            return value
        default:
            return value
        }
    }
    
    static func inferType(from values: [String]) -> EnhancedDataType {
        let nonEmptyValues = values.filter { !$0.isEmpty }
        guard !nonEmptyValues.isEmpty else { return .string }
        
        let totalCount = nonEmptyValues.count
        var integerCount = 0
        var doubleCount = 0
        var booleanCount = 0
        var dateCount = 0
        
        let dateFormatter = ISO8601DateFormatter()
        let alternativeDateFormatter = DateFormatter()
        alternativeDateFormatter.dateFormat = "yyyy-MM-dd"
        
        for value in nonEmptyValues {
            // Check integer
            if Int(value) != nil {
                integerCount += 1
            }
            // Check double
            else if Double(value) != nil {
                doubleCount += 1
            }
            // Check boolean
            else if value.lowercased() == "true" || value.lowercased() == "false" {
                booleanCount += 1
            }
            // Check date
            else if dateFormatter.date(from: value) != nil || alternativeDateFormatter.date(from: value) != nil {
                dateCount += 1
            }
        }
        
        let threshold = 0.8
        
        if Double(integerCount) / Double(totalCount) >= threshold {
            return .integer
        } else if Double(doubleCount + integerCount) / Double(totalCount) >= threshold {
            return .double
        } else if Double(booleanCount) / Double(totalCount) >= threshold {
            return .boolean
        } else if Double(dateCount) / Double(totalCount) >= threshold {
            return .date
        } else {
            // Check if it should be categorical (limited unique values)
            let uniqueCount = Set(nonEmptyValues).count
            if Double(uniqueCount) / Double(totalCount) < 0.5 && uniqueCount < 20 {
                return .categorical
            } else {
                return .string
            }
        }
    }
}