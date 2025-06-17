import SwiftUI
import UIKit
import Foundation
import RealityKit

struct NotebookChartsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var result: String = "No response yet"
    @State private var chartImages: [String: [UIImage]] = [:]
    @State private var chartOffsets: [String: CGSize] = [:]
    @State private var debugMode: Bool = true
    @State private var notebookName: String = ""
    @State private var tapped = false
    @State private var modelLoadingError: Error?
    @State private var isLoading = false
    @State private var showingSidebar = true

    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // Header with Close Button
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.title2)
                                .foregroundStyle(.blue)

                            Text("Notebooks")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        // Close button in sidebar
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .background(Circle().fill(.ultraThinMaterial))
                        }
                        .buttonStyle(.plain)
                    }

                    // Search/Input Field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("Notebook name (e.g., Pulto.ipynb)", text: $notebookName)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()

                // Actions Section
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Actions")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Button(action: openNotebook) {
                            HStack {
                                Image(systemName: "folder.badge.plus")
                                    .foregroundStyle(.blue)
                                Text("Open Notebook")
                                    .fontWeight(.medium)
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading || notebookName.isEmpty)
                    }

                    // Recent Files Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        ForEach(["Analysis.ipynb", "DataViz.ipynb", "Research.ipynb"], id: \.self) { name in
                            Button(action: { notebookName = name }) {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundStyle(.orange)
                                    Text(name)
                                        .font(.body)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.quaternary.opacity(0.5))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Status Section
                VStack(alignment: .leading, spacing: 8) {
                    if !result.contains("No response yet") {
                        Text("Status")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(result)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(minWidth: 280, maxWidth: 320)
            .background(.regularMaterial)
        } detail: {
            // Main Content Area
            ZStack {
                if chartImages.isEmpty && !isLoading {
                    // Empty State
                    VStack(spacing: 24) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 64))
                            .foregroundStyle(.tertiary)

                        VStack(spacing: 8) {
                            Text("Import Your Notebook")
                                .font(.title)
                                .fontWeight(.semibold)

                            Text("Enter a notebook name and tap 'Open Notebook' to visualize your charts in spatial computing.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isLoading {
                    // Loading State
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Processing notebook...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Charts Display
                    chartContentView
                }
            }
            .background(.ultraThinMaterial)
            .navigationTitle("Spatial Notebook")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear {
            loadModel()
        }
        // Add keyboard dismiss gesture
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private var chartContentView: some View {
        ScrollView {
            LazyVStack(spacing: 32) {
                ForEach(Array(chartImages.keys.sorted()), id: \.self) { chartKey in
                    chartCardView(for: chartKey)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
    }

    private func chartCardView(for chartKey: String) -> some View {
        let images = chartImages[chartKey] ?? []

        return VStack(alignment: .leading, spacing: 16) {
            // Card Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chart \(chartKey.replacingOccurrences(of: "chartKey_", with: ""))")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Interactive visualization ready for spatial placement")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: {
                    Task { await sendNotebookJSON(named: notebookName) }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Chart Images
            ForEach(0..<images.count, id: \.self) { idx in
                VStack(spacing: 12) {
                    Image(uiImage: images[idx])
                        .resizable()
                        .scaledToFit()
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .offset(chartOffsets[chartKey] ?? .zero)
                        .scaleEffect(tapped ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: tapped)
                        .gesture(
                            SimultaneousGesture(
                                TapGesture()
                                    .onEnded { _ in
                                        withAnimation {
                                            tapped.toggle()
                                        }
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        chartOffsets[chartKey] = value.translation
                                        debugLog("Dragging \(chartKey): \(value.translation)")
                                    }
                                    .onEnded { _ in
                                        Task {
                                            await sendNotebookJSON(named: notebookName)
                                        }
                                    }
                            )
                        )

                    // Position Indicator
                    if let offset = chartOffsets[chartKey], offset != .zero {
                        HStack {
                            Image(systemName: "move.3d")
                                .foregroundStyle(.blue)
                            Text("Position: (\(Int(offset.width)), \(Int(offset.height)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, idx == images.count - 1 ? 20 : 0)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private func openNotebook() {
        Task {
            isLoading = true
            await sendNotebookJSON(named: notebookName)
            isLoading = false
        }
    }

    private func loadModel() {
        Task {
            do {
                let modelURL = Bundle.main.url(forResource: "Pulto_1_2374", withExtension: "usdz")
                debugLog("Model URL: \(String(describing: modelURL))")

                let _ = try await Model3D(named: "Pulto_1_2374.usdz")
                debugLog("Model loaded successfully")
            } catch {
                modelLoadingError = error
                debugLog("Error loading model: \(error)")
            }
        }
    }

    // MARK: - Existing Functions (unchanged)

    func decodeBase64ToImage(base64String: String) -> UIImage? {
        debugLog("Decoding base64 string to UIImage")
        guard let imageData = Data(base64Encoded: base64String) else {
            debugLog("Failed to decode base64 string into Data")
            return nil
        }
        guard let image = UIImage(data: imageData) else {
            debugLog("Failed to create UIImage from Data")
            return nil
        }
        debugLog("Successfully decoded image")
        return image
    }

    struct ChartImage: Codable {
        // Dictionary: chartKey -> array of base64 images
    }

    struct NotebookConversionResponse: Codable {
        var charts: [String: [String]]

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawDictionary = try container.decode([String: [String]].self)

            charts = [:]
            for (key, value) in rawDictionary {
                if key.hasPrefix("chartKey_") {
                    charts[key] = value
                }
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(charts)
        }
    }

    func convertNotebook(filePath: String, completion: @escaping (Result<NotebookConversionResponse, Error>) -> Void) {
        guard var components = URLComponents(string: "http://selle:8000/convert") else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid base URL"])))
            return
        }
        components.queryItems = [URLQueryItem(name: "file_path", value: filePath)]

        guard let url = components.url else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not construct URL with file path"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No HTTP response received"])))
                return
            }

            if !(200...299).contains(httpResponse.statusCode) {
                let errorDescription = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                completion(.failure(NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode) - \(errorDescription)"])))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "DataError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let decoder = JSONDecoder()
                let conversionResponse = try decoder.decode(NotebookConversionResponse.self, from: data)
                completion(.success(conversionResponse))
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }

    func processNotebookConversion(filePath: String) {
        convertNotebook(filePath: filePath) { result in
            switch result {
            case .success(let response):
                debugLog("Successfully converted notebook!")
                for (chartKey, base64Images) in response.charts {
                    debugLog("Chart Key: \(chartKey)")
                    for (index, base64Image) in base64Images.enumerated() {
                        debugLog("Image \(index + 1): \(base64Image.prefix(50))...")

                        if let imageData = Data(base64Encoded: base64Image) {
                            // Process image data
                        } else {
                            debugLog("Invalid base64 string. Could not convert to Data.")
                        }
                    }
                }

            case .failure(let error):
                debugLog("Error converting notebook: \(error)")
                if let nsError = error as NSError? {
                    debugLog("Domain: \(nsError.domain)")
                    debugLog("Code: \(nsError.code)")
                    debugLog("Description: \(nsError.localizedDescription)")
                    if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                        debugLog("Underlying Error: \(underlyingError)")
                    }
                }
            }
        }
    }

    func ensureNotebookExistsInDocuments() -> URL? {
        let fileManager = FileManager.default
        guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            debugLog("Failed to locate Documents directory")
            return nil
        }

        let notebookDocURL = docsURL.appendingPathComponent("notebook.ipynb")

        if !fileManager.fileExists(atPath: notebookDocURL.path) {
            if let bundleURL = Bundle.main.url(forResource: "notebook", withExtension: "ipynb") {
                do {
                    try fileManager.copyItem(at: bundleURL, to: notebookDocURL)
                    debugLog("Copied notebook file from bundle to Documents at \(notebookDocURL.path)")
                } catch {
                    debugLog("Failed to copy notebook file: \(error.localizedDescription)")
                    return nil
                }
            } else {
                debugLog("Notebook file not found in bundle")
                return nil
            }
        } else {
            debugLog("Notebook file already exists in Documents at \(notebookDocURL.path)")
        }

        return notebookDocURL
    }

    func sendNotebookJSON(named name: String) async {
        debugLog("Preparing notebook JSON from Documents directory")

        guard let notebookFileURL = ensureNotebookExistsInDocuments() else {
            await MainActor.run {
                result = "Failed to ensure notebook file exists in Documents"
            }
            return
        }

        let chartPositions: [String: [String: CGFloat]] = chartOffsets.mapValues { size in
            ["x": size.width, "y": size.height]
        }

        guard let fileData = try? Data(contentsOf: notebookFileURL) else {
            debugLog("Failed to read notebook file at \(notebookFileURL.path)")
            await MainActor.run {
                result = "Failed to read notebook file"
            }
            return
        }

        guard var notebookDict = try? JSONSerialization.jsonObject(with: fileData, options: []) as? [String: Any] else {
            debugLog("Failed to parse notebook JSON from file")
            await MainActor.run {
                result = "Invalid notebook file JSON"
            }
            return
        }

        if var metadata = notebookDict["metadata"] as? [String: Any] {
            metadata["chartPositions"] = chartPositions
            notebookDict["metadata"] = metadata
        } else {
            notebookDict["metadata"] = ["chartPositions": chartPositions]
        }

        guard let notebookJSONData = try? JSONSerialization.data(withJSONObject: notebookDict, options: .prettyPrinted) else {
            debugLog("Failed to serialize updated notebook dictionary to JSON")
            await MainActor.run {
                result = "Failed to serialize dictionary to JSON"
            }
            return
        }

        guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "http://selle:8000/convert/\(encodedName)") else {
            debugLog("Invalid URL")
            await MainActor.run {
                result = "Invalid URL"
            }
            return
        }

        var request_update = URLRequest(url: url)
        request_update.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request_update.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"notebook.ipynb\"\r\n")
        body.append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(notebookJSONData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        request_update.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request_update)
            if let httpResponse = response as? HTTPURLResponse {
                debugLog("Received response: \(httpResponse.statusCode)")
            }

            if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []),
               let responseDict = jsonResponse as? [String: Any] {
                debugLog("Decoded JSON response: \(responseDict)")

                if responseDict["nbformat"] != nil {
                    if let updatedData = try? JSONSerialization.data(withJSONObject: responseDict, options: .prettyPrinted) {
                        do {
                            try updatedData.write(to: notebookFileURL)
                            debugLog("Local notebook file updated at: \(notebookFileURL.path)")
                            await MainActor.run {
                                result = "Local notebook file updated."
                            }
                        } catch {
                            debugLog("Failed to write updated notebook file: \(error.localizedDescription)")
                            await MainActor.run {
                                result = "Failed to update local file."
                            }
                        }
                    } else {
                        debugLog("Failed to re-serialize updated notebook dictionary.")
                        await MainActor.run {
                            result = "Failed to update local file."
                        }
                    }
                } else {
                    var decodedCharts: [String: [UIImage]] = [:]
                    for (key, value) in responseDict {
                        if let imageArray = value as? [String] {
                            var uiImages: [UIImage] = []
                            for base64Str in imageArray {
                                if let img = decodeBase64ToImage(base64String: base64Str) {
                                    uiImages.append(img)
                                }
                            }
                            if !uiImages.isEmpty {
                                decodedCharts[key] = uiImages
                            }
                        }
                    }

                    await MainActor.run {
                        if decodedCharts.isEmpty {
                            debugLog("No images found in response")
                            if let responseString = String(data: data, encoding: .utf8) {
                                result = "Success, but no images found:\n\(responseString)"
                            } else {
                                result = "Success but unable to decode response."
                            }
                        } else {
                            chartImages = decodedCharts
                            result = "Images decoded successfully"
                        }
                    }
                }
            } else {
                debugLog("Failed to decode JSON response")
                await MainActor.run {
                    if let responseString = String(data: data, encoding: .utf8) {
                        result = "Success:\n\(responseString)"
                    } else {
                        result = "Success but unable to decode response."
                    }
                }
            }
        } catch {
            debugLog("Error occurred: \(error.localizedDescription)")
            await MainActor.run {
                result = "Error: \(error.localizedDescription)"
            }
        }
    }

    func updateSpatial(forNotebook notebookName: String) {
        guard let url = URL(string: "http://selle:8000/notebooks/\(notebookName)/cells/0/spatial") else {
            debugLog("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "x": 1,
            "y": 1,
            "z": 1,
            "pitch": 0,
            "yaw": 0,
            "roll": 0
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            debugLog("Error serializing JSON: \(error)")
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                debugLog("Request error: \(error)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                debugLog("Status code: \(httpResponse.statusCode)")
            }

            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                debugLog("Response: \(responseString)")
            }
        }

        task.resume()
    }

    func debugLog(_ message: String) {
        if debugMode {
            print("[DEBUG]: \(message)")
        }
    }
}

// Helper to append strings to Data body
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}

// Usage example showing how to present it modally
struct ContentView: View {
    @State private var showingNotebook = false

    var body: some View {
        Button("Show Notebook Charts") {
            showingNotebook = true
        }
        .sheet(isPresented: $showingNotebook) {
            NotebookChartsView()
        }
    }
}

#Preview {
    NotebookChartsView()
}
