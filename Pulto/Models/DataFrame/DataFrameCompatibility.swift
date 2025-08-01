//
//  DataFrameCompatibility.swift
//  Pulto
//
//  Compatibility layer for legacy DataFrameData structure
//

import Foundation

// MARK: - Enhanced Data Processing Extensions

extension DataFrameModel {
    
    // MARK: - Advanced Operations
    
    func groupBy(column: String) -> [String: DataFrameModel] {
        guard let columnIndex = getColumnIndex(named: column) else { return [:] }
        
        let groupedIndices = Dictionary(grouping: 0..<rowCount) { rowIndex in
            columns[columnIndex].values[rowIndex]
        }
        
        var result: [String: DataFrameModel] = [:]
        
        for (groupValue, indices) in groupedIndices {
            let groupedDataFrame = DataFrameModel(name: "\(name) - \(groupValue)")
            
            for column in columns {
                var newColumn = column
                newColumn.values = indices.map { column.values[$0] }
                groupedDataFrame.columns.append(newColumn)
            }
            
            result[groupValue] = groupedDataFrame
        }
        
        return result
    }
    
    func aggregate(column: String, function: AggregateFunction) -> Double? {
        guard let columnIndex = getColumnIndex(named: column),
              columns[columnIndex].dataType == .integer || columns[columnIndex].dataType == .double else {
            return nil
        }
        
        let numericValues = columns[columnIndex].values.compactMap { Double($0) }
        guard !numericValues.isEmpty else { return nil }
        
        switch function {
        case .sum:
            return numericValues.reduce(0, +)
        case .mean:
            return numericValues.reduce(0, +) / Double(numericValues.count)
        case .median:
            let sorted = numericValues.sorted()
            let count = sorted.count
            if count % 2 == 0 {
                return (sorted[count/2 - 1] + sorted[count/2]) / 2.0
            } else {
                return sorted[count/2]
            }
        case .min:
            return numericValues.min()
        case .max:
            return numericValues.max()
        case .standardDeviation:
            let mean = numericValues.reduce(0, +) / Double(numericValues.count)
            let variance = numericValues.reduce(0) { $0 + pow($1 - mean, 2) } / Double(numericValues.count)
            return sqrt(variance)
        }
    }
    
    func pivot(index: String, columns: String, values: String) -> DataFrameModel? {
        // Simplified pivot implementation
        guard let indexColumnIndex = getColumnIndex(named: index),
              let columnsColumnIndex = getColumnIndex(named: columns),
              let valuesColumnIndex = getColumnIndex(named: values) else {
            return nil
        }
        
        // Get unique values for pivot columns
        let uniqueIndexValues = Set(self.columns[indexColumnIndex].values).sorted()
        let uniqueColumnValues = Set(self.columns[columnsColumnIndex].values).sorted()
        
        let pivotedDataFrame = DataFrameModel(name: "\(name) - Pivoted")
        
        // Create index column
        let indexColumn = DataColumn(name: index, dataType: .string, values: uniqueIndexValues)
        pivotedDataFrame.columns.append(indexColumn)
        
        // Create pivot columns
        for columnValue in uniqueColumnValues {
            var pivotValues: [String] = []
            
            for indexValue in uniqueIndexValues {
                // Find matching value
                var foundValue = ""
                for rowIndex in 0..<rowCount {
                    if self.columns[indexColumnIndex].values[rowIndex] == indexValue &&
                       self.columns[columnsColumnIndex].values[rowIndex] == columnValue {
                        foundValue = self.columns[valuesColumnIndex].values[rowIndex]
                        break
                    }
                }
                pivotValues.append(foundValue)
            }
            
            let pivotColumn = DataColumn(name: columnValue, dataType: .string, values: pivotValues)
            pivotedDataFrame.columns.append(pivotColumn)
        }
        
        return pivotedDataFrame
    }
    
    func merge(with other: DataFrameModel, on columnName: String, how: MergeType = .inner) -> DataFrameModel {
        guard let leftColumnIndex = getColumnIndex(named: columnName),
              let rightColumnIndex = other.getColumnIndex(named: columnName) else {
            return DataFrameModel(name: "Merge Failed")
        }
        
        let mergedDataFrame = DataFrameModel(name: "\(name) + \(other.name)")
        
        // Add all columns from left DataFrame
        for column in columns {
            mergedDataFrame.columns.append(column)
        }
        
        // Add columns from right DataFrame (excluding the merge key)
        for rightColumn in other.columns where rightColumn.name != columnName {
            var newColumn = rightColumn
            newColumn.name = "right_\(rightColumn.name)" // Avoid name conflicts
            mergedDataFrame.columns.append(newColumn)
        }
        
        // Perform merge based on type
        switch how {
        case .inner:
            performInnerMerge(mergedDataFrame, other, leftColumnIndex, rightColumnIndex, columnName)
        case .left:
            performLeftMerge(mergedDataFrame, other, leftColumnIndex, rightColumnIndex, columnName)
        case .right:
            performRightMerge(mergedDataFrame, other, leftColumnIndex, rightColumnIndex, columnName)
        case .outer:
            performOuterMerge(mergedDataFrame, other, leftColumnIndex, rightColumnIndex, columnName)
        }
        
        return mergedDataFrame
    }
    
    // MARK: - Data Quality Functions
    
    func detectDuplicates() -> [Int] {
        var seen = Set<[String]>()
        var duplicateIndices: [Int] = []
        
        for rowIndex in 0..<rowCount {
            let row = columns.map { column in
                rowIndex < column.values.count ? column.values[rowIndex] : ""
            }
            
            if seen.contains(row) {
                duplicateIndices.append(rowIndex)
            } else {
                seen.insert(row)
            }
        }
        
        return duplicateIndices
    }
    
    func removeDuplicates() -> DataFrameModel {
        let duplicateIndices = Set(detectDuplicates())
        let cleanedDataFrame = DataFrameModel(name: "\(name) - No Duplicates")
        
        for column in columns {
            var newColumn = column
            newColumn.values = []
            
            for (index, value) in column.values.enumerated() {
                if !duplicateIndices.contains(index) {
                    newColumn.values.append(value)
                }
            }
            
            cleanedDataFrame.columns.append(newColumn)
        }
        
        return cleanedDataFrame
    }
    
    func fillNullValues(strategy: FillStrategy) -> DataFrameModel {
        let filledDataFrame = DataFrameModel(name: "\(name) - Filled")
        
        for column in columns {
            var newColumn = column
            
            switch strategy {
            case .mean:
                if column.dataType == .integer || column.dataType == .double {
                    let numericValues = column.values.compactMap { Double($0) }
                    let meanValue = numericValues.isEmpty ? 0 : numericValues.reduce(0, +) / Double(numericValues.count)
                    newColumn.values = column.values.map { $0.isEmpty ? String(meanValue) : $0 }
                }
            case .median:
                if column.dataType == .integer || column.dataType == .double {
                    let numericValues = column.values.compactMap { Double($0) }.sorted()
                    let median = numericValues.isEmpty ? 0 : 
                        (numericValues.count % 2 == 0 ? 
                         (numericValues[numericValues.count/2 - 1] + numericValues[numericValues.count/2]) / 2 :
                         numericValues[numericValues.count/2])
                    newColumn.values = column.values.map { $0.isEmpty ? String(median) : $0 }
                }
            case .mode:
                let frequency = Dictionary(grouping: column.values.filter { !$0.isEmpty }) { $0 }
                let mode = frequency.max(by: { $0.value.count < $1.value.count })?.key ?? column.dataType.defaultValue
                newColumn.values = column.values.map { $0.isEmpty ? mode : $0 }
            case .forward:
                var lastValue = column.dataType.defaultValue
                newColumn.values = column.values.map { value in
                    if value.isEmpty {
                        return lastValue
                    } else {
                        lastValue = value
                        return value
                    }
                }
            case .backward:
                newColumn.values = column.values
                for i in stride(from: newColumn.values.count - 1, through: 0, by: -1) {
                    if newColumn.values[i].isEmpty {
                        for j in i+1..<newColumn.values.count {
                            if !newColumn.values[j].isEmpty {
                                newColumn.values[i] = newColumn.values[j]
                                break
                            }
                        }
                    }
                }
            case .constant(let value):
                newColumn.values = column.values.map { $0.isEmpty ? value : $0 }
            }
            
            filledDataFrame.columns.append(newColumn)
        }
        
        return filledDataFrame
    }
    
    // MARK: - Private Merge Helpers
    
    private func performInnerMerge(_ merged: DataFrameModel, _ right: DataFrameModel, _ leftCol: Int, _ rightCol: Int, _ keyColumn: String) {
        // Inner merge implementation
        let rightKeyValues = Set(right.columns[rightCol].values)
        
        for rowIndex in 0..<rowCount {
            let keyValue = columns[leftCol].values[rowIndex]
            if rightKeyValues.contains(keyValue) {
                // Find matching row in right DataFrame
                if let rightRowIndex = right.columns[rightCol].values.firstIndex(of: keyValue) {
                    // Add row data
                    for (colIndex, column) in merged.columns.enumerated() {
                        if colIndex < columns.count {
                            // Left DataFrame columns
                            merged.columns[colIndex].values.append(columns[colIndex].values[rowIndex])
                        } else {
                            // Right DataFrame columns
                            let rightColIndex = colIndex - columns.count
                            if rightColIndex < right.columns.count {
                                merged.columns[colIndex].values.append(right.columns[rightColIndex].values[rightRowIndex])
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func performLeftMerge(_ merged: DataFrameModel, _ right: DataFrameModel, _ leftCol: Int, _ rightCol: Int, _ keyColumn: String) {
        // Left merge implementation (similar to inner but keeps all left rows)
        for rowIndex in 0..<rowCount {
            let keyValue = columns[leftCol].values[rowIndex]
            let rightRowIndex = right.columns[rightCol].values.firstIndex(of: keyValue)
            
            for (colIndex, column) in merged.columns.enumerated() {
                if colIndex < columns.count {
                    // Left DataFrame columns
                    merged.columns[colIndex].values.append(columns[colIndex].values[rowIndex])
                } else {
                    // Right DataFrame columns
                    let rightColIndex = colIndex - columns.count
                    if let rightRow = rightRowIndex, rightColIndex < right.columns.count {
                        merged.columns[colIndex].values.append(right.columns[rightColIndex].values[rightRow])
                    } else {
                        merged.columns[colIndex].values.append("")
                    }
                }
            }
        }
    }
    
    private func performRightMerge(_ merged: DataFrameModel, _ right: DataFrameModel, _ leftCol: Int, _ rightCol: Int, _ keyColumn: String) {
        // Right merge implementation
        for rightRowIndex in 0..<right.rowCount {
            let keyValue = right.columns[rightCol].values[rightRowIndex]
            let leftRowIndex = columns[leftCol].values.firstIndex(of: keyValue)
            
            for (colIndex, column) in merged.columns.enumerated() {
                if colIndex < columns.count {
                    // Left DataFrame columns
                    if let leftRow = leftRowIndex {
                        merged.columns[colIndex].values.append(columns[colIndex].values[leftRow])
                    } else {
                        merged.columns[colIndex].values.append("")
                    }
                } else {
                    // Right DataFrame columns
                    let rightColIndex = colIndex - columns.count
                    if rightColIndex < right.columns.count {
                        merged.columns[colIndex].values.append(right.columns[rightColIndex].values[rightRowIndex])
                    }
                }
            }
        }
    }
    
    private func performOuterMerge(_ merged: DataFrameModel, _ right: DataFrameModel, _ leftCol: Int, _ rightCol: Int, _ keyColumn: String) {
        // Outer merge implementation (combination of left and right)
        performLeftMerge(merged, right, leftCol, rightCol, keyColumn)
        
        // Add right-only rows
        let leftKeyValues = Set(columns[leftCol].values)
        for rightRowIndex in 0..<right.rowCount {
            let keyValue = right.columns[rightCol].values[rightRowIndex]
            if !leftKeyValues.contains(keyValue) {
                for (colIndex, column) in merged.columns.enumerated() {
                    if colIndex < columns.count {
                        merged.columns[colIndex].values.append("")
                    } else {
                        let rightColIndex = colIndex - columns.count
                        if rightColIndex < right.columns.count {
                            merged.columns[colIndex].values.append(right.columns[rightColIndex].values[rightRowIndex])
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Enums

enum AggregateFunction {
    case sum, mean, median, min, max, standardDeviation
}

enum MergeType {
    case inner, left, right, outer
}

enum FillStrategy {
    case mean, median, mode, forward, backward, constant(String)
}