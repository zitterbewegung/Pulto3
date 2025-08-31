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
    @State private var showingCSVImport = false
    
    var body: some View {
        VStack(spacing: 30) {
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
            
            VStack(spacing: 16) {
                Button("Open Main Workspace") {
                    openWindow(id: "main")
                    dismissWindow(id: "launcher")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Browse Projects") {
                    openWindow(id: "open-project-window")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                #if os(visionOS)
                Button("Open Immersive Workspace") {
                    Task {
                        await openWindow(id: "immersive-workspace")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                #endif
            }
            
            VStack(spacing: 8) {
                Text("Quick Actions")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 16) {
                    Button("Import 3D Model") {
                        openWindow(id: "main")
                        dismissWindow(id: "launcher")
                        // Trigger 3D model import when needed
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Import Point Cloud") {
                        openWindow(id: "main")
                        dismissWindow(id: "launcher")
                        // Trigger point cloud import when needed
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Import CSV Data") {
                        showingCSVImport = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .sheet(isPresented: $showingCSVImport) {
            FileClassifierAndRecommenderView()
        }
    }
}

#Preview {
    LauncherView()
}