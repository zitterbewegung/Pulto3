//
//  BatchImportManager.swift
//  Pulto3
//
//  Created by AI Assistant on 1/29/25.
//

import SwiftUI
import UniformTypeIdentifiers
import Combine
import RealityKit

// MARK: - Batch Import Manager

@MainActor
class BatchImportManager: ObservableObject {
    static let shared = BatchImportManager()
    
    @Published var isImporting = false
    @Published var importProgress: BatchImportProgress = BatchImportProgress()
    @Published var importHistory: [BatchImportSession] = []
    @Published var showingBatchImporter = false
    
    private let windowManager = WindowTypeManager.shared
    private let fileClassifier = FileClassifier()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Batch Import Session
    
    func startBatchImport(files: [URL]) async {
        guard !isImporting else { return }
        
        let session = BatchImportSession(files: files)
        importHistory.append(session)
        
        isImporting = true
        importProgress = BatchImportProgress(totalFiles: files.count)
        
        await processBatchImport(session: session)
        
        isImporting = false
        importProgress = BatchImportProgress()
    }
    
    private func processBatchImport(session: BatchImportSession) async {
        session.startedAt = Date()
        session.status = .processing
        
        var createdWindows: [Int] = []
        
        for (index, fileURL) in session.files.enumerated() {
            importProgress.currentFileIndex = index
            importProgress.currentFileName = fileURL.lastPathComponent
            importProgress.currentFileStatus = .analyzing
            
            // Analyze file
            let (fileType, csvData, recommendations) = await analyzeFile(fileURL)
            
            importProgress.currentFileStatus = .importing
            
            // Create appropriate window
            do {
                let windowID = try await importSingleFile(
                    url: fileURL,
                    fileType: fileType,
                    csvData: csvData,
                    recommendations: recommendations
                )
                
                if let windowID = windowID {
                    createdWindows.append(windowID)
                    session.successfulImports.append(BatchFileResult(
                        url: fileURL,
                        windowID: windowID,
                        fileType: fileType,
                        status: .success
                    ))
                    importProgress.successCount += 1
                } else {
                    session.failedImports.append(BatchFileResult(
                        url: fileURL,
                        windowID: nil,
                        fileType: fileType,
                        status: .failed(BatchImportError.unsupportedFormat)
                    ))
                    importProgress.failureCount += 1
                }
            } catch {
                session.failedImports.append(BatchFileResult(
                    url: fileURL,
                    windowID: nil,
                    fileType: fileType,
                    status: .failed(error)
                ))
                importProgress.failureCount += 1
            }
            
            importProgress.currentFileStatus = .completed
            
            // Small delay for UI updates
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        session.completedAt = Date()
        session.status = .completed
        session.createdWindows = createdWindows
        
        // Auto-arrange windows if multiple files imported
        if createdWindows.count > 1 {
            await arrangeImportedWindows(createdWindows)
        }
    }
    
    // MARK: - File Analysis
    
    private func analyzeFile(_ url: URL) async -> (FileType, CSVData?, [ChartScore]?) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.fileClassifier.classifyFile(at: url)
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Single File Import
    
    private func importSingleFile(
        url: URL,
        fileType: FileType,
        csvData: CSVData?,
        recommendations: [ChartScore]?
    ) async throws -> Int? {
        
        let windowID = windowManager.getNextWindowID()
        let position = calculateWindowPosition(for: windowID)
        
        switch fileType {
        case .csv(let delimiter):
            guard let csvData = csvData else { throw BatchImportError.invalidData }
            
            // Create chart window if recommendations available
            if let recommendations = recommendations, !recommendations.isEmpty {
                _ = windowManager.createWindow(.charts, id: windowID, position: position)
                
                // Store CSV data and recommendations
                let chartData = createChartDataFromCSV(csvData, recommendation: recommendations.first!.recommendation)
                windowManager.updateWindowChartData(windowID, chartData: chartData)
                windowManager.addWindowTag(windowID, tag: "batch-import")
                windowManager.addWindowTag(windowID, tag: "csv-data")
            } else {
                // Create data table window
                _ = windowManager.createWindow(.column, id: windowID, position: position)
                let dataFrameData = createDataFrameFromCSV(csvData)
                windowManager.updateDataFrame(for: windowID, dataFrame: dataFrameData)
                windowManager.addWindowTag(windowID, tag: "batch-import")
            }
            
            return windowID
            
        case .pointCloudPLY:
            _ = windowManager.createWindow(.pointcloud, id: windowID, position: position)
            
            if let pointCloud = await parsePointCloudFile(url) {
                windowManager.updateWindowPointCloud(windowID, pointCloud: pointCloud)
                windowManager.addWindowTag(windowID, tag: "batch-import")
                return windowID
            }
            throw BatchImportError.parsingFailed
            
        case .usdz:
            _ = windowManager.createWindow(.model3d, id: windowID, position: position)
            
            do {
                let bookmark = try url.bookmarkData(options: .minimalBookmark)
                windowManager.updateUSDZBookmark(for: windowID, bookmark: bookmark)
                windowManager.addWindowTag(windowID, tag: "batch-import")
                return windowID
            } catch {
                throw BatchImportError.bookmarkFailed
            }
            
        case .unknown:
            throw BatchImportError.unsupportedFormat
        }
    }
    
    // MARK: - Window Arrangement
    
    private func arrangeImportedWindows(_ windowIDs: [Int]) async {
        let columns = Int(ceil(sqrt(Double(windowIDs.count))))
        let spacing: Double = 100
        let baseX: Double = -Double(columns) * spacing / 2
        let baseZ: Double = -Double(windowIDs.count / columns) * spacing / 2
        
        for (index, windowID) in windowIDs.enumerated() {
            let row = index / columns
            let col = index % columns
            
            let x = baseX + Double(col) * spacing
            let z = baseZ + Double(row) * spacing
            
            let position = WindowPosition(x: x, y: 0, z: z, width: 800, height: 600)
            windowManager.updateWindowPosition(windowID, position: position)
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateWindowPosition(for windowID: Int) -> WindowPosition {
        let gridSize = 3
        let spacing = 150.0
        let index = windowID % (gridSize * gridSize)
        
        let row = index / gridSize
        let col = index % gridSize
        
        return WindowPosition(
            x: Double(col - 1) * spacing,
            y: 0,
            z: Double(row - 1) * spacing,
            width: 800,
            height: 600
        )
    }
    
    private func createChartDataFromCSV(_ csvData: CSVData, recommendation: ChartRecommendation) -> ChartData {
        let numericIndices = csvData.columnTypes.enumerated().compactMap { index, type in
            type == .numeric ? index : nil
        }
        
        guard numericIndices.count >= 1 else {
            return ChartData(
                title: "Imported Data",
                chartType: "line",
                xLabel: "Index",
                yLabel: "Value",
                xData: [0, 1, 2, 3, 4],
                yData: [1, 2, 3, 4, 5]
            )
        }
        
        let xIndex = 0
        let yIndex = numericIndices[0]
        
        var xData: [Double] = []
        var yData: [Double] = []
        
        for (index, row) in csvData.rows.enumerated() {
            xData.append(Double(index))
            
            if yIndex < row.count, let value = Double(row[yIndex]) {
                yData.append(value)
            } else {
                yData.append(0)
            }
        }
        
        return ChartData(
            title: "Imported \(recommendation.name)",
            chartType: recommendation.rawValue.lowercased(),
            xLabel: csvData.headers.first ?? "Index",
            yLabel: csvData.headers[safe: yIndex] ?? "Value",
            xData: xData,
            yData: yData
        )
    }
    
    private func createDataFrameFromCSV(_ csvData: CSVData) -> DataFrameData {
        var dtypes: [String: String] = [:]
        
        for (index, type) in csvData.columnTypes.enumerated() {
            let columnName = csvData.headers[safe: index] ?? "Column_\(index)"
            switch type {
            case .numeric:
                dtypes[columnName] = "float"
            case .categorical:
                dtypes[columnName] = "string"
            case .date:
                dtypes[columnName] = "datetime"
            case .unknown:
                dtypes[columnName] = "string"
            }
        }
        
        return DataFrameData(
            columns: csvData.headers,
            rows: csvData.rows,
            dtypes: dtypes
        )
    }
    
    private func parsePointCloudFile(_ url: URL) async -> PointCloudData? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let pointCloud = parsePLY(at: url)
                continuation.resume(returning: pointCloud)
            }
        }
    }
}

// MARK: - Supporting Models

enum BatchImportError: LocalizedError {
    case unsupportedFormat
    case invalidData
    case parsingFailed
    case bookmarkFailed
    case accessDenied
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported file format"
        case .invalidData:
            return "Invalid or corrupted data"
        case .parsingFailed:
            return "Failed to parse file content"
        case .bookmarkFailed:
            return "Failed to create file bookmark"
        case .accessDenied:
            return "Access denied to file"
        }
    }
}

struct BatchImportProgress {
    var totalFiles: Int = 0
    var currentFileIndex: Int = 0
    var currentFileName: String = ""
    var currentFileStatus: FileProcessingStatus = .pending
    var successCount: Int = 0
    var failureCount: Int = 0
    
    var completedFiles: Int {
        successCount + failureCount
    }
    
    var progressPercentage: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(completedFiles) / Double(totalFiles)
    }
    
    var isCompleted: Bool {
        completedFiles >= totalFiles && totalFiles > 0
    }
}

enum FileProcessingStatus {
    case pending
    case analyzing
    case importing
    case completed
    case failed
    
    var description: String {
        switch self {
        case .pending: return "Waiting"
        case .analyzing: return "Analyzing"
        case .importing: return "Importing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

class BatchImportSession: ObservableObject, Identifiable {
    let id = UUID()
    let files: [URL]
    @Published var status: BatchSessionStatus = .pending
    @Published var startedAt: Date?
    @Published var completedAt: Date?
    @Published var successfulImports: [BatchFileResult] = []
    @Published var failedImports: [BatchFileResult] = []
    @Published var createdWindows: [Int] = []
    
    init(files: [URL]) {
        self.files = files
    }
    
    var duration: TimeInterval? {
        guard let start = startedAt else { return nil }
        let end = completedAt ?? Date()
        return end.timeIntervalSince(start)
    }
    
    var successRate: Double {
        let total = successfulImports.count + failedImports.count
        guard total > 0 else { return 0 }
        return Double(successfulImports.count) / Double(total)
    }
}

enum BatchSessionStatus {
    case pending
    case processing
    case completed
    case cancelled
}

struct BatchFileResult: Identifiable {
    let id = UUID()
    let url: URL
    let windowID: Int?
    let fileType: FileType
    let status: BatchFileStatus
    
    enum BatchFileStatus {
        case success
        case failed(Error)
        
        var isSuccess: Bool {
            switch self {
            case .success: return true
            case .failed: return false
            }
        }
    }
}

extension ChartRecommendation {
    var rawValue: String {
        switch self {
        case .lineChart: return "Line"
        case .barChart: return "Bar"
        case .scatterPlot: return "Scatter"
        case .pieChart: return "Pie"
        case .areaChart: return "Area"
        case .histogram: return "Histogram"
        }
    }
}