import SwiftUI
import JupyterKit

struct SettingsView: View {
    @EnvironmentObject var settings: PultoSettings
    @EnvironmentObject var bookmarks: BookmarkStore
    @State private var showPicker = false

    var body: some View {
        Form {
            Section(header: Text("Interface")) {
                Picker("Jupyter UI", selection: $settings.preferredUI) {
                    ForEach(JupyterUI.allCases, id: .self) { ui in
                        Text(ui == .lab ? "JupyterLab" : "Notebook").tag(ui)
                    }
                }.pickerStyle(.segmented)
            }
            Section(header: Text("Notebook Root")) {
                if let url = bookmarks.bookmarkedURL {
                    Text(url.path).font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("Documents/").font(.footnote).foregroundStyle(.secondary)
                }
                Button("Choose Folder") { showPicker = true }
                    .sheet(isPresented: $showPicker) {
                        FolderPicker().environmentObject(bookmarks)
                    }
            }
        }
        .padding()
        .navigationTitle("Settings")
    }
}
