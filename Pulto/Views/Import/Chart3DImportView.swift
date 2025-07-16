//
//  Chart3DImportView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/15/25.
//  Copyright 2025 Apple. All rights reserved.
//

import SwiftUI

struct Chart3DImportView: View {
    let windowID: Int
    @ObservedObject var windowManager: WindowTypeManager = .shared
    @State private var showFileImporter = false
    @State private var selectedDataType: String = "scatter"
    @State private var importStatus: String = ""
    @State private var previewData: Chart3DData?
    @Environment(\.openWindow) private var openWindow

    let dataTypes = ["scatter", "surface", "line"]

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 60))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                Text("3D Chart Viewer")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Import and visualize three-dimensional data")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 30)

            // Data type selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Chart Type")
                    .font(.headline)

                Picker("Data Type", selection: $selectedDataType) {
                    ForEach(dataTypes, id: \.self) { type in
                        Text(type.capitalized).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: 300)
            }
            .padding()

            // Demo data buttons
            VStack(spacing: 16) {
                Text("Demo Data")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    Button {
                        createDemoWave()
                    } label: {
                        Label("Wave Surface", systemImage: "waveform")
                            .frame(minWidth: 140)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)

                    Button {
                        createDemoScatter()
                    } label: {
                        Label("Scatter Plot", systemImage: "circle.grid.3x3")
                            .frame(minWidth: 140)
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                }

                Divider()
                    .frame(maxWidth: 400)
                    .padding(.vertical, 8)

                // File import button
                Button {
                    showFileImporter = true
                } label: {
                    Label("Import 3D Data File", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .padding()
                        .frame(minWidth: 250)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Text("Supported: CSV, JSON with X,Y,Z columns")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Status display
            if !importStatus.isEmpty {
                Text(importStatus)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
            }

            // Preview section
            if let preview = previewData {
                VStack(spacing: 8) {
                    Text("Preview: \(preview.title)")
                        .font(.headline)

                    HStack(spacing: 20) {
                        Label("\(preview.points.count) points", systemImage: "circle.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Button {
                        openVolumetricView()
                    } label: {
                        Label("Open 3D View", systemImage: "view.3d")
                            .font(.headline)
                            .padding()
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }

            Spacer()
        }
        .padding(40)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText, .json, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Demo Data Creation
    private func createDemoWave() {
        let waveData = Chart3DData.generateWave()
        updateWindowWithChart3D(waveData)
        previewData = waveData
        importStatus = "Created wave surface demo"
    }

    private func createDemoScatter() {
        let scatterData = Chart3DData.generateScatter()
        updateWindowWithChart3D(scatterData)
        previewData = scatterData
        importStatus = "Created scatter plot demo"
    }

    // MARK: - File Import
    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard let url = try? result.get().first else {
            importStatus = "Failed to access file"
            return
        }

        Task {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let chartData = parseCSV3DData(content, filename: url.lastPathComponent)
                
                await MainActor.run {
                    updateWindowWithChart3D(chartData)
                    previewData = chartData
                    importStatus = "Successfully imported \(chartData.points.count) points"
                }
            } catch {
                await MainActor.run {
                    importStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    private func parseCSV3DData(_ content: String, filename: String) -> Chart3DData {
        var chartData = Chart3DData(
            title: filename,
            chartType: selectedDataType,
        )

        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var startIndex = 0
        if let firstLine = lines.first {
            let components = firstLine.components(separatedBy: ",")
            if components.count >= 3 && Double(components[0]) == nil {
                startIndex = 1
            }
        }

        for i in startIndex..<lines.count {
            let components = lines[i].components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            if components.count >= 3,
               let x = Double(components[0]),
               let y = Double(components[1]),
               let z = Double(components[2]) {

                let point = Chart3DData.Point3D(x: x, y: y, z: z)
                chartData.points.append(point)
            }
        }

        return chartData
    }

    // MARK: - Window Updates
    private func updateWindowWithChart3D(_ chartData: Chart3DData) {
        windowManager.updateWindowChart3DData(windowID, chart3DData: chartData)

        let pythonCode = chartData.toPythonCode()
        windowManager.updateWindowContent(windowID, content: pythonCode)

        windowManager.addWindowTag(windowID, tag: "Chart3D")
    }

    private func openVolumetricView() {
        openWindow(id: "volumetric-chart3d", value: windowID)
    }
}
