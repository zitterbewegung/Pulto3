//
//  GridConstants.swift
//  Pulto
//
//  Created by Joshua Herman on 6/20/25.
//  Copyright © 2025 Apple. All rights reserved.
//


//
//  VisionGridApp.swift
//  VisionGrid
//
//  Created by ChatGPT on 6/20/25.
//  Demonstrates a 3 × 3 grid of visionOS windows that automatically
//  snap together, retain fixed positions, and angle subtly toward the user.
//  Includes Xcode #Preview macros for quick iteration.
//
//  Build with Xcode 16.4 (visionOS 2.4 SDK or newer).
//

import SwiftUI
import RealityKit

// MARK: - Grid Constants
private enum GridConstants {
    static let rows = 3
    static let cols = 3
    static let tileWidth: CGFloat  = 550   // points
    static let tileHeight: CGFloat = 380   // points
    static let gap: CGFloat        = 25    // spacing between windows (points)
}

// MARK: - Math helpers
/// Convert a grid row/column into a CGPoint in window‑placement space.
private func positionForCell(row: Int, col: Int) -> CGPoint {
    // Center of grid is at (0,0). Adjust so that the whole grid is centered.
    let offsetX = CGFloat(col - GridConstants.cols / 2) * (GridConstants.tileWidth  + GridConstants.gap)
    let offsetY = CGFloat(row - GridConstants.rows / 2) * (GridConstants.tileHeight + GridConstants.gap)
    return CGPoint(x: offsetX, y: offsetY)
}

// MARK: - UI building blocks
struct GridTileView: View {
    let row: Int
    let col: Int

    var body: some View {
        ZStack {
            // Transparent background lets the glass show through when using .plain style
            Color.clear
            VStack(spacing: 12) {
                Text("Tile (\(row + 1), \(col + 1))")
                    .font(.title2)
                    .bold()
                Image(systemName: "\((row * 3 + col + 1)).circle")
                    .font(.system(size: 64))
            }
        }
        .padding()
        // Subtle Y‑axis tilt so the whole grid feels like a single slanted surface.
        .rotation3DEffect(.degrees(Double(col - GridConstants.cols / 2) * 3), axis: (x: 0, y: 1, z: 0))
    }
}

/// The launcher opens all nine grid tiles.
struct LauncherView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 24) {
            Text("3×3 Grid Demo")
                .font(.largeTitle)
            Button("Open Grid") {
                for r in 0..<GridConstants.rows {
                    for c in 0..<GridConstants.cols {
                        openWindow(id: "grid-\(r)-\(c)")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
}

// MARK: - Previews
#Preview("Grid Tile Sample") {
    GridTileView(row: 1, col: 1)
        .frame(width: GridConstants.tileWidth, height: GridConstants.tileHeight)
}

#Preview("Launcher View") {
    LauncherView()
        .frame(width: 600, height: 400)
}
