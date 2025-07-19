//
//  CSVParser.swift
//  Pulto3
//
//  Created by Joshua Herman on 7/18/25.
//  Copyright © 2025 Apple. All rights reserved.
//


//
//  CSVParser.swift
//  Pulto3
//

import Foundation

class ImportCSVParser {
    static func parse(_ data: String, delimiter: Character) -> (headers: [String], rows: [[String]]) {
        let lines = data.split(whereSeparator: \.isNewline).map(String.init)
        guard !lines.isEmpty else { return ([], []) }
        
        // Assumes the first line is the header
        let headers = lines[0]
            .split(separator: delimiter)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        
        let rows = lines.dropFirst().map { line in
            line.split(separator: delimiter, omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        
        return (headers, rows)
    }
}
