//
//  BatchImportView.swift
//  Pulto3
//
//  Created by AI Assistant on 1/29/25.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Batch Import View

struct BatchImportView: View {
    @StateObject private var batchManager = BatchImportManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    
    @State private var showingFilePicker = false
    @State private var selectedFiles: [URL] = []
    @State private var isDragOver = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    if batchManager.isImporting {
                        importProgressSection
                    } else if selectedFiles.isEmpty {
                        dropZoneSection
                    } else {
                        fileListSection
                        importActionsSection
                    }
                    
                    if !batchManager.importHistory.isEmpty {
                        importHistorySection
                    }
                }
                .padding()
            }
            .navigationTitle("Batch Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Import Single File") { showingFilePicker = true }
                        Button("Clear Selection") { selectedFiles.removeAll() }
                        if !batchManager.importHistory.isEmpty {
                            Button("Clear History") { batchManager.importHistory.removeAll() }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: supportedContentTypes,
                allowsMultipleSelection: true
            ) { result in
                handleFileSelection(result)
            }
            .onDrop(of: supportedContentTypes, isTargeted: $isDragOver) { providers in
                handleDrop(providers: providers)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)
            
            VStack(spacing: 8) {
                Text("Batch File Import")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Import multiple files simultaneously with automatic window arrangement")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Drop Zone Section
    
    private var dropZoneSection: some View {
        VStack(spacing: 20) {
            dropZone
            supportedFormatsGrid
        }
    }
    
    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(isDragOver ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            .stroke(
                isDragOver ? Color.blue : Color.gray.opacity(0.3),
                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
            )
            .frame(height: 200)
            .overlay {
                VStack(spacing: 16) {
                    Image(systemName: isDragOver ? "arrow.down.circle.fill" : "plus.circle.dashed")
                        .font(.system(size: 48))
                        .foregroundStyle(isDragOver ? .blue : .gray)
                    
                    VStack(spacing: 4) {
                        Text(isDragOver ? "Drop files here" : "Drag files here")
                            .font(.headline)
                            .foregroundStyle(isDragOver ? .blue : .primary)
                        
                        Text("or click to browse")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingFilePicker = true
            }
    }
    
    private var supportedFormatsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            FormatSupportCard(
                title: "Data Files",
                formats: ["CSV", "TSV", "JSON"],
                icon: "tablecells",
                color: .green
            )
            
            FormatSupportCard(
                title: "3D Models",
                formats: ["USDZ", "OBJ", "STL"],
                icon: "cube",
                color: .orange
            )
            
            FormatSupportCard(
                title: "Point Clouds",
                formats: ["PLY", "PCD", "XYZ"],
                icon: "circle.grid.3x3",
                color: .purple
            )
            
            FormatSupportCard(
                title: "Notebooks",
                formats: ["IPYNB"],
                icon: "text.book.closed",
                color: .blue
            )
        }
    }
    
    // MARK: - File List Section
    
    private var fileListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Selected Files (\(selectedFiles.count))")
                    .font(.headline)
                
                Spacer()
                
                Button("Clear All") {
                    selectedFiles.removeAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(Array(selectedFiles.enumerated()), id: \.offset) { index, url in
                    FilePreviewCard(
                        url: url,
                        onRemove: { selectedFiles.remove(at: index) }
                    )
                }
            }
        }
    }
    
    // MARK: - Import Actions Section
    
    private var importActionsSection: some View {
        VStack(spacing: 12) {
            Button(action: startBatchImport) {
                Label("Import All Files", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedFiles.isEmpty)
            
            HStack(spacing: 16) {
                Button("Add More Files") {
                    showingFilePicker = true
                }
                .buttonStyle(.bordered)
                
                Button("Preview Files") {
                    // TODO: Implement file preview
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // MARK: - Import Progress Section
    
    private var importProgressSection: some View {
        VStack(spacing: 20) {
            Text("Importing Files...")
                .font(.title2)
                .fontWeight(.semibold)
            
            ImportProgressView(progress: batchManager.importProgress)
            
            Button("Cancel Import") {
                // TODO: Implement cancellation
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.red)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Import History Section
    
    private var importHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Imports")
                .font(.headline)
            
            LazyVStack(spacing: 12) {
                ForEach(batchManager.importHistory.reversed()) { session in
                    ImportSessionCard(
                        session: session,
                        onOpenWindows: { openWindowsForSession(session) }
                    )
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedFiles.append(contentsOf: urls)
        case .failure(let error):
            print("File selection failed: \(error)")
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var newURLs: [URL] = []
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                defer { group.leave() }
                if let url = url, error == nil {
                    newURLs.append(url)
                }
            }
        }
        
        group.notify(queue: .main) {
            selectedFiles.append(contentsOf: newURLs)
        }
        
        return true
    }
    
    private func startBatchImport() {
        Task {
            await batchManager.startBatchImport(files: selectedFiles)
            selectedFiles.removeAll()
        }
    }
    
    private func openWindowsForSession(_ session: BatchImportSession) {
        for windowID in session.createdWindows {
            if let window = WindowTypeManager.shared.getWindow(for: windowID) {
                switch window.windowType {
                case .charts:
                    openWindow(value: windowID)
                case .column:
                    openWindow(value: windowID)
                case .pointcloud:
                    openWindow(id: "volumetric-pointcloud", value: windowID)
                case .model3d:
                    openWindow(id: "volumetric-model3d", value: windowID)
                default:
                    openWindow(value: windowID)
                }
            }
        }
    }
    
    // MARK: - Supported Content Types
    
    private var supportedContentTypes: [UTType] {
        [
            .commaSeparatedText,    // CSV
            .tabSeparatedText,      // TSV
            .json,                  // JSON
            .usdz,                  // USDZ models
            UTType(filenameExtension: "obj")!,  // OBJ models
            UTType(filenameExtension: "stl")!,  // STL models
            UTType(filenameExtension: "ply")!,  // PLY point clouds
            UTType(filenameExtension: "pcd")!,  // PCD point clouds
            UTType(filenameExtension: "xyz")!,  // XYZ point clouds
            UTType(filenameExtension: "ipynb")!, // Jupyter notebooks
            .plainText,             // Fallback
            .data                   // Ultimate fallback
        ]
    }
}

// MARK: - Supporting Views

struct FormatSupportCard: View {
    let title: String
    let formats: [String]
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            Text(formats.joined(separator: " • "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct FilePreviewCard: View {
    let url: URL
    let onRemove: () -> Void
    
    @State private var fileSize: String = ""
    @State private var fileType: String = ""
    
    var body: some View {
        HStack {
            Image(systemName: iconForFile(url))
                .font(.title2)
                .foregroundStyle(colorForFile(url))
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Text(fileType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if !fileSize.isEmpty {
                        Text(fileSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .onAppear {
            loadFileInfo()
        }
    }
    
    private func loadFileInfo() {
        fileType = url.pathExtension.uppercased()
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? Int64 {
                fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        } catch {
            fileSize = "Unknown"
        }
    }
    
    private func iconForFile(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "csv", "tsv": return "tablecells"
        case "json": return "curlybraces"
        case "usdz", "obj", "stl": return "cube"
        case "ply", "pcd", "xyz": return "circle.grid.3x3"
        case "ipynb": return "text.book.closed"
        default: return "doc"
        }
    }
    
    private func colorForFile(_ url: URL) -> Color {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "csv", "tsv": return .green
        case "json": return .blue
        case "usdz", "obj", "stl": return .orange
        case "ply", "pcd", "xyz": return .purple
        case "ipynb": return .red
        default: return .gray
        }
    }
}

struct ImportProgressView: View {
    let progress: BatchImportProgress
    
    var body: some View {
        VStack(spacing: 16) {
            // Overall progress
            VStack(spacing: 8) {
                HStack {
                    Text("Overall Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(progress.completedFiles)/\(progress.totalFiles)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                ProgressView(value: progress.progressPercentage)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(.blue)
            }
            
            // Current file status
            if !progress.currentFileName.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("Current File")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(progress.currentFileStatus.description)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(0.2))
                            .foregroundStyle(statusColor)
                            .cornerRadius(8)
                    }
                    
                    Text(progress.currentFileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Success/failure stats
            HStack(spacing: 24) {
                StatView(
                    title: "Success",
                    value: progress.successCount,
                    color: .green
                )
                
                StatView(
                    title: "Failed",
                    value: progress.failureCount,
                    color: .red
                )
            }
        }
    }
    
    private var statusColor: Color {
        switch progress.currentFileStatus {
        case .pending: return .gray
        case .analyzing: return .blue
        case .importing: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}

struct StatView: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ImportSessionCard: View {
    @ObservedObject var session: BatchImportSession
    let onOpenWindows: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Batch Import")
                        .font(.headline)
                    
                    if let startTime = session.startedAt {
                        Text(startTime.formatted())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                StatusBadge(status: session.status)
            }
            
            HStack(spacing: 20) {
                StatView(
                    title: "Files",
                    value: session.files.count,
                    color: .blue
                )
                
                StatView(
                    title: "Success",
                    value: session.successfulImports.count,
                    color: .green
                )
                
                StatView(
                    title: "Failed",
                    value: session.failedImports.count,
                    color: .red
                )
                
                if let duration = session.duration {
                    VStack(spacing: 4) {
                        Text(String(format: "%.1fs", duration))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                        
                        Text("Duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if !session.createdWindows.isEmpty {
                Button(action: onOpenWindows) {
                    Label("Open Windows (\(session.createdWindows.count))", systemImage: "rectangle.on.rectangle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct StatusBadge: View {
    let status: BatchSessionStatus
    
    var body: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return .gray
        case .processing: return .blue
        case .completed: return .green
        case .cancelled: return .orange
        }
    }
    
    private var statusText: String {
        switch status {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

#Preview {
    BatchImportView()
}