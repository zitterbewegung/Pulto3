//
//  SampleChartView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/19/25.
//  Copyright © 2025 Apple. All rights reserved.
//


// File: ChartViews.swift

import SwiftUI
import Charts

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
