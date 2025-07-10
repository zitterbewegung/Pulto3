//
//  WindowTypeManager+Replace.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/10/25.
//  Copyright © 2025 Apple. All rights reserved.
//


//
//  WindowTypeManager+Replace.swift
//  Pulto
//
//  Created by ChatGPT on 2025-07-10.
//

import SwiftUI

/// Public helper for safely mutating the window list from helpers
/// like `SaveNotebookDialog`, without exposing `windows` itself.
@MainActor
extension WindowTypeManager {

    /// Replace an existing window (matched by `id`) or append if absent.
    public func replaceWindow(_ window: NewWindowID) {
        if let idx = windows.firstIndex(where: { $0.id == window.id }) {
            windows[idx] = window
        } else {
            windows.append(window)
        }
    }
}