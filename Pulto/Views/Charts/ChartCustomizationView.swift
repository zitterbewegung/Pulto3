//
//  ChartCustomizationView.swift
//  Pulto3
//
//  Created by AI Assistant on 1/29/25.
//

import SwiftUI

struct ChartCustomizationView: View {
    @ObservedObject var chartBuilder: ChartBuilder
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Chart Metadata
                VStack(alignment: .leading, spacing: 16) {
                    Text("Chart Information")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        TextField("Chart Title", text: $chartBuilder.chartMetadata.title)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Description", text: $chartBuilder.chartMetadata.description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3, reservesSpace: true)
                        
                        HStack {
                            TextField("X-Axis Label", text: $chartBuilder.chartMetadata.xAxisLabel)
                                .textFieldStyle(.roundedBorder)
                            
                            TextField("Y-Axis Label", text: $chartBuilder.chartMetadata.yAxisLabel)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        TextField("Data Source", text: $chartBuilder.chartMetadata.source)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                // Visual Style
                VStack(alignment: .leading, spacing: 16) {
                    Text("Visual Style")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Primary Color")
                            Spacer()
                            ColorPicker("Primary", selection: $chartBuilder.chartStyle.primaryColor)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("Secondary Color")
                            Spacer()
                            ColorPicker("Secondary", selection: $chartBuilder.chartStyle.secondaryColor)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("Background")
                            Spacer()
                            ColorPicker("Background", selection: $chartBuilder.chartStyle.backgroundColor)
                                .labelsHidden()
                        }
                        
                        Divider()
                        
                        Toggle("Show Grid", isOn: $chartBuilder.chartStyle.showGrid)
                        Toggle("Show Legend", isOn: $chartBuilder.chartStyle.showLegend)
                        Toggle("Show Axes", isOn: $chartBuilder.chartStyle.showAxes)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Line Width: \(String(format: "%.1f", chartBuilder.chartStyle.lineWidth))")
                            Slider(value: $chartBuilder.chartStyle.lineWidth, in: 0.5...5.0)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Point Size: \(String(format: "%.1f", chartBuilder.chartStyle.pointSize))")
                            Slider(value: $chartBuilder.chartStyle.pointSize, in: 1...10)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Corner Radius: \(String(format: "%.1f", chartBuilder.chartStyle.cornerRadius))")
                            Slider(value: $chartBuilder.chartStyle.cornerRadius, in: 0...20)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Opacity: \(String(format: "%.2f", chartBuilder.chartStyle.opacity))")
                            Slider(value: $chartBuilder.chartStyle.opacity, in: 0.1...1.0)
                        }
                    }
                }
                
                // Color Themes
                VStack(alignment: .leading, spacing: 16) {
                    Text("Color Themes")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(ColorTheme.allCases, id: \.self) { theme in
                            ColorThemeCard(theme: theme) {
                                applyColorTheme(theme)
                            }
                        }
                    }
                }
                
                // Style Presets
                VStack(alignment: .leading, spacing: 16) {
                    Text("Style Presets")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(StylePreset.allCases, id: \.self) { preset in
                            StylePresetCard(preset: preset) {
                                applyStylePreset(preset)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func applyColorTheme(_ theme: ColorTheme) {
        switch theme {
        case .ocean:
            chartBuilder.chartStyle.primaryColor = .blue
            chartBuilder.chartStyle.secondaryColor = .teal
            chartBuilder.chartStyle.backgroundColor = Color.blue.opacity(0.05)
            
        case .sunset:
            chartBuilder.chartStyle.primaryColor = .orange
            chartBuilder.chartStyle.secondaryColor = .red
            chartBuilder.chartStyle.backgroundColor = Color.orange.opacity(0.05)
            
        case .forest:
            chartBuilder.chartStyle.primaryColor = .green
            chartBuilder.chartStyle.secondaryColor = Color(red: 0.2, green: 0.6, blue: 0.2)
            chartBuilder.chartStyle.backgroundColor = Color.green.opacity(0.05)
            
        case .monochrome:
            chartBuilder.chartStyle.primaryColor = .black
            chartBuilder.chartStyle.secondaryColor = .gray
            chartBuilder.chartStyle.backgroundColor = .clear
            
        case .vibrant:
            chartBuilder.chartStyle.primaryColor = .purple
            chartBuilder.chartStyle.secondaryColor = .pink
            chartBuilder.chartStyle.backgroundColor = Color.purple.opacity(0.05)
            
        case .professional:
            chartBuilder.chartStyle.primaryColor = Color(red: 0.2, green: 0.4, blue: 0.8)
            chartBuilder.chartStyle.secondaryColor = Color(red: 0.6, green: 0.6, blue: 0.6)
            chartBuilder.chartStyle.backgroundColor = .clear
        }
    }
    
    private func applyStylePreset(_ preset: StylePreset) {
        switch preset {
        case .minimal:
            chartBuilder.chartStyle.showGrid = false
            chartBuilder.chartStyle.showAxes = true
            chartBuilder.chartStyle.lineWidth = 1.5
            chartBuilder.chartStyle.pointSize = 3.0
            chartBuilder.chartStyle.cornerRadius = 0
            chartBuilder.chartStyle.opacity = 1.0
            
        case .bold:
            chartBuilder.chartStyle.showGrid = true
            chartBuilder.chartStyle.showAxes = true
            chartBuilder.chartStyle.lineWidth = 4.0
            chartBuilder.chartStyle.pointSize = 8.0
            chartBuilder.chartStyle.cornerRadius = 8
            chartBuilder.chartStyle.opacity = 0.9
            
        case .subtle:
            chartBuilder.chartStyle.showGrid = true
            chartBuilder.chartStyle.showAxes = true
            chartBuilder.chartStyle.lineWidth = 1.0
            chartBuilder.chartStyle.pointSize = 2.0
            chartBuilder.chartStyle.cornerRadius = 2
            chartBuilder.chartStyle.opacity = 0.6
            
        case .modern:
            chartBuilder.chartStyle.showGrid = false
            chartBuilder.chartStyle.showAxes = false
            chartBuilder.chartStyle.lineWidth = 3.0
            chartBuilder.chartStyle.pointSize = 6.0
            chartBuilder.chartStyle.cornerRadius = 12
            chartBuilder.chartStyle.opacity = 0.8
        }
    }
}

// MARK: - Color Themes

enum ColorTheme: String, CaseIterable {
    case ocean = "Ocean"
    case sunset = "Sunset"
    case forest = "Forest"
    case monochrome = "Monochrome"
    case vibrant = "Vibrant"
    case professional = "Professional"
    
    var colors: [Color] {
        switch self {
        case .ocean: return [.blue, .teal, .cyan]
        case .sunset: return [.orange, .red, .yellow]
        case .forest: return [.green, Color(red: 0.2, green: 0.6, blue: 0.2), Color(red: 0.4, green: 0.8, blue: 0.4)]
        case .monochrome: return [.black, .gray, Color(white: 0.6)]
        case .vibrant: return [.purple, .pink, .indigo]
        case .professional: return [Color(red: 0.2, green: 0.4, blue: 0.8), Color(red: 0.6, green: 0.6, blue: 0.6), Color(red: 0.3, green: 0.5, blue: 0.9)]
        }
    }
}

enum StylePreset: String, CaseIterable {
    case minimal = "Minimal"
    case bold = "Bold"
    case subtle = "Subtle"
    case modern = "Modern"
    
    var description: String {
        switch self {
        case .minimal: return "Clean and simple"
        case .bold: return "Strong visual impact"
        case .subtle: return "Soft and gentle"
        case .modern: return "Contemporary design"
        }
    }
}

// MARK: - Theme Cards

struct ColorThemeCard: View {
    let theme: ColorTheme
    let onSelection: () -> Void
    
    var body: some View {
        Button(action: onSelection) {
            VStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        if index < theme.colors.count {
                            Rectangle()
                                .fill(theme.colors[index])
                                .frame(height: 20)
                        }
                    }
                }
                .cornerRadius(4)
                
                Text(theme.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct StylePresetCard: View {
    let preset: StylePreset
    let onSelection: () -> Void
    
    var body: some View {
        Button(action: onSelection) {
            VStack(alignment: .leading, spacing: 8) {
                Text(preset.rawValue)
                    .font(.headline)
                
                Text(preset.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Chart Customization View") {
    let chartBuilder = ChartBuilder()
    chartBuilder.generateSampleData()
    
    return ChartCustomizationView(chartBuilder: chartBuilder)
        .frame(width: 800, height: 600)
}

#Preview("Color Theme Card") {
    ColorThemeCard(
        theme: .ocean,
        onSelection: {}
    )
    .frame(width: 120, height: 80)
}

#Preview("Style Preset Card") {
    StylePresetCard(
        preset: .modern,
        onSelection: {}
    )
    .frame(width: 200, height: 80)
}