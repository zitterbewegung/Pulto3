//
//  Enhanced NotebookImportDialog.swift
//  Fixed window restoration and UI sizing issues
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

// MARK: - NotebookCell Model
struct NotebookCell: Identifiable {
    let id = UUID()
    let cellType: String
    let source: [String]
    let outputs: [[String: Any]]?
    let metadata: [String: Any]?
    let executionCount: Int?
    
    var sourceText: String {
        source.joined(separator: "\n")
    }
    
    var isWindowCell: Bool {
        metadata?["window_type"] != nil
    }
    
    var windowType: String? {
        metadata?["window_type"] as? String
    }
    
    var cellIndex: Int {
        metadata?["cell_index"] as? Int ?? 0
    }
}

struct NotebookImportDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject var windowManager: WindowTypeManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.openWindow) private var openWindow  // Add this to open windows

    @State private var availableNotebooks: [NotebookFile] = []
    @State private var selectedNotebook: NotebookFile?
    @State private var isLoadingFiles = true
    @State private var notebookAnalysis: NotebookAnalysis?
    @State private var notebookCells: [NotebookCell] = []
    @State private var isAnalyzing = false
    @State private var isLoadingCells = false
    @State private var analysisError: String?
    @State private var clearExistingWindows = false
    @State private var importResult: ImportResult?
    @State private var isImporting = false
    @State private var showingFilePicker = false
    @State private var fileLoadError: String?
    @State private var selectedCellId: UUID?

    @StateObject private var jupyterClient = JupyterAPIClient()
    @State private var showJupyterConnection = false
    @State private var jupyterServerURL = ""
    @State private var jupyterToken = ""
    @State private var jupyterServerName = ""
    @State private var selectedJupyterNotebook: JupyterNotebook?
    @State private var importMode: ImportMode = .localFiles

    enum ImportMode {
        case localFiles
        case jupyterServer
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom navigation bar
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Text("Import Notebook")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Menu {
                    Button("Browse Local Files") {
                        showingFilePicker = true
                    }
                    
                    Button("Connect to Jupyter Server") {
                        showJupyterConnection = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Source")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // Import mode selector
            Picker("Import Mode", selection: $importMode) {
                Text("Local Files").tag(ImportMode.localFiles)
                Text("Jupyter Server").tag(ImportMode.jupyterServer)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom)
            
            // Main content
            ScrollView {
                VStack(spacing: 20) {
                    headerView

                    if importMode == .localFiles {
                        localFilesContent
                    } else {
                        jupyterServerContent
                    }

                    if let result = importResult {
                        importResultView(result)
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "ipynb") ?? .json],
            allowsMultipleSelection: false
        ) { result in
            handleExternalFileSelection(result)
        }
        .sheet(isPresented: $showJupyterConnection) {
            JupyterConnectionView(
                isPresented: $showJupyterConnection,
                serverURL: $jupyterServerURL,
                token: $jupyterToken,
                serverName: $jupyterServerName,
                onConnect: { connectToJupyterServer() }
            )
        }
        .onAppear {
            if importMode == .localFiles {
                scanForNotebooks()
            }
        }
        .onChange(of: importMode) { _, newMode in
            if newMode == .localFiles {
                scanForNotebooks()
            } else if newMode == .jupyterServer {
                if jupyterClient.isConnected {
                    loadJupyterNotebooks()
                }
            }
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
                    notebookCells = []
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

    @ViewBuilder
    private var localFilesContent: some View {
        if isLoadingFiles {
            loadingView
        } else if !availableNotebooks.isEmpty || selectedNotebook != nil {
            if selectedNotebook == nil {
                notebookListView
            } else {
                selectedNotebookView

                if let analysis = notebookAnalysis {
                    analysisView(analysis)
                    
                    if !notebookCells.isEmpty {
                        cellsContentView
                    }
                    
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
    }

    @ViewBuilder
    private var jupyterServerContent: some View {
        if !jupyterClient.isConnected {
            jupyterConnectionPrompt
        } else if selectedJupyterNotebook == nil {
            jupyterNotebookListView
        } else {
            selectedJupyterNotebookView
            
            if let analysis = notebookAnalysis {
                analysisView(analysis)
                
                if !notebookCells.isEmpty {
                    cellsContentView
                }
                
                importOptionsView
                jupyterImportActionsView
            } else if let error = analysisError {
                errorView(error)
            } else if isAnalyzing {
                ProgressView("Analyzing notebook...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var jupyterConnectionPrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "server.rack")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            VStack(spacing: 8) {
                Text("Connect to Jupyter Server")
                    .font(.headline)
                
                Text("Connect to a running Jupyter server to import notebooks directly")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let error = jupyterClient.connectionError {
                Text("Connection Error: \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Button("Connect to Server") {
                showJupyterConnection = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var jupyterNotebookListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Jupyter Notebooks", systemImage: "server.rack")
                    .font(.headline)
                
                Spacer()
                
                if jupyterClient.isConnecting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("Refresh") {
                        loadJupyterNotebooks()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if jupyterClient.notebooks.isEmpty && !jupyterClient.isConnecting {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    Text("No notebooks found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("No .ipynb files were found on the server")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(jupyterClient.notebooks, id: \.id) { notebook in
                            jupyterNotebookRow(notebook)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }

    private func jupyterNotebookRow(_ notebook: JupyterNotebook) -> some View {
        Button(action: { selectJupyterNotebook(notebook) }) {
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
                        Text(notebook.formattedLastModified)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    Text(notebook.path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
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

    private var selectedJupyterNotebookView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: {
                    selectedJupyterNotebook = nil
                    notebookAnalysis = nil
                    notebookCells = []
                    importResult = nil
                }) {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()
            }

            if let notebook = selectedJupyterNotebook {
                HStack {
                    Image(systemName: "server.rack")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading) {
                        Text(notebook.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        HStack {
                            Text(notebook.formattedSize)
                            Text("•")
                            Text(notebook.formattedLastModified)
                            Text("•")
                            Text("Remote")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                        Text(notebook.path)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var jupyterImportActionsView: some View {
        HStack(spacing: 12) {
            Button("Cancel Import") {
                selectedJupyterNotebook = nil
                notebookAnalysis = nil
                notebookCells = []
                importResult = nil
            }
            .buttonStyle(.bordered)
            .disabled(isImporting)

            Spacer()

            Button("Import from Server") {
                performJupyterImport()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isImporting || notebookAnalysis?.windowCells == 0)
        }
    }

    // MARK: - Cells Content View
    private var cellsContentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Notebook Cells", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                
                Spacer()
                
                Text("\(notebookCells.count) cells")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Kernel management for remote execution
                if importMode == .jupyterServer && jupyterClient.isConnected {
                    kernelManagementView
                }
            }

            if isLoadingCells {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading cell contents...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(notebookCells) { cell in
                            if importMode == .jupyterServer {
                                CellCardView(
                                    cell: cell,
                                    isSelected: selectedCellId == cell.id,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedCellId = selectedCellId == cell.id ? nil : cell.id
                                        }
                                    },
                                    jupyterClient: jupyterClient
                                )
                            } else {
                                LocalCellCardView(
                                    cell: cell,
                                    isSelected: selectedCellId == cell.id,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedCellId = selectedCellId == cell.id ? nil : cell.id
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(minHeight: 300, maxHeight: .infinity)
                .background(Color(uiColor: .systemGray6).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var kernelManagementView: some View {
        HStack(spacing: 8) {
            if let kernel = jupyterClient.activeKernel {
                Text("Kernel: \(kernel.name)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .clipShape(Capsule())
                
                Button("Stop") {
                    Task {
                        try? await jupyterClient.stopKernel(kernel)
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            } else {
                if jupyterClient.isStartingKernel {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Starting...")
                            .font(.caption)
                    }
                } else {
                    Button("Start Kernel") {
                        Task {
                            try? await jupyterClient.startKernel()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
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
                notebookCells = []
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
                        notebookCells = []
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
                
                // Also load the cell contents
                let cells = try await loadNotebookCells(from: notebook.url)

                await MainActor.run {
                    self.notebookAnalysis = analysis
                    self.notebookCells = cells
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
    
    private func loadNotebookCells(from url: URL) async throws -> [NotebookCell] {
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NSError(domain: "NotebookImportDialog", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
        }
        
        guard let cellsArray = json["cells"] as? [[String: Any]] else {
            throw NSError(domain: "NotebookImportDialog", code: 2, userInfo: [NSLocalizedDescriptionKey: "No cells found in notebook"])
        }
        
        var cells: [NotebookCell] = []
        
        for (index, cellDict) in cellsArray.enumerated() {
            let cellType = cellDict["cell_type"] as? String ?? "unknown"
            let source = cellDict["source"] as? [String] ?? []
            let outputs = cellDict["outputs"] as? [[String: Any]]
            let metadata = cellDict["metadata"] as? [String: Any]
            let executionCount = cellDict["execution_count"] as? Int
            
            // Add cell index to metadata if not present
            var enrichedMetadata = metadata ?? [:]
            enrichedMetadata["cell_index"] = index
            
            let cell = NotebookCell(
                cellType: cellType,
                source: source,
                outputs: outputs,
                metadata: enrichedMetadata,
                executionCount: executionCount
            )
            
            cells.append(cell)
        }
        
        return cells
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

    // MARK: - Jupyter Helper Methods
    
    private func connectToJupyterServer() {
        guard !jupyterServerURL.isEmpty else { return }
        
        let config = JupyterServerConfig(
            baseURL: jupyterServerURL,
            token: jupyterToken.isEmpty ? nil : jupyterToken,
            name: jupyterServerName.isEmpty ? jupyterServerURL : jupyterServerName
        )
        
        Task {
            await jupyterClient.connect(to: config)
            if jupyterClient.isConnected {
                await loadJupyterNotebooks()
                await MainActor.run {
                    importMode = .jupyterServer
                    showJupyterConnection = false
                }
            }
        }
    }
    
    private func loadJupyterNotebooks() {
        Task {
            do {
                _ = try await jupyterClient.listNotebooks()
            } catch {
                await MainActor.run {
                    analysisError = "Failed to load notebooks: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func selectJupyterNotebook(_ notebook: JupyterNotebook) {
        selectedJupyterNotebook = notebook
        analyzeJupyterNotebook(notebook)
    }
    
    private func analyzeJupyterNotebook(_ notebook: JupyterNotebook) {
        isAnalyzing = true
        analysisError = nil
        
        Task {
            do {
                // Fetch the full notebook content
                let fullNotebook = try await jupyterClient.fetchNotebook(at: notebook.path)
                
                // Convert to NotebookFile format for analysis
                if let notebookFile = jupyterClient.convertToNotebookFile(fullNotebook) {
                    let analysis = try windowManager.analyzeGenericNotebook(fileURL: notebookFile.url)
                    let cells = try await loadNotebookCells(from: notebookFile.url)
                    
                    await MainActor.run {
                        self.notebookAnalysis = analysis
                        self.notebookCells = cells
                        self.isAnalyzing = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.analysisError = error.localizedDescription
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    private func performJupyterImport() {
        guard let notebook = selectedJupyterNotebook else { return }

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

                // Convert Jupyter notebook to local file for import
                if let notebookFile = jupyterClient.convertToNotebookFile(notebook) {
                    let result = try manager.importFromGenericNotebook(fileURL: notebookFile.url)

                    // Open each restored window visually
                    await MainActor.run {
                        for window in result.restoredWindows {
                            openWindow(value: window.id)
                        }

                        self.importResult = result
                        self.isImporting = false
                    }
                } else {
                    throw ImportError.fileReadError
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

// MARK: - Cell Card View
struct CellCardView: View {
    let cell: NotebookCell
    let isSelected: Bool
    let onTap: () -> Void
    
    // Remote execution support
    @ObservedObject var jupyterClient: JupyterAPIClient
    @State private var isEditing = false
    @State private var editedSource: String = ""
    
    var executionSession: RemoteExecutionSession? {
        jupyterClient.executionSessions[cell.id.uuidString]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cell header with execution controls
            HStack {
                cellTypeIcon
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(cellTypeDisplayName)
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        if cell.isWindowCell {
                            Text("WINDOW")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        
                        if cell.cellType.lowercased() == "code" && jupyterClient.isConnected {
                            Text("REMOTE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("Cell \(cell.cellIndex + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let executionCount = cell.executionCount {
                            Text("• Execution: \(executionCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let session = executionSession {
                            if session.isExecuting {
                                Text("• Executing...")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            } else if session.executionCount > 0 {
                                Text("• Remote: \(session.executionCount)")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                        
                        if let windowType = cell.windowType {
                            Text("• Type: \(windowType)")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                Spacer()
                
                // Remote execution controls
                if cell.cellType.lowercased() == "code" && jupyterClient.isConnected {
                    HStack(spacing: 8) {
                        if let session = executionSession, session.isExecuting {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Button(action: { executeRemotely() }) {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.plain)
                            .disabled(jupyterClient.activeKernel == nil)
                        }
                        
                        Button(action: { toggleEditing() }) {
                            Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Button(action: onTap) {
                    Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Cell content with editing support
            if !cell.sourceText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    if isEditing && cell.cellType.lowercased() == "code" {
                        // Editable text area for remote editing
                        TextEditor(text: $editedSource)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 100, maxHeight: 200)
                            .padding(8)
                            .background(Color(uiColor: .systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onAppear {
                                editedSource = cell.sourceText
                            }
                    } else if isSelected {
                        // Full content (read-only view)
                        ScrollView {
                            Text(cell.sourceText)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color(uiColor: .systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .frame(maxHeight: 200)
                    } else {
                        // Preview (first few lines)
                        let previewText = cell.sourceText.components(separatedBy: .newlines).prefix(3).joined(separator: "\n")
                        Text(previewText + (cell.sourceText.components(separatedBy: .newlines).count > 3 ? "\n..." : ""))
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(uiColor: .systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            
            // Show remote execution outputs
            if let session = executionSession, !session.outputs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Remote Outputs:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    ForEach(Array(session.outputs.enumerated()), id: \.offset) { index, output in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(output.outputType)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .clipShape(Capsule())
                                
                                if let executionCount = output.executionCount {
                                    Text("[\(executionCount)]")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            if let text = output.text {
                                Text(text.joined(separator: "\n"))
                                    .font(.system(.caption2, design: .monospaced))
                                    .padding(6)
                                    .background(Color.green.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
            }
            
            // Show remote execution error
            if let session = executionSession, let error = session.error {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Execution Error:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                    
                    Text(error)
                        .font(.system(.caption2, design: .monospaced))
                        .padding(6)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            
            // Show original outputs if selected and available (for imported notebooks)
            if isSelected, let outputs = cell.outputs, !outputs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Original Outputs:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    ForEach(Array(outputs.enumerated()), id: \.offset) { index, output in
                        if let outputType = output["output_type"] as? String {
                            HStack {
                                Text("\(index + 1). \(outputType)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.2))
                                    .clipShape(Capsule())
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(cell.isWindowCell ? Color.blue.opacity(0.05) : Color(uiColor: .secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(cell.isWindowCell ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            onTap()
        }
    }
    
    private func executeRemotely() {
        guard let kernel = jupyterClient.activeKernel else { return }
        
        Task {
            do {
                // Convert NotebookCell to JupyterCell for execution
                let jupyterCell = JupyterCell(
                    cellType: cell.cellType,
                    source: isEditing ? editedSource.components(separatedBy: .newlines) : cell.source,
                    metadata: nil,
                    outputs: nil,
                    executionCount: nil
                )
                
                try await jupyterClient.executeCell(jupyterCell, in: kernel)
            } catch {
                print("Remote execution failed: \(error)")
            }
        }
    }
    
    private func toggleEditing() {
        if isEditing {
            // Save changes (you might want to implement saving to remote notebook)
            // For now, just update local source
            isEditing = false
        } else {
            editedSource = cell.sourceText
            isEditing = true
        }
    }
    
    private var cellTypeIcon: some View {
        Image(systemName: cellTypeIconName)
            .font(.title2)
            .foregroundStyle(cellTypeColor)
            .frame(width: 30)
    }
    
    private var cellTypeIconName: String {
        switch cell.cellType.lowercased() {
        case "code":
            return "curlybraces"
        case "markdown":
            return "text.format"
        case "raw":
            return "doc.plaintext"
        default:
            return "questionmark.circle"
        }
    }
    
    private var cellTypeColor: Color {
        switch cell.cellType.lowercased() {
        case "code":
            return .blue
        case "markdown":
            return .green
        case "raw":
            return .orange
        default:
            return .gray
        }
    }
    
    private var cellTypeDisplayName: String {
        switch cell.cellType.lowercased() {
        case "code":
            return "Code Cell"
        case "markdown":
            return "Markdown Cell"
        case "raw":
            return "Raw Cell"
        default:
            return "Unknown Cell"
        }
    }
}

// MARK: - Local Cell Card View
struct LocalCellCardView: View {
    let cell: NotebookCell
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cell header
            HStack {
                cellTypeIcon
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(cellTypeDisplayName)
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        if cell.isWindowCell {
                            Text("WINDOW")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        
                        Text("IMPORT ONLY")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("Cell \(cell.cellIndex + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let executionCount = cell.executionCount {
                            Text("• Execution: \(executionCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let windowType = cell.windowType {
                            Text("• Type: \(windowType)")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onTap) {
                    Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Cell content preview
            if !cell.sourceText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    if isSelected {
                        // Full content
                        ScrollView {
                            Text(cell.sourceText)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color(uiColor: .systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .frame(maxHeight: 200)
                    } else {
                        // Preview (first few lines)
                        let previewText = cell.sourceText.components(separatedBy: .newlines).prefix(3).joined(separator: "\n")
                        Text(previewText + (cell.sourceText.components(separatedBy: .newlines).count > 3 ? "\n..." : ""))
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(uiColor: .systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            
            // Show outputs if selected and available
            if isSelected, let outputs = cell.outputs, !outputs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stored Outputs:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    ForEach(Array(outputs.enumerated()), id: \.offset) { index, output in
                        if let outputType = output["output_type"] as? String {
                            HStack {
                                Text("\(index + 1). \(outputType)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.2))
                                    .clipShape(Capsule())
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
            
            // Note about local limitations
            if isSelected && cell.cellType.lowercased() == "code" {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("Import Only Mode")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Text("This notebook will be imported into the spatial environment. To execute cells, connect to a Jupyter server.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        .background(cell.isWindowCell ? Color.blue.opacity(0.05) : Color(uiColor: .secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(cell.isWindowCell ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            onTap()
        }
    }
    
    private var cellTypeIcon: some View {
        Image(systemName: cellTypeIconName)
            .font(.title2)
            .foregroundStyle(cellTypeColor)
            .frame(width: 30)
    }
    
    private var cellTypeIconName: String {
        switch cell.cellType.lowercased() {
        case "code":
            return "curlybraces"
        case "markdown":
            return "text.format"
        case "raw":
            return "doc.plaintext"
        default:
            return "questionmark.circle"
        }
    }
    
    private var cellTypeColor: Color {
        switch cell.cellType.lowercased() {
        case "code":
            return .blue
        case "markdown":
            return .green
        case "raw":
            return .orange
        default:
            return .gray
        }
    }
    
    private var cellTypeDisplayName: String {
        switch cell.cellType.lowercased() {
        case "code":
            return "Code Cell"
        case "markdown":
            return "Markdown Cell"
        case "raw":
            return "Raw Cell"
        default:
            return "Unknown Cell"
        }
    }
}

// MARK: - Jupyter Connection Dialog
struct JupyterConnectionView: View {
    @Binding var isPresented: Bool
    @Binding var serverURL: String
    @Binding var token: String
    @Binding var serverName: String
    let onConnect: () -> Void
    
    @State private var showAdvanced = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                
                connectionForm
                
                Spacer()
                
                connectionInstructions
            }
            .padding()
            .navigationTitle("Connect to Jupyter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Connect") {
                        onConnect()
                    }
                    .disabled(serverURL.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "server.rack")
                .font(.system(size: 50))
                .foregroundStyle(.blue)
            
            Text("Connect to Jupyter Server")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enter your Jupyter server details to import notebooks directly")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var connectionForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Server URL")
                    .font(.headline)
                
                TextField("http://localhost:8888", text: $serverURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Text("The base URL of your Jupyter server")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Authentication Token")
                    .font(.headline)
                
                SecureField("Token (optional)", text: $token)
                    .textFieldStyle(.roundedBorder)
                
                Text("Required if your server uses token authentication")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            DisclosureGroup("Advanced Options", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("My Jupyter Server", text: $serverName)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("A friendly name for this connection")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
        }
    }
    
    private var connectionInstructions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to find your token:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text("1.")
                        .fontWeight(.medium)
                    Text("Check your Jupyter server startup logs")
                }
                
                HStack(alignment: .top) {
                    Text("2.")
                        .fontWeight(.medium)
                    Text("Look for a line containing 'token='")
                }
                
                HStack(alignment: .top) {
                    Text("3.")
                        .fontWeight(.medium)
                    Text("Copy the token value after '='")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(uiColor: .systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}