import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = PultoHomeViewModel()
    @StateObject private var sheetManager = SheetManager()
    @StateObject private var windowManager = WindowTypeManager.shared
    @StateObject private var workspaceManager = WorkspaceManager.shared
    
    var body: some View {
        NavigationStack {
            TabView {
                // Home Tab
                PultoHomeContentView(
                    viewModel: viewModel,
                    sheetManager: sheetManager,
                    onOpenWorkspace: {}
                )
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
                .environmentObject(sheetManager)
                .environmentObject(windowManager)
                
                // Workspace Tab (replaces the EnvironmentView)
                EnvironmentView()
                    .tabItem {
                        Image(systemName: "rectangle.3.offgrid")
                        Text("Workspace")
                    }
                    .environmentObject(sheetManager)
                    .environmentObject(windowManager)
                    .environmentObject(workspaceManager)
                
                // Library Tab
                LibraryView()
                    .tabItem {
                        Image(systemName: "books.vertical")
                        Text("Library")
                    }
            }
        }
        .environmentObject(sheetManager)
        .environmentObject(windowManager)
        .environmentObject(workspaceManager)
    }
}

// Library View
struct LibraryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Library")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Templates, examples, and resources")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Library sections
                LibrarySection(
                    title: "Templates",
                    items: [
                        LibraryItem(title: "Data Visualization", subtitle: "Chart templates", icon: "chart.bar.doc.horizontal", color: .blue),
                        LibraryItem(title: "3D Models", subtitle: "3D model examples", icon: "cube", color: .red),
                        LibraryItem(title: "Point Clouds", subtitle: "Point cloud samples", icon: "circle.grid.3x3", color: .cyan)
                    ]
                )
                
                LibrarySection(
                    title: "Examples",
                    items: [
                        LibraryItem(title: "Sales Dashboard", subtitle: "Interactive dashboard", icon: "speedometer", color: .green),
                        LibraryItem(title: "Scientific Data", subtitle: "Research visualization", icon: "waveform.path.ecg", color: .purple),
                        LibraryItem(title: "IoT Monitoring", subtitle: "Real-time metrics", icon: "sensor.tag.radiowaves.forward", color: .orange)
                    ]
                )
                
                LibrarySection(
                    title: "Resources",
                    items: [
                        LibraryItem(title: "Documentation", subtitle: "User guides", icon: "doc", color: .gray),
                        LibraryItem(title: "Tutorials", subtitle: "Step-by-step guides", icon: "play.rectangle", color: .pink),
                        LibraryItem(title: "Community", subtitle: "Forum and discussions", icon: "person.3", color: .indigo)
                    ]
                )
            }
            .padding(.vertical)
        }
        .navigationTitle("Library")
    }
}

// Library Section
struct LibrarySection: View {
    let title: String
    let items: [LibraryItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(items.indices, id: \.self) { index in
                    LibraryItemView(item: items[index])
                }
            }
            .padding(.horizontal)
        }
    }
}

// Library Item Model
struct LibraryItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

// Library Item View
struct LibraryItemView: View {
    let item: LibraryItem
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(item.color.opacity(0.1))
                        .frame(height: 60)
                    
                    Image(systemName: item.icon)
                        .font(.title)
                        .foregroundColor(item.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(isHovered ? 0.1 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovered = $0 }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
