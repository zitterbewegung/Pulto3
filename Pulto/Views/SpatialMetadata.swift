//
//  SpatialMetadata.swift
//  Volumetric Window
//
//  Created by Joshua Herman on 5/26/25.
//  Copyright 2025 Apple. All rights reserved.
//


//
//  SpatialMetadata.swift
//  SwiftChartsWWDC24
//
//  Created by Joshua Herman on 2/11/25.
//  Copyright 2025 Apple. All rights reserved.
//

import SwiftUI
import Combine
import RealityKit

// MARK: - Model for Spatial Metadata

struct SpatialMetadata: Codable {
    var x: Double
    var y: Double
    var z: Double
    var pitch: Double
    var yaw: Double
    var roll: Double
}

// MARK: - Notebook API Client

class NotebookAPI {
    // Set the base URL for your FastAPI server.
    let baseURL = URL(string: "http://localhost:8000")!

    /// Lists all notebook files in the notebooks directory.
    func listNotebooks(completion: @escaping (Result<[String], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("notebooks")
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                let err = NSError(domain: "NotebookAPI", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "No data returned"])
                completion(.failure(err))
                return
            }
            do {
                let notebooks = try JSONDecoder().decode([String].self, from: data)
                completion(.success(notebooks))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    /// Updates spatial metadata for a specific cell.
    func updateCellSpatialMetadata(notebookName: String, cellIndex: Int, spatial: SpatialMetadata, completion: @escaping (Result<String, Error>) -> Void) {
        var url = baseURL.appendingPathComponent("notebooks")
        url.appendPathComponent(notebookName)
        url.appendPathComponent("cells")
        url.appendPathComponent(String(cellIndex))
        url.appendPathComponent("spatial")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(spatial)
            request.httpBody = jsonData
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                let err = NSError(domain: "NotebookAPI", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "No data returned"])
                completion(.failure(err))
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
                   let message = json["message"] {
                    completion(.success(message))
                } else {
                    let err = NSError(domain: "NotebookAPI", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
                    completion(.failure(err))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    /// Updates spatial metadata for all cells in a notebook.
    func updateAllCellsSpatialMetadata(notebookName: String, spatial: SpatialMetadata, completion: @escaping (Result<String, Error>) -> Void) {
        var url = baseURL.appendingPathComponent("notebooks")
        url.appendPathComponent(notebookName)
        url.appendPathComponent("cells")
        url.appendPathComponent("spatial")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(spatial)
            request.httpBody = jsonData
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                let err = NSError(domain: "NotebookAPI", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "No data returned"])
                completion(.failure(err))
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
                   let message = json["message"] {
                    completion(.success(message))
                } else {
                    let err = NSError(domain: "NotebookAPI", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
                    completion(.failure(err))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

// MARK: - ViewModel

@MainActor
class NotebookViewModel: ObservableObject {
    @Published var notebooks: [String] = []
    @Published var isLoading: Bool = false
    let api = NotebookAPI()

    func fetchNotebooks() {
        isLoading = true
        api.listNotebooks { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let notebooks):
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.notebooks = notebooks
                    }
                case .failure(let error):
                    print("Error fetching notebooks: \(error)")
                }
            }
        }
    }
}

// MARK: - Modern VisionOS Views

/// A beautifully designed home view for spatial metadata management
struct SpatialMetadataHomeView: View {
    @StateObject var viewModel = NotebookViewModel()
    @State private var isDarkMode = true
    @State private var showSettings = false
    @State private var selectedNotebook: String? = nil
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: isDarkMode ? [
                        Color(red: 0.07, green: 0.07, blue: 0.12),
                        Color(red: 0.05, green: 0.05, blue: 0.08)
                    ] : [
                        Color(red: 0.98, green: 0.98, blue: 1.0),
                        Color(red: 0.95, green: 0.95, blue: 0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 40) {
                    // Header
                    SpatialHeaderView(isDarkMode: isDarkMode)

                    // Main Content
                    ScrollView {
                        VStack(spacing: 32) {
                            // Hero Section
                            //SpatialHeroSection(isDarkMode: isDarkMode)

                            // Notebooks Section
                            if viewModel.isLoading {
                                LoadingSection(isDarkMode: isDarkMode)
                            } else if !viewModel.notebooks.isEmpty {
                                NotebooksSection(
                                    notebooks: viewModel.notebooks,
                                    isDarkMode: isDarkMode,
                                    onNotebookTap: { notebook in
                                        selectedNotebook = notebook
                                    }
                                )
                            } else {
                                EmptyStateSection(
                                    isDarkMode: isDarkMode,
                                    onRefresh: {
                                        viewModel.fetchNotebooks()
                                    }
                                )
                            }

                            // Quick Actions
                            QuickActionsSection(
                                isDarkMode: isDarkMode,
                                onRefresh: {
                                    viewModel.fetchNotebooks()
                                }
                            )
                        }
                        .padding(.horizontal, 60)
                        .padding(.bottom, 40)
                    }
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isDarkMode.toggle()
                            }
                        } label: {
                            Image(systemName: isDarkMode ? "sun.max" : "moon")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title2)
                                .foregroundStyle(isDarkMode ? .yellow : .indigo)
                        }
                        .buttonStyle(.borderless)

                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title2)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .onAppear {
                viewModel.fetchNotebooks()
            }
        }
        .sheet(item: Binding<NotebookItem?>(
            get: { selectedNotebook.map(NotebookItem.init) },
            set: { selectedNotebook = $0?.name }
        )) { item in
            ModernNotebookDetailView(notebookName: item.name)
        }
        .sheet(isPresented: $showSettings) {
            //SettingsView()
        }
    }
}

struct NotebookItem: Identifiable {
    let id = UUID()
    let name: String
}

struct SpatialHeaderView: View {
    let isDarkMode: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Spatial Metadata")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Notebook Spatial Configuration")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(isDarkMode ? .white : .black)
            }

            Spacer()

            // Status Indicator
            HStack(spacing: 12) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)

                Text("API Connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 60)
        .padding(.top, 40)
    }
}

struct HeroSection: View {
    let isDarkMode: Bool

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .frame(height: 300)

                // Animated gradient background
                LinearGradient(
                    colors: [
                        .blue.opacity(0.3),
                        .purple.opacity(0.3),
                        .pink.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    VStack(spacing: 16) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 80))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))

                        Text("Manage Spatial Positioning")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(isDarkMode ? .white : .black)

                        Text("Configure 3D coordinates and orientation for notebook cells")
                            .font(.body)
                            .foregroundStyle(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                )
            }
        }
    }
}

struct NotebooksSection: View {
    let notebooks: [String]
    let isDarkMode: Bool
    let onNotebookTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Available Notebooks")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(isDarkMode ? .white : .black)

                Spacer()

                Text("\(notebooks.count) notebooks")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                ForEach(notebooks, id: \.self) { notebook in
                    NotebookCard(
                        name: notebook,
                        isDarkMode: isDarkMode,
                        onTap: { onNotebookTap(notebook) }
                    )
                }
            }
        }
    }
}

struct NotebookCard: View {
    let name: String
    let isDarkMode: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                // Icon
                Image(systemName: "doc.richtext")
                    .font(.system(size: 40))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text("Ready for configuration")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack {
                    Image(systemName: "arrow.right.circle")
                        .font(.title3)
                        .foregroundStyle(.blue)

                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .padding(24)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.blue.opacity(isHovered ? 0.5 : 0), lineWidth: 2)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct LoadingSection: View {
    let isDarkMode: Bool

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)

            Text("Loading notebooks...")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
    }
}

struct EmptyStateSection: View {
    let isDarkMode: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Notebooks Found")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Make sure your FastAPI server is running and notebooks are available")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Refresh") {
                onRefresh()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(height: 200)
        .padding()
    }
}

struct QuickActionsSection: View {
    let isDarkMode: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(isDarkMode ? .white : .black)

            HStack(spacing: 20) {
                ActionCard(
                    title: "Refresh",
                    subtitle: "Update notebook list",
                    icon: "arrow.clockwise",
                    color: .blue
                ) {
                    onRefresh()
                }

                ActionCard(
                    title: "Settings",
                    subtitle: "Configure API endpoint",
                    icon: "gearshape",
                    color: .purple
                ) {
                    // Handle settings
                }

                ActionCard(
                    title: "Help",
                    subtitle: "View documentation",
                    icon: "questionmark.circle",
                    color: .green
                ) {
                    // Handle help
                }
            }
        }
    }
}

struct ActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .padding(24)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(isHovered ? 0.5 : 0), lineWidth: 2)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ConfigurationSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .symbolRenderingMode(.hierarchical)

                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()
            }

            content
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Modern Detail View

struct ModernNotebookDetailView: View {
    let notebookName: String
    @State private var cellIndex: String = "0"
    @State private var x: String = ""
    @State private var y: String = ""
    @State private var z: String = ""
    @State private var pitch: String = ""
    @State private var yaw: String = ""
    @State private var roll: String = ""
    @State private var message: String = ""
    @State private var showAlert: Bool = false
    @State private var isLoading: Bool = false
    @State private var isDarkMode = true
    @Environment(\.dismiss) var dismiss

    let api = NotebookAPI()

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: isDarkMode ? [
                        Color(red: 0.07, green: 0.07, blue: 0.12),
                        Color(red: 0.05, green: 0.05, blue: 0.08)
                    ] : [
                        Color(red: 0.98, green: 0.98, blue: 1.0),
                        Color(red: 0.95, green: 0.95, blue: 0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(notebookName)
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )

                                    Text("Configure Spatial Metadata")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button("Done") {
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            }
                        }

                        // Configuration Sections
                        VStack(spacing: 24) {
                            // Cell Selection
                            ConfigurationSection(
                                title: "Target Cell",
                                icon: "doc.text",
                                color: .blue
                            ) {
                                HStack {
                                    Text("Cell Index")
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    TextField("0", text: $cellIndex)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.numberPad)
                                        .frame(width: 100)
                                }
                                .padding(.vertical, 8)
                            }

                            // Position Configuration
                            ConfigurationSection(
                                title: "3D Position",
                                icon: "cube",
                                color: .green
                            ) {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                                    ParameterField(label: "X", value: $x, color: .red)
                                    ParameterField(label: "Y", value: $y, color: .green)
                                    ParameterField(label: "Z", value: $z, color: .blue)
                                }
                            }

                            // Rotation Configuration
                            ConfigurationSection(
                                title: "3D Rotation",
                                icon: "rotate.3d",
                                color: .purple
                            ) {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                                    ParameterField(label: "Pitch", value: $pitch, color: .orange)
                                    ParameterField(label: "Yaw", value: $yaw, color: .pink)
                                    ParameterField(label: "Roll", value: $roll, color: .cyan)
                                }
                            }

                            // Action Buttons
                            VStack(spacing: 16) {
                                Button {
                                    updateCellMetadata()
                                } label: {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "doc.badge.gearshape")
                                        }

                                        Text(isLoading ? "Updating..." : "Update Cell Metadata")
                                            .font(.headline)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(isLoading)

                                Button {
                                    updateAllCellsMetadata()
                                } label: {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "doc.on.doc")
                                        }

                                        Text(isLoading ? "Updating..." : "Update All Cells")
                                            .font(.headline)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(.purple)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(isLoading)
                            }
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.bottom, 40)
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
        .alert("Update Result", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(message)
        }
    }

    private func updateCellMetadata() {
        guard let cellIndexInt = Int(cellIndex),
              let xVal = Double(x),
              let yVal = Double(y),
              let zVal = Double(z),
              let pitchVal = Double(pitch),
              let yawVal = Double(yaw),
              let rollVal = Double(roll) else {
            self.message = "Invalid input. Please check your values."
            self.showAlert = true
            return
        }

        isLoading = true
        let spatial = SpatialMetadata(x: xVal, y: yVal, z: zVal, pitch: pitchVal, yaw: yawVal, roll: rollVal)
        
        api.updateCellSpatialMetadata(notebookName: notebookName, cellIndex: cellIndexInt, spatial: spatial) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let msg):
                    self.message = msg
                case .failure(let error):
                    self.message = "Error: \(error.localizedDescription)"
                }
                self.showAlert = true
            }
        }
    }

    private func updateAllCellsMetadata() {
        guard let xVal = Double(x),
              let yVal = Double(y),
              let zVal = Double(z),
              let pitchVal = Double(pitch),
              let yawVal = Double(yaw),
              let rollVal = Double(roll) else {
            self.message = "Invalid input. Please check your values."
            self.showAlert = true
            return
        }

        isLoading = true
        let spatial = SpatialMetadata(x: xVal, y: yVal, z: zVal, pitch: pitchVal, yaw: yawVal, roll: rollVal)
        
        api.updateAllCellsSpatialMetadata(notebookName: notebookName, spatial: spatial) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let msg):
                    self.message = msg
                case .failure(let error):
                    self.message = "Error: \(error.localizedDescription)"
                }
                self.showAlert = true
            }
        }
    }
}

struct ParameterField: View {
    let label: String
    @Binding var value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            TextField("0.0", text: $value)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
        }
    }
}

// Placeholder Settings View
struct SpatialSettingsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("API Configuration and Preferences")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(width: 600, height: 400)
        .padding()
    }
}

// MARK: - Main Entry Point

/// This is the main entry point for the spatial metadata app
struct VisionOSNotebookView: View {
    var body: some View {
        SpatialMetadataHomeView()
            .scenePadding()
    }
}

// MARK: - Preview Provider

struct VisionOSNotebookView_Previews: PreviewProvider {
    static var previews: some View {
        VisionOSNotebookView()
    }
}