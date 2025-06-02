//
//  EnhancedRecommendationCard.swift
//  Pulto
//
//  Created by Joshua Herman on 6/1/25.
//  Copyright © 2025 Apple. All rights reserved.
//

/*
// MARK: - Updated Main View with Explanation Integration
extension CSVChartRecommenderView {
    @State private var showingExplanation = false
    
    var bodyWithExplanation: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if csvData == nil {
                    // Welcome screen (unchanged)
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
                    // Data loaded view with explanation button
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Data Summary with Explanation Button
                            HStack {
                                Text("Data Summary")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                Button(action: { showingExplanation = true }) {
                                    Label("Why these charts?", systemImage: "questionmark.circle")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            
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
                            
                            // Recommendations with enhanced cards
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Recommended Charts")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                ForEach(recommendations, id: \.recommendation) { score in
                                    EnhancedRecommendationCard(
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
            .sheet(isPresented: $showingExplanation) {
                NavigationView {
                    if let data = csvData {
                        let analysis = ChartRecommender.analyzeData(data)
                        ChartExplanationView(data: data, analysis: analysis)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        showingExplanation = false
                                    }
                                }
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Recommendation Card with Quick Insights
struct EnhancedRecommendationCard: View {
    let score: ChartScore
    let isSelected: Bool
    let action: () -> Void
    @State private var showingQuickInfo = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: score.recommendation.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(score.recommendation.name)
                            .font(.headline)
                            .foregroundColor(isSelected ? .white : .primary)
                        
                        Button(action: { showingQuickInfo.toggle() }) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .blue)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(score.reasoning)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(showingQuickInfo ? nil : 2)
                    
                    if showingQuickInfo {
                        Text(score.recommendation.description)
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                            .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                VStack {
                    Text("\(Int(score.score * 100))%")
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : scoreColor(score.score))
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
    
    func scoreColor(_ score: Double) -> Color {
        if score >= 0.8 { return .green }
        else if score >= 0.6 { return .orange }
        else { return .red }
    }
}

// MARK: - Quick Insights Popover
struct QuickInsightsView: View {
    let data: CSVData
    let recommendations: [ChartScore]
    
    var topInsights: [String] {
        var insights: [String] = []
        
        // Data shape insight
        if data.rows.count > 1000 {
            insights.append("📊 Large dataset with \(data.rows.count) rows - consider sampling for better performance")
        } else if data.rows.count < 20 {
            insights.append("📋 Small dataset - all chart types will render quickly")
        }
        
        // Column type insights
        let numericCount = data.columnTypes.filter { $0 == .numeric }.count
        let categoricalCount = data.columnTypes.filter { $0 == .categorical }.count
        let dateCount = data.columnTypes.filter { $0 == .date }.count
        
        if dateCount > 0 && numericCount > 0 {
            insights.append("📈 Time series data detected - line and area charts recommended")
        }
        
        if numericCount >= 2 {
            insights.append("🔍 Multiple numeric columns - explore correlations with scatter plots")
        }
        
        if categoricalCount > 0 && data.rows.count < 50 {
            insights.append("🥧 Small categorical dataset - pie charts could work well")
        }
        
        return insights
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Insights")
                .font(.headline)
            
            ForEach(topInsights, id: \.self) { insight in
                Text(insight)
                    .font(.caption)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
            }
            
            Divider()
            
            Text("Top Recommendation")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if let topRec = recommendations.first {
                HStack {
                    Image(systemName: topRec.recommendation.icon)
                        .foregroundColor(.blue)
                    Text(topRec.recommendation.name)
                        .font(.caption)
                    Spacer()
                    Text("\(Int(topRec.score * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - Export Options
struct ChartExportView: View {
    let data: CSVData
    let chartType: ChartRecommendation
    @State private var exportFormat = "PNG"
    @State private var includeAnalysis = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Export Chart")
                .font(.title2)
                .fontWeight(.bold)
            
            // Format selection
            VStack(alignment: .leading, spacing: 10) {
                Text("Export Format")
                    .font(.headline)
                
                Picker("Format", selection: $exportFormat) {
                    Text("PNG Image").tag("PNG")
                    Text("PDF Document").tag("PDF")
                    Text("SwiftUI Code").tag("Code")
                    Text("Raw Data + Config").tag("JSON")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Options
            Toggle("Include data analysis", isOn: $includeAnalysis)
            
            // Export button
            Button(action: performExport) {
                Label("Export \(chartType.name)", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }
    
    func performExport() {
        // Implementation would generate the appropriate export format
        print("Exporting \(chartType.name) as \(exportFormat)")
    }
}
 */
