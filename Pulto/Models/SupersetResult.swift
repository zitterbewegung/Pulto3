//
//  SupersetResult.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/11/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import Foundation

struct SupersetResult: Decodable {
    struct Data: Decodable {
        struct Record: Decodable {
            let __timestamp: Date
            let value: Double
        }
        let data: [Record]
    }
    let result: [Data]
}

func fetchSeries(sliceID: Int, jwt: String, supersetURL: String) async throws -> [ChartPoint] {
    let url = URL(string: "\(supersetURL)/api/v1/chart/data?form_data=%7B%22slice_id%22:\(sliceID)%7D")!
    var req = URLRequest(url: url)
    req.addValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: req)

    // Debug: Print raw JSON to inspect the response (e.g., in Xcode console)
    if let jsonString = String(data: data, encoding: .utf8) {
        print("Raw Superset JSON Response: \(jsonString)")
    } else {
        print("Failed to decode response as UTF-8 string")
    }

    let decoder = JSONDecoder()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"  // Adjust if your timestamps include timezone (e.g., "yyyy-MM-dd HH:mm:ssZ") or are in a different format
    formatter.timeZone = TimeZone(secondsFromGMT: 0)  // Assume UTC; adjust if needed
    decoder.dateDecodingStrategy = .formatted(formatter)

    let superset = try decoder.decode(SupersetResult.self, from: data)
    return superset.result.flatMap { payload in
        payload.data.map { ChartPoint(date: $0.__timestamp, value: $0.value) }
    }
}