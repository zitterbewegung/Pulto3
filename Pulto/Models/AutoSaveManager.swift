//
//  AutoSaveManager.swift
//  Pulto
//
//  Auto-save system for window focus and movement changes
//

import Foundation
import SwiftUI
import Combine

// MARK: - Auto-save Events and Models

enum AutoSaveEvent {
    case windowFocusLost(windowID: Int)
    case windowFocusGained(windowID: Int)
    case windowMovementStopped(windowID: Int, position: WindowPosition)
    case windowContentChanged(windowID: Int, content: String)
    case windowClosed(windowID: Int)
    case manualSave
    case intervalSave
}

enum AutoSaveDestination {
    case localFile
    case jupyterServer
    case both
}

struct AutoSaveResult {
    let success: Bool
    let destination: AutoSaveDestination
    let error: Error?
    let timestamp: Date
    let windowID: Int?
    let fileURL: URL?
}

// MARK: - Auto-save Manager

@MainActor
class AutoSaveManager: ObservableObject {
    static let shared = AutoSaveManager()
    
    // MARK: - Published Properties
    @Published var isAutoSaving: Bool = false
    @Published var lastSaveTime: Date?
    @Published var lastSaveResults: [AutoSaveResult] = []
    @Published var autoSaveEnabled: Bool = true
    @Published var jupyterServerAutoSave: Bool = false
    @Published var saveToLocalFiles: Bool = true
    
    // MARK: - Settings
    @AppStorage("autoSaveInterval") private var autoSaveInterval: Double = 30.0
    @AppStorage("autoSaveOnFocusLoss") private var autoSaveOnFocusLoss: Bool = true
    @AppStorage("autoSaveOnMovement") private var autoSaveOnMovement: Bool = true
    @AppStorage("autoSaveRetryCount") private var autoSaveRetryCount: Int = 3
    @AppStorage("defaultJupyterServerURL") private var defaultJupyterServerURL: String = "http://localhost:8888"
    
    // MARK: - Dependencies
    private let windowManager: WindowTypeManager
    private let workspaceManager: WorkspaceManager
    private let windowFocusTracker: WindowFocusTracker
    private let windowMovementDebouncer: WindowMovementDebouncer
    
    // MARK: - Internal State
    private var cancellables = Set<AnyCancellable>()
    private var intervalTimer: Timer?
    private var saveQueue: [AutoSaveEvent] = []
    private var isProcessingSaveQueue: Bool = false
    
    // MARK: - Initialization
    
    private init() {
        self.windowManager = WindowTypeManager.shared
        self.workspaceManager = WorkspaceManager.shared
        self.windowFocusTracker = WindowFocusTracker()
        self.windowMovementDebouncer = WindowMovementDebouncer()
        
        setupAutoSaveSystem()
    }
    
    // MARK: - Public Methods
    
    func startAutoSave() {
        guard autoSaveEnabled else { return }
        
        print("🔄 AutoSaveManager: Starting auto-save system")
        
        // Start interval timer
        startIntervalTimer()
        
        // Begin tracking window events
        windowFocusTracker.startTracking()
        windowMovementDebouncer.startTracking()
        
        print("✅ AutoSaveManager: Auto-save system started")
    }
    
    func stopAutoSave() {
        print("⏹️ AutoSaveManager: Stopping auto-save system")
        
        intervalTimer?.invalidate()
        intervalTimer = nil
        
        windowFocusTracker.stopTracking()
        windowMovementDebouncer.stopTracking()
        
        // Process any remaining saves
        Task {
            await processSaveQueue()
        }
        
        print("✅ AutoSaveManager: Auto-save system stopped")
    }
    
    func triggerManualSave() async {
        await processSaveEvent(.manualSave)
    }
    
    func updateSettings(
        autoSaveEnabled: Bool? = nil,
        jupyterServerAutoSave: Bool? = nil,
        saveToLocalFiles: Bool? = nil
    ) {
        if let autoSaveEnabled = autoSaveEnabled {
            self.autoSaveEnabled = autoSaveEnabled
            if autoSaveEnabled {
                startAutoSave()
            } else {
                stopAutoSave()
            }
        }
        
        if let jupyterServerAutoSave = jupyterServerAutoSave {
            self.jupyterServerAutoSave = jupyterServerAutoSave
        }
        
        if let saveToLocalFiles = saveToLocalFiles {
            self.saveToLocalFiles = saveToLocalFiles
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAutoSaveSystem() {
        // Listen for window focus changes
        windowFocusTracker.$focusedWindowID
            .sink { [weak self] windowID in
                if let windowID = windowID {
                    self?.handleWindowEvent(.windowFocusGained(windowID: windowID))
                }
            }
            .store(in: &cancellables)
        
        windowFocusTracker.$lastFocusedWindowID
            .sink { [weak self] windowID in
                if let windowID = windowID {
                    self?.handleWindowEvent(.windowFocusLost(windowID: windowID))
                }
            }
            .store(in: &cancellables)
        
        // Listen for window movement
        windowMovementDebouncer.$stoppedMovingEvents
            .sink { [weak self] events in
                for event in events {
                    self?.handleWindowEvent(.windowMovementStopped(
                        windowID: event.windowID,
                        position: event.position
                    ))
                }
            }
            .store(in: &cancellables)
        
        // Listen for window content changes
        NotificationCenter.default.publisher(for: .windowContentChanged)
            .sink { [weak self] notification in
                if let windowID = notification.userInfo?["windowID"] as? Int,
                   let content = notification.userInfo?["content"] as? String {
                    self?.handleWindowEvent(.windowContentChanged(windowID: windowID, content: content))
                }
            }
            .store(in: &cancellables)
        
        // Listen for window closures
        NotificationCenter.default.publisher(for: .windowClosed)
            .sink { [weak self] notification in
                if let windowID = notification.userInfo?["windowID"] as? Int {
                    self?.handleWindowEvent(.windowClosed(windowID: windowID))
                }
            }
            .store(in: &cancellables)
    }
    
    private func startIntervalTimer() {
        intervalTimer?.invalidate()
        intervalTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleWindowEvent(.intervalSave)
            }
        }
    }
    
    private func handleWindowEvent(_ event: AutoSaveEvent) {
        guard autoSaveEnabled else { return }
        
        // Add to queue for processing
        saveQueue.append(event)
        
        // Process queue if not already processing
        if !isProcessingSaveQueue {
            Task {
                await processSaveQueue()
            }
        }
    }
    
    private func processSaveQueue() async {
        guard !isProcessingSaveQueue else { return }
        isProcessingSaveQueue = true
        
        while !saveQueue.isEmpty {
            let event = saveQueue.removeFirst()
            await processSaveEvent(event)
        }
        
        isProcessingSaveQueue = false
    }
    
    private func processSaveEvent(_ event: AutoSaveEvent) async {
        guard shouldProcessEvent(event) else { return }
        
        isAutoSaving = true
        
        print("💾 AutoSaveManager: Processing save event: \(event)")
        
        var results: [AutoSaveResult] = []
        
        // Determine destinations
        var destinations: [AutoSaveDestination] = []
        if saveToLocalFiles {
            destinations.append(.localFile)
        }
        if jupyterServerAutoSave {
            destinations.append(.jupyterServer)
        }
        
        // Perform saves
        for destination in destinations {
            let result = await performSave(event: event, destination: destination)
            results.append(result)
        }
        
        // Update results
        lastSaveResults = Array(results.suffix(10)) // Keep last 10 results
        lastSaveTime = Date()
        
        // Log results
        for result in results {
            if result.success {
                print("✅ AutoSaveManager: Saved to \(result.destination)")
            } else {
                print("❌ AutoSaveManager: Failed to save to \(result.destination): \(result.error?.localizedDescription ?? "Unknown error")")
            }
        }
        
        isAutoSaving = false
    }
    
    private func shouldProcessEvent(_ event: AutoSaveEvent) -> Bool {
        switch event {
        case .windowFocusLost:
            return autoSaveOnFocusLoss
        case .windowMovementStopped:
            return autoSaveOnMovement
        case .windowContentChanged, .windowClosed, .manualSave, .intervalSave:
            return true
        case .windowFocusGained:
            return false // Don't save on focus gain
        }
    }
    
    private func performSave(event: AutoSaveEvent, destination: AutoSaveDestination) async -> AutoSaveResult {
        let windowID = extractWindowID(from: event)
        
        do {
            let fileURL: URL?
            
            switch destination {
            case .localFile:
                fileURL = try await saveToLocalFile(event: event)
            case .jupyterServer:
                fileURL = try await saveToJupyterServer(event: event)
            case .both:
                // This shouldn't happen since we process each destination separately
                fileURL = nil
            }
            
            return AutoSaveResult(
                success: true,
                destination: destination,
                error: nil,
                timestamp: Date(),
                windowID: windowID,
                fileURL: fileURL
            )
            
        } catch {
            return AutoSaveResult(
                success: false,
                destination: destination,
                error: error,
                timestamp: Date(),
                windowID: windowID,
                fileURL: nil
            )
        }
    }
    
    private func saveToLocalFile(event: AutoSaveEvent) async throws -> URL {
        let timestamp = DateFormatter.fileTimestamp.string(from: Date())
        let filename = "autosave_\(timestamp).ipynb"
        
        // Use the existing notebook export method from WindowTypeManager
        let notebookJSON = windowManager.exportToJupyterNotebook()
        
        // Save to documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw AutoSaveError.fileWriteFailed
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        do {
            try notebookJSON.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            throw AutoSaveError.fileWriteFailed
        }
    }
    
    private func saveToJupyterServer(event: AutoSaveEvent) async throws -> URL {
        // For now, create a local file that represents the server save
        // Full Jupyter server integration would require JupyterAPIClient
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("autosave_server_\(Date().timeIntervalSince1970).ipynb")
        
        let notebookJSON = windowManager.exportToJupyterNotebook()
        try notebookJSON.write(to: tempURL, atomically: true, encoding: .utf8)
        
        return tempURL
    }
    
    private func extractWindowID(from event: AutoSaveEvent) -> Int? {
        switch event {
        case .windowFocusLost(let windowID), .windowFocusGained(let windowID),
             .windowMovementStopped(let windowID, _), .windowContentChanged(let windowID, _),
             .windowClosed(let windowID):
            return windowID
        case .manualSave, .intervalSave:
            return nil
        }
    }
}

// MARK: - Window Focus Tracker

class WindowFocusTracker: ObservableObject {
    @Published var focusedWindowID: Int?
    @Published var lastFocusedWindowID: Int?
    
    private var isTracking: Bool = false
    
    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        
        // Listen for window focus notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowFocusGained),
            name: .windowFocusGained,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowFocusLost),
            name: .windowFocusLost,
            object: nil
        )
        
        print("🔍 WindowFocusTracker: Started tracking")
    }
    
    func stopTracking() {
        isTracking = false
        
        NotificationCenter.default.removeObserver(self, name: .windowFocusGained, object: nil)
        NotificationCenter.default.removeObserver(self, name: .windowFocusLost, object: nil)
        
        print("🔍 WindowFocusTracker: Stopped tracking")
    }
    
    @objc private func handleWindowFocusGained(_ notification: Notification) {
        guard let windowID = notification.userInfo?["windowID"] as? Int else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.focusedWindowID = windowID
        }
    }
    
    @objc private func handleWindowFocusLost(_ notification: Notification) {
        guard let windowID = notification.userInfo?["windowID"] as? Int else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.lastFocusedWindowID = windowID
            self?.focusedWindowID = nil
        }
    }
}

// MARK: - Window Movement Debouncer

struct WindowMovementEvent {
    let windowID: Int
    let position: WindowPosition
    let timestamp: Date
}

class WindowMovementDebouncer: ObservableObject {
    @Published var stoppedMovingEvents: [WindowMovementEvent] = []
    
    private var movementTimers: [Int: Timer] = [:]
    private var pendingMovements: [Int: WindowMovementEvent] = [:]
    private let debounceInterval: TimeInterval = 1.0
    private var isTracking: Bool = false
    
    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        
        // Listen for window position changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowPositionChanged),
            name: .windowPositionChanged,
            object: nil
        )
        
        print("📍 WindowMovementDebouncer: Started tracking")
    }
    
    func stopTracking() {
        isTracking = false
        
        NotificationCenter.default.removeObserver(self, name: .windowPositionChanged, object: nil)
        
        // Cancel all timers
        movementTimers.values.forEach { $0.invalidate() }
        movementTimers.removeAll()
        pendingMovements.removeAll()
        
        print("📍 WindowMovementDebouncer: Stopped tracking")
    }
    
    @objc private func handleWindowPositionChanged(_ notification: Notification) {
        guard let windowID = notification.userInfo?["windowID"] as? Int,
              let position = notification.userInfo?["position"] as? WindowPosition else { return }
        
        let event = WindowMovementEvent(
            windowID: windowID,
            position: position,
            timestamp: Date()
        )
        
        // Cancel existing timer for this window
        movementTimers[windowID]?.invalidate()
        
        // Store the pending movement
        pendingMovements[windowID] = event
        
        // Create new timer
        movementTimers[windowID] = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.handleMovementStopped(for: windowID)
        }
    }
    
    private func handleMovementStopped(for windowID: Int) {
        guard let event = pendingMovements[windowID] else { return }
        
        // Clean up
        movementTimers.removeValue(forKey: windowID)
        pendingMovements.removeValue(forKey: windowID)
        
        // Notify
        DispatchQueue.main.async { [weak self] in
            self?.stoppedMovingEvents.append(event)
        }
    }
}

// MARK: - Auto-save Errors

enum AutoSaveError: LocalizedError {
    case invalidNotebookFormat
    case serverConnectionFailed
    case fileWriteFailed
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidNotebookFormat:
            return "Invalid notebook format"
        case .serverConnectionFailed:
            return "Failed to connect to Jupyter server"
        case .fileWriteFailed:
            return "Failed to write file"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}