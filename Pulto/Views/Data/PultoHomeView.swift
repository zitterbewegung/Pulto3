import SwiftUI
import RealityKit
import Foundation

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
        isLoadingProjects = true
        
        // Load user state (fast)
        await loadUserState()
        
        // Create sample projects immediately
        createSampleProjectsInMemory()
        
        isLoadingProjects = false
    }

    func saveRecentProjects() async {
        // Simplified - just cache in memory for now
        projectsCache = recentProjects
    }
    
    func addRecentProject(_ project: Project) async {
        // Add to beginning of array (most recent)
        recentProjects.insert(project, at: 0)
        
        // Keep only the most recent 10 projects
        if recentProjects.count > 10 {
            recentProjects = Array(recentProjects.prefix(10))
        }
        
        // Save to memory
        await saveRecentProjects()
    }
    
    func updateProjectLastModified(_ projectId: UUID) async {
        if let index = recentProjects.firstIndex(where: { $0.id == projectId }) {
            let updatedProject = Project(
                id: recentProjects[index].id,
                name: recentProjects[index].name,
                type: recentProjects[index].type,
                icon: recentProjects[index].icon,
                color: recentProjects[index].color,
                lastModified: Date(),
                visualizations: recentProjects[index].visualizations,
                dataPoints: recentProjects[index].dataPoints,
                collaborators: recentProjects[index].collaborators,
                filename: recentProjects[index].filename
            )
            
            recentProjects[index] = updatedProject
            
            // Re-sort by last modified
            recentProjects.sort { $0.lastModified > $1.lastModified }
            
            // Save to memory
            await saveRecentProjects()
        }
    }
    
    func removeRecentProject(_ projectId: UUID) async {
        recentProjects.removeAll { $0.id == projectId }
        await saveRecentProjects()
    }

    private func loadUserState() async {
        // Simple implementation without file system access
        userName = "Guest"
        isUserLoggedIn = false
    }

    private func createSampleProjectsInMemory() {
        let sampleProjects = [
            Project(
                name: "Sales Dashboard",
                type: "Data Visualization",
                icon: "chart.bar",
                color: .blue,
                lastModified: Date().addingTimeInterval(-3600),
                visualizations: 4,
                dataPoints: 250,
                collaborators: 1,
                filename: "Sales_Dashboard.ipynb"
            ),
            Project(
                name: "Climate Model",
                type: "Scientific Computing",
                icon: "function",
                color: .green,
                lastModified: Date().addingTimeInterval(-7200),
                visualizations: 6,
                dataPoints: 1500,
                collaborators: 1,
                filename: "Climate_Model.ipynb"
            ),
            Project(
                name: "Stock Analysis",
                type: "Data Analysis",
                icon: "tablecells",
                color: .purple,
                lastModified: Date().addingTimeInterval(-86400),
                visualizations: 3,
                dataPoints: 800,
                collaborators: 1,
                filename: "Stock_Analysis.ipynb"
            ),
            Project(
                name: "Population Data",
                type: "Data Visualization",
                icon: "chart.bar",
                color: .orange,
                lastModified: Date().addingTimeInterval(-172800),
                visualizations: 2,
                dataPoints: 300,
                collaborators: 1,
                filename: "Population_Data.ipynb"
            )
        ]
        
        projectsCache = sampleProjects
        recentProjects = sampleProjects
    }

    private func loadUserStats() async {
        // Calculate stats from the user's current projects
        let totalProjects = recentProjects.count
        let visualizations = recentProjects.reduce(0) { $0 + $1.visualizations }
        let dataPointsTotal = recentProjects.reduce(0) { $0 + $1.dataPoints }
        let collaborators = recentProjects.reduce(0) { $0 + $1.collaborators }

        let dataPointsString = Self.formatNumber(dataPointsTotal)

        stats = UserStats(
            totalProjects: totalProjects,
            visualizations: visualizations,
            dataPoints: dataPointsString,
            collaborators: collaborators
        )
    }

    // Utility to turn large numbers into 1.2K / 3.4M style strings
    private static func formatNumber(_ number: Int) -> String {
        switch number {
        case 0..<1_000:
            return "\(number)"
        case 1_000..<1_000_000:
            return String(format: "%.1fK", Double(number) / 1_000)
        default:
            return String(format: "%.1fM", Double(number) / 1_000_000)
        }
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

// MARK: - Supporting Models
struct UserInfo {
    let name: String
    let email: String
}

// MARK: - Keychain Helper
class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
    
    func store(key: String, value: String) {
        // Simplified implementation
    }
    
    func read(key: String) -> String? {
        return nil
    }
    
    func delete(key: String) {
        // Simplified implementation
    }
}

struct SpatialBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Primary volumetric gradient
                RadialGradient(
                    colors: [
                        Color(red: 0.1, green: 0.15, blue: 0.25).opacity(0.3),
                        Color(red: 0.05, green: 0.08, blue: 0.15).opacity(0.5),
                        Color.black.opacity(0.8)
                    ],
                    center: .center,
                    startRadius: 100,
                    endRadius: max(geometry.size.width, geometry.size.height)
                )
                
                // Floating particles for depth
                ForEach(0..<15, id: \.self) { index in
                    FloatingElement(
                        index: index,
                        geometry: geometry
                    )
                }
                
                // Volumetric lighting effects
                DynamicLighting()
            }
            .ignoresSafeArea()
        }
    }
}

struct FloatingElement: View {
    let index: Int
    let geometry: GeometryProxy
    @State private var position: CGPoint = .zero
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 1
    
    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: CGFloat.random(in: 30...80))
            .blur(radius: CGFloat.random(in: 15...40))
            .opacity(opacity)
            .scaleEffect(scale)
            .position(position)
            .onAppear {
                position = CGPoint(
                    x: CGFloat.random(in: 0...geometry.size.width),
                    y: CGFloat.random(in: 0...geometry.size.height)
                )
                
                withAnimation(
                    .easeInOut(duration: Double.random(in: 8...20))
                    .repeatForever(autoreverses: true)
                ) {
                    position = CGPoint(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height)
                    )
                    opacity = Double.random(in: 0.1...0.4)
                    scale = CGFloat.random(in: 0.8...1.3)
                }
            }
    }
}

struct DynamicLighting: View {
    @State private var lightPosition: CGPoint = CGPoint(x: 200, y: 200)
    
    var body: some View {
        RadialGradient(
            colors: [
                Color.blue.opacity(0.15),
                Color.purple.opacity(0.08),
                Color.clear
            ],
            center: UnitPoint(x: lightPosition.x / 400, y: lightPosition.y / 400),
            startRadius: 50,
            endRadius: 300
        )
        .blur(radius: 20)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 12)
                .repeatForever(autoreverses: true)
            ) {
                lightPosition = CGPoint(x: 600, y: 300)
            }
        }
    }
}

struct VisionOSButtonStyle: ButtonStyle {
    enum Style {
        case primary, secondary, tertiary
        
        var backgroundColor: AnyShapeStyle {
            switch self {
            case .primary: return AnyShapeStyle(.blue)
            case .secondary: return AnyShapeStyle(.regularMaterial)
            case .tertiary: return AnyShapeStyle(.ultraThinMaterial)
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .primary
            case .tertiary: return .secondary
            }
        }
    }
    
    let style: Style
    
    init(_ style: Style = .primary) {
        self.style = style
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .medium))
            .foregroundStyle(style.foregroundColor)
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(style.backgroundColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Main View
struct PultoHomeView: View {
    @StateObject private var viewModel = PultoHomeViewModel()
    @StateObject private var windowManager = WindowTypeManager.shared
    @StateObject private var sheetManager = SheetManager()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationStack {
            ZStack {
                SpatialBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        SimpleHeaderView(viewModel: viewModel, onLoginTap: {
                            sheetManager.dismissAllAndPresent(.appleSignIn)
                        }, onSettingsTap: {
                            sheetManager.dismissAllAndPresent(.settings)
                        })

                        PrimaryActionsGrid(
                            sheetManager: sheetManager,
                            onOpenProject: {
                                openWindow(id: "main")
                            },
                            createNewProject: createNewProject
                        )

                        if viewModel.isLoadingProjects {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Loading projects...")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(24)
                            .background {
                                RoundedRectangle(cornerRadius: 32, style: .continuous)
                                    .fill(.regularMaterial)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                                    }
                                    .shadow(color: .black.opacity(0.15), radius: 25, x: 0, y: 15)
                                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        } else if !viewModel.recentProjects.isEmpty {
                            RecentProjectsSection(
                                projects: viewModel.recentProjects,
                                onProjectTap: openRecentProject,
                                onViewAll: {
                                    sheetManager.presentSheet(.projectBrowser)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                }
            }
            .preferredColorScheme(.dark)
            .toolbar {
            }
            .task {
                await viewModel.loadInitialData()
            }
            .singleSheetManager(sheetManager) { sheetType, data in
                AnyView(sheetContent(for: sheetType, data: data))
            }
        }
    }

    // MARK: - Sheet Content Builder
    @ViewBuilder
    private func sheetContent(for type: SheetType, data: AnyHashable?) -> some View {
        switch type {
        case .createProject:
            NavigationView {
                NotebookChartsView()
                    .navigationTitle("Create New Project")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                sheetManager.dismissSheet()
                            }
                        }
                    }
            }
            .frame(width: 1200, height: 800)
            
        case .settings:
            NavigationView {
                VStack {
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Settings panel coming soon...")
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding()
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            sheetManager.dismissSheet()
                        }
                    }
                }
            }
            .frame(width: 600, height: 500)
            
        case .appleSignIn:
            AppleSignInView(isPresented: sheetManager.binding(for: .appleSignIn))
                .frame(width: 700, height: 800)
                
        case .templateGallery:
            NotebookImportDialog(
                isPresented: sheetManager.binding(for: .templateGallery),
                windowManager: windowManager
            )
            
        case .projectBrowser:
            ProjectBrowserView(windowManager: windowManager)
            
        default:
            EmptyView()
        }
    }

    private func openRecentProject(_ project: Project) {
        Task {
            // Update the project's last modified date
            await viewModel.updateProjectLastModified(project.id)
            
            // Store the selected project in the window manager
            windowManager.setSelectedProject(project)
            
            // Dismiss all sheets
            sheetManager.dismissAllSheets()
            
            // Open the main spatial workspace with the selected project
            openWindow(id: "main")
        }
    }
    
    private func createNewProject() {
        Task {
            do {
                // Generate a unique project name with timestamp
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = formatter.string(from: Date())
                let projectName = "New_Project_\(timestamp)"
                
                // Create the project with automatic notebook generation
                if let notebookURL = windowManager.createNewProjectWithNotebook(projectName: projectName) {
                    print("✅ Created new project with notebook: \(notebookURL.lastPathComponent)")
                    
                    // Create a new project object
                    let newProject = Project(
                        name: projectName.replacingOccurrences(of: "_", with: " "),
                        type: "Data Visualization",
                        icon: "chart.bar.doc.horizontal",
                        color: .blue,
                        lastModified: Date(),
                        visualizations: 3, // Template windows created
                        dataPoints: 0,
                        collaborators: 1,
                        filename: notebookURL.lastPathComponent
                    )
                    
                    // Add to recent projects
                    await viewModel.addRecentProject(newProject)
                    
                    // Set as selected project
                    windowManager.setSelectedProject(newProject)
                    
                    print("✅ New project '\(newProject.name)' created successfully")
                } else {
                    print("❌ Failed to create notebook for new project")
                    // Still continue to open the workspace even if notebook creation failed
                }
                
                // Dismiss all sheets and open the workspace
                await MainActor.run {
                    sheetManager.dismissSheet()
                    openWindow(id: "main")
                }
                
            } catch {
                print("❌ Error creating new project: \(error)")
                // Still try to open the workspace
                await MainActor.run {
                    sheetManager.dismissSheet()
                    openWindow(id: "main")
                }
            }
        }
    }
}

// MARK: - Simple Header View
struct SimpleHeaderView: View {
    @ObservedObject var viewModel: PultoHomeViewModel
    let onLoginTap: () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pulto")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Spatial Data Visualization Platform")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 16) {
                Button {
                    onSettingsTap()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)

                Button(action: onLoginTap) {
                    HStack(spacing: 16) {
                        Image(systemName: viewModel.isUserLoggedIn ? "person.circle.fill" : "person.circle")
                            .font(.title)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.isUserLoggedIn ? viewModel.userName : "Sign In")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            if viewModel.isUserLoggedIn {
                                Text("View Profile")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.15), radius: 25, x: 0, y: 15)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

// MARK: - Primary Actions Grid
struct PrimaryActionsGrid: View {
    let sheetManager: SheetManager
    let onOpenProject: () -> Void
    let createNewProject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Get Started")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            HStack(spacing: 16) {
                HomeActionCard(
                    title: "Create New",
                    subtitle: "Start a visualization",
                    icon: "plus.square.on.square",
                    color: .blue,
                    action: createNewProject
                )

                HomeActionCard(
                    title: "Open Project", 
                    subtitle: "Browse existing projects",
                    icon: "square.and.arrow.down.on.square",
                    color: .purple
                ) {
                    onOpenProject()
                }

                HomeActionCard(
                    title: "Import",
                    subtitle: "Import jupyter notebooks",
                    icon: "folder.badge.gearshape",
                    color: .green
                ) {
                    sheetManager.dismissAllAndPresent(.templateGallery)
                }
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.15), radius: 25, x: 0, y: 15)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

// MARK: - Spatial Action Card
struct HomeActionCard: View {
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
                    .font(.system(size: 48))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(color)
                    .symbolEffect(.bounce, value: isHovered)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .padding(32)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(color.opacity(isHovered ? 0.4 : 0.1), lineWidth: isHovered ? 2 : 1)
                }
                .shadow(color: .black.opacity(isHovered ? 0.2 : 0.1), radius: isHovered ? 16 : 8, x: 0, y: isHovered ? 8 : 4)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Recent Projects Section
struct RecentProjectsSection: View {
    let projects: [Project]
    let onProjectTap: (Project) -> Void 
    let onViewAll: () -> Void 

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Projects")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()

                Button("View All") {
                    onViewAll() 
                }
                .buttonStyle(VisionOSButtonStyle(.secondary))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(Array(projects.prefix(6))) { project in
                        SpatialProjectCard(
                            project: project,
                            onTap: { onProjectTap(project) } 
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.15), radius: 25, x: 0, y: 15)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

// MARK: - Spatial Project Card
struct SpatialProjectCard: View {
    let project: Project
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Project icon area with color
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [project.color.opacity(0.4), project.color.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 100)
                    .overlay {
                        Image(systemName: project.icon)
                            .font(.system(size: 32))
                            .foregroundStyle(project.color)
                            .symbolEffect(.bounce, value: isHovered)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.filename)  
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    Text(project.type)
                        .font(.caption)
                        .foregroundStyle(project.color)

                    Text(project.lastModified, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .frame(width: 200)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(isHovered ? 0.3 : 0.1), lineWidth: isHovered ? 2 : 1)
                }
                .shadow(color: .black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 12 : 6, x: 0, y: isHovered ? 6 : 3)
        }
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Project
struct Project: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: String
    let icon: String
    private let colorString: String  // Store color as string for Codable
    let lastModified: Date
    let visualizations: Int
    let dataPoints: Int
    let collaborators: Int
    let filename: String  // Actual filename on disk
    
    // Computed property to get Color from string
    var color: Color {
        Color.fromString(colorString)
    }
    
    init(id: UUID = UUID(),
         name: String,
         type: String,
         icon: String,
         color: Color,
         lastModified: Date,
         visualizations: Int,
         dataPoints: Int,
         collaborators: Int,
         filename: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.icon = icon
        self.colorString = color.toString()
        self.lastModified = lastModified
        self.visualizations = visualizations
        self.dataPoints = dataPoints
        self.collaborators = collaborators
        // Use provided filename or generate one
        self.filename = filename ?? "\(name.replacingOccurrences(of: " ", with: "_")).ipynb"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case icon
        case colorString = "color"
        case lastModified
        case visualizations
        case dataPoints
        case collaborators
        case filename
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        icon = try container.decode(String.self, forKey: .icon)
        colorString = try container.decode(String.self, forKey: .colorString)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
        visualizations = try container.decode(Int.self, forKey: .visualizations)
        dataPoints = try container.decode(Int.self, forKey: .dataPoints)
        collaborators = try container.decode(Int.self, forKey: .collaborators)
        filename = try container.decode(String.self, forKey: .filename)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(icon, forKey: .icon)
        try container.encode(colorString, forKey: .colorString)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(visualizations, forKey: .visualizations)
        try container.encode(dataPoints, forKey: .dataPoints)
        try container.encode(collaborators, forKey: .collaborators)
        try container.encode(filename, forKey: .filename)
    }
}

// MARK: - Simple Login View
struct SimpleLoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userName: String
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var showingAppleSignIn = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Sign In to Pulto")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 20)

            VStack(spacing: 16) {
                TextField("Username", text: $userName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)

                Button("Sign In") {
                    showingAppleSignIn = true
                }
                .buttonStyle(VisionOSButtonStyle(.primary))
                .controlSize(.large)
            }
            .padding()
            
            Spacer()
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.15), radius: 25, x: 0, y: 15)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .sheet(isPresented: $showingAppleSignIn) {
            AppleSignInView()
                .frame(width: 600, height: 700)
        }
    }
}

// MARK: - Color Extensions for Codable Support
extension Color {
    func toString() -> String {
        switch self {
        case .blue: return "blue"
        case .green: return "green"
        case .purple: return "purple"
        case .orange: return "orange"
        case .red: return "red"
        case .yellow: return "yellow"
        case .pink: return "pink"
        case .cyan: return "cyan"
        case .mint: return "mint"
        case .indigo: return "indigo"
        case .teal: return "teal"
        case .brown: return "brown"
        case .gray: return "gray"
        case .black: return "black"
        case .white: return "white"
        case .clear: return "clear"
        default: return "blue" // fallback
        }
    }
    
    static func fromString(_ string: String) -> Color {
        switch string.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "yellow": return .yellow
        case "pink": return .pink
        case "cyan": return .cyan
        case "mint": return .mint
        case "indigo": return .indigo
        case "teal": return .teal
        case "brown": return .brown
        case "gray": return .gray
        case "black": return .black
        case "white": return .white
        case "clear": return .clear
        default: return .blue // fallback
        }
    }
}

// MARK: - Preview
struct PultoHomeView_Previews: PreviewProvider {
    static var previews: some View {
        PultoHomeView()
    }
}