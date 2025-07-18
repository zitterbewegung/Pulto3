//  FileImportIntegration.swift
//  Pulto3
//  Created by Joshua Herman on 7/18/25.
//  Integration layer between enhanced file import and existing window management
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - WindowTypeManager Extensions

extension WindowTypeManager {
    
    /// Create windows from file analysis results
    @MainActor
    func createWindowsFromFileAnalysis(
        _ result: FileAnalysisResult,
        suggestions: [VisualizationRecommendation],
        openWindow: @escaping (Int) -> Void
    ) async -> [Int] {
        var createdWindowIDs: [Int] = []
        
        switch result.fileType {
        case .xlsx:
            // Handle multi-sheet Excel files
            if let structure = result.analysis.structure as? SpreadsheetStructure {
                for sheet in structure.sheets {
                    let windowID = await createWindowForExcelSheet(
                        sheet: sheet,
                        fileURL: result.fileURL,
                        openWindow: openWindow
                    )
                    createdWindowIDs.append(windowID)
                }
            }
            
        default:
            // Create single window for other file types
            if let primarySuggestion = suggestions.first {
                let windowID = await createWindowFromSuggestion(
                    suggestion: primarySuggestion,
                    fileResult: result,
                    openWindow: openWindow
                )
                createdWindowIDs.append(windowID)
            }
        }
        
        return createdWindowIDs
    }
    
    /// Create a window for an Excel sheet
    @MainActor
    private func createWindowForExcelSheet(
        sheet: ExcelParser.ExcelSheet,
        fileURL: URL,
        openWindow: @escaping (Int) -> Void
    ) async -> Int {
        let windowID = getNextWindowID()
        let position = WindowPosition(
            x: 100 + Double(windowID * 20),
            y: 100 + Double(windowID * 20),
            z: 0,
            width: 800,
            height: 600
        )
        
        // Create data table window for Excel sheet
        _ = createWindow(.column, id: windowID, position: position)
        
        // Convert sheet to DataFrame
        let dataFrame = ExcelParser.convertSheetToWindowData(sheet)
        updateWindowDataFrame(windowID, dataFrame: dataFrame)
        
        // Set metadata
        updateWindowContent(windowID, content: "Excel Sheet: \(sheet.name) from \(fileURL.lastPathComponent)")
        addWindowTag(windowID, tag: "excel")
        addWindowTag(windowID, tag: sheet.name)
        
        // Open the window
        openWindow(windowID)
        markWindowAsOpened(windowID)
        
        return windowID
    }
    
    /// Create a window from visualization suggestion
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
            y: 100 + Double(windowID * 20),
            z: 0,
            width: 800,
            height: 600
        )
        
        _ = createWindow(windowType, id: windowID, position: position)
        
        // Populate window based on visualization type and file data
        await populateWindowFromFile(
            windowID: windowID,
            windowType: windowType,
            visualizationType: suggestion.type,
            fileResult: fileResult,
            configuration: suggestion.configuration
        )
        
        // Open the window
        openWindow(windowID)
        markWindowAsOpened(windowID)
        
        return windowID
    }
    
    /// Populate window with data from file
    @MainActor
    private func populateWindowFromFile(
        windowID: Int,
        windowType: WindowType,
        visualizationType: SpatialVisualizationType,
        fileResult: FileAnalysisResult,
        configuration: VisualizationConfiguration
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
                fileURL: fileResult.fileURL,
                visualizationType: visualizationType,
                analysis: fileResult.analysis
            )
            
        case .ipynb:
            await handleNotebookImport(
                windowID: windowID,
                fileURL: fileResult.fileURL,
                analysis: fileResult.analysis
            )
            
        case .usdz:
            await handleUSDZImport(
                windowID: windowID,
                fileURL: fileResult.fileURL
            )
            
        default:
            break
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
        do {
            let data = try String(contentsOf: fileURL)
            guard let csv = CSVParser.parse(data) else { return }
            
            switch visualizationType {
            case .dataTable:
                // Create DataFrame
                let dtypes = Dictionary(uniqueKeysWithValues: zip(
                    csv.headers,
                    csv.columnTypes.map { type -> String in
                        switch type {
                        case .numeric: return "float"
                        case .categorical: return "string"
                        case .date: return "datetime"
                        case .unknown: return "string"
                        }
                    }
                ))
                
                let dataFrame = DataFrameData(
                    columns: csv.headers,
                    rows: csv.rows,
                    dtypes: dtypes
                )
                
                updateWindowDataFrame(windowID, dataFrame: dataFrame)
                
            case .scatterPlot3D:
                if let structure = analysis.structure as? TabularStructure,
                   structure.coordinateColumns.count >= 3 {
                    // Create 3D scatter plot
                    let chartData = createScatter3DFromCSV(
                        csv: csv,
                        coordinateColumns: structure.coordinateColumns
                    )
                    updateWindowChart3DData(windowID, chart3DData: chartData)
                }
                
            case .pointCloud3D:
                if let structure = analysis.structure as? TabularStructure,
                   structure.coordinateColumns.count >= 3 {
                    // Create point cloud
                    let pointCloud = createPointCloudFromCSV(
                        csv: csv,
                        coordinateColumns: structure.coordinateColumns,
                        fileURL: fileURL
                    )
                    updateWindowPointCloud(windowID, pointCloud: pointCloud)
                }
                
            default:
                // Handle other visualization types
                break
            }
            
        } catch {
            print("Error importing CSV: \(error)")
        }
    }
    
    @MainActor
    private func handleLASImport(
        windowID: Int,
        fileURL: URL,
        analysis: DataAnalysisResult
    ) async {
        do {
            let data = try Data(contentsOf: fileURL)
            let reader = LASFileReader(data: data)
            let header = try reader.readHeader()
            
            // Read sample points for preview
            let sampleSize = min(100000, Int(header.numberOfPointRecords))
            let points = try reader.readPoints(count: sampleSize, header: header)
            
            // Convert to PointCloudData
            var pointCloudData = PointCloudData(
                title: fileURL.lastPathComponent,
                demoType: "las"
            )
            
            pointCloudData.points = points.map { point in
                PointCloudData.PointData(
                    x: point.x,
                    y: point.y,
                    z: point.z,
                    intensity: Double(point.intensity) / 65535.0,
                    color: point.red > 0 || point.green > 0 || point.blue > 0 ?
                        String(format: "#%02X%02X%02X",
                               point.red >> 8,
                               point.green >> 8,
                               point.blue >> 8) : nil,
                    classification: Int(point.classification),
                    gpsTime: point.gpsTime > 0 ? point.gpsTime : nil
                )
            }
            
            pointCloudData.totalPoints = Int(header.numberOfPointRecords)
            pointCloudData.bounds = PointCloudBounds(
                minX: header.minX,
                maxX: header.maxX,
                minY: header.minY,
                maxY: header.maxY,
                minZ: header.minZ,
                maxZ: header.maxZ
            )
            
            if let structure = analysis.structure as? PointCloudStructure {
                pointCloudData.hasIntensity = structure.hasIntensity
                pointCloudData.hasColor = structure.hasColor
                pointCloudData.hasGPSTime = structure.hasGPSTime
            }
            
            updateWindowPointCloud(windowID, pointCloud: pointCloudData)
            updateWindowContent(windowID, content: "LAS Point Cloud: \(fileURL.lastPathComponent)")
            addWindowTag(windowID, tag: "lidar")
            
        } catch {
            print("Error importing LAS file: \(error)")
        }
    }
    
    @MainActor
    private func handleJSONImport(
        windowID: Int,
        fileURL: URL,
        visualizationType: SpatialVisualizationType,
        analysis: DataAnalysisResult
    ) async {
        do {
            let data = try Data(contentsOf: fileURL)
            let json = try JSONSerialization.jsonObject(with: data)
            
            if let structure = analysis.structure as? JSONStructure {
                if structure.isArrayOfObjects,
                   let array = json as? [[String: Any]] {
                    // Convert to tabular format
                    let (headers, rows) = convertJSONArrayToTable(array)
                    
                    let dataFrame = DataFrameData(
                        columns: headers,
                        rows: rows,
                        dtypes: Dictionary(uniqueKeysWithValues: headers.map { ($0, "string") })
                    )
                    
                    updateWindowDataFrame(windowID, dataFrame: dataFrame)
                } else if structure.hasCoordinates {
                    // Handle geospatial JSON
                    if let geoJSON = extractGeoJSONData(from: json) {
                        let pointCloud = createPointCloudFromGeoJSON(geoJSON)
                        updateWindowPointCloud(windowID, pointCloud: pointCloud)
                    }
                }
            }
            
            updateWindowContent(windowID, content: "JSON Data: \(fileURL.lastPathComponent)")
            
        } catch {
            print("Error importing JSON: \(error)")
        }
    }
    
    @MainActor
    private func handleNotebookImport(
        windowID: Int,
        fileURL: URL,
        analysis: DataAnalysisResult
    ) async {
        do {
            let data = try Data(contentsOf: fileURL)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let structure = analysis.structure as? NotebookStructure else { return }
            
            // Import the notebook structure
            let importResult = try importFromGenericNotebook(data: data)
            
            // For notebooks, we might want to create multiple windows
            // based on the extracted data and visualizations
            for extractedData in structure.extractedData {
                switch extractedData.dataType {
                case .dataFrame:
                    // Would extract the actual DataFrame data from the notebook
                    updateWindowContent(
                        windowID,
                        content: "DataFrame '\(extractedData.variableName)' from notebook"
                    )
                    
                case .pointCloud:
                    // Would extract point cloud data
                    updateWindowContent(
                        windowID,
                        content: "Point Cloud '\(extractedData.variableName)' from notebook"
                    )
                    
                case .array:
                    // Would handle array data
                    break
                }
            }
            
            addWindowTag(windowID, tag: "notebook")
            
        } catch {
            print("Error importing notebook: \(error)")
        }
    }
    
    @MainActor
    private func handleUSDZImport(
        windowID: Int,
        fileURL: URL
    ) async {
        // Store the file bookmark for the 3D viewer
        if let bookmark = try? fileURL.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            updateUSDZBookmark(for: windowID, bookmark: bookmark)
        }
        
        // Create a placeholder model data
        let modelData = Model3DData(
            title: fileURL.lastPathComponent,
            modelType: "usdz",
            scale: 1.0
        )
        
        updateWindowModel3DData(windowID, model3DData: modelData)
        updateWindowContent(windowID, content: "USDZ Model: \(fileURL.lastPathComponent)")
        addWindowTag(windowID, tag: "usdz")
    }
    
    // MARK: - Helper Methods
    
    private func createScatter3DFromCSV(
        csv: CSVData,
        coordinateColumns: [String]
    ) -> Chart3DData {
        let xCol = coordinateColumns[0]
        let yCol = coordinateColumns[1]
        let zCol = coordinateColumns[2]
        
        let xIndex = csv.headers.firstIndex(of: xCol) ?? 0
        let yIndex = csv.headers.firstIndex(of: yCol) ?? 1
        let zIndex = csv.headers.firstIndex(of: zCol) ?? 2
        
        let xData = csv.rows.compactMap { row in
            xIndex < row.count ? Double(row[xIndex]) : nil
        }
        let yData = csv.rows.compactMap { row in
            yIndex < row.count ? Double(row[yIndex]) : nil
        }
        let zData = csv.rows.compactMap { row in
            zIndex < row.count ? Double(row[zIndex]) : nil
        }
        
        return Chart3DData(
            title: "3D Scatter Plot",
            chartType: .scatter,
            xData: xData,
            yData: yData,
            zData: zData,
            xLabel: xCol,
            yLabel: yCol,
            zLabel: zCol
        )
    }
    
    private func createPointCloudFromCSV(
        csv: CSVData,
        coordinateColumns: [String],
        fileURL: URL
    ) -> PointCloudData {
        let xCol = coordinateColumns[0]
        let yCol = coordinateColumns[1]
        let zCol = coordinateColumns[2]
        
        let xIndex = csv.headers.firstIndex(of: xCol) ?? 0
        let yIndex = csv.headers.firstIndex(of: yCol) ?? 1
        let zIndex = csv.headers.firstIndex(of: zCol) ?? 2
        
        // Look for intensity column
        let intensityIndex = csv.headers.firstIndex { header in
            header.lowercased().contains("intensity") ||
            header.lowercased().contains("value")
        }
        
        var pointCloud = PointCloudData(
            title: fileURL.lastPathComponent,
            demoType: "csv"
        )
        
        pointCloud.points = csv.rows.compactMap { row in
            guard xIndex < row.count,
                  yIndex < row.count,
                  zIndex < row.count,
                  let x = Double(row[xIndex]),
                  let y = Double(row[yIndex]),
                  let z = Double(row[zIndex]) else { return nil }
            
            let intensity: Double? = intensityIndex.flatMap { idx in
                idx < row.count ? Double(row[idx]) : nil
            }
            
            return PointCloudData.PointData(
                x: x, y: y, z: z,
                intensity: intensity,
                color: nil
            )
        }
        
        pointCloud.totalPoints = pointCloud.points.count
        
        return pointCloud
    }
    
    private func convertJSONArrayToTable(_ array: [[String: Any]]) -> (headers: [String], rows: [[String]]) {
        guard !array.isEmpty else { return ([], []) }
        
        // Extract headers from first object
        let headers = Array(array[0].keys).sorted()
        
        // Convert each object to row
        let rows = array.map { obj in
            headers.map { header in
                String(describing: obj[header] ?? "")
            }
        }
        
        return (headers, rows)
    }
    
    private func extractGeoJSONData(from json: Any) -> [GeoJSONFeature]? {
        // Simplified GeoJSON extraction
        guard let dict = json as? [String: Any],
              let features = dict["features"] as? [[String: Any]] else { return nil }
        
        return features.compactMap { feature in
            guard let geometry = feature["geometry"] as? [String: Any],
                  let coordinates = geometry["coordinates"] as? [Double],
                  coordinates.count >= 2 else { return nil }
            
            return GeoJSONFeature(
                coordinates: coordinates,
                properties: feature["properties"] as? [String: Any] ?? [:]
            )
        }
    }
    
    private func createPointCloudFromGeoJSON(_ features: [GeoJSONFeature]) -> PointCloudData {
        var pointCloud = PointCloudData(
            title: "GeoJSON Points",
            demoType: "geojson"
        )
        
        pointCloud.points = features.map { feature in
            PointCloudData.PointData(
                x: feature.coordinates[0],
                y: feature.coordinates[1],
                z: feature.coordinates.count > 2 ? feature.coordinates[2] : 0,
                intensity: nil,
                color: nil
            )
        }
        
        pointCloud.totalPoints = pointCloud.points.count
        
        return pointCloud
    }
}

// MARK: - Supporting Types

struct GeoJSONFeature {
    let coordinates: [Double]
    let properties: [String: Any]
}

// MARK: - EnvironmentView Integration

extension EnvironmentView {
    
    /// Updated file import handler using enhanced system
    func handleEnhancedFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Show enhanced import dialog
            showEnhancedImporter(for: url)
            
        case .failure(let error):
            print("Import failed:", error)
        }
    }
    
    @MainActor
    private func showEnhancedImporter(for url: URL) {
        // This would show the EnhancedFileImportView
        // The view would be added to the sheet presentations in EnvironmentView
    }
}

// MARK: - UTType Extensions

extension UTType {
    static let las = UTType(filenameExtension: "las") ?? .data
    static let xlsx = UTType(filenameExtension: "xlsx") ?? .data
    static let ipynb = UTType(filenameExtension: "ipynb") ?? .json
}
