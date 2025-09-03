import SwiftUI
import Combine

// Represents a project in the UI
struct Project: Identifiable, Hashable {
    let id: UUID
    var name: String
    var type: String
    var icon: String
    var color: Color
    var lastModified: Date
    var visualizations: Int
    var dataPoints: Int
    var collaborators: Int
    var filename: String
}

@MainActor
class PultoHomeViewModel: ObservableObject {
    @Published var recentProjects: [Project] = []
    @Published var isLoadingProjects = true
    @Published var isUserLoggedIn = false
    @Published var userName = "R2-Q2"
    
    private let workspaceManager = WorkspaceManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Mock user login status
        self.isUserLoggedIn = true
        
        // Listen for workspace updates
        workspaceManager.$workspaces
            .receive(on: DispatchQueue.main)
            .map { workspaces in
                // Filter out demo projects from recent projects list
                // Recent projects should be user-created projects, not demos
                let userWorkspaces = workspaces.filter { workspace in
                    workspace.category != .demo && workspace.name != "Teapot IoT Demo"
                }
                
                return userWorkspaces.map { meta in
                    let filename = meta.name.replacingOccurrences(of: " ", with: "_") + ".pulto_workspace"
                    return Project(
                        id: meta.id,
                        name: meta.name,
                        type: meta.category.displayName,
                        icon: meta.category.iconName,
                        color: meta.category.color,
                        lastModified: meta.modifiedDate,
                        visualizations: meta.totalWindows,
                        dataPoints: 0, // Placeholder
                        collaborators: 1, // Placeholder
                        filename: filename
                    )
                }
                .sorted(by: { $0.lastModified > $1.lastModified }) // Sort by most recent
            }
            .assign(to: &$recentProjects)
    }
    
    func loadInitialData() async {
        isLoadingProjects = true
        await workspaceManager.ensureTeapotDemoProjectExists() // Ensure demo is created
        await workspaceManager.loadWorkspaces()
        isLoadingProjects = false
    }

    func addRecentProject(_ project: Project) async {
        // This would typically involve creating a new workspace file
        // For now, we just add to the UI state and assume WorkspaceManager handles persistence
        if !recentProjects.contains(where: { $0.id == project.id }) {
            recentProjects.insert(project, at: 0)
        }
    }

    func updateProjectLastModified(_ projectId: UUID) async {
        if let index = recentProjects.firstIndex(where: { $0.id == projectId }) {
            recentProjects[index].lastModified = Date()
            
            // Also update the workspace metadata
            if var workspace = workspaceManager.workspaces.first(where: { $0.id == projectId }) {
                workspace.modifiedDate = Date()
                await workspaceManager.saveWorkspaceMetadata(workspace)
            }
        }
    }
    
    // Placeholder for deleting a project
    func deleteProject(_ project: Project) async {
        recentProjects.removeAll { $0.id == project.id }
        // TODO: Add logic to delete workspace file from WorkspaceManager
    }
}