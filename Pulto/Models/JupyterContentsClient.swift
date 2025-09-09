//
//  JupyterContentsClient.swift
//  Pulto3
//
//  Created by Joshua Herman on 9/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//


// JupyterContentsClient.swift
/*
import Foundation

public struct JupyterContentsClient {
    private let baseURLString: () -> String
    private var baseURL: URL { URL(string: baseURLString())! }

    public init(baseURLString: @escaping () -> String) {
        self.baseURLString = baseURLString
    }

    /// PUT /api/contents/<path> with notebook JSON (nbformat dict)
    public func putNotebook(path: String, notebookObject: Any) async throws {
        var url = baseURL
        url.appendPathComponent("api/contents")
        url.appendPathComponent(path)

        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try jsonData([
            "type": "notebook",
            "format": "json",
            "content": notebookObject
        ])

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw JupyterError.badResponse((resp as? HTTPURLResponse)?.statusCode)
        }
    }
}
*/
