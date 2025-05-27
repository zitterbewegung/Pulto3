import SwiftUI
import SwiftData
/*

 // MARK: - Usage Example
 struct ContentView: View {
     @Environment(\.modelContext) private var modelContext

     var body: some View {
         NavigationStack {
             VisionOSTableView()
                 .navigationTitle("Data Table")
                 .toolbar {
                     ToolbarItem(placement: .topBarTrailing) {
                         Button(action: addSampleItem) {
                             Label("Add Item", systemImage: "plus.circle.fill")
                         }
                         .buttonStyle(.borderedProminent)
                     }
                 }
         }
     }

     func addSampleItem() {
         let statuses = ["Active", "Pending", "Complete", "Inactive"]
         let newItem = DataItem(
             title: "Item \(Int.random(in: 1...100))",
             subtitle: "Description text",
             value: Double.random(in: 10...1000),
             status: statuses.randomElement()!
         )
         modelContext.insert(newItem)
     }
 }
 */
// MARK: - SwiftData Model (example)
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

// MARK: - VisionOS Table View
struct DataTableView: View {
    @Query private var items: [DataItem]
    @State private var sortOrder = [KeyPathComparator(\DataItem.title)]
    @State private var selectedItems = Set<DataItem.ID>()
    @State private var searchText = ""

    var filteredItems: [DataItem] {
        if searchText.isEmpty {
            return items.sorted(using: sortOrder)
        } else {
            return items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.subtitle.localizedCaseInsensitiveContains(searchText)
            }.sorted(using: sortOrder)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.title3)

                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
            }
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 32)
            .padding(.vertical, 20)

            // Table
            Table(filteredItems, selection: $selectedItems, sortOrder: $sortOrder) {
                TableColumn("Title", value: \.title) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .width(min: 250, ideal: 300)

                TableColumn("Value", value: \.value) { item in
                    Text(item.value, format: .number.precision(.fractionLength(2)))
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                .width(ideal: 150)

                TableColumn("Status") { item in
                    HStack {
                        Circle()
                            .fill(statusColor(for: item.status))
                            .frame(width: 10, height: 10)
                        Text(item.status)
                            .font(.callout)
                    }
                }
                .width(ideal: 150)

                TableColumn("Date", value: \.timestamp) { item in
                    Text(item.timestamp, format: .dateTime.day().month().hour().minute())
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .width(ideal: 200)
            }
            .tableStyle(.inset)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
            .padding(.horizontal, 32)
            .padding(.bottom, 32)

            // Summary Bar
            if !items.isEmpty {
                HStack {
                    Label("\(filteredItems.count) items", systemImage: "list.bullet")
                        .font(.headline)

                    Spacer()

                    if !selectedItems.isEmpty {
                        Label("\(selectedItems.count) selected", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            //.foregroundStyle(.accent)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(.regularMaterial)
            }
        }
        .frame(depth: 20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 32))
    }

    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "active", "complete", "success":
            return .green
        case "pending", "warning":
            return .orange
        case "inactive", "error", "failed":
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Usage Example
struct SpreadSheetContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            SpreadSheetContentView()
                .navigationTitle("Data Table")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: addSampleItem) {
                            Label("Add Item", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
        }
    }

    func addSampleItem() {
        let statuses = ["Active", "Pending", "Complete", "Inactive"]
        let newItem = DataItem(
            title: "Item \(Int.random(in: 1...100))",
            subtitle: "Description text",
            value: Double.random(in: 10...1000),
            status: statuses.randomElement()!
        )
        modelContext.insert(newItem)
    }
}

// MARK: - Preview
#Preview("VisionOS Table View") {
    DataTableView()
        .frame(width: 1280, height: 720)
        .modelContainer(for: DataItem.self, inMemory: true)
}

#Preview("Table in Navigation") {
    SpreadSheetContentView()
        .frame(width: 1200, height: 800)
        .modelContainer(for: DataItem.self, inMemory: true)
}

// MARK: - Preview with Sample Data
struct PreviewContainer: View {
    @State private var container: ModelContainer

    init() {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: DataItem.self, configurations: config)

            // Add sample data
            let sampleData = [
                DataItem(title: "Project Alpha", subtitle: "Development phase", value: 85.5, status: "Active"),
                DataItem(title: "Project Beta", subtitle: "Testing phase", value: 92.0, status: "Complete"),
                DataItem(title: "Project Gamma", subtitle: "Planning phase", value: 45.3, status: "Pending"),
                DataItem(title: "Project Delta", subtitle: "On hold", value: 12.8, status: "Inactive"),
                DataItem(title: "Project Epsilon", subtitle: "Final review", value: 98.7, status: "Active")
            ]

            for item in sampleData {
                container.mainContext.insert(item)
            }

            self._container = State(initialValue: container)
        } catch {
            fatalError("Failed to create model container for preview: \(error)")
        }
    }

    var body: some View {
        DataTableView()
            .frame(width: 1000, height: 600)
            .modelContainer(container)
    }
}

#Preview("Table with Data") {
    PreviewContainer()
}
