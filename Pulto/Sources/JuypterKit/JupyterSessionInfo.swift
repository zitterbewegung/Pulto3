//
//  JupyterSessionInfo.swift
//  Pulto3
//
//  Created by Joshua Herman on 9/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//


import Foundation

public struct JupyterSessionInfo: Decodable {
    public struct Kernel: Decodable { public let id: String; public let name: String? }
    public let id: String
    public let path: String
    public let kernel: Kernel
}

public struct JupyterSessionsClient {
    private let baseURLString: () -> String
    private var baseURL: URL { URL(string: baseURLString())! }

    public init(baseURLString: @escaping () -> String) {
        self.baseURLString = baseURLString
    }

    /// POST /api/sessions — create a session for the notebook at `notebookPath`.
    @discardableResult
    public func ensureSession(notebookPath: String) async throws -> JupyterSessionInfo {
        var url = baseURL
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

        let (data, response) = try await URLSession.shared.data(for: req)

        let statusCode = (response as? HTTPURLResponse)?.statusCode
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JupyterError.badServerResponse(statusCode)
        }

        return try JSONDecoder().decode(JupyterSessionInfo.self, from: data)
    }

    /// DELETE /api/sessions/{id}
    public func deleteSession(id: String) async throws {
        var url = baseURL
        url.appendPathComponent("api/sessions/\(id)")

        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: req)

        let statusCode = (response as? HTTPURLResponse)?.statusCode
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JupyterError.badServerResponse(statusCode)
        }
    }

    /// POST /api/kernels/{id}/interrupt
    public func interruptKernel(id: String) async throws {
        var url = baseURL
        url.appendPathComponent("api/kernels/\(id)/interrupt")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        let (_, response) = try await URLSession.shared.data(for: req)

        let statusCode = (response as? HTTPURLResponse)?.statusCode
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JupyterError.badServerResponse(statusCode)
        }
    }
}
