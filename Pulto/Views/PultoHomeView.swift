import SwiftUI
import RealityKit

// MARK: - View Models
@MainActor
final class PultoHomeViewModel: ObservableObject {
    @Published var selectedSection: HomeSection? = nil
    @Published var recentProjects: [Project] = []
    @Published var isUserLoggedIn = false
    @Published var userName = "Guest"
    @Published var isDarkMode = true
    @Published var isLoadingProjects = false
    @Published var stats: UserStats?

    // Cache computed values
    private var projectsCache: [Project]?

    func loadInitialData() async {
        // Simulate async data loading
        isLoadingProjects = true

        // Load user authentication state
        await loadUserState()

        // Load projects only if user is logged in
        if isUserLoggedIn {
            await loadRecentProjects()
            await loadUserStats()
        }

        isLoadingProjects = false
    }

    private func loadUserState() async {
        // Simulate checking authentication
        //try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        // In real app, check actual auth state
    }

    private func loadRecentProjects() async {
        // Simulate network delay
        //try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // Use cached projects if available
        if let cached = projectsCache {
            recentProjects = cached
        } else {
            let projects = Project.sampleProjects
            projectsCache = projects
            recentProjects = projects
        }
    }

    private func loadUserStats() async {
        // Simulate loading stats
        //try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
        stats = UserStats(
            totalProjects: 12,
            visualizations: 47,
            dataPoints: "3.2K",
            collaborators: 8
        )
    }
}

// MARK: - Models
struct UserStats {
    let totalProjects: Int
    let visualizations: Int
    let dataPoints: String
    let collaborators: Int
}

enum HomeSection: String, CaseIterable {
    case create = "Create Project"
    case open = "Open Project"
    case recent = "Recent"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .create: return "plus.square.on.square"
        case .open: return "folder"
        case .recent: return "clock"
        case .settings: return "gearshape"
        }
    }

    var description: String {
        switch self {
        case .create: return "Start a new visualization project"
        case .open: return "Browse and open existing projects"
        case .recent: return "Continue where you left off"
        case .settings: return "Customize your experience"
        }
    }
}

// MARK: - Main View
struct PultoHomeView: View {
    @StateObject private var viewModel = PultoHomeViewModel()
    @State private var showCreateProject = false
    @State private var showSettings = false
    @State private var showLogin = false
    @State private var showTemplates = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                VStack(spacing: 40) {
                    HeaderView(viewModel: viewModel) {
                        showLogin = true
                    }

                    mainContent
                }
            }
            .preferredColorScheme(viewModel.isDarkMode ? .dark : .light)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarButtons
                }
            }
            .task {
                await viewModel.loadInitialData()
            }
            .sheet(isPresented: $showCreateProject) {
                NotebookChartsView().frame(width:1280, height:720)
                //CSVChartRecommenderView()
                //    .frame(width: 600, height: 750)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showLogin) {
                LoginView(
                    isLoggedIn: $viewModel.isUserLoggedIn,
                    userName: $viewModel.userName
                )
            }
            .sheet(isPresented: $showTemplates) {
                //TemplateView()

            }
        }
    }

    // MARK: - Subviews
    private var backgroundGradient: some View {
        LinearGradient(
            colors: viewModel.isDarkMode ? [
                Color(red: 0.07, green: 0.07, blue: 0.12),
                Color(red: 0.05, green: 0.05, blue: 0.08)
            ] : [
                Color(red: 0.98, green: 0.98, blue: 1.0),
                Color(red: 0.95, green: 0.95, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 32) {
                PrimaryActionsGrid(
                    showCreateProject: $showCreateProject,
                    showTemplates: $showTemplates,
                    onOpenProject: {
                        openWindow(id: "open-project-window")
                    },
                    isDarkMode: viewModel.isDarkMode
                )

                if viewModel.isUserLoggedIn {
                    if viewModel.isLoadingProjects {
                        ProgressView("Loading projects...")
                            .frame(height: 200)
                    } else if !viewModel.recentProjects.isEmpty {
                        RecentProjectsSection(
                            projects: viewModel.recentProjects,
                            isDarkMode: viewModel.isDarkMode
                        )
                    }

                    if let stats = viewModel.stats {
                        QuickStatsSection(
                            stats: stats,
                            isDarkMode: viewModel.isDarkMode
                        )
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }

    private var toolbarButtons: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.isDarkMode.toggle()
                }
            } label: {
                Image(systemName: viewModel.isDarkMode ? "sun.max" : "moon")
                    .symbolRenderingMode(.hierarchical)
                    .font(.title2)
                    .foregroundStyle(viewModel.isDarkMode ? .yellow : .indigo)
            }
            .buttonStyle(.borderless)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .symbolRenderingMode(.hierarchical)
                    .font(.title2)
            }
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    @ObservedObject var viewModel: PultoHomeViewModel
    let onLoginTap: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pulto")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Spatial Data Visualization Platform")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.isDarkMode ? .white : .black)
            }

            Spacer()

            UserProfileButton(
                userName: viewModel.userName,
                isLoggedIn: viewModel.isUserLoggedIn,
                onTap: onLoginTap
            )
        }
        .padding(.horizontal, 40)
        .padding(.top, 40)
    }
}

// MARK: - User Profile Button
struct UserProfileButton: View {
    let userName: String
    let isLoggedIn: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isLoggedIn ? "person.circle.fill" : "person.circle")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isLoggedIn ? userName : "Sign In")
                        .font(.headline)

                    if isLoggedIn {
                        Text("View Profile")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Primary Actions Grid
struct PrimaryActionsGrid: View {
    @Binding var showCreateProject: Bool
    @Binding var showTemplates: Bool
    let onOpenProject: () -> Void
    let isDarkMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Get Started")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(isDarkMode ? .white : .black)

            HStack(spacing: 20) {
                ActionCard(
                    title: "Create New",
                    subtitle: "Start a visualization",
                    icon: "plus.square.on.square",
                    color: .blue,
                    action: onOpenProject
                )

                ActionCard(
                    title: "Open Project",
                    subtitle: "Continue working",
                    icon: "folder",
                    color: .purple,

                ){
                    showCreateProject = true
                }

                ActionCard(
                    title: "Templates",
                    subtitle: "Quick start guides",
                    icon: "square.grid.2x2",
                    color: .green
                ) {
                    showTemplates = true
                }
            }
        }
    }
}

// MARK: - Action Card
struct ActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .padding(24)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(isHovered ? 0.5 : 0), lineWidth: 2)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Recent Projects Section
struct RecentProjectsSection: View {
    let projects: [Project]
    let isDarkMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Recent Projects")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(isDarkMode ? .white : .black)

                Spacer()

                Button("View All") {
                    // Handle view all
                }
                .buttonStyle(.borderless)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(projects) { project in
                        RecentProjectCard(project: project)
                    }
                }
            }
        }
    }
}

// MARK: - Recent Project Card
struct RecentProjectCard: View {
    let project: Project
    @State private var isHovered = false

    var body: some View {
        Button {
            // Handle project tap
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(project.color.opacity(0.3))
                    .frame(width: 200, height: 120)
                    .overlay(
                        Image(systemName: project.icon)
                            .font(.system(size: 40))
                            .foregroundStyle(project.color)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text(project.type)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(project.lastModified, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .frame(width: 200)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Quick Stats Section
struct QuickStatsSection: View {
    let stats: UserStats
    let isDarkMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your Activity")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(isDarkMode ? .white : .black)

            HStack(spacing: 20) {
                StatCard(
                    value: "\(stats.totalProjects)",
                    label: "Total Projects",
                    icon: "square.stack.3d.up",
                    color: .blue
                )

                StatCard(
                    value: "\(stats.visualizations)",
                    label: "Visualizations",
                    icon: "chart.bar.xaxis",
                    color: .purple
                )

                StatCard(
                    value: stats.dataPoints,
                    label: "Data Points",
                    icon: "circle.grid.3x3",
                    color: .green
                )

                StatCard(
                    value: "\(stats.collaborators)",
                    label: "Collaborators",
                    icon: "person.2",
                    color: .orange
                )
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Supporting Models
struct Project: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let icon: String
    let color: Color
    let lastModified: Date

    static let sampleProjects = [
        Project(
            name: "Sales Dashboard",
            type: "2D Chart",
            icon: "chart.bar",
            color: .blue,
            lastModified: Date().addingTimeInterval(-3600)
        ),
        Project(
            name: "Climate Model",
            type: "3D Visualization",
            icon: "globe",
            color: .green,
            lastModified: Date().addingTimeInterval(-7200)
        ),
        Project(
            name: "Stock Analysis",
            type: "Time Series",
            icon: "chart.line.uptrend.xyaxis",
            color: .purple,
            lastModified: Date().addingTimeInterval(-86400)
        ),
        Project(
            name: "Population Data",
            type: "Heatmap",
            icon: "map",
            color: .orange,
            lastModified: Date().addingTimeInterval(-172800)
        )
    ]
}

// MARK: - Placeholder Views
/*struct CSVChartRecommenderView: View {
    var body: some View {
        Text("CSV Chart Recommender View")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct VisualizationWindowView: View {
    var body: some View {
        Text("Visualization Window View")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
*/
struct SettingsView: View {
    var body: some View {
        Text("Settings View")
            .frame(width: 600, height: 400)
    }
}

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userName: String
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Sign In to Pulto")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()

                Button(action: { dismiss() }) {
                    Label("Close", systemImage: "xmark.circle.fill")
                        .font(.title2)
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
            }

            VStack(spacing: 16) {
                TextField("Username", text: $userName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)

                Button("Sign In") {
                    Task {

                        // Simulate login
                        isLoggedIn = true
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
        .frame(width: 400, height: 300)
        .padding()
    }
}

// MARK: - Preview
struct PultoHomeView_Previews: PreviewProvider {
    static var previews: some View {
        PultoHomeView()
    }
}
