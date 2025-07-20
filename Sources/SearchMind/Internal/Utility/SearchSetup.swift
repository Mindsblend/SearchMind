import Foundation

struct SearchSetup {
  func createMetadata(
          data: String?,
          path: String,
          providerType: SearchType
      ) -> [String: String] {
          let url = URL(fileURLWithPath: path)
          var metadata: [String: String] = [:]

          switch providerType {
          case .file:
              metadata["provider"] = "file"
              metadata["filename"] = url.lastPathComponent
              metadata["fileExtension"] = url.pathExtension
              metadata["directory"] = url.deletingLastPathComponent().lastPathComponent

          case .fileContents:
              metadata["provider"] = "fileContents"
              metadata["filename"] = url.lastPathComponent
              metadata["fileExtension"] = url.pathExtension
              metadata["lineCount"] = data.map { "\($0.components(separatedBy: .newlines).count)" } ?? "0"
              metadata["characterCount"] = data.map { "\($0.count)" } ?? "0"
              metadata["preview"] = data.map { String($0.prefix(80)).replacingOccurrences(of: "\n", with: " ") } ?? ""

          case .database:
              metadata["provider"] = "database"
              metadata["collection"] = url.deletingLastPathComponent().lastPathComponent
              metadata["documentId"] = url.deletingPathExtension().lastPathComponent
              metadata["preview"] = data.map { String($0.prefix(80)).replacingOccurrences(of: "\n", with: " ") } ?? ""
          }

          return metadata
      }

  /// Recursively flattens all string-like values in a dictionary to a single text blob.
  func extractText(from dictionary: [String: Any]) -> String {
      var collectedText: [String] = []

      func flatten(_ value: Any) {
          if let string = value as? String {
              collectedText.append(string)
          } else if let number = value as? NSNumber {
              collectedText.append(number.stringValue)
          } else if let array = value as? [Any] {
              array.forEach(flatten)
          } else if let dict = value as? [String: Any] {
              for key in dict.keys.sorted() {
                  if let value = dict[key] {
                      flatten(value)
                  }
              }
          }
      }

      flatten(dictionary)
      return collectedText.joined(separator: "\n")
  }
}
