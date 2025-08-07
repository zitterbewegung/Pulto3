import SwiftUI

struct NotebookImportDialogWrapper: View {
    let windowManager: WindowTypeManager
    
    var body: some View {
        Text("Notebook Import Dialog")
            .frame(width: 400, height: 300)
    }
}

#Preview {
    NotebookImportDialogWrapper(windowManager: WindowTypeManager())
}