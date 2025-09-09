//
//  JupyterError.swift
//  Pulto3
//
//  Created by Joshua Herman on 9/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//


import Foundation

enum JupyterError: Error {
    case badURL
    case badResponse(Int?)          // preferred name
    case badServerResponse(Int?)    // legacy/alias used by other files
    case notConnected
    case decodeError
}

// Convert http(s) → ws(s) for /api/kernels/<id>/channels
@inline(__always)
func httpToWS(_ url: URL) -> URL? {
    var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
    if comps?.scheme == "http"  { comps?.scheme = "ws" }
    if comps?.scheme == "https" { comps?.scheme = "wss" }
    return comps?.url
}

// JSON encode an arbitrary object (Dictionary/Array) for request bodies
@inline(__always)
func jsonData(_ object: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: object, options: [])
}
