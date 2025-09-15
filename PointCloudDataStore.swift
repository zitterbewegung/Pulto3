import Foundation
import simd

// This file intentionally kept as a shim to avoid duplicate definitions.
// The canonical implementations of PointCloudDataStore and PLYParser (with ASCII + Binary support)
// are provided in PointCloudSupport.swift. Import that file to use the shared store and parser.

// Re-export types by providing typealiases if needed by older code paths.
// If other files import PointCloudDataStore.swift specifically, they will still compile.

// NOTE: Ensure PointCloudSupport.swift is part of the build target.

// Typealiases to the canonical implementations
public typealias PointCloudDataStore = _PointCloudSupport_PointCloudDataStore
public typealias PLYParser = _PointCloudSupport_PLYParser
