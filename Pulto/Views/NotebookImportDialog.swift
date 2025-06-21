//
//  Enhanced NotebookImportDialog.swift
//  Fixed window restoration and UI sizing issues
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct NotebookImportDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject var windowManager: WindowTypeManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.openWindow) private var openWindow  // Add this to open windows

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
            ScrollView {  // Add ScrollView for better content management
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

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Import Notebook")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
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
        .frame(minWidth: 600, minHeight: 500)  // Set minimum window size
        .frame(idealWidth: 700, idealHeight: 600)  // Set ideal window size
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "ipynb") ?? .json],
            allowsMultipleSelection: false
        ) { result in
            handleExternalFileSelection(result)
        }
        .onAppear {
            scanForNotebooks()
        }
    }

    // MARK: - View Components

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Import Jupyter Notebook", systemImage: "doc.badge.arrow.up")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Import windows from a Jupyter notebook with VisionOS export data")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning for notebook files...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: 200)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.quaternary)

            Text("No Notebooks Found")
                .font(.headline)

            Text("Browse for a notebook file or place notebooks in the Documents folder")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Browse Files") {
                showingFilePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: 200)
    }

    private var notebookListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Available Notebooks", systemImage: "folder")
                .font(.headline)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(availableNotebooks) { notebook in
                        notebookRow(notebook)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
    }

    private func notebookRow(_ notebook: NotebookFile) -> some View {
        Button(action: { selectNotebook(notebook) }) {
            HStack {
                Image(systemName: "doc.text")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(notebook.name)
                        .fontWeight(.medium)

                    HStack {
                        Text(notebook.formattedSize)
                        Text("•")
                        Text(notebook.formattedModifiedDate)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(uiColor: .systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var selectedNotebookView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: {
                    selectedNotebook = nil
                    notebookAnalysis = nil
                    importResult = nil
                }) {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()
            }

            if let notebook = selectedNotebook {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading) {
                        Text(notebook.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        HStack {
                            Text(notebook.formattedSize)
                            Text("•")
                            Text(notebook.formattedModifiedDate)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color(uiColor: .systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func analysisView(_ analysis: NotebookAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Analysis Results", systemImage: "magnifyingglass")
                .font(.headline)

            HStack {
                StatBox(
                    title: "Total Cells",
                    value: "\(analysis.totalCells)",
                    icon: "square.grid.3x3"
                )

                StatBox(
                    title: "Window Cells",
                    value: "\(analysis.windowCells)",
                    icon: "macwindow",
                    highlight: analysis.windowCells > 0
                )
            }

            if !analysis.windowTypes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Window Types:")
                        .fontWeight(.medium)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(analysis.windowTypes, id: \.self) { type in
                                Text(type)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
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
                    .font(.title)

                VStack(alignment: .leading) {
                    Text(result.isSuccessful ? "Import Successful" : "Import Failed")
                        .font(.headline)

                    Text(result.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if !result.errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Errors:")
                        .fontWeight(.medium)

                    ForEach(Array(result.errors.enumerated()), id: \.offset) { _, error in
                        Label(error.localizedDescription, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            HStack {
                if result.isSuccessful {
                    Button("Import Another") {
                        selectedNotebook = nil
                        importResult = nil
                        notebookAnalysis = nil
                    }
                    .buttonStyle(.bordered)
                }

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(result.isSuccessful ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helper Methods

    private func scanForNotebooks() {
        isLoadingFiles = true
        availableNotebooks = []

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            isLoadingFiles = false
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let notebooks = self.findNotebooksInDirectory(documentsDirectory)

            DispatchQueue.main.async {
                self.availableNotebooks = notebooks
                self.isLoadingFiles = false
            }
        }
    }

    private func findNotebooksInDirectory(_ directory: URL) -> [NotebookFile] {
        var notebooks: [NotebookFile] = []

        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey, .fileSizeKey]) else {
            return notebooks
        }

        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension.lowercased() == "ipynb" else { continue }

            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .nameKey])

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

                // Open each restored window visually
                await MainActor.run {
                    for window in result.restoredWindows {
                        openWindow(value: window.id)
                    }

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

    // MARK: - Supporting Views

    struct StatBox: View {
        let title: String
        let value: String
        let icon: String
        var highlight: Bool = false

        var body: some View {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(highlight ? .blue : .secondary)

                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(highlight ? .primary : .secondary)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(uiColor: .systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
