//
//  HTTPHelpers.swift
//  Pulto3
//
//  Created by Joshua Herman on 9/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//


import Foundation

func httpToWebSocketURL(_ url: URL) -> URL? {
    var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
    if comps?.scheme == "http"  { comps?.scheme = "ws" }
    if comps?.scheme == "https" { comps?.scheme = "wss" }
    return comps?.url
}

func jsonData(_ object: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: object, options: [])
}
