//
//  SimpleRestoreDialog.swift
//  Pulto
//
//  Created by Joshua Herman on 6/18/25.
//  Copyright 2025 Apple. All rights reserved.
//

import SwiftUI

// MARK: - Create this simple dialog struct
// Add this to a new file or at the bottom of your OpenWindowView file:

struct SimpleRestoreDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject var windowManager: WindowTypeManager
    @Binding var nextWindowID: Int
    @Environment(\.openWindow) private var openWindow
    
    @State private var availableFiles: [String] = []
    @State private var selectedFile: String?
    @State private var isLoading = false
    @State private var resultMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Restore Environment")
                    .font(.title2)
                    .padding()
                
                if isLoading {
                    ProgressView("Restoring...")
                        .padding()
                } else {
                    VStack(spacing: 15) {
                        Text("Available Notebook Files:")
                            .font(.headline)
                        
                        if availableFiles.isEmpty {
                            Text("No .ipynb files found in Documents")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(availableFiles, id: \.self) { fileName in
                                Button(fileName) {
                                    selectedFile = fileName
                                    performSimpleRestore(fileName)
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        
                        Button("Refresh Files") {
                            loadAvailableFiles()
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
                if !resultMessage.isEmpty {
                    Text(resultMessage)
                        .foregroundStyle(.green)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Restore Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            loadAvailableFiles()
        }
    }
    
    private func loadAvailableFiles() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let notebookFiles = contents.filter { $0.pathExtension.lowercased() == "ipynb" }
            availableFiles = notebookFiles.map { $0.lastPathComponent }
        } catch {
            print("Error loading files: \(error)")
            availableFiles = []
        }
    }
    
    private func performSimpleRestore(_ fileName: String) {
        isLoading = true
        resultMessage = ""
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            isLoading = false
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        Task {
            do {
                // Simple import without the complex environment restoration
                let result = try windowManager.importFromGenericNotebook(fileURL: fileURL)
                
                await MainActor.run {
                    // Convert AnyHashable back to NewWindowID
                    let restoredWindows = result.restoredWindows.compactMap { $0 as? NewWindowID }
                    
                    // Open the windows
                    for window in restoredWindows {
                        openWindow(value: window.id)
                    }
                    
                    // Update next window ID
                    let currentMaxID = windowManager.getAllWindows().map { $0.id }.max() ?? 0
                    nextWindowID = currentMaxID + 1
                    
                    resultMessage = " Restored \(restoredWindows.count) windows"
                    isLoading = false
                    
                    // Auto-close after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isPresented = false
                    }
                }
            } catch {
                await MainActor.run {
                    resultMessage = " Failed to restore: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}