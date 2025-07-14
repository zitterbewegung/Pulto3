//
//  AutoSaveStatusView.swift
//  Pulto
//
//  Auto-save status and control view
//

import SwiftUI

struct AutoSaveStatusView: View {
    @StateObject private var autoSaveManager = AutoSaveManager.shared
    @State private var showingDetails = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Status Header
            HStack {
                Image(systemName: autoSaveManager.isAutoSaving ? "arrow.clockwise" : "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(autoSaveManager.isAutoSaving ? .orange : .green)
                    .symbolEffect(.pulse, isActive: autoSaveManager.isAutoSaving)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto-Save Status")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(autoSaveManager.isAutoSaving ? "Saving..." : "Ready")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: { showingDetails.toggle() }) {
                    Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            
            // Last Save Info
            if let lastSaveTime = autoSaveManager.lastSaveTime {
                HStack {
                    Text("Last saved:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(lastSaveTime, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                }
            }
            
            // Expanded Details
            if showingDetails {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    // Settings Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Settings")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack {
                            settingRow("Auto-save enabled", autoSaveManager.autoSaveEnabled)
                            Spacer()
                            settingRow("Local files", autoSaveManager.saveToLocalFiles)
                        }
                        
                        HStack {
                            settingRow("Jupyter server", autoSaveManager.jupyterServerAutoSave)
                            Spacer()
                        }
                    }
                    
                    Divider()
                    
                    // Recent Results
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Save Results")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if autoSaveManager.lastSaveResults.isEmpty {
                            Text("No recent saves")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 4) {
                                    ForEach(autoSaveManager.lastSaveResults.reversed().prefix(5).indices, id: \.self) { index in
                                        let result = autoSaveManager.lastSaveResults.reversed()[index]
                                        saveResultRow(result)
                                    }
                                }
                            }
                            .frame(maxHeight: 120)
                        }
                    }
                    
                    // Manual Save Button
                    Button(action: {
                        Task {
                            await autoSaveManager.triggerManualSave()
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save Now")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(autoSaveManager.isAutoSaving)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
    }
    
    private func settingRow(_ title: String, _ isEnabled: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(isEnabled ? .green : .red)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func saveResultRow(_ result: AutoSaveResult) -> some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(result.success ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.destination == .localFile ? "Local File" : "Jupyter Server")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(result.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let windowID = result.windowID {
                Text("Window \(windowID)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Preview

#Preview {
    AutoSaveStatusView()
        .frame(width: 400, height: 300)
}