//
//  FlatSpatialEditorView.swift
//  Pulto
//
//  Created by Joshua Herman on 6/17/25.
//  Copyright 2025 Apple. All rights reserved.
//
import SwiftUI
import Charts

// MARK: - Main View

struct WindowChartView: View {
    @StateObject private var viewModel = ChartViewModel()
    @State private var draggingOffsets: [UUID: CGSize] = [:]
    @State private var draggingOffsetControl: CGSize = .zero
    @State private var showCodeSidebar = false 
    @State private var generatedCode = "" 
    let windowID: Int?

    init(windowID: Int? = nil) {
        self.windowID = windowID
    }

    var body: some View {
        HStack(spacing: 0) {
            // Main Chart Content
            ZStack {
                // Windows
                ForEach(Array(viewModel.windows.enumerated()), id: \.element.id) { index, window in
                    if window.isVisible {
                        DraggableWindow(
                            window: window,
                            index: index,
                            viewModel: viewModel,
                            draggingOffset: draggingOffsets[window.id] ?? .zero
                        ) { newOffset in
                            draggingOffsets[window.id] = newOffset
                        }
                        .zIndex(Double(index))
                    }
                }

                // Control Window
                ControlWindowView(viewModel: viewModel)
                    .frame(width: 350, height: 500)
                    .background(Color.gray.opacity(0.9))
                    .cornerRadius(15)
                    .shadow(radius: 10)
                    .offset(
                        x: viewModel.controlOffset.width + draggingOffsetControl.width,
                        y: viewModel.controlOffset.height + draggingOffsetControl.height
                    )
                    .rotationEffect(viewModel.controlRotation)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                draggingOffsetControl = gesture.translation
                            }
                            .onEnded { gesture in
                                viewModel.controlOffset.width += gesture.translation.width
                                viewModel.controlOffset.height += gesture.translation.height
                                draggingOffsetControl = .zero
                                viewModel.saveWindowStates()
                                generateChartCode() 
                            }
                    )
                    .zIndex(1000) // Always on top
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.1))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCodeSidebar.toggle() }) {
                        Image(systemName: showCodeSidebar ? "chevron.right" : "chevron.left")
                            .font(.title3)
                    }
                }
            }
            
            // Code Sidebar
            if showCodeSidebar {
                CodeSidebarView(code: generatedCode)
                    .frame(width: 400)
                    .transition(.move(edge: .trailing))
            }
        }
        .onAppear {
            if let windowID = windowID {
                saveChartDataToWindowManager()
            }
            generateChartCode() 
        }
        .onDisappear {
            if let windowID = windowID {
                saveChartDataToWindowManager()
            }
        }
        .onChange(of: viewModel.windows.count) { _, _ in
            generateChartCode() 
        }
        .animation(.easeInOut(duration: 0.3), value: showCodeSidebar)
    }
    
    private struct CodeSidebarView: View {
        let code: String
        @State private var showingCopySuccess = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Label("Chart Code", systemImage: "chart.xyaxis.line")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Button(action: copyCode) {
                        Image(systemName: showingCopySuccess ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(showingCopySuccess ? .green : .blue)
                    }
                    .animation(.easeInOut, value: showingCopySuccess)
                }
                .padding()
                .background(.regularMaterial)
                
                Divider()
                
                // Code content
                ScrollView {
                    Text(code)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(.ultraThinMaterial)
            }
            .background(.regularMaterial)
        }
        
        private func copyCode() {
            #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
            #else
            UIPasteboard.general.string = code
            #endif
            
            showingCopySuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showingCopySuccess = false
            }
        }
    }
    
    private func generateChartCode() {
        generatedCode = generateChartContent()
    }
    
    private func saveChartDataToWindowManager() {
        guard let windowID = windowID else { return }
        
        let windowManager = WindowTypeManager.shared
        
        let chartData = ChartData(
            title: "Chart Collection - Window \(windowID)",
            chartType: "multi_chart",
            xLabel: "Chart Index",
            yLabel: "Window Position",
            xData: viewModel.windows.enumerated().map { Double($0.offset) },
            yData: viewModel.windows.map { Double($0.offset.width) },
            color: "blue",
            style: "solid"
        )
        
        let chartContent = generateChartContent()
        
        windowManager.updateWindowChartData(windowID, chartData: chartData)
        windowManager.updateWindowContent(windowID, content: chartContent)
        
        print(" Saved chart data for window \(windowID)")
    }
    
    private func generateChartContent() -> String {
        var content = """
        # Chart Window Collection
        # Generated from WindowChartView
        
        import matplotlib.pyplot as plt
        import numpy as np
        
        chart_windows = [
        """
        
        for (index, window) in viewModel.windows.enumerated() {
            content += """
            
            {
                'id': \(index),
                'title': '\(window.title)',
                'position': {'x': \(window.offset.width), 'y': \(window.offset.height)},
                'rotation': \(window.rotation.degrees),
                'visible': \(window.isVisible),
                'color': '\(window.color)',
                'content_type': '\(window.contentType)'
            },
            """
        }
        
        content += """
        ]
        
        control_window = {
            'position': {'x': \(viewModel.controlOffset.width), 'y': \(viewModel.controlOffset.height)},
            'rotation': \(viewModel.controlRotation.degrees),
            'grid_mode': \(viewModel.isGridMode),
            'grid_size': '\(viewModel.gridColumns)x\(viewModel.gridRows)'
        }
        
        fig, axes = plt.subplots(\(viewModel.gridRows), \(viewModel.gridColumns), figsize=(15, 10))
        fig.suptitle('Recreated Chart Layout from VisionOS')
        
        for i, window in enumerate(chart_windows):
            if window['visible'] and i < len(axes.flat):
                ax = axes.flat[i] if \(viewModel.gridRows * viewModel.gridColumns) > 1 else axes
                
                x = np.linspace(0, 10, 50)
                y = np.sin(x + i * 0.5) * (i + 1)
                
                ax.plot(x, y, label=window['title'])
                ax.set_title(window['title'])
                ax.grid(True, alpha=0.3)
                ax.legend()
        
        plt.tight_layout()
        plt.show()
        
        print("Chart Window Summary:")
        print("-" * 40)
        for window in chart_windows:
            status = "Visible" if window['visible'] else "Hidden"
            print(f"{window['title']:15} | {status:8} | Pos: ({window['position']['x']:6.1f}, {window['position']['y']:6.1f})")
        
        print(f"\nControl Window: Grid {control_window['grid_size']}, Grid Mode: {control_window['grid_mode']}")
        """
        
        return content
    }
}
#Preview {
    WindowChartView()
}
