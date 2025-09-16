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
                let raw = try String(contentsOf: url, encoding: .utf8)
                let preferTab: Character? = (fileExtension == "tsv" || fileExtension == "tab") ? "\t" : nil
                if let data = CSVParser.parseAuto(raw, preferredDelimiter: preferTab) {
                    let recommendations = ChartRecommender.recommend(for: data)
                    let chosen = preferTab ?? "," // best-effort log
                    print("DEBUG CSV/TSV: auto-parse ok, preferred='\(preferTab != nil ? "\\t" : ",")', headers=\(data.headers.count), rows=\(data.rows.count)")
                    return (.csv(delimiter: preferTab != nil ? "\t" : ","), data, recommendations)
                } else {
                    print("Error: CSV/TSV auto-parse failed")
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
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = row.startIndex

        func appendField() {
            // Unescape double quotes inside quoted fields
            let unescaped = current.replacingOccurrences(of: "\"\"", with: "\"")
            fields.append(unescaped)
            current = ""
        }

        while i < row.endIndex {
            let ch = row[i]
            if ch == "\"" {
                if inQuotes {
                    // Lookahead for escaped quote
                    let next = row.index(after: i)
                    if next < row.endIndex && row[next] == "\"" {
                        current.append("\"")
                        i = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if ch == delimiter && !inQuotes {
                // End of field
                appendField()
            } else {
                current.append(ch)
            }
            i = row.index(after: i)
        }

        // Append last field
        appendField()

        // Trim surrounding spaces only for non-quoted style (already handled by quotes logic)
        return fields.map { $0.trimmingCharacters(in: .whitespaces) }
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

extension CSVParser {
    /// Normalize content: BOM, CRLF to LF, and escaped tabs to real tabs
    private static func normalize(_ content: String) -> String {
        var s = content
        // Remove UTF-8 BOM if present
        if s.hasPrefix("\u{FEFF}") { s.removeFirst() }
        // Normalize CRLF and CR to LF
        s = s.replacingOccurrences(of: "\r\n", with: "\n")
             .replacingOccurrences(of: "\r", with: "\n")
        // Convert escaped tabs to real tabs
        s = s.replacingOccurrences(of: "\\t", with: "\t")
        return s
    }

    /// Detect delimiter by scanning up to first 20 non-empty lines and choosing the one with the most consistent column count.
    private static func detectDelimiter(lines: [String], preferred: Character? = nil) -> Character {
        if let preferred = preferred { return preferred }
        let candidates: [Character] = ["\t", ",", ";"]
        var best: (delim: Character, consistency: Int, columns: Int) = (",", -1, 0)

        for cand in candidates {
            var counts: [Int: Int] = [:]
            for line in lines.prefix(20) {
                let cols = parseRow(line, delimiter: cand).count
                counts[cols, default: 0] += 1
            }
            if let (cols, freq) = counts.max(by: { $0.value < $1.value }) {
                if freq > best.consistency || (freq == best.consistency && cols > best.columns) {
                    best = (cand, freq, cols)
                }
            }
        }
        return best.delim
    }

    /// Auto-detect delimiter (tab/comma/semicolon), with optional preference, and parse.
    static func parseAuto(_ content: String, preferredDelimiter: Character? = nil) -> CSVData? {
        let normalized = normalize(content)
        let lines = normalized.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        let delimiter = detectDelimiter(lines: lines, preferred: preferredDelimiter)
        let headers = parseRow(lines[0], delimiter: delimiter)
        guard !headers.isEmpty else { return nil }

        var rows: [[String]] = []
        for line in lines.dropFirst() {
            let fields = parseRow(line, delimiter: delimiter)
            // Pad or truncate to header count for consistency
            var adjusted = fields
            if adjusted.count < headers.count { adjusted += Array(repeating: "", count: headers.count - adjusted.count) }
            if adjusted.count > headers.count { adjusted = Array(adjusted.prefix(headers.count)) }
            rows.append(adjusted)
        }

        let columnTypes = detectColumnTypes(headers: headers, rows: rows)
        return CSVData(headers: headers, rows: rows, columnTypes: columnTypes)
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
