//
//  ChartPreviewView.swift
//  Pulto3
//
//  Created by AI Assistant on 1/29/25.
//

import SwiftUI
import Charts

struct ChartPreviewView: View {
    @ObservedObject var chartBuilder: ChartBuilder
    @State private var showingFullScreen = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Chart Title and Info
            VStack(spacing: 8) {
                Text(chartBuilder.chartMetadata.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                if !chartBuilder.chartMetadata.description.isEmpty {
                    Text(chartBuilder.chartMetadata.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top)
            
            // Main Chart
            chartContent
                .frame(maxWidth: .infinity)
                .frame(height: 400)
                .background(chartBuilder.chartStyle.backgroundColor)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)
            
            // Chart Info
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chart Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(chartBuilder.chartType.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Data Points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(totalDataPoints)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Series")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(chartBuilder.chartData.series.count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Actions
            HStack(spacing: 12) {
                Button("Full Screen") {
                    showingFullScreen = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Regenerate Data") {
                    chartBuilder.generateSampleData()
                }
                .buttonStyle(.bordered)
                
                Button("Reset Style") {
                    chartBuilder.chartStyle = ChartStyle()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            FullScreenChartView(chartBuilder: chartBuilder)
        }
    }
    
    @ViewBuilder
    private var chartContent: some View {
        if chartBuilder.chartData.series.isEmpty {
            ContentUnavailableView(
                "No Data Available",
                systemImage: "chart.bar",
                description: Text("Add data to see your chart preview")
            )
        } else {
            switch chartBuilder.chartType {
            case .line:
                FullLineChart(data: chartBuilder.chartData, style: chartBuilder.chartStyle, metadata: chartBuilder.chartMetadata)
            case .bar:
                FullBarChart(data: chartBuilder.chartData, style: chartBuilder.chartStyle, metadata: chartBuilder.chartMetadata)
            case .scatter:
                FullScatterChart(data: chartBuilder.chartData, style: chartBuilder.chartStyle, metadata: chartBuilder.chartMetadata)
            case .pie:
                FullPieChart(data: chartBuilder.chartData, style: chartBuilder.chartStyle, metadata: chartBuilder.chartMetadata)
            case .area:
                FullAreaChart(data: chartBuilder.chartData, style: chartBuilder.chartStyle, metadata: chartBuilder.chartMetadata)
            case .histogram:
                FullHistogramChart(data: chartBuilder.chartData, style: chartBuilder.chartStyle, metadata: chartBuilder.chartMetadata)
            default:
                PlaceholderChartPreview(type: chartBuilder.chartType)
            }
        }
    }
    
    private var totalDataPoints: Int {
        chartBuilder.chartData.series.reduce(0) { $0 + $1.values.count }
    }
}

// MARK: - Full Chart Views

struct FullLineChart: View {
    let data: ChartDataSet
    let style: ChartStyle
    let metadata: ChartMetadata
    
    var body: some View {
        Chart {
            ForEach(0..<data.series.count, id: \.self) { seriesIndex in
                let series = data.series[seriesIndex]
                ForEach(0..<min(series.values.count, data.categories.count), id: \.self) { index in
                    LineMark(
                        x: .value(metadata.xAxisLabel, data.categories[index]),
                        y: .value(metadata.yAxisLabel, series.values[index])
                    )
                    .foregroundStyle(series.color)
                    .lineStyle(StrokeStyle(lineWidth: style.lineWidth))
                    .symbol(.circle)
                    .symbolSize(style.pointSize * 15)
                    .interpolationMethod(.catmullRom)
                }
                .opacity(style.opacity)
            }
        }
        .chartBackground { proxy in
            Rectangle()
                .fill(style.backgroundColor)
        }
        .chartXAxis(style.showAxes ? .visible : .hidden)
        .chartYAxis(style.showAxes ? .visible : .hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(style.showGrid ? .gray.opacity(0.1) : .clear)
        }
        .chartLegend(style.showLegend ? .visible : .hidden)
        .padding()
    }
}

struct FullBarChart: View {
    let data: ChartDataSet
    let style: ChartStyle
    let metadata: ChartMetadata
    
    var body: some View {
        Chart {
            ForEach(0..<data.series.count, id: \.self) { seriesIndex in
                let series = data.series[seriesIndex]
                ForEach(0..<min(series.values.count, data.categories.count), id: \.self) { index in
                    BarMark(
                        x: .value(metadata.xAxisLabel, data.categories[index]),
                        y: .value(metadata.yAxisLabel, series.values[index])
                    )
                    .foregroundStyle(series.color)
                    .cornerRadius(style.cornerRadius)
                    .opacity(style.opacity)
                }
            }
        }
        .chartBackground { proxy in
            Rectangle()
                .fill(style.backgroundColor)
        }
        .chartXAxis(style.showAxes ? .visible : .hidden)
        .chartYAxis(style.showAxes ? .visible : .hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(style.showGrid ? .gray.opacity(0.1) : .clear)
        }
        .chartLegend(style.showLegend ? .visible : .hidden)
        .padding()
    }
}

struct FullScatterChart: View {
    let data: ChartDataSet
    let style: ChartStyle
    let metadata: ChartMetadata
    
    var body: some View {
        Chart {
            ForEach(0..<min(data.xAxisData.count, data.yAxisData.count), id: \.self) { index in
                PointMark(
                    x: .value(metadata.xAxisLabel, data.xAxisData[index]),
                    y: .value(metadata.yAxisLabel, data.yAxisData[index])
                )
                .foregroundStyle(style.primaryColor)
                .symbol(.circle)
                .symbolSize(style.pointSize * 20)
                .opacity(style.opacity)
            }
        }
        .chartBackground { proxy in
            Rectangle()
                .fill(style.backgroundColor)
        }
        .chartXAxis(style.showAxes ? .visible : .hidden)
        .chartYAxis(style.showAxes ? .visible : .hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(style.showGrid ? .gray.opacity(0.1) : .clear)
        }
        .padding()
    }
}

struct FullPieChart: View {
    let data: ChartDataSet
    let style: ChartStyle
    let metadata: ChartMetadata
    
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
            .chartLegend(style.showLegend ? .visible : .hidden)
            .padding()
        } else {
            ContentUnavailableView(
                "No Pie Data",
                systemImage: "chart.pie",
                description: Text("Add data series to display pie chart")
            )
        }
    }
}

struct FullAreaChart: View {
    let data: ChartDataSet
    let style: ChartStyle
    let metadata: ChartMetadata
    
    var body: some View {
        Chart {
            ForEach(0..<data.series.count, id: \.self) { seriesIndex in
                let series = data.series[seriesIndex]
                ForEach(0..<min(series.values.count, data.categories.count), id: \.self) { index in
                    AreaMark(
                        x: .value(metadata.xAxisLabel, data.categories[index]),
                        y: .value(metadata.yAxisLabel, series.values[index])
                    )
                    .foregroundStyle(series.color.gradient)
                    .interpolationMethod(.catmullRom)
                    .opacity(style.opacity * 0.7)
                    
                    LineMark(
                        x: .value(metadata.xAxisLabel, data.categories[index]),
                        y: .value(metadata.yAxisLabel, series.values[index])
                    )
                    .foregroundStyle(series.color)
                    .lineStyle(StrokeStyle(lineWidth: style.lineWidth))
                    .interpolationMethod(.catmullRom)
                }
            }
        }
        .chartBackground { proxy in
            Rectangle()
                .fill(style.backgroundColor)
        }
        .chartXAxis(style.showAxes ? .visible : .hidden)
        .chartYAxis(style.showAxes ? .visible : .hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(style.showGrid ? .gray.opacity(0.1) : .clear)
        }
        .chartLegend(style.showLegend ? .visible : .hidden)
        .padding()
    }
}

struct FullHistogramChart: View {
    let data: ChartDataSet
    let style: ChartStyle
    let metadata: ChartMetadata
    
    var body: some View {
        if let series = data.series.first {
            let bins = createHistogramBins(from: series.values)
            
            Chart {
                ForEach(0..<bins.count, id: \.self) { index in
                    BarMark(
                        x: .value("Range", bins[index].label),
                        y: .value("Frequency", bins[index].count)
                    )
                    .foregroundStyle(style.primaryColor)
                    .cornerRadius(style.cornerRadius)
                    .opacity(style.opacity)
                }
            }
            .chartBackground { proxy in
                Rectangle()
                    .fill(style.backgroundColor)
            }
            .chartXAxis(style.showAxes ? .visible : .hidden)
            .chartYAxis(style.showAxes ? .visible : .hidden)
            .chartPlotStyle { plotArea in
                plotArea
                    .background(style.showGrid ? .gray.opacity(0.1) : .clear)
            }
            .padding()
        } else {
            ContentUnavailableView(
                "No Histogram Data",
                systemImage: "chart.bar.doc.horizontal",
                description: Text("Add data series to display histogram")
            )
        }
    }
    
    private func createHistogramBins(from values: [Double]) -> [HistogramBin] {
        guard !values.isEmpty else { return [] }
        
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let binCount = 10
        let binWidth = (maxValue - minValue) / Double(binCount)
        
        var bins: [HistogramBin] = []
        
        for i in 0..<binCount {
            let rangeStart = minValue + Double(i) * binWidth
            let rangeEnd = rangeStart + binWidth
            let count = values.filter { $0 >= rangeStart && $0 < rangeEnd }.count
            
            bins.append(HistogramBin(
                label: String(format: "%.1f-%.1f", rangeStart, rangeEnd),
                count: count
            ))
        }
        
        return bins
    }
}

struct HistogramBin {
    let label: String
    let count: Int
}

// MARK: - Full Screen View

struct FullScreenChartView: View {
    @ObservedObject var chartBuilder: ChartBuilder
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Chart Title
                Text(chartBuilder.chartMetadata.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Full-size chart
                Group {
                    switch chartBuilder.chartType {
                    case .line:
                        FullLineChart(data: chartBuilder.chartData, style: chartBuilder.chartStyle, metadata: chartBuilder.chartMetadata)
                    case .bar:
                        FullBarChart(data: chartBuilder.chartData, style: chartBuilder.chartStyle, metadata: chartBuilder.chartMetadata)
                    case .scatter:
                        FullScatterChart(data: chartBuilder.chartData, style: chartBuilder.chartStyle, metadata: chartBuilder.chartMetadata)
                    case .pie:
                        FullPieChart(data: chartBuilder.chartData, style: chartBuilder.chartStyle, metadata: chartBuilder.chartMetadata)
                    case .area:
                        FullAreaChart(data: chartBuilder.chartData, style: chartBuilder.chartStyle, metadata: chartBuilder.chartMetadata)
                    case .histogram:
                        FullHistogramChart(data: chartBuilder.chartData, style: chartBuilder.chartStyle, metadata: chartBuilder.chartMetadata)
                    default:
                        PlaceholderChartPreview(type: chartBuilder.chartType)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(chartBuilder.chartStyle.backgroundColor)
                .cornerRadius(12)
                
                // Chart description
                if !chartBuilder.chartMetadata.description.isEmpty {
                    Text(chartBuilder.chartMetadata.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

#Preview("Chart Preview View") {
    let chartBuilder = ChartBuilder()
    chartBuilder.generateSampleData()
    
    return ChartPreviewView(chartBuilder: chartBuilder)
        .frame(width: 800, height: 600)
}

#Preview("Full Line Chart") {
    let sampleData = ChartDataSet.generateSample(for: .line)
    let sampleStyle = ChartStyle()
    let sampleMetadata = ChartMetadata(
        title: "Sample Line Chart",
        xAxisLabel: "Month",
        yAxisLabel: "Value"
    )
    
    return FullLineChart(
        data: sampleData,
        style: sampleStyle,
        metadata: sampleMetadata
    )
    .frame(width: 600, height: 400)
}

#Preview("Full Bar Chart") {
    let sampleData = ChartDataSet.generateSample(for: .bar)
    let sampleStyle = ChartStyle()
    let sampleMetadata = ChartMetadata(
        title: "Sample Bar Chart",
        xAxisLabel: "Category",
        yAxisLabel: "Value"
    )
    
    return FullBarChart(
        data: sampleData,
        style: sampleStyle,
        metadata: sampleMetadata
    )
    .frame(width: 600, height: 400)
}

#Preview("Full Pie Chart") {
    let sampleData = ChartDataSet.generateSample(for: .pie)
    let sampleStyle = ChartStyle()
    let sampleMetadata = ChartMetadata(
        title: "Sample Pie Chart",
        xAxisLabel: "Category",
        yAxisLabel: "Value"
    )
    
    return FullPieChart(
        data: sampleData,
        style: sampleStyle,
        metadata: sampleMetadata
    )
    .frame(width: 400, height: 400)
}