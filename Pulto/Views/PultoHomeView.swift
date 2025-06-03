import SwiftUI
import RealityKit




struct PultoHomeView: View {
    @State private var selectedSection: HomeSection? = nil
    @State private var showCreateProject = false
    @State private var showOpenProject = false
    @State private var showSettings = false
    @State private var showLogin = false
    @State private var isUserLoggedIn = false
    @State private var userName = "Guest"
    @State private var recentProjects: [Project] = Project.sampleProjects
    @State private var isDarkMode = true
    @Environment(\.colorScheme) var colorScheme

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

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: isDarkMode ? [
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

                VStack(spacing: 40) {
                    // Header
                    HeaderView(
                        userName: userName,
                        isLoggedIn: isUserLoggedIn,
                        isDarkMode: isDarkMode,
                        onLoginTap: { showLogin = true }
                    )

                    // Main Content
                    ScrollView {
                        VStack(spacing: 32) {
                            // Hero Section
                            HeroSection(isDarkMode: isDarkMode)

                            // Primary Actions
                            PrimaryActionsGrid(
                                showCreateProject: $showCreateProject,
                                showOpenProject: $showOpenProject,
                                isDarkMode: isDarkMode
                            )

                            // Recent Projects
                            if !recentProjects.isEmpty && isUserLoggedIn {
                                RecentProjectsSection(
                                    projects: recentProjects,
                                    isDarkMode: isDarkMode,
                                    onProjectTap: { project in
                                        // Handle project opening
                                    }
                                )
                            }

                            // Quick Stats (if logged in)
                            if isUserLoggedIn {
                                QuickStatsSection(isDarkMode: isDarkMode)
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                    }
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isDarkMode.toggle()
                            }
                        } label: {
                            Image(systemName: isDarkMode ? "sun.max" : "moon")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title2)
                                .foregroundStyle(isDarkMode ? .yellow : .indigo)
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
        }
        .sheet(isPresented: $showCreateProject) {
            //CreateProjectView()
            //
            //CSVChartRecommenderView().frame(width: 600, height: 750)
            DataImportView().frame(width: 600, height: 750)
        }
        .sheet(isPresented: $showOpenProject) {
            OpenWindowView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showLogin) {
            LoginView(isLoggedIn: $isUserLoggedIn, userName: $userName)
        }
    }
}

struct HeaderView: View {
    let userName: String
    let isLoggedIn: Bool
    let isDarkMode: Bool
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
                    .foregroundColor(isDarkMode ? .white : .black)
            }

            Spacer()

            // User Profile
            Button(action: onLoginTap) {
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
        .padding(.horizontal, 40)
        .padding(.top, 40)
    }
}

struct SpatialHeroSection: View {
    let isDarkMode: Bool

    var body: some View {
        VStack(spacing: 24) {
            // 3D Visualization Preview
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .frame(height: 300)

                // Animated gradient background
                LinearGradient(
                    colors: [
                        .blue.opacity(0.3),
                        .purple.opacity(0.3),
                        .pink.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    VStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 80))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))

                        Text("Visualize Your Data in 2D & 3D")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(isDarkMode ? .white : .black)

                        Text("Create stunning interactive visualizations")
                            .font(.body)
                            .foregroundStyle(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    }
                    .padding()
                )
            }
        }
    }
}

struct PrimaryActionsGrid: View {
    @Binding var showCreateProject: Bool
    @Binding var showOpenProject: Bool
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
                    color: .blue
                ) {
                    showCreateProject = true
                }

                ActionCard(
                    title: "Open Project",
                    subtitle: "Continue working",
                    icon: "folder",
                    color: .purple
                ) {
                    showOpenProject = true
                }

                ActionCard(
                    title: "Templates",
                    subtitle: "Quick start guides",
                    icon: "square.grid.2x2",
                    color: .green
                ) {
                    // Handle templates
                }
            }
        }
    }
}

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
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct RecentProjectsSection: View {
    let projects: [Project]
    let isDarkMode: Bool
    let onProjectTap: (Project) -> Void

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
                HStack(spacing: 16) {
                    ForEach(projects) { project in
                        RecentProjectCard(
                            project: project,
                            onTap: { onProjectTap(project) }
                        )
                    }
                }
            }
        }
    }
}

struct RecentProjectCard: View {
    let project: Project
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Preview
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
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct QuickStatsSection: View {
    let isDarkMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your Activity")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(isDarkMode ? .white : .black)

            HStack(spacing: 20) {
                StatCard(
                    value: "12",
                    label: "Total Projects",
                    icon: "square.stack.3d.up",
                    color: .blue
                )

                StatCard(
                    value: "47",
                    label: "Visualizations",
                    icon: "chart.bar.xaxis",
                    color: .purple
                )

                StatCard(
                    value: "3.2K",
                    label: "Data Points",
                    icon: "circle.grid.3x3",
                    color: .green
                )

                StatCard(
                    value: "8",
                    label: "Collaborators",
                    icon: "person.2",
                    color: .orange
                )
            }
        }
    }
}

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

// Supporting Models
struct Project: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let icon: String
    let color: Color
    let lastModified: Date

    static let sampleProjects = [
        Project(name: "Sales Dashboard", type: "2D Chart", icon: "chart.bar", color: .blue, lastModified: Date().addingTimeInterval(-3600)),
        Project(name: "Climate Model", type: "3D Visualization", icon: "globe", color: .green, lastModified: Date().addingTimeInterval(-7200)),
        Project(name: "Stock Analysis", type: "Time Series", icon: "chart.line.uptrend.xyaxis", color: .purple, lastModified: Date().addingTimeInterval(-86400)),
        Project(name: "Population Data", type: "Heatmap", icon: "map", color: .orange, lastModified: Date().addingTimeInterval(-172800))
    ]
}

// Placeholder Views
struct CreateProjectView: View {
    var body: some View {
        Text("Create Project View")
            .frame(width: 600, height: 400)
    }
}

struct OpenProjectView: View {
    var body: some View {
        Text("Open Project View")
            .frame(width: 600, height: 400)
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings View")
            .frame(width: 600, height: 400)
    }
}

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userName: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Sign In to Pulto")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Placeholder login form
            VStack(spacing: 16) {
                TextField("Username", text: $userName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)

                SecureField("Password", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)

                Button("Sign In") {
                    isLoggedIn = true
                    dismiss()
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

// Preview
struct PultoHomeView_Previews: PreviewProvider {
    static var previews: some View {
        PultoHomeView()
    }
}
