//
//  JupyterError.swift
//  Pulto3
//
//  Created by Joshua Herman on 9/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//

/*
// JupyterHelpers.swift
import Foundation

enum JupyterError: Error {
    case badURL
    case badResponse(Int?)
    case notConnected
    case decode
}

@inline(__always)
func httpToWS(_ url: URL) -> URL? {
    var c = URLComponents(url: url, resolvingAgainstBaseURL: false)
    if c?.scheme == "http"  { c?.scheme = "ws"  }
    if c?.scheme == "https" { c?.scheme = "wss" }
    return c?.url
}

@inline(__always)
func jsonData(_ object: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: object, options: [])
}
*/
