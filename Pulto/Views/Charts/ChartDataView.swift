//
//  ChartDataView.swift
//  Pulto3
//
//  Created by AI Assistant on 1/29/25.
//

import SwiftUI

struct ChartDataView: View {
    @ObservedObject var chartBuilder: ChartBuilder
    @Binding var showingDataImporter: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Data Import Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Data Source")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 12) {
                        Button("Import CSV") {
                            showingDataImporter = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Generate Sample") {
                            chartBuilder.generateSampleData()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Clear Data") {
                            chartBuilder.chartData = ChartDataSet()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Data Series Management
                if !chartBuilder.chartData.series.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Data Series")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        ForEach(0..<chartBuilder.chartData.series.count, id: \.self) { index in
                            DataSeriesRow(
                                series: chartBuilder.chartData.series[index],
                                onEdit: { newSeries in
                                    chartBuilder.chartData.series[index] = newSeries
                                },
                                onDelete: {
                                    chartBuilder.chartData.series.remove(at: index)
                                }
                            )
                        }
                        
                        Button("Add Series") {
                            let newSeries = DataSeries(
                                name: "Series \(chartBuilder.chartData.series.count + 1)",
                                values: Array(repeating: 0.0, count: 5),
                                color: ChartStyle.defaultColors[chartBuilder.chartData.series.count % ChartStyle.defaultColors.count]
                            )
                            chartBuilder.chartData.series.append(newSeries)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Data Table View
                if !chartBuilder.chartData.series.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Data Preview")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        ChartDataTable(data: chartBuilder.chartData)
                            .frame(maxHeight: 300)
                    }
                }
            }
            .padding()
        }
    }
}

struct DataSeriesRow: View {
    let series: DataSeries
    let onEdit: (DataSeries) -> Void
    let onDelete: () -> Void
    
    @State private var showingEditor = false
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(series.color)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(series.name)
                    .font(.headline)
                
                Text("\(series.values.count) values")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Edit") {
                showingEditor = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button("Delete") {
                onDelete()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundStyle(.red)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .sheet(isPresented: $showingEditor) {
            DataSeriesEditor(series: series, onSave: onEdit)
        }
    }
}

struct DataSeriesEditor: View {
    let series: DataSeries
    let onSave: (DataSeries) -> Void
    
    @State private var name: String
    @State private var values: [String]
    @State private var selectedColor: Color
    
    @Environment(\.dismiss) private var dismiss
    
    init(series: DataSeries, onSave: @escaping (DataSeries) -> Void) {
        self.series = series
        self.onSave = onSave
        self._name = State(initialValue: series.name)
        self._values = State(initialValue: series.values.map { String($0) })
        self._selectedColor = State(initialValue: series.color)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Series Properties") {
                    TextField("Name", text: $name)
                    
                    ColorPicker("Color", selection: $selectedColor)
                }
                
                Section("Values") {
                    ForEach(0..<values.count, id: \.self) { index in
                        HStack {
                            Text("Value \(index + 1)")
                            TextField("0.0", text: $values[index])
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    Button("Add Value") {
                        values.append("0.0")
                    }
                    
                    if values.count > 1 {
                        Button("Remove Last") {
                            values.removeLast()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Series")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let doubleValues = values.compactMap { Double($0) }
                        let newSeries = DataSeries(
                            name: name,
                            values: doubleValues,
                            color: selectedColor
                        )
                        onSave(newSeries)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ChartDataTable: View {
    let data: ChartDataSet
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVGrid(columns: createColumns(), spacing: 1) {
                // Headers
                if !data.categories.isEmpty {
                    Text("Category")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                }
                
                ForEach(data.series, id: \.name) { series in
                    Text(series.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                }
                
                // Data Rows
                ForEach(0..<maxRowCount, id: \.self) { rowIndex in
                    if !data.categories.isEmpty && rowIndex < data.categories.count {
                        Text(data.categories[rowIndex])
                            .font(.caption)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                    } else if !data.categories.isEmpty {
                        Text("")
                            .font(.caption)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                    }
                    
                    ForEach(data.series, id: \.name) { series in
                        if rowIndex < series.values.count {
                            Text(String(format: "%.2f", series.values[rowIndex]))
                                .font(.caption)
                                .padding(8)
                                .background(Color.white)
                        } else {
                            Text("")
                                .font(.caption)
                                .padding(8)
                                .background(Color.white)
                        }
                    }
                }
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private func createColumns() -> [GridItem] {
        var columns: [GridItem] = []
        
        if !data.categories.isEmpty {
            columns.append(GridItem(.flexible(minimum: 80)))
        }
        
        for _ in data.series {
            columns.append(GridItem(.flexible(minimum: 80)))
        }
        
        return columns
    }
    
    private var maxRowCount: Int {
        let categoryCount = data.categories.isEmpty ? 0 : data.categories.count
        let maxSeriesCount = data.series.map { $0.values.count }.max() ?? 0
        return max(categoryCount, maxSeriesCount)
    }
}

#Preview("Chart Data View") {
    let chartBuilder = ChartBuilder()
    chartBuilder.generateSampleData()
    
    return ChartDataView(
        chartBuilder: chartBuilder,
        showingDataImporter: .constant(false)
    )
    .frame(width: 800, height: 600)
}

#Preview("Data Series Row") {
    DataSeriesRow(
        series: DataSeries(
            name: "Sample Data",
            values: [10, 20, 30, 40, 50],
            color: .blue
        ),
        onEdit: { _ in },
        onDelete: {}
    )
    .frame(width: 400, height: 80)
}

#Preview("Chart Data Table") {
    let sampleData = ChartDataSet.generateSample(for: .line)
    
    return ChartDataTable(data: sampleData)
        .frame(width: 600, height: 300)
}