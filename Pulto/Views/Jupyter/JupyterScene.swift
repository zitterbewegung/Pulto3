import SwiftUI
import JupyterKit

struct JupyterScene: View {
    @EnvironmentObject var settings: PultoSettings
    @EnvironmentObject var bookmarks: BookmarkStore
    @StateObject private var jm = JupyterManager()

    var body: some View {
        VStack(spacing: 12) {
            Text("Pulto — Jupyter").font(.title).bold()
            if let url = jm.url {
                JupyterWebView(url: url).frame(minWidth: 1000, minHeight: 700)
            } else {
                ProgressView("Launching embedded Python & Jupyter…")
                    .task {
                        let root = bookmarks.bookmarkedURL
                        if let r = root { _ = r.startAccessingSecurityScopedResource() }
                        await jm.startIfNeeded(ui: settings.preferredUI, root: bookmarks.bookmarkedURL)
                        if let r = bookmarks.bookmarkedURL { r.stopAccessingSecurityScopedResource() }
                    }
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text(settings.preferredUI == .lab ? "Lab" : "Notebook")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Restart") {
                    jm.stop()
                    Task { await jm.startIfNeeded(ui: settings.preferredUI, root: bookmarks.bookmarkedURL) }
                }
            }
        }
    }
}
