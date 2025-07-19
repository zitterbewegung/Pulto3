//
//  PointCloudData.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/19/25.
//  Copyright © 2025 Apple. All rights reserved.
//


/// File: FileClassifierAndRecommenderView.swift

import SwiftUI
import Charts
import UniformTypeIdentifiers
import RealityKit

// MARK: - File Classifier and Recommender Integration
// The following code is the integrated FileClassifierAndRecommenderView
// Place this in the same file or a separate one and import if needed.


func parsePLY(at url: URL) -> PointCloudData? {
    guard url.startAccessingSecurityScopedResource() else { return nil }
    defer { url.stopAccessingSecurityScopedResource() }

    do {
        let data = try Data(contentsOf: url)
        guard let headerStr = String(data: data.prefix(1024), encoding: .ascii) else { return nil }

        guard let endRange = headerStr.range(of: "end_header\n") else { return nil }
        let header = String(headerStr[..<endRange.upperBound])
        let headerLines = header.components(separatedBy: .newlines)

        var format = "ascii 1.0"
        var vertexCount = 0
        var propList = [String]()
        var propTypes = [String]()

        for line in headerLines {
            let parts = line.components(separatedBy: " ")
            if parts.count > 1 {
                if parts[0] == "format" {
                    format = parts[1...].joined(separator: " ")
                } else if parts[0] == "element" && parts[1] == "vertex" {
                    vertexCount = Int(parts[2]) ?? 0
                } else if parts[0] == "property" {
                    propTypes.append(parts[1])
                    propList.append(parts.last ?? "")
                }
            }
        }

        let bodyStart = header.utf8CString.count - 1 // Account for null terminator or line break
        let bodyData = data.subdata(in: bodyStart..<data.count)

        var points = [SIMD3<Float>]()

        if format.hasPrefix("ascii") {
            guard let bodyStr = String(data: bodyData, encoding: .ascii) else { return nil }
            let bodyLines = bodyStr.components(separatedBy: .newlines).filter { !$0.isEmpty }

            for line in bodyLines.prefix(vertexCount) {
                let values = line.components(separatedBy: " ").compactMap { Float($0) }
                if values.count >= 3 {
                    points.append(SIMD3(values[0], values[1], values[2]))
                }
            }
        } else if format.hasPrefix("binary") {
            let isBigEndian = format.contains("big_endian")
            var offset = 0
            let xIndex = propList.firstIndex(of: "x") ?? -1
            let yIndex = propList.firstIndex(of: "y") ?? -1
            let zIndex = propList.firstIndex(of: "z") ?? -1
            if xIndex == -1 || yIndex == -1 || zIndex == -1 { return nil }

            for _ in 0..<vertexCount {
                var x: Float = 0, y: Float = 0, z: Float = 0
                for propIndex in 0..<propList.count {
                    let propType = propTypes[propIndex]
                    let size: Int
                    switch propType {
                    case "float32", "float":
                        size = 4
                    case "double":
                        size = 8
                    case "int32", "uint32":
                        size = 4
                    case "uchar", "uint8":
                        size = 1
                    default:
                        size = 4 // Default to 4 bytes
                    }
                    let propData = bodyData.subdata(in: offset..<offset + size)
                    offset += size

                    let value: Float
                    switch size {
                    case 4:
                        let uint32 = propData.withUnsafeBytes { $0.load(as: UInt32.self) }
                        let finalUInt32 = isBigEndian ? uint32.bigEndian : uint32.littleEndian
                        value = Float(bitPattern: finalUInt32)
                    case 8:
                        let uint64 = propData.withUnsafeBytes { $0.load(as: UInt64.self) }
                        let finalUInt64 = isBigEndian ? uint64.bigEndian : uint64.littleEndian
                        value = Float(bitPattern: UInt32(finalUInt64)) // Approximate
                    default:
                        value = 0
                    }

                    if propIndex == xIndex { x = value }
                    else if propIndex == yIndex { y = value }
                    else if propIndex == zIndex { z = value }
                }
                points.append(SIMD3(x, y, z))
            }
        }

        return PointCloudData(points: points)
    } catch {
        print("PLY parse error: \(error)")
        return nil
    }
}

// MARK: - Main View
struct FileClassifierAndRecommenderView: View {
    @EnvironmentObject private var windowManager: WindowTypeManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @State private var csvData: CSVData?
    @State private var recommendations: [ChartScore] = []
    @State private var selectedRecommendation: ChartRecommendation?
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var nonCSVType: FileType?
    @State private var importedURL: URL?

    private var welcomeScreen: some View {
        VStack(spacing: 30) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("File Classifier and Chart Recommender")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Import a file from iCloud to classify it and get chart recommendations for CSV/TSV")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: { isImporting = true }) {
                Label("Import File from iCloud", systemImage: "icloud.and.arrow.down")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }

    private var nonCSVScreen: some View {
        Group {
            if let type = nonCSVType {
                VStack(spacing: 30) {
                    Image(systemName: "doc")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    Text("File Classified")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("This is a \(type.description)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Text("Chart recommendations are only available for CSV/TSV files.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button(action: { isImporting = true }) {
                        Label("Import Another File", systemImage: "icloud.and.arrow.down")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
    }

    private var dataLoadedScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Data Summary
                VStack(alignment: .leading, spacing: 10) {
                    Text("Data Summary")
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 30) {
                        DataSummaryItem(
                            icon: "tablecells",
                            label: "Rows",
                            value: "\(csvData!.rows.count)"
                        )

                        DataSummaryItem(
                            icon: "rectangle.split.3x1",
                            label: "Columns",
                            value: "\(csvData!.headers.count)"
                        )

                        DataSummaryItem(
                            icon: "number",
                            label: "Numeric",
                            value: "\(csvData!.columnTypes.filter { $0 == .numeric }.count)"
                        )
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }

                // Recommendations
                VStack(alignment: .leading, spacing: 15) {
                    Text("Recommended Charts")
                        .font(.title2)
                        .fontWeight(.bold)

                    ForEach(recommendations, id: \.recommendation) { score in
                        RecommendationCardView(
                            score: score,
                            selectedRecommendation: selectedRecommendation,
                            onSelection: { selectedRecommendation = score.recommendation }
                        )
                    }
                }

                // Chart Preview
                if let selected = selectedRecommendation {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Chart Preview")
                            .font(.title2)
                            .fontWeight(.bold)

                        SampleChartView(data: csvData!, recommendation: selected)
                    }
                }
            }
            .padding()
        }
    }

    private var bottomToolbar: some View {
        HStack {
            Button(action: { isImporting = true }) {
                Label("Import New File", systemImage: "arrow.up.doc")
            }

            Spacer()

            if selectedRecommendation != nil {
                Button(action: generateFullChart) {
                    Label("Generate Full Chart", systemImage: "wand.and.stars")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                nonCSVScreen

                if csvData == nil && nonCSVType == nil {
                    welcomeScreen
                } else if csvData != nil {
                    dataLoadedScreen
                    bottomToolbar
                }
            }
            .toolbar { // Add a toolbar
                ToolbarItem(placement: .navigationBarTrailing) { // Place the button on the trailing edge
                    Button("Dismiss") { // Create a button with the text "Dismiss"
                        dismiss() // Dismiss the current view
                    }
                }
            }
            .navigationTitle("File Classifier and Chart Recommender")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [
                    UTType.commaSeparatedText,
                    UTType.tabSeparatedText,
                    UTType.usdz,
                    UTType(filenameExtension: "ply") ?? UTType.data
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: nonCSVType) { oldValue, newValue in
                if let type = newValue {
                    handleNonCSVType(type)
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        nonCSVType = nil
        csvData = nil
        recommendations = []
        selectedRecommendation = nil

        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importedURL = url

            let classifier = FileClassifier()
            let (type, data, recs) = classifier.classifyFile(at: url)

            switch type {
            case .csv(_):
                if let data = data, let recommendationsList = recs, !recommendationsList.isEmpty {
                    csvData = data
                    recommendations = recommendationsList
                    selectedRecommendation = recommendations.first?.recommendation
                } else {
                    errorMessage = "Failed to parse CSV/TSV file or no recommendations available"
                }
            case .unknown:
                errorMessage = "Unknown file type"
            default:
                nonCSVType = type
            }

        case .failure(let error):
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func handleNonCSVType(_ type: FileType) {
        guard let url = importedURL else {
            errorMessage = "No file URL available"
            return
        }

        let id = windowManager.getNextWindowID()
        let position = WindowPosition(x: 100, y: 100, z: 0, width: 800, height: 600)

        switch type {
        case .pointCloudPLY:
            _ = windowManager.createWindow(.pointcloud, id: id, position: position)
            if let pointCloud = parsePLY(at: url) {
                windowManager.updateWindowPointCloud(id, pointCloud: pointCloud)
            }
            openWindow(id: "volumetric-pointcloud", value: id)
            windowManager.markWindowAsOpened(id)

        case .usdz:
            _ = windowManager.createWindow(.model3d, id: id, position: position)
            do {
                let bookmark = try url.bookmarkData(options: .minimalBookmark)
                windowManager.updateUSDZBookmark(for: id, bookmark: bookmark)
            } catch {
                print("Error creating bookmark: \(error)")
            }
            openWindow(id: "volumetric-model3d", value: id)
            windowManager.markWindowAsOpened(id)

        default:
            break
        }

        dismiss()
    }

    private func generateFullChart() {
        let id = windowManager.getNextWindowID()
        let position = WindowPosition(x: 100, y: 100, z: 0, width: 800, height: 600)

        _ = windowManager.createWindow(.charts, id: id, position: position)
        openWindow(value: id)
        windowManager.markWindowAsOpened(id)

        // TODO: Update window state with csvData and selectedRecommendation for rendering the chart

        dismiss()
    }
}

struct RecommendationCardView: View {
    let score: ChartScore
    let selectedRecommendation: ChartRecommendation?
    let onSelection: () -> Void

    private var isSelected: Bool {
        selectedRecommendation == score.recommendation
    }

    private var iconColor: Color {
        isSelected ? .white : .blue
    }

    private var titleColor: Color {
        isSelected ? .white : .primary
    }

    private var descriptionColor: Color {
        isSelected ? .white.opacity(0.8) : .secondary
    }

    private var scoreColor: Color {
        isSelected ? .white : .green
    }

    private var backgroundColor: Color {
        isSelected ? Color.blue : Color.gray.opacity(0.1)
    }

    var body: some View {
        Button(action: onSelection) {
            HStack {
                Image(systemName: score.recommendation.icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 5) {
                    Text(score.recommendation.name)
                        .font(.headline)
                        .foregroundColor(titleColor)

                    Text(score.reasoning)
                        .font(.caption)
                        .foregroundColor(descriptionColor)
                        .lineLimit(2)
                }

                Spacer()

                VStack {
                    Text("\(Int(score.score * 100))%")
                        .font(.headline)
                        .foregroundColor(scoreColor)
                    Text("match")
                        .font(.caption2)
                        .foregroundColor(descriptionColor)
                }
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct DataSummaryItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}

#Preview {
    FileClassifierAndRecommenderView()
}
