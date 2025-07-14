//
//  SettingsView.swift
//  Pulto
//
//  Configuration and preferences view
//

import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    
    // Settings stored persistently
    @AppStorage("autoSaveEnabled") private var autoSaveEnabled: Bool = true
    @AppStorage("defaultJupyterServerURL") private var defaultJupyterServerURL: String = "http://localhost:8888"
    @AppStorage("autoSaveInterval") private var autoSaveInterval: Double = 30.0
    @AppStorage("maxRecentProjects") private var maxRecentProjects: Int = 10
    @AppStorage("enableAdvancedFeatures") private var enableAdvancedFeatures: Bool = false
    @AppStorage("defaultWindowSize") private var defaultWindowSize: String = "Medium"
    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    @AppStorage("themePreference") private var themePreference: String = "Auto"
    
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case workspace = "Workspace"
        case jupyter = "Jupyter"
        case advanced = "Advanced"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .workspace: return "folder"
            case .jupyter: return "doc.text"
            case .advanced: return "wrench.and.screwdriver"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Tab Selection
                tabSelectionView
                
                Divider()
                
                // Content
                TabView(selection: $selectedTab) {
                    generalSettingsView
                        .tag(SettingsTab.general)
                    
                    workspaceSettingsView
                        .tag(SettingsTab.workspace)
                    
                    jupyterSettingsView
                        .tag(SettingsTab.jupyter)
                    
                    advancedSettingsView
                        .tag(SettingsTab.advanced)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .background(Color.black.opacity(0.05))
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "gear")
                    .font(.title)
                    .foregroundStyle(.blue)
                
                Text("Pulto Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            Text("Configure your Pulto experience")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Tab Selection View
    private var tabSelectionView: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                        
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(selectedTab == tab ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.blue.opacity(0.1))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial)
    }
    
    // MARK: - General Settings
    private var generalSettingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("Appearance") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Theme")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Picker("Theme", selection: $themePreference) {
                                Text("Auto").tag("Auto")
                                Text("Light").tag("Light")
                                Text("Dark").tag("Dark")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 200)
                        }
                        
                        HStack {
                            Text("Default Window Size")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Picker("Window Size", selection: $defaultWindowSize) {
                                Text("Small").tag("Small")
                                Text("Medium").tag("Medium")
                                Text("Large").tag("Large")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 120)
                        }
                    }
                }
                
                SettingsSection("Notifications") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Notifications", isOn: $enableNotifications)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if enableNotifications {
                            Text("Receive notifications for workspace updates and system alerts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                }
                
                SettingsSection("Recent Projects") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Maximum Recent Projects")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Stepper("\(maxRecentProjects)", value: $maxRecentProjects, in: 5...50, step: 5)
                                .frame(width: 120)
                        }
                        
                        Text("Controls how many recent projects are shown in the workspace tab")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Workspace Settings
    private var workspaceSettingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("Auto-Save") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Auto-save after every window action", isOn: $autoSaveEnabled)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if autoSaveEnabled {
                            Text("Automatically saves your workspace configuration after any window is created, moved, or modified")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                }
                
                if autoSaveEnabled {
                    SettingsSection("Auto-Save Interval") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Save Interval")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text("\(Int(autoSaveInterval)) seconds")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Slider(value: $autoSaveInterval, in: 10...300, step: 10) {
                                Text("Auto-save interval")
                            }
                            .tint(.blue)
                            
                            Text("How often to automatically save workspace changes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                SettingsSection("Window Management") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Advanced Features", isOn: $enableAdvancedFeatures)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if enableAdvancedFeatures {
                            Text("Enables experimental features like advanced window positioning, custom layouts, and developer tools")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Jupyter Settings
    private var jupyterSettingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("Server Configuration") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Default Server URL")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                        }
                        
                        TextField("Enter Jupyter server URL", text: $defaultJupyterServerURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(.body, design: .monospaced))
                        
                        Text("Default Jupyter notebook server to connect to when importing or creating notebooks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                SettingsSection("Connection") {
                    VStack(alignment: .leading, spacing: 12) {
                        Button("Test Connection") {
                            testJupyterConnection()
                        }
                        .buttonStyle(.bordered)
                        
                        Text("Test the connection to your Jupyter server")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                SettingsSection("Common Server URLs") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Options:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(commonJupyterURLs, id: \.self) { url in
                                Button(url) {
                                    defaultJupyterServerURL = url
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .font(.caption)
                                .fontDesign(.monospaced)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Advanced Settings
    private var advancedSettingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("Developer Options") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("These settings are for advanced users and developers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                        
                        Button("Reset All Settings") {
                            resetAllSettings()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        
                        Button("Export Settings") {
                            exportSettings()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Import Settings") {
                            importSettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                SettingsSection("Debug Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("App Version: 1.0.0")
                            .font(.caption)
                            .fontDesign(.monospaced)
                        
                        Text("Build: \(getCurrentBuildNumber())")
                            .font(.caption)
                            .fontDesign(.monospaced)
                        
                        Text("Platform: visionOS")
                            .font(.caption)
                            .fontDesign(.monospaced)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Helper Views
    private func SettingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Helper Properties
    private var commonJupyterURLs: [String] {
        [
            "http://localhost:8888",
            "http://localhost:8889",
            "http://127.0.0.1:8888",
            "http://127.0.0.1:8889"
        ]
    }
    
    // MARK: - Helper Methods
    private func testJupyterConnection() {
        // Implementation for testing Jupyter connection
        print("Testing connection to: \(defaultJupyterServerURL)")
    }
    
    private func resetAllSettings() {
        autoSaveEnabled = true
        defaultJupyterServerURL = "http://localhost:8888"
        autoSaveInterval = 30.0
        maxRecentProjects = 10
        enableAdvancedFeatures = false
        defaultWindowSize = "Medium"
        enableNotifications = true
        themePreference = "Auto"
    }
    
    private func exportSettings() {
        // Implementation for exporting settings
        print("Exporting settings...")
    }
    
    private func importSettings() {
        // Implementation for importing settings
        print("Importing settings...")
    }
    
    private func getCurrentBuildNumber() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

#Preview {
    SettingsView(isPresented: .constant(true))
}