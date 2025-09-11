import SwiftUI

struct JupyterLiteWindow: View {
    // Read the default Jupyter URL if one has been set elsewhere in the app
    @State private var jupyterURLString: String = UserDefaults.standard.string(forKey: "defaultJupyterURL") ?? ""

    var body: some View {
        VStack(spacing: 12) {
            Text("JupyterLite")
                .font(.system(.title, design: .rounded))
                .bold()

            Text("This is a placeholder JupyterLite window. You can replace this view with a WebView or your custom UI when ready.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let url = URL(string: jupyterURLString), !jupyterURLString.isEmpty {
                Link("Open Jupyter (\(url.absoluteString))", destination: url)
                    .font(.callout)
            } else {
                Text("No default Jupyter URL configured.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(24)
    }
}

#Preview {
    JupyterLiteWindow()
}
