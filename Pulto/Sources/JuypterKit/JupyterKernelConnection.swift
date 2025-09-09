//
//  JupyterKernelDelegate.swift
//  Pulto3
//
//  Created by Joshua Herman on 9/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//


import Foundation

public protocol JupyterKernelConnectionDelegate: AnyObject {
    /// Called for any decoded Jupyter message from the websocket
    func kernelConnection(_ connection: JupyterKernelConnection, didReceive message: [String: Any])
    /// Called when the websocket closes or errors
    func kernelConnection(_ connection: JupyterKernelConnection, didCloseWith error: Error?)
}

public final class JupyterKernelConnection {
    public let baseURL: URL
    public let kernelID: String
    public let token: String?
    public weak var delegate: JupyterKernelConnectionDelegate?

    private var ws: URLSessionWebSocketTask?
    private let session: URLSession
    private let sessionID = UUID().uuidString

    public init(base: URL, kernelID: String, token: String? = nil) {
        self.baseURL = base
        self.kernelID = kernelID
        self.token = token

        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: cfg)
    }

    /// Convenience to support call sites that pass `serverURL:` instead of `base:`
    public convenience init(serverURL: URL, kernelID: String, token: String? = nil) {
        self.init(base: serverURL, kernelID: kernelID, token: token)
    }

    /// Convenience to support call sites that pass `server:` (URL) instead of `base:`
    public convenience init(server: URL, kernelID: String, token: String? = nil) {
        self.init(base: server, kernelID: kernelID, token: token)
    }

    public func connect() throws {
        var channelsURL = baseURL
        channelsURL.appendPathComponent("api/kernels/\(kernelID)/channels")
        guard var wsURL = httpToWS(channelsURL) else { throw JupyterError.badURL }
        if let token, var comps = URLComponents(url: wsURL, resolvingAgainstBaseURL: false) {
            var items = comps.queryItems ?? []
            items.append(URLQueryItem(name: "token", value: token))
            comps.queryItems = items
            if let u = comps.url { wsURL = u }
        }

        ws = session.webSocketTask(with: wsURL)
        ws?.resume()
        receiveLoop()
    }

    public func close() {
        ws?.cancel(with: .normalClosure, reason: nil)
        ws = nil
    }

    /// Minimal execute, sends an `execute_request` over the shell channel.
    public func execute(code: String) async throws {
        guard let ws else { throw JupyterError.notConnected }

        let header: [String: Any] = [
            "msg_id": UUID().uuidString,
            "username": "pulto",
            "session": sessionID,
            "msg_type": "execute_request",
            "version": "5.3"
        ]
        let envelope: [String: Any] = [
            "header": header,
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

        let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
        try await ws.send(.data(data))
    }

    // MARK: - Receive loop (logs; expand to delegate if you want UI updates)
    private func receiveLoop() {
        ws?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                #if DEBUG
                switch message {
                case .string(let s): print("[Jupyter WS] \(s.prefix(300))…")
                case .data(let d):   print("[Jupyter WS bin] \(String(data: d, encoding: .utf8) ?? "<?>")")
                @unknown default:    break
                }
                #endif

                // Try to parse payload as JSON and notify delegate
                let data: Data?
                switch message {
                case .string(let s): data = s.data(using: .utf8)
                case .data(let d):   data = d
                @unknown default:    data = nil
                }

                if let data, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.delegate?.kernelConnection(self, didReceive: obj)
                }

            case .failure(let err):
                #if DEBUG
                print("[Jupyter WS error] \(err)")
                #endif
                self.delegate?.kernelConnection(self, didCloseWith: err)
            }
            self.receiveLoop()
        }
    }

    /// Returns a URL with the token query item appended if available.
    private func urlByAppendingToken(_ url: URL) -> URL {
        guard let token, var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = comps.queryItems ?? []
        items.append(URLQueryItem(name: "token", value: token))
        comps.queryItems = items
        return comps.url ?? url
    }
}
