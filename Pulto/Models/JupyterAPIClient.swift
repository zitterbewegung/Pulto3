//
//  JupyterAPIClient.swift
//  Pulto
//
//  Enhanced Jupyter Server API integration with remote execution
//

import Foundation
import Combine

// MARK: - Jupyter API Models

struct JupyterServerConfig: Codable {
    let baseURL: String
    let token: String?
    let name: String
    
    var displayName: String {
        return name.isEmpty ? baseURL : name
    }
    
    var websocketURL: String {
        return baseURL.replacingOccurrences(of: "http://", with: "ws://")
                     .replacingOccurrences(of: "https://", with: "wss://")
    }
}

struct JupyterKernel: Codable, Identifiable {
    let id: String
    let name: String
    let lastActivity: String?
    let executionState: String?
    let connections: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, connections
        case lastActivity = "last_activity"
        case executionState = "execution_state"
    }
}

struct JupyterNotebook: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let type: String
    let size: Int?
    let lastModified: Date?
    let content: JupyterNotebookContent?
    
    var formattedSize: String {
        guard let size = size else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    var formattedLastModified: String {
        guard let lastModified = lastModified else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastModified)
    }
    
    // Custom Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(path)
    }
    
    static func == (lhs: JupyterNotebook, rhs: JupyterNotebook) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.path == rhs.path
    }
}

struct JupyterNotebookContent: Codable {
    let cells: [JupyterCell]
    let metadata: [String: AnyCodable]
    let nbformat: Int
    let nbformatMinor: Int
    
    enum CodingKeys: String, CodingKey {
        case cells, metadata, nbformat
        case nbformatMinor = "nbformat_minor"
    }
}

struct JupyterCell: Codable, Identifiable {
    let id = UUID()
    let cellType: String
    var source: [String]
    let metadata: [String: AnyCodable]?
    var outputs: [JupyterCellOutput]?
    var executionCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case cellType = "cell_type"
        case source, metadata, outputs
        case executionCount = "execution_count"
    }
}

struct JupyterCellOutput: Codable {
    let outputType: String
    let text: [String]?
    let data: [String: AnyCodable]?
    let executionCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case outputType = "output_type"
        case text, data
        case executionCount = "execution_count"
    }
}

// MARK: - Jupyter Messaging Protocol

struct JupyterMessage: Codable {
    let msgId: String
    let msgType: String
    let parentHeader: [String: AnyCodable]?
    let metadata: [String: AnyCodable]?
    let content: [String: AnyCodable]
    let buffers: [String]?
    
    enum CodingKeys: String, CodingKey {
        case msgId = "msg_id"
        case msgType = "msg_type"
        case parentHeader = "parent_header"
        case metadata, content, buffers
    }
}

struct ExecuteRequest: Codable {
    let code: String
    let silent: Bool
    let storeHistory: Bool
    let userExpressions: [String: String]
    let allowStdin: Bool
    
    enum CodingKeys: String, CodingKey {
        case code, silent
        case storeHistory = "store_history"
        case userExpressions = "user_expressions"
        case allowStdin = "allow_stdin"
    }
}

// MARK: - Remote Execution State

class RemoteExecutionSession: ObservableObject {
    @Published var isExecuting = false
    @Published var executionCount = 0
    @Published var outputs: [JupyterCellOutput] = []
    @Published var error: String?
    
    private var webSocket: URLSessionWebSocketTask?
    private let messageId = UUID().uuidString
    
    func reset() {
        isExecuting = false
        outputs = []
        error = nil
    }
}

// MARK: - API Response Models

struct JupyterContentsResponse: Codable {
    let name: String
    let path: String
    let type: String
    let size: Int?
    let lastModified: String?
    let content: [JupyterContentsItem]?
    
    enum CodingKeys: String, CodingKey {
        case name, path, type, size, content
        case lastModified = "last_modified"
    }
}

struct JupyterContentsItem: Codable {
    let name: String
    let path: String
    let type: String
    let size: Int?
    let lastModified: String?
    
    enum CodingKeys: String, CodingKey {
        case name, path, type, size
        case lastModified = "last_modified"
    }
}

struct JupyterNotebookResponse: Codable {
    let name: String
    let path: String
    let type: String
    let size: Int?
    let lastModified: String?
    let content: JupyterNotebookContent
    
    enum CodingKeys: String, CodingKey {
        case name, path, type, size, content
        case lastModified = "last_modified"
    }
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        // Handle common types specifically to avoid encoding issues
        if let dict = value as? [String: Any] {
            self.value = dict.mapValues { AnyCodable($0) }
        } else if let array = value as? [Any] {
            self.value = array.map { AnyCodable($0) }
        } else {
            self.value = value
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [AnyCodable]:
            try container.encode(array)
        case let dictionary as [String: AnyCodable]:
            try container.encode(dictionary)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            // Try to convert to string as fallback
            try container.encode(String(describing: value))
        }
    }
    
    // Add Equatable conformance for better debugging
    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Simple equality check - in practice this might need to be more sophisticated
        return String(describing: lhs.value) == String(describing: rhs.value)
    }
}

// MARK: - Jupyter API Client with Remote Execution

@MainActor
class JupyterAPIClient: ObservableObject {
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var connectionError: String?
    @Published var notebooks: [JupyterNotebook] = []
    @Published var kernels: [JupyterKernel] = []
    @Published var activeKernel: JupyterKernel?
    @Published var isStartingKernel = false
    
    private var config: JupyterServerConfig?
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    private var webSocketTask: URLSessionWebSocketTask?
    
    // Remote execution
    @Published var executionSessions: [String: RemoteExecutionSession] = [:]
    
    // msg_id routing dictionary
    private var msgRouting: [String: String] = [:]
    
    // MARK: - Connection Management
    
    func connect(to config: JupyterServerConfig) async {
        self.config = config
        isConnecting = true
        connectionError = nil
        
        do {
            // Test connection by listing root contents
            let _ = try await listContents(path: "")
            // Load available kernels
            try await loadKernels()
            isConnected = true
            connectionError = nil
        } catch {
            isConnected = false
            connectionError = error.localizedDescription
        }
        
        isConnecting = false
    }
    
    func disconnect() {
        // Close WebSocket connection
        webSocketTask?.cancel()
        webSocketTask = nil
        
        // Clear state
        config = nil
        isConnected = false
        connectionError = nil
        notebooks = []
        kernels = []
        activeKernel = nil
        executionSessions = [:]
        msgRouting = [:]
    }
    
    // MARK: - Kernel Management
    
    func loadKernels() async throws {
        guard let config = config else {
            throw JupyterAPIError.notConnected
        }
        
        let url = buildURL(endpoint: "api/kernels")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = config.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JupyterAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw JupyterAPIError.httpError(httpResponse.statusCode)
        }
        
        let kernelList = try JSONDecoder().decode([JupyterKernel].self, from: data)
        
        await MainActor.run {
            self.kernels = kernelList
        }
    }
    
    func startKernel(name: String = "python3") async throws -> JupyterKernel {
        guard let config = config else {
            throw JupyterAPIError.notConnected
        }
        
        isStartingKernel = true
        
        let url = buildURL(endpoint: "api/kernels")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = config.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let requestBody = ["name": name]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JupyterAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 201 else {
            throw JupyterAPIError.httpError(httpResponse.statusCode)
        }
        
        let kernel = try JSONDecoder().decode(JupyterKernel.self, from: data)
        
        await MainActor.run {
            self.activeKernel = kernel
            self.kernels.append(kernel)
            self.isStartingKernel = false
        }
        
        return kernel
    }
    
    func stopKernel(_ kernel: JupyterKernel) async throws {
        guard let config = config else {
            throw JupyterAPIError.notConnected
        }
        
        let url = buildURL(endpoint: "api/kernels/\(kernel.id)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        if let token = config.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JupyterAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 204 else {
            throw JupyterAPIError.httpError(httpResponse.statusCode)
        }
        
        await MainActor.run {
            self.kernels.removeAll { $0.id == kernel.id }
            if self.activeKernel?.id == kernel.id {
                self.activeKernel = nil
            }
        }
    }
    
    // MARK: - Remote Execution
    
    func executeCell(_ cell: JupyterCell, in kernel: JupyterKernel) async throws {
        guard let config = config else {
            throw JupyterAPIError.notConnected
        }
        
        let parentMsgId = UUID().uuidString
        // Create execution session
        let sessionId = cell.id.uuidString
        let session = RemoteExecutionSession()
        
        await MainActor.run {
            self.executionSessions[sessionId] = session
            session.isExecuting = true
            session.reset()
            self.msgRouting[parentMsgId] = sessionId
        }
        
        // Create WebSocket connection if needed
        if webSocketTask == nil {
            try await connectToKernel(kernel)
            startListening()
        }
        
        // Send execute request
        let executeRequest = ExecuteRequest(
            code: cell.source.joined(separator: "\n"),
            silent: false,
            storeHistory: true,
            userExpressions: [:],
            allowStdin: false
        )
        
        let message = JupyterMessage(
            msgId: parentMsgId,
            msgType: "execute_request",
            parentHeader: nil,
            metadata: nil,
            content: [
                "code": AnyCodable(executeRequest.code),
                "silent": AnyCodable(executeRequest.silent),
                "store_history": AnyCodable(executeRequest.storeHistory),
                "user_expressions": AnyCodable(executeRequest.userExpressions),
                "allow_stdin": AnyCodable(executeRequest.allowStdin)
            ],
            buffers: nil
        )
        
        let messageData = try JSONEncoder().encode(message)
        let messageString = String(data: messageData, encoding: .utf8)!
        
        try await webSocketTask?.send(.string(messageString))
    }
    
    private func connectToKernel(_ kernel: JupyterKernel) async throws {
        guard let config = config else {
            throw JupyterAPIError.notConnected
        }
        var wsURL = "\(config.websocketURL)/api/kernels/\(kernel.id)/channels"
        if let token = config.token, !token.isEmpty {
            let separator = wsURL.contains("?") ? "&" : "?"
            wsURL += "\(separator)token=\(token)"
        }
        guard let url = URL(string: wsURL) else {
            throw JupyterAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        if let token = config.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
    }
    
    private func startListening() {
        guard let webSocket = webSocketTask else { return }
        webSocket.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
                    await self?.handleWebSocketMessage(message)
                    self?.startListening()
                case .failure(let error):
                    if let keys = self?.executionSessions.keys {
                        for key in keys {
                            self?.executionSessions[key]?.error = error.localizedDescription
                            self?.executionSessions[key]?.isExecuting = false
                        }
                    }
                    // Optionally clear routing on failure to avoid stale mappings
                    self?.msgRouting.removeAll()
                }
            }
        }
    }
    
    @MainActor
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) async {
        func routeSession(for parentId: String?) -> String? {
            guard let parentId else { return nil }
            return msgRouting[parentId]
        }
        switch message {
        case .string(let text):
            do {
                let data = text.data(using: .utf8)!
                let jupyterMessage = try JSONDecoder().decode(JupyterMessage.self, from: data)
                let parentId = (jupyterMessage.parentHeader?["msg_id"]?.value as? String)
                let key = routeSession(for: parentId)
                if let key, let session = executionSessions[key] {
                    switch jupyterMessage.msgType {
                    case "execute_reply":
                        session.isExecuting = false
                        if let cnt = jupyterMessage.content["execution_count"]?.value as? Int {
                            session.executionCount = cnt
                        }
                    case "stream":
                        if let text = jupyterMessage.content["text"]?.value as? [String] {
                            let output = JupyterCellOutput(outputType: "stream", text: text, data: nil, executionCount: nil)
                            session.outputs.append(output)
                        }
                    case "display_data", "execute_result":
                        if let data = jupyterMessage.content["data"]?.value as? [String: Any] {
                            let output = JupyterCellOutput(outputType: jupyterMessage.msgType, text: nil, data: data.mapValues { AnyCodable($0) }, executionCount: jupyterMessage.content["execution_count"]?.value as? Int)
                            session.outputs.append(output)
                        }
                    case "error":
                        let err = jupyterMessage.content["evalue"]?.value as? String ?? "Execution error"
                        session.error = err
                        session.isExecuting = false
                    default:
                        break
                    }
                }
            } catch {
                // Ignore decode errors for now
            }
        case .data(_):
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - Remote Editing

    func saveNotebook(_ notebook: JupyterNotebook, with content: JupyterNotebookContent) async throws {
        guard let config = config else {
            throw JupyterAPIError.notConnected
        }
        
        let url = buildURL(endpoint: "api/contents/\(notebook.path)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = config.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Create a simplified structure for JSON encoding
        struct SaveRequest: Codable {
            let type: String
            let format: String
            let content: NotebookContent
        }
        
        struct NotebookContent: Codable {
            let cells: [Cell]
            let metadata: [String: AnyCodable]
            let nbformat: Int
            let nbformatMinor: Int
        }
        
        struct Cell: Codable {
            let cellType: String
            let source: [String]
            let metadata: [String: AnyCodable]?
            let outputs: [Output]?
            let executionCount: Int?
            
            enum CodingKeys: String, CodingKey {
                case cellType = "cell_type"
                case source, metadata, outputs
                case executionCount = "execution_count"
            }
        }
        
        struct Output: Codable {
            let outputType: String
            let text: [String]?
            let data: [String: AnyCodable]?
            let executionCount: Int?
            
            enum CodingKeys: String, CodingKey {
                case outputType = "output_type"
                case text, data
                case executionCount = "execution_count"
            }
        }
        
        // Convert the content to our simplified structure
        let cells = content.cells.map { cell in
            Cell(
                cellType: cell.cellType,
                source: cell.source,
                metadata: cell.metadata,
                outputs: cell.outputs?.map { output in
                    Output(
                        outputType: output.outputType,
                        text: output.text,
                        data: output.data,
                        executionCount: output.executionCount
                    )
                },
                executionCount: cell.executionCount
            )
        }
        
        let notebookContent = NotebookContent(
            cells: cells,
            metadata: content.metadata,
            nbformat: content.nbformat,
            nbformatMinor: content.nbformatMinor
        )
        
        let saveRequest = SaveRequest(
            type: "notebook",
            format: "json",
            content: notebookContent
        )
        
        do {
            // Encode the request
            let requestData = try JSONEncoder().encode(saveRequest)
            request.httpBody = requestData
            
            // Send the request
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw JupyterAPIError.invalidResponse
            }
            
            // Check for successful response (200 or 201 are both valid for Jupyter API)
            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                // Try to parse error response for better debugging
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Jupyter API Error Response: \(errorString)")
                }
                throw JupyterAPIError.httpError(httpResponse.statusCode)
            }
            
            print("Notebook saved successfully to \(notebook.path)")
        } catch let encodingError as EncodingError {
            print("JSON Encoding Error: \(encodingError)")
            throw JupyterAPIError.decodingFailed
        } catch let decodingError as DecodingError {
            print("JSON Decoding Error: \(decodingError)")
            throw JupyterAPIError.decodingFailed
        } catch {
            print("Network Error: \(error)")
            throw JupyterAPIError.networkError(error)
        }
    }
    
    // MARK: - API Methods (Unchanged from previous implementation)
    
    func listNotebooks(in path: String = "") async throws -> [JupyterNotebook] {
        guard let config = config else {
            throw JupyterAPIError.notConnected
        }
        
        let contents = try await listContents(path: path)
        var notebooks: [JupyterNotebook] = []
        
        for item in contents {
            if item.type == "notebook" {
                let lastModified = parseISO8601Date(item.lastModified)
                let notebook = JupyterNotebook(
                    name: item.name,
                    path: item.path,
                    type: item.type,
                    size: item.size,
                    lastModified: lastModified,
                    content: nil
                )
                notebooks.append(notebook)
            }
        }
        
        await MainActor.run {
            self.notebooks = notebooks
        }
        
        return notebooks
    }
    
    func fetchNotebook(at path: String) async throws -> JupyterNotebook {
        guard let config = config else {
            throw JupyterAPIError.notConnected
        }
        
        let url = buildURL(endpoint: "api/contents/\(path)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = config.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JupyterAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw JupyterAPIError.httpError(httpResponse.statusCode)
        }
        
        let notebookResponse = try JSONDecoder().decode(JupyterNotebookResponse.self, from: data)
        let lastModified = parseISO8601Date(notebookResponse.lastModified)
        
        return JupyterNotebook(
            name: notebookResponse.name,
            path: notebookResponse.path,
            type: notebookResponse.type,
            size: notebookResponse.size,
            lastModified: lastModified,
            content: notebookResponse.content
        )
    }
    
    private func listContents(path: String) async throws -> [JupyterContentsItem] {
        guard let config = config else {
            throw JupyterAPIError.notConnected
        }
        
        let endpoint = path.isEmpty ? "api/contents" : "api/contents/\(path)"
        let url = buildURL(endpoint: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = config.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JupyterAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw JupyterAPIError.httpError(httpResponse.statusCode)
        }
        
        // Try to decode as directory listing first
        if let contentsResponse = try? JSONDecoder().decode(JupyterContentsResponse.self, from: data),
           let content = contentsResponse.content {
            return content
        }
        
        // If not a directory, try to decode as single item array
        if let singleItem = try? JSONDecoder().decode(JupyterContentsItem.self, from: data) {
            return [singleItem]
        }
        
        throw JupyterAPIError.decodingFailed
    }
    
    // MARK: - Helper Methods
    
    private func buildURL(endpoint: String) -> URL {
        guard let config = config else {
            fatalError("No configuration available")
        }
        
        var baseURL = config.baseURL
        if !baseURL.hasSuffix("/") {
            baseURL += "/"
        }
        
        return URL(string: baseURL + endpoint)!
    }
    
    private func parseISO8601Date(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    // MARK: - Notebook Import Conversion (Modified to disable local execution)
    
    func convertToNotebookFile(_ jupyterNotebook: JupyterNotebook) -> NotebookFile? {
        guard let content = jupyterNotebook.content else { return nil }
        
        // Create temporary URL for the notebook data
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent(jupyterNotebook.name)
        
        do {
            // Convert to standard Jupyter notebook JSON format but mark as read-only
            let notebookData = try createNotebookData(from: content, metadata: ["pulto_remote_only": true])
            try notebookData.write(to: tempURL)
            
            return NotebookFile(
                url: tempURL,
                name: jupyterNotebook.name,
                size: Int64(jupyterNotebook.size ?? 0),
                createdDate: Date(),
                modifiedDate: jupyterNotebook.lastModified ?? Date()
            )
        } catch {
            print("Failed to convert Jupyter notebook: \(error)")
            return nil
        }
    }
    
    private func createNotebookData(from content: JupyterNotebookContent, metadata: [String: Any]) throws -> Data {
        var notebookMetadata = content.metadata.mapValues { $0.value }
        notebookMetadata.merge(metadata) { (_, new) in new }
        
        let notebookDict: [String: Any] = [
            "cells": content.cells.map { cell in
                var cellDict: [String: Any] = [
                    "cell_type": cell.cellType,
                    "source": cell.source
                ]
                
                if let metadata = cell.metadata {
                    cellDict["metadata"] = metadata.mapValues { $0.value }
                }
                
                if let outputs = cell.outputs {
                    cellDict["outputs"] = outputs.map { output in
                        var outputDict: [String: Any] = [
                            "output_type": output.outputType
                        ]
                        if let text = output.text {
                            outputDict["text"] = text
                        }
                        if let data = output.data {
                            outputDict["data"] = data.mapValues { $0.value }
                        }
                        return outputDict
                    }
                }
                
                if let executionCount = cell.executionCount {
                    cellDict["execution_count"] = executionCount
                }
                
                return cellDict
            },
            "metadata": notebookMetadata,
            "nbformat": content.nbformat,
            "nbformat_minor": content.nbformatMinor
        ]
        
        return try JSONSerialization.data(withJSONObject: notebookDict, options: .prettyPrinted)
    }
    
    // MARK: - Ensure Session
    
    struct SessionCreateResponse: Decodable {
        struct Kernel: Decodable { let id: String; let name: String }
        let id: String
        let kernel: Kernel
    }

    func ensureSession(forNotebookPath path: String, kernelName: String = "python3") async throws {
        guard let config = config else { throw JupyterAPIError.notConnected }
        let url = buildURL(endpoint: "api/sessions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = config.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: Any] = [
            "kernel": ["name": kernelName],
            "name": UUID().uuidString,
            "path": path,
            "type": "notebook"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw JupyterAPIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw JupyterAPIError.httpError(http.statusCode) }
        let info = try JSONDecoder().decode(SessionCreateResponse.self, from: data)

        // Update active kernel from session
        let kernel = JupyterKernel(id: info.kernel.id, name: info.kernel.name, lastActivity: nil, executionState: nil, connections: nil)
        await MainActor.run {
            self.activeKernel = kernel
            if !self.kernels.contains(where: { $0.id == kernel.id }) {
                self.kernels.append(kernel)
            }
        }
    }
}

// MARK: - Error Types

enum JupyterAPIError: LocalizedError {
    case notConnected
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingFailed
    case networkError(Error)
    case kernelNotAvailable
    case executionFailed(String)
    case saveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to Jupyter server"
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingFailed:
            return "Failed to decode server response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .kernelNotAvailable:
            return "No kernel available for execution"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .saveFailed(let message):
            return "Failed to save notebook: \(message)"
        }
    }
}

// MARK: - Helper Methods for Testing

extension JupyterAPIClient {
    /// Test method to verify notebook submission functionality
    func testNotebookSubmission() async throws -> Bool {
        // Create a simple test notebook
        let testCell = JupyterCell(
            cellType: "code",
            source: ["print('Hello, Jupyter!')"],
            metadata: ["trusted": AnyCodable(true)],
            outputs: nil,
            executionCount: nil
        )
        
        let testContent = JupyterNotebookContent(
            cells: [testCell],
            metadata: ["test": AnyCodable(true)],
            nbformat: 4,
            nbformatMinor: 4
        )
        
        let testNotebook = JupyterNotebook(
            name: "test_notebook.ipynb",
            path: "test_notebook.ipynb",
            type: "notebook",
            size: nil,
            lastModified: Date(),
            content: nil
        )
        
        do {
            try await self.saveNotebook(testNotebook, with: testContent)
            print("Test notebook submission successful!")
            return true
        } catch {
            print("Test notebook submission failed: \(error)")
            throw error
        }
    }
}

// MARK: - Static Helper Methods for Testing

/// Static test method to verify notebook submission functionality with a client instance
func testNotebookSubmissionWithClient(_ client: JupyterAPIClient) async throws -> Bool {
    return try await client.testNotebookSubmission()
}

