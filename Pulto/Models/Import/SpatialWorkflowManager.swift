//
//  SpatialWorkflowManager.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/19/25.
//  Copyright © 2025 Apple. All rights reserved.
//
/*

import SwiftUI
import RealityKit
import Combine

// MARK: - Spatial Workflow Manager
class SpatialWorkflowManager: ObservableObject {
    static let shared = SpatialWorkflowManager()
    
    @Published var activeWorkflows: [SpatialWorkflow] = []
    @Published var isProcessing = false
    
    private let windowManager = WindowTypeManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Workflow Creation
    
    func createWorkflowFromFiles(_ urls: [URL]) async -> SpatialWorkflow {
        let workflow = SpatialWorkflow(name: "New Analysis - \(Date().formatted())")
        
        await MainActor.run {
            activeWorkflows.append(workflow)
            isProcessing = true
        }
        
        // Analyze files
        for url in urls {
            if let result = await analyzeFile(url) {
                workflow.analysisResults.append(result)
            }
        }
        
        // Generate notebook
        let notebook = NotebookSerializer.createSpatialNotebook(from: workflow.analysisResults)
        workflow.notebook = notebook
        
        // Create visualization plan
        workflow.visualizationPlan = createVisualizationPlan(for: workflow.analysisResults)
        
        await MainActor.run {
            isProcessing = false
        }
        
        return workflow
    }
    
    // MARK: - File Analysis
    
    private func analyzeFile(_ url: URL) async -> FileAnalysisResult? {
        let analyzer = FileAnalyzer()
        return await analyzer.analyze(url)
    }
    
    // MARK: - Visualization Planning
    
    private func createVisualizationPlan(for results: [FileAnalysisResult]) -> VisualizationPlan {
        var plan = VisualizationPlan()
        
        // Group by visualization type
        let grouped = Dictionary(grouping: results) { result in
            switch result.visualizationType {
            case .dataTable, .chart2D:
                return "2D"
            case .pointCloud3D, .volumetric3D:
                return "3D"
            case .notebook:
                return "notebook"
            case .unknown:
                return "unknown"
            }
        }
        
        // Create layout based on groups
        var position = SIMD3<Float>(0, 0, 0)
        
        for (group, results) in grouped {
            for (index, result) in results.enumerated() {
                let item = VisualizationItem(
                    fileResult: result,
                    position: position,
                    scale: SIMD3<Float>(1, 1, 1),
                    windowID: nil
                )
                
                plan.items.append(item)
                
                // Update position for next item
                switch group {
                case "2D":
                    position.x += 2.0
                case "3D":
                    position.z += 2.0
                default:
                    position.y += 1.0
                }
            }
        }
        
        return plan
    }
    
    // MARK: - Workflow Execution
    
    func executeWorkflow(_ workflow: SpatialWorkflow) async {
        workflow.status = .executing
        
        for item in workflow.visualizationPlan.items {
            await openVisualization(for: item, in: workflow)
        }
        
        workflow.status = .completed
        
        // Save workflow notebook
        if let notebook = workflow.notebook {
            await saveWorkflowNotebook(workflow, notebook: notebook)
        }
    }
    
    private func openVisualization(for item: VisualizationItem, in workflow: SpatialWorkflow) async {
        let windowID = windowManager.createWindow(
            type: mapVisualizationTypeToWindowType(item.fileResult.visualizationType),
            title: item.fileResult.suggestedWindowTitle
        )
        
        // Update item with window ID
        if let index = workflow.visualizationPlan.items.firstIndex(where: { $0.id == item.id }) {
            workflow.visualizationPlan.items[index].windowID = windowID
        }
        
        // Store metadata
        windowManager.updateWindowMetadata(windowID, key: "workflowID", value: workflow.id.uuidString)
        windowManager.updateWindowMetadata(windowID, key: "fileURL", value: item.fileResult.fileURL.absoluteString)
        
        // Open appropriate window
        await MainActor.run {
            openWindow(for: item.fileResult, windowID: windowID)
        }
    }
    
    @MainActor
    private func openWindow(for result: FileAnalysisResult, windowID: Int) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        switch result.visualizationType {
        case .dataTable:
            if let openWindow = windowScene.windows.first?.rootViewController as? OpenWindowAction {
                openWindow(id: "data-table", value: windowID)
            }
            
        case .chart2D:
            if let openWindow = windowScene.windows.first?.rootViewController as? OpenWindowAction {
                openWindow(id: "chart-2d", value: windowID)
            }
            
        case .pointCloud3D:
            if let openWindow = windowScene.windows.first?.rootViewController as? OpenWindowAction {
                openWindow(id: "volumetric-pointcloud", value: windowID)
            }
            
        case .volumetric3D:
            if let openWindow = windowScene.windows.first?.rootViewController as? OpenWindowAction {
                openWindow(id: "volumetric-model3d", value: windowID)
            }
            
        case .notebook:
            if let openWindow = windowScene.windows.first?.rootViewController as? OpenWindowAction {
                openWindow(id: "notebook-viewer", value: windowID)
            }
            
        case .unknown:
            break
        }
    }
    
    // MARK: - Notebook Management
    
    private func saveWorkflowNotebook(_ workflow: SpatialWorkflow, notebook: JupyterNotebook) async {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let notebookURL = documentsURL.appendingPathComponent("Workflows/\(workflow.id.uuidString).ipynb")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: notebookURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        // Save notebook
        do {
            try NotebookSerializer.saveNotebook(notebook, to: notebookURL)
            workflow.notebookURL = notebookURL
        } catch {
            print("Error saving notebook: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func mapVisualizationTypeToWindowType(_ type: FileAnalysisResult.VisualizationType) -> WindowType {
        switch type {
        case .dataTable:
            return .dataTable
        case .chart2D:
            return .chart
        case .pointCloud3D, .volumetric3D:
            return .spatialEditor
        case .notebook:
            return .notebook
        case .unknown:
            return .editor
        }
    }
}

// MARK: - Workflow Models

class SpatialWorkflow: ObservableObject, Identifiable {
    let id = UUID()
    @Published var name: String
    @Published var analysisResults: [FileAnalysisResult] = []
    @Published var visualizationPlan: VisualizationPlan = VisualizationPlan()
    @Published var notebook: JupyterNotebook?
    @Published var notebookURL: URL?
    @Published var status: WorkflowStatus = .created
    
    init(name: String) {
        self.name = name
    }
    
    enum WorkflowStatus {
        case created
        case analyzing
        case planning
        case executing
        case completed
        case failed(Error)
    }
}

struct VisualizationPlan {
    var items: [VisualizationItem] = []
    var layout: LayoutType = .automatic
    
    enum LayoutType {
        case automatic
        case grid
        case stack
        case custom
    }
}

struct VisualizationItem: Identifiable {
    let id = UUID()
    let fileResult: FileAnalysisResult
    var position: SIMD3<Float>
    var scale: SIMD3<Float>
    var windowID: Int?
}

// MARK: - File Analyzer

class FileAnalyzer {
    func analyze(_ url: URL) async -> FileAnalysisResult? {
        let fileExtension = url.pathExtension.lowercased()
        let fileName = url.lastPathComponent
        
        // Determine visualization type
        let visualizationType: FileAnalysisResult.VisualizationType
        var metadata: [String: Any] = [:]
        
        switch fileExtension {
        case "csv", "tsv":
            if let csvData = await analyzeCSVFile(url) {
                metadata["csvData"] = csvData
                let recommendations = ChartRecommender.recommend(for: csvData)
                visualizationType = recommendations.first?.recommendation != nil 
                    ? .chart2D(recommendations.first!.recommendation)
                    : .dataTable
            } else {
                visualizationType = .dataTable
            }
            
        case "usdz", "usd":
            visualizationType = .volumetric3D
            metadata["modelType"] = "usdz"
            
        case "ply", "pcd", "xyz":
            visualizationType = .pointCloud3D
            metadata["pointFormat"] = fileExtension
            
        case "ipynb":
            visualizationType = .notebook
            
        default:
            visualizationType = .unknown
        }
        
        return FileAnalysisResult(
            fileURL: url,
            fileName: fileName,
            fileType: fileExtension,
            visualizationType: visualizationType,
            metadata: metadata,
            suggestedWindowTitle: generateTitle(fileName: fileName, type: visualizationType)
        )
    }
    
    private func analyzeCSVFile(_ url: URL) async -> CSVData? {
        do {
            let content = try String(contentsOf: url)
            return CSVParser.parse(content)
        } catch {
            return nil
        }
    }
    
    private func generateTitle(fileName: String, type: FileAnalysisResult.VisualizationType) -> String {
        let baseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        
        switch type {
        case .dataTable:
            return "\(baseName) - Table"
        case .chart2D(let rec):
            return "\(baseName) - \(rec.name)"
        case .pointCloud3D:
            return "\(baseName) - Points"
        case .volumetric3D:
            return "\(baseName) - 3D"
        case .notebook:
            return "\(baseName) - Notebook"
        case .unknown:
            return baseName
        }
    }
}

// MARK: - Workflow View

struct SpatialWorkflowView: View {
    @StateObject private var workflowManager = SpatialWorkflowManager.shared
    @State private var selectedWorkflow: SpatialWorkflow?
    @State private var showingFileImporter = false
    @State private var selectedFiles: [URL] = []
    
    var body: some View {
        NavigationSplitView {
            // Sidebar - Workflow List
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Label("Workflows", systemImage: "flowchart")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: { showingFileImporter = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                
                Divider()
                
                // Workflow list
                if workflowManager.activeWorkflows.isEmpty {
                    ContentUnavailableView(
                        "No Workflows",
                        systemImage: "flowchart",
                        description: Text("Create a new workflow by importing files")
                    )
                } else {
                    List(workflowManager.activeWorkflows, selection: $selectedWorkflow) { workflow in
                        WorkflowRow(workflow: workflow)
                    }
                }
            }
            .frame(minWidth: 300)
        } detail: {
            if let workflow = selectedWorkflow {
                WorkflowDetailView(workflow: workflow)
            } else {
                ContentUnavailableView(
                    "Select a Workflow",
                    systemImage: "flowchart.fill",
                    description: Text("Choose a workflow from the sidebar or create a new one")
                )
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: FileAnalyzerView().supportedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                let workflow = await workflowManager.createWorkflowFromFiles(urls)
                selectedWorkflow = workflow
            }
        case .failure(let error):
            print("Error importing files: \(error)")
        }
    }
}

struct WorkflowRow: View {
    @ObservedObject var workflow: SpatialWorkflow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workflow.name)
                .font(.headline)
            
            HStack {
                Label("\(workflow.analysisResults.count) files", systemImage: "doc.stack")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                StatusBadge(status: workflow.status)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: SpatialWorkflow.WorkflowStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(colorForStatus)
                .frame(width: 8, height: 8)
            
            Text(textForStatus)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(colorForStatus.opacity(0.2))
        .clipShape(Capsule())
    }
    
    private var colorForStatus: Color {
        switch status {
        case .created: return .gray
        case .analyzing: return .blue
        case .planning: return .purple
        case .executing: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
    
    private var textForStatus: String {
        switch status {
        case .created: return "Created"
        case .analyzing: return "Analyzing"
        case .planning: return "Planning"
        case .executing: return "Executing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

struct WorkflowDetailView: View {
    @ObservedObject var workflow: SpatialWorkflow
    @StateObject private var workflowManager = SpatialWorkflowManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(workflow.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack {
                        StatusBadge(status: workflow.status)
                        
                        if workflow.notebookURL != nil {
                            Button(action: openNotebook) {
                                Label("Open Notebook", systemImage: "text.book.closed")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                // File Analysis Results
                VStack(alignment: .leading, spacing: 12) {
                    Text("Analysis Results")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    ForEach(workflow.analysisResults, id: \.fileURL) { result in
                        FileAnalysisResultCard(result: result)
                    }
                }
                
                // Visualization Plan
                if !workflow.visualizationPlan.items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Visualization Plan")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VisualizationPlanView(plan: workflow.visualizationPlan)
                    }
                }
                
                // Execute button
                if workflow.status != .completed && workflow.status != .executing {
                    Button(action: executeWorkflow) {
                        Label("Execute Workflow", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding()
        }
    }
    
    private func openNotebook() {
        if let url = workflow.notebookURL {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            // iOS implementation
            #endif
        }
    }
    
    private func executeWorkflow() {
        Task {
            await workflowManager.executeWorkflow(workflow)
        }
    }
}

struct FileAnalysisResultCard: View {
    let result: FileAnalysisResult
    
    var body: some View {
        HStack {
            Image(systemName: iconForType(result.visualizationType))
                .font(.title2)
                .foregroundStyle(colorForType(result.visualizationType))
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.fileName)
                    .font(.headline)
                
                Text(descriptionForType(result.visualizationType))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func iconForType(_ type: FileAnalysisResult.VisualizationType) -> String {
        switch type {
        case .dataTable: return "tablecells"
        case .chart2D: return "chart.xyaxis.line"
        case .pointCloud3D: return "circle.grid.3x3.fill"
        case .volumetric3D: return "cube.transparent"
        case .notebook: return "text.book.closed"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private func colorForType(_ type: FileAnalysisResult.VisualizationType) -> Color {
        switch type {
        case .dataTable: return .green
        case .chart2D: return .blue
        case .pointCloud3D: return .purple
        case .volumetric3D: return .orange
        case .notebook: return .red
        case .unknown: return .gray
        }
    }
    
    private func descriptionForType(_ type: FileAnalysisResult.VisualizationType) -> String {
        switch type {
        case .dataTable: return "Tabular Data"
        case .chart2D(let rec): return rec.name
        case .pointCloud3D: return "3D Point Cloud"
        case .volumetric3D: return "3D Model"
        case .notebook: return "Notebook"
        case .unknown: return "Unknown"
        }
    }
}

struct VisualizationPlanView: View {
    let plan: VisualizationPlan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Layout: \(layoutName(plan.layout))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("\(plan.items.count) visualizations planned")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Simple 3D preview of layout
            GeometryReader { geometry in
                ForEach(plan.items) { item in
                    Circle()
                        .fill(colorForType(item.fileResult.visualizationType))
                        .frame(width: 30, height: 30)
                        .position(
                            x: CGFloat(item.position.x * 50 + 100),
                            y: CGFloat(item.position.z * 50 + 100)
                        )
                }
            }
            .frame(height: 200)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    private func layoutName(_ layout: VisualizationPlan.LayoutType) -> String {
        switch layout {
        case .automatic: return "Automatic"
        case .grid: return "Grid"
        case .stack: return "Stack"
        case .custom: return "Custom"
        }
    }
    
    private func colorForType(_ type: FileAnalysisResult.VisualizationType) -> Color {
        switch type {
        case .dataTable: return .green
        case .chart2D: return .blue
        case .pointCloud3D: return .purple
        case .volumetric3D: return .orange
        case .notebook: return .red
        case .unknown: return .gray
        }
    }
}
*/
