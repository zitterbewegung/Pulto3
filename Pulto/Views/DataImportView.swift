import SwiftUI
import UniformTypeIdentifiers

struct DataImportView: View {
    @State private var urlText = ""
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var showFileImporter = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var importedFileName = ""
    @State private var selectedImportMethod: ImportMethod = .url
    @Environment(\.dismiss) private var dismiss  // Add this line

    enum ImportMethod: String, CaseIterable {
        case url = "URL"
        case file = "File"

        var icon: String {
            switch self {
            case .url: return "link"
            case .file: return "doc"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                        .symbolRenderingMode(.hierarchical)

                    Text("Import Data")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Import data from a URL or local file")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                // Import Method Selection
                VStack(alignment: .leading, spacing: 16) {
                   // Text("Import Method")
                   //     .font(.headline)
                   //     .foregroundStyle(.secondary)

                    HStack(spacing: 20) {
                        ForEach(ImportMethod.allCases, id: \.self) { method in
                            ImportMethodButton(
                                method: method,
                                isSelected: selectedImportMethod == method
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedImportMethod = method
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 600)

                // Import Interface
                Group {
                    if selectedImportMethod == .url {
                        URLImportSection(
                            urlText: $urlText,
                            isImporting: $isImporting,
                            onImport: importFromURL
                        )
                    } else {
                        FileImportSection(
                            importedFileName: $importedFileName,
                            isImporting: $isImporting,
                            onImport: { showFileImporter = true }
                        )
                    }
                }
                .frame(maxWidth: 600)

                // Progress Indicator
                if isImporting {
                    VStack(spacing: 16) {
                        ProgressView(value: importProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 300)

                        Text("Importing data...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Spacer()
            }
            .padding(.horizontal, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                       dismiss()
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json, .text, .xml, .commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("Import Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func importFromURL() {
        guard !urlText.isEmpty else {
            showError(message: "Please enter a valid URL")
            return
        }

        guard let url = URL(string: urlText) else {
            showError(message: "Invalid URL format")
            return
        }

        isImporting = true
        importProgress = 0

        // Simulate import progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            importProgress += 0.1
            if importProgress >= 1.0 {
                timer.invalidate()
                isImporting = false
                // Handle successful import
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                showError(message: "No file selected")
                return
            }

            importedFileName = url.lastPathComponent
            isImporting = true
            importProgress = 0

            // Simulate import progress
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                importProgress += 0.1
                if importProgress >= 1.0 {
                    timer.invalidate()
                    isImporting = false
                    // Handle successful import
                }
            }

        case .failure(let error):
            showError(message: error.localizedDescription)
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

struct ImportMethodButton: View {
    let method: DataImportView.ImportMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: method.icon)
                    .font(.system(size: 32))
                    .symbolRenderingMode(.hierarchical)

                Text(method.rawValue)
                    .font(.headline)
            }
            .frame(width: 140, height: 100)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? Color.accentColor : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct URLImportSection: View {
    @Binding var urlText: String
    @Binding var isImporting: Bool
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter URL")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack {
                TextField("https://example.com/data.json", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isImporting)

                Button(action: onImport) {
                    Label("Import", systemImage: "arrow.down.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlText.isEmpty || isImporting)
            }

            Text("Supported formats: JSON, CSV, XML, TXT")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct FileImportSection: View {
    @Binding var importedFileName: String
    @Binding var isImporting: Bool
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            if importedFileName.isEmpty {
                Text("No file selected")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    Text("Selected File")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(importedFileName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Button(action: onImport) {
                Label("Choose File", systemImage: "folder")
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isImporting)

            Text("Supported formats: JSON, CSV, XML, TXT")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// Preview
struct DataImportView_Previews: PreviewProvider {
    static var previews: some View {
        DataImportView()
    }
}
