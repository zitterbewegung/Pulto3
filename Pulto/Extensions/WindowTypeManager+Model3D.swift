//
//  WindowTypeManager+Model3D.swift
//  Pulto3
//
//  Adds the missing Model-3D update helper.
//  Make sure this file’s Target Membership includes your app target.
//

import Foundation

extension WindowTypeManager {

    /// Generate a fresh integer window ID.
       /// Wraps the existing getNextWindowID().
       @MainActor
       func generateNewWindowID() -> Int {
           getNextWindowID()
       }
}
