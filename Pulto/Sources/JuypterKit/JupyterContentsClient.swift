//
//  JupyterContentsClient.swift
//  Pulto3
//
//  Created by Joshua Herman on 9/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//


import Foundation

/// Minimal client for Jupyter Contents API used by NotebookManager.
/// Matches initializer + method signatures your code already calls.
public struct JupyterContentsClient {
    private let baseURLString: () -> String
    private let tokenProvider: () -> String?

    /// - Parameters:
    ///   - baseURLString: e.g. "http://127.0.0.1:8888"
    ///   - token: optional bearer token provider if your server requires it (Carnets usually doesn't)
    public init(baseURLString: @escaping () -> String,
                token: @escaping () -> String? = { nil }) {
        self.baseURLString = baseURLString
        self.tokenProvider = token
    }

    /// PUT /api/contents/<path> with an nbformat JSON object.
    /// `notebookObject` must be a JSON object (Dictionary/Array from JSONSerialization).
    @discardableResult
    public func putNotebook(path: String, notebookObject: Any) async throws -> Void {
        // Build base URL
        guard var url = URL(string: baseURLString()) else {
            throw URLError(.badURL)
        }
        url.appendPathComponent("api/contents")

        // Normalize and append the notebook path safely
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        for comp in trimmed.split(separator: "/") {
            url.appendPathComponent(String(comp))
        }

        // Create request
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Optional auth header if provided
        if let tok = tokenProvider(), !tok.isEmpty {
            req.addValue("token \(tok)", forHTTPHeaderField: "Authorization")
        }

        // Body per Jupyter Contents API for notebooks
        let body: [String: Any] = [
            "type": "notebook",
            "format": "json",
            "content": notebookObject
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        // Perform request
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "JupyterContentsClient",
                          code: code,
                          userInfo: [NSLocalizedDescriptionKey: "PUT /api/contents failed with status \(code)"])
        }
    }
}