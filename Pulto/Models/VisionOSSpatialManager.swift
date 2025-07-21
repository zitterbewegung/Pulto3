//
//  VisionOSSpatialManager.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/21/25.
//  Copyright © 2025 Apple. All rights reserved.
//  Native visionOS spatial computing integration for data visualization

import SwiftUI
import RealityKit
import Combine

// MARK: - VisionOS Spatial Manager

@MainActor
class VisionOSSpatialManager: ObservableObject {
    static let shared = VisionOSSpatialManager()
    
    // MARK: - Published Properties
    @Published var spatialAnchors: [UUID: SpatialAnchorData] = [:]
    @Published var immersiveSpaceActive = false
    @Published var spatialTrackingQuality: SpatialTrackingQuality = .good
    @Published var error: SpatialTrackingError?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private weak var windowManager: WindowTypeManager?
    
    // Coordinate system for spatial positioning
    private var worldOrigin: Transform = Transform.identity
    private var userHeadPosition: SIMD3<Float> = SIMD3<Float>(0, 1.6, 0) // Default eye level
    
    private init() {}
    
    // MARK: - Setup & Configuration
    
    func configure(with windowManager: WindowTypeManager) {
        self.windowManager = windowManager
        setupSpatialTracking()
    }
    
    private func setupSpatialTracking() {
        // visionOS automatically handles world tracking - we just manage our spatial anchors
        print("🌍 VisionOS: Spatial tracking configured")
    }
    
    // MARK: - Spatial Anchor Management
    
    func createSpatialAnchor(for windowID: Int, at transform: Transform) -> UUID {
        let anchorID = UUID()
        let anchorData = SpatialAnchorData(
            id: anchorID,
            windowID: windowID,
            transform: transform,
            isActive: true,
            createdAt: Date()
        )
        
        spatialAnchors[anchorID] = anchorData
        
        // Update window with spatial anchor information
        updateWindowWithSpatialAnchor(windowID: windowID, anchorID: anchorID, transform: transform)
        
        print("🔗 VisionOS: Created spatial anchor \(anchorID) for window #\(windowID)")
        return anchorID
    }
    
    func removeSpatialAnchor(for windowID: Int) {
        // Find and remove anchor associated with this window
        if let anchorID = findAnchorID(for: windowID) {
            spatialAnchors.removeValue(forKey: anchorID)
            
            // Remove anchor tag from window
            windowManager?.removeWindowTag(windowID, tag: "spatial-anchored:\(anchorID.uuidString)")
            
            print("🗑️ VisionOS: Removed spatial anchor \(anchorID) for window #\(windowID)")
        }
    }
    
    func updateAnchorTransform(_ anchorID: UUID, transform: Transform) {
        guard var anchorData = spatialAnchors[anchorID] else { return }
        
        anchorData.transform = transform
        anchorData.lastUpdated = Date()
        spatialAnchors[anchorID] = anchorData
        
        // Update associated window position
        if let windowManager = windowManager {
            let position = WindowPosition(
                x: Double(transform.translation.x),
                y: Double(transform.translation.y),
                z: Double(transform.translation.z),
                width: windowManager.getWindow(for: anchorData.windowID)?.position.width ?? 400,
                height: windowManager.getWindow(for: anchorData.windowID)?.position.height ?? 300
            )
            
            windowManager.updateWindowPosition(anchorData.windowID, position: position)
        }
    }
    
    // MARK: - Window Integration
    
    private func updateWindowWithSpatialAnchor(windowID: Int, anchorID: UUID, transform: Transform) {
        guard let windowManager = windowManager else { return }
        
        // Convert transform to window position
        let position = WindowPosition(
            x: Double(transform.translation.x),
            y: Double(transform.translation.y),
            z: Double(transform.translation.z),
            width: windowManager.getWindow(for: windowID)?.position.width ?? 400,
            height: windowManager.getWindow(for: windowID)?.position.height ?? 300
        )
        
        windowManager.updateWindowPosition(windowID, position: position)
        
        // Tag window as spatially anchored
        windowManager.addWindowTag(windowID, tag: "spatial-anchored:\(anchorID.uuidString)")
        windowManager.addWindowTag(windowID, tag: "visionos-spatial")
    }
    
    private func findAnchorID(for windowID: Int) -> UUID? {
        return spatialAnchors.values.first(where: { $0.windowID == windowID })?.id
    }
    
    // MARK: - Spatial Positioning
    
    func getOptimalSpatialPlacement(for windowType: WindowType, around userPosition: SIMD3<Float>) -> Transform {
        let config = getPlacementConfig(for: windowType)
        
        // Calculate position in a circle around user
        let angleOffset = Float.random(in: -0.3...0.3) // Add some randomness
        let angle = config.preferredAngle + angleOffset
        
        let distance = config.distance
        let height = userPosition.y + config.heightOffset
        
        let position = SIMD3<Float>(
            userPosition.x + distance * sin(angle),
            height,
            userPosition.z + distance * cos(angle)
        )
        
        var transform = Transform.identity
        transform.translation = position
        
        // Rotate to face user
        let lookDirection = normalize(userPosition - position)
        let rotation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: lookDirection)
        transform.rotation = rotation
        
        return transform
    }
    
    private func getPlacementConfig(for windowType: WindowType) -> SpatialPlacementConfig {
        switch windowType {
        case .charts:
            return SpatialPlacementConfig(distance: 1.2, heightOffset: 0.0, preferredAngle: 0.0)
        case .spatial, .pointcloud:
            return SpatialPlacementConfig(distance: 1.8, heightOffset: -0.1, preferredAngle: 0.5)
        case .model3d:
            return SpatialPlacementConfig(distance: 2.0, heightOffset: 0.1, preferredAngle: -0.5)
        case .column:
            return SpatialPlacementConfig(distance: 1.0, heightOffset: 0.2, preferredAngle: 0.3)
        case .volume:
            return SpatialPlacementConfig(distance: 1.5, heightOffset: -0.2, preferredAngle: -0.3)
        }
    }
    
    // MARK: - Spatial Queries
    
    func findNearbySpatialAnchors(to position: SIMD3<Float>, within distance: Float) -> [UUID] {
        return spatialAnchors.compactMap { (anchorID, anchorData) in
            let anchorPosition = anchorData.transform.translation
            let distanceToAnchor = simd_distance(position, anchorPosition)
            
            return distanceToAnchor <= distance ? anchorID : nil
        }
    }
    
    func getSpatialLayout() -> SpatialLayout {
        let activeAnchors = spatialAnchors.values.filter { $0.isActive }
        
        return SpatialLayout(
            anchors: activeAnchors,
            userPosition: userHeadPosition,
            boundingBox: calculateBoundingBox(for: activeAnchors)
        )
    }
    
    private func calculateBoundingBox(for anchors: [SpatialAnchorData]) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard !anchors.isEmpty else {
            return (SIMD3<Float>(0, 0, 0), SIMD3<Float>(0, 0, 0))
        }
        
        let positions = anchors.map { $0.transform.translation }
        
        var minBounds = positions[0]
        var maxBounds = positions[0]
        
        for position in positions {
            minBounds = simd_min(minBounds, position)
            maxBounds = simd_max(maxBounds, position)
        }
        
        return (minBounds, maxBounds)
    }
    
    // MARK: - Immersive Space Management
    
    func activateImmersiveSpace() {
        immersiveSpaceActive = true
        print("🚀 VisionOS: Immersive space activated")
    }
    
    func deactivateImmersiveSpace() {
        immersiveSpaceActive = false
        print("⏸️ VisionOS: Immersive space deactivated")
    }
    
    // MARK: - Persistence Support
    
    func exportSpatialConfiguration() -> [String: Any] {
        let anchorsData = spatialAnchors.mapValues { anchorData in
            return [
                "id": anchorData.id.uuidString,
                "windowID": anchorData.windowID,
                "transform": [
                    "translation": [
                        "x": anchorData.transform.translation.x,
                        "y": anchorData.transform.translation.y,
                        "z": anchorData.transform.translation.z
                    ],
                    "rotation": [
                        "x": anchorData.transform.rotation.vector.x,
                        "y": anchorData.transform.rotation.vector.y,
                        "z": anchorData.transform.rotation.vector.z,
                        "w": anchorData.transform.rotation.vector.w
                    ],
                    "scale": [
                        "x": anchorData.transform.scale.x,
                        "y": anchorData.transform.scale.y,
                        "z": anchorData.transform.scale.z
                    ]
                ],
                "isActive": anchorData.isActive,
                "createdAt": ISO8601DateFormatter().string(from: anchorData.createdAt)
            ]
        }
        
        return [
            "spatialAnchors": anchorsData,
            "immersiveSpaceActive": immersiveSpaceActive,
            "userPosition": [
                "x": userHeadPosition.x,
                "y": userHeadPosition.y,
                "z": userHeadPosition.z
            ],
            "version": "1.0"
        ]
    }
    
    func importSpatialConfiguration(_ data: [String: Any]) {
        guard let anchorsData = data["spatialAnchors"] as? [String: [String: Any]] else {
            print("⚠️ VisionOS: No spatial anchors data found in import")
            return
        }
        
        spatialAnchors.removeAll()
        
        for (_, anchorInfo) in anchorsData {
            guard let idString = anchorInfo["id"] as? String,
                  let anchorID = UUID(uuidString: idString),
                  let windowID = anchorInfo["windowID"] as? Int,
                  let transformData = anchorInfo["transform"] as? [String: Any],
                  let isActive = anchorInfo["isActive"] as? Bool else {
                continue
            }
            
            // Parse transform
            guard let transform = parseTransform(from: transformData) else {
                continue
            }
            
            // Parse creation date
            let createdAt: Date
            if let createdAtString = anchorInfo["createdAt"] as? String,
               let date = ISO8601DateFormatter().date(from: createdAtString) {
                createdAt = date
            } else {
                createdAt = Date()
            }
            
            let anchorData = SpatialAnchorData(
                id: anchorID,
                windowID: windowID,
                transform: transform,
                isActive: isActive,
                createdAt: createdAt
            )
            
            spatialAnchors[anchorID] = anchorData
        }
        
        // Restore user position if available
        if let userPosData = data["userPosition"] as? [String: Float] {
            userHeadPosition = SIMD3<Float>(
                userPosData["x"] ?? 0,
                userPosData["y"] ?? 1.6,
                userPosData["z"] ?? 0
            )
        }
        
        print("✅ VisionOS: Imported \(spatialAnchors.count) spatial anchors")
    }
    
    private func parseTransform(from data: [String: Any]) -> Transform? {
        guard let translationData = data["translation"] as? [String: Float],
              let rotationData = data["rotation"] as? [String: Float],
              let scaleData = data["scale"] as? [String: Float] else {
            return nil
        }
        
        let translation = SIMD3<Float>(
            translationData["x"] ?? 0,
            translationData["y"] ?? 0,
            translationData["z"] ?? 0
        )
        
        let rotation = simd_quatf(
            vector: SIMD4<Float>(
                rotationData["x"] ?? 0,
                rotationData["y"] ?? 0,
                rotationData["z"] ?? 0,
                rotationData["w"] ?? 1
            )
        )
        
        let scale = SIMD3<Float>(
            scaleData["x"] ?? 1,
            scaleData["y"] ?? 1,
            scaleData["z"] ?? 1
        )
        
        var transform = Transform.identity
        transform.translation = translation
        transform.rotation = rotation
        transform.scale = scale
        
        return transform
    }
    
    // MARK: - User Position Tracking
    
    func updateUserPosition(_ position: SIMD3<Float>) {
        userHeadPosition = position
        
        // Update spatial tracking quality based on movement
        updateTrackingQuality()
    }
    
    private func updateTrackingQuality() {
        // In a real implementation, this would check visionOS tracking state
        // For now, we'll simulate good tracking
        spatialTrackingQuality = .good
    }
}

// MARK: - Supporting Types

struct SpatialAnchorData: Identifiable {
    let id: UUID
    let windowID: Int
    var transform: Transform
    var isActive: Bool
    let createdAt: Date
    var lastUpdated: Date = Date()
}

struct SpatialPlacementConfig {
    let distance: Float
    let heightOffset: Float
    let preferredAngle: Float
}

struct SpatialLayout {
    let anchors: [SpatialAnchorData]
    let userPosition: SIMD3<Float>
    let boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>)
}

enum SpatialTrackingQuality {
    case good
    case limited
    case poor
    case unavailable
    
    var description: String {
        switch self {
        case .good: return "Good"
        case .limited: return "Limited"
        case .poor: return "Poor"
        case .unavailable: return "Unavailable"
        }
    }
    
    var color: Color {
        switch self {
        case .good: return .green
        case .limited: return .yellow
        case .poor: return .orange
        case .unavailable: return .red
        }
    }
}

enum SpatialTrackingError: LocalizedError {
    case immersiveSpaceUnavailable
    case anchorCreationFailed
    case spatialTrackingLimited
    
    var errorDescription: String? {
        switch self {
        case .immersiveSpaceUnavailable:
            return "Immersive space is not available"
        case .anchorCreationFailed:
            return "Failed to create spatial anchor"
        case .spatialTrackingLimited:
            return "Spatial tracking quality is limited"
        }
    }
}


