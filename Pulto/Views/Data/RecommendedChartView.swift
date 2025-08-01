//
//  RecommendedChartView.swift
//  Pulto3
//
//  Created by AI Assistant on 1/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import Charts

struct RecommendedChartView: View {
    let windowID: Int
    @EnvironmentObject var windowManager: WindowTypeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ContentUnavailableView(
                    "Chart View Temporarily Unavailable",
                    systemImage: "chart.xyaxis.line",
                    description: Text("This view is being updated to resolve type conflicts. Please check back soon.")
                )
            }
            .navigationTitle("Chart - Window #\(windowID)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu("Export") {
                        Button("Export to Jupyter") {
                            // Temporarily disabled
                            print("Export temporarily disabled")
                        }
                        
                        Button("Save as Image") {
                            // TODO: Implement image export
                        }
                    }
                }
            }
        }
    }
}

// TEMPORARILY COMMENTED OUT: All enhanced chart views to resolve compilation issues

/*
// Enhanced individual chart views with better styling and more data
struct EnhancedLineChartView: View {
    let data: CSVData
    
    var body: some View {
        // Implementation temporarily removed
    }
}

struct EnhancedBarChartView: View {
    let data: CSVData
    
    var body: some View {
        // Implementation temporarily removed
    }
}

struct EnhancedScatterPlotView: View {
    let data: CSVData
    
    var body: some View {
        // Implementation temporarily removed
    }
}

struct EnhancedAreaChartView: View {
    let data: CSVData
    
    var body: some View {
        // Implementation temporarily removed
    }
}

struct EnhancedHistogramView: View {
    let data: CSVData
    
    var body: some View {
        // Implementation temporarily removed
    }
}

struct EnhancedPieChartView: View {
    let data: CSVData
    
    var body: some View {
        // Implementation temporarily removed
    }
}

// Chart insights view
struct ChartInsightsView: View {
    let data: CSVData
    let recommendation: ChartRecommendation
    
    var body: some View {
        // Implementation temporarily removed
    }
}
*/

struct InsightCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// TEMPORARILY COMMENTED OUT: Extensions for better data handling
/*
// Extensions for better data handling
extension ColumnType {
    var displayName: String {
        switch self {
        case .numeric: return "Numeric"
        case .categorical: return "Category"
        case .date: return "Date"
        case .unknown: return "Unknown"
        }
    }
    
    var color: Color {
        switch self {
        case .numeric: return .blue
        case .categorical: return .green
        case .date: return .orange
        case .unknown: return .gray
        }
    }
}
*/

#Preview {
    RecommendedChartView(windowID: 1)
        .environmentObject(WindowTypeManager.shared)
}