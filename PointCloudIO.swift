import Foundation
import simd

public struct PointCloudSample {
    public var position: SIMD3<Float>
    public var intensity: Float?

    public init(position: SIMD3<Float>, intensity: Float? = nil) {
        self.position = position
        self.intensity = intensity
    }
}

public struct PointCloud {
    public var samples: [PointCloudSample]
    public var title: String

    public init(samples: [PointCloudSample] = [], title: String = "Point Cloud") {
        self.samples = samples
        self.title = title
    }
}

public enum PointCloudIO {
    public static func load(from url: URL) throws -> PointCloud {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "csv":
            return try loadCSV(url)
        case "xyz":
            return try loadXYZ(url)
        case "ply":
            return try loadPLY(url)
        case "pcd":
            return try loadPCD(url)
        case "pts":
            return try loadXYZ(url) // treat like XYZ
        default:
            // Attempt best-effort as whitespace-separated XYZ
            return try loadXYZ(url)
        }
    }
}

// MARK: - Normalization
public extension PointCloud {
    func centeredAndScaled(maxExtent: Float = 1.0) -> PointCloud {
        guard !samples.isEmpty else { return self }
        var minV = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxV = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for s in samples {
            minV = min(minV, s.position)
            maxV = max(maxV, s.position)
        }
        let center = (minV + maxV) * 0.5
        let extent = max(maxV.x - minV.x, max(maxV.y - minV.y, maxV.z - minV.z))
        let scale: Float = extent > 0 ? (maxExtent / extent) : 1.0
        let norm = samples.map { s in
            PointCloudSample(position: (s.position - center) * scale, intensity: s.intensity)
        }
        return PointCloud(samples: norm, title: title)
    }
}

// MARK: - Bridge to existing PointCloudData
public extension PointCloud {
    func toPointCloudData() -> PointCloudData {
        var pc = PointCloudData(title: title, demoType: "imported")
        pc.points = samples.map { s in
            PointCloudData.PointData(x: Double(s.position.x), y: Double(s.position.y), z: Double(s.position.z), intensity: s.intensity != nil ? Double(s.intensity!) : nil)
        }
        pc.totalPoints = pc.points.count
        return pc
    }
}

// MARK: - Helpers
private extension StringProtocol {
    var trimmed: String { self.trimmingCharacters(in: .whitespacesAndNewlines) }
}

private extension PointCloudIO {
    static func loadCSV(_ url: URL) throws -> PointCloud {
        let text = try String(contentsOf: url)
        let lines = text.split(whereSeparator: \.isNewline)
        var samples: [PointCloudSample] = []
        samples.reserveCapacity(min(lines.count, 200_000))

        var startIndex = 0
        if let first = lines.first, !isNumericCSVLine(String(first)) {
            startIndex = 1 // skip header
        }

        for (i, lineSub) in lines.enumerated() {
            if i < startIndex { continue }
            if samples.count >= 200_000 { break }
            let line = String(lineSub).trimmed
            if line.isEmpty || line.hasPrefix("#") { continue }
            // Split by comma first; if not enough, split by any whitespace
            var parts = line.split(separator: ",").map { String($0).trimmed }
            if parts.count < 3 {
                parts = line.split(whereSeparator: { $0.isWhitespace || $0 == "," }).map { String($0) }
            }
            guard parts.count >= 3,
                  let x = Float(parts[0]),
                  let y = Float(parts[1]),
                  let z = Float(parts[2]) else { continue }
            let intensity: Float? = parts.count > 3 ? Float(parts[3]) : nil
            samples.append(PointCloudSample(position: SIMD3(x,y,z), intensity: intensity))
        }

        return PointCloud(samples: samples, title: url.lastPathComponent)
    }

    static func isNumericCSVLine(_ line: String) -> Bool {
        let parts = line.split(separator: ",").map { String($0).trimmed }
        guard parts.count >= 3 else { return false }
        return Float(parts[0]) != nil && Float(parts[1]) != nil && Float(parts[2]) != nil
    }

    static func loadXYZ(_ url: URL) throws -> PointCloud {
        let text = try String(contentsOf: url)
        let lines = text.split(whereSeparator: \.isNewline)
        var samples: [PointCloudSample] = []
        samples.reserveCapacity(min(lines.count, 200_000))

        for lineSub in lines {
            if samples.count >= 200_000 { break }
            let line = String(lineSub).trimmed
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(whereSeparator: { $0.isWhitespace || $0 == "," }).map { String($0) }
            guard parts.count >= 3,
                  let x = Float(parts[0]),
                  let y = Float(parts[1]),
                  let z = Float(parts[2]) else { continue }
            let intensity: Float? = parts.count > 3 ? Float(parts[3]) : nil
            samples.append(PointCloudSample(position: SIMD3(x,y,z), intensity: intensity))
        }

        return PointCloud(samples: samples, title: url.lastPathComponent)
    }

    static func loadPLY(_ url: URL) throws -> PointCloud {
        let text = try String(contentsOf: url)
        let lines = text.components(separatedBy: .newlines)
        var inHeader = true
        var vertexCount = 0
        var xIndex = 0, yIndex = 1, zIndex = 2
        var intensityIndex: Int? = nil
        var propertyIndex = 0
        var samples: [PointCloudSample] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if inHeader {
                if trimmed.hasPrefix("element vertex ") {
                    let parts = trimmed.split(separator: " ")
                    if parts.count >= 3 { vertexCount = Int(parts[2]) ?? 0 }
                } else if trimmed.hasPrefix("property") {
                    let parts = trimmed.split(separator: " ")
                    let name = parts.last?.lowercased() ?? ""
                    switch name {
                    case "x": xIndex = propertyIndex
                    case "y": yIndex = propertyIndex
                    case "z": zIndex = propertyIndex
                    case "intensity", "scalar_intensity", "i": intensityIndex = propertyIndex
                    default: break
                    }
                    propertyIndex += 1
                } else if trimmed == "end_header" {
                    inHeader = false
                }
                continue
            }
            // Data section (ASCII only)
            if vertexCount == 0 { continue }
            if samples.count >= vertexCount || samples.count >= 200_000 { break }
            if trimmed.isEmpty { continue }
            let parts = trimmed.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
            if parts.count <= max(zIndex, intensityIndex ?? 0) { continue }
            guard let x = Float(parts[xIndex]), let y = Float(parts[yIndex]), let z = Float(parts[zIndex]) else { continue }
            let intensity: Float? = intensityIndex != nil ? Float(parts[intensityIndex!]) : nil
            samples.append(PointCloudSample(position: SIMD3(x,y,z), intensity: intensity))
        }

        return PointCloud(samples: samples, title: url.lastPathComponent)
    }

    static func loadPCD(_ url: URL) throws -> PointCloud {
        let text = try String(contentsOf: url)
        let lines = text.components(separatedBy: .newlines)
        var fields: [String] = []
        var xIndex = 0, yIndex = 1, zIndex = 2
        var intensityIndex: Int? = nil
        var dataStarted = false
        var samples: [PointCloudSample] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if !dataStarted {
                if trimmed.hasPrefix("FIELDS") {
                    fields = trimmed.split(separator: " ").dropFirst().map { String($0).lowercased() }
                    for (i, f) in fields.enumerated() {
                        switch f {
                        case "x": xIndex = i
                        case "y": yIndex = i
                        case "z": zIndex = i
                        case "intensity", "i": intensityIndex = i
                        default: break
                        }
                    }
                } else if trimmed.hasPrefix("DATA") {
                    dataStarted = true
                }
                continue
            } else {
                if samples.count >= 200_000 { break }
                let parts = trimmed.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
                if parts.count <= max(zIndex, intensityIndex ?? 0) { continue }
                guard let x = Float(parts[xIndex]), let y = Float(parts[yIndex]), let z = Float(parts[zIndex]) else { continue }
                let intensity: Float? = intensityIndex != nil ? Float(parts[intensityIndex!]) : nil
                samples.append(PointCloudSample(position: SIMD3(x,y,z), intensity: intensity))
            }
        }

        return PointCloud(samples: samples, title: url.lastPathComponent)
    }
}
