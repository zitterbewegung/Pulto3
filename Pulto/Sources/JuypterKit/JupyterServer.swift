//
//  JupyterServer.swift
//  Pulto3
//
//  Created by Joshua Herman on 9/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//


import Foundation

public struct JupyterServer {
    public var baseURL: URL
    public var token: String? // If your server needs token auth (Carnets usually doesn’t)
    public var requestTimeout: TimeInterval
    public var resourceTimeout: TimeInterval

    public init(baseURL: URL,
                token: String? = nil,
                requestTimeout: TimeInterval = 10,
                resourceTimeout: TimeInterval = 30) {
        self.baseURL = baseURL
        self.token = token
        self.requestTimeout = requestTimeout
        self.resourceTimeout = resourceTimeout
    }

    public func makeSession() -> URLSession {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = requestTimeout
        cfg.timeoutIntervalForResource = resourceTimeout
        return URLSession(configuration: cfg)
    }

    public func applyAuth(to request: inout URLRequest) {
        if let token {
            request.addValue("token \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}

public enum LegacyJupyterError: Error {
    case badURL
    case badServerResponse(Int?)
    case socketNotConnected
    case decodeError
}
