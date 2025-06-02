//
//  CSVData.swift
//  Pulto
//
//  Created by Joshua Herman on 6/1/25.
//  Copyright © 2025 Apple. All rights reserved.
//


import SwiftUI
import Charts
import UniformTypeIdentifiers

// MARK: - Data Models
struct CSVData {
    let headers: [String]
    let rows: [[String]]
    let columnTypes: [ColumnType]
}

enum ColumnType {
    case numeric
    case categorical
    case date
    case unknown
}

enum ChartRecommendation: CaseIterable {
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

struct ChartScore {
    let recommendation: ChartRecommendation
    let score: Double
    let reasoning: String
}

// MARK: - CSV Parser
class CSVParser {
    static func parse(_ content: String) -> CSVData? {
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return nil }
        
        let headers = parseRow(lines[0])
        var rows: [[String]] = []
        
        for i in 1..<lines.count {
            rows.append(parseRow(lines[i]))
        }
        
        let columnTypes = detectColumnTypes(headers: headers, rows: rows)
        
        return CSVData(headers: headers, rows: rows, columnTypes: columnTypes)
    }
    
    private static func parseRow(_ row: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        
        for char in row {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if csvData == nil {
                    // Welcome screen
                    VStack(spacing: 30) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("CSV Chart Recommender")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Import a CSV file from iCloud to get intelligent chart recommendations")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: { isImporting = true }) {
                            Label("Import CSV from iCloud", systemImage: "icloud.and.arrow.down")
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
                                    RecommendationCard(
                                        score: score,
                                        isSelected: selectedRecommendation == score.recommendation,
                                        action: { selectedRecommendation = score.recommendation }
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
                            Label("Import New CSV", systemImage: "arrow.up.doc")
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
            .navigationTitle("Chart Recommender")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [UTType.commaSeparatedText],
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
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let content = try String(contentsOf: url)
                if let data = CSVParser.parse(content) {
                    csvData = data
                    recommendations = ChartRecommender.recommend(for: data)
                    selectedRecommendation = recommendations.first?.recommendation
                } else {
                    errorMessage = "Failed to parse CSV file"
                }
            } catch {
                errorMessage = "Error reading file: \(error.localizedDescription)"
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

struct RecommendationCard: View {
    let score: ChartScore
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: score.recommendation.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(score.recommendation.name)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(score.reasoning)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack {
                    Text("\(Int(score.score * 100))%")
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .green)
                    Text("match")
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding()
            .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App Entry Point
struct ContentView: View {
    var body: some View {
        CSVChartRecommenderView()
    }
}