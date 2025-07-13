//
//  ContentView.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/13/25.
//  Copyright © 2025 Apple. All rights reserved.
//


import SwiftUI
import RealityKit

struct TestContentView: View {
    var body: some View {
        Model3D(url: URL(string: "https://developer.apple.com/augmented-reality/quick-look/models/biplane/toy_biplane_idle.usdz")!) { model in
            model
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            ProgressView()
        }
    }
}
#Preview {
    TestContentView()
}
