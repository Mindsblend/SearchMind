@testable import SearchMind
import XCTest

final class FileProviderTests: XCTestCase {
    var fileProvider: FileProvider!
    var tempDirectory: String!

    override func setUpWithError() throws {
        fileProvider = FileProvider()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: tempDirectory), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: tempDirectory))
    }

    func createFile(named name: String, withExtension ext: String = "txt") throws -> URL {
        let fileURL = URL(fileURLWithPath: tempDirectory).appendingPathComponent("\(name).\(ext)")
        try "Test Content".write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func test_fetchItems_returnsAllFilesInDirectory() async throws {
        _ = try createFile(named: "file1")
        _ = try createFile(named: "file2")

        let options = SearchOptions(searchPaths: [tempDirectory], fileExtensions: nil)

        let items = try await fileProvider.fetchItems(for: options)

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.allSatisfy { $0.data.hasSuffix(".txt") })
    }

    func test_fetchItems_filtersByFileExtension() async throws {
        _ = try createFile(named: "notes", withExtension: "md")
        _ = try createFile(named: "code", withExtension: "swift")

        let options = SearchOptions(searchPaths: [tempDirectory], fileExtensions: ["swift"])

        let items = try await fileProvider.fetchItems(for: options)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.data, "code.swift")
    }

    func test_fetchItems_shouldThrowError_forInvalidPath() async throws {
        let provider = FileProvider()
        let invalidPath = "/invalid/path"
        let options = SearchOptions(searchPaths: [invalidPath])

        do {
            _ = try await provider.fetchItems(for: options)
            XCTFail("Expected error not thrown")
        } catch let error as SearchError {
            XCTAssertEqual(error, .invalidSearchPath(invalidPath))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
