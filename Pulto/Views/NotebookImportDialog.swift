//
//  Enhanced NotebookImportDialog.swift
//  Now scans for existing notebook files automatically
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers


struct NotebookImportDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject var windowManager: WindowTypeManager
    @Environment(\.dismiss) var dismiss
    @State private var availableNotebooks: [NotebookFile] = []
    @State private var selectedNotebook: NotebookFile?
    @State private var isLoadingFiles = true
    @State private var notebookAnalysis: NotebookAnalysis?
    @State private var isAnalyzing = false
    @State private var analysisError: String?
    @State private var clearExistingWindows = false
    @State private var importResult: ImportResult?
    @State private var isImporting = false
    @State private var showingFilePicker = false
    @State private var fileLoadError: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerView

                if isLoadingFiles {
                    loadingView
                } else if !availableNotebooks.isEmpty || selectedNotebook != nil {
                    if selectedNotebook == nil {
                        notebookListView
                    } else {
                        selectedNotebookView

                        if let analysis = notebookAnalysis {
                            analysisView(analysis)
                            importOptionsView
                            importActionsView
                        } else if let error = analysisError {
                            errorView(error)
                        } else if isAnalyzing {
                            ProgressView("Analyzing notebook...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                } else {
                    emptyStateView
                }

                if let result = importResult {
                    importResultView(result)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Import Notebook")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        //isPresented = false
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Browse Files") {
                        showingFilePicker = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.init(filenameExtension: "ipynb") ?? .json],
            allowsMultipleSelection: false
        ) { result in
            handleExternalFileSelection(result)
        }
        .onAppear {
            loadAvailableNotebooks()
        }
    }

    // MARK: - View Components

    private var headerView: some View {
        VStack(spacing: 8) {
            //Image(systemName: "square.and.arrow.down.on.square")
            //    .font(.system(size: 50))
            //    .foregroundStyle(.blue)
        }
        .padding(.top)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Scanning for notebook files...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notebookListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Available Notebooks", systemImage: "doc.text")
                    .font(.headline)

                Spacer()

                Button("Refresh") {
                    loadAvailableNotebooks()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let error = fileLoadError {
                Text("Error loading files: \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.bottom, 8)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(availableNotebooks) { notebook in
                        notebookRowView(notebook)
                    }
                }
            }
            .frame(maxHeight: 400)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func notebookRowView(_ notebook: NotebookFile) -> some View {
        Button(action: {
            selectNotebook(notebook)
        }) {
            HStack(spacing: 12) {
                // File icon
                Image(systemName: "doc.text")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(notebook.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        Label(notebook.formattedSize, systemImage: "doc")
                            .font(.caption)

                        Label(notebook.formattedModifiedDate, systemImage: "clock")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Quick preview info
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var selectedNotebookView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Selected Notebook", systemImage: "doc.text")
                    .font(.headline)

                Spacer()

                Button("Change") {
                    selectedNotebook = nil
                    notebookAnalysis = nil
                    analysisError = nil
                    importResult = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let notebook = selectedNotebook {
                VStack(alignment: .leading, spacing: 8) {
                    Text(notebook.name)
                        .font(.title3)
                        .fontWeight(.semibold)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Size")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(notebook.formattedSize)
                                .font(.body)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Modified")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(notebook.formattedModifiedDate)
                                .font(.body)
                        }

                        Spacer()
                    }

                    Text(notebook.url.path)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                .padding()
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Notebook Files Found")
                    .font(.headline)

                Text("No .ipynb files were found in your Documents folder. Export a notebook first or browse for files from another location.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button("Browse for Files") {
                    showingFilePicker = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Refresh") {
                    loadAvailableNotebooks()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
    }

    private func analysisView(_ analysis: NotebookAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notebook Analysis", systemImage: "chart.bar.doc.horizontal")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Total Cells:")
                    Spacer()
                    Text("\(analysis.totalCells)")
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Window Cells:")
                    Spacer()
                    Text("\(analysis.windowCells)")
                        .fontWeight(.medium)
                        .foregroundStyle(analysis.windowCells > 0 ? .green : .orange)
                }

                if !analysis.windowTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Window Types:")
                            .fontWeight(.medium)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(analysis.windowTypes, id: \.self) { type in
                                    Text(type)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.blue.opacity(0.1))
                                        .clipShape(Capsule())
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }

                if let metadata = analysis.metadata {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Export Info:")
                            .fontWeight(.medium)

                        Text("Exported: \(formatDate(metadata.export_date))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Original Windows: \(metadata.total_windows)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var importOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Import Options", systemImage: "gearshape")
                .font(.headline)

            Toggle("Clear existing windows before import", isOn: $clearExistingWindows)
                .toggleStyle(SwitchToggleStyle())

            if clearExistingWindows {
                Text("⚠️ This will remove all current windows before importing")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.leading, 20)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var importActionsView: some View {
        HStack(spacing: 12) {
            Button("Cancel Import") {
                selectedNotebook = nil
                notebookAnalysis = nil
                importResult = nil
            }
            .buttonStyle(.bordered)
            .disabled(isImporting)

            Spacer()

            Button("Import Windows") {
                performImport()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isImporting || notebookAnalysis?.windowCells == 0)
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Analysis Failed")
                .font(.headline)

            Text(error)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                analyzeSelectedNotebook()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func importResultView(_ result: ImportResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.isSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result.isSuccessful ? .green : .red)

                Text("Import Result")
                    .font(.headline)
            }

            Text(result.summary)
                .font(.body)

            if !result.errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Errors:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(Array(result.errors.enumerated()), id: \.offset) { index, error in
                        Text("• \(error.localizedDescription)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            if result.isSuccessful {
                HStack {
                    Button("Done") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
            }
        }
        .padding()
        .background(result.isSuccessful ? .green.opacity(0.1) : .red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helper Methods

    private func loadAvailableNotebooks() {
        isLoadingFiles = true
        fileLoadError = nil

        Task {
            do {
                let notebooks = try await scanForNotebookFiles()

                await MainActor.run {
                    self.availableNotebooks = notebooks.sorted { $0.modifiedDate > $1.modifiedDate }
                    self.isLoadingFiles = false
                }
            } catch {
                await MainActor.run {
                    self.fileLoadError = error.localizedDescription
                    self.availableNotebooks = []
                    self.isLoadingFiles = false
                }
            }
        }
    }

    private func scanForNotebookFiles() async throws -> [NotebookFile] {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ImportError.fileReadError
        }

        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .nameKey]

        guard let enumerator = fileManager.enumerator(
            at: documentsDirectory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
            errorHandler: nil
        ) else {
            return []
        }

        var notebooks: [NotebookFile] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "ipynb" else { continue }

            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))

                let notebook = NotebookFile(
                    url: fileURL,
                    name: resourceValues.name ?? fileURL.lastPathComponent,
                    size: Int64(resourceValues.fileSize ?? 0),
                    createdDate: resourceValues.creationDate ?? Date(),
                    modifiedDate: resourceValues.contentModificationDate ?? Date()
                )

                notebooks.append(notebook)
            } catch {
                print("Error reading file attributes for \(fileURL): \(error)")
            }
        }

        return notebooks
    }

    private func selectNotebook(_ notebook: NotebookFile) {
        selectedNotebook = notebook
        analyzeSelectedNotebook()
    }

    private func analyzeSelectedNotebook() {
        guard let notebook = selectedNotebook else { return }

        isAnalyzing = true
        analysisError = nil

        let manager = windowManager

        Task {
            do {
                let analysis = try manager.analyzeGenericNotebook(fileURL: notebook.url)

                await MainActor.run {
                    self.notebookAnalysis = analysis
                    self.isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    self.analysisError = error.localizedDescription
                    self.isAnalyzing = false
                }
            }
        }
    }

    private func handleExternalFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Create a NotebookFile from the external file
            do {
                let resourceValues = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .nameKey])

                let notebook = NotebookFile(
                    url: url,
                    name: resourceValues.name ?? url.lastPathComponent,
                    size: Int64(resourceValues.fileSize ?? 0),
                    createdDate: resourceValues.creationDate ?? Date(),
                    modifiedDate: resourceValues.contentModificationDate ?? Date()
                )

                selectNotebook(notebook)
            } catch {
                analysisError = "Failed to read file information: \(error.localizedDescription)"
            }

        case .failure(let error):
            analysisError = error.localizedDescription
        }
    }

    private func performImport() {
        guard let notebook = selectedNotebook else { return }

        isImporting = true

        let manager = windowManager
        let shouldClearWindows = clearExistingWindows

        Task {
            do {
                if shouldClearWindows {
                    await MainActor.run {
                        manager.clearAllWindows()
                    }
                }

                let result = try manager.importFromGenericNotebook(fileURL: notebook.url)

                await MainActor.run {
                    self.importResult = result
                    self.isImporting = false
                }
            } catch {
                await MainActor.run {
                    self.importResult = ImportResult(
                        restoredWindows: [],
                        errors: [ImportError.fileReadError],
                        originalMetadata: nil,
                        idMapping: [:]
                    )
                    self.isImporting = false
                }
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}
