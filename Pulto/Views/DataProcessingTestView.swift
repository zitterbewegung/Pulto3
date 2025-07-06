import SwiftUI
import RealityKit

struct DataProcessingTestView: View {
    @StateObject private var dataProcessor = DataFrameProcessor()
    @StateObject private var dataBinder = RealTimeDataBinder(dataProcessor: DataFrameProcessor())
    @State private var showingFileImporter = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Data Processing & Visualization Test")
                .font(.title)
                .padding()
            
            // Data Processing Status
            Group {
                if dataProcessor.isProcessing {
                    VStack {
                        Text("Processing Data...")
                        ProgressView(value: dataProcessor.processingProgress)
                            .frame(width: 300)
                        Text("\(Int(dataProcessor.processingProgress * 100))%")
                    }
                } else {
                    Text("Ready to process data")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            // Controls
            HStack(spacing: 20) {
                Button("Generate Sample Data") {
                    generateSampleData()
                }
                
                Button("Import CSV File") {
                    showingFileImporter = true
                }
                
                Button("Create Test Visualization") {
                    createTestVisualization()
                }
            }
            .padding()
            
            // Chart Data Display
            if !dataBinder.chartData.isEmpty {
                VStack {
                    Text("Chart Data Points: \(dataBinder.chartData.count)")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(dataBinder.chartData.prefix(10).enumerated()), id: \.offset) { index, point in
                                HStack {
                                    Text("Point \(index + 1):")
                                        .fontWeight(.medium)
                                    Text("X: \(point.x, specifier: "%.2f"), Y: \(point.y, specifier: "%.2f")")
                                    if let z = point.z {
                                        Text("Z: \(z, specifier: "%.2f")")
                                    }
                                }
                                .font(.caption)
                            }
                            if dataBinder.chartData.count > 10 {
                                Text("... and \(dataBinder.chartData.count - 10) more points")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(height: 200)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // 3D Visualization
            if !dataBinder.spatialEntities.isEmpty {
                Text("3D Entities: \(dataBinder.spatialEntities.count)")
                    .font(.headline)
                
                RealityView { content in
                    // Initial setup
                } update: { content in
                    content.entities.removeAll()
                    for entity in dataBinder.spatialEntities.prefix(100) {
                        content.add(entity)
                    }
                }
                .frame(height: 300)
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    processFile(url)
                }
            case .failure(let error):
                print("File import failed: \(error)")
            }
        }
    }
    
    private func generateSampleData() {
        Task {
            // Create sample CSV data
            let csvContent = """
            x,y,z,value,category
            1.0,2.0,3.0,10.5,A
            2.0,3.0,4.0,15.2,B
            3.0,4.0,5.0,8.7,A
            4.0,5.0,6.0,12.3,C
            5.0,6.0,7.0,9.8,B
            """
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("sample_data.csv")
            try? csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            
            do {
                try await dataProcessor.processLargeDataset(from: tempURL)
            } catch {
                print("Error processing sample data: \(error)")
            }
        }
    }
    
    private func processFile(_ url: URL) {
        Task {
            do {
                _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                
                try await dataProcessor.processLargeDataset(from: url)
            } catch {
                print("Error processing file: \(error)")
            }
        }
    }
    
    private func createTestVisualization() {
        // Create some test spatial entities manually
        var entities: [Entity] = []
        
        for i in 0..<50 {
            let entity = Entity()
            let mesh = MeshResource.generateSphere(radius: 0.02)
            let material = SimpleMaterial(color: .systemBlue, isMetallic: false)
            
            entity.components[ModelComponent.self] = ModelComponent(
                mesh: mesh,
                materials: [material]
            )
            
            // Position in a spiral
            let t = Float(i) * 0.2
            entity.position = SIMD3<Float>(
                cos(t) * t * 0.1,
                Float(i) * 0.02 - 0.5,
                sin(t) * t * 0.1
            )
            
            entities.append(entity)
        }
        
        dataBinder.spatialEntities = entities
    }
}