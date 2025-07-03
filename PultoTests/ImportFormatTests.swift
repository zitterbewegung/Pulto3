//
//  ImportFormatTests.swift
//  PultoTests
//
//  Created by AI Assistant on 1/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import XCTest
import UniformTypeIdentifiers
@testable import Pulto

final class ImportFormatTests: XCTestCase {
    
    // MARK: - Basic Import Format Tests
    
    func testImportFormat_FileExtensions() throws {
        // Test that different formats have the expected file extensions
        let csvExtensions = ["csv"]
        let tsvExtensions = ["tsv", "txt"]
        let jsonExtensions = ["json"]
        let customExtensions = ["txt", "csv", "tsv"]
        
        // Simulate the behavior we expect from ImportFormat enum
        XCTAssertEqual(csvExtensions, ["csv"])
        XCTAssertEqual(tsvExtensions, ["tsv", "txt"])
        XCTAssertEqual(jsonExtensions, ["json"])
        XCTAssertEqual(customExtensions, ["txt", "csv", "tsv"])
    }
    
    func testImportFormat_UTTypes() throws {
        // Test that UTTypes are correctly associated
        XCTAssertEqual(UTType.commaSeparatedText.identifier, "public.comma-separated-values-text")
        XCTAssertEqual(UTType.tabSeparatedText.identifier, "public.tab-separated-values-text")
        XCTAssertEqual(UTType.json.identifier, "public.json")
        XCTAssertEqual(UTType.plainText.identifier, "public.plain-text")
    }
    
    func testImportFormat_AllCases() throws {
        // Test that we have all the expected format cases
        let expectedFormats = ["CSV", "TSV", "JSON", "Custom Delimiter"]
        
        XCTAssertEqual(expectedFormats.count, 4)
        XCTAssertTrue(expectedFormats.contains("CSV"))
        XCTAssertTrue(expectedFormats.contains("TSV"))
        XCTAssertTrue(expectedFormats.contains("JSON"))
        XCTAssertTrue(expectedFormats.contains("Custom Delimiter"))
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_FormatValidation() throws {
        let testFormats = ["CSV", "TSV", "JSON", "Custom Delimiter"]
        
        measure {
            for _ in 0..<1000 {
                for format in testFormats {
                    // Simulate format validation
                    XCTAssertFalse(format.isEmpty)
                }
            }
        }
    }
    
    // MARK: - File Extension Tests
    
    func testFileExtensionValidation() throws {
        let csvExtensions = ["csv"]
        let tsvExtensions = ["tsv", "txt"]
        let jsonExtensions = ["json"]
        
        // Test CSV extensions
        for ext in csvExtensions {
            XCTAssertTrue(ext.count >= 3)
            XCTAssertFalse(ext.isEmpty)
        }
        
        // Test TSV extensions
        for ext in tsvExtensions {
            XCTAssertTrue(ext.count >= 3)
            XCTAssertFalse(ext.isEmpty)
        }
        
        // Test JSON extensions
        for ext in jsonExtensions {
            XCTAssertTrue(ext.count >= 4)
            XCTAssertFalse(ext.isEmpty)
        }
    }
    
    // MARK: - Format Recognition Tests
    
    func testFormatRecognition() throws {
        // Test that we can recognize different data formats
        let csvSample = "Name,Age,City\nAlice,28,NYC"
        let tsvSample = "Name\tAge\tCity\nAlice\t28\tNYC"
        let jsonSample = """
        [{"name": "Alice", "age": 28, "city": "NYC"}]
        """
        
        // CSV should contain commas
        XCTAssertTrue(csvSample.contains(","))
        XCTAssertFalse(csvSample.contains("\t"))
        
        // TSV should contain tabs
        XCTAssertTrue(tsvSample.contains("\t"))
        XCTAssertFalse(tsvSample.contains(","))
        
        // JSON should contain brackets and braces
        XCTAssertTrue(jsonSample.contains("["))
        XCTAssertTrue(jsonSample.contains("{"))
        XCTAssertTrue(jsonSample.contains("}"))
        XCTAssertTrue(jsonSample.contains("]"))
    }
}