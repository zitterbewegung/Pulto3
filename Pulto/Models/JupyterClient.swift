//
//  JupyterClient.swift
//  Pulto3
//
//  Created by Joshua Herman on 9/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//


// JupyterClient.swift
import Foundation

public final class JupyterClient {
    // Inputs
    private let serverURL: URL

    // Session state
    private var sessionID: String?
    private var kernelID: String?

    // WS
    private var ws: URLSessionWebSocketTask?
    private let wsSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 60
        return URLSession(configuration: cfg)
    }()

    public init(serverURLString: String) {
        self.serverURL = URL(string: serverURLString)!
    }

    // MARK: Session lifecycle

    /// Create a session for a notebook path. Returns the session id (your manager stores it).
    public func ensureSession(notebookPath: String) async throws -> String {
        var url = serverURL
        url.appendPathComponent("api/sessions")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try jsonData([
            "kernel": ["name": "python3"],
            "name": UUID().uuidString,
            "path": notebookPath,
            "type": "notebook"
        ])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw JupyterError.badResponse((resp as? HTTPURLResponse)?.statusCode)
        }

        // Minimal decode of session+kernel ids
        struct SessionInfo: Decodable {
            struct Kernel: Decodable { let id: String }
            let id: String
            let kernel: Kernel
        }
        let info = try JSONDecoder().decode(SessionInfo.self, from: data)
        self.sessionID = info.id
        self.kernelID = info.kernel.id
        return info.id
    }

    /// Connect to kernel channels over WebSocket
    public func connectChannels() async throws {
        guard let kernelID else { throw JupyterError.notConnected }
        var url = serverURL
        url.appendPathComponent("api/kernels/\(kernelID)/channels")
        guard let wsURL = httpToWS(url) else { throw JupyterError.badURL }

        ws = wsSession.webSocketTask(with: wsURL)
        ws?.resume()
        receiveLoop()
    }

    // MARK: Exec

    public func execute(code: String) async throws {
        guard let ws else { throw JupyterError.notConnected }
        let hdr: [String: Any] = [
            "msg_id": UUID().uuidString,
            "username": "pulto",
            "session": UUID().uuidString,
            "msg_type": "execute_request",
            "version": "5.3"
        ]
        let env: [String: Any] = [
            "header": hdr,
            "parent_header": [:],
            "metadata": [:],
            "content": [
                "code": code,
                "silent": false,
                "store_history": true,
                "user_expressions": [:],
                "allow_stdin": false,
                "stop_on_error": true
            ],
            "channel": "shell"
        ]
        let data = try JSONSerialization.data(withJSONObject: env)
        try await ws.send(.data(data))
    }

    public func interruptKernel() async {
        guard let kernelID else { return }
        var url = serverURL
        url.appendPathComponent("api/kernels/\(kernelID)/interrupt")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        _ = try? await URLSession.shared.data(for: req) // fire-and-forget
    }

    public func shutdownSession() async {
        guard let sessionID else { return }
        var url = serverURL
        url.appendPathComponent("api/sessions/\(sessionID)")

        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        _ = try? await URLSession.shared.data(for: req)

        ws?.cancel(with: .normalClosure, reason: nil)
        ws = nil
    }

    // MARK: Receive (minimal logging; expand if you want UI updates)

    private func receiveLoop() {
        ws?.receive { [weak self] result in
            switch result {
            case .success(let msg):
                switch msg {
                case .string(let s):
                    #if DEBUG
                    print("[Jupyter WS] \(s.prefix(300))…")
                    #endif
                case .data(let d):
                    if let s = String(data: d, encoding: .utf8) {
                        #if DEBUG
                        print("[Jupyter WS bin] \(s.prefix(300))…")
                        #endif
                    }
                @unknown default: break
                }
            case .failure(let err):
                #if DEBUG
                print("[Jupyter WS error] \(err)")
                #endif
            }
            self?.receiveLoop()
        }
    }
}
