//
//  SupersetDashboardView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/11/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import Charts

struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct LoginResponse: Decodable {
    let access_token: String
    // let refresh_token: String // If needed
}

func loginToSuperset(username: String, password: String) async throws -> String {
    let url = URL(string: "https://superset.example.com/api/v1/security/login")!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "username": username,
        "password": password,
        "provider": "db", // Change to "ldap" or other if using different auth
        "refresh": true
    ]
    req.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, _) = try await URLSession.shared.data(for: req)

    // Debug: Print raw JSON
    if let jsonString = String(data: data, encoding: .utf8) {
        print("Raw Login JSON Response: \(jsonString)")
    }

    let response = try JSONDecoder().decode(LoginResponse.self, from: data)
    return response.access_token
}

struct NativeChart: View {
    let username: String
    let password: String
    @State private var points: [ChartPoint] = []
    @State private var error: Error? = nil
    @State private var jwt: String = ""

    var body: some View {
        if let error = error {
            Text("Error loading chart: \(error.localizedDescription)")
                .foregroundColor(.red)
        } else {
            Chart(points) {
                LineMark(
                    x: .value("Date", $0.date),
                    y: .value("Metric", $0.value)
                )
            }
            .chartYAxis {
                AxisMarks(position: .trailing)
            }
            .onAppear {
                Task {
                    do {
                        if jwt.isEmpty {
                            jwt = try await loginToSuperset(username: username, password: password)
                        }
                        points = try await fetchSeries(sliceID: 123, jwt: jwt)
                    } catch {
                        self.error = error
                    }
                }
            }
        }
    }
}

struct SupersetDashboardView: View {
    let username: String
    let password: String

    var body: some View {
        NativeChart(username: username, password: password)
            // To expand to full dashboard: Fetch dashboard metadata via API (/api/v1/dashboard/{id}),
            // parse json_metadata for chart IDs and types, then render multiple NativeChart-like views in a layout.
    }
}
