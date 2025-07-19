import Algorithms
@preconcurrency import FirebaseDatabase
import Foundation

/// Protocol defining a search engine
public protocol SearchEngine: Sendable {
    /// Perform a search operation
    /// - Parameters:
    ///   - term: The search term
    ///   - type: The type of search to perform
    ///   - options: Additional search options
    /// - Returns: Array of search results sorted by relevance
    func search(term: String, type: SearchType, options: SearchOptions) async throws -> [SearchMind.SearchResult]
}

/// Default implementation of the search engine
public final class DefaultSearchEngine: SearchEngine {
    /// Algorithm selector for choosing the best search algorithm based on input
    private let algorithmSelector = SearchAlgorithmSelector()

    public init() {}

    public func search(term: String, type: SearchType, options: SearchOptions) async throws -> [SearchMind.SearchResult] {
        // Choose the appropriate algorithm
        let algorithm = algorithmSelector.selectAlgorithm(for: term, type: type, options: options)

        // If timeout is set, use a task with timeout
        if let timeout = options.timeout {
            return try await withThrowingTaskGroup(of: [SearchMind.SearchResult].self) { group in
                // Store values locally to avoid capture issues
                let termCopy = term
                let typeCopy = type
                let optionsCopy = options

                // Add the search task
                group.addTask { [algorithm] in
                    return try await algorithm.search(term: termCopy, type: typeCopy, options: optionsCopy)
                }

                // Add a timeout task
                let timeoutNanoseconds = UInt64(timeout * 1_000_000_000)
                group.addTask {
                    try await Task.sleep(nanoseconds: timeoutNanoseconds)
                    throw SearchError.searchTimeout
                }

                // Return the first completed task (either the search or the timeout)
                let result = try await group.next()!

                // Cancel any remaining tasks
                group.cancelAll()

                return result
            }
        } else {
            // No timeout, just perform the search
            return try await algorithm.search(term: term, type: type, options: options)
        }
    }
}

/// Selects the most appropriate search algorithm based on inputs
final class SearchAlgorithmSelector: Sendable {
    func selectAlgorithm(for _: String, type: SearchType, options: SearchOptions) -> SearchAlgorithm {
      switch type {
        case .file:
          return selectFileAlgorithm(options: options)
        case .fileContents:
          return selectFileContentsAlgorithm(options: options)
        case .database:
          return selectDatabaseAlgorithm(options: options)
      }
    }

    private func selectFileAlgorithm(options: SearchOptions) -> SearchAlgorithm {
      let provider = FileProvider()

        if options.semantic {
          return GPTSemanticSearchAlgorithm(provider: provider)
        }
        if options.fuzzyMatching {
          return FuzzyMatchAlgorithm(provider: provider)
        }
        if options.patternMatch {
          return PatternMatchAlgorithm(provider: provider)
        }
      return ExactMatchAlgorithm(provider: provider)
    }

    private func selectFileContentsAlgorithm(options: SearchOptions) -> SearchAlgorithm {
      let provider = FileContentsProvider()
        if options.semantic {
          return GPTSemanticSearchAlgorithm(provider: provider)
        }
        if options.patternMatch {
          return PatternMatchAlgorithm(provider: provider)
        }
        if options.fuzzyMatching {
          return FuzzyMatchAlgorithm(provider: provider)
        }
      return ExactMatchAlgorithm(provider: provider)
    }

    private func selectDatabaseAlgorithm(options: SearchOptions) -> SearchAlgorithm {
      let provider = RealtimeDatabaseProvider()
        if options.semantic {
          return GPTSemanticSearchAlgorithm(provider: provider)
        }
        if options.patternMatch {
          return PatternMatchAlgorithm(provider: provider)
        }
        if options.fuzzyMatching {
          return FuzzyMatchAlgorithm(provider: provider)
        }
      return ExactMatchAlgorithm(provider: provider)
    }
}

/// Base protocol for search algorithms
protocol SearchAlgorithm: Sendable {
    func search(term: String, type: SearchType, options: SearchOptions) async throws -> [SearchMind.SearchResult]
}

/// Provider to fetch and prepare the target operation data for  the search algotihtm (e.g .file, .fileContents, .database)
protocol Provider: Sendable {
    func fetchItems(for options: SearchOptions) async throws -> [SearchableItem]
}

final class FileProvider: Provider {
  func fetchItems(for options: SearchOptions) async throws -> [SearchableItem] {
          let fileManager = FileManager.default
          var allFiles: [URL] = []

          guard let searchPaths = options.searchPaths else {
            throw SearchError.searchPathUnavailable
          }

          for path in searchPaths {
              var isDirectory: ObjCBool = false

              guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
                  throw SearchError.invalidSearchPath(path)
              }

              if isDirectory.boolValue {
                  let contents = try fileManager.contentsOfDirectory(
                      at: URL(fileURLWithPath: path),
                      includingPropertiesForKeys: [.isRegularFileKey],
                      options: [.skipsHiddenFiles]
                  )
                  for url in contents {
                      if let isRegular = try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isRegular {
                          allFiles.append(url)
                      }
                  }
              } else {
                allFiles.append(URL(fileURLWithPath: path))
              }
          }

          if let fileExtensions = options.fileExtensions, !fileExtensions.isEmpty {
              allFiles = allFiles.filter { fileExtensions.contains($0.pathExtension) }
          }


    var searchableItems: [SearchableItem] = []

    for fileURL in allFiles {
      let id = UUID().uuidString
      let data = fileURL.lastPathComponent
      let path = fileURL.path
      let metadata = SearchSetup().createMetadata(
            data: data,
            path: fileURL.path,
            providerType: .file
        )
      
        let item = SearchableItem(
          id: id,
          data: data,
          path: path,
          metadata: metadata
        )
        searchableItems.append(item)
    }

    return searchableItems
      }
}

final class FileContentsProvider: Provider {
    func fetchItems(for options: SearchOptions) async throws -> [SearchableItem] {
        let fileManager = FileManager.default
        var allFiles: [URL] = []

        guard let searchPaths = options.searchPaths else {
            throw SearchError.searchPathUnavailable
        }

        for path in searchPaths {
            var isDirectory: ObjCBool = false

            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
                throw SearchError.invalidSearchPath(path)
            }

            if isDirectory.boolValue {
                let contents = try fileManager.contentsOfDirectory(
                    at: URL(fileURLWithPath: path),
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
                for url in contents {
                    if let isRegular = try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isRegular {
                        allFiles.append(url)
                    }
                }
            } else {
                allFiles.append(URL(fileURLWithPath: path))
            }
        }

        if let fileExtensions = options.fileExtensions, !fileExtensions.isEmpty {
            allFiles = allFiles.filter { fileExtensions.contains($0.pathExtension) }
        }

        var searchableItems: [SearchableItem] = []

        for fileURL in allFiles {
          let id = UUID().uuidString
          let data = try String(contentsOf: fileURL)
          let path = fileURL.path
          let metadata = SearchSetup().createMetadata(
                data: data,
                path: fileURL.path,
                providerType: .file
            )

            let item = SearchableItem(
              id: id,
              data: data,
              path: path,
              metadata: metadata
            )

            searchableItems.append(item)
        }

        return searchableItems
    }
}

final class RealtimeDatabaseProvider: Provider {
  func fetchItems(for options: SearchOptions) async throws -> [SearchableItem] {
      var searchableItems: [SearchableItem] = []
      let db = Database.database().reference()

    guard let searchPaths = options.searchPaths else {
      throw SearchError.searchPathUnavailable
    }

      for path in searchPaths {
          let fetchedItems: [SearchableItem] = try await withCheckedThrowingContinuation { continuation in
              db.child(path).observeSingleEvent(of: .value, with: { snapshot in
                  guard let value = snapshot.value as? [String: Any] else {
                    continuation.resume(throwing: SearchError.invalidSnapshotFormat)
                      return
                  }

                  var localItems: [SearchableItem] = []

                for (key, value) in value {
                    if let dict = value as? [String: Any] {
                        let id = key
                        let path = "\(path)/\(key)"
                        let data = SearchSetup().extractText(from: dict)

                        let metadata = SearchSetup().createMetadata(
                            data: data,
                            path: path,
                            providerType: .database
                        )

                        let item = SearchableItem(
                            id: id,
                            data: data,
                            path: path,
                            metadata: metadata
                        )

                        localItems.append(item)
                    }
                }

                continuation.resume(returning: localItems)
              })
          }

        searchableItems.append(contentsOf: fetchedItems)
      }

      return searchableItems
  }
}


/// Algorithm for exact string matching
struct ExactMatchAlgorithm: SearchAlgorithm {
  let provider: Provider

    func search(term: String, type: SearchType, options: SearchOptions) async throws -> [SearchMind.SearchResult] {
        let searchTerm = options.caseSensitive ? term : term.lowercased()
        let items = try await provider.fetchItems(for: options)

        // Filter files based on search term
        var results: [SearchMind.SearchResult] = []


      for item in items {
          let searchableData = options.caseSensitive ? item.data : item.data.lowercased()

          if searchableData.contains(searchTerm) {
              let score = searchableData == searchTerm ? 1.0 : 0.7

              results.append(SearchMind.SearchResult(
                  matchType: type,
                  path: item.path,
                  relevanceScore: score,
                  matchedTerms: [term]
              ))
          }
      }

        // Sort by relevance score (highest first)
        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }
}

/// Algorithm for fuzzy string matching using Swift Algorithms
struct FuzzyMatchAlgorithm: SearchAlgorithm {
  let provider: Provider
    func search(term: String, type: SearchType, options: SearchOptions) async throws -> [SearchMind.SearchResult] {
        let searchTerm = options.caseSensitive ? term : term.lowercased()
        let items = try await provider.fetchItems(for: options)

        // Use fuzzy matching to find potential matches
        var results: [SearchMind.SearchResult] = []

        for item in items {
            let searchableData = options.caseSensitive ? item.data : item.data.lowercased()

            // Using Swift Algorithms to calculate Levenshtein distance
            let distance = calculateLevenshteinDistance(from: searchTerm, to: searchableData)

            // Calculate normalized relevance score (0 to 1)
            // Lower distance = higher relevance
            let maxLength = max(searchTerm.count, searchableData.count)
            let normalizedDistance = maxLength > 0 ? Double(distance) / Double(maxLength) : 1.0
            let relevanceScore = 1.0 - normalizedDistance

            // Only include results above a certain relevance threshold
            if relevanceScore > 0.3 {
                results.append(SearchMind.SearchResult(
                    matchType: type,
                    path: item.path,
                    relevanceScore: relevanceScore,
                    matchedTerms: [term]
                ))
            }
        }

        // Sort by relevance score (highest first)
        return results.sorted { $0.relevanceScore > $1.relevanceScore }.prefix(options.maxResults).map { $0 }
    }

    private func calculateLevenshteinDistance(from source: String, to target: String) -> Int {
        // Simple Levenshtein distance implementation
        // For a production implementation, we would use more efficient algorithms
        let source = Array(source)
        let target = Array(target)

        var dist = Array(repeating: Array(repeating: 0, count: target.count + 1), count: source.count + 1)

        for i in 0 ... source.count {
            dist[i][0] = i
        }

        for j in 0 ... target.count {
            dist[0][j] = j
        }

        for i in 1 ... source.count {
            for j in 1 ... target.count {
                if source[i - 1] == target[j - 1] {
                    dist[i][j] = dist[i - 1][j - 1]
                } else {
                    dist[i][j] = min(
                        dist[i - 1][j] + 1, // deletion
                        dist[i][j - 1] + 1, // insertion
                        dist[i - 1][j - 1] + 1 // substitution
                    )
                }
            }
        }

        return dist[source.count][target.count]
    }
}

/// Algorithm for pattern matching in file contents
struct PatternMatchAlgorithm: SearchAlgorithm {
    let provider: Provider

    func search(term: String, type: SearchType, options: SearchOptions) async throws -> [SearchMind.SearchResult] {
        let searchTerm = options.caseSensitive ? term : term.lowercased()
        let items = try await provider.fetchItems(for: options)

        var results: [SearchMind.SearchResult] = []

        // Search through file contents (limited to text files)
        for item in items {
          let searchableData = options.caseSensitive ? item.data : item.data.lowercased()

          // Simple content search to find matches
          if searchableData.contains(searchTerm) {
              // Extract context around the match
              let context = extractContext(from: searchableData, around: searchTerm)

              // Count matches to influence relevance score
              let matchCount = searchableData.components(separatedBy: searchTerm).count - 1
              let relevanceScore = min(Double(matchCount) * 0.1 + 0.5, 1.0)

              results.append(SearchMind.SearchResult(
                  matchType: type,
                  path: item.path,
                  relevanceScore: relevanceScore,
                  matchedTerms: [term],
                  context: context
              ))
          }
        }

        // Sort by relevance score
        return results.sorted { $0.relevanceScore > $1.relevanceScore }.prefix(options.maxResults).map { $0 }
    }

    private func extractContext(from text: String, around term: String) -> String? {
        guard let range = text.range(of: term, options: .caseInsensitive) else {
            return nil
        }

        // Extract characters before and after the match
        let contextLength = 50
        let start = text.index(range.lowerBound, offsetBy: -min(contextLength, text.distance(from: text.startIndex, to: range.lowerBound)), limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: min(contextLength, text.distance(from: range.upperBound, to: text.endIndex)), limitedBy: text.endIndex) ?? text.endIndex

        let contextRange = start ..< end
        var context = String(text[contextRange])

        // Add ellipses if context is truncated
        if start != text.startIndex {
            context = "..." + context
        }
        if end != text.endIndex {
            context = context + "..."
        }

        return context
    }
}

/// Algorithm for semantic search with AI
struct GPTSemanticSearchAlgorithm: SearchAlgorithm {
  let provider: Provider
    func search(term: String, type: SearchType, options: SearchOptions) async throws -> [SearchMind.SearchResult] {
        let searchTerm = options.caseSensitive ? term : term.lowercased()
        let items = try await provider.fetchItems(for: options)
        guard let apiKey = options.apiKey else {
            throw SearchError.missingKey
        }
        let termEmbedding = try await embed(data: searchTerm, apiKey: apiKey)

        var results: [SearchMind.SearchResult] = []

        for item in items {

          let searchableData = options.caseSensitive ? item.data : item.data.lowercased()

          let fileEmbedding = try await embed(data: searchableData, apiKey: apiKey)

            let similarity = cosineSimilarity(termEmbedding, fileEmbedding)
            if similarity > 0.4 {
                results.append(SearchMind.SearchResult(
                    matchType: type,
                    path: item.path,
                    relevanceScore: similarity,
                    matchedTerms: [term]
                ))
            }
        }

        return results.sorted { $0.relevanceScore > $1.relevanceScore }
            .prefix(options.maxResults)
            .map { $0 }
    }

    private func embed(data: String, apiKey: String) async throws -> [Double] {
        let request = EmbeddingRequest(model: "text-embedding-ada-002", input: [data])
        let jsonData = try JSONEncoder().encode(request)

        var urlRequest = URLRequest(url: URL(string: "https://api.openai.com/v1/embeddings")!)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = jsonData

        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let response = try JSONDecoder().decode(EmbeddingResponse.self, from: data)

        guard let embedding = response.data.first?.embedding else {
            throw SearchError.failedEmbeddingExtraction
        }

        return embedding
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0.0 }
        let dot = zip(a, b).map(*).reduce(0, +)
        let magA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        return (magA > 0 && magB > 0) ? dot / (magA * magB) : 0
    }
}
