//
//  MainView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/12/25.
//  Copyright © 2025 Apple. All rights reserved.
//


struct MainView: View {
    @State private var showFileImporter = false
    @State private var showURLInput = false
    @State private var urlText = ""
    
    @Environment(\.openWindow) private var openWindow
    
    let demoURL = URL(string: "https://developer.apple.com/augmented-reality/quick-look/models/teapot/teapot.usdz")!
    
    var body: some View {
        VStack(spacing: 20) {
            Text("3D Model Viewer")
                .font(.largeTitle)
            
            Button("Load Demo Model") {
                openWindow(id: "modelViewer", value: demoURL)
            }
            
            Button("Load from URL") {
                showURLInput = true
            }
            
            Button("Load from File") {
                showFileImporter = true
            }
        }
        .padding()
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.usdz]) { result in
            switch result {
            case .success(let url):
                if url.startAccessingSecurityScopedResource() {
                    openWindow(id: "modelViewer", value: url)
                }
            case .failure(let error):
                print("Error importing file: \(error)")
            }
        }
        .alert("Enter USDZ URL", isPresented: $showURLInput) {
            TextField("https://example.com/model.usdz", text: $urlText)
            Button("Cancel", role: .cancel) {}
            Button("OK") {
                if let url = URL(string: urlText), url.pathExtension.lowercased() == "usdz" {
                    openWindow(id: "modelViewer", value: url)
                } else {
                    print("Invalid URL")
                }
            }
        } message: {
            Text("Enter the URL of a USDZ file.")
        }
    }
}

struct ModelViewerView: View {
    let modelURL: URL
    @State private var modelEntity: ModelEntity?
    
    var body: some View {
        RealityView(make: { content in
            // Placeholder or empty initially
            return content
        }, update: { content in
            if let entity = modelEntity, content.entities.isEmpty {
                content.add(entity)
            }
        })
        .gesture(SpatialTapGesture().onEnded { _ in
            // Optional: Add interaction if needed
        })
        .task {
            do {
                modelEntity = try await ModelEntity(contentsOf: modelURL)
            } catch {
                print("Error loading model: \(error)")
            }
        }
        .onDisappear {
            if modelURL.isFileURL {
                modelURL.stopAccessingSecurityScopedResource()
            }
        }
    }
}