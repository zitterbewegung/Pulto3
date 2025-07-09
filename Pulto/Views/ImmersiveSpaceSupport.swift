//
//  ImmersiveSpaceSupport.swift
//  Pulto
//
//  Created by Assistant on 12/29/2024.
//

import SwiftUI

// MARK: - Immersive Space Entry Button

struct ImmersiveSpaceEntryButton: View {
    @StateObject private var spatialManager = SpatialWindowManager.shared
    @StateObject private var windowManager = WindowTypeManager.shared
    
    var body: some View {
        Button(action: {
            if spatialManager.isImmersiveSpaceActive {
                spatialManager.exitImmersiveSpace()
            } else {
                spatialManager.enterImmersiveSpace()
            }
        }) {
            Label(
                spatialManager.isImmersiveSpaceActive ? "Exit Immersive Space" : "Enter Immersive Space",
                systemImage: spatialManager.isImmersiveSpaceActive ? "xmark.circle" : "cube.transparent"
            )
        }
        .buttonStyle(.borderedProminent)
        .disabled(windowManager.getAllWindows(onlyOpen: true).isEmpty)
    }
}

// MARK: - Immersive Space View Modifier

struct ImmersiveSpaceModifier: ViewModifier {
    @StateObject private var spatialManager = SpatialWindowManager.shared
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    func body(content: Content) -> some View {
        content
            .onChange(of: spatialManager.isImmersiveSpaceActive) { isActive in
                if isActive {
                    Task {
                        await openImmersiveSpace(id: "immersive-workspace")
                    }
                } else {
                    Task {
                        await dismissImmersiveSpace()
                    }
                }
            }
    }
}

extension View {
    func immersiveSpaceSupport() -> some View {
        self.modifier(ImmersiveSpaceModifier())
    }
}