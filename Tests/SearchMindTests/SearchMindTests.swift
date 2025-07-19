import Foundation
@testable import SearchMind
import Firebase
import XCTest

final class SearchMindTests: XCTestCase {
    private var testWorkspaceDirectoryURL: URL!
    private var testWorkspacePath: String!
    private var testDatabasePath: String!
    private var search: SearchMind!

    var provider: RealtimeDatabaseProvider!

    enum SearchScope: CaseIterable {
        case file, fileContents, database

        var type: SearchType {
            switch self {
            case .file: return .file
            case .fileContents: return .fileContents
            case .database: return .database
            }
        }

        var description: String {
            switch self {
            case .file: return "File"
            case .fileContents: return "FileContents"
            case .database: return "Database"
            }
        }
    }

    enum SearchAlgorithm: CaseIterable {
        case exact, fuzzy, semantic, patternMatch

        var query: String {
            switch self {
            case .exact: return "sample"
            case .fuzzy: return "sample content"
            case .semantic: return "search terms"
            case .patternMatch: return "testing"
            }
        }

        var description: String {
            switch self {
            case .exact: return "Exact"
            case .fuzzy: return "Fuzzy"
            case .semantic: return "Semantic"
            case .patternMatch: return "PatternMatch"
            }
        }

        func buildOptions(searchPaths: [String]) -> SearchOptions {
            switch self {
            case .exact:
              return SearchOptions(fuzzyMatching: false, searchPaths: searchPaths)
            case .fuzzy:
              return SearchOptions(fuzzyMatching: true, searchPaths: searchPaths)
            case .semantic:
              return SearchOptions(semantic: true, searchPaths: searchPaths)
            case .patternMatch:
              return SearchOptions(patternMatch: true, searchPaths: searchPaths)
            }
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        try setUpWorkspace()
        try await setUpDatabase()
        try configureFirebase()
        search = SearchMind()
    }

    override func tearDown() async throws {
        try await super.tearDown()
        if let testWorkspacePath = testWorkspacePath {
            try FileManager.default.removeItem(at: URL(fileURLWithPath: testWorkspacePath))
        }
        search = nil
        provider = nil
    }

    func testAllAlgorithmsAgainstAllScopes() async throws {
        for algorithm in SearchAlgorithm.allCases {
            for scope in SearchScope.allCases {
                try await runSearchTest(algorithm: algorithm, scope: scope)
            }
        }
    }

    private func runSearchTest(algorithm: SearchAlgorithm, scope: SearchScope) async throws {
        let searchPaths: [String] = {
            switch scope.type {
            case .file, .fileContents:
                return [testWorkspacePath]
            case .database:
                return [testDatabasePath]
            }
        }()

        let options = algorithm.buildOptions(searchPaths: searchPaths)
        let results = try await search.search(algorithm.query, type: scope.type, options: options)
        let description = "[\(algorithm.description) - \(scope.description)]"

        switch (algorithm, scope) {
        case (.patternMatch, .file):
            XCTAssertTrue(results.contains { $0.path.contains("testing_software.txt") }, "\(description) should find testing_software.txt")
        case (.patternMatch, .fileContents):
            XCTAssertTrue(results.contains { $0.path.contains("sample.txt") }, "\(description) should find sample.txt")
        case (.patternMatch, .database):
            XCTAssertTrue(results.contains { $0.path.contains("test/posts/sample") }, "\(description) should find test/posts/sample")

        case (.fuzzy, .file):
            XCTAssertTrue(results.contains { $0.path.contains("sample.txt") }, "\(description) should find sample.txt")
        case (.fuzzy, .fileContents):
            XCTAssertTrue(results.contains { $0.path.contains("sample.txt") }, "\(description) should find sample.txt")
        case (.fuzzy, .database):
            XCTAssertTrue(results.contains { $0.path.contains("test/posts/sample") }, "\(description) should find test/posts/sample")

        case (.exact, .file):
            XCTAssertTrue(results.contains { $0.path.contains("sample.txt") }, "\(description) should find sample.txt")
        case (.exact, .fileContents):
            XCTAssertTrue(results.contains { $0.path.contains("sample.txt") }, "\(description) should find sample.txt")
        case (.exact, .database):
            XCTAssertTrue(results.contains { $0.path.contains("test/posts/sample") }, "\(description) should find test/posts/sample")

        case (.semantic, .file):
            XCTAssertTrue(results.contains { $0.path.contains("document.doc") }, "\(description) should find document.doc")
        case (.semantic, .fileContents):
            XCTAssertTrue(results.contains { $0.path.contains("document.doc") }, "\(description) should find document.doc")
        case (.semantic, .database):
            XCTAssertTrue(results.contains { $0.path.contains("test/posts/document") }, "\(description) should find test/posts/document")
        }
    }

    private func setUpWorkspace() throws {
        testWorkspaceDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        testWorkspacePath = testWorkspaceDirectoryURL.path

        try FileManager.default.createDirectory(at: testWorkspaceDirectoryURL, withIntermediateDirectories: true)

        let testFiles: [(name: String, content: String)] = [
            ("sample.txt", "Sample content for testing"),
            ("text_file.txt", "Another sample text file"),
            ("testing_software.txt", "Another sample text file"),
            ("document.doc", "Test document with search terms")
        ]

        for (fileName, content) in testFiles {
            let path = testWorkspaceDirectoryURL.appendingPathComponent(fileName)
            try content.write(to: path, atomically: true, encoding: .utf8)
        }
    }

    private func setUpDatabase() async throws {
        testDatabasePath = "test/posts"
        provider = RealtimeDatabaseProvider()
        let ref = Database.database().reference(withPath: testDatabasePath)

        try await ref.removeValue()

        let testPosts: [String: [String: String]] = [
            "sample": [
                "id": "1",
                "title": "sample",
                "content": "Sample content for testing"
            ],
            "text_file": [
                "id": "2",
                "title": "text_file",
                "content": "Another sample text file"
            ],
            "document": [
                "id": "3",
                "title": "document",
                "content": "This document contains search terms for semantic match"
            ]
        ]

        try await ref.setValue(testPosts)
    }

    private func configureFirebase() throws {
        guard FirebaseApp.app() == nil else { return }

        guard let plistPath = Bundle.module.path(forResource: "GoogleService-Info", ofType: "plist") else {
            XCTFail("GoogleService-Info.plist not found.")
            return
        }

        guard let options = FirebaseOptions(contentsOfFile: plistPath) else {
            XCTFail("Unable to create FirebaseOptions")
            return
        }

        FirebaseApp.configure(options: options)
    }
}
