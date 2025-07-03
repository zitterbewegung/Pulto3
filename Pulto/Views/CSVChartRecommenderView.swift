//
//  CSVChartRecommenderView.swift
//  Pulto
//
//  Created by Joshua Herman on 1/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

struct CSVChartRecommenderView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var csvData: CSVData?
    @State private var selectedColumns: Set<String> = []
    @State private var recommendedCharts: [ChartRecommendation] = []
    
    struct ChartRecommendation {
        let type: String
        let description: String
        let columns: [String]
        let reason: String
        let complexity: Int // 1-5
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerView
                
                if let csvData = csvData {
                    csvDataView(csvData)
                } else {
                    emptyStateView
                }
                
                Spacer()
            }
            .navigationTitle("Chart Recommendations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        // Handle import logic
                        dismiss()
                    }
                    .disabled(csvData == nil)
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("CSV Chart Recommendations")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Import CSV data and get intelligent chart suggestions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Button("Select CSV File") {
                // Trigger file import
                loadSampleCSV()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Text("Or drag and drop a CSV file here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func csvDataView(_ data: CSVData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Data preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Data Preview")
                    .font(.headline)
                
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Headers
                        HStack(spacing: 1) {
                            ForEach(data.headers, id: \.self) { header in
                                Text(header)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .frame(minWidth: 80)
                                    .background(Color.blue.opacity(0.1))
                                    .border(Color.gray.opacity(0.3), width: 0.5)
                            }
                        }
                        
                        // Sample rows
                        ForEach(Array(data.rows.prefix(3).enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 1) {
                                ForEach(Array(row.enumerated()), id: \.offset) { index, cell in
                                    Text(cell)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .frame(minWidth: 80)
                                        .background(Color.gray.opacity(0.05))
                                        .border(Color.gray.opacity(0.3), width: 0.5)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
            
            // Chart recommendations
            if !recommendedCharts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommended Charts")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(Array(recommendedCharts.enumerated()), id: \.offset) { _, recommendation in
                            ChartRecommendationCard(recommendation: recommendation) {
                                // Handle chart selection
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func loadSampleCSV() {
        // Load sample CSV data for demonstration
        let sampleData = CSVData(
            headers: ["Month", "Sales", "Profit", "Region"],
            rows: [
                ["January", "10000", "2000", "North"],
                ["February", "12000", "2400", "North"],
                ["March", "15000", "3000", "South"],
                ["April", "13000", "2600", "East"],
                ["May", "18000", "3600", "West"]
            ],
            columnTypes: [.categorical, .numeric, .numeric, .categorical]
        )
        
        self.csvData = sampleData
        self.recommendedCharts = generateRecommendations(for: sampleData)
    }
    
    private func generateRecommendations(for data: CSVData) -> [ChartRecommendation] {
        var recommendations: [ChartRecommendation] = []
        
        // Find numeric columns
        let numericColumns = data.headers.enumerated().compactMap { index, header in
            data.columnTypes[index] == .numeric ? header : nil
        }
        
        // Find categorical columns
        let categoricalColumns = data.headers.enumerated().compactMap { index, header in
            data.columnTypes[index] == .categorical ? header : nil
        }
        
        // Bar chart recommendation
        if !categoricalColumns.isEmpty && !numericColumns.isEmpty {
            recommendations.append(ChartRecommendation(
                type: "Bar Chart",
                description: "Compare values across categories",
                columns: [categoricalColumns.first!, numericColumns.first!],
                reason: "Perfect for comparing \(numericColumns.first!) across different \(categoricalColumns.first!) values",
                complexity: 2
            ))
        }
        
        // Line chart recommendation
        if numericColumns.count >= 2 {
            recommendations.append(ChartRecommendation(
                type: "Line Chart",
                description: "Show trends over time",
                columns: Array(numericColumns.prefix(2)),
                reason: "Great for showing trends and relationships between numeric values",
                complexity: 2
            ))
        }
        
        // Pie chart recommendation
        if !categoricalColumns.isEmpty && !numericColumns.isEmpty {
            recommendations.append(ChartRecommendation(
                type: "Pie Chart",
                description: "Show proportional data",
                columns: [categoricalColumns.first!, numericColumns.first!],
                reason: "Ideal for showing how \(numericColumns.first!) is distributed across \(categoricalColumns.first!)",
                complexity: 1
            ))
        }
        
        // Scatter plot recommendation
        if numericColumns.count >= 2 {
            recommendations.append(ChartRecommendation(
                type: "Scatter Plot",
                description: "Explore correlations",
                columns: Array(numericColumns.prefix(2)),
                reason: "Excellent for finding correlations between \(numericColumns[0]) and \(numericColumns[1])",
                complexity: 3
            ))
        }
        
        return recommendations
    }
}

struct ChartRecommendationCard: View {
    let recommendation: CSVChartRecommenderView.ChartRecommendation
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(recommendation.type)
                        .font(.headline)
                    Spacer()
                    complexityIndicator
                }
                
                Text(recommendation.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Columns: \(recommendation.columns.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private var complexityIndicator: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { level in
                Circle()
                    .fill(level <= recommendation.complexity ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
}