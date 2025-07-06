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
        // Simulate async data loading
        isLoadingProjects = true

        // Load user authentication state
        await loadUserState()

        // Load projects regardless of login state
        await loadRecentProjects()

        isLoadingProjects = false
    }

    func saveRecentProjects() async {
        do {
            let url = try recentProjectsFileURL()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(recentProjects)
            try data.write(to: url)
            
            // Update cache
            projectsCache = recentProjects
        } catch {
            print("Failed to save recent projects: \(error)")
        }
    }
    
    func addRecentProject(_ project: Project) async {
        // Add to beginning of array (most recent)
        recentProjects.insert(project, at: 0)
        
        // Keep only the most recent 10 projects
        if recentProjects.count > 10 {
            recentProjects = Array(recentProjects.prefix(10))
        }
        
        // Save to disk
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
            
            // Save to disk
            await saveRecentProjects()
        }
    }
    
    func removeRecentProject(_ projectId: UUID) async {
        recentProjects.removeAll { $0.id == projectId }
        await saveRecentProjects()
    }

    private func loadUserState() async {
        // Step 1: Check for stored authentication token in Keychain
        let tokenKey = "pulto.auth.token"
        let userNameKey = "pulto.userName"
        
        // Try to retrieve auth token from Keychain
        if let authToken = KeychainHelper.shared.read(key: tokenKey) {
            // Step 2: Validate token with server/auth service
            let isValid = await validateAuthToken(authToken)
            
            if isValid {
                // Token is valid, restore user state
                if let storedUserName = KeychainHelper.shared.read(key: userNameKey) {
                    userName = storedUserName
                    isUserLoggedIn = true
                } else {
                    // Token valid but no username - fetch from server
                    let userInfo = await fetchUserInfo(authToken)
                    userName = userInfo?.name ?? "User"
                    isUserLoggedIn = true
                    
                    // Store username for future use
                    KeychainHelper.shared.store(key: userNameKey, value: userName)
                }
                return
            } else {
                // Token invalid - clear stored credentials
                KeychainHelper.shared.delete(key: tokenKey)
                KeychainHelper.shared.delete(key: userNameKey)
            }
        }
        
        // Step 3: Check for remembered login preference
        let rememberLoginKey = "pulto.rememberLogin"
        if UserDefaults.standard.bool(forKey: rememberLoginKey) {
            // User previously chose to be remembered but no valid token
            // Set as guest but could trigger re-authentication
            userName = "Guest (Sign In Required)"
            isUserLoggedIn = false
        } else {
            // Fresh start - no previous login
            userName = "Guest"
            isUserLoggedIn = false
        }
    }
    
    private func validateAuthToken(_ token: String) async -> Bool {
        // In a real app, this would make an HTTP request to your auth server
        // For now, just check if token follows expected format
        return token.hasPrefix("pulto_token_") && token.count > 20
    }
    
    private func fetchUserInfo(_ token: String) async -> UserInfo? {
        // In a real app, this would make an HTTP request to your user service
        // For now, return nil to use fallback username
        return nil
    }

    private func loadRecentProjects() async {
        // Return cached projects if we already fetched them this session
        if let cached = projectsCache {
            recentProjects = cached
            return
        }

        do {
            // Get the Documents/RecentProjects directory
            guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw URLError(.fileDoesNotExist)
            }
            
            let recentProjectsDir = docsURL.appendingPathComponent("RecentProjects")
            
            // Create directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: recentProjectsDir.path) {
                try FileManager.default.createDirectory(at: recentProjectsDir, withIntermediateDirectories: true)
            }
            
            // Get all .ipynb files in the RecentProjects directory
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: recentProjectsDir,
                includingPropertiesForKeys: [.contentModificationDateKey, .nameKey],
                options: [.skipsHiddenFiles]
            )
            
            let notebookFiles = fileURLs.filter { $0.pathExtension.lowercased() == "ipynb" }
            
            // If no .ipynb files exist, create some sample ones
            if notebookFiles.isEmpty {
                try createSampleNotebooks(in: recentProjectsDir)
                
                // Re-scan the directory after creating samples
                let updatedFileURLs = try FileManager.default.contentsOfDirectory(
                    at: recentProjectsDir,
                    includingPropertiesForKeys: [.contentModificationDateKey, .nameKey],
                    options: [.skipsHiddenFiles]
                )
                
                processNotebookFiles(updatedFileURLs.filter { $0.pathExtension.lowercased() == "ipynb" })
            } else {
                processNotebookFiles(notebookFiles)
            }
            
        } catch {
            // If anything goes wrong, we'll have an empty projects array
            print("Failed to load projects from disk: \(error)")
            projectsCache = []
            recentProjects = []
        }
    }
    
    private func createSampleNotebooks(in directory: URL) throws {
        let sampleNotebooks = [
            ("Sales_Dashboard.ipynb", createSalesNotebookContent(), -3600),
            ("Climate_Model.ipynb", createClimateNotebookContent(), -7200),
            ("Stock_Analysis.ipynb", createStockNotebookContent(), -86400),
            ("Population_Data.ipynb", createPopulationNotebookContent(), -172800)
        ]
        
        for (filename, content, timeOffset) in sampleNotebooks {
            let fileURL = directory.appendingPathComponent(filename)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // Set the modification date
            let modificationDate = Date().addingTimeInterval(TimeInterval(timeOffset))
            try FileManager.default.setAttributes([.modificationDate: modificationDate], ofItemAtPath: fileURL.path)
        }
    }
    
    private func processNotebookFiles(_ fileURLs: [URL]) {
        var projects: [Project] = []
        
        for fileURL in fileURLs {
            let filename = fileURL.lastPathComponent
            let projectName = fileURL.deletingPathExtension().lastPathComponent
            
            // Get file modification date
            let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            let modificationDate = resourceValues?.contentModificationDate ?? Date()
            
            // Try to determine project type from notebook content
            let projectType = determineProjectTypeFromNotebook(fileURL) ?? "Jupyter Notebook"
            let (icon, color) = getIconAndColor(for: projectType)
            
            // Try to get stats from notebook content
            let (visualizations, dataPoints, collaborators) = getNotebookStats(fileURL)
            
            let project = Project(
                id: UUID(),
                name: projectName,
                type: projectType,
                icon: icon,
                color: color,
                lastModified: modificationDate,
                visualizations: visualizations,
                dataPoints: dataPoints,
                collaborators: collaborators,
                filename: filename
            )
            
            projects.append(project)
        }
        
        // Sort by last-modified so the newest projects appear first
        projects.sort { $0.lastModified > $1.lastModified }
        
        // Cache & publish
        projectsCache = projects
        recentProjects = projects
    }
    
    private func createSalesNotebookContent() -> String {
        return """
        {
         "cells": [
          {
           "cell_type": "markdown",
           "metadata": {},
           "source": ["# Sales Dashboard Analysis"]
          },
          {
           "cell_type": "code",
           "execution_count": null,
           "metadata": {},
           "outputs": [],
           "source": [
            "import pandas as pd\\n",
            "import matplotlib.pyplot as plt\\n",
            "import seaborn as sns\\n",
            "\\n",
            "# Load sales data\\n",
            "data = pd.read_csv('sales_data.csv')\\n",
            "\\n",
            "# Create visualization\\n",
            "plt.figure(figsize=(10, 6))\\n",
            "plt.plot(data['date'], data['revenue'])\\n",
            "plt.title('Sales Revenue Over Time')\\n",
            "plt.show()"
           ]
          }
         ],
         "metadata": {
          "kernelspec": {
           "display_name": "Python 3",
           "language": "python",
           "name": "python3"
          }
         },
         "nbformat": 4,
         "nbformat_minor": 4
        }
        """
    }
    
    private func createClimateNotebookContent() -> String {
        return """
        {
         "cells": [
          {
           "cell_type": "markdown",
           "metadata": {},
           "source": ["# Climate Model Visualization"]
          },
          {
           "cell_type": "code",
           "execution_count": null,
           "metadata": {},
           "outputs": [],
           "source": [
            "import numpy as np\\n",
            "import matplotlib.pyplot as plt\\n",
            "import plotly.graph_objects as go\\n",
            "\\n",
            "# Load climate data\\n",
            "temperature_data = pd.read_csv('climate_data.csv')\\n",
            "\\n",
            "# 3D visualization\\n",
            "fig = go.Figure()\\n",
            "fig.add_trace(go.Scatter3d(x=data.x, y=data.y, z=data.z))\\n",
            "fig.show()"
           ]
          }
         ],
         "metadata": {
          "kernelspec": {
           "display_name": "Python 3",
           "language": "python",
           "name": "python3"
          }
         },
         "nbformat": 4,
         "nbformat_minor": 4
        }
        """
    }
    
    private func createStockNotebookContent() -> String {
        return """
        {
         "cells": [
          {
           "cell_type": "markdown",
           "metadata": {},
           "source": ["# Stock Analysis - Time Series"]
          },
          {
           "cell_type": "code",
           "execution_count": null,
           "metadata": {},
           "outputs": [],
           "source": [
            "import pandas as pd\\n",
            "import numpy as np\\n",
            "from sklearn.linear_model import LinearRegression\\n",
            "import matplotlib.pyplot as plt\\n",
            "\\n",
            "# Load stock data\\n",
            "stock_data = pd.read_json('stock_prices.json')\\n",
            "\\n",
            "# Time series analysis\\n",
            "plt.figure(figsize=(12, 8))\\n",
            "plt.plot(stock_data.index, stock_data.price)\\n",
            "plt.title('Stock Price Analysis')\\n",
            "plt.show()"
           ]
          }
         ],
         "metadata": {
          "kernelspec": {
           "display_name": "Python 3",
           "language": "python",
           "name": "python3"
          }
         },
         "nbformat": 4,
         "nbformat_minor": 4
        }
        """
    }
    
    private func createPopulationNotebookContent() -> String {
        return """
        {
         "cells": [
          {
           "cell_type": "markdown",
           "metadata": {},
           "source": ["# Population Data Heatmap"]
          },
          {
           "cell_type": "code",
           "execution_count": null,
           "metadata": {},
           "outputs": [],
           "source": [
            "import pandas as pd\\n",
            "import seaborn as sns\\n",
            "import matplotlib.pyplot as plt\\n",
            "\\n",
            "# Load population data\\n",
            "pop_data = pd.read_csv('population.csv')\\n",
            "\\n",
            "# Create heatmap\\n",
            "plt.figure(figsize=(10, 8))\\n",
            "sns.heatmap(pop_data.corr(), annot=True)\\n",
            "plt.title('Population Data Correlation Heatmap')\\n",
            "plt.show()"
           ]
          }
         ],
         "metadata": {
          "kernelspec": {
           "display_name": "Python 3",
           "language": "python",
           "name": "python3"
          }
         },
         "nbformat": 4,
         "nbformat_minor": 4
        }
        """
    }
    
    private func determineProjectTypeFromNotebook(_ fileURL: URL) -> String? {
        do {
            let content = try String(contentsOf: fileURL)
            let lowercaseContent = content.lowercased()
            
            if lowercaseContent.contains("matplotlib") || lowercaseContent.contains("plotly") || lowercaseContent.contains("seaborn") {
                return "Data Visualization"
            } else if lowercaseContent.contains("pandas") || lowercaseContent.contains("dataframe") {
                return "Data Analysis"
            } else if lowercaseContent.contains("sklearn") || lowercaseContent.contains("tensorflow") || lowercaseContent.contains("pytorch") {
                return "Machine Learning"
            } else if lowercaseContent.contains("numpy") || lowercaseContent.contains("scipy") {
                return "Scientific Computing"
            } else {
                return "Jupyter Notebook"
            }
        } catch {
            return nil
        }
    }
    
    private func getNotebookStats(_ fileURL: URL) -> (Int, Int, Int) {
        do {
            let content = try String(contentsOf: fileURL)
            
            // Count visualizations (rough estimate based on plot commands)
            let plotKeywords = ["plt.show()", "plt.plot()", "plt.scatter()", "plotly", "seaborn"]
            let visualizations = plotKeywords.reduce(0) { count, keyword in
                count + content.components(separatedBy: keyword).count - 1
            }
            
            // Estimate data points (rough estimate based on data loading)
            let dataKeywords = ["pd.read_csv", "pd.read_json", "load_data"]
            let dataPoints = dataKeywords.reduce(0) { count, keyword in
                count + (content.components(separatedBy: keyword).count - 1) * 100
            }
            
            // Default collaborators to 1 (could be enhanced to read from notebook metadata)
            let collaborators = 1
            
            return (max(visualizations, 1), max(dataPoints, 50), collaborators)
        } catch {
            return (1, 50, 1)
        }
    }
    
    private func getIconAndColor(for projectType: String) -> (String, Color) {
        switch projectType.lowercased() {
        case "data visualization":
            return ("chart.bar", .blue)
        case "data analysis":
            return ("tablecells", .purple)
        case "machine learning":
            return ("brain.head.profile", .green)
        case "scientific computing":
            return ("function", .orange)
        case "3d visualization":
            return ("cube.transparent", .mint)
        default:
            return ("doc.text", .gray)
        }
    }

    private func recentProjectsFileURL() throws -> URL {
        guard let docsURL = FileManager.default.urls(for: .documentDirectory,
                                                     in: .userDomainMask).first else {
            throw URLError(.fileDoesNotExist)
        }
        return docsURL.appendingPathComponent("RecentProjects")
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
        let data = Data(value.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
/*
// MARK: - visionOS Curved Window Components

struct VisionOSWindow<Content: View>: View {
    let content: Content
    let depth: CGFloat
    
    init(depth: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.depth = depth
    }
    
    var body: some View {
        content
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
            .scaleEffect(depth > 0 ? 1.0 + (depth * 0.02) : 1.0)
    }
}
*/
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
    @State private var showCreateProject = false
    @State private var showSettings = false
    @State private var showLogin = false
    @State private var showTemplates = false
    @State private var showImportDialog = false
    @State private var showProjectBrowser = false
    @State private var showAppleSignIn = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationStack {
            ZStack {
                SpatialBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        HeaderView(viewModel: viewModel, onLoginTap: {
                            closeAllSheets()
                            showAppleSignIn = true
                        }, onSettingsTap: {
                            closeAllSheets()
                            showSettings = true
                        })

                        PrimaryActionsGrid(
                            showCreateProject: $showCreateProject,
                            showTemplates: $showTemplates,
                            showProjectBrowser: $showProjectBrowser,
                            onOpenProject: {
                                closeAllSheets()
                                openWindow(id: "main")
                            },
                            closeAllSheets: closeAllSheets
                        )

                        if viewModel.isLoadingProjects {
                            VisionOSWindow {
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text("Loading projects...")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(24)
                            }
                        } else if !viewModel.recentProjects.isEmpty {
                            RecentProjectsSection(
                                projects: viewModel.recentProjects,
                                onProjectTap: openRecentProject,
                                onViewAll: {
                                    closeAllSheets()
                                    showProjectBrowser = true
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
            .sheet(isPresented: $showCreateProject) {
                NavigationView {
                    NotebookChartsView()
                        .navigationTitle("Create New Project")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showCreateProject = false
                                }
                            }
                        }
                }
                .frame(width: 1200, height: 800)
            }
            .sheet(isPresented: $showSettings) {
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
                                showSettings = false
                            }
                        }
                    }
                }
                .frame(width: 600, height: 500)
            }
            .sheet(isPresented: $showLogin) {
                LoginView(
                    isLoggedIn: $viewModel.isUserLoggedIn,
                    userName: $viewModel.userName
                )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") {
                                showLogin = false
                            }
                        }
                    }
            }
            .sheet(isPresented: $showAppleSignIn) {
                AppleSignInView(isPresented: $showAppleSignIn)
                    .frame(width: 700, height: 800)
            }
            .fullScreenCover(isPresented: $showTemplates) {
                NotebookImportDialog(
                    isPresented: $showTemplates,
                    windowManager: windowManager
                )
            }
            .sheet(isPresented: $showProjectBrowser) {
                ProjectBrowserView(windowManager: windowManager)
            }
        }
    }

    private func closeAllSheets() {
        showCreateProject = false
        showSettings = false
        showLogin = false
        showTemplates = false
        showAppleSignIn = false
        showProjectBrowser = false
    }

    private func openRecentProject(_ project: Project) {
        Task {
            // Update the project's last modified date
            await viewModel.updateProjectLastModified(project.id)
            
            // Store the selected project in the window manager
            windowManager.setSelectedProject(project)
            
            // Close all sheets
            closeAllSheets()
            
            // Open the main spatial workspace with the selected project
            openWindow(id: "main")
        }
    }
}
/*
// MARK: - Header View
struct HeaderView: View {
    @ObservedObject var viewModel: PultoHomeViewModel
    let onLoginTap: () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        VisionOSWindow(depth: 1) {
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
                    SettingsButton(onTap: onSettingsTap)

                    UserProfileButton(
                        userName: viewModel.userName,
                        isLoggedIn: viewModel.isUserLoggedIn,
                        onTap: onLoginTap
                    )
                }
            }
            .padding(24)
        }
    }
}

// MARK: - User Profile Button
struct UserProfileButton: View {
    let userName: String
    let isLoggedIn: Bool
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: isLoggedIn ? "person.circle.fill" : "person.circle")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isLoggedIn ? userName : "Sign In")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if isLoggedIn {
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
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(isHovered ? 0.3 : 0.1), lineWidth: isHovered ? 2 : 1)
                }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
*/
// MARK: - Primary Actions Grid
struct PrimaryActionsGrid: View {
    @Binding var showCreateProject: Bool
    @Binding var showTemplates: Bool
    @Binding var showProjectBrowser: Bool
    let onOpenProject: () -> Void
    let closeAllSheets: () -> Void

    var body: some View {
        VisionOSWindow(depth: 2) {
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
                        action: onOpenProject
                    )

                    HomeActionCard(
                        title: "Open Project", 
                        subtitle: "Browse existing projects",
                        icon: "square.and.arrow.down.on.square",
                        color: .purple
                    ) {
                        closeAllSheets()
                        showProjectBrowser = true
                    }

                    HomeActionCard(
                        title: "Import",
                        subtitle: "Import jupyter notebooks",
                        icon: "folder.badge.gearshape",
                        color: .green
                    ) {
                        closeAllSheets()
                        showTemplates = true
                    }
                }
            }
            .padding(24)
        }
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
        VisionOSWindow(depth: 1) {
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
        }
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

// MARK: - Login View
struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userName: String
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var showingAppleSignIn = false

    var body: some View {
        VisionOSWindow {
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
        }
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
/*
struct SettingsButton: View {
    let onTap: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button {
            onTap()
        } label: {
            Image(systemName: "gearshape")
                .font(.title)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(isHovered ? 0.3 : 0.1), lineWidth: isHovered ? 2 : 1)
                }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
*/
