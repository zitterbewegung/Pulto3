import SwiftUI

struct PLYToJSONView: View {
    @State private var jsonString: String = ""
    @State private var showingFileImporter = false

    var body: some View {
        VStack {
            Button("Import") {
                showingFileImporter = true
            }
            .padding()

            TextEditor(text: $jsonString)
            .frame(minWidth: 300, minHeight: 200)
                .padding()
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.text],  // Assuming ASCII
            allowsMultipleSelection: false

        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    jsonString = "No file selected."
                    return
                }
                do {
                    let data = try Data(contentsOf: url)
                    if let content = String(data: data, encoding: .utf8) {
                        if let json = parsePLY(content) {
                            jsonString = json
                        } else {
                            jsonString = "Error: Invalid file."
                        }
                    } else {
                        jsonString = "Error: File is not in ASCII format or unreadable."
                    }
                } catch {
                    jsonString = "Error: \(error.localizedDescription)"
                }
            case .failure(let error):
                jsonString = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func parsePLY(_ content: String) -> String? {
        let lines = content.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }

        guard !lines.isEmpty && lines[0] == "ply" else { return nil }

        var i = 1
        var format: String?
        var vertexCount = 0
        var vertexProperties: [String] = []
        var inVertexSection = false

        while i < lines.count && lines[i] != "end_header" {
            let line = lines[i]
            let parts = line.split(separator: " ").map { String($0) }

            if parts.first == "format" && parts.count >= 2 {
                format = parts[1]
                if format != "ascii" {
                    return nil  // Binary not supported in this simple parser
                }
            } else if parts.first == "element" && parts.count >= 3 {
                if parts[1] == "vertex" {
                    vertexCount = Int(parts[2]) ?? 0
                    inVertexSection = true
                } else {
                    inVertexSection = false
                }
            } else if inVertexSection && parts.first == "property" && parts.count >= 3 {
                let propName = parts.last!
                vertexProperties.append(propName)
            }

            i += 1
        }

        guard lines[i] == "end_header" && vertexCount > 0 else { return nil }
        i += 1  // Move to data section

        // Find indices of x, y, z properties
        guard let xIndex = vertexProperties.firstIndex(of: "x"),
              let yIndex = vertexProperties.firstIndex(of: "y"),
              let zIndex = vertexProperties.firstIndex(of: "z") else {
            return nil
        }

        // Parse vertex data
        var points: [[String: Double]] = []
        let dataEnd = min(i + vertexCount, lines.count)
        for j in i..<dataEnd {
            let line = lines[j]
            let values = line.split(separator: " ").map { String($0) }
            guard values.count >= vertexProperties.count else { continue }

            if let x = Double(values[xIndex]),
               let y = Double(values[yIndex]),
               let z = Double(values[zIndex]) {
                points.append(["x": x, "y": y, "z": z])
            }
        }

        // Create JSON structure
        let chartData: [String: Any] = [
            "title": "Sample 3D Chart",
            "chartType": "scatter",
            "points": points
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: chartData, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

#Preview {
    PLYToJSONView()
}
