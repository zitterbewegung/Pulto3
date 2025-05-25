//
//  ContentView.swift
//  SwiftChartsWWDC24
//
//  Created by Joshua Herman on 4/10/25.
//  Copyright © 2025 Apple. All rights reserved.
//


import SwiftUI
import RealityKit

struct PultoEnvironment: View {
    var body: some View {
        ZStack {
            // RealityView for the 3D model
            RealityView { content in
                // Load and add your 3D model
                if let modelEntity = try? ModelEntity.load(named: "Pulto_1_2374") {
                    // Position the model in the spatial environment
                    modelEntity.position = SIMD3(x: 0, y: 0, z: -1) // Place it 1 meter in front
                    content.add(modelEntity)
                }
            }
            .frame(depth: 1000) // Define the depth of the 3D space

            // SwiftUI Window alongside the 3D model
            VStack {
                Text("Control Window")
                    .font(.headline)
                Button("Rotate Model") {
                    // Add logic to interact with the 3D model if needed
                }
                .padding()
            }
            .frame(width: 300, height: 200)
            .background(.ultraThinMaterial) // VisionOS-style material
            .cornerRadius(12)
            .offset(x: 400, y: 0) // Position the window to the right of the 3D model
        }
    }
}

// Preview for development
#Preview {
    PultoEnvironment()
}
