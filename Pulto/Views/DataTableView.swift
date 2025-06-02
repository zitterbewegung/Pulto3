import SwiftUI
import SwiftData

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
struct DataTableContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            DataTableView()
                .navigationTitle("Data Management")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add Item", systemImage: "plus") {
                            addSampleItem()
                        }
                        .labelStyle(.iconOnly)
                    }
                }
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
}

// MARK: - Data Table View
struct DataTableView: View {
    @Query private var items: [DataItem]
    @State private var sortOrder = [KeyPathComparator(\DataItem.title)]
    @State private var selectedItems = Set<DataItem.ID>()
    @State private var searchText = ""

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

    var body: some View {
        VStack(spacing: 20) {
            searchSection

            if filteredItems.isEmpty {
                emptyStateView
            } else {
                tableSection
                summarySection
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
    }

    // MARK: - View Components

    private var searchSection: some View {
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
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No Items")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Text("Add your first item to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
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

#Preview("Main Content View") {
    DataTableContentView()
        .modelContainer(for: DataItem.self, inMemory: true)
}
