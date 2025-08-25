// File: FileClassifier.swift

import SwiftUI
import Charts
import UniformTypeIdentifiers
import Foundation
import RealityKit

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
        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "ply":
            guard url.startAccessingSecurityScopedResource() else {
                print("Error: Could not access security-scoped resource for PLY.")
                return (.unknown, nil, nil)
            }
            defer { url.stopAccessingSecurityScopedResource() }

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

        case "pcd":
            guard url.startAccessingSecurityScopedResource() else {
                print("Error: Could not access security-scoped resource for PCD.")
                return (.unknown, nil, nil)
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                if let header = String(data: data.prefix(100), encoding: .ascii), header.lowercased().hasPrefix("version") || header.lowercased().hasPrefix("# .pcd") {
                    return (.pointCloudPLY, nil, nil) // Reuse PLY handler for PCD since both are point clouds
                } else {
                    return (.unknown, nil, nil)
                }
            } catch {
                print("Error reading PCD file: \(error)")
                return (.unknown, nil, nil)
            }

        case "xyz", "pts":
            guard url.startAccessingSecurityScopedResource() else {
                print("Error: Could not access security-scoped resource for XYZ/PTS.")
                return (.unknown, nil, nil)
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
                if !lines.isEmpty {
                    // Basic validation: check if first line has 3+ space-separated numbers
                    let firstLineComponents = lines[0].components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if firstLineComponents.count >= 3 {
                        if let _ = Double(firstLineComponents[0]), 
                           let _ = Double(firstLineComponents[1]), 
                           let _ = Double(firstLineComponents[2]) {
                            return (.pointCloudPLY, nil, nil) // Reuse PLY handler for XYZ/PTS
                        }
                    }
                }
                return (.unknown, nil, nil)
            } catch {
                print("Error reading XYZ/PTS file: \(error)")
                return (.unknown, nil, nil)
            }

        case "usdz":
            return (.usdz, nil, nil)

        case "csv", "tsv", "tab":
            // Handle CSV or tab-separated files
            guard url.startAccessingSecurityScopedResource() else {
                print("Error: Could not access security-scoped resource for CSV.")
                return (.unknown, nil, nil)
            }
            defer { url.stopAccessingSecurityScopedResource() }

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
// Custom UTType extensions for point cloud files
extension UTType {
    static let plyFile = UTType(filenameExtension: "ply") ?? UTType.plainText
    static let pcdFile = UTType(filenameExtension: "pcd") ?? UTType.plainText
    static let xyzFile = UTType(filenameExtension: "xyz") ?? UTType.plainText
}