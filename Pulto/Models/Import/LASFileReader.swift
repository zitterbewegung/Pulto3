//
//  LASFileReader.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/18/25.
//  Copyright © 2025 Apple. All rights reserved.
//


//
//  LASFileReader.swift
//  Pulto3
//
//  LAS (LiDAR) file reader with GPS time support
//

import Foundation

class LASFileReader {
    private let data: Data
    private var offset: Int = 0
    
    init(data: Data) {
        self.data = data
    }
    
    // MARK: - Header Reading
    
    func readHeader() throws -> LASHeader {
        offset = 0
        
        // File signature "LASF"
        let signature = try readString(length: 4)
        guard signature == "LASF" else {
            throw FileAnalysisError.invalidLASFile("Invalid file signature")
        }
        
        // File source ID (2 bytes) - skip
        offset += 2
        
        // Global encoding (2 bytes)
        let globalEncoding = try readUInt16()
        let hasGPSTime = (globalEncoding & 0x01) != 0
        
        // Project ID - GUID (16 bytes) - skip
        offset += 16
        
        // Version
        let versionMajor = try readUInt8()
        let versionMinor = try readUInt8()
        
        // System identifier
        let systemIdentifier = try readString(length: 32).trimmingCharacters(in: .controlCharacters)
        
        // Generating software
        let generatingSoftware = try readString(length: 32).trimmingCharacters(in: .controlCharacters)
        
        // File creation
        let fileCreationDayOfYear = try readUInt16()
        let fileCreationYear = try readUInt16()
        
        // Header size
        let headerSize = try readUInt16()
        
        // Offset to point data
        let offsetToPointData = try readUInt32()
        
        // Number of variable length records
        let numberOfVariableLengthRecords = try readUInt32()
        
        // Point data format
        let pointDataFormatID = try readUInt8()
        
        // Point data record length
        let pointDataRecordLength = try readUInt16()
        
        // Number of point records
        let numberOfPointRecords = try readUInt32()
        
        // Number of points by return (5 * 4 bytes) - skip for now
        offset += 20
        
        // Scale factors
        let scaleX = try readDouble()
        let scaleY = try readDouble()
        let scaleZ = try readDouble()
        
        // Offsets
        let offsetX = try readDouble()
        let offsetY = try readDouble()
        let offsetZ = try readDouble()
        
        // Bounds
        let maxX = try readDouble()
        let minX = try readDouble()
        let maxY = try readDouble()
        let minY = try readDouble()
        let maxZ = try readDouble()
        let minZ = try readDouble()
        
        return LASHeader(
            versionMajor: versionMajor,
            versionMinor: versionMinor,
            systemIdentifier: systemIdentifier,
            generatingSoftware: generatingSoftware,
            fileCreationDayOfYear: fileCreationDayOfYear,
            fileCreationYear: fileCreationYear,
            headerSize: headerSize,
            offsetToPointData: offsetToPointData,
            numberOfVariableLengthRecords: numberOfVariableLengthRecords,
            pointDataFormatID: pointDataFormatID,
            pointDataRecordLength: pointDataRecordLength,
            numberOfPointRecords: numberOfPointRecords,
            scaleX: scaleX,
            scaleY: scaleY,
            scaleZ: scaleZ,
            offsetX: offsetX,
            offsetY: offsetY,
            offsetZ: offsetZ,
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            minZ: minZ,
            maxZ: maxZ
        )
    }
    
    // MARK: - Point Reading
    
    func readPoints(count: Int, header: LASHeader? = nil) throws -> [LASPoint] {
        let header = try header ?? readHeader()
        
        // Move to point data
        offset = Int(header.offsetToPointData)
        
        var points: [LASPoint] = []
        let pointsToRead = min(count, Int(header.numberOfPointRecords))
        
        for _ in 0..<pointsToRead {
            let point = try readPoint(format: header.pointDataFormatID, header: header)
            points.append(point)
        }
        
        return points
    }
    
    private func readPoint(format: UInt8, header: LASHeader) throws -> LASPoint {
        // Read X, Y, Z as Int32
        let xInt = try readInt32()
        let yInt = try readInt32()
        let zInt = try readInt32()
        
        // Apply scale and offset
        let x = Double(xInt) * header.scaleX + header.offsetX
        let y = Double(yInt) * header.scaleY + header.offsetY
        let z = Double(zInt) * header.scaleZ + header.offsetZ
        
        // Read intensity
        let intensity = try readUInt16()
        
        // Read return information byte
        let returnByte = try readUInt8()
        
        // Read classification
        let classification = try readUInt8()
        
        // Read scan angle rank (skip)
        offset += 1
        
        // Read user data (skip)
        offset += 1
        
        // Read point source ID (skip)
        offset += 2
        
        // Initialize default values
        var gpsTime: Double = 0
        var red: UInt16 = 0
        var green: UInt16 = 0
        var blue: UInt16 = 0
        
        // Read format-specific data
        switch format {
        case 0:
            // Format 0: No GPS time, no color
            break
            
        case 1:
            // Format 1: GPS time, no color
            gpsTime = try readDouble()
            
        case 2:
            // Format 2: Color, no GPS time
            red = try readUInt16()
            green = try readUInt16()
            blue = try readUInt16()
            
        case 3:
            // Format 3: GPS time and color
            gpsTime = try readDouble()
            red = try readUInt16()
            green = try readUInt16()
            blue = try readUInt16()
            
        case 4:
            // Format 4: GPS time, wave packets (skip wave packets)
            gpsTime = try readDouble()
            offset += 29 // Skip wave packet descriptor and other fields
            
        case 5:
            // Format 5: GPS time, color, wave packets
            gpsTime = try readDouble()
            red = try readUInt16()
            green = try readUInt16()
            blue = try readUInt16()
            offset += 29 // Skip wave packet descriptor and other fields
            
        case 6...10:
            // Extended formats (LAS 1.4)
            // These would require more complex parsing
            // For now, just read GPS time if present
            if format == 6 || format == 7 || format == 8 || format == 9 || format == 10 {
                gpsTime = try readDouble()
            }
            // Skip remaining bytes based on point record length
            let bytesRead = 20 + (format >= 6 ? 8 : 0) // Base + GPS time
            let remainingBytes = Int(header.pointDataRecordLength) - bytesRead
            if remainingBytes > 0 {
                offset += remainingBytes
            }
            
        default:
            throw FileAnalysisError.invalidLASFile("Unsupported point format: \(format)")
        }
        
        return LASPoint(
            x: x,
            y: y,
            z: z,
            intensity: intensity,
            classification: classification,
            red: red,
            green: green,
            blue: blue,
            gpsTime: gpsTime
        )
    }
    
    // MARK: - Binary Reading Helpers
    
    private func readUInt8() throws -> UInt8 {
        guard offset < data.count else {
            throw FileAnalysisError.invalidLASFile("Unexpected end of file")
        }
        let value = data[offset]
        offset += 1
        return value
    }
    
    private func readUInt16() throws -> UInt16 {
        guard offset + 2 <= data.count else {
            throw FileAnalysisError.invalidLASFile("Unexpected end of file")
        }
        let value = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
        offset += 2
        return value
    }
    
    private func readUInt32() throws -> UInt32 {
        guard offset + 4 <= data.count else {
            throw FileAnalysisError.invalidLASFile("Unexpected end of file")
        }
        let value = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
        offset += 4
        return value
    }
    
    private func readInt32() throws -> Int32 {
        guard offset + 4 <= data.count else {
            throw FileAnalysisError.invalidLASFile("Unexpected end of file")
        }
        let value = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: Int32.self).littleEndian
        }
        offset += 4
        return value
    }
    
    private func readDouble() throws -> Double {
        guard offset + 8 <= data.count else {
            throw FileAnalysisError.invalidLASFile("Unexpected end of file")
        }
        let value = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: Double.self).littleEndian
        }
        offset += 8
        return value
    }
    
    private func readString(length: Int) throws -> String {
        guard offset + length <= data.count else {
            throw FileAnalysisError.invalidLASFile("Unexpected end of file")
        }
        let stringData = data.subdata(in: offset..<(offset + length))
        offset += length
        
        // Remove null terminators and convert to string
        let nullTerminatorIndex = stringData.firstIndex(of: 0) ?? stringData.count
        let trimmedData = stringData.subdata(in: 0..<nullTerminatorIndex)
        
        return String(data: trimmedData, encoding: .ascii) ?? ""
    }
    
    // MARK: - Utility Methods
    
    func estimatePointCount() throws -> Int {
        let header = try readHeader()
        return Int(header.numberOfPointRecords)
    }
    
    func getBounds() throws -> PointCloudBounds {
        let header = try readHeader()
        var bounds = PointCloudBounds()
        bounds.minX = header.minX
        bounds.maxX = header.maxX
        bounds.minY = header.minY
        bounds.maxY = header.maxY
        bounds.minZ = header.minZ
        bounds.maxZ = header.maxZ
        return bounds
    }
    
    func hasGPSTime() throws -> Bool {
        let header = try readHeader()
        // GPS time is available in formats 1, 3, 4, 5, and 6-10
        return [1, 3, 4, 5, 6, 7, 8, 9, 10].contains(header.pointDataFormatID)
    }
    
    func hasColor() throws -> Bool {
        let header = try readHeader()
        // Color is available in formats 2, 3, 5, 7, 8, 10
        return [2, 3, 5, 7, 8, 10].contains(header.pointDataFormatID)
    }
}

// MARK: - Extensions for numeric types

extension FixedWidthInteger {
    var littleEndian: Self {
        return self.littleEndian
    }
}

extension Double {
    var littleEndian: Double {
        let bitPattern = self.bitPattern.littleEndian
        return Double(bitPattern: bitPattern)
    }
}
