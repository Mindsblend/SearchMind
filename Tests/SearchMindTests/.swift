import XCTest
import FirebaseCore
import FirebaseDatabase
@testable import SearchMind

final class RealtimeDatabaseProviderTests: XCTestCase {

    var provider: RealtimeDatabaseProvider!

    override func setUp() {
        super.setUp()

        // Firebase manual config from SPM resource bundle
        if FirebaseApp.app() == nil {
            let testBundle = Bundle(for: type(of: self))
            guard let filePath = testBundle.path(forResource: "GoogleService-Info", ofType: "plist"),
                  let options = FirebaseOptions(contentsOfFile: filePath) else {
                fatalError("Failed to load GoogleService-Info.plist from test bundle.")
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
        // Given
        let testPath = "test/posts"
        let ref = Database.database().reference(withPath: testPath)

        // Clean up existing data
        try await ref.removeValue()

        let sampleData: [String: Any] = [
            "post1": [
                "id": "1",
                "title": "Swift Concurrency",
                "content": "Learn structured concurrency"
            ],
            "post2": [
                "id": "2",
                "title": "iOS Testing",
                "content": "Unit and UI testing in Xcode"
            ],
            "post3": [
                "id": "3",
                "title": "Unrelated",
                "content": "Nothing about the topic"
            ]
        ]

        // Write sample data to Firebase
        try await ref.setValue(sampleData)

        let options = SearchOptions(searchPaths: [URL(string: testPath)!])
        let query = "swift"

        // When
        let results: [SearchableItem] = try await provider.fetchItems(for: options)

        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Swift Concurrency")
        XCTAssertEqual(results.first?.id, "1")
    }
}
