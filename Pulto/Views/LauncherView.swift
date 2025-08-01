//
//  LauncherView.swift
//  Pulto3
//
//  Created by Assistant on 1/29/25.
//

import SwiftUI

struct LauncherView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State private var showingFileClassifier = false
    @State private var showingBatchImporter = false
    @State private var showingFormatConverter = false
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "cube.transparent.fill")
                .font(.system(size: 80))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Text("Pulto")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Volumetric Data Analysis and 3D Visualization")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Import & Analysis")
                .font(.title2)
                .fontWeight(.bold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                FeatureCard(
                    title: "File Classifier",
                    description: "Import and analyze data files",
                    icon: "doc.text.magnifyingglass",
                    color: .blue
                ) {
                    showingFileClassifier = true
                }

                FeatureCard(
                    title: "Batch Import",
                    description: "Import multiple files at once",
                    icon: "square.and.arrow.down.on.square",
                    color: .green
                ) {
                    showingBatchImporter = true
                }

                FeatureCard(
                    title: "Format Converter",
                    description: "Convert between file formats",
                    icon: "arrow.triangle.2.circlepath",
                    color: .purple
                ) {
                    showingFormatConverter = true
                }

                // ... existing feature cards ...
            }
        }
    }
    
    private var windowsSection: some View {
        VStack(spacing: 16) {
            Text("Open Windows")
                .font(.title2)
                .fontWeight(.bold)
            
            ForEach(windowManager.getAllWindows(), id: \.id) { window in
                Button(window.title) {
                    openWindow(id: window.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    headerSection
                    featuresSection
                    
                    if !windowManager.getAllWindows().isEmpty {
                        windowsSection
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .sheet(isPresented: $showingFileClassifier) {
                FileClassifierView()
            }
            .sheet(isPresented: $showingBatchImporter) {
                BatchImportView()
            }
            .sheet(isPresented: $showingFormatConverter) {
                FormatConverterView()
            }
        }
    }
}

#Preview {
    LauncherView()
}