import SwiftUI

// Placeholder echo terminal; swap with SwiftTerm if desired in your project.
struct TerminalScene: View {
    @State private var input: String = ""
    @State private var lines: [String] = ["Pulto Terminal — demo only"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(lines.indices, id: .self) { i in
                        Text(lines[i]).font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            HStack {
                TextField("Type a command…", text: $input)
                    .textFieldStyle(.roundedBorder)
                Button("Run") {
                    if !input.isEmpty {
                        lines.append("$ " + input)
                        lines.append("echo: " + input)
                        input.removeAll()
                    }
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
