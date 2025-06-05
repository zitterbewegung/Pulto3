import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - SwiftData Model
@Model
final class DataItem {
    var id: UUID
    var title: String
    var subtitle: String
    var value: Double
    var status: String
    var timestamp: Date

    init(title: String, subtitle: String, value: Double, status: String) {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.status = status
        self.timestamp = Date()
    }
}

// MARK: - Main Content View
struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingImportSheet = false
    @State private var showingDeleteAlert = false
    @State private var itemsToDelete: [DataItem] = []

    var body: some View {
        NavigationStack {
            DataTableView()
                .navigationTitle("Data Management")
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button("Import", systemImage: "square.and.arrow.down") {
                            showingImportSheet = true
                        }
                        .labelStyle(.iconOnly)

                        Button("Add Item", systemImage: "plus") {
                            addSampleItem()
                        }
                        .labelStyle(.iconOnly)
                    }
                }
        }
        .sheet(isPresented: $showingImportSheet) {
            DataImportView(modelContext: modelContext)
        }
        .alert("Delete Items", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteItems()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(itemsToDelete.count) item(s)?")
        }
    }

    private func addSampleItem() {
        let statuses = ["Active", "Pending", "Complete", "Inactive"]
        let newItem = DataItem(
            title: "Item \(Int.random(in: 1...100))",
            subtitle: "Description text",
            value: Double.random(in: 10...1000),
            status: statuses.randomElement()!
        )
        modelContext.insert(newItem)
    }

    private func deleteItems() {
        for item in itemsToDelete {
            modelContext.delete(item)
        }
        itemsToDelete.removeAll()
    }
}

// MARK: - Data Table View
struct DataTableView: View {
    @Query private var items: [DataItem]
    @State private var sortOrder = [KeyPathComparator(\DataItem.title)]
    @State private var selectedItems = Set<DataItem.ID>()
    @State private var searchText = ""
    @State private var showingBulkActions = false
    @Environment(\.modelContext) private var modelContext

    private var filteredItems: [DataItem] {
        if searchText.isEmpty {
            return items.sorted(using: sortOrder)
        } else {
            return items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.subtitle.localizedCaseInsensitiveContains(searchText)
            }.sorted(using: sortOrder)
        }
    }

    private var selectedItemObjects: [DataItem] {
        items.filter { selectedItems.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 20) {
            searchAndActionsSection

            if filteredItems.isEmpty {
                emptyStateView
            } else {
                tableSection
                summarySection
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .confirmationDialog("Bulk Actions", isPresented: $showingBulkActions) {
            Button("Mark as Active") {
                updateSelectedItemsStatus("Active")
            }
            Button("Mark as Complete") {
                updateSelectedItemsStatus("Complete")
            }
            Button("Mark as Pending") {
                updateSelectedItemsStatus("Pending")
            }
            Button("Mark as Inactive") {
                updateSelectedItemsStatus("Inactive")
            }
            Button("Delete Selected", role: .destructive) {
                deleteSelectedItems()
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - View Components

    private var searchAndActionsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.title2)

                TextField("Search items...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .submitLabel(.search)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Search items")

            if !selectedItems.isEmpty {
                HStack {
                    Button("Bulk Actions") {
                        showingBulkActions = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Clear Selection") {
                        selectedItems.removeAll()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Text("\(selectedItems.count) selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var tableSection: some View {
        Table(filteredItems, selection: $selectedItems, sortOrder: $sortOrder) {
            TableColumn("Item", value: \.title) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(item.title), \(item.subtitle)")
            }
            .width(min: 200, ideal: 280, max: 400)

            TableColumn("Value", value: \.value) { item in
                Text(item.value, format: .currency(code: "USD"))
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
            .width(min: 100, ideal: 140, max: 180)

            TableColumn("Status") { item in
                StatusBadge(status: item.status)
            }
            .width(min: 100, ideal: 120, max: 160)

            TableColumn("Date", value: \.timestamp) { item in
                Text(item.timestamp, format: .dateTime.day().month().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .width(min: 140, ideal: 180, max: 220)

            TableColumn("Actions") { item in
                HStack(spacing: 8) {
                    Button("Edit", systemImage: "pencil") {
                        // Edit action
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.blue)

                    Button("Delete", systemImage: "trash") {
                        modelContext.delete(item)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }
            }
            .width(min: 100, ideal: 120, max: 140)
        }
        .tableStyle(.inset)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel("Data table with \(filteredItems.count) items")
    }

    private var summarySection: some View {
        HStack {
            Label("\(filteredItems.count) \(filteredItems.count == 1 ? "item" : "items")",
                  systemImage: "list.bullet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Summary statistics
            if !filteredItems.isEmpty {
                let totalValue = filteredItems.reduce(0) { $0 + $1.value }
                Text("Total: \(totalValue, format: .currency(code: "USD"))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if !selectedItems.isEmpty {
                Label("\(selectedItems.count) selected",
                      systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No Items")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Text("Add your first item or import data to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Add Sample Item") {
                    addSampleItem()
                }
                .buttonStyle(.borderedProminent)

                Button("Import Data") {
                    // This would trigger the import sheet
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Helper Methods

    private func addSampleItem() {
        let statuses = ["Active", "Pending", "Complete", "Inactive"]
        let newItem = DataItem(
            title: "Item \(Int.random(in: 1...100))",
            subtitle: "Description text",
            value: Double.random(in: 10...1000),
            status: statuses.randomElement()!
        )
        modelContext.insert(newItem)
    }

    private func updateSelectedItemsStatus(_ status: String) {
        for item in selectedItemObjects {
            item.status = status
            item.timestamp = Date()
        }
        selectedItems.removeAll()
    }

    private func deleteSelectedItems() {
        for item in selectedItemObjects {
            modelContext.delete(item)
        }
        selectedItems.removeAll()
    }
}

// MARK: - Data Import View
struct DataImportView: View {
    let modelContext: ModelContext
    @State private var urlText = ""
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var showFileImporter = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var importedFileName = ""
    @State private var selectedImportMethod: ImportMethod = .url
    @State private var importedCount = 0
    @Environment(\.dismiss) private var dismiss

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

                        Text("Importing data... (\(Int(importProgress * 100))%)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Success indicator
                if importedCount > 0 && !isImporting {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Successfully imported \(importedCount) items")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding()
                    .background(.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()
            }
            .padding(.horizontal, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if importedCount > 0 && !isImporting {
                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.borderless)
                    }
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

        performImport(from: url)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                showError(message: "No file selected")
                return
            }

            importedFileName = url.lastPathComponent
            performImport(from: url)

        case .failure(let error):
            showError(message: error.localizedDescription)
        }
    }

    private func performImport(from url: URL) {
        isImporting = true
        importProgress = 0
        importedCount = 0

        // Simulate import with sample data creation
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            importProgress += 0.2

            // Add sample items during import simulation
            if importProgress <= 1.0 {
                let statuses = ["Active", "Pending", "Complete", "Inactive"]
                let sampleTitles = ["Project Alpha", "Data Analysis", "System Update", "User Research", "Performance Test"]
                let sampleSubtitles = ["Backend development", "Statistical analysis", "Security patches", "UX improvements", "Load testing"]

                let newItem = DataItem(
                    title: sampleTitles.randomElement()! + " \(Int.random(in: 100...999))",
                    subtitle: sampleSubtitles.randomElement()!,
                    value: Double.random(in: 100...5000),
                    status: statuses.randomElement()!
                )

                modelContext.insert(newItem)
                importedCount += 1
            }

            if importProgress >= 1.0 {
                timer.invalidate()
                isImporting = false
                importProgress = 1.0
            }
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Supporting Views

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

// MARK: - Status Badge Component
struct StatusBadge: View {
    let status: String

    private var statusInfo: (color: Color, icon: String) {
        switch status.lowercased() {
        case "active":
            return (.green, "checkmark.circle.fill")
        case "complete":
            return (.blue, "checkmark.seal.fill")
        case "pending":
            return (.orange, "clock.fill")
        case "inactive":
            return (.red, "xmark.circle.fill")
        default:
            return (.gray, "circle.fill")
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: statusInfo.icon)
                .font(.caption)
                .foregroundStyle(statusInfo.color)

            Text(status)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(statusInfo.color.opacity(0.1), in: Capsule())
        .accessibilityLabel("Status: \(status)")
    }
}

// MARK: - Previews
#Preview("Empty State") {
    NavigationStack {
        DataTableView()
            .navigationTitle("Data Management")
    }
    .modelContainer(for: DataItem.self, inMemory: true)
}

#Preview("With Data") {
    let container = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: DataItem.self, configurations: config)

            let sampleData = [
                DataItem(title: "Project Alpha", subtitle: "Development phase", value: 1285.50, status: "Active"),
                DataItem(title: "Project Beta", subtitle: "Testing phase", value: 2192.00, status: "Complete"),
                DataItem(title: "Project Gamma", subtitle: "Planning phase", value: 845.30, status: "Pending"),
                DataItem(title: "Project Delta", subtitle: "On hold", value: 412.80, status: "Inactive"),
                DataItem(title: "Project Epsilon", subtitle: "Final review", value: 3287.45, status: "Active")
            ]

            for item in sampleData {
                container.mainContext.insert(item)
            }

            return container
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }()

    NavigationStack {
        DataTableView()
            .navigationTitle("Data Management")
    }
    .modelContainer(container)
}

#Preview("Main View") {
    DataManagementView()
        .modelContainer(for: DataItem.self, inMemory: true)
}

#Preview("Import View") {
    let container = try! ModelContainer(for: DataItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    DataImportView(modelContext: container.mainContext)
}
