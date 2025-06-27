//  
//  EnhancedNotebookChartsView.swift
//  Pulto
//
//  Created by Joshua Herman on 6/22/25.
//  Copyright © 2025 Apple. All rights reserved.
//


import SwiftUI
import UIKit
import Foundation
import RealityKit
import UniformTypeIdentifiers

struct EnhancedNotebookChartsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var windowManager = WindowTypeManager.shared
    @Environment(\.openWindow) private var openWindow
    
    // File management
    @State private var showingFilePicker = false
    @State private var showingSaveDialog = false
    @State private var selectedFile: URL?
    @State private var localNotebooks: [NotebookFile] = []
    
    // Existing states
    @State private var result: String = "No response yet"
    @State private var chartImages: [String: [UIImage]] = [:]
    @State private var chartOffsets: [String: CGSize] = [:]
    @State private var debugMode: Bool = true
    @State private var notebookName: String = ""
    @State private var tapped = false
    @State private var modelLoadingError: Error?
    @State private var isLoading = false
    @State private var showingSidebar = true
    @State private var notebookMetadata: NotebookMetadata?

    var body: some View {
        NavigationSplitView {
            // Enhanced Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // Header with Close Button
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.title2)
                                .foregroundStyle(.blue)

                            Text("Notebooks")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .background(Circle().fill(.ultraThinMaterial))
                        }
                        .buttonStyle(.plain)
                    }

                    // Search/Input Field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("Notebook name (e.g., Pulto.ipynb)", text: $notebookName)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()

                // Enhanced Actions Section
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Actions")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        // File Browser Button
                        Button(action: { showingFilePicker = true }) {
                            HStack {
                                Image(systemName: "folder.badge.plus")
                                    .foregroundStyle(.blue)
                                Text("Browse Files")
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        
                        // Save Environment Button
                        Button(action: { showingSaveDialog = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                    .foregroundStyle(.green)
                                Text("Save Environment")
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        // Open from Server Button
                        Button(action: openNotebook) {
                            HStack {
                                Image(systemName: "network")
                                    .foregroundStyle(.orange)
                                Text("Open from Server")
                                    .fontWeight(.medium)
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading || notebookName.isEmpty)
                    }

                    // Local Files Section
                    if !localNotebooks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Local Files")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Button("Refresh") {
                                    loadLocalNotebooks()
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }

                            ScrollView {
                                VStack(spacing: 4) {
                                    ForEach(localNotebooks) { notebook in
                                        LocalNotebookRow(
                                            notebook: notebook,
                                            onSelect: { loadLocalNotebook(notebook) }
                                        )
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        }
                    }

                    // Recent Files Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        ForEach(["Analysis.ipynb", "DataViz.ipynb", "Research.ipynb"], id: \.self) { name in
                            Button(action: { notebookName = name }) {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundStyle(.orange)
                                    Text(name)
                                        .font(.body)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.quaternary.opacity(0.5))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Enhanced Status Section
                VStack(alignment: .leading, spacing: 8) {
                    if !result.contains("No response yet") || notebookMetadata != nil {
                        Text("Status")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        if let metadata = notebookMetadata {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Windows: \(metadata.windowCount)")
                                    .font(.caption)
                                Text("Created: \(metadata.createdDate, style: .relative)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        }

                        Text(result)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(minWidth: 280, maxWidth: 320)
            .background(.regularMaterial)
        } detail: {
            // Main Content Area (existing code)
            ZStack {
                if chartImages.isEmpty && !isLoading {
                    emptyStateView
                } else if isLoading {
                    loadingView
                } else {
                    chartContentView
                }
            }
            .background(.ultraThinMaterial)
            .navigationTitle("Spatial Notebook")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear {
            loadModel()
            loadLocalNotebooks()
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "ipynb") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: $showingSaveDialog) {
            SaveNotebookDialog(
                isPresented: $showingSaveDialog,
                windowManager: windowManager
            )
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // MARK: - Enhanced Views
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)

            VStack(spacing: 8) {
                Text("Import Your Notebook")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Browse for a local notebook file or connect to your server")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)
            
            HStack(spacing: 16) {
                Button("Browse Files") {
                    showingFilePicker = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Restore Environment") {
                    showingFilePicker = true
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Processing notebook...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - File Management Functions
    
    private func loadLocalNotebooks() {
        DispatchQueue.global(qos: .userInitiated).async {
            let notebooks = findLocalNotebooks()
            DispatchQueue.main.async {
                self.localNotebooks = notebooks
            }
        }
    }
    
    private func findLocalNotebooks() -> [NotebookFile] {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            return fileURLs.compactMap { url in
                guard url.pathExtension == "ipynb" else { return nil }
                
                do {
                    let attributes = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
                    
                    return NotebookFile(
                        url: url,
                        name: url.lastPathComponent,
                        size: Int64(attributes.fileSize ?? 0),
                        createdDate: attributes.creationDate ?? Date(),
                        modifiedDate: attributes.contentModificationDate ?? Date()
                    )
                } catch {
                    return nil
                }
            }
            .sorted { $0.modifiedDate > $1.modifiedDate }
        } catch {
            debugLog("Error loading local notebooks: \(error)")
            return []
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFile = url
            loadNotebookFromFile(url)
            
        case .failure(let error):
            debugLog("File selection error: \(error)")
            self.result = "Error selecting file: \(error.localizedDescription)"
        }
    }
    
    private func loadLocalNotebook(_ notebook: NotebookFile) {
        selectedFile = notebook.url
        notebookName = notebook.name
        loadNotebookFromFile(notebook.url)
    }
    
    private func loadNotebookFromFile(_ url: URL) {
        isLoading = true
        
        Task {
            do {
                // Read the notebook file
                let data = try Data(contentsOf: url)
                
                // Try to parse it for VisionOS metadata
                if let notebookJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Check for VisionOS metadata
                    if let metadata = notebookJSON["metadata"] as? [String: Any],
                       let visionOSData = metadata["visionos_export"] as? [String: Any] {
                        
                        // This is a VisionOS notebook - restore environment
                        await restoreVisionOSEnvironment(from: data)
                    } else {
                        // Regular notebook - send to server for chart extraction
                        await sendNotebookData(data, filename: url.lastPathComponent)
                    }
                }
            } catch {
                await MainActor.run {
                    self.result = "Error loading notebook: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func restoreVisionOSEnvironment(from data: Data) async {
        await MainActor.run {
            do {
                let importResult = try windowManager.importFromGenericNotebook(data: data)

                if !importResult.restoredWindows.isEmpty {
                    self.result = "Restored \(importResult.restoredWindows.count) windows"
                    self.notebookMetadata = NotebookMetadata(
                        windowCount: importResult.restoredWindows.count,
                        createdDate: Date()
                    )

                    for window in importResult.restoredWindows {
                        openWindow(id: window.windowType.rawValue, value: window.id)
                    }
                } else {
                    self.result = "No windows found to restore"
                }
            } catch {
                self.result = "Error restoring: \(error.localizedDescription)"
            }

            self.isLoading = false
        }
    }

    private func sendNotebookData(_ data: Data, filename: String) async {
        // Send to server for processing
        guard let encodedName = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "http://selle:8000/convert/\(encodedName)") else {
            await MainActor.run {
                self.result = "Invalid URL"
                self.isLoading = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(data)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        request.httpBody = body
        
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            await handleServerResponse(responseData, response: response)
        } catch {
            await MainActor.run {
                self.result = "Error: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func handleServerResponse(_ data: Data, response: URLResponse?) async {
        if let httpResponse = response as? HTTPURLResponse {
            debugLog("Server response: \(httpResponse.statusCode)")
        }
        
        do {
            if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Process chart images
                var decodedCharts: [String: [UIImage]] = [:]
                
                for (key, value) in jsonResponse {
                    if let imageArray = value as? [String] {
                        var uiImages: [UIImage] = []
                        for base64Str in imageArray {
                            if let img = decodeBase64ToImage(base64String: base64Str) {
                                uiImages.append(img)
                            }
                        }
                        if !uiImages.isEmpty {
                            decodedCharts[key] = uiImages
                        }
                    }
                }
                
                await MainActor.run {
                    self.chartImages = decodedCharts
                    self.result = "Loaded \(decodedCharts.count) charts"
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.result = "Error processing response: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Existing Functions (keep all your existing functions)
    
    private var chartContentView: some View {
        ScrollView {
            LazyVStack(spacing: 32) {
                ForEach(Array(chartImages.keys.sorted()), id: \.self) { chartKey in
                    chartCardView(for: chartKey)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
    }
    
    private func chartCardView(for chartKey: String) -> some View {
        let images = chartImages[chartKey] ?? []
        
        return VStack(alignment: .leading, spacing: 16) {
            // Card Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chart \(chartKey.replacingOccurrences(of: "chartKey_", with: ""))")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Interactive visualization ready for spatial placement")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    Task { await sendNotebookJSON(named: notebookName) }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Chart Images (your existing implementation)
            ForEach(0..<images.count, id: \.self) { idx in
                VStack(spacing: 12) {
                    Image(uiImage: images[idx])
                        .resizable()
                        .scaledToFit()
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .offset(chartOffsets[chartKey] ?? .zero)
                        .scaleEffect(tapped ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: tapped)
                        .gesture(
                            SimultaneousGesture(
                                TapGesture()
                                    .onEnded { _ in
                                        withAnimation {
                                            tapped.toggle()
                                        }
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        chartOffsets[chartKey] = value.translation
                                        debugLog("Dragging \(chartKey): \(value.translation)")
                                    }
                                    .onEnded { _ in
                                        Task {
                                            await sendNotebookJSON(named: notebookName)
                                        }
                                    }
                            )
                        )
                    
                    // Position Indicator
                    if let offset = chartOffsets[chartKey], offset != .zero {
                        HStack {
                            Image(systemName: "move.3d")
                                .foregroundStyle(.blue)
                            Text("Position: (\(Int(offset.width)), \(Int(offset.height)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, idx == images.count - 1 ? 20 : 0)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary, lineWidth: 1)
        )
    }
    
    // Keep all your existing functions like openNotebook, loadModel, sendNotebookJSON, etc.
    private func openNotebook() {
        Task {
            isLoading = true
            await sendNotebookJSON(named: notebookName)
            isLoading = false
        }
    }
    
    private func loadModel() {
        Task {
            do {
                let modelURL = Bundle.main.url(forResource: "Pulto_1_2374", withExtension: "usdz")
                debugLog("Model URL: \(String(describing: modelURL))")
                
                let _ = try await Model3D(named: "Pulto_1_2374.usdz")
                debugLog("Model loaded successfully")
            } catch {
                modelLoadingError = error
                debugLog("Error loading model: \(error)")
            }
        }
    }
    
    func decodeBase64ToImage(base64String: String) -> UIImage? {
        debugLog("Decoding base64 string to UIImage")
        guard let imageData = Data(base64Encoded: base64String) else {
            debugLog("Failed to decode base64 string into Data")
            return nil
        }
        guard let image = UIImage(data: imageData) else {
            debugLog("Failed to create UIImage from Data")
            return nil
        }
        debugLog("Successfully decoded image")
        return image
    }
    
    func sendNotebookJSON(named name: String) async {
        // Your existing implementation
        debugLog("Sending notebook to server: \(name)")
        // ... rest of your existing implementation
    }
    
    func debugLog(_ message: String) {
        if debugMode {
            print("[DEBUG]: \(message)")
        }
    }
}

// MARK: - Supporting Views

struct LocalNotebookRow: View {
    let notebook: NotebookFile
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(notebook.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(notebook.formattedSize)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(notebook.modifiedDate, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Data Models

struct NotebookMetadata {
    let windowCount: Int
    let createdDate: Date
}
