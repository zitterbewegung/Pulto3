//
//  CSVData.swift
//  Pulto
//
//  Created by Joshua Herman on 6/1/25.
//  Copyright 2025 Apple. All rights reserved.
//

import SwiftUI
import Charts
import UniformTypeIdentifiers
import Foundation

// MARK: - File Classifier
enum FileType: Equatable {
    case pointCloudPLY
    case csv(delimiter: String)
    case usdz
    case unknown

    var description: String {
        switch self {
        case .pointCloudPLY:
            return "Point Cloud (PLY) file"
        case .csv(let del):
            return "CSV file (delimiter: \(del))"
        case .usdz:
            return "USDZ 3D model file"
        case .unknown:
            return "Unknown file"
        }
    }
}

struct FileClassifier {

    func classifyFile(at url: URL) -> (FileType, CSVData?, [ChartScore]?) {
        // Start accessing the security-scoped resource
        // Note: This is required for security-scoped URLs from fileImporter in sandboxed environments like VisionOS.
        // If encountering issues, verify the context; it should exist on URL.
        guard url.startAccessingSecurityScopedResource() else {
            print("Error: Could not access security-scoped resource.")
            return (.unknown, nil, nil)
        }

        // Ensure to stop accessing when done
        defer {
            url.stopAccessingSecurityScopedResource()
        }

        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "ply":
            // Basic check to confirm it's a PLY file (point cloud)
            do {
                let data = try Data(contentsOf: url)
                if let header = String(data: data.prefix(100), encoding: .ascii), header.lowercased().hasPrefix("ply") {
                    return (.pointCloudPLY, nil, nil)
                } else {
                    return (.unknown, nil, nil)
                }
            } catch {
                print("Error reading PLY file: \(error)")
                return (.unknown, nil, nil)
            }

        case "usdz":
            // USDZ is a zip archive, but for simplicity, assume extension is sufficient
            // If needed, check if it's a valid zip with USD content, but that's more complex
            return (.usdz, nil, nil)

        case "csv", "tsv", "tab":
            // Handle CSV or tab-separated files
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
                guard !lines.isEmpty else {
                    return (.unknown, nil, nil)
                }

                // Determine delimiter: check first line for commas vs tabs
                let firstLine = lines[0]
                let commaCount = firstLine.filter { $0 == "," }.count
                let tabCount = firstLine.filter { $0 == "\t" }.count

                let delimiterChar: Character
                let delimiterStr: String
                if commaCount > tabCount && commaCount > 0 {
                    delimiterChar = ","
                    delimiterStr = ","
                } else if tabCount > 0 {
                    delimiterChar = "\t"
                    delimiterStr = "\t"
                } else {
                    // No clear delimiter, assume comma for .csv
                    if fileExtension == "csv" {
                        delimiterChar = ","
                        delimiterStr = ","
                    } else {
                        return (.unknown, nil, nil)
                    }
                }

                if let data = CSVParser.parse(content, delimiter: delimiterChar) {
                    let recommendations = ChartRecommender.recommend(for: data)
                    return (.csv(delimiter: delimiterStr), data, recommendations)
                } else {
                    return (.unknown, nil, nil)
                }

            } catch {
                print("Error reading CSV/TSV file: \(error)")
                return (.unknown, nil, nil)
            }

        default:
            return (.unknown, nil, nil)
        }
    }
}

// MARK: - Data Models
struct CSVData: Equatable {
    let headers: [String]
    let rows: [[String]]
    let columnTypes: [ColumnType]
}

enum ColumnType: Equatable {
    case numeric
    case categorical
    case date
    case unknown
}

enum ChartRecommendation: CaseIterable, Equatable {
    case lineChart
    case barChart
    case scatterPlot
    case pieChart
    case areaChart
    case histogram

    var name: String {
        switch self {
        case .lineChart: return "Line Chart"
        case .barChart: return "Bar Chart"
        case .scatterPlot: return "Scatter Plot"
        case .pieChart: return "Pie Chart"
        case .areaChart: return "Area Chart"
        case .histogram: return "Histogram"
        }
    }

    var description: String {
        switch self {
        case .lineChart: return "Best for showing trends over time"
        case .barChart: return "Ideal for comparing categories"
        case .scatterPlot: return "Perfect for showing relationships between two numeric variables"
        case .pieChart: return "Good for showing proportions of a whole"
        case .areaChart: return "Great for showing cumulative trends"
        case .histogram: return "Excellent for showing distribution of numeric data"
        }
    }

    var icon: String {
        switch self {
        case .lineChart: return "chart.line.uptrend.xyaxis"
        case .barChart: return "chart.bar"
        case .scatterPlot: return "chart.dots.scatter"
        case .pieChart: return "chart.pie"
        case .areaChart: return "chart.line.uptrend.xyaxis.circle.fill"
        case .histogram: return "chart.bar.doc.horizontal"
        }
    }
}

struct ChartScore: Equatable {
    let recommendation: ChartRecommendation
    let score: Double
    let reasoning: String
}

// MARK: - CSV Parser (Modified to handle custom delimiter)
class CSVParser {
    static func parse(_ content: String, delimiter: Character = ",") -> CSVData? {
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return nil }

        let headers = parseRow(lines[0], delimiter: delimiter)
        var rows: [[String]] = []

        for i in 1..<lines.count {
            rows.append(parseRow(lines[i], delimiter: delimiter))
        }

        let columnTypes = detectColumnTypes(headers: headers, rows: rows)

        return CSVData(headers: headers, rows: rows, columnTypes: columnTypes)
    }

    private static func parseRow(_ row: String, delimiter: Character) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in row {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == delimiter && !inQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }

        result.append(current.trimmingCharacters(in: .whitespaces))
        return result
    }

    private static func detectColumnTypes(headers: [String], rows: [[String]]) -> [ColumnType] {
        return headers.indices.map { index in
            detectColumnType(at: index, rows: rows)
        }
    }

    private static func detectColumnType(at index: Int, rows: [[String]]) -> ColumnType {
        var numericCount = 0
        var dateCount = 0
        let totalCount = rows.count

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let altDateFormatter = DateFormatter()
        altDateFormatter.dateFormat = "MM/dd/yyyy"

        for row in rows {
            guard index < row.count else { continue }
            let value = row[index]

            if Double(value) != nil {
                numericCount += 1
            } else if dateFormatter.date(from: value) != nil || altDateFormatter.date(from: value) != nil {
                dateCount += 1
            }
        }

        if Double(numericCount) / Double(totalCount) > 0.8 {
            return .numeric
        } else if Double(dateCount) / Double(totalCount) > 0.8 {
            return .date
        } else {
            return .categorical
        }
    }
}

// MARK: - Chart Recommender
class ChartRecommender {
    static func recommend(for data: CSVData) -> [ChartScore] {
        var scores: [ChartScore] = []

        let numericColumns = data.columnTypes.filter { $0 == .numeric }.count
        let categoricalColumns = data.columnTypes.filter { $0 == .categorical }.count
        let dateColumns = data.columnTypes.filter { $0 == .date }.count
        let rowCount = data.rows.count

        // Line Chart recommendation
        if dateColumns > 0 && numericColumns > 0 {
            scores.append(ChartScore(
                recommendation: .lineChart,
                score: 0.9,
                reasoning: "You have date and numeric columns - perfect for showing trends over time"
            ))
        }

        // Bar Chart recommendation
        if categoricalColumns > 0 && numericColumns > 0 {
            scores.append(ChartScore(
                recommendation: .barChart,
                score: 0.85,
                reasoning: "Categorical and numeric data work well for comparing values across categories"
            ))
        }

        // Scatter Plot recommendation
        if numericColumns >= 2 {
            scores.append(ChartScore(
                recommendation: .scatterPlot,
                score: 0.8,
                reasoning: "Multiple numeric columns can show relationships and correlations"
            ))
        }

        // Pie Chart recommendation
        if categoricalColumns > 0 && numericColumns > 0 && rowCount < 10 {
            scores.append(ChartScore(
                recommendation: .pieChart,
                score: 0.7,
                reasoning: "Small dataset with categories is suitable for showing proportions"
            ))
        }

        // Area Chart recommendation
        if dateColumns > 0 && numericColumns > 0 {
            scores.append(ChartScore(
                recommendation: .areaChart,
                score: 0.75,
                reasoning: "Time-series data can be visualized with filled areas to show cumulative values"
            ))
        }

        // Histogram recommendation
        if numericColumns > 0 {
            scores.append(ChartScore(
                recommendation: .histogram,
                score: 0.65,
                reasoning: "Numeric data can be binned to show distribution patterns"
            ))
        }

        return scores.sorted { $0.score > $1.score }
    }
}

// MARK: - Sample Chart Views
struct SampleChartView: View {
    let data: CSVData
    let recommendation: ChartRecommendation

    var body: some View {
        VStack {
            switch recommendation {
            case .lineChart:
                LineChartView(data: data)
            case .barChart:
                BarChartView(data: data)
            case .scatterPlot:
                ScatterPlotView(data: data)
            case .pieChart:
                PieChartView(data: data)
            case .areaChart:
                AreaChartView(data: data)
            case .histogram:
                HistogramView(data: data)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct LineChartView: View {
    let data: CSVData

    var body: some View {
        if let xIndex = data.columnTypes.firstIndex(where: { $0 == .date || $0 == .numeric }),
           let yIndex = data.columnTypes.firstIndex(where: { $0 == .numeric }) {
            Chart {
                ForEach(Array(data.rows.prefix(20).enumerated()), id: \.offset) { index, row in
                    if xIndex < row.count && yIndex < row.count,
                       let yValue = Double(row[yIndex]) {
                        LineMark(
                            x: .value("X", row[xIndex]),
                            y: .value("Y", yValue)
                        )
                    }
                }
            }
            .frame(height: 200)
        } else {
            Text("Insufficient data for line chart")
                .foregroundColor(.secondary)
        }
    }
}

struct BarChartView: View {
    let data: CSVData

    var body: some View {
        if let catIndex = data.columnTypes.firstIndex(where: { $0 == .categorical }),
           let numIndex = data.columnTypes.firstIndex(where: { $0 == .numeric }) {
            Chart {
                ForEach(Array(data.rows.prefix(10).enumerated()), id: \.offset) { index, row in
                    if catIndex < row.count && numIndex < row.count,
                       let value = Double(row[numIndex]) {
                        BarMark(
                            x: .value("Category", row[catIndex]),
                            y: .value("Value", value)
                        )
                    }
                }
            }
            .frame(height: 200)
        } else {
            Text("Insufficient data for bar chart")
                .foregroundColor(.secondary)
        }
    }
}

struct ScatterPlotView: View {
    let data: CSVData

    var body: some View {
        let numericIndices = data.columnTypes.enumerated().compactMap { $0.element == .numeric ? $0.offset : nil }

        if numericIndices.count >= 2 {
            Chart {
                ForEach(Array(data.rows.prefix(50).enumerated()), id: \.offset) { index, row in
                    if let xValue = Double(row[numericIndices[0]]),
                       let yValue = Double(row[numericIndices[1]]) {
                        PointMark(
                            x: .value("X", xValue),
                            y: .value("Y", yValue)
                        )
                    }
                }
            }
            .frame(height: 200)
        } else {
            Text("Insufficient numeric columns for scatter plot")
                .foregroundColor(.secondary)
        }
    }
}

struct PieChartView: View {
    let data: CSVData

    var body: some View {
        Text("Pie Chart Preview")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(height: 200)
    }
}

struct AreaChartView: View {
    let data: CSVData

    var body: some View {
        if let xIndex = data.columnTypes.firstIndex(where: { $0 == .date || $0 == .numeric }),
           let yIndex = data.columnTypes.firstIndex(where: { $0 == .numeric }) {
            Chart {
                ForEach(Array(data.rows.prefix(20).enumerated()), id: \.offset) { index, row in
                    if xIndex < row.count && yIndex < row.count,
                       let yValue = Double(row[yIndex]) {
                        AreaMark(
                            x: .value("X", row[xIndex]),
                            y: .value("Y", yValue)
                        )
                    }
                }
            }
            .frame(height: 200)
        } else {
            Text("Insufficient data for area chart")
                .foregroundColor(.secondary)
        }
    }
}

struct HistogramView: View {
    let data: CSVData

    var body: some View {
        if let numIndex = data.columnTypes.firstIndex(where: { $0 == .numeric }) {
            let values = data.rows.compactMap { row in
                numIndex < row.count ? Double(row[numIndex]) : nil
            }

            if !values.isEmpty {
                Chart {
                    ForEach(Array(values.prefix(30).enumerated()), id: \.offset) { index, value in
                        BarMark(
                            x: .value("Value", value),
                            y: .value("Count", 1)
                        )
                    }
                }
                .frame(height: 200)
            } else {
                Text("No numeric data for histogram")
                    .foregroundColor(.secondary)
            }
        } else {
            Text("No numeric columns for histogram")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Main View
struct CSVChartRecommenderView: View {
    @State private var csvData: CSVData?
    @State private var recommendations: [ChartScore] = []
    @State private var selectedRecommendation: ChartRecommendation?
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var nonCSVType: FileType?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {

                VStack(spacing: 20) {


                    if let type = nonCSVType {
                        // Non-CSV file imported
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
                    } else if csvData == nil {
                        // Welcome screen
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
                    } else {
                        // Data loaded view
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

                        // Bottom toolbar
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

            do {
                // Note: startAccessingSecurityScopedResource is called inside the classifier,
                // but if needed here for additional access, it can be added.
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
            } catch {
                errorMessage = "Error processing file: \(error.localizedDescription)"
            }

        case .failure(let error):
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func generateFullChart() {
        // This would typically generate a more detailed chart view
        // For now, it's a placeholder for future implementation
        print("Generating full chart for \(selectedRecommendation?.name ?? "")")
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
    CSVChartRecommenderView()
}
