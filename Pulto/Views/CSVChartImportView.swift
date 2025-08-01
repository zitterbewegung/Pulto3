//
//  CSVChartImportView.swift
//  Pulto3
//
//  Created by Assistant on 1/29/25.
//

import SwiftUI
import Charts
import UniformTypeIdentifiers

struct CSVChartImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var windowManager: WindowTypeManager
    
    @State private var csvData: CSVData?
    @State private var recommendations: [ChartScore] = []
    @State private var selectedRecommendation: ChartRecommendation?
    @State private var isImporting = false
    @State private var showingPreview = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if csvData == nil {
                    welcomeView
                } else {
                    dataLoadedView
                }
            }
            .navigationTitle("CSV Chart Import")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if csvData != nil && selectedRecommendation != nil {
                        Button("Create Chart") {
                            createChartWindow()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [
                    .commaSeparatedText,
                    .tabSeparatedText,
                    .plainText,
                    .text
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Import Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showingPreview) {
                if let csvData = csvData, let recommendation = selectedRecommendation {
                    ChartPreviewSheet(
                        data: csvData,
                        recommendation: recommendation,
                        onCreateChart: createChartWindow
                    )
                }
            }
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 30) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 80))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .green],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            VStack(spacing: 16) {
                Text("Import CSV for Charts")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Select a CSV or TSV file to automatically generate chart recommendations and visualizations")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                Button(action: { isImporting = true }) {
                    Label("Select CSV/TSV File", systemImage: "doc.text")
                        .font(.title3)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Text("Supports CSV, TSV, and other delimited text files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Sample data preview
            sampleDataSection
        }
        .padding()
    }
    
    private var sampleDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Example Data Format")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("CSV Example:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("""
                Product,Sales,Revenue,Region
                iPhone,1500,75000,North America
                iPad,1200,48000,Europe
                MacBook,800,96000,Asia
                """)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var dataLoadedView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Data summary
                dataSummarySection
                
                // Chart recommendations
                if !recommendations.isEmpty {
                    recommendationsSection
                }
                
                // Preview section
                if selectedRecommendation != nil {
                    previewSection
                }
                
                Spacer(minLength: 100) // Space for toolbar
            }
            .padding(.horizontal)
        }
    }
    
    private var dataSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Summary")
                .font(.title2)
                .fontWeight(.bold)
            
            if let csvData = csvData {
                HStack(spacing: 20) {
                    SummaryCard(
                        icon: "tablecells",
                        title: "Rows",
                        value: "\(csvData.rows.count)",
                        color: .blue
                    )
                    
                    SummaryCard(
                        icon: "rectangle.split.3x1",
                        title: "Columns",
                        value: "\(csvData.headers.count)",
                        color: .green
                    )
                    
                    SummaryCard(
                        icon: "number",
                        title: "Numeric",
                        value: "\(csvData.columnTypes.filter { $0 == .numeric }.count)",
                        color: .orange
                    )
                }
            }
        }
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chart Recommendations")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(recommendations, id: \.recommendation) { score in
                    RecommendationCard(
                        score: score,
                        isSelected: selectedRecommendation == score.recommendation
                    ) {
                        selectedRecommendation = score.recommendation
                    }
                }
            }
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Chart Preview")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Full Preview") {
                    showingPreview = true
                }
                .buttonStyle(.bordered)
            }
            
            if let csvData = csvData, let recommendation = selectedRecommendation {
                SampleChartView(data: csvData, recommendation: recommendation)
                    .frame(height: 250)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            Task {
                do {
                    let parsedData = try await parseCSVFile(at: url)
                    await MainActor.run {
                        csvData = parsedData
                        recommendations = ChartRecommender.recommend(for: parsedData)
                        selectedRecommendation = recommendations.first?.recommendation
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to parse file: \(error.localizedDescription)"
                    }
                }
            }
            
        case .failure(let error):
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }
    
    private func parseCSVFile(at url: URL) async throws -> CSVData {
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        
        // Determine delimiter
        let firstLine = content.components(separatedBy: .newlines).first ?? ""
        let commaCount = firstLine.filter { $0 == "," }.count
        let tabCount = firstLine.filter { $0 == "\t" }.count
        
        let delimiter: Character = tabCount > commaCount ? "\t" : ","
        
        guard let parsedData = CSVParser.parse(content, delimiter: delimiter) else {
            throw ImportError.parseError
        }
        
        return parsedData
    }
    
    private func createChartWindow() {
        guard let csvData = csvData, let recommendation = selectedRecommendation else {
            return
        }
        
        // Create a new chart window
        let windowID = windowManager.getNextWindowID()
        let position = WindowPosition(x: 100, y: 100, z: 0, width: 1000, height: 700)
        
        _ = windowManager.createWindow(.charts, id: windowID, position: position)
        
        // Create chart data from CSV
        let chartData = createChartData(from: csvData, recommendation: recommendation)
        windowManager.updateWindowChartData(windowID, chartData: chartData)
        
        // Store the CSV data for the chart view
        windowManager.updateWindowContent(windowID, content: "CSV Chart: \(recommendation.name)")
        windowManager.addWindowTag(windowID, tag: "CSV-Import")
        
        // Open the window
        openWindow(value: windowID)
        windowManager.markWindowAsOpened(windowID)
        
        dismiss()
    }
    
    private func createChartData(from csvData: CSVData, recommendation: ChartRecommendation) -> ChartData {
        // Find appropriate columns based on recommendation
        let numericIndices = csvData.columnTypes.enumerated().compactMap { 
            $0.element == .numeric ? $0.offset : nil 
        }
        let categoricalIndices = csvData.columnTypes.enumerated().compactMap { 
            $0.element == .categorical ? $0.offset : nil 
        }
        
        let xLabel: String
        let yLabel: String
        let xData: [Double]
        let yData: [Double]
        
        switch recommendation {
        case .lineChart, .areaChart:
            if let xIndex = numericIndices.first, let yIndex = numericIndices.dropFirst().first {
                xLabel = csvData.headers[xIndex]
                yLabel = csvData.headers[yIndex]
                xData = csvData.rows.enumerated().compactMap { index, _ in Double(index) }
                yData = csvData.rows.compactMap { row in 
                    yIndex < row.count ? Double(row[yIndex]) : nil 
                }
            } else {
                xLabel = "Index"
                yLabel = "Value"
                xData = csvData.rows.enumerated().map { Double($0.offset) }
                yData = Array(0..<csvData.rows.count).map { _ in Double.random(in: 0...100) }
            }
            
        case .barChart, .pieChart:
            if let catIndex = categoricalIndices.first, let numIndex = numericIndices.first {
                xLabel = csvData.headers[catIndex]
                yLabel = csvData.headers[numIndex]
                xData = csvData.rows.enumerated().map { Double($0.offset) }
                yData = csvData.rows.compactMap { row in 
                    numIndex < row.count ? Double(row[numIndex]) : nil 
                }
            } else {
                xLabel = "Category"
                yLabel = "Value"
                xData = csvData.rows.enumerated().map { Double($0.offset) }
                yData = Array(0..<csvData.rows.count).map { _ in Double.random(in: 0...100) }
            }
            
        case .scatterPlot:
            if numericIndices.count >= 2 {
                let xIndex = numericIndices[0]
                let yIndex = numericIndices[1]
                xLabel = csvData.headers[xIndex]
                yLabel = csvData.headers[yIndex]
                xData = csvData.rows.compactMap { row in 
                    xIndex < row.count ? Double(row[xIndex]) : nil 
                }
                yData = csvData.rows.compactMap { row in 
                    yIndex < row.count ? Double(row[yIndex]) : nil 
                }
            } else {
                xLabel = "X Values"
                yLabel = "Y Values"
                xData = Array(0..<csvData.rows.count).map { _ in Double.random(in: 0...100) }
                yData = Array(0..<csvData.rows.count).map { _ in Double.random(in: 0...100) }
            }
            
        case .histogram:
            if let numIndex = numericIndices.first {
                xLabel = csvData.headers[numIndex]
                yLabel = "Frequency"
                let values = csvData.rows.compactMap { row in 
                    numIndex < row.count ? Double(row[numIndex]) : nil 
                }
                xData = values
                yData = Array(repeating: 1.0, count: values.count)
            } else {
                xLabel = "Values"
                yLabel = "Frequency"
                xData = Array(0..<csvData.rows.count).map { _ in Double.random(in: 0...100) }
                yData = Array(repeating: 1.0, count: csvData.rows.count)
            }
        }
        
        return ChartData(
            title: "Imported CSV Chart: \(recommendation.name)",
            chartType: recommendation.name.lowercased().replacingOccurrences(of: " ", with: "_"),
            xLabel: xLabel,
            yLabel: yLabel,
            xData: xData,
            yData: yData,
            color: "blue",
            style: "solid"
        )
    }
}

// MARK: - Supporting Views

struct SummaryCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct RecommendationCard: View {
    let score: ChartScore
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: score.recommendation.icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : .blue)
                    
                    Spacer()
                    
                    Text("\(Int(score.score * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(isSelected ? .white : .green)
                }
                
                Text(score.recommendation.name)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Text(score.reasoning)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(3)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ChartPreviewSheet: View {
    let data: CSVData
    let recommendation: ChartRecommendation
    let onCreateChart: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                SampleChartView(data: data, recommendation: recommendation)
                    .frame(height: 400)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Chart Details")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow(label: "Type", value: recommendation.name)
                        DetailRow(label: "Data Points", value: "\(data.rows.count)")
                        DetailRow(label: "Columns", value: "\(data.headers.count)")
                        DetailRow(label: "Description", value: recommendation.description)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Chart Preview")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create Chart") {
                        onCreateChart()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}

// MARK: - Error Types

enum ImportError: LocalizedError {
    case accessDenied
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Cannot access the selected file"
        case .parseError:
            return "Failed to parse the CSV/TSV file"
        }
    }
}

#Preview {
    CSVChartImportView()
        .environmentObject(WindowTypeManager.shared)
}