import Foundation

struct SearchableItem: Sendable {
    let id: String
    let data: String
    let path: String
    let metadata: [String: String]?
}
