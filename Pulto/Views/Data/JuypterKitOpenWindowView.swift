//
//  OpenWindowView.swift
//  Pulto3
//
//  Created by Joshua Herman on 9/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

struct OpenWindowView: View {
    let window: NewWindowID
    let windowManager: WindowTypeManager

    // Read from environment (provided in EntryPoint.swift)
    @EnvironmentObject var notebookManager: NotebookManager
    @Environment(\.generateNotebookJSON) private var generateNotebookJSON

    var body: some View {
        Group {
            if window.state.tags.contains("Notebook") {
                NotebookWindowView(
                    windowId: window.id,
                    notebookManager: notebookManager,
                    generateNotebookJSON: generateNotebookJSON
                )
            } else {
                fallbackContent(for: window)
            }
        }
    }

    @ViewBuilder
    private func fallbackContent(for window: NewWindowID) -> some View {
        Text("Window #\(window.id): \(window.windowType.displayName)")
    }
}
