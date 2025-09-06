import SwiftUI

struct NotebookJSONSheet: View {
    let notebookURL: URL
    @EnvironmentObject var sheetManager: SheetManager
    @State private var jsonContent: String = "Loading..."
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack {
                if let errorMessage = errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        
                        Text("Error Loading Notebook")
                            .font(.title2)
                            .padding(.top)
                        
                        Text(errorMessage)
                            .padding()
                            .multilineTextAlignment(.center)
                        
                        Button("Close") {
                            sheetManager.dismissSheet()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        Text(jsonContent)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                }
            }
            .navigationTitle("Notebook JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        sheetManager.dismissSheet()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .task {
            await loadNotebookContent()
        }
    }
    
    private func loadNotebookContent() async {
        do {
            let data = try Data(contentsOf: notebookURL)
            if let jsonString = String(data: data, encoding: .utf8) {
                // Format JSON for better readability
                if let jsonData = jsonString.data(using: .utf8) {
                    let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
                    let prettyJSONData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted])
                    if let prettyJSONString = String(data: prettyJSONData, encoding: .utf8) {
                        await MainActor.run {
                            jsonContent = prettyJSONString
                        }
                        return
                    }
                }
                
                // Fallback to raw string if JSON parsing fails
                await MainActor.run {
                    jsonContent = jsonString
                }
            } else {
                await MainActor.run {
                    errorMessage = "Unable to read notebook file"
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error loading notebook: \(error.localizedDescription)"
            }
        }
    }
}

struct NotebookJSONSheet_Previews: PreviewProvider {
    static var previews: some View {
        NotebookJSONSheet(notebookURL: URL(string: "https://example.com")!)
    }
}