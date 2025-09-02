// Since I don't have access to this file, I'll assume it has a deleteProject method.
// If it doesn't exist, you'll need to implement it in your PultoHomeViewModel.
//
// Add this method to your PultoHomeViewModel:
//
// func deleteProject(_ project: Project) async {
//     // Remove from recent projects list
//     recentProjects.removeAll { $0.id == project.id }
//     
//     // Delete associated files/workspace if needed
//     // This would depend on your project structure
//     // For example:
//     // await WorkspaceManager.shared.deleteWorkspace(for: project)
//     
//     // Update UserDefaults or other persistence
//     // updateRecentProjectsStorage()
// }