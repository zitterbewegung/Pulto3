import SwiftUI
import UniformTypeIdentifiers

struct UnifiedImportSheet: View {
    @EnvironmentObject private var windowManager: WindowTypeManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    @State private var selectedFileType: FileType = .unknown
    @State private var importedFileURL: URL?
    @State private var pointCloudData: PointCloudData?
    @State private var errorMessage: String?
    @State private var isProcessing = false
    
    enum FileType {
        case unknown
        case csv
        case pointCloudPLY
        case pointCloudXYZ
        case pointCloudPCD
        case pointCloudPTS
        case modelUSDZ
        case modelOBJ
        case modelSTL
        
        var description: String {
            switch self {
            case .unknown: return "Unknown File"
            case .csv: return "CSV Data File"
            case .pointCloudPLY: return "PLY Point Cloud"
            case .pointCloudXYZ: return "XYZ Point Cloud"
            case .pointCloudPCD: return "PCD Point Cloud"
            case .pointCloudPTS: return "PTS Point Cloud"
            case .modelUSDZ: return "USDZ 3D Model"
            case .modelOBJ: return "OBJ 3D Model"
            case .modelSTL: return "STL 3D Model"
            }
        }
        
        var icon: String {
            switch self {
            case .unknown: return "doc"
            case .csv: return "tablecells"
            case .pointCloudPLY, .pointCloudXYZ, .pointCloudPCD, .pointCloudPTS: return "circle.grid.3x3"
            case .modelUSDZ, .modelOBJ, .modelSTL: return "cube"
            }
        }
        
        var color: Color {
            switch self {
            case .unknown: return .gray
            case .csv: return .green
            case .pointCloudPLY, .pointCloudXYZ, .pointCloudPCD, .pointCloudPTS: return .cyan
            case .modelUSDZ, .modelOBJ, .modelSTL: return .red
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isProcessing {
                    processingView
                } else if pointCloudData != nil {
                    pointCloudPreviewView
                } else {
                    welcomeView
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Dismiss") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Import File")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [
                    .commaSeparatedText,    // CSV files
                    .plainText,             // For XYZ/PTS files
                    .usdz,                  // USDZ files
                    .data                   // Fallback for any file type
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 30) {
            Image(systemName: "arrow.up.doc")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Import File")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Select a file to import into Pulto")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Supported Formats Section
            VStack(alignment: .leading, spacing: 20) {
                Text("Supported Formats")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 16) {
                    UnifiedImportFormatCard(
                        title: "Data Files", 
                        formats: ["CSV"], 
                        icon: "tablecells", 
                        color: .green
                    )
                    UnifiedImportFormatCard(
                        title: "Point Clouds", 
                        formats: ["PLY", "XYZ", "PCD", "PTS"], 
                        icon: "circle.grid.3x3", 
                        color: .cyan
                    )
                    UnifiedImportFormatCard(
                        title: "3D Models", 
                        formats: ["USDZ", "OBJ", "STL"], 
                        icon: "cube", 
                        color: .red
                    )
                }
            }
            
            Button(action: { isImporting = true }) {
                Label("Choose File", systemImage: "folder")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Processing File...")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let fileType = getFileType() {
                HStack {
                    Image(systemName: fileType.icon)
                        .font(.title)
                        .foregroundColor(fileType.color)
                    
                    Text(fileType.description)
                        .font(.headline)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var pointCloudPreviewView: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "circle.grid.3x3")
                    .font(.title)
                    .foregroundColor(.cyan)
                
                Text("Point Cloud Preview")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding(.horizontal)
            
            if let data = pointCloudData {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("File:")
                        Spacer()
                        Text(importedFileURL?.lastPathComponent ?? "Unknown")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Points:")
                        Spacer()
                        Text("\(data.totalPoints)")

                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Format:")
                        Spacer()
                        Text(selectedFileType.description)
                            .fontWeight(.medium)
                    }
                    
                    if !data.points.isEmpty {
                        // Show a simple preview of the point cloud bounds
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bounds:")
                                .font(.headline)
                            
                            let xValues = data.points.map { $0.x }
                            let yValues = data.points.map { $0.y }
                            let zValues = data.points.map { $0.z }
                            
                            HStack {
                                Text("X:")
                                Spacer()
                                Text(String(format: "%.2f to %.2f", xValues.min()!, xValues.max()!))
                            }
                            
                            HStack {
                                Text("Y:")
                                Spacer()
                                Text(String(format: "%.2f to %.2f", yValues.min()!, yValues.max()!))
                            }
                            
                            HStack {
                                Text("Z:")
                                Spacer()
                                Text(String(format: "%.2f to %.2f", zValues.min()!, zValues.max()!))
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    pointCloudData = nil
                    importedFileURL = nil
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(action: openInVolumetricView) {
                    Label("Open in 3D View", systemImage: "eye")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importedFileURL = url
            isProcessing = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.classifyAndProcessFile(url)
            }
            
        case .failure(let error):
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }
    
    private func classifyAndProcessFile(_ url: URL) {
        guard let fileExtension = url.pathExtension.lowercased().nilIfEmpty else {
            DispatchQueue.main.async {
                self.errorMessage = "File has no extension"
                self.isProcessing = false
            }
            return
        }
        
        // Classify file type
        switch fileExtension {
        case "csv":
            selectedFileType = .csv
        case "ply":
            selectedFileType = .pointCloudPLY
        case "xyz":
            selectedFileType = .pointCloudXYZ
        case "pcd":
            selectedFileType = .pointCloudPCD
        case "pts":
            selectedFileType = .pointCloudPTS
        case "usdz":
            selectedFileType = .modelUSDZ
        case "obj":
            selectedFileType = .modelOBJ
        case "stl":
            selectedFileType = .modelSTL
        default:
            selectedFileType = .unknown
        }
        
        // Process based on file type
        switch selectedFileType {
        case .pointCloudPLY, .pointCloudXYZ, .pointCloudPCD, .pointCloudPTS:
            processPointCloudFile(url)
        case .modelUSDZ, .modelOBJ, .modelSTL:
            processModelFile(url)
        case .csv:
            processCSVFile(url)
        case .unknown:
            DispatchQueue.main.async {
                self.errorMessage = "Unsupported file type: \(fileExtension)"
                self.isProcessing = false
            }
        }
    }
    
    private func processPointCloudFile(_ url: URL) {
        let data: PointCloudData?
        
        switch selectedFileType {
        case .pointCloudPLY:
            data = parsePLYFile(url)
        case .pointCloudXYZ:
            data = parseXYZFile(url)
        case .pointCloudPCD:
            data = parsePCDFile(url)
        case .pointCloudPTS:
            data = parsePTSFile(url)
        default:
            data = nil
        }
        
        DispatchQueue.main.async {
            self.isProcessing = false
            
            if let data = data {
                self.pointCloudData = data
            } else {
                self.errorMessage = "Failed to parse point cloud file"
            }
        }
    }
    
    private func processModelFile(_ url: URL) {
        DispatchQueue.main.async {
            self.isProcessing = false
            
            // Create window for 3D model
            let id = self.windowManager.getNextWindowID()
            let position = WindowPosition(x: 100, y: 100, z: 0, width: 800, height: 600)
            
            _ = self.windowManager.createWindow(.model3d, id: id, position: position)
            
            do {
                let bookmark = try url.bookmarkData(options: .minimalBookmark)
                self.windowManager.updateUSDZBookmark(for: id, bookmark: bookmark)
            } catch {
                print("Error creating bookmark: \(error)")
            }
            
            #if os(visionOS)
            self.openWindow(id: "volumetric-model3d", value: id)
            #endif
            
            self.windowManager.markWindowAsOpened(id)
            self.dismiss()
        }
    }
    
    private func processCSVFile(_ url: URL) {
        DispatchQueue.main.async {
            self.isProcessing = false
            
            // For CSV, we'll just open the standard import process
            // You might want to add specific CSV processing here
            self.dismiss()
        }
    }
    
    private func openInVolumetricView() {
        guard let data = pointCloudData else { return }
        
        let id = windowManager.getNextWindowID()
        let position = WindowPosition(x: 100, y: 100, z: 0, width: 800, height: 600)
        
        _ = windowManager.createWindow(.pointcloud, id: id, position: position)
        windowManager.updateWindowPointCloud(id, pointCloud: data)
        windowManager.markWindowAsOpened(id)
        
        #if os(visionOS)
        openWindow(id: "volumetric-pointcloud", value: id)
        #endif
        
        dismiss()
    }
    
    // MARK: - File Parsers
    private func parsePLYFile(_ url: URL) -> PointCloudData? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            guard let headerStr = String(data: data.prefix(1024), encoding: .ascii) else { return nil }
            
            guard let endRange = headerStr.range(of: "end_header\n") else { return nil }
            let header = String(headerStr[..<endRange.upperBound])
            let headerLines = header.components(separatedBy: .newlines)
            
            var format = "ascii 1.0"
            var vertexCount = 0
            var propList = [String]()
            var propTypes = [String]()
            
            for line in headerLines {
                let parts = line.components(separatedBy: " ")
                if parts.count > 1 {
                    if parts[0] == "format" {
                        format = parts[1...].joined(separator: " ")
                    } else if parts[0] == "element" && parts[1] == "vertex" {
                        vertexCount = Int(parts[2]) ?? 0
                    } else if parts[0] == "property" {
                        propTypes.append(parts[1])
                        propList.append(parts.last ?? "")
                    }
                }
            }
            
            let bodyStart = header.utf8CString.count - 1 // Account for null terminator or line break
            let bodyData = data.subdata(in: bodyStart..<data.count)
            
            var points = [PointCloudData.PointData]()
            
            if format.hasPrefix("ascii") {
                guard let bodyStr = String(data: bodyData, encoding: .ascii) else { return nil }
                let bodyLines = bodyStr.components(separatedBy: .newlines).filter { !$0.isEmpty }
                
                for line in bodyLines.prefix(vertexCount) {
                    let values = line.components(separatedBy: " ").compactMap { Float($0) }
                    if values.count >= 3 {
                        points.append(PointCloudData.PointData(
                            x: Double(values[0]), 
                            y: Double(values[1]), 
                            z: Double(values[2])
                        ))
                    }
                }
            } else if format.hasPrefix("binary") {
                let isBigEndian = format.contains("big_endian")
                var offset = 0
                let xIndex = propList.firstIndex(of: "x") ?? -1
                let yIndex = propList.firstIndex(of: "y") ?? -1
                let zIndex = propList.firstIndex(of: "z") ?? -1
                if xIndex == -1 || yIndex == -1 || zIndex == -1 { return nil }
                
                for _ in 0..<vertexCount {
                    var x: Float = 0, y: Float = 0, z: Float = 0
                    for propIndex in 0..<propList.count {
                        let propType = propTypes[propIndex]
                        let size: Int
                        switch propType {
                        case "float32", "float":
                            size = 4
                        case "double":
                            size = 8
                        case "int32", "uint32":
                            size = 4
                        case "uchar", "uint8":
                            size = 1
                        default:
                            size = 4 // Default to 4 bytes
                        }
                        let propData = bodyData.subdata(in: offset..<offset + size)
                        offset += size
                        
                        let value: Float
                        switch size {
                        case 4:
                            let uint32 = propData.withUnsafeBytes { $0.load(as: UInt32.self) }
                            let finalUInt32 = isBigEndian ? uint32.bigEndian : uint32.littleEndian
                            value = Float(bitPattern: finalUInt32)
                        case 8:
                            let uint64 = propData.withUnsafeBytes { $0.load(as: UInt64.self) }
                            let finalUInt64 = isBigEndian ? uint64.bigEndian : uint64.littleEndian
                            value = Float(bitPattern: UInt32(finalUInt64)) // Approximate
                        default:
                            value = 0
                        }
                        
                        if propIndex == xIndex { x = value }
                        else if propIndex == yIndex { y = value }
                        else if propIndex == zIndex { z = value }
                    }
                    points.append(PointCloudData.PointData(
                        x: Double(x), 
                        y: Double(y), 
                        z: Double(z)
                    ))
                }
            }
            
            var pc = PointCloudData(
                title: url.lastPathComponent,
                demoType: "ply-import",
                points: points
            )
            pc.totalPoints = points.count
            return pc
        } catch {
            print("PLY parse error: \(error)")
            return nil
        }
    }
    
    private func parseXYZFile(_ url: URL) -> PointCloudData? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            var points: [PointCloudData.PointData] = []
            
            for line in lines {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if components.count >= 3,
                   let x = Double(components[0]),
                   let y = Double(components[1]),
                   let z = Double(components[2]) {
                    let intensity = components.count > 3 ? Double(components[3]) : nil
                    points.append(PointCloudData.PointData(x: x, y: y, z: z, intensity: intensity))
                }
            }
            
            var pc = PointCloudData(
                title: url.lastPathComponent,
                demoType: "xyz-import",
                points: points
            )
            pc.totalPoints = points.count
            return pc
            
        } catch {
            print("Error parsing XYZ file: \(error)")
            return nil
        }
    }
    
    private func parsePCDFile(_ url: URL) -> PointCloudData? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            // Find DATA line to know where point data starts
            guard let dataIndex = lines.firstIndex(where: { $0.hasPrefix("DATA") }) else {
                return nil
            }
            
            var points: [PointCloudData.PointData] = []
            
            // Parse points starting after DATA line
            for line in lines.dropFirst(dataIndex + 1) {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if components.count >= 3,
                   let x = Double(components[0]),
                   let y = Double(components[1]),
                   let z = Double(components[2]) {
                    let intensity = components.count > 3 ? Double(components[3]) : nil
                    points.append(PointCloudData.PointData(x: x, y: y, z: z, intensity: intensity))
                }
            }
            
            var pc = PointCloudData(
                title: url.lastPathComponent,
                demoType: "pcd-import",
                points: points
            )
            pc.totalPoints = points.count
            return pc
            
        } catch {
            print("Error parsing PCD file: \(error)")
            return nil
        }
    }
    
    private func parsePTSFile(_ url: URL) -> PointCloudData? {
        // PTS files are often similar to XYZ, try the same parsing
        return parseXYZFile(url)
    }
    
    private func getFileType() -> FileType? {
        guard let url = importedFileURL else { return nil }
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "csv": return .csv
        case "ply": return .pointCloudPLY
        case "xyz": return .pointCloudXYZ
        case "pcd": return .pointCloudPCD
        case "pts": return .pointCloudPTS
        case "usdz": return .modelUSDZ
        case "obj": return .modelOBJ
        case "stl": return .modelSTL
        default: return .unknown
        }
    }
}

// MARK: - Format Card
struct UnifiedImportFormatCard: View {
    let title: String
    let formats: [String]
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.headline)
            }
            Text(formats.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Helper Extension
extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

#Preview {
    UnifiedImportSheet()
        .environmentObject(WindowTypeManager.shared)
}
