//
//  FileImportIntegration.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/18/25.
//  Copyright © 2025 Apple. All rights reserved.
//


//
//  FileImportIntegration.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/18/25.
//  Integration layer between enhanced file import and existing window management
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - WindowTypeManager Extensions

extension WindowTypeManager {
    
    /// Create a window from a visualization suggestion
    @MainActor
    private func createWindowFromSuggestion(
        suggestion: VisualizationRecommendation,
        fileResult: FileAnalysisResult,
        openWindow: @escaping (Int) -> Void
    ) async -> Int {
        let windowID = getNextWindowID()
        let windowType = suggestion.type.windowType
        let position = WindowPosition(
            x: 100 + Double(windowID * 20),
            y: 100 + Double(windowID * 20)
        )
        
        _ = createWindow(type: windowType, id: windowID, position: position)
        
        // Populate window based on visualization type and file data
        await populateWindowFromFile(
            windowID: windowID,
            visualizationType: suggestion.type,
            fileResult: fileResult,
            configuration: suggestion.configuration
        )
        
        // Open the window
        openWindow(windowID)
        markWindowAsOpened(windowID)
        
        return windowID
    }
    
    /// Main router to populate window with data from a file
    @MainActor
    private func populateWindowFromFile(
        windowID: Int,
        visualizationType: SpatialVisualizationType,
        fileResult: FileAnalysisResult,
        configuration: any VisualizationConfiguration
    ) async {
        switch fileResult.fileType {
        case .csv, .tsv:
            await handleCSVImport(
                windowID: windowID,
                fileURL: fileResult.fileURL,
                visualizationType: visualizationType,
                analysis: fileResult.analysis
            )
            
        case .las:
            await handleLASImport(
                windowID: windowID,
                fileURL: fileResult.fileURL,
                analysis: fileResult.analysis
            )
            
        case .json:
            await handleJSONImport(
                windowID: windowID,
                fileURL: fileResult.fileURL
            )
            
        case .usdz:
            await handleUSDZImport(
                windowID: windowID,
                fileURL: fileResult.fileURL
            )
            
        default:
             updateWindowContent(windowID, content: "Preview for \(fileResult.fileURL.lastPathComponent)")
        }
    }
    
    // MARK: - File Type Handlers
    
    @MainActor
    private func handleCSVImport(
        windowID: Int,
        fileURL: URL,
        visualizationType: SpatialVisualizationType,
        analysis: DataAnalysisResult
    ) async {
        guard let data = try? String(contentsOf: fileURL) else { return }
        let delimiter: Character = fileURL.pathExtension.lowercased() == "csv" ? "," : "\t"
        let (headers, rows) = CSVParser.parse(data, delimiter: delimiter)
        guard let structure = analysis.structure as? TabularStructure else { return }
            
        switch visualizationType {
        case .dataTable:
            let dataFrame = DataFrameData(columns: headers, rows: rows, dtypes: structure.columnTypes.mapValues { $0.rawValue })
            updateWindowDataFrame(windowID, dataFrame: dataFrame)
            
        case .scatterPlot3D, .pointCloud3D:
            if structure.coordinateColumns.count >= 3 {
                let pointCloud = createPointCloudFromCSV(csvRows: rows, headers: headers, coordinateColumns: structure.coordinateColumns, fileURL: fileURL)
                updateWindowPointCloud(windowID, pointCloud: pointCloud)
            }
            
        default:
            updateWindowContent(windowID, content: "CSV: \(fileURL.lastPathComponent)")
        }
    }
    
    @MainActor
    private func handleLASImport(
        windowID: Int,
        fileURL: URL,
        analysis: DataAnalysisResult
    ) async {
        guard let data = try? Data(contentsOf: fileURL),
              let structure = analysis.structure as? PointCloudStructure else { return }
        let reader = LASFileReader(data: data)
        
        do {
            let header = try reader.readHeader()
            let sampleSize = min(100_000, Int(header.numberOfPointRecords))
            let points = try reader.readPoints(count: sampleSize, header: header)
            
            let pointCloudPoints = points.map { point -> PointCloudData.PointData in
                let color: String? = structure.hasColor ? String(format: "#%02X%02X%02X", point.red >> 8, point.green >> 8, point.blue >> 8) : nil
                return PointCloudData.PointData(
                    x: point.x, y: point.y, z: point.z,
                    intensity: structure.hasIntensity ? Double(point.intensity) / 65535.0 : nil,
                    color: color,
                    classification: Int(point.classification)
                )
            }
            
            let pointCloud = PointCloudData(
                title: fileURL.lastPathComponent,
                points: pointCloudPoints,
                totalPoints: structure.pointCount,
                bounds: structure.bounds
            )
            updateWindowPointCloud(windowID, pointCloud: pointCloud)
            
        } catch {
            print("Error importing LAS file: \(error)")
            updateWindowContent(windowID, content: "Error reading LAS file: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func handleJSONImport(windowID: Int, fileURL: URL) async {
        guard let data = try? Data(contentsOf: fileURL),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        
        // For JSON, a good default is the raw text viewer
        updateWindowContent(windowID, content: jsonString)
        addWindowTag(windowID, tag: "json")
    }
    
    @MainActor
    private func handleUSDZImport(windowID: Int, fileURL: URL) async {
        guard let bookmark = try? fileURL.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) else {
            return
        }
        updateUSDZBookmark(for: windowID, bookmark: bookmark)
        
        let modelData = Model3DData(
            title: fileURL.lastPathComponent,
            modelType: "usdz",
            scale: 1.0
        )
        updateWindowModel3DData(windowID, model3DData: modelData)
    }
    
    // MARK: - Helper Creation Methods
    
    private func createPointCloudFromCSV(csvRows: [[String]], headers: [String], coordinateColumns: [String], fileURL: URL) -> PointCloudData {
        let xIndex = headers.firstIndex(of: coordinateColumns[0]) ?? -1
        let yIndex = headers.firstIndex(of: coordinateColumns[1]) ?? -1
        let zIndex = headers.firstIndex(of: coordinateColumns[2]) ?? -1
        
        let points = csvRows.compactMap { row -> PointCloudData.PointData? in
            guard xIndex != -1, yIndex != -1, zIndex != -1,
                  let x = Double(row[xIndex]),
                  let y = Double(row[yIndex]),
                  let z = Double(row[zIndex]) else {
                return nil
            }
            return PointCloudData.PointData(x: x, y: y, z: z)
        }
        
        return PointCloudData(title: fileURL.lastPathComponent, points: points, totalPoints: points.count, bounds: nil)
    }
}

// MARK: - EnvironmentView Integration

extension EnvironmentView {
    /// Updated file import handler using enhanced system
    func handleEnhancedFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // This is where you would trigger your EnhancedFileImportView to appear,
            // likely by setting a state variable that controls a .sheet modifier.
            // For example: `self.importingURL = url`
            
        case .failure(let error):
            // Present an alert to the user
            print("Import failed:", error)
        }
    }
}