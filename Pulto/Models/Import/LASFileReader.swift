//
//  LASFileReader.swift
//  Pulto3
//

import Foundation

class LASFileReader {
    private let data: Data

    init(data: Data) {
        self.data = data
    }

    // Check features based on point format ID
    func pointFormatHasColor() -> Bool {
        let formatID = (try? readHeader().pointDataFormatID) ?? 0
        return formatID == 2 || formatID == 3 || formatID == 5
    }

    func pointFormatHasGPSTime() -> Bool {
        let formatID = (try? readHeader().pointDataFormatID) ?? 0
        return formatID == 1 || formatID == 3 || formatID == 4 || formatID == 5
    }

    func pointFormatHasIntensity() -> Bool {
        // Standard formats 0-5 all have intensity
        return true
    }

    func readHeader() throws -> LASHeader {
        guard data.count >= 227 else { throw FileAnalysisError.invalidLASFile("Header is too small.") }

        // Helper to read values from data at a specific offset
        func read<T: FixedWidthInteger>(_ type: T.Type, at offset: Int) -> T {
            return data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: T.self) }
        }
        func readDouble(at offset: Int) -> Double {
            return data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Double.self) }
        }
        func readString(at offset: Int, length: Int) -> String {
            let range = offset..<(offset + length)
            return String(decoding: data[range], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines.union(["\0"]))
        }

        return LASHeader(
            versionMajor: read(UInt8.self, at: 24),
            versionMinor: read(UInt8.self, at: 25),
            systemIdentifier: readString(at: 4, length: 32),
            generatingSoftware: readString(at: 36, length: 32),
            fileCreationDayOfYear: read(UInt16.self, at: 88),
            fileCreationYear: read(UInt16.self, at: 90),
            headerSize: read(UInt16.self, at: 94),
            offsetToPointData: read(UInt32.self, at: 96),
            numberOfVariableLengthRecords: read(UInt32.self, at: 100),
            pointDataFormatID: read(UInt8.self, at: 104),
            pointDataRecordLength: read(UInt16.self, at: 105),
            numberOfPointRecords: read(UInt32.self, at: 107),
            scaleX: readDouble(at: 131),
            scaleY: readDouble(at: 139),
            scaleZ: readDouble(at: 147),
            offsetX: readDouble(at: 155),
            offsetY: readDouble(at: 163),
            offsetZ: readDouble(at: 171),
            minX: readDouble(at: 187),
            maxX: readDouble(at: 179),
            minY: readDouble(at: 203),
            maxY: readDouble(at: 195),
            minZ: readDouble(at: 219),
            maxZ: readDouble(at: 211)
        )
    }

    func readPoints(count: Int, header: LASHeader) throws -> [LASPoint] {
        var points = [LASPoint]()
        let start = Int(header.offsetToPointData)
        let recordLength = Int(header.pointDataRecordLength)

        for i in 0..<count {
            let offset = start + (i * recordLength)
            guard data.count >= offset + recordLength else { break }

            let x_raw = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Int32.self) }
            let y_raw = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 4, as: Int32.self) }
            let z_raw = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 8, as: Int32.self) }

            let intensity = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 12, as: UInt16.self) }
            let classificationByte = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 15, as: UInt8.self) }

            // Extract classification from the first 5 bits
            let classification = classificationByte & 0b00011111

            let x = (Double(x_raw) * header.scaleX) + header.offsetX
            let y = (Double(y_raw) * header.scaleY) + header.offsetY
            let z = (Double(z_raw) * header.scaleZ) + header.offsetZ

            var gpsTime: Double = 0
            var red: UInt16 = 0
            var green: UInt16 = 0
            var blue: UInt16 = 0

            let format = header.pointDataFormatID

            if format == 1 || format == 3 || format == 4 || format == 5 {
                gpsTime = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 20, as: Double.self) }
            }
            if format == 2 || format == 3 || format == 5 {
                red = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 20, as: UInt16.self) }
                green = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 22, as: UInt16.self) }
                blue = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 24, as: UInt16.self) }
            }

            points.append(LASPoint(x: x, y: y, z: z, intensity: intensity, classification: classification, red: red, green: green, blue: blue, gpsTime: gpsTime))
        }

        return points
    }
}
