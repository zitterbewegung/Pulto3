//
//  FeatureFlagManager.swift
//  Pulto
//
//  Created by Assistant on 8/8/2025.
//

import Foundation

// MARK: - Feature Flag Manager
class FeatureFlagManager {
    static let shared = FeatureFlagManager()
    
    // MARK: - Feature Flags (Hard-coded, not user changeable)
    
    /// Controls whether templates functionality is enabled
    var isTemplatesEnabled: Bool {
        // Set to false to disable templates feature
        return false
    }
    
    /// Controls whether spatial views can be created as IoT dashboards
    var isSpatialViewAsIoTDashboardEnabled: Bool {
        // Set to false to disable spatial view as IoT dashboard
        return false
    }
    
    /// Controls whether the data frame view is enabled
    var isDataFrameViewEnabled: Bool {
        // Set to true to enable data frame view
        return true
    }
    
    /// Controls whether point cloud visualization is enabled
    var isPointCloudEnabled: Bool {
        // Set to true to enable point cloud features
        return true
    }
    
    /// Controls whether 3D model visualization is enabled
    var isModel3DEnabled: Bool {
        // Set to true to enable 3D model features
        return true
    }
    
    private init() { }
}