import XCTest
import FirebaseCore
import FirebaseDatabase
@testable import SearchMind

final class RealtimeDatabaseProviderTests: XCTestCase {

    var provider: RealtimeDatabaseProvider!

    override func setUp() {
        super.setUp()

        if FirebaseApp.app() == nil {
            guard let plistPath = Bundle.module.path(forResource: "GoogleService-Info", ofType: "plist") else {
                XCTFail("GoogleService-Info.plist not found in Bundle.module. Make sure it's marked as a resource in Package.swift.")
                return
            }

            guard let options = FirebaseOptions(contentsOfFile: plistPath) else {
                XCTFail("Unable to create FirebaseOptions from GoogleService-Info.plist")
                return
            }

            FirebaseApp.configure(options: options)
        }

        provider = RealtimeDatabaseProvider()
    }

    override func tearDown() {
        provider = nil
        super.tearDown()
    }

  func testSearchReturnsMatchingPosts() async throws {
      let testPath = "test/posts"
      let ref = Database.database().reference(withPath: testPath)

      try await ref.removeValue()

      let sampleData: [String: Any] = [
          "post1": ["id": "1", "title": "Swift Concurrency", "content": "Learn structured concurrency"],
          "post2": ["id": "2", "title": "iOS Testing", "content": "Unit and UI testing in Xcode"],
          "post3": ["id": "3", "title": "Unrelated", "content": "Nothing about the topic"]
      ]

      try await ref.setValue(sampleData)

      let options = SearchOptions(searchPaths: [testPath])

    let results: [SearchableItem] = try await provider.fetchItems(for: options).sorted { $0.id < $1.id }


      XCTAssertEqual(results.count, 3)
      XCTAssertEqual(results.first?.data, "Learn structured concurrency\n1\nSwift Concurrency")
      XCTAssertEqual(results.first?.id, "post1")
  }
}
