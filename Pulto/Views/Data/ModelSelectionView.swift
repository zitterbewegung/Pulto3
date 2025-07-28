//
//  ModelSelectionView.swift
//  Pulto3
//
//  Created by Assistant on Date.
//  Copyright 2025 Apple. All rights reserved.
//

import SwiftUI
import RealityKit
import UniformTypeIdentifiers

struct ModelSelectionView: View {
    let windowID: Int
    @EnvironmentObject var windowManager: WindowTypeManager
    @Environment(\.openWindow) private var openWindow
    
    @State private var showingFilePicker = false
    @State private var selectedModelType: ModelType = .cube
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    enum ModelType: String, CaseIterable {
        case cube = "Cube"
        case sphere = "Sphere"
        case importFile = "Import File"
        
        var icon: String {
            switch self {
            case .cube: return "cube.fill"
            case .sphere: return "sphere.fill"
            case .importFile: return "doc.badge.arrow.up.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .cube: return .blue
            case .sphere: return .green
            case .importFile: return .orange
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "cube.transparent.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                
                VStack(spacing: 8) {
                    Text("Select 3D Model")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Choose how to create your 3D model")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Model Type Selection
            LazyVGrid(columns: [
                GridItem(.flexible()), 
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(ModelType.allCases, id: \.self) { type in
                    ModelTypeCard(
                        type: type,
                        isSelected: selectedModelType == type
                    ) {
                        selectedModelType = type
                        handleModelTypeSelection(type)
                    }
                }
            }
            
            // Error display
            if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.orange)
                    
                    Text("Error")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(error)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Loading state
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Creating 3D Model...")
                        .font(.headline)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.usdz, .realityFile, UTType.data],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }
    
    private func handleModelTypeSelection(_ type: ModelType) {
        switch type {
        case .cube:
            createCubeModel()
        case .sphere:
            createSphereModel()
        case .importFile:
            showingFilePicker = true
        }
    }
    
    private func createCubeModel() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let cubeModel = Model3DData.generateCube(size: 2.0)
            windowManager.updateWindowModel3DData(windowID, model3DData: cubeModel)
            windowManager.updateWindowContent(windowID, content: "Generated Cube Model")
            isLoading = false
        }
    }
    
    private func createSphereModel() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let sphereModel = Model3DData.generateSphere(radius: 2.0, segments: 32)
            windowManager.updateWindowModel3DData(windowID, model3DData: sphereModel)
            windowManager.updateWindowContent(windowID, content: "Generated Sphere Model")
            isLoading = false
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importModelFromFile(url)
        case .failure(let error):
            errorMessage = "File selection failed: \(error.localizedDescription)"
        }
    }
    
    private func importModelFromFile(_ url: URL) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Create bookmark for security-scoped access
                let bookmark = try url.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                await MainActor.run {
                    // Store the bookmark in the window state
                    windowManager.updateUSDZBookmark(for: windowID, bookmark: bookmark)
                    windowManager.updateWindowContent(windowID, content: "Imported USDZ Model: \(url.lastPathComponent)")
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to import model: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Model Type Card
private struct ModelTypeCard: View {
    let type: ModelSelectionView.ModelType
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(type.color)
                
                Text(type.rawValue)
                    .font(.headline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .padding()
        }
        .buttonStyle(.plain)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? .blue : .clear, lineWidth: 3)
        }
        .scaleEffect(isSelected ? 0.95 : (isHovered ? 1.05 : 1.0))
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
        .onHover { isHovered = $0 }
    }
}

#Preview {
    ModelSelectionView(windowID: 1)
        .environmentObject(WindowTypeManager.shared)
}