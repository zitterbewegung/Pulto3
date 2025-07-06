import Foundation
import TabularData
import SwiftUI
import RealityKit
import Combine

// MARK: - Enhanced DataFrame Integration

class DataFrameProcessor: ObservableObject {
    @Published var dataFrame: DataFrame?
    @Published var processingProgress: Float = 0
    @Published var isProcessing = false
    
    // MARK: - Real-time Data Processing
    
    func processLargeDataset(from url: URL) async throws {
        await MainActor.run {
            isProcessing = true
            processingProgress = 0
        }
        
        // Load DataFrame in chunks for large datasets
        let dataFrame = try await loadDataFrameInChunks(from: url)
        
        // Apply data transformations
        let processedDataFrame = try await applyRealTimeTransformations(dataFrame)
        
        await MainActor.run {
            self.dataFrame = processedDataFrame
            self.isProcessing = false
            self.processingProgress = 1.0
        }
    }
    
    private func loadDataFrameInChunks(from url: URL) async throws -> DataFrame {
        let chunkSize = 10000
        var combinedDataFrame: DataFrame?
        
        // Read file in chunks
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { fileHandle.closeFile() }
        
        var processedRows = 0
        let totalEstimatedRows = try estimateRowCount(url: url)
        
        while true {
            let chunkData = fileHandle.readData(ofLength: chunkSize * 100) // Approximate chunk size
            if chunkData.isEmpty { break }
            
            // Process chunk
            let chunkDataFrame = try parseDataFrameChunk(chunkData)
            
            if combinedDataFrame == nil {
                combinedDataFrame = chunkDataFrame
            } else {
                combinedDataFrame!.append(chunkDataFrame)
            }
            
            processedRows += chunkDataFrame.rows.count
            
            await MainActor.run {
                self.processingProgress = Float(processedRows) / Float(totalEstimatedRows)
            }
        }
        
        return combinedDataFrame ?? DataFrame()
    }
    
    private func applyRealTimeTransformations(_ dataFrame: DataFrame) async throws -> DataFrame {
        var transformedDataFrame = dataFrame
        
        // Apply statistical transformations
        transformedDataFrame = try await applyStatisticalTransformations(transformedDataFrame)
        
        // Apply spatial transformations
        transformedDataFrame = try await applySpatialTransformations(transformedDataFrame)
        
        return transformedDataFrame
    }
    
    private func applyStatisticalTransformations(_ dataFrame: DataFrame) async throws -> DataFrame {
        var transformed = dataFrame
        
        // Add derived columns
        for column in dataFrame.columns {
            if let numericColumn = column as? Column<Double> {
                // Add normalized version
                let normalizedValues = normalizeColumn(numericColumn)
                let normalizedColumn = Column(name: "\(column.name)_normalized", contents: normalizedValues)
                transformed.append(column: normalizedColumn)
                
                // Add rolling average
                let rollingAverage = calculateRollingAverage(numericColumn, window: 5)
                let rollingColumn = Column(name: "\(column.name)_rolling", contents: rollingAverage)
                transformed.append(column: rollingColumn)
            }
        }
        
        return transformed
    }
    
    private func applySpatialTransformations(_ dataFrame: DataFrame) async throws -> DataFrame {
        var transformed = dataFrame
        
        // Look for spatial columns (x, y, z coordinates)
        let spatialColumns = findSpatialColumns(in: dataFrame)
        
        if spatialColumns.count >= 3 {
            // Calculate spatial derivatives
            let spatialDerivatives = calculateSpatialDerivatives(spatialColumns)
            for (name, values) in spatialDerivatives {
                let column = Column(name: name, contents: values)
                transformed.append(column: column)
            }
        }
        
        return transformed
    }
    
    // MARK: - Helper Methods
    
    private func estimateRowCount(url: URL) throws -> Int {
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as! Int64
        return Int(fileSize / 100) // Rough estimate
    }
    
    private func parseDataFrameChunk(_ data: Data) throws -> DataFrame {
        // Parse CSV chunk or other format
        let string = String(data: data, encoding: .utf8) ?? ""
        
        // Split into lines and parse as CSV
        let lines = string.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return DataFrame() }
        
        // Create a simple DataFrame from the parsed data
        let headers = lines[0].components(separatedBy: ",")
        var columns: [String: [String]] = [:]
        
        for header in headers {
            columns[header] = []
        }
        
        // Parse data rows
        for line in lines.dropFirst() {
            let values = line.components(separatedBy: ",")
            for (index, value) in values.enumerated() {
                if index < headers.count {
                    columns[headers[index]]?.append(value)
                }
            }
        }
        
        // Create DataFrame
        var dataFrame = DataFrame()
        for (header, values) in columns {
            let column = Column(name: header, contents: values)
            dataFrame.append(column: column)
        }
        
        return dataFrame
    }
    
    private func normalizeColumn(_ column: Column<Double>) -> [Double] {
        let values = Array(column).compactMap { $0 } // Remove nil values
        guard !values.isEmpty else { return [] }
        
        let min = values.min() ?? 0
        let max = values.max() ?? 1
        let range = max - min
        
        return values.map { range > 0 ? ($0 - min) / range : 0 }
    }
    
    private func calculateRollingAverage(_ column: Column<Double>, window: Int) -> [Double] {
        let values = Array(column).compactMap { $0 } // Remove nil values
        var rollingAverage: [Double] = []
        
        for i in 0..<values.count {
            let start = max(0, i - window + 1)
            let end = i + 1
            let windowValues = Array(values[start..<end])
            let average = windowValues.reduce(0, +) / Double(windowValues.count)
            rollingAverage.append(average)
        }
        
        return rollingAverage
    }
    
    private func findSpatialColumns(in dataFrame: DataFrame) -> [Column<Double>] {
        let spatialColumnNames = ["x", "y", "z", "lat", "lon", "latitude", "longitude"]
        
        return dataFrame.columns.compactMap { column in
            if let doubleColumn = column as? Column<Double>,
               spatialColumnNames.contains(column.name.lowercased()) {
                return doubleColumn
            }
            return nil
        }
    }
    
    private func calculateSpatialDerivatives(_ spatialColumns: [Column<Double>]) -> [String: [Double]] {
        var derivatives: [String: [Double]] = [:]
        
        if spatialColumns.count >= 3 {
            let xColumn = Array(spatialColumns[0]).compactMap { $0 }
            let yColumn = Array(spatialColumns[1]).compactMap { $0 }
            let zColumn = Array(spatialColumns[2]).compactMap { $0 }
            
            // Calculate velocity (first derivative)
            derivatives["velocity_x"] = calculateDerivative(xColumn)
            derivatives["velocity_y"] = calculateDerivative(yColumn)
            derivatives["velocity_z"] = calculateDerivative(zColumn)
            
            // Calculate magnitude
            let magnitudes = zip(zip(xColumn, yColumn), zColumn).map { xyz in
                let ((x, y), z) = xyz
                return sqrt(x*x + y*y + z*z)
            }
            derivatives["magnitude"] = magnitudes
        }
        
        return derivatives
    }
    
    private func calculateDerivative(_ values: [Double]) -> [Double] {
        var derivatives: [Double] = [0] // First value has no derivative
        
        for i in 1..<values.count {
            derivatives.append(values[i] - values[i-1])
        }
        
        return derivatives
    }
}

// MARK: - Real-time Data Binding

class RealTimeDataBinder: ObservableObject {
    @Published var chartData: [ChartDataPoint] = []
    @Published var spatialEntities: [Entity] = []
    
    private var dataProcessor: DataFrameProcessor
    private var cancellables = Set<AnyCancellable>()
    
    init(dataProcessor: DataFrameProcessor) {
        self.dataProcessor = dataProcessor
        setupBindings()
    }
    
    private func setupBindings() {
        dataProcessor.$dataFrame
            .compactMap { $0 }
            .sink { [weak self] dataFrame in
                self?.updateVisualization(from: dataFrame)
            }
            .store(in: &cancellables)
    }
    
    private func updateVisualization(from dataFrame: DataFrame) {
        // Convert DataFrame to chart data
        updateChartData(from: dataFrame)
        
        // Create spatial entities
        updateSpatialEntities(from: dataFrame)
    }
    
    private func updateChartData(from dataFrame: DataFrame) {
        var newChartData: [ChartDataPoint] = []
        
        // Extract chart data from DataFrame
        for row in dataFrame.rows {
            // Create a simple chart data point from the first few numeric columns
            let numericValues = row.compactMap { element -> Double? in
                if let value = element as? Double {
                    return value
                } else if let value = element as? Int {
                    return Double(value)
                } else if let value = element as? Float {
                    return Double(value)
                }
                return nil
            }
            
            if numericValues.count >= 2 {
                let chartPoint = ChartDataPoint(
                    x: numericValues[0],
                    y: numericValues[1],
                    z: numericValues.count > 2 ? numericValues[2] : nil,
                    category: "data",
                    color: "blue",
                    intensity: numericValues[1]
                )
                newChartData.append(chartPoint)
            }

        }
        
        chartData = newChartData
    }
    
    private func updateSpatialEntities(from dataFrame: DataFrame) {
        // Convert DataFrame rows to spatial entities
        var newEntities: [Entity] = []
        
        for row in dataFrame.rows {
            let entity = createSpatialEntity(from: row)
            newEntities.append(entity)
        }
        
        spatialEntities = newEntities
    }
    
    private func createSpatialEntity(from row: DataFrame.Row) -> Entity {
        let entity = Entity()
        
        // Add basic model component for visualization
        let mesh = MeshResource.generateSphere(radius: 0.01)
        var material = UnlitMaterial()
        material.color = .init(tint: .cyan)
        
        entity.components[ModelComponent.self] = ModelComponent(
            mesh: mesh,
            materials: [material]
        )
        
        // Position based on numeric values in row
        let numericValues = row.compactMap { element -> Float? in
            if let value = element as? Double {
                return Float(value)
            } else if let value = element as? Int {
                return Float(value)
            } else if let value = element as? Float {
                return value
            }
            return nil
        }
        
        if numericValues.count >= 3 {
            entity.position = SIMD3<Float>(numericValues[0], numericValues[1], numericValues[2])
        }
        
        return entity
    }
}