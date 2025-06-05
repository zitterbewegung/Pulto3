//
//  ChartDataPoint.swift
//  Pulto
//
//  Created by Joshua Herman on 6/4/25.
//  Copyright © 2025 Apple. All rights reserved.
//


import SwiftUI
import Charts
import Foundation

// MARK: - Data Models
struct ChartDataPoint: Codable {
    let x: Double
    let y: Double
    let category: String?
    
    init(x: Double, y: Double, category: String? = nil) {
        self.x = x
        self.y = y
        self.category = category
    }
}

struct JupyterChartData: Codable {
    let title: String
    let dataPoints: [ChartDataPoint]
    let chartType: String
    let xAxisLabel: String?
    let yAxisLabel: String?
    
    init(title: String, dataPoints: [ChartDataPoint], chartType: String, xAxisLabel: String? = nil, yAxisLabel: String? = nil) {
        self.title = title
        self.dataPoints = dataPoints
        self.chartType = chartType
        self.xAxisLabel = xAxisLabel
        self.yAxisLabel = yAxisLabel
    }
}

// MARK: - Chart Data Extractor
class ChartDataExtractor {
    
    // Extract data from a line chart
    static func extractLineChartData(
        title: String,
        data: [(x: Double, y: Double)],
        xAxisLabel: String? = nil,
        yAxisLabel: String? = nil
    ) -> JupyterChartData {
        let dataPoints = data.map { ChartDataPoint(x: $0.x, y: $0.y) }
        return JupyterChartData(
            title: title,
            dataPoints: dataPoints,
            chartType: "line",
            xAxisLabel: xAxisLabel,
            yAxisLabel: yAxisLabel
        )
    }
    
    // Extract data from a bar chart with categories
    static func extractBarChartData(
        title: String,
        data: [(category: String, value: Double)],
        xAxisLabel: String? = nil,
        yAxisLabel: String? = nil
    ) -> JupyterChartData {
        let dataPoints = data.enumerated().map { index, item in
            ChartDataPoint(x: Double(index), y: item.value, category: item.category)
        }
        return JupyterChartData(
            title: title,
            dataPoints: dataPoints,
            chartType: "bar",
            xAxisLabel: xAxisLabel,
            yAxisLabel: yAxisLabel
        )
    }
    
    // Convert chart data to JSON string for Jupyter
    static func toJupyterJSON(_ chartData: JupyterChartData) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let jsonData = try encoder.encode(chartData)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Error encoding chart data: \(error)")
            return nil
        }
    }
    
    // Generate Python code for Jupyter cell
    static func generateJupyterPythonCode(_ chartData: JupyterChartData) -> String {
        let jsonString = toJupyterJSON(chartData) ?? "{}"
        
        return """
        import json
        import matplotlib.pyplot as plt
        import pandas as pd
        import numpy as np
        
        # Chart data from Swift
        chart_data_json = '''\(jsonString)'''
        
        # Parse the data
        chart_data = json.loads(chart_data_json)
        
        # Extract data points
        x_values = [point['x'] for point in chart_data['dataPoints']]
        y_values = [point['y'] for point in chart_data['dataPoints']]
        categories = [point.get('category') for point in chart_data['dataPoints']]
        
        # Create the plot
        plt.figure(figsize=(10, 6))
        
        if chart_data['chartType'] == 'line':
            plt.plot(x_values, y_values, marker='o')
        elif chart_data['chartType'] == 'bar':
            if any(categories):
                plt.bar(categories, y_values)
                plt.xticks(rotation=45)
            else:
                plt.bar(x_values, y_values)
        
        plt.title(chart_data['title'])
        if chart_data.get('xAxisLabel'):
            plt.xlabel(chart_data['xAxisLabel'])
        if chart_data.get('yAxisLabel'):
            plt.ylabel(chart_data['yAxisLabel'])
        
        plt.grid(True, alpha=0.3)
        plt.tight_layout()
        plt.show()
        
        # Also create a pandas DataFrame for further analysis
        df_data = {
            'x': x_values,
            'y': y_values
        }
        if any(categories):
            df_data['category'] = categories
        
        df = pd.DataFrame(df_data)
        print("\\nDataFrame:")
        print(df)
        """
    }
    
    // Save Jupyter code to file
    static func saveJupyterCode(_ code: String, to filename: String) {
        let url = URL(fileURLWithPath: filename)
        do {
            try code.write(to: url, atomically: true, encoding: .utf8)
            print("Jupyter code saved to: \(filename)")
        } catch {
            print("Error saving file: \(error)")
        }
    }
}

// MARK: - Example Usage
struct DemoContentView: View {
    // Sample data
    let salesData = [
        (category: "Q1", value: 1200.0),
        (category: "Q2", value: 1800.0),
        (category: "Q3", value: 1500.0),
        (category: "Q4", value: 2100.0)
    ]
    
    let temperatureData = [
        (x: 1.0, y: 20.5),
        (x: 2.0, y: 22.1),
        (x: 3.0, y: 24.8),
        (x: 4.0, y: 23.2),
        (x: 5.0, y: 21.7)
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Swift Chart Data Extractor")
                .font(.title)
                .padding()
            
            // Sample Swift Chart
            Chart(salesData, id: \.category) { item in
                BarMark(
                    x: .value("Quarter", item.category),
                    y: .value("Sales", item.value)
                )
            }
            .frame(height: 200)
            .padding()
            
            Button("Extract Chart Data for Jupyter") {
                extractAndExportData()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
    
    func extractAndExportData() {
        // Extract bar chart data
        let barChartData = ChartDataExtractor.extractBarChartData(
            title: "Quarterly Sales Data",
            data: salesData,
            xAxisLabel: "Quarter",
            yAxisLabel: "Sales ($)"
        )
        
        // Extract line chart data
        let lineChartData = ChartDataExtractor.extractLineChartData(
            title: "Temperature Over Time",
            data: temperatureData,
            xAxisLabel: "Day",
            yAxisLabel: "Temperature (°C)"
        )
        
        // Generate Jupyter code for bar chart
        let barChartJupyterCode = ChartDataExtractor.generateJupyterPythonCode(barChartData)
        ChartDataExtractor.saveJupyterCode(barChartJupyterCode, to: "bar_chart_jupyter.py")
        
        // Generate Jupyter code for line chart
        let lineChartJupyterCode = ChartDataExtractor.generateJupyterPythonCode(lineChartData)
        ChartDataExtractor.saveJupyterCode(lineChartJupyterCode, to: "line_chart_jupyter.py")
        
        // Print JSON data for manual copying
        if let barChartJSON = ChartDataExtractor.toJupyterJSON(barChartData) {
            print("Bar Chart JSON:")
            print(barChartJSON)
            let separator = String(repeating: "=", count: 50)
            print("\n\(separator)\n")
        }
        
        if let lineChartJSON = ChartDataExtractor.toJupyterJSON(lineChartData) {
            print("Line Chart JSON:")
            print(lineChartJSON)
        }
    }
}

// MARK: - Command Line Usage Example
func commandLineExample() {
    // Sample data
    let data = [
        (category: "Apple", value: 45.0),
        (category: "Orange", value: 30.0),
        (category: "Banana", value: 25.0)
    ]
    
    // Extract chart data
    let chartData = ChartDataExtractor.extractBarChartData(
        title: "Fruit Sales",
        data: data,
        xAxisLabel: "Fruit Type",
        yAxisLabel: "Units Sold"
    )
    
    // Generate Jupyter code
    let jupyterCode = ChartDataExtractor.generateJupyterPythonCode(chartData)
    
    // Save to file
    ChartDataExtractor.saveJupyterCode(jupyterCode, to: "fruit_sales_jupyter.py")
    
    // Print for copying to Jupyter
    print("Copy this code to your Jupyter cell:")
    print(jupyterCode)
}

// Uncomment to run command line example
// commandLineExample()

// For visionOS specific preview
#Preview("visionOS", traits: .fixedLayout(width: 400, height: 300)) {
    ContentView()
}
