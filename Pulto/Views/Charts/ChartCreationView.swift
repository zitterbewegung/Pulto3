//
//  ChartCreationView.swift
//  Pulto3
//
//  Created by AI Assistant on 1/29/25.
//

import SwiftUI
import Charts

// MARK: - Chart Creation View

struct ChartCreationView: View {
    @ObservedObject var chartBuilder: ChartBuilder
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Chart Type Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose Chart Type")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(ChartBuilder.ChartType.allCases, id: \.self) { type in
                            ChartTypeCard(
                                type: type,
                                isSelected: chartBuilder.chartType == type
                            ) {
                                chartBuilder.chartType = type
                                chartBuilder.generateSampleData()
                            }
                        }
                    }
                }
                
                // Quick Start Templates
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Start Templates")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(ChartTemplate.allCases, id: \.self) { template in
                            ChartTemplateCard(template: template) {
                                applyTemplate(template)
                            }
                        }
                    }
                }
                
                // Chart Preview (Small)
                if !chartBuilder.chartData.series.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Preview")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        MiniChartPreview(chartBuilder: chartBuilder)
                            .frame(height: 200)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
    }
    
    private func applyTemplate(_ template: ChartTemplate) {
        switch template {
        case .salesDashboard:
            chartBuilder.chartType = .line
            chartBuilder.chartMetadata.title = "Sales Dashboard"
            chartBuilder.chartMetadata.xAxisLabel = "Month"
            chartBuilder.chartMetadata.yAxisLabel = "Sales ($)"
            chartBuilder.generateSampleData()
            
        case .performanceMetrics:
            chartBuilder.chartType = .bar
            chartBuilder.chartMetadata.title = "Performance Metrics"
            chartBuilder.chartMetadata.xAxisLabel = "Metrics"
            chartBuilder.chartMetadata.yAxisLabel = "Score"
            chartBuilder.generateSampleData()
            
        case .dataDistribution:
            chartBuilder.chartType = .histogram
            chartBuilder.chartMetadata.title = "Data Distribution"
            chartBuilder.chartMetadata.xAxisLabel = "Value"
            chartBuilder.chartMetadata.yAxisLabel = "Frequency"
            chartBuilder.generateSampleData()
            
        case .correlation:
            chartBuilder.chartType = .scatter
            chartBuilder.chartMetadata.title = "Correlation Analysis"
            chartBuilder.chartMetadata.xAxisLabel = "Variable X"
            chartBuilder.chartMetadata.yAxisLabel = "Variable Y"
            chartBuilder.generateSampleData()
        }
    }
}

// MARK: - Chart Templates

enum ChartTemplate: String, CaseIterable {
    case salesDashboard = "Sales Dashboard"
    case performanceMetrics = "Performance Metrics"
    case dataDistribution = "Data Distribution"
    case correlation = "Correlation Analysis"
    
    var icon: String {
        switch self {
        case .salesDashboard: return "chart.line.uptrend.xyaxis"
        case .performanceMetrics: return "chart.bar"
        case .dataDistribution: return "chart.bar.doc.horizontal"
        case .correlation: return "chart.dots.scatter"
        }
    }
    
    var description: String {
        switch self {
        case .salesDashboard: return "Track sales trends over time"
        case .performanceMetrics: return "Compare performance across categories"
        case .dataDistribution: return "Analyze data distribution patterns"
        case .correlation: return "Explore relationships between variables"
        }
    }
}

// MARK: - Supporting Views

struct ChartTypeCard: View {
    let type: ChartBuilder.ChartType
    let isSelected: Bool
    let onSelection: () -> Void
    
    var body: some View {
        Button(action: onSelection) {
            VStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.title)
                    .foregroundStyle(isSelected ? .white : .blue)
                
                Text(type.rawValue)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Text(type.description)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 120)
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

struct ChartTemplateCard: View {
    let template: ChartTemplate
    let onSelection: () -> Void
    
    var body: some View {
        Button(action: onSelection) {
            HStack(spacing: 12) {
                Image(systemName: template.icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(template.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct MiniChartPreview: View {
    @ObservedObject var chartBuilder: ChartBuilder
    
    var body: some View {
        Group {
            switch chartBuilder.chartType {
            case .line:
                LineChartPreview(data: chartBuilder.chartData, style: chartBuilder.chartStyle)
            case .bar:
                BarChartPreview(data: chartBuilder.chartData, style: chartBuilder.chartStyle)
            case .scatter:
                ScatterChartPreview(data: chartBuilder.chartData, style: chartBuilder.chartStyle)
            case .pie:
                PieChartPreview(data: chartBuilder.chartData, style: chartBuilder.chartStyle)
            default:
                PlaceholderChartPreview(type: chartBuilder.chartType)
            }
        }
    }
}

struct LineChartPreview: View {
    let data: ChartDataSet
    let style: ChartStyle
    
    var body: some View {
        Chart {
            ForEach(0..<data.series.count, id: \.self) { seriesIndex in
                let series = data.series[seriesIndex]
                ForEach(0..<min(series.values.count, data.categories.count), id: \.self) { index in
                    LineMark(
                        x: .value("Category", data.categories[index]),
                        y: .value("Value", series.values[index])
                    )
                    .foregroundStyle(series.color)
                    .lineStyle(StrokeStyle(lineWidth: style.lineWidth))
                }
            }
        }
        .chartBackground { chartProxy in
            Rectangle()
                .fill(style.backgroundColor)
        }
        .padding()
    }
}

struct BarChartPreview: View {
    let data: ChartDataSet
    let style: ChartStyle
    
    var body: some View {
        Chart {
            ForEach(0..<data.series.count, id: \.self) { seriesIndex in
                let series = data.series[seriesIndex]
                ForEach(0..<min(series.values.count, data.categories.count), id: \.self) { index in
                    BarMark(
                        x: .value("Category", data.categories[index]),
                        y: .value("Value", series.values[index])
                    )
                    .foregroundStyle(series.color)
                    .cornerRadius(style.cornerRadius)
                    .opacity(style.opacity)
                }
            }
        }
        .padding()
    }
}

struct ScatterChartPreview: View {
    let data: ChartDataSet
    let style: ChartStyle
    
    var body: some View {
        Chart {
            ForEach(0..<min(data.xAxisData.count, data.yAxisData.count), id: \.self) { index in
                PointMark(
                    x: .value("X", data.xAxisData[index]),
                    y: .value("Y", data.yAxisData[index])
                )
                .foregroundStyle(style.primaryColor)
                .symbol(.circle)
                .symbolSize(style.pointSize * 10)
            }
        }
        .padding()
    }
}

struct PieChartPreview: View {
    let data: ChartDataSet
    let style: ChartStyle
    
    var body: some View {
        if let series = data.series.first {
            Chart {
                ForEach(0..<min(series.values.count, data.categories.count), id: \.self) { index in
                    SectorMark(
                        angle: .value("Value", series.values[index]),
                        innerRadius: .ratio(0.4),
                        angularInset: 2
                    )
                    .foregroundStyle(ChartStyle.defaultColors[index % ChartStyle.defaultColors.count])
                    .opacity(style.opacity)
                }
            }
            .padding()
        } else {
            PlaceholderChartPreview(type: .pie)
        }
    }
}

struct PlaceholderChartPreview: View {
    let type: ChartBuilder.ChartType
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No data available")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Generate sample data or import CSV to see preview")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Chart Creation View") {
    ChartCreationView(chartBuilder: ChartBuilder())
        .frame(width: 800, height: 600)
}

#Preview("Chart Type Card") {
    ChartTypeCard(
        type: .line,
        isSelected: true,
        onSelection: {}
    )
    .frame(width: 200, height: 120)
}

#Preview("Chart Template Card") {
    ChartTemplateCard(
        template: .salesDashboard,
        onSelection: {}
    )
    .frame(width: 300, height: 80)
}

#Preview("Mini Chart Preview") {
    let chartBuilder = ChartBuilder()
    chartBuilder.generateSampleData()
    
    return MiniChartPreview(chartBuilder: chartBuilder)
        .frame(width: 400, height: 200)
}