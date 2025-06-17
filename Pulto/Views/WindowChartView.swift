//
//  FlatSpatialEditorView.swift
//  Pulto
//
//  Created by Joshua Herman on 6/17/25.
//  Copyright © 2025 Apple. All rights reserved.
//
import SwiftUI
import Charts

// MARK: - Main View

struct WindowChartView: View {
    @StateObject private var viewModel = ChartViewModel()
    @State private var draggingOffsets: [UUID: CGSize] = [:]
    @State private var draggingOffsetControl: CGSize = .zero

    var body: some View {
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
                        }
                )
                .zIndex(1000) // Always on top
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.1))
    }
}
