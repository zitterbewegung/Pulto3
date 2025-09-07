import SwiftUI
import JupyterKit

struct LauncherView: View {
    @EnvironmentObject var settings: PultoSettings
    @EnvironmentObject var bookmarks: BookmarkStore
    @Environment(.openWindow) private var openWindow
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Pulto — Launcher").font(.largeTitle).bold()

            Picker("Jupyter UI", selection: $settings.preferredUI) {
                Text("JupyterLab").tag(JupyterUI.lab)
                Text("Notebook (Classic)").tag(JupyterUI.notebook)
            }.pickerStyle(.segmented).frame(maxWidth: 420)

            if let url = bookmarks.bookmarkedURL {
                Text("Notebook Root: \(url.path)").font(.footnote).foregroundStyle(.secondary)
            } else {
                Text("Notebook Root: Documents/").font(.footnote).foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("Choose Notebook Folder") { showPicker = true }
                    .buttonStyle(.bordered)
                    .sheet(isPresented: $showPicker) {
                        FolderPicker().environmentObject(bookmarks)
                    }

                Button {
                    openWindow(id: WindowType.jupyter.rawValue)
                } label: {
                    Text("Open Jupyter").font(.title3).bold().padding().frame(maxWidth: 320)
                }.buttonStyle(.borderedProminent)
            }

            Button("Open Terminal") { openWindow(id: WindowType.terminal.rawValue) }
                .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
    }
}

struct FolderPicker: UIViewControllerRepresentable {
    @EnvironmentObject var bookmarks: BookmarkStore

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FolderPicker
        init(_ parent: FolderPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            parent.bookmarks.saveBookmark(for: url)
            url.stopAccessingSecurityScopedResource()
        }
    }
}
