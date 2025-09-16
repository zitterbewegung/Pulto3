//  PhotogrammetryPipeline.swift
//  Pulto3
//
//  A small pipeline that runs Object Capture photogrammetry to produce a point cloud (PLY),
//  then converts it to PointCloudData for use in WindowTypeManager and RealityKit views.
//

import Foundation

#if canImport(ObjectCapture)
import ObjectCapture
#endif

import UniformTypeIdentifiers

struct PhotogrammetryPipeline {
    enum PipelineError: Error, LocalizedError {
        case objectCaptureUnavailable
        case exportFailed(String)
        case noPoints

        var errorDescription: String? {
            switch self {
            case .objectCaptureUnavailable:
                return "Object Capture (Photogrammetry) is not available on this platform."
            case .exportFailed(let reason):
                return "Photogrammetry export failed: \(reason)"
            case .noPoints:
                return "The exported point cloud contained no points."
            }
        }
    }

    #if canImport(ObjectCapture)
    struct Configuration {
        var detail: PhotogrammetrySession.Request.Detail = .medium
        var requestTimeout: TimeInterval = 60 * 60 // 1 hour default for safety
    }
    #endif

    /// Run photogrammetry on an input folder of images, export a PLY point cloud, and return PointCloudData
    /// - Parameters:
    ///   - inputFolder: Folder containing images suitable for Object Capture
    ///   - exportURL: Destination PLY file URL
    /// - Returns: PointCloudData built from the exported PLY
    @discardableResult
    static func generatePointCloudData(from inputFolder: URL, exportURL: URL) async throws -> PointCloudData {
        #if canImport(ObjectCapture)
        // 1) Run Object Capture to export a point cloud PLY
        try await exportPointCloudPLY(inputFolder: inputFolder, exportURL: exportURL)

        // 2) Load PLY into PointCloudData using existing loader
        let loaded = PointCloudDemo.loadPointCloud(from: exportURL)
        guard !loaded.isEmpty else { throw PipelineError.noPoints }

        var pointCloudData = PointCloudData(
            title: "Photogrammetry Point Cloud: \(exportURL.lastPathComponent)",
            xAxisLabel: "X",
            yAxisLabel: "Y",
            zAxisLabel: "Z",
            demoType: "photogrammetry",
            parameters: ["points": Double(loaded.count)]
        )
        pointCloudData.points = loaded
        pointCloudData.totalPoints = loaded.count
        return pointCloudData
        #else
        throw PipelineError.objectCaptureUnavailable
        #endif
    }

    #if canImport(ObjectCapture)
    /// Export a PLY point cloud using Object Capture
    private static func exportPointCloudPLY(inputFolder: URL, exportURL: URL, configuration: Configuration = Configuration()) async throws {
        let session = try PhotogrammetrySession(input: inputFolder, configuration: .init())

        // Remove existing file if any
        try? FileManager.default.removeItem(at: exportURL)

        // Request a point cloud export
        let request = PhotogrammetrySession.Request.pointCloud(detail: configuration.detail, exportFileURL: exportURL)

        // Run the request and await completion
        let task = Task {
            try await session.process(requests: [request])
        }

        // Optional timeout handling
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(configuration.requestTimeout * 1_000_000_000))
            task.cancel()
        }

        do {
            try await task.value
        } catch is CancellationError {
            throw PipelineError.exportFailed("Timed out after \(configuration.requestTimeout) seconds")
        } catch {
            throw PipelineError.exportFailed(error.localizedDescription)
        }

        timeoutTask.cancel()

        // Verify file exists
        guard FileManager.default.fileExists(atPath: exportURL.path) else {
            throw PipelineError.exportFailed("PLY file not created")
        }
    }
    #endif
}
