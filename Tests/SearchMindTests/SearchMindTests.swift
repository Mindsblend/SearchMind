import Foundation
@testable import SearchMind
import XCTest

final class SearchMindTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var search: SearchMind!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary directory for file tests
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        temporaryDirectory = tempDir

        // Create sample files for testing
        try "Sample content for testing".write(to: tempDir.appendingPathComponent("sample.txt"), atomically: true, encoding: .utf8)
        try "Another sample text file".write(to: tempDir.appendingPathComponent("text_file.txt"), atomically: true, encoding: .utf8)
        try "Test document with search terms".write(to: tempDir.appendingPathComponent("document.doc"), atomically: true, encoding: .utf8)

        search = SearchMind()
    }

    override func tearDown() async throws {
        try await super.tearDown()

        // Clean up temporary directory
        if let tempDir = temporaryDirectory {
            try FileManager.default.removeItem(at: tempDir)
        }

        // Clean up search instance
        search = nil
    }

    /// Test exact file search
    func testFileSearch() async throws {
        let options = SearchOptions(
            fuzzyMatching: false,
            searchPaths: [temporaryDirectory]
        )

        let results = try await search.search("sample", type: .file, options: options)

        XCTAssertFalse(results.isEmpty, "Should find at least one file")
        XCTAssertTrue(results.contains { $0.path.contains("sample.txt") }, "Should find sample.txt")
    }

    func testFuzzyFileSearch() async throws {
        let options = SearchOptions(
            fuzzyMatching: true,
            searchPaths: [temporaryDirectory]
        )

        let results = try await search.search("sampl", type: .file, options: options)

        XCTAssertFalse(results.isEmpty, "Should find at least one file with fuzzy matching")
        XCTAssertTrue(results.contains { $0.path.contains("sample.txt") }, "Should find sample.txt with fuzzy matching")
    }

    /// Test Semantic Search using GPT Embeddings
    func testSemanticSearch() async throws {
        // Given: Define search options for semantic search
        let options = SearchOptions(
            semantic: true,
            searchPaths: [temporaryDirectory]
        )

        // Sample query and expected result
        let query = "search terms"
        let expectedFile = "document.doc"

        // When: Perform the search using the 'search' method of the SearchMind class
        let results = try await search.search(query, type: .fileContents, options: options)

        // Then: Assert that the search returns at least one result
        XCTAssertFalse(results.isEmpty, "Should find results for semantic search")

        // And: Assert that the expected file is found based on the semantic relevance
        XCTAssertTrue(results.contains { $0.path.contains(expectedFile) }, "Should find the document.doc file based on semantic search")
    }

    func testFileContentSearch() async throws {
        // Test file content search
        let options = SearchOptions(
            patternMatch: true,
            searchPaths: [temporaryDirectory]
        )

        let results = try await search.search("testing", type: .fileContents, options: options)

        XCTAssertFalse(results.isEmpty, "Should find file containing 'testing'")
        XCTAssertTrue(results.contains { $0.path.contains("sample.txt") }, "Should find sample.txt containing 'testing'")
    }

    func testFileExtensionFiltering() async throws {
        // Test file extension filtering
        let options = SearchOptions(
            searchPaths: [temporaryDirectory],
            fileExtensions: ["txt"]
        )

        let results = try await search.search("sample", type: .file, options: options)

        XCTAssertFalse(results.isEmpty, "Should find txt files")
        XCTAssertTrue(results.all { $0.path.hasSuffix(".txt") }, "Should only find .txt files")
        XCTAssertFalse(results.contains { $0.path.hasSuffix(".doc") }, "Should not find .doc files")
    }

    func testCaseInsensitiveSearch() async throws {
        // Test case insensitive search
        let options = SearchOptions(
            caseSensitive: false,
            searchPaths: [temporaryDirectory]
        )

        let results = try await search.search("SAMPLE", type: .fileContents, options: options)

        XCTAssertFalse(results.isEmpty, "Should find matches with case insensitive search")
    }

    func testCaseSensitiveSearch() async throws {
        // Test case sensitive search
        let options = SearchOptions(
            caseSensitive: true,
            searchPaths: [temporaryDirectory]
        )

        let results = try await search.search("SAMPLE", type: .fileContents, options: options)

        // Assuming our test files don't contain uppercase "SAMPLE"
        XCTAssertTrue(results.isEmpty, "Should not find matches with case sensitive search")
    }

    func testMultiSearch() async throws {
        // Test searching for multiple terms
        let options = SearchOptions(
            searchPaths: [temporaryDirectory]
        )

        let results = try await search.multiSearch(terms: ["sample", "testing"], type: .fileContents, options: options)

        XCTAssertEqual(results.count, 2, "Should return results for both search terms")
        XCTAssertTrue(results.keys.contains("sample"), "Should contain results for 'sample'")
        XCTAssertTrue(results.keys.contains("testing"), "Should contain results for 'testing'")
    }
}

extension Array {
    func all(_ predicate: (Element) -> Bool) -> Bool {
        !contains { !predicate($0) }
    }
}
