import SwiftUI
import UniformTypeIdentifiers

// MARK: - Design System Constants 
struct DesignSystem {
    // Spacing
    static let spacing = (
        xs: CGFloat(2),
        sm: CGFloat(4),
        md: CGFloat(8),
        lg: CGFloat(12),
        xl: CGFloat(16),
        xxl: CGFloat(20),
        xxxl: CGFloat(24)
    )

    // Padding
    static let padding = (
        xs: CGFloat(2),
        sm: CGFloat(4),
        md: CGFloat(8),
        lg: CGFloat(12),
        xl: CGFloat(16),
        xxl: CGFloat(20)
    )

    // Corner Radius
    static let cornerRadius = (
        sm: CGFloat(4),
        md: CGFloat(6),
        lg: CGFloat(8),
        xl: CGFloat(12)
    )

    // Shadows
    static let shadow = (
        sm: (radius: CGFloat(2), opacity: 0.05),
        md: (radius: CGFloat(4), opacity: 0.08),
        lg: (radius: CGFloat(6), opacity: 0.10)
    )

    // Icon Sizes
    static let iconSize = (
        sm: CGFloat(12),
        md: CGFloat(16),
        lg: CGFloat(20),
        xl: CGFloat(24),
        xxl: CGFloat(32)
    )

    // Button Heights
    static let buttonHeight = (
        sm: CGFloat(28),
        md: CGFloat(36),
        lg: CGFloat(48),
        xl: CGFloat(60)
    )

    // Card Heights
    static let cardHeight = (
        sm: CGFloat(60),
        md: CGFloat(90),
        lg: CGFloat(100),
        xl: CGFloat(120)
    )
}

// MARK: - Custom View Modifiers
struct CardStyle: ViewModifier {
    var isSelected: Bool = false
    var isHovering: Bool = false

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .shadow(
                color: .black.opacity(DesignSystem.shadow.md.opacity),
                radius: DesignSystem.shadow.md.radius,
                x: 0,
                y: 4
            )
    }
}

extension View {
    func cardStyle(isSelected: Bool = false) -> some View {
        self.modifier(CardStyle(isSelected: isSelected))
    }
}

// MARK: - EnvironmentView (Standard Window Management)
struct EnvironmentView: View {
    @State var nextWindowID = 1
    @Environment(\.openWindow) private var openWindow
    @StateObject private var windowManager = WindowTypeManager.shared
    @StateObject private var workspaceManager = WorkspaceManager.shared
    @State private var showExportSidebar = false
    @State private var showImportDialog = false
    @State private var showTemplateGallery = false
    @State private var showWorkspaceDialog = false
    @State private var showFileImport = false
    @State private var selectedWindowType: StandardWindowType?
    @State private var hoveredWindowType: StandardWindowType?

    var body: some View {
        HStack(spacing: 0) {
            // Main content
            ScrollView {
                LazyVStack(spacing: DesignSystem.spacing.xxl) {
                    headerSection
                    VStack(spacing: DesignSystem.spacing.xxl) {
                        workspaceManagementSection
                        windowTypeSection
                        dataImportSection

                        if !windowManager.getAllWindows().isEmpty {
                            activeWindowsSection
                        }
                    }
                }
                .padding(DesignSystem.padding.xxl)
            }
            .frame(maxWidth: .infinity)

            // Export sidebar
            if showExportSidebar {
                ExportConfigurationSidebar()
                    .frame(width: 320)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        )
                    )
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.2), value: showExportSidebar)
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(.systemBackground))
        .sheet(isPresented: $showWorkspaceDialog) {
            WorkspaceDialog(
                isPresented: $showWorkspaceDialog,
                windowManager: windowManager
            )
        }
        .sheet(isPresented: $showTemplateGallery) {
            TemplateView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .fileImporter(
            isPresented: $showFileImport,
            allowedContentTypes: [
                UTType.commaSeparatedText,    // CSV files
                UTType.tabSeparatedText,      // TSV files  
                UTType.json,                  // JSON files
                UTType.plainText,             // TXT files
                UTType.image,                 // Images
                UTType.usdz,                  // 3D models
                UTType.threeDContent,         // 3D content
                UTType.data                   // Other data files
            ],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        HStack(alignment: .center, spacing: DesignSystem.spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.spacing.sm) {
                Text("Project Manager")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                if !workspaceManager.getCustomWorkspaces().isEmpty {
                    Text("\(workspaceManager.getCustomWorkspaces().count) saved project\(workspaceManager.getCustomWorkspaces().count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: DesignSystem.spacing.md) {
                WindowCountIndicator(
                    count: windowManager.getAllWindows().count
                )

                CircularButton(
                    icon: showExportSidebar ? "sidebar.trailing" : "gearshape",
                    action: { showExportSidebar.toggle() }
                )
            }
        }
        .padding(.bottom, DesignSystem.padding.md)
    }

    private var workspaceManagementSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing.lg) {
            SectionHeader(
                title: "Project Management",
                subtitle: "Create, save, and manage your data analysis projects",
                icon: "folder.badge.gearshape"
            )

            HStack(spacing: DesignSystem.spacing.md) {
                PrimaryActionCard(
                    title: "Project Manager",
                    subtitle: "Create, load, and manage projects",
                    icon: "folder.fill.badge.plus",
                    action: { showWorkspaceDialog = true },
                    style: .prominent
                )

                PrimaryActionCard(
                    title: "Template Gallery",
                    subtitle: "Browse pre-built projects",
                    icon: "doc.badge.gearshape",
                    action: { showTemplateGallery = true },
                    style: .secondary
                )
            }

            if !workspaceManager.getCustomWorkspaces().isEmpty {
                quickWorkspacesSection
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.spacing.md), count: 3),
                spacing: DesignSystem.spacing.md
            ) {
                SecondaryActionButton(
                    title: "Quick Save",
                    icon: "square.and.arrow.up",
                    action: quickSaveWorkspace
                )

                SecondaryActionButton(
                    title: "Demo",
                    icon: "doc.badge.plus",
                    action: createSampleWorkspace
                )

                SecondaryActionButton(
                    title: "Clear All",
                    icon: "trash",
                    action: clearAllWindowsWithConfirmation,
                    isDestructive: true
                )
            }
        }
        .padding(DesignSystem.padding.xl)
        .cardStyle()
    }

    private var windowTypeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing.lg) {
            SectionHeader(
                title: "Create New View",
                subtitle: "Choose a view type to add to your project",
                icon: "plus.rectangle.on.folder"
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DesignSystem.spacing.md),
                    GridItem(.flexible(), spacing: DesignSystem.spacing.md)
                ],
                spacing: DesignSystem.spacing.md
            ) {
                ForEach(StandardWindowType.allCases, id: \.self) { windowType in
                    StandardWindowTypeCard(
                        windowType: windowType,
                        isSelected: selectedWindowType == windowType,
                        isHovered: hoveredWindowType == windowType,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedWindowType = windowType
                                createStandardWindow(type: windowType)
                            }
                        }
                    )
                    .onHover { hovering in
                        hoveredWindowType = hovering ? windowType : nil
                    }
                }
            }
        }
        .padding(DesignSystem.padding.xl)
        .cardStyle()
    }

    private var activeWindowsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing.lg) {
            HStack {
                SectionHeader(
                    title: "Active Views",
                    subtitle: "\(windowManager.getAllWindows().count) view\(windowManager.getAllWindows().count == 1 ? "" : "s") currently open",
                    icon: "rectangle.3.group"
                )

                Spacer()

                Button("Close All") {
                    clearAllWindowsWithConfirmation()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.red)
                .fontWeight(.medium)
            }

            if windowManager.getAllWindows().isEmpty {
                EmptyStateView()
            } else {
                activeWindowsList
            }
        }
        .padding(DesignSystem.padding.xl)
        .cardStyle()
    }

    private var activeWindowsList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.spacing.sm) {
                ForEach(windowManager.getAllWindows(), id: \.id) { window in
                    HStack(spacing: DesignSystem.spacing.lg) {
                        IconBadge(icon: iconForWindowType(window.windowType))
                            .scaleEffect(0.8)

                        VStack(alignment: .leading, spacing: DesignSystem.spacing.xs) {
                            Text(window.windowType.displayName)
                                .font(.headline)
                                .fontWeight(.medium)

                            HStack(spacing: DesignSystem.spacing.md) {
                                Label("ID: #\(window.id)", systemImage: "number")
                                    .font(.caption2)

                                Label("\(window.state.exportTemplate.rawValue)", systemImage: "doc.text")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        WindowSizeBadge(width: window.position.width, height: window.position.height)

                        HStack(spacing: DesignSystem.spacing.sm) {
                            CircularButton(
                                icon: "arrow.up.left.and.arrow.down.right",
                                action: { openWindow(value: window.id) }
                            )
                            .scaleEffect(0.8)

                            CircularButton(
                                icon: "xmark.circle.fill",
                                action: { windowManager.removeWindow(window.id) }
                            )
                            .scaleEffect(0.8)
                            .foregroundStyle(.red)
                        }
                    }
                    .padding(DesignSystem.padding.md)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.md)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                    )
                }
            }
        }
        .frame(maxHeight: 250)
    }

    private var quickWorkspacesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing.md) {
            HStack {
                Text("Recent Projects")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button("View All") {
                    showWorkspaceDialog = true
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }

            let recentWorkspaces = Array(workspaceManager.getCustomWorkspaces().prefix(3))

            if recentWorkspaces.isEmpty {
                Text("No saved projects yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                VStack(spacing: DesignSystem.spacing.sm) {
                    ForEach(recentWorkspaces) { workspace in
                        QuickWorkspaceRowView(
                            workspace: workspace,
                            onLoad: { loadWorkspace(workspace) }
                        )
                    }
                }
            }
        }
        .padding(DesignSystem.padding.md)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.md))
    }

    private var dataImportSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing.lg) {
            SectionHeader(
                title: "File Import",
                subtitle: "Import files and automatically create appropriate views",
                icon: "square.and.arrow.down"
            )

            HStack(spacing: DesignSystem.spacing.md) {
                DataImportActionCard(
                    title: "Import Any File",
                    subtitle: "CSV, JSON, Images, 3D Models",
                    icon: "doc.badge.plus",
                    action: { showFileImport = true },
                    style: .prominent
                )

                DataImportActionCard(
                    title: "Create Blank Table",
                    subtitle: "Start with sample data",
                    icon: "plus.rectangle.on.rectangle",
                    action: { createBlankDataTable() },
                    style: .secondary
                )
            }

            Text("Import any file type to automatically create the most appropriate view for analysis and visualization")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, DesignSystem.padding.sm)
        }
        .padding(DesignSystem.padding.xl)
        .cardStyle()
    }

    private func createStandardWindow(type: StandardWindowType) {
        let standardPosition = WindowPosition(
            x: 100,
            y: 100,
            z: 0,
            width: 800,
            height: 600
        )
        
        let windowType = type.toWindowType()
        _ = windowManager.createWindow(windowType, id: nextWindowID, position: standardPosition)
        openWindow(value: nextWindowID)
        windowManager.markWindowAsOpened(nextWindowID)
        nextWindowID += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            selectedWindowType = nil
        }
    }

    private func quickSaveWorkspace() {
        let windows = windowManager.getAllWindows()
        guard !windows.isEmpty else { return }

        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        let workspaceName = "Project \(timestamp)"

        Task {
            do {
                _ = try await workspaceManager.createNewWorkspace(
                    name: workspaceName,
                    description: "Quick save with \(windows.count) views",
                    category: .custom,
                    tags: ["quick-save"],
                    windowManager: windowManager
                )

                print("Quick project saved: \(workspaceName)")
            } catch {
                print("Failed to quick save project: \(error)")
            }
        }
    }

    private func loadWorkspace(_ workspace: WorkspaceMetadata) {
        Task {
            do {
                _ = try await workspaceManager.loadWorkspace(
                    workspace,
                    into: windowManager,
                    clearExisting: true
                ) { windowID in
                    openWindow(value: windowID)
                    windowManager.markWindowAsOpened(windowID)
                }

                print("Workspace loaded: \(workspace.name)")
            } catch {
                print("Failed to load project: \(error)")
            }
        }
    }

    private func createSampleWorkspace() {
        let windowTypes: [WindowType] = [.charts, .column, .volume, .model3d]

        for (index, type) in windowTypes.enumerated() {
            let position = WindowPosition(
                x: Double(100 + index * 50),
                y: Double(100 + index * 50),
                z: 0,
                width: 600,
                height: 450
            )
            _ = windowManager.createWindow(type, id: nextWindowID, position: position)

            switch type {
            case .charts:
                windowManager.updateWindowContent(
                    nextWindowID,
                    content: """
                    # Sample Chart
                    plt.figure(figsize=(10, 6))
                    x = np.linspace(0, 10, 100)
                    y = np.sin(x)
                    plt.plot(x, y)
                    plt.title('Sample Sine Wave')
                    plt.show()
                    """
                )
                windowManager.updateWindowTemplate(nextWindowID, template: .matplotlib)
            case .column:
                let sampleDataFrame = DataFrameData(
                    columns: ["Name", "Value", "Category"],
                    rows: [
                        ["Sample A", "100", "Type 1"],
                        ["Sample B", "200", "Type 2"],
                        ["Sample C", "150", "Type 1"]
                    ],
                    dtypes: ["Name": "string", "Value": "int", "Category": "string"]
                )
                windowManager.updateWindowDataFrame(nextWindowID, dataFrame: sampleDataFrame)
                windowManager.updateWindowTemplate(nextWindowID, template: .pandas)
            case .volume:
                windowManager.updateWindowContent(
                    nextWindowID,
                    content: """
                    # Model Performance Metrics
                    import numpy as np
                    import matplotlib.pyplot as plt

                    metrics = {
                        'accuracy': 0.95,
                        'precision': 0.92,
                        'recall': 0.89,
                        'f1_score': 0.90
                    }

                    print("Model Performance Metrics:")
                    for key, value in metrics.items():
                        print(f"{key}: {value}")
                    """
                )
                windowManager.updateWindowTemplate(nextWindowID, template: .custom)
            case .model3d:
                let sampleCube = Model3DData.generateCube(size: 3.0)
                windowManager.updateWindowModel3DData(nextWindowID, model3DData: sampleCube)
                windowManager.updateWindowTemplate(nextWindowID, template: .custom)
            default:
                break
            }

            windowManager.addWindowTag(nextWindowID, tag: "demo")
            openWindow(value: nextWindowID)
            windowManager.markWindowAsOpened(nextWindowID)
            nextWindowID += 1
        }
    }

    private func clearAllWindowsWithConfirmation() {
        let allWindows = windowManager.getAllWindows()
        for window in allWindows {
            windowManager.removeWindow(window.id)
        }
    }

    private func createDataTableWithImport() {
        showFileImport = true
    }
    
    private func createBlankDataTable() {
        let position = WindowPosition(
            x: 100,
            y: 100,
            z: 0,
            width: 1000,
            height: 700
        )
        
        _ = windowManager.createWindow(.column, id: nextWindowID, position: position)
        
        let sampleDataFrame = DataFrameData(
            columns: ["Name", "Value", "Category", "Date"],
            rows: [
                ["Sample A", "100", "Type 1", "2024-01-01"],
                ["Sample B", "200", "Type 2", "2024-01-02"],
                ["Sample C", "150", "Type 1", "2024-01-03"]
            ],
            dtypes: ["Name": "string", "Value": "int", "Category": "string", "Date": "string"]
        )
        windowManager.updateWindowDataFrame(nextWindowID, dataFrame: sampleDataFrame)
        
        openWindow(value: nextWindowID)
        windowManager.markWindowAsOpened(nextWindowID)
        nextWindowID += 1
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    print("Cannot access the selected file")
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                
                let fileExtension = url.pathExtension.lowercased()
                let fileName = url.lastPathComponent
                
                // Determine the appropriate view type based on file extension
                let viewType = determineViewType(for: fileExtension)
                
                let position = WindowPosition(
                    x: 100,
                    y: 100,
                    z: 0,
                    width: viewType == .model3d ? 800 : 1000,
                    height: viewType == .model3d ? 600 : 700
                )
                
                _ = windowManager.createWindow(viewType, id: nextWindowID, position: position)
                
                // Handle different file types
                switch viewType {
                case .column:
                    // Data files (CSV, JSON, TSV)
                    let content = try String(contentsOf: url)
                    let importedData: DataFrameData
                    
                    switch fileExtension {
                    case "csv":
                        importedData = try parseCSVForDataTable(content)
                    case "tsv", "txt":
                        importedData = try parseTSVForDataTable(content)
                    case "json":
                        importedData = try parseJSONForDataTable(content)
                    default:
                        importedData = try parseCSVForDataTable(content)
                    }
                    
                    windowManager.updateWindowDataFrame(nextWindowID, dataFrame: importedData)
                    windowManager.updateWindowTemplate(nextWindowID, template: .pandas)
                    
                case .model3d:
                    // 3D model files (USDZ, USD, etc.)
                    windowManager.updateWindowContent(
                        nextWindowID,
                        content: """
                        # 3D Model: \(fileName)
                        # File: \(url.path)
                        
                        # 3D model loaded from: \(fileName)
                        # Use the model viewer to interact with the 3D content
                        """
                    )
                    windowManager.updateWindowTemplate(nextWindowID, template: .custom)
                    
                case .charts:
                    // Image files or other files that might be suitable for chart analysis
                    let content = try? String(contentsOf: url)
                    windowManager.updateWindowContent(
                        nextWindowID,
                        content: """
                        # File Analysis: \(fileName)
                        # File path: \(url.path)
                        # File type: \(fileExtension.uppercased())
                        
                        import matplotlib.pyplot as plt
                        import numpy as np
                        
                        # File imported: \(fileName)
                        # Add your analysis code here
                        
                        plt.figure(figsize=(10, 6))
                        plt.title('Analysis of \(fileName)')
                        plt.text(0.5, 0.5, 'File: \(fileName)\\nType: \(fileExtension.uppercased())', 
                                ha='center', va='center', fontsize=12)
                        plt.axis('off')
                        plt.show()
                        """
                    )
                    windowManager.updateWindowTemplate(nextWindowID, template: .matplotlib)
                    
                default:
                    // Generic content view for other file types
                    let content = try? String(contentsOf: url)
                    windowManager.updateWindowContent(
                        nextWindowID,
                        content: """
                        # File: \(fileName)
                        # Type: \(fileExtension.uppercased())
                        # Path: \(url.path)
                        
                        \(content?.prefix(1000) ?? "Binary file content not displayable")
                        """
                    )
                    windowManager.updateWindowTemplate(nextWindowID, template: .plain)
                }
                
                // Add tags to identify the imported file
                windowManager.addWindowTag(nextWindowID, tag: "imported")
                windowManager.addWindowTag(nextWindowID, tag: fileExtension)
                windowManager.addWindowTag(nextWindowID, tag: "file:\(fileName)")
                
                openWindow(value: nextWindowID)
                windowManager.markWindowAsOpened(nextWindowID)
                nextWindowID += 1
                
                print("File imported: \(fileName) -> \(viewType.displayName) view")
                
            } catch {
                print("Error importing file: \(error.localizedDescription)")
            }
            
        case .failure(let error):
            print("Import failed: \(error.localizedDescription)")
        }
    }
    
    private func determineViewType(for fileExtension: String) -> WindowType {
        switch fileExtension.lowercased() {
        case "csv", "tsv", "json", "txt":
            return .column  // Data table view
        case "usdz", "usd", "usda", "usdc", "obj", "dae", "3ds":
            return .model3d  // 3D model view
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp":
            return .charts  // Image analysis view
        case "py", "ipynb", "r", "m", "scala":
            return .volume  // Code/notebook view
        case "md", "txt", "rtf":
            return .spatial  // Text/document view
        default:
            return .charts  // Default to charts for analysis
        }
    }
    
    private func parseCSVForDataTable(_ content: String) throws -> DataFrameData {
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else {
            throw FileImportError.noData
        }
        
        let rows = lines.map { line in
            line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        
        let columns = rows.first ?? []
        let dataRows = Array(rows.dropFirst())
        
        let dtypes = autoDetectDataTypesForTable(columns: columns, rows: dataRows)
        
        return DataFrameData(columns: columns, rows: dataRows, dtypes: dtypes)
    }
    
    private func parseTSVForDataTable(_ content: String) throws -> DataFrameData {
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else {
            throw FileImportError.noData
        }
        
        let rows = lines.map { line in
            line.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        
        let columns = rows.first ?? []
        let dataRows = Array(rows.dropFirst())
        
        let dtypes = autoDetectDataTypesForTable(columns: columns, rows: dataRows)
        
        return DataFrameData(columns: columns, rows: dataRows, dtypes: dtypes)
    }
    
    private func parseJSONForDataTable(_ content: String) throws -> DataFrameData {
        guard let data = content.data(using: .utf8) else {
            throw FileImportError.invalidFormat
        }
        
        let json = try JSONSerialization.jsonObject(with: data)
        
        if let array = json as? [[String: Any]] {
            let allKeys = Set(array.flatMap { $0.keys })
            let columns = Array(allKeys).sorted()
            
            let rows = array.map { object in
                columns.map { column in
                    if let value = object[column] {
                        return String(describing: value)
                    } else {
                        return ""
                    }
                }
            }
            
            let dtypes = autoDetectDataTypesForTable(columns: columns, rows: rows)
            return DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
            
        } else if let object = json as? [String: Any] {
            let columns = ["Key", "Value"]
            let rows = object.map { [String($0.key), String(describing: $0.value)] }
            let dtypes = autoDetectDataTypesForTable(columns: columns, rows: rows)
            return DataFrameData(columns: columns, rows: rows, dtypes: dtypes)
        } else {
            throw FileImportError.invalidFormat
        }
    }
    
    private func autoDetectDataTypesForTable(columns: [String], rows: [[String]]) -> [String: String] {
        var dtypes: [String: String] = [:]
        
        for (index, column) in columns.enumerated() {
            let columnValues = rows.compactMap { row in
                index < row.count ? row[index] : nil
            }.filter { !$0.isEmpty }
            
            if columnValues.isEmpty {
                dtypes[column] = "string"
                continue
            }
            
            let numericCount = columnValues.compactMap { Double($0) }.count
            
            if Double(numericCount) / Double(columnValues.count) > 0.8 {
                if columnValues.allSatisfy({ $0.contains(".") || Int($0) == nil }) {
                    dtypes[column] = "float"
                } else {
                    dtypes[column] = "int"
                }
            } else {
                dtypes[column] = "string"
            }
        }
        
        return dtypes
    }

    private func iconForWindowType(_ type: WindowType) -> String {
        switch type {
        case .charts: return "chart.line.uptrend.xyaxis"
        case .spatial: return "rectangle.3.group"
        case .column: return "tablecells"
        case .volume: return "gauge"
        case .pointcloud: return "circle.grid.3x3"
        case .model3d: return "cube.transparent"
        }
    }
}

// MARK: - Standard Window Types (Non-Volumetric)
enum StandardWindowType: String, CaseIterable {
    case charts = "Charts"
    case dataFrame = "DataFrame Viewer"
    case metrics = "Model Metric Viewer"
    case spatial = "Spatial Editor"
    case model3d = "3D Model Viewer"
    
    var displayName: String {
        return self.rawValue
    }
    
    func toWindowType() -> WindowType {
        switch self {
        case .charts: return .charts
        case .dataFrame: return .column
        case .metrics: return .volume
        case .spatial: return .spatial
        case .model3d: return .model3d
        }
    }
}

struct QuickWorkspaceRowView: View {
    let workspace: WorkspaceMetadata
    let onLoad: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("\(workspace.totalWindows) views • \(workspace.formattedModifiedDate)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Load") {
                onLoad()
            }
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .foregroundStyle(.blue)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Data Import Action Card
struct DataImportActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    var style: ActionCardStyle = .secondary

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.iconSize.xl, weight: .medium))
                    .foregroundStyle(style == .prominent ? .white : Color.accentColor)

                VStack(spacing: DesignSystem.spacing.xs) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(style == .prominent ? .white : .primary)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(style == .prominent ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.cardHeight.md)
            .padding(DesignSystem.padding.md)
            .background(style == .prominent ? Color.orange : Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg))
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
}

// MARK: - Reusable Components

struct WindowCountIndicator: View {
    let count: Int

    var body: some View {
        Label("\(count)", systemImage: "rectangle.3.group")
            .font(.headline)
            .padding(.horizontal, DesignSystem.padding.md)
            .padding(.vertical, DesignSystem.padding.xs)
            .background(Color.accentColor.opacity(0.15))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
    }
}

struct CircularButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.iconSize.md))
                .foregroundStyle(.secondary)
                .frame(width: DesignSystem.buttonHeight.md, height: DesignSystem.buttonHeight.md)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: DesignSystem.spacing.xl) {
            IconBadge(icon: icon)

            VStack(alignment: .leading, spacing: DesignSystem.spacing.xs) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

struct IconBadge: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: DesignSystem.iconSize.lg))
            .foregroundStyle(Color.accentColor)
            .frame(width: DesignSystem.iconSize.xl, height: DesignSystem.iconSize.xl)
    }
}

enum ActionCardStyle {
    case prominent
    case secondary
}

struct PrimaryActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    var style: ActionCardStyle = .secondary

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.iconSize.xl, weight: .medium))
                    .foregroundStyle(style == .prominent ? .white : Color.accentColor)

                VStack(spacing: DesignSystem.spacing.xs) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(style == .prominent ? .white : .primary)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(style == .prominent ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.cardHeight.md)
            .padding(DesignSystem.padding.md)
            .background(style == .prominent ? Color.accentColor : Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg))
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
}

struct SecondaryActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var isDestructive: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.iconSize.md))
                    .foregroundStyle(isDestructive ? .red : .secondary)

                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isDestructive ? .red : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.buttonHeight.lg)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.md))
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
}

struct StandardWindowTypeCard: View {
    let windowType: StandardWindowType
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(isSelected ? 0.2 : 0.15))
                        .frame(width: DesignSystem.buttonHeight.lg, height: DesignSystem.buttonHeight.lg)

                    Image(systemName: iconForStandardWindowType(windowType))
                        .font(.system(size: DesignSystem.iconSize.lg, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)

                VStack(spacing: DesignSystem.spacing.xs) {
                    Text(windowType.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(descriptionForStandardWindowType(windowType))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.cardHeight.md)
            .padding(DesignSystem.padding.md)
            .background(Color.secondary.opacity(isSelected ? 0.15 : 0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }

    private func iconForStandardWindowType(_ type: StandardWindowType) -> String {
        switch type {
        case .charts: return "chart.line.uptrend.xyaxis"
        case .dataFrame: return "tablecells"
        case .metrics: return "gauge"
        case .spatial: return "rectangle.3.group"
        case .model3d: return "cube.transparent"
        }
    }

    private func descriptionForStandardWindowType(_ type: StandardWindowType) -> String {
        switch type {
        case .charts: return "Visualize data with charts and graphs"
        case .dataFrame: return "Browse and analyze tabular data"
        case .metrics: return "Performance metrics and analytics"
        case .spatial: return "Interactive spatial editor"
        case .model3d: return "3D model rendering and interaction"
        }
    }
}

struct WindowSizeBadge: View {
    let width: Double
    let height: Double

    var body: some View {
        Text("\(Int(width))×\(Int(height))")
            .font(.caption2)
            .fontDesign(.monospaced)
            .padding(.horizontal, DesignSystem.padding.sm)
            .padding(.vertical, DesignSystem.padding.xs)
            .background(Color.secondary.opacity(0.2))
            .clipShape(Capsule())
            .foregroundStyle(.secondary)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: DesignSystem.spacing.md) {
            Image(systemName: "rectangle.dashed")
                .font(.system(size: DesignSystem.iconSize.xl))
                .foregroundStyle(.secondary)

            Text("No Active Views")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Create a new view to get started")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: DesignSystem.cardHeight.md)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg))
    }
}

struct ExportConfigurationSidebar: View {
    @StateObject private var windowManager = WindowTypeManager.shared
    @State private var selectedWindowID: Int? = nil
    @State private var selectedTemplate: ExportTemplate = .plain
    @State private var customImports = ""
    @State private var newTag = ""
    @State private var windowContent = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing.md) {
            headerView
            windowSelectorSection
            configurationSection
            Spacer()
            exportActionsSection
        }
        .padding()
        .frame(width: 320)
    }

    private var headerView: some View {
        Text("Export Configuration")
            .font(.title2)
            .bold()
    }

    private var windowSelectorSection: some View {
        WindowSelectorView(
            windowManager: windowManager,
            selectedWindowID: $selectedWindowID,
            onWindowSelected: loadWindowConfiguration
        )
    }

    @ViewBuilder
    private var configurationSection: some View {
        if let windowID = selectedWindowID {
            Divider()
            WindowConfigurationView(
                windowID: windowID,
                windowManager: windowManager,
                selectedTemplate: $selectedTemplate,
                customImports: $customImports,
                newTag: $newTag,
                windowContent: $windowContent
            )
        }
    }

    private var exportActionsSection: some View {
        ExportActionsView(windowManager: windowManager)
    }

    private func loadWindowConfiguration(_ window: NewWindowID) {
        selectedTemplate = window.state.exportTemplate
        customImports = window.state.customImports.joined(separator: "\n")
        windowContent = window.state.content
    }
}

enum FileImportError: LocalizedError {
    case noData
    case invalidFormat
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .noData:
            return "No data found in the file"
        case .invalidFormat:
            return "Invalid file format"
        case .parsingFailed:
            return "Failed to parse the data"
        }
    }
}