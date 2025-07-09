//
//  LauncherView.swift
//  Pulto
//
//  Created by Assistant on 12/29/2024.
//

import SwiftUI

struct LauncherView: View {
    @StateObject private var windowManager = WindowTypeManager.shared
    @StateObject private var spatialManager = SpatialWindowManager.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Pulto Launcher")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Launch spatial windows and manage your workspace")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Quick Actions
                VStack(spacing: 16) {
                    Text("Quick Actions")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        LauncherActionCard(
                            title: "Main Interface",
                            subtitle: "Open main workspace",
                            icon: "rectangle.stack.fill",
                            color: .blue
                        ) {
                            openWindow(id: "main")
                        }
                        
                        LauncherActionCard(
                            title: "Immersive Space",
                            subtitle: "Enter spatial mode",
                            icon: "cube.transparent",
                            color: .purple
                        ) {
                            spatialManager.enterImmersiveSpace()
                        }
                        
                        LauncherActionCard(
                            title: "Project Browser",
                            subtitle: "Browse projects",
                            icon: "folder.fill",
                            color: .green
                        ) {
                            openWindow(id: "open-project-window")
                        }
                    }
                }
                
                Divider()
                
                // Recent Windows
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Windows")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if windowManager.getAllWindows().isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "rectangle.dashed")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("No recent windows")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Create a new window to get started")
                                .font(.caption)
                                .foregroundColor(.tertiary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(windowManager.getAllWindows().prefix(5), id: \.id) { window in
                                    RecentWindowRow(window: window) {
                                        openWindow(value: window.id)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                
                Spacer()
                
                // Bottom Actions
                HStack(spacing: 16) {
                    Button("Close Launcher") {
                        dismissWindow(id: "launcher")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Create New Window") {
                        let newId = windowManager.getNextWindowID()
                        let newWindow = windowManager.createWindow(.spatial, id: newId)
                        openWindow(value: newWindow.id)
                        windowManager.markWindowAsOpened(newWindow.id)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Launcher")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            print("🚀 Launcher appeared")
        }
        .onDisappear {
            print("🚀 Launcher disappeared")
        }
    }
}

struct LauncherActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(isHovered ? 0.5 : 0.2), lineWidth: 2)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

struct RecentWindowRow: View {
    let window: NewWindowID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: window.windowType.icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(window.windowType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Window #\(window.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(window.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    LauncherView()
        .environmentObject(WindowTypeManager.shared)
        .environmentObject(SpatialWindowManager.shared)
}