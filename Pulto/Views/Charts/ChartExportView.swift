//
//  ChartExportView.swift
//  Pulto3
//
//  Created by AI Assistant on 1/29/25.
//

import SwiftUI

struct ChartExportView: View {
    @ObservedObject var chartBuilder: ChartBuilder
    @Binding var showingCodeExporter: Bool
    @Binding var showingChartExporter: Bool
    
    @State private var selectedExportFormat: ExportFormat = .python
    @State private var generatedCode: String = ""
    @State private var showingCopySuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Export Format Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Export Format")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Picker("Format", selection: $selectedExportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Label(format.rawValue, systemImage: format.icon)
                                .tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(selectedExportFormat.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Export Actions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Export Options")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        Button(action: { showingCodeExporter = true }) {
                            ExportActionCard(
                                title: "Export Code",
                                description: "Save as Python/Jupyter file",
                                icon: "doc.text"
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { showingChartExporter = true }) {
                            ExportActionCard(
                                title: "Export Image",
                                description: "Save as PNG image",
                                icon: "photo"
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: copyToClipboard) {
                            ExportActionCard(
                                title: "Copy Code",
                                description: "Copy to clipboard",
                                icon: showingCopySuccess ? "checkmark" : "doc.on.doc"
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: shareChart) {
                            ExportActionCard(
                                title: "Share Chart",
                                description: "Share with others",
                                icon: "square.and.arrow.up"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Code Preview
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Generated Code")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Refresh") {
                            generateCode()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    ScrollView {
                        Text(generatedCode)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(height: 300)
                }
                
                // Export Stats
                VStack(alignment: .leading, spacing: 16) {
                    Text("Export Information")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Chart Type:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(chartBuilder.chartType.rawValue)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Data Series:")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(chartBuilder.chartData.series.count)")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Total Data Points:")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(totalDataPoints)")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Code Lines:")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(generatedCode.components(separatedBy: .newlines).count)")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Created:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(chartBuilder.chartMetadata.createdDate.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .onAppear {
            generateCode()
        }
        .onChange(of: selectedExportFormat) { _, _ in
            generateCode()
        }
        .onChange(of: chartBuilder.chartType) { _, _ in
            generateCode()
        }
        .onChange(of: chartBuilder.chartData.series.count) { _, _ in
            generateCode()
        }
    }
    
    private var totalDataPoints: Int {
        chartBuilder.chartData.series.reduce(0) { $0 + $1.values.count }
    }
    
    private func generateCode() {
        switch selectedExportFormat {
        case .python:
            generatedCode = chartBuilder.generatePythonCode()
        case .jupyter:
            generatedCode = chartBuilder.generateJupyterNotebook()
        case .r:
            generatedCode = generateRCode()
        case .javascript:
            generatedCode = generateJavaScriptCode()
        }
    }
    
    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(generatedCode, forType: .string)
        #else
        UIPasteboard.general.string = generatedCode
        #endif
        
        showingCopySuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingCopySuccess = false
        }
    }
    
    private func shareChart() {
        // Implement sharing functionality
        print("Sharing chart...")
    }
    
    private func generateRCode() -> String {
        let generator = RChartCodeGenerator()
        return generator.generateCode(
            chartType: chartBuilder.chartType,
            data: chartBuilder.chartData,
            style: chartBuilder.chartStyle,
            metadata: chartBuilder.chartMetadata
        )
    }
    
    private func generateJavaScriptCode() -> String {
        let generator = JavaScriptChartCodeGenerator()
        return generator.generateCode(
            chartType: chartBuilder.chartType,
            data: chartBuilder.chartData,
            style: chartBuilder.chartStyle,
            metadata: chartBuilder.chartMetadata
        )
    }
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case python = "Python"
    case jupyter = "Jupyter"
    case r = "R"
    case javascript = "JavaScript"
    
    var icon: String {
        switch self {
        case .python: return "snake"
        case .jupyter: return "book"
        case .r: return "r.circle"
        case .javascript: return "j.circle"
        }
    }
    
    var description: String {
        switch self {
        case .python: return "Generate matplotlib/seaborn code"
        case .jupyter: return "Create complete Jupyter notebook"
        case .r: return "Generate ggplot2 code"
        case .javascript: return "Create D3.js/Chart.js code"
        }
    }
}

// MARK: - Export Action Card

struct ExportActionCard: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Code Generators

struct PythonChartCodeGenerator {
    func generateCode(chartType: ChartBuilder.ChartType, data: ChartDataSet, style: ChartStyle, metadata: ChartMetadata) -> String {
        var code = """
        # \(metadata.title)
        # Generated by Pulto Chart Generator
        # \(metadata.description)
        
        import matplotlib.pyplot as plt
        import numpy as np
        import pandas as pd
        import seaborn as sns
        
        # Set style
        plt.style.use('default')
        
        """
        
        // Add data
        if !data.categories.isEmpty {
            code += "# Categories\n"
            code += "categories = \(formatPythonArray(data.categories))\n\n"
        }
        
        for (index, series) in data.series.enumerated() {
            code += "# \(series.name) data\n"
            code += "\(sanitizeName(series.name).lowercased())_data = \(formatPythonArray(series.values.map { String($0) }))\n\n"
        }
        
        // Generate chart-specific code
        switch chartType {
        case .line:
            code += generateLineChartCode(data: data, style: style, metadata: metadata)
        case .bar:
            code += generateBarChartCode(data: data, style: style, metadata: metadata)
        case .scatter:
            code += generateScatterChartCode(data: data, style: style, metadata: metadata)
        case .pie:
            code += generatePieChartCode(data: data, style: style, metadata: metadata)
        case .area:
            code += generateAreaChartCode(data: data, style: style, metadata: metadata)
        case .histogram:
            code += generateHistogramCode(data: data, style: style, metadata: metadata)
        default:
            code += "# Chart type not implemented yet\n"
        }
        
        code += """
        
        # Customize and show
        plt.title('\(metadata.title)')
        plt.xlabel('\(metadata.xAxisLabel)')
        plt.ylabel('\(metadata.yAxisLabel)')
        """
        
        if style.showGrid {
            code += "\nplt.grid(True, alpha=0.3)"
        }
        
        if style.showLegend && data.series.count > 1 {
            code += "\nplt.legend()"
        }
        
        code += """
        
        plt.tight_layout()
        plt.show()
        
        # Optional: Save the chart
        # plt.savefig('\(sanitizeName(metadata.title)).png', dpi=300, bbox_inches='tight')
        """
        
        return code
    }
    
    private func generateLineChartCode(data: ChartDataSet, style: ChartStyle, metadata: ChartMetadata) -> String {
        var code = "# Create line chart\nfig, ax = plt.subplots(figsize=(10, 6))\n\n"
        
        for series in data.series {
            let colorHex = colorToHex(series.color)
            code += "ax.plot(categories, \(sanitizeName(series.name).lowercased())_data, "
            code += "label='\(series.name)', color='\(colorHex)', "
            code += "linewidth=\(style.lineWidth), alpha=\(style.opacity))\n"
        }
        
        return code
    }
    
    private func generateBarChartCode(data: ChartDataSet, style: ChartStyle, metadata: ChartMetadata) -> String {
        var code = "# Create bar chart\nfig, ax = plt.subplots(figsize=(10, 6))\n\n"
        
        if data.series.count == 1 {
            let series = data.series[0]
            let colorHex = colorToHex(series.color)
            code += "ax.bar(categories, \(sanitizeName(series.name).lowercased())_data, "
            code += "color='\(colorHex)', alpha=\(style.opacity))\n"
        } else {
            code += "x = np.arange(len(categories))\n"
            code += "width = 0.8 / \(data.series.count)\n\n"
            
            for (index, series) in data.series.enumerated() {
                let colorHex = colorToHex(series.color)
                code += "ax.bar(x + \(index) * width, \(sanitizeName(series.name).lowercased())_data, "
                code += "width, label='\(series.name)', color='\(colorHex)', alpha=\(style.opacity))\n"
            }
            
            code += "\nax.set_xticks(x + width * (\(data.series.count - 1)) / 2)\n"
            code += "ax.set_xticklabels(categories)\n"
        }
        
        return code
    }
    
    private func generateScatterChartCode(data: ChartDataSet, style: ChartStyle, metadata: ChartMetadata) -> String {
        var code = "# Create scatter plot\nfig, ax = plt.subplots(figsize=(10, 6))\n\n"
        
        if !data.xAxisData.isEmpty && !data.yAxisData.isEmpty {
            code += "x_data = \(formatPythonArray(data.xAxisData.map { String($0) }))\n"
            code += "y_data = \(formatPythonArray(data.yAxisData.map { String($0) }))\n\n"
            
            let colorHex = colorToHex(style.primaryColor)
            code += "ax.scatter(x_data, y_data, color='\(colorHex)', "
            code += "s=\(style.pointSize * 10), alpha=\(style.opacity))\n"
        }
        
        return code
    }
    
    private func generatePieChartCode(data: ChartDataSet, style: ChartStyle, metadata: ChartMetadata) -> String {
        var code = "# Create pie chart\nfig, ax = plt.subplots(figsize=(8, 8))\n\n"
        
        if let series = data.series.first {
            code += "values = \(formatPythonArray(series.values.map { String($0) }))\n"
            code += "labels = categories\n\n"
            
            code += "colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7', '#DDA0DD']\n"
            code += "ax.pie(values, labels=labels, colors=colors[:len(values)], "
            code += "autopct='%1.1f%%', startangle=90)\n"
            code += "ax.axis('equal')\n"
        }
        
        return code
    }
    
    private func generateAreaChartCode(data: ChartDataSet, style: ChartStyle, metadata: ChartMetadata) -> String {
        var code = "# Create area chart\nfig, ax = plt.subplots(figsize=(10, 6))\n\n"
        
        for series in data.series {
            let colorHex = colorToHex(series.color)
            code += "ax.fill_between(categories, \(sanitizeName(series.name).lowercased())_data, "
            code += "label='\(series.name)', color='\(colorHex)', alpha=\(style.opacity * 0.7))\n"
        }
        
        return code
    }
    
    private func generateHistogramCode(data: ChartDataSet, style: ChartStyle, metadata: ChartMetadata) -> String {
        var code = "# Create histogram\nfig, ax = plt.subplots(figsize=(10, 6))\n\n"
        
        if let series = data.series.first {
            let colorHex = colorToHex(series.color)
            code += "ax.hist(\(sanitizeName(series.name).lowercased())_data, bins=10, "
            code += "color='\(colorHex)', alpha=\(style.opacity), edgecolor='black')\n"
        }
        
        return code
    }
    
    private func formatPythonArray(_ items: [String]) -> String {
        return "[" + items.map { "'\($0)'" }.joined(separator: ", ") + "]"
    }
    
    private func sanitizeName(_ name: String) -> String {
        return name.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }
    
    private func colorToHex(_ color: Color) -> String {
        // Simplified color to hex conversion
        // In a real implementation, you'd want proper color conversion
        return "#4A90E2" // Default blue
    }
}

struct JupyterNotebookGenerator {
    func generateNotebook(chartType: ChartBuilder.ChartType, data: ChartDataSet, style: ChartStyle, metadata: ChartMetadata) -> String {
        let pythonCode = PythonChartCodeGenerator().generateCode(
            chartType: chartType,
            data: data,
            style: style,
            metadata: metadata
        )
        
        return """
        {
         "cells": [
          {
           "cell_type": "markdown",
           "metadata": {},
           "source": [
            "# \(metadata.title)\\n",
            "\\n",
            "\(metadata.description)\\n",
            "\\n",
            "Generated by Pulto Chart Generator on \(Date().formatted())"
           ]
          },
          {
           "cell_type": "code",
           "execution_count": null,
           "metadata": {},
           "source": [
            "\(pythonCode.components(separatedBy: .newlines).map { "\"\($0)\\n\"" }.joined(separator: ",\n            ")),"
           ],
           "outputs": []
          }
         ],
         "metadata": {
          "kernelspec": {
           "display_name": "Python 3",
           "language": "python",
           "name": "python3"
          },
          "language_info": {
           "name": "python",
           "version": "3.8.0"
          }
         },
         "nbformat": 4,
         "nbformat_minor": 4
        }
        """
    }
}

struct RChartCodeGenerator {
    func generateCode(chartType: ChartBuilder.ChartType, data: ChartDataSet, style: ChartStyle, metadata: ChartMetadata) -> String {
        return """
        # \(metadata.title)
        # Generated by Pulto Chart Generator
        # \(metadata.description)
        
        library(ggplot2)
        library(dplyr)
        
        # Create sample data (replace with your actual data)
        data <- data.frame(
          category = c(\(data.categories.map { "\"\($0)\"" }.joined(separator: ", "))),
          value = c(\(data.series.first?.values.map { String($0) }.joined(separator: ", ") ?? ""))
        )
        
        # Create plot
        p <- ggplot(data, aes(x = category, y = value)) +
          geom_\(chartType == .line ? "line(group = 1)" : "bar(stat = \"identity\")") +
          labs(
            title = "\(metadata.title)",
            x = "\(metadata.xAxisLabel)",
            y = "\(metadata.yAxisLabel)"
          ) +
          theme_minimal()
        
        print(p)
        
        # Optional: Save the plot
        # ggsave("\(sanitizeName(metadata.title)).png", plot = p, width = 10, height = 6, dpi = 300)
        """
    }
    
    private func sanitizeName(_ name: String) -> String {
        return name.replacingOccurrences(of: " ", with: "_").lowercased()
    }
}

struct JavaScriptChartCodeGenerator {
    func generateCode(chartType: ChartBuilder.ChartType, data: ChartDataSet, style: ChartStyle, metadata: ChartMetadata) -> String {
        return """
        // \(metadata.title)
        // Generated by Pulto Chart Generator
        // \(metadata.description)
        
        // Chart.js implementation
        const ctx = document.getElementById('myChart').getContext('2d');
        const myChart = new Chart(ctx, {
            type: '\(chartType.jsType)',
            data: {
                labels: \(formatJSArray(data.categories)),
                datasets: [{
                    label: '\(data.series.first?.name ?? "Data")',
                    data: \(formatJSArray(data.series.first?.values.map { String($0) } ?? [])),
                    backgroundColor: 'rgba(74, 144, 226, 0.2)',
                    borderColor: 'rgba(74, 144, 226, 1)',
                    borderWidth: \(Int(style.lineWidth))
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: '\(metadata.title)'
                    },
                    legend: {
                        display: \(style.showLegend ? "true" : "false")
                    }
                },
                scales: {
                    x: {
                        display: \(style.showAxes ? "true" : "false"),
                        title: {
                            display: true,
                            text: '\(metadata.xAxisLabel)'
                        },
                        grid: {
                            display: \(style.showGrid ? "true" : "false")
                        }
                    },
                    y: {
                        display: \(style.showAxes ? "true" : "false"),
                        title: {
                            display: true,
                            text: '\(metadata.yAxisLabel)'
                        },
                        grid: {
                            display: \(style.showGrid ? "true" : "false")
                        }
                    }
                }
            }
        });
        """
    }
    
    private func formatJSArray(_ items: [String]) -> String {
        return "[" + items.map { "'\($0)'" }.joined(separator: ", ") + "]"
    }
}

extension ChartBuilder.ChartType {
    var jsType: String {
        switch self {
        case .line: return "line"
        case .bar: return "bar"
        case .scatter: return "scatter"
        case .pie: return "pie"
        case .area: return "line"
        case .histogram: return "bar"
        default: return "bar"
        }
    }
}

#Preview("Chart Export View") {
    let chartBuilder = ChartBuilder()
    chartBuilder.generateSampleData()
    
    return ChartExportView(
        chartBuilder: chartBuilder,
        showingCodeExporter: .constant(false),
        showingChartExporter: .constant(false)
    )
    .frame(width: 800, height: 600)
}

#Preview("Export Action Card") {
    ExportActionCard(
        title: "Export Code",
        description: "Save as Python/Jupyter file",
        icon: "doc.text"
    )
    .frame(width: 200, height: 100)
}