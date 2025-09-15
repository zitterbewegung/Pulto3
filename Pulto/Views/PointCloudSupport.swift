import Foundation
import simd

// MARK: - Shared Point Cloud Store

final class _PointCloudSupport_PointCloudDataStore {
    static let shared = _PointCloudSupport_PointCloudDataStore()
    private init() {}

    private var storage: [Int: [SIMD3<Float>]] = [:]
    private let queue = DispatchQueue(label: "PointCloudDataStore.queue", attributes: .concurrent)

    func set(points: [SIMD3<Float>], for windowID: Int) {
        queue.async(flags: .barrier) { self.storage[windowID] = points }
    }

    func getPoints(for windowID: Int) -> [SIMD3<Float>]? {
        var result: [SIMD3<Float>]? = nil
        queue.sync { result = storage[windowID] }
        return result
    }

    func removePoints(for windowID: Int) {
        queue.async(flags: .barrier) { self.storage.removeValue(forKey: windowID) }
    }

    func removeAll() {
        queue.async(flags: .barrier) { self.storage.removeAll() }
    }
}

// MARK: - Extended PLY Parser (ASCII + Binary)

enum _PointCloudSupport_PLYParser {
    enum Format { case ascii, binaryLittleEndian, binaryBigEndian }

    struct Header {
        var format: Format = .ascii
        var vertexCount: Int = 0
        var propertyOrder: [String] = [] // e.g., ["x","y","z","red","green","blue"]
        var headerByteLength: Int = 0 // for binary payload offset
    }

    /// Top-level parse function that detects format and calls the appropriate parser.
    static func parse(url: URL, maxPoints: Int = 2_000_000) -> [SIMD3<Float>] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        // Find end of header ("end_header\n")
        guard let (header, headerText) = _PointCloudSupport_PLYParser.parseHeader(data: data) else { return [] }

        switch header.format {
        case .ascii:
            guard let text = String(data: data, encoding: .utf8) else { return [] }
            return _PointCloudSupport_PLYParser.parseASCIIBody(text: text, headerLineCount: headerText.lineCount, vertexCount: header.vertexCount, propertyOrder: header.propertyOrder, maxPoints: maxPoints)
        case .binaryLittleEndian:
            return _PointCloudSupport_PLYParser.parseBinaryBody(data: data, offset: header.headerByteLength, vertexCount: header.vertexCount, propertyOrder: header.propertyOrder, littleEndian: true, maxPoints: maxPoints)
        case .binaryBigEndian:
            return _PointCloudSupport_PLYParser.parseBinaryBody(data: data, offset: header.headerByteLength, vertexCount: header.vertexCount, propertyOrder: header.propertyOrder, littleEndian: false, maxPoints: maxPoints)
        }
    }

    // MARK: - Header

    private static func parseHeader(data: Data) -> (Header, HeaderText)? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let lines = text.split(whereSeparator: { $0.isNewline }).map(String.init)
        guard lines.first == "ply" else { return nil }

        var header = Header()
        var headerEnded = false
        var headerBytes = 0
        var headerLineCount = 0

        for (i, line) in lines.enumerated() {
            headerLineCount = i + 1
            headerBytes += (line.lengthOfBytes(using: .utf8) + 1) // include newline
            let parts = line.split(separator: " ")
            if parts.isEmpty { continue }

            switch parts[0] {
            case "format":
                if parts.count >= 2 {
                    if parts[1] == "ascii" { header.format = .ascii }
                    else if parts[1] == "binary_little_endian" { header.format = .binaryLittleEndian }
                    else if parts[1] == "binary_big_endian" { header.format = .binaryBigEndian }
                }
            case "element":
                if parts.count >= 3, parts[1] == "vertex" {
                    header.vertexCount = Int(parts[2]) ?? 0
                }
            case "property":
                if parts.count >= 3 {
                    header.propertyOrder.append(String(parts[2]))
                }
            case "end_header":
                headerEnded = true
                break
            default:
                break
            }
            if headerEnded { break }
        }

        guard headerEnded else { return nil }
        header.headerByteLength = headerBytes
        return (header, HeaderText(lineCount: headerLineCount))
    }

    private struct HeaderText { let lineCount: Int }

    // MARK: - ASCII body

    private static func parseASCIIBody(text: String, headerLineCount: Int, vertexCount: Int, propertyOrder: [String], maxPoints: Int) -> [SIMD3<Float>] {
        guard let xIndex = propertyOrder.firstIndex(of: "x"),
              let yIndex = propertyOrder.firstIndex(of: "y"),
              let zIndex = propertyOrder.firstIndex(of: "z") else { return [] }

        let lines = text.split(whereSeparator: { $0.isNewline }).map(String.init)
        var points: [SIMD3<Float>] = []
        points.reserveCapacity(min(vertexCount, maxPoints))

        var parsed = 0
        for line in lines.dropFirst(headerLineCount) {
            if parsed >= vertexCount || points.count >= maxPoints { break }
            let comps = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard comps.count > max(xIndex, yIndex, zIndex) else { continue }
            if let x = Float(comps[xIndex]), let y = Float(comps[yIndex]), let z = Float(comps[zIndex]) {
                points.append(SIMD3<Float>(x, y, z))
                parsed += 1
            }
        }
        return points
    }

    // MARK: - Binary body

    private static func parseBinaryBody(data: Data, offset: Int, vertexCount: Int, propertyOrder: [String], littleEndian: Bool, maxPoints: Int) -> [SIMD3<Float>] {
        guard let xIndex = propertyOrder.firstIndex(of: "x"),
              let yIndex = propertyOrder.firstIndex(of: "y"),
              let zIndex = propertyOrder.firstIndex(of: "z") else { return [] }

        // Each property is typically a 4-byte float for x,y,z. This parser assumes float for coordinates.
        // It walks each vertex record using the property order and reads Float for coordinate properties; skips others.
        var points: [SIMD3<Float>] = []
        points.reserveCapacity(min(vertexCount, maxPoints))

        var cursor = offset
        let end = data.count

        for i in 0..<vertexCount {
            if points.count >= maxPoints || cursor >= end { break }

            var values: [Float?] = Array(repeating: nil, count: propertyOrder.count)
            var localCursor = cursor

            for (pi, name) in propertyOrder.enumerated() {
                if name == "x" || name == "y" || name == "z" {
                    if localCursor + 4 <= end {
                        let f: Float = _PointCloudSupport_PLYParser.readFloat32(data: data, offset: localCursor, littleEndian: littleEndian)
                        values[pi] = f
                        localCursor += 4
                    } else { break }
                } else {
                    // Heuristic: treat unknown property as 1 byte (common for colors as uchar)
                    if localCursor + 1 <= end { localCursor += 1 } else { break }
                }
            }

            if let x = values[xIndex], let y = values[yIndex], let z = values[zIndex] {
                points.append(SIMD3<Float>(x, y, z))
            }

            cursor = localCursor
            if i % 10000 == 0 && points.count >= maxPoints { break }
        }

        return points
    }

    private static func readFloat32(data: Data, offset: Int, littleEndian: Bool) -> Float {
        let slice = data[offset..<(offset+4)]
        var value: UInt32 = 0
        _ = withUnsafeMutableBytes(of: &value) { slice.copyBytes(to: $0)}
        if littleEndian {
            value = UInt32(littleEndian: value)
        } else {
            value = UInt32(bigEndian: value)
        }
        return Float(bitPattern: value)
    }
}

