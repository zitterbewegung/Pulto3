import SwiftUI

struct WorkspaceDialogWrapper: View {
    let windowManager: WindowTypeManager
    
    var body: some View {
        Text("Workspace Dialog")
            .frame(width: 400, height: 300)
    }
}

#Preview {
    WorkspaceDialogWrapper(windowManager: WindowTypeManager())
}