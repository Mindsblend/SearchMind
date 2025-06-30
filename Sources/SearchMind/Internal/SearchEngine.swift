import Algorithms
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
        let provider = FileProvider()
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

        let searchPaths = options.searchPaths ?? [URL(fileURLWithPath: fileManager.currentDirectoryPath)]
        for path in searchPaths {
            var isDirectory: ObjCBool = false

            guard fileManager.fileExists(atPath: path.path, isDirectory: &isDirectory) else {
                throw SearchError.invalidSearchPath(path.path)
            }

            if isDirectory.boolValue {
                let contents = try fileManager.contentsOfDirectory(
                    at: path,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
                for url in contents {
                    if let isRegular = try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isRegular {
                        allFiles.append(url)
                    }
                }
            } else {
                allFiles.append(path)
            }
        }

        if let fileExtensions = options.fileExtensions, !fileExtensions.isEmpty {
            allFiles = allFiles.filter { fileExtensions.contains($0.pathExtension) }
        }

        return allFiles.map {
            SearchableItem(id: UUID().uuidString, title: $0.lastPathComponent, content: nil, metadata: nil, path: $0.path)
        }
    }
}

/// Algorithm for exact string matching
struct ExactMatchAlgorithm: SearchAlgorithm {
    let provider: Provider

    func search(term: String, type _: SearchType, options: SearchOptions) async throws -> [SearchMind.SearchResult] {
        let searchTerm = options.caseSensitive ? term : term.lowercased()
        let items = try await provider.fetchItems(for: options)

        // Filter files based on search term
        var results: [SearchMind.SearchResult] = []

        for item in items {
            let title = options.caseSensitive ? item.title : item.title.lowercased()

            if title.contains(searchTerm) {
                let score = title == searchTerm ? 1.0 : 0.7

                results.append(SearchMind.SearchResult(
                    matchType: .file,
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
    func search(term: String, type _: SearchType, options: SearchOptions) async throws -> [SearchMind.SearchResult] {
        let searchTerm = options.caseSensitive ? term : term.lowercased()
        let items = try await provider.fetchItems(for: options)

        // Use fuzzy matching to find potential matches
        var results: [SearchMind.SearchResult] = []

        for item in items {
            let title = options.caseSensitive ? item.title : item.title.lowercased()

            // Using Swift Algorithms to calculate Levenshtein distance
            let distance = calculateLevenshteinDistance(from: searchTerm, to: title)

            // Calculate normalized relevance score (0 to 1)
            // Lower distance = higher relevance
            let maxLength = max(searchTerm.count, title.count)
            let normalizedDistance = maxLength > 0 ? Double(distance) / Double(maxLength) : 1.0
            let relevanceScore = 1.0 - normalizedDistance

            // Only include results above a certain relevance threshold
            if relevanceScore > 0.3 {
                results.append(SearchMind.SearchResult(
                    matchType: .file,
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

    func search(term: String, type _: SearchType, options: SearchOptions) async throws -> [SearchMind.SearchResult] {
        let searchTerm = options.caseSensitive ? term : term.lowercased()
        let items = try await provider.fetchItems(for: options)

        var results: [SearchMind.SearchResult] = []

        // Search through file contents (limited to text files)
        for item in items {
            do {
                let url = URL(fileURLWithPath: item.path)
                let itemContents = try String(contentsOf: url)
                let compareContents = options.caseSensitive ? itemContents : itemContents.lowercased()

                // Simple content search to find matches
                if compareContents.contains(searchTerm) {
                    // Extract context around the match
                    let context = extractContext(from: compareContents, around: searchTerm)

                    // Count matches to influence relevance score
                    let matchCount = compareContents.components(separatedBy: searchTerm).count - 1
                    let relevanceScore = min(Double(matchCount) * 0.1 + 0.5, 1.0)

                    results.append(SearchMind.SearchResult(
                        matchType: .fileContents,
                        path: item.path,
                        relevanceScore: relevanceScore,
                        matchedTerms: [term],
                        context: context
                    ))
                }
            } catch {
                // Skip files that can't be read as text
                continue
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
    func search(term: String, type _: SearchType, options: SearchOptions) async throws -> [SearchMind.SearchResult] {
        let searchTerm = options.caseSensitive ? term : term.lowercased()
        let items = try await provider.fetchItems(for: options)
        guard let apiKey = options.apiKey else {
            throw SearchError.missingKey
        }
        let termEmbedding = try await embed(text: searchTerm, apiKey: apiKey)

        var results: [SearchMind.SearchResult] = []

        for item in items {
            let url = URL(fileURLWithPath: item.path)
            let content = try String(contentsOf: url)
            let fileEmbedding = try await embed(text: content, apiKey: apiKey)

            let similarity = cosineSimilarity(termEmbedding, fileEmbedding)
            if similarity > 0.4 {
                results.append(SearchMind.SearchResult(
                    matchType: .fileContents,
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

    private func embed(text: String, apiKey: String) async throws -> [Double] {
        let request = EmbeddingRequest(model: "text-embedding-ada-002", input: [text])
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
