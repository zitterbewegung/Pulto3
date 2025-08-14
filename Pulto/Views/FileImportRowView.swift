import SwiftUI
import UniformTypeIdentifiers
import Foundation

struct FileImportRowView: View {
    @State private var selectedFolderURL: URL?
    @State private var files: [FileInfo] = []
    @State private var isFolderPickerPresented = false
    
    let onImportFile: (URL) -> Void
    
    struct FileInfo: Identifiable {
        let id = UUID()
        let url: URL
        let name: String
        let size: String
        let type: FileType
        let icon: String
    }
    
    enum FileType {
        case usdz
        case pointCloud
        case unknown
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Import Files")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    isFolderPickerPresented = true
                }) {
                    Label("Select Folder", systemImage: "folder.badge.plus")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Content area
            contentView
        }
        .padding()
        .background(Color.gray.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .fileImporter(
            isPresented: $isFolderPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let folderURL = urls.first {
                    selectedFolderURL = folderURL
                    loadFiles(from: folderURL)
                }
            case .failure(let error):
                print("Error selecting folder: \(error)")
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if !files.isEmpty {
            // Show files when available
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(files) { file in
                        FileCardView(
                            file: file,
                            onTap: { onImportFile(file.url) }
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 180)
        } else if selectedFolderURL != nil {
            // Show message when folder selected but no compatible files found
            ContentUnavailableView(
                "No Compatible Files Found",
                systemImage: "doc.badge.plus",
                description: Text("The selected folder doesn't contain any .usdz or point cloud files (.ply, .pcd, .xyz, .pts)")
            )
            .frame(height: 180)
        } else {
            // Show initial placeholder when no folder selected
            placeholderView
        }
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.fill.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.blue.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Folder Selected")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Select a folder to browse compatible 3D models and point cloud files")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Supported formats:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    Label("USDZ", systemImage: "cube")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    
                    Label("Point Clouds", systemImage: "circle.grid.3x3")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                }
                .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundStyle(Color.gray.opacity(0.2))
        )
    }
    
    private func loadFiles(from folderURL: URL) {
        files.removeAll()
        
        guard let fileEnumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        for case let fileURL as URL in fileEnumerator {
            let fileName = fileURL.lastPathComponent
            let fileExtension = fileURL.pathExtension.lowercased()
            
            // Check if it's a compatible file type
            let fileType: FileType
            let icon: String
            
            switch fileExtension {
            case "usdz":
                fileType = .usdz
                icon = "cube"
            case "ply", "pcd", "xyz", "pts":
                fileType = .pointCloud
                icon = "circle.grid.3x3"
            default:
                continue // Skip unsupported files
            }
            
            // Get file size
            let fileSizeString: String
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let fileSize = attributes[FileAttributeKey.size] as? NSNumber {
                    fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize.int64Value, countStyle: .file)
                } else {
                    fileSizeString = "Unknown size"
                }
            } catch {
                fileSizeString = "Unknown size"
            }
            
            files.append(FileInfo(
                url: fileURL,
                name: fileName,
                size: fileSizeString,
                type: fileType,
                icon: icon
            ))
        }
    }
}

struct FileCardView: View {
    let file: FileImportRowView.FileInfo
    let onTap: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // File icon
                ZStack {
                    Circle()
                        .fill(getFileColor(for: file.type).opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: file.icon)
                        .font(.title2)
                        .foregroundColor(getFileColor(for: file.type))
                }
                
                // File name
                Text(file.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                // File size
                Text(file.size)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 120, height: 140)
            .padding(12)
            .background(Color.gray.opacity(isHovered ? 0.1 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? getFileColor(for: file.type).opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    private func getFileColor(for type: FileImportRowView.FileType) -> Color {
        switch type {
        case .usdz:
            return .red
        case .pointCloud:
            return .cyan
        case .unknown:
            return .gray
        }
    }
}

struct FileImportRowView_Previews: PreviewProvider {
    static var previews: some View {
        FileImportRowView { _ in }
            .padding()
    }
}
