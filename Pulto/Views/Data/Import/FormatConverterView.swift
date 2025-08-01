//
//  FormatConverterView.swift
//  Pulto3
//
//  Created by AI Assistant on 1/29/25.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Format Converter View

struct FormatConverterView: View {
    @StateObject private var converter = FormatConverter.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: FormatConverter.ConversionCategory = .data
    @State private var selectedConversion: FormatConverter.ConversionType?
    @State private var inputFile: URL?
    @State private var showingFilePicker = false
    @State private var showingOutputPicker = false
    @State private var convertedFile: URL?
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    if converter.isConverting {
                        conversionProgressSection
                    } else {
                        conversionSetupSection
                    }
                    
                    if !converter.conversionHistory.isEmpty {
                        conversionHistorySection
                    }
                }
                .padding()
            }
            .navigationTitle("Format Converter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Clear History") {
                            converter.conversionHistory.removeAll()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: allowedInputTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .fileExporter(
                isPresented: $showingOutputPicker,
                document: convertedFile.map { ConvertedFileDocument(url: $0) },
                contentType: outputContentType,
                defaultFilename: defaultOutputFilename
            ) { result in
                handleExportResult(result)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let file = convertedFile {
                    ShareSheet(items: [file])
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.purple.gradient)
            
            VStack(spacing: 8) {
                Text("Format Converter")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Convert between different file formats with ease")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Conversion Setup Section
    
    private var conversionSetupSection: some View {
        VStack(spacing: 20) {
            categorySelector
            conversionTypeSelector
            inputFileSection
            
            if inputFile != nil && selectedConversion != nil {
                convertButton
            }
        }
    }
    
    private var categorySelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversion Category")
                .font(.headline)
            
            Picker("Category", selection: $selectedCategory) {
                ForEach(FormatConverter.ConversionCategory.allCases, id: \.self) { category in
                    Label(category.rawValue, systemImage: category.icon)
                        .tag(category)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedCategory) { _, _ in
                selectedConversion = nil
                inputFile = nil
            }
        }
    }
    
    private var conversionTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversion Type")
                .font(.headline)
            
            let conversions = FormatConverter.ConversionType.allCases.filter { 
                $0.category == selectedCategory 
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(conversions, id: \.self) { conversion in
                    ConversionTypeCard(
                        conversion: conversion,
                        isSelected: selectedConversion == conversion
                    ) {
                        selectedConversion = conversion
                        inputFile = nil
                    }
                }
            }
        }
    }
    
    private var inputFileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Input File")
                .font(.headline)
            
            if let inputFile = inputFile {
                selectedFileCard(inputFile)
            } else {
                selectFileButton
            }
        }
    }
    
    private var selectFileButton: some View {
        Button(action: { showingFilePicker = true }) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                .frame(height: 80)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        Text("Select \(selectedConversion?.inputFormat ?? "File")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(selectedConversion == nil)
    }
    
    private func selectedFileCard(_ url: URL) -> some View {
        HStack {
            Image(systemName: iconForFile(url))
                .font(.title2)
                .foregroundStyle(colorForFile(url))
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(url.pathExtension.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Change") {
                showingFilePicker = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var convertButton: some View {
        Button(action: startConversion) {
            Label("Convert to \(selectedConversion?.outputFormat ?? "")", 
                  systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
    
    // MARK: - Conversion Progress Section
    
    private var conversionProgressSection: some View {
        VStack(spacing: 20) {
            Text("Converting File...")
                .font(.title2)
                .fontWeight(.semibold)
            
            ConversionProgressView(progress: converter.conversionProgress)
            
            Button("Cancel") {
                // TODO: Implement cancellation
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.red)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Conversion History Section
    
    private var conversionHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Conversion History")
                .font(.headline)
            
            LazyVStack(spacing: 12) {
                ForEach(converter.conversionHistory.reversed()) { session in
                    ConversionSessionCard(
                        session: session,
                        onShare: { shareFile(session.outputURL) },
                        onExport: { exportFile(session.outputURL) }
                    )
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            inputFile = urls.first
        case .failure(let error):
            print("File selection failed: \(error)")
        }
    }
    
    private func startConversion() {
        guard let inputFile = inputFile,
              let conversionType = selectedConversion else { return }
        
        Task {
            do {
                let outputURL = try await converter.convertFile(
                    inputURL: inputFile,
                    conversionType: conversionType
                )
                
                await MainActor.run {
                    convertedFile = outputURL
                    showingOutputPicker = true
                }
            } catch {
                print("Conversion failed: \(error)")
            }
        }
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("File exported to: \(url)")
        case .failure(let error):
            print("Export failed: \(error)")
        }
        convertedFile = nil
    }
    
    private func shareFile(_ url: URL?) {
        guard let url = url else { return }
        convertedFile = url
        showingShareSheet = true
    }
    
    private func exportFile(_ url: URL?) {
        guard let url = url else { return }
        convertedFile = url
        showingOutputPicker = true
    }
    
    // MARK: - Helper Properties
    
    private var allowedInputTypes: [UTType] {
        guard let conversion = selectedConversion else { return [.data] }
        
        switch conversion.inputFormat {
        case "CSV": return [.commaSeparatedText]
        case "JSON": return [.json]
        case "TSV": return [.tabSeparatedText]
        case "OBJ": return [UTType(filenameExtension: "obj")!]
        case "USDZ": return [.usdz]
        case "STL": return [UTType(filenameExtension: "stl")!]
        case "PLY": return [UTType(filenameExtension: "ply")!]
        default: return [.data]
        }
    }
    
    private var outputContentType: UTType {
        guard let conversion = selectedConversion else { return .data }
        
        switch conversion.outputFormat {
        case "CSV": return .commaSeparatedText
        case "JSON": return .json
        case "XLSX": return UTType(filenameExtension: "xlsx")!
        case "OBJ": return UTType(filenameExtension: "obj")!
        case "USDZ": return .usdz
        case "STL": return UTType(filenameExtension: "stl")!
        case "PLY": return UTType(filenameExtension: "ply")!
        default: return .data
        }
    }
    
    private var defaultOutputFilename: String {
        guard let inputFile = inputFile,
              let conversion = selectedConversion else { return "converted_file" }
        
        let baseName = inputFile.deletingPathExtension().lastPathComponent
        return "\(baseName)_converted.\(conversion.outputFormat.lowercased())"
    }
    
    private func iconForFile(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "csv", "tsv": return "tablecells"
        case "json": return "curlybraces"
        case "usdz", "obj", "stl": return "cube"
        case "ply": return "circle.grid.3x3"
        default: return "doc"
        }
    }
    
    private func colorForFile(_ url: URL) -> Color {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "csv", "tsv": return .green
        case "json": return .blue
        case "usdz", "obj", "stl": return .orange
        case "ply": return .purple
        default: return .gray
        }
    }
}

// MARK: - Supporting Views

struct ConversionTypeCard: View {
    let conversion: FormatConverter.ConversionType
    let isSelected: Bool
    let onSelection: () -> Void
    
    var body: some View {
        Button(action: onSelection) {
            VStack(spacing: 8) {
                HStack {
                    Text(conversion.inputFormat)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundStyle(.blue)
                        .cornerRadius(4)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(conversion.outputFormat)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .cornerRadius(4)
                }
                
                Text(conversion.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct ConversionProgressView: View {
    let progress: ConversionProgress
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(progress.description)
                    .font(.headline)
                
                if !progress.currentFile.isEmpty {
                    Text(progress.currentFile)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
        }
    }
}

struct ConversionSessionCard: View {
    @ObservedObject var session: ConversionSession
    let onShare: () -> Void
    let onExport: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.conversionType.description)
                        .font(.headline)
                    
                    Text(session.startedAt.formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                ConversionStatusBadge(status: session.status)
            }
            
            HStack {
                Text(session.inputURL.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                if let outputURL = session.outputURL {
                    Text(outputURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if let duration = session.duration {
                    Text(String(format: "%.1fs", duration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            if session.status.isCompleted && session.outputURL != nil {
                HStack(spacing: 12) {
                    Button(action: onShare) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: onExport) {
                        Label("Export", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ConversionStatusBadge: View {
    let status: ConversionStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
    
    private var statusText: String {
        switch status {
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

// MARK: - File Document Wrapper

struct ConvertedFileDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.data]
    
    let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    init(configuration: FileDocumentReadConfiguration) throws {
        // This won't be used for our export case
        self.url = URL(fileURLWithPath: "")
    }
    
    func fileWrapper(configuration: FileDocumentWriteConfiguration) throws -> FileWrapper {
        return try FileWrapper(url: url)
    }
}

// MARK: - Share Sheet (iOS)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    FormatConverterView()
}