//
//  EntityLifecycleManager.swift
//  Pulto3
//
//  Created by AI Assistant on [Date]
//  Copyright © 2025 Apple. All rights reserved.
//

import Foundation
import RealityKit
import SwiftUI
import Combine

// MARK: - Entity Lifecycle Management System

@MainActor
class EntityLifecycleManager: ObservableObject {
    static let shared = EntityLifecycleManager()
    
    // MARK: - Properties
    
    @Published var memoryUsage: MemoryInfo = MemoryInfo()
    @Published var activeWindowCount: Int = 0
    
    private var windowEntities: [Int: Set<Entity>] = [:]
    private var entityPools: [String: Any] = [:]
    private var memoryMonitorTimer: Timer?
    private let maxMemoryThreshold: Int64 = 500_000_000 // 500MB
    
    // MARK: - Memory Info Structure
    
    struct MemoryInfo {
        let usedBytes: Int64
        let availableBytes: Int64
        let entityCount: Int
        let pooledEntityCount: Int
        
        init(usedBytes: Int64 = 0, availableBytes: Int64 = 0, entityCount: Int = 0, pooledEntityCount: Int = 0) {
            self.usedBytes = usedBytes
            self.availableBytes = availableBytes
            self.entityCount = entityCount
            self.pooledEntityCount = pooledEntityCount
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        startMemoryMonitoring()
    }
    
    deinit {
        Task { @MainActor in
            stopMemoryMonitoring()
        }
    }
    
    // MARK: - Public Interface
    
    /// Register an entity for a specific window
    func registerEntity(_ entity: Entity, for windowID: Int) {
        windowEntities[windowID, default: []].insert(entity)
        updateActiveWindowCount()
        print("📝 Registered entity for window \(windowID). Total entities: \(getTotalEntityCount())")
    }
    
    /// Register multiple entities for a window
    func registerEntities(_ entities: [Entity], for windowID: Int) {
        for entity in entities {
            registerEntity(entity, for: windowID)
        }
    }
    
    /// Clean up all entities for a specific window
    func cleanupWindow(_ windowID: Int) {
        guard let entities = windowEntities[windowID] else {
            print("⚠️ No entities found for window \(windowID)")
            return
        }
        
        print("🧹 Cleaning up \(entities.count) entities for window \(windowID)")
        
        for entity in entities {
            cleanupEntity(entity)
        }
        
        windowEntities.removeValue(forKey: windowID)
        updateActiveWindowCount()
        
        print("✅ Cleanup complete for window \(windowID). Remaining windows: \(windowEntities.keys.count)")
    }
    
    /// Get entity count for a specific window
    func getEntityCount(for windowID: Int) -> Int {
        return windowEntities[windowID]?.count ?? 0
    }
    
    /// Get total entity count across all windows
    func getTotalEntityCount() -> Int {
        return windowEntities.values.reduce(0) { $0 + $1.count }
    }
    
    /// Perform emergency cleanup if memory usage is too high
    func performEmergencyCleanup() {
        print("🚨 Performing emergency cleanup - Memory usage: \(formatBytes(memoryUsage.usedBytes))")
        
        // Clean up oldest windows first
        let sortedWindows = windowEntities.keys.sorted()
        let windowsToCleanup = Array(sortedWindows.prefix(sortedWindows.count / 2))
        
        for windowID in windowsToCleanup {
            cleanupWindow(windowID)
        }
        
        // Clean up all entity pools
        cleanupAllPools()
        
        // Force garbage collection
        performGarbageCollection()
        
        print("✅ Emergency cleanup complete")
    }
    
    /// Clean up all entities and pools
    func cleanupAll() {
        print("🧹 Cleaning up all entities and pools")
        
        for windowID in windowEntities.keys {
            cleanupWindow(windowID)
        }
        
        cleanupAllPools()
        performGarbageCollection()
        
        print("✅ Complete cleanup finished")
    }
    
    // MARK: - Entity Pool Management
    
    /// Get a point cloud entity pool
    func getPointCloudPool() -> PointCloudEntityPool {
        if let pool = entityPools["pointCloud"] as? PointCloudEntityPool {
            return pool
        }
        
        let newPool = PointCloudEntityPool()
        entityPools["pointCloud"] = newPool
        return newPool
    }
    
    /// Get a model entity pool
    func getModelPool() -> ModelEntityPool {
        if let pool = entityPools["model"] as? ModelEntityPool {
            return pool
        }
        
        let newPool = ModelEntityPool()
        entityPools["model"] = newPool
        return newPool
    }
    
    // MARK: - Private Methods
    
    private func cleanupEntity(_ entity: Entity) {
        // Remove from parent hierarchy
        entity.removeFromParent()
        
        // Clear all components
        entity.components.removeAll()
        
        // Remove all children recursively
        cleanupEntityChildren(entity)
        
        // If entity supports pooling, return to pool
        if let poolableEntity = entity as? PoolableEntity {
            returnEntityToPool(poolableEntity)
        }
    }
    
    private func cleanupEntityChildren(_ entity: Entity) {
        for child in entity.children {
            cleanupEntityChildren(child)
            child.removeFromParent()
            child.components.removeAll()
        }
    }
    
    private func returnEntityToPool(_ entity: PoolableEntity) {
        switch entity.poolType {
        case "pointCloud":
            if let modelEntity = entity as? ModelEntity {
                getPointCloudPool().returnEntity(modelEntity)
            }
        case "model":
            if let modelEntity = entity as? ModelEntity {
                getModelPool().returnEntity(modelEntity)
            }
        default:
            break
        }
    }
    
    private func cleanupAllPools() {
        for (_, pool) in entityPools {
            if let pointCloudPool = pool as? PointCloudEntityPool {
                pointCloudPool.cleanup()
            } else if let modelPool = pool as? ModelEntityPool {
                modelPool.cleanup()
            }
        }
        entityPools.removeAll()
    }
    
    private func updateActiveWindowCount() {
        activeWindowCount = windowEntities.keys.count
    }
    
    private func performGarbageCollection() {
        // Force memory cleanup
        autoreleasepool {
            // This forces Swift to clean up autoreleased objects
        }
    }
    
    // MARK: - Memory Monitoring
    
    private func startMemoryMonitoring() {
        memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMemoryInfo()
            }
        }
    }
    
    private func stopMemoryMonitoring() {
        memoryMonitorTimer?.invalidate()
        memoryMonitorTimer = nil
    }
    
    private func updateMemoryInfo() async {
        let memInfo = getMemoryInfo()
        self.memoryUsage = memInfo
        
        // Trigger cleanup if memory usage is too high
        if memInfo.usedBytes > maxMemoryThreshold {
            print("⚠️ Memory usage high: \(formatBytes(memInfo.usedBytes))")
            performEmergencyCleanup()
        }
    }
    
    private func getMemoryInfo() -> MemoryInfo {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        let usedBytes = result == KERN_SUCCESS ? Int64(info.resident_size) : 0
        let entityCount = getTotalEntityCount()
        let pooledCount = getPooledEntityCount()
        
        return MemoryInfo(
            usedBytes: usedBytes,
            availableBytes: 0, // Available memory is hard to calculate accurately
            entityCount: entityCount,
            pooledEntityCount: pooledCount
        )
    }
    
    private func getPooledEntityCount() -> Int {
        var total = 0
        for (_, pool) in entityPools {
            if let pointCloudPool = pool as? PointCloudEntityPool {
                total += pointCloudPool.getPooledCount()
            } else if let modelPool = pool as? ModelEntityPool {
                total += modelPool.getPooledCount()
            }
        }
        return total
    }
}

// MARK: - Entity Pool Protocols

protocol PoolableEntity: Entity {
    var poolType: String { get }
    func resetForReuse()
}

// MARK: - Point Cloud Entity Pool

class PointCloudEntityPool {
    private var availableEntities: [ModelEntity] = []
    private var activeEntities: Set<ModelEntity> = []
    private let maxPoolSize = 1000
    
    func getEntity() -> ModelEntity {
        if let entity = availableEntities.popLast() {
            activeEntities.insert(entity)
            return entity
        }
        
        // Create new entity if pool is empty
        let entity = createPointEntity()
        activeEntities.insert(entity)
        return entity
    }
    
    func returnEntity(_ entity: ModelEntity) {
        activeEntities.remove(entity)
        
        // Reset entity state
        entity.transform = Transform.identity
        entity.removeFromParent()
        
        // Clear components except the ones we want to keep
        if let modelComponent = entity.components[ModelComponent.self] {
            entity.components.removeAll()
            entity.components[ModelComponent.self] = modelComponent
        }
        
        // Return to pool if under limit
        if availableEntities.count < maxPoolSize {
            availableEntities.append(entity)
        }
    }
    
    func cleanup() {
        for entity in activeEntities {
            entity.removeFromParent()
            entity.components.removeAll()
        }
        activeEntities.removeAll()
        
        for entity in availableEntities {
            entity.components.removeAll()
        }
        availableEntities.removeAll()
    }
    
    func getPooledCount() -> Int {
        return availableEntities.count
    }
    
    func getActiveCount() -> Int {
        return activeEntities.count
    }
    
    private func createPointEntity() -> ModelEntity {
        let sphereMesh = MeshResource.generateSphere(radius: 0.005)
        let material = SimpleMaterial(color: .white, isMetallic: false)
        return ModelEntity(mesh: sphereMesh, materials: [material])
    }
}

// MARK: - Model Entity Pool

class ModelEntityPool {
    private var availableEntities: [ModelEntity] = []
    private var activeEntities: Set<ModelEntity> = []
    private let maxPoolSize = 100
    
    func getEntity() -> ModelEntity {
        if let entity = availableEntities.popLast() {
            activeEntities.insert(entity)
            return entity
        }
        
        let entity = ModelEntity()
        activeEntities.insert(entity)
        return entity
    }
    
    func returnEntity(_ entity: ModelEntity) {
        activeEntities.remove(entity)
        
        // Reset entity state
        entity.transform = Transform.identity
        entity.removeFromParent()
        entity.components.removeAll()
        
        if availableEntities.count < maxPoolSize {
            availableEntities.append(entity)
        }
    }
    
    func cleanup() {
        for entity in activeEntities {
            entity.removeFromParent()
            entity.components.removeAll()
        }
        activeEntities.removeAll()
        availableEntities.removeAll()
    }
    
    func getPooledCount() -> Int {
        return availableEntities.count
    }
    
    func getActiveCount() -> Int {
        return activeEntities.count
    }
}

// MARK: - Utility Functions

func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB, .useGB]
    formatter.countStyle = .memory
    return formatter.string(fromByteCount: bytes)
}

// MARK: - Performance Metrics View

struct PerformanceMetricsView: View {
    @ObservedObject private var entityManager = EntityLifecycleManager.shared
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gauge")
                    .foregroundStyle(.blue)
                
                Text("Performance Metrics")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingDetail.toggle() }) {
                    Image(systemName: showingDetail ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
            }
            
            if showingDetail {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Memory Usage:")
                        Text(formatBytes(entityManager.memoryUsage.usedBytes))
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                    
                    HStack {
                        Text("Active Entities:")
                        Text("\(entityManager.memoryUsage.entityCount)")
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                    
                    HStack {
                        Text("Pooled Entities:")
                        Text("\(entityManager.memoryUsage.pooledEntityCount)")
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                    
                    HStack {
                        Text("Active Windows:")
                        Text("\(entityManager.activeWindowCount)")
                            .fontWeight(.semibold)
                            .foregroundStyle(.purple)
                    }
                    
                    HStack(spacing: 12) {
                        Button("Emergency Cleanup") {
                            entityManager.performEmergencyCleanup()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Full Cleanup") {
                            entityManager.cleanupAll()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .font(.caption)
                .padding(.leading)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}