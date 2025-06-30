import Foundation

struct SearchableItem: Sendable {
    let id: String
    let title: String
    let content: String?
    let metadata: [String: String]?
  let path: String
}
