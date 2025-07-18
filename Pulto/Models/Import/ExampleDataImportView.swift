//
//  ExampleDataImportView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/18/25.
//  Copyright © 2025 Apple. All rights reserved.
//
//  Examples of how to use the enhanced file import system
//

import SwiftUI

// MARK: - Example 1: Basic Usage in a View

struct ExampleDataImportView: View {
    @StateObject private var fileAnalyzer = FileAnalyzer.shared
    @EnvironmentObject var windowManager: WindowTypeManager
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack {
            // Direct file analysis
            Button("Analyze File") {
                analyzeExampleFile()
            }
            
            // Show import dialog
            Button("Import with UI") {
                showImportDialog()
            }
        }
    }
    
    func analyzeExampleFile() {
        Task {
            do {
                let url = URL(fileURLWithPath: "/path/to/data.csv")
                let result = try await fileAnalyzer.analyzeFile(url)
                
                print("File type: \(result.fileType)")
                print("Data type: \(result.analysis.dataType)")
                print("Suggestions: \(result.suggestions.count)")
                
                // Create visualization based on top suggestion
                if let suggestion = result.suggestions.first {
                    await createVisualization(from: result, suggestion: suggestion)
                }
            } catch {
                print("Analysis failed: \(error)")
            }
        }
    }
    
    @MainActor
    func createVisualization(
        from result: FileAnalysisResult,
        suggestion: VisualizationRecommendation
    ) async {
        let windowIDs = await windowManager.createWindowsFromFileAnalysis(
            result,
            suggestions: [suggestion],
            openWindow: { openWindow(value: $0) }
        )
        
        print("Created windows: \(windowIDs)")
    }
    
    func showImportDialog() {
        // This would present the EnhancedFileImportView
    }
}

// MARK: - Example 2: Programmatic Import of Different File Types

class FileImportExamples {
    let windowManager = WindowTypeManager.shared
    let fileAnalyzer = FileAnalyzer.shared
    
    // MARK: CSV Import Example
    
    func importCSVWithCoordinates() async {
        let csvContent = """
        x,y,z,intensity,label
        10.5,20.3,5.1,0.8,Building
        11.2,21.1,5.3,0.7,Building
        15.6,25.4,2.1,0.3,Ground
        16.1,26.2,2.0,0.3,Ground
        """
        
        // Save to temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("coordinates.csv")
        try? csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
        
        // Analyze file
        do {
            let result = try await fileAnalyzer.analyzeFile(tempURL)
            
            // Should detect tabular data with coordinates
            if case .tabularWithCoordinates = result.analysis.dataType {
                print("✅ Correctly detected coordinate data")
                
                // Check suggestions
                for suggestion in result.suggestions {
                    print("- \(suggestion.type): \(suggestion.reason)")
                }
            }
        } catch {
            print("❌ Import failed: \(error)")
        }
    }
    
    // MARK: Excel Import Example
    
    func importExcelWithMultipleSheets() async {
        let excelURL = URL(fileURLWithPath: "/path/to/data.xlsx")
        
        do {
            let result = try await fileAnalyzer.analyzeFile(excelURL)
            
            if let structure = result.analysis.structure as? SpreadsheetStructure {
                print("Found \(structure.sheets.count) sheets:")
                
                for sheet in structure.sheets {
                    print("- \(sheet.name): \(sheet.rowCount) rows × \(sheet.columnCount) columns")
                }
                
                // Create windows for each sheet
                await windowManager.createWindowsFromFileAnalysis(
                    result,
                    suggestions: result.suggestions,
                    openWindow: { _ in }
                )
            }
        } catch {
            print("Excel import failed: \(error)")
        }
    }
    
    // MARK: LAS Import Example
    
    func importLiDARFile() async {
        let lasURL = URL(fileURLWithPath: "/path/to/pointcloud.las")
        
        do {
            let result = try await fileAnalyzer.analyzeFile(lasURL)
            
            if let structure = result.analysis.structure as? PointCloudStructure {
                print("Point cloud properties:")
                print("- Points: \(structure.pointCount)")
                print("- Has intensity: \(structure.hasIntensity)")
                print("- Has color: \(structure.hasColor)")
                print("- Has GPS time: \(structure.hasGPSTime)")
                print("- Density: \(structure.averageDensity) points/m³")
                
                // Should suggest point cloud visualization
                let pointCloudSuggestions = result.suggestions.filter {
                    $0.type == .pointCloud3D || $0.type == .volumetric
                }
                
                print("Found \(pointCloudSuggestions.count) point cloud visualizations")
            }
        } catch {
            print("LAS import failed: \(error)")
        }
    }
    
    // MARK: Notebook Import Example
    
    func importJupyterNotebook() async {
        let notebookContent = """
        {
            "cells": [
                {
                    "cell_type": "code",
                    "source": [
                        "import pandas as pd\\n",
                        "import numpy as np\\n",
                        "\\n",
                        "# Create sample data\\n",
                        "data = pd.DataFrame({\\n",
                        "    'x': np.random.randn(100),\\n",
                        "    'y': np.random.randn(100),\\n",
                        "    'z': np.random.randn(100)\\n",
                        "})"
                    ],
                    "metadata": {}
                },
                {
                    "cell_type": "code",
                    "source": [
                        "# Create 3D scatter plot\\n",
                        "import matplotlib.pyplot as plt\\n",
                        "from mpl_toolkits.mplot3d import Axes3D\\n",
                        "\\n",
                        "fig = plt.figure()\\n",
                        "ax = fig.add_subplot(111, projection='3d')\\n",
                        "ax.scatter(data['x'], data['y'], data['z'])"
                    ],
                    "metadata": {}
                }
            ],
            "metadata": {
                "kernelspec": {
                    "display_name": "Python 3",
                    "language": "python",
                    "name": "python3"
                }
            },
            "nbformat": 4,
            "nbformat_minor": 4
        }
        """
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("example.ipynb")
        try? notebookContent.write(to: tempURL, atomically: true, encoding: .utf8)
        
        do {
            let result = try await fileAnalyzer.analyzeFile(tempURL)
            
            if let structure = result.analysis.structure as? NotebookStructure {
                print("Notebook analysis:")
                print("- Cells: \(structure.cellCount)")
                print("- Extracted data: \(structure.extractedData.count)")
                print("- Visualizations: \(structure.visualizationCode.count)")
                
                // Should detect DataFrame and suggest native visualization
                for data in structure.extractedData {
                    print("- Found \(data.dataType) named '\(data.variableName)'")
                }
                
                for viz in structure.visualizationCode {
                    print("- Found \(viz.type) visualization using \(viz.library)")
                }
            }
        } catch {
            print("Notebook import failed: \(error)")
        }
    }
}

// MARK: - Example 3: Custom Visualization Configuration

struct CustomVisualizationExample {
    
    func createCustomPointCloudVisualization() async {
        let fileURL = URL(fileURLWithPath: "/path/to/data.las")
        
        // Create custom configuration
        let customConfig = PointCloudConfiguration(
            estimatedPoints: 1_000_000,
            coordinateColumns: ["x", "y", "z"],
            hasIntensity: true,
            hasColor: true,
            hasClassification: true,
            enableLOD: true  // Level of detail for performance
        )
        
        // Create custom recommendation
        let customRecommendation = VisualizationRecommendation(
            type: .pointCloud3D,
            priority: .high,
            confidence: 1.0,
            reason: "Custom high-performance point cloud visualization",
            configuration: customConfig
        )
        
        // Use the custom recommendation
        // ... implementation
    }
    
    func createTimeSeriesVisualization() async {
        let config = TimeSeriesConfiguration(
            timeColumn: "timestamp",
            spatialColumns: ["x", "y", "z"],
            animationSpeed: 2.0
        )
        
        let recommendation = VisualizationRecommendation(
            type: .timeSeriesPath,
            priority: .high,
            confidence: 0.9,
            reason: "Animate movement over time",
            configuration: config
        )
        
        // Use for GPS-tracked data
    }
}

// MARK: - Example 4: Batch Processing

struct BatchImportExample {
    @MainActor
    func importMultipleFiles() async {
        let urls = [
            URL(fileURLWithPath: "/data/scan1.las"),
            URL(fileURLWithPath: "/data/scan2.las"),
            URL(fileURLWithPath: "/data/metadata.xlsx"),
            URL(fileURLWithPath: "/data/analysis.ipynb")
        ]
        
        for url in urls {
            do {
                let result = try await FileAnalyzer.shared.analyzeFile(url)
                
                print("\n📄 File: \(url.lastPathComponent)")
                print("   Type: \(result.fileType.displayName)")
                print("   Data: \(result.analysis.dataType)")
                print("   Top suggestion: \(result.suggestions.first?.type ?? .dataTable)")
                
                // Create appropriate visualization
                if let suggestion = result.suggestions.first {
                    await createVisualizationForBatch(
                        result: result,
                        suggestion: suggestion
                    )
                }
                
                // Small delay between imports
                try? await Task.sleep(nanoseconds: 500_000_000)
                
            } catch {
                print("   ❌ Failed: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func createVisualizationForBatch(
        result: FileAnalysisResult,
        suggestion: VisualizationRecommendation
    ) async {
        // Implementation to create windows
    }
}

// MARK: - Example 5: Error Handling

struct ErrorHandlingExample {
    
    func importWithErrorHandling() async {
        let url = URL(fileURLWithPath: "/path/to/file.unknown")
        
        do {
            let result = try await FileAnalyzer.shared.analyzeFile(url)
            // Process result
        } catch FileAnalysisError.unsupportedFormat {
            print("This file format is not supported")
            // Show user-friendly error
        } catch FileAnalysisError.emptyFile {
            print("The file appears to be empty")
        } catch FileAnalysisError.encodingError {
            print("Could not read the file - encoding issue")
        } catch FileAnalysisError.invalidLASFile(let message) {
            print("LAS file error: \(message)")
        } catch {
            print("Unexpected error: \(error)")
        }
    }
}

// MARK: - Example 6: Integration with SwiftUI

struct ContentViewWithImport: View {
    @State private var showImporter = false
    @State private var importedWindows: [Int] = []
    
    var body: some View {
        NavigationView {
            VStack {
                // Your content
                
                Button("Import Data") {
                    showImporter = true
                }
                .sheet(isPresented: $showImporter) {
                    EnhancedFileImportView()
                        .onDisappear {
                            // Handle completion
                            print("Imported windows: \(importedWindows)")
                        }
                }
            }
            .navigationTitle("Data Visualization")
        }
    }
}

// MARK: - Usage Instructions

/*
 ENHANCED FILE IMPORT SYSTEM USAGE:
 
 1. SETUP:
    - Add all the Swift files to your project
    - Install CoreXLSX package (optional, for Excel support)
    - Update EnvironmentView as shown in the integration guide
 
 2. BASIC USAGE:
    - Use EnhancedFileImportView for UI-based import
    - Use FileAnalyzer.analyzeFile() for programmatic import
    - System automatically detects file type and suggests visualizations
 
 3. SUPPORTED FORMATS:
    - CSV/TSV: Tabular data with automatic coordinate detection
    - Excel: Multi-sheet workbooks with independent import
    - JSON: Structured data with geospatial support
    - LAS: LiDAR point clouds with GPS time
    - Jupyter: Notebook analysis with data extraction
    - USDZ: 3D models
 
 4. VISUALIZATION SUGGESTIONS:
    - System analyzes data structure and patterns
    - Suggests appropriate visualizations with confidence scores
    - Prioritizes based on data characteristics
 
 5. CUSTOMIZATION:
    - Create custom VisualizationConfiguration objects
    - Override suggestions with custom recommendations
    - Extend file type support by adding parsers
 
 6. PERFORMANCE:
    - Large files are sampled for analysis
    - Point clouds use LOD for performance
    - Excel sheets imported independently
 
 7. ERROR HANDLING:
    - Comprehensive error types for debugging
    - User-friendly error messages
    - Graceful fallbacks for unsupported features
 */
