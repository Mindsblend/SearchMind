import Algorithms
import Foundation

/// Main entry point for searching files and file contents
///
/// SearchMind provides a clean, easy-to-use API for searching file names and contents.
/// It automatically selects the most appropriate search algorithm based on the
/// search type and options you specify.
///
/// ## Features
///
/// - Search in file names with exact or fuzzy matching
/// - Search in file contents with context extraction
/// - Concurrent search operations for multiple terms
/// - Configurable search options
/// - Thread-safe for use with Swift concurrency
///
/// ## Basic Usage
///
/// ```swift
/// import SearchMind
///
/// // Create a search instance
/// let searchMind = SearchMind()
///
/// // Search for files with "model" in their name
/// let fileResults = try await searchMind.search("model", type: .file)
///
/// // Search for files containing "protocol" in their contents
/// let contentResults = try await searchMind.search("protocol", type: .fileContents)
///
/// // Search multiple terms at once
/// let terms = ["class", "struct", "enum"]
/// let multiResults = try await searchMind.multiSearch(terms: terms)
/// ```
///
/// ## Performance Considerations
///
/// - File name searches are generally faster than content searches
/// - Fuzzy matching is more CPU-intensive than exact matching
/// - Consider using file extension filtering to limit search scope
/// - For large directories, consider setting a timeout value
///
/// ## Thread Safety
///
/// SearchMind is designed to be thread-safe and conforms to the `Sendable` protocol,
/// making it safe to use with Swift's structured concurrency. All search results are
/// immutable value types.
public final class SearchMind: Sendable {
    /// Result of a search operation
    ///
    /// SearchResult represents a single match found during a search operation.
    /// It contains information about the match location, relevance, and context.
    ///
    /// This struct is immutable and thread-safe, conforming to the `Sendable` protocol
    /// for safe use with Swift concurrency.
    ///
    /// - Example: Basic usage
    /// ```swift
    /// let results = try await searchMind.search("view", type: .file)
    /// for result in results {
    ///     print("Match found: \(result.path) (Score: \(result.relevanceScore))")
    /// }
    /// ```
    ///
    /// - Example: Sorting by relevance
    /// ```swift
    /// // Results are already sorted by relevance, but you can sort them differently
    /// let sortedByPath = results.sorted { $0.path.localizedCompare($1.path) == .orderedAscending }
    /// ```
    public struct SearchResult: Sendable {
        /// The type of search that found this result
        ///
        /// Indicates whether this match was found in a filename or file contents.
        /// This can be useful when presenting results to differentiate between
        /// matches in file names versus matches in content.
        public let matchType: SearchType

        /// The file path where the match was found
        ///
        /// For both file name and content searches, this is the path to the file
        /// containing the match. The path is absolute.
        ///
        /// - Note: To get just the filename, use `URL(fileURLWithPath: path).lastPathComponent`
        public let path: String

        /// Relevance score for this match (0.0 to 1.0)
        ///
        /// A value between 0.0 and 1.0 indicating how relevant this result is to
        /// the search query, with 1.0 being the most relevant.
        ///
        /// For exact matches, the score is typically 1.0. For fuzzy matches,
        /// the score decreases as the match quality decreases.
        ///
        /// Results returned by search methods are sorted by relevance score in
        /// descending order (highest relevance first).
        public let relevanceScore: Double

        /// The search terms that matched this result
        ///
        /// Contains the search terms that led to this match. For single-term searches,
        /// this array will contain just one element. For multi-term searches using
        /// `multiSearch`, this array may contain multiple matching terms.
        public let matchedTerms: [String]

        /// Surrounding context for content matches
        ///
        /// For `.fileContents` searches, this provides text surrounding the match
        /// to help understand the context. The matched term is included within
        /// this context string.
        ///
        /// For `.file` searches, this is `nil`.
        ///
        /// - Note: The context typically includes about 50 characters before and after
        ///   the match, depending on the content structure.
        public let context: String?

        /// Creates a new search result
        ///
        /// - Parameters:
        ///   - matchType: The type of search that found this result
        ///   - path: The file path where the match was found
        ///   - relevanceScore: Relevance score from 0.0 to 1.0
        ///   - matchedTerms: The search terms that matched
        ///   - context: Surrounding context for content matches (nil for file matches)
        ///
        /// - Returns: A configured SearchResult instance
        public init(matchType: SearchType, path: String, relevanceScore: Double, matchedTerms: [String], context: String? = nil) {
            self.matchType = matchType
            self.path = path
            self.relevanceScore = relevanceScore
            self.matchedTerms = matchedTerms
            self.context = context
        }
    }

    private let searchEngine: SearchEngine

    /// Initialize with default search engine
    ///
    /// Creates a new SearchMind instance with the default search engine implementation.
    /// This is the recommended initializer for most use cases.
    ///
    /// ```swift
    /// let searchMind = SearchMind()
    /// ```
    public init() {
        searchEngine = DefaultSearchEngine()
    }

    /// Initialize with custom search engine
    ///
    /// Creates a new SearchMind instance with a custom search engine implementation.
    /// This is useful for testing or when you need to customize the search behavior
    /// beyond what the standard options provide.
    ///
    /// - Parameter searchEngine: A custom implementation of the SearchEngine protocol
    ///
    /// ```swift
    /// let customEngine = MyCustomSearchEngine()
    /// let searchMind = SearchMind(searchEngine: customEngine)
    /// ```
    public init(searchEngine: SearchEngine) {
        self.searchEngine = searchEngine
    }

    /// Searches for a single term
    ///
    /// Performs a search operation for a single term using the specified search type and options.
    /// Results are sorted by relevance score (highest first).
    ///
    /// - Parameters:
    ///   - term: The term to search for
    ///   - type: The type of search to perform (default: `.file`)
    ///   - options: Additional search options (default: standard options)
    ///
    /// - Returns: Array of search results sorted by relevance
    ///
    /// - Throws: `SearchError.emptySearchTerm` if the term is empty
    /// - Throws: `SearchError.invalidSearchPath` if a provided search path doesn't exist
    /// - Throws: `SearchError.searchTimeout` if the search exceeds the specified timeout
    /// - Throws: `SearchError.fileAccessDenied` if a file can't be accessed
    /// - Throws: Other errors if file operations fail
    ///
    /// - Example: Simple file name search
    /// ```swift
    /// let results = try await searchMind.search("model", type: .file)
    /// ```
    ///
    /// - Example: Content search with options
    /// ```swift
    /// let options = SearchOptions(
    ///     fileExtensions: ["swift"],
    ///     timeout: 2.0
    /// )
    /// let results = try await searchMind.search("protocol", type: .fileContents, options: options)
    /// ```
    public func search(_ term: String, type: SearchType = .file, options: SearchOptions = SearchOptions()) async throws -> [SearchResult] {
        // Validate search term
        guard !term.isEmpty else {
            throw SearchError.emptySearchTerm
        }
        // Perform search with validated inputs
        return try await searchEngine.search(term: term, type: type, options: options)
    }

    /// Searches for multiple terms concurrently
    ///
    /// Performs parallel search operations for multiple terms, improving performance
    /// when you need to search for several terms at once. Each search uses the same
    /// search type and options.
    ///
    /// This method leverages Swift's structured concurrency to run searches in parallel
    /// and collect the results efficiently.
    ///
    /// - Parameters:
    ///   - terms: Array of search terms to look for
    ///   - type: The type of search to perform (default: `.file`)
    ///   - options: Additional search options (default: standard options)
    ///
    /// - Returns: Dictionary mapping search terms to their respective result arrays
    ///
    /// - Throws: `SearchError.emptySearchTerm` if any term is empty
    /// - Throws: `SearchError.invalidSearchPath` if a provided search path doesn't exist
    /// - Throws: `SearchError.searchTimeout` if the search exceeds the specified timeout
    /// - Throws: `SearchError.fileAccessDenied` if a file can't be accessed
    /// - Throws: Other errors if file operations fail
    ///
    /// - Example: Searching for multiple terms
    /// ```swift
    /// let terms = ["class", "struct", "enum"]
    /// let resultsByTerm = try await searchMind.multiSearch(terms: terms, type: .fileContents)
    ///
    /// // Check how many results were found for each term
    /// for (term, results) in resultsByTerm {
    ///     print("\(term): \(results.count) results")
    /// }
    /// ```
    public func multiSearch(terms: [String], type: SearchType = .file, options: SearchOptions = SearchOptions()) async throws -> [String: [SearchResult]] {
        guard !terms.isEmpty else {
            return [:]
        }

        // Execute searches concurrently and collect results
        var results = [String: [SearchResult]]()

        // Copy search engine to local constant to avoid capturing self
        let engine = searchEngine

        // Using async let for concurrent execution
        try await withThrowingTaskGroup(of: (String, [SearchResult]).self) { group in
            for term in terms {
                let termCopy = term // Capture the term locally
                let typeCopy = type
                let optionsCopy = options

                group.addTask {
                    // Directly call engine's search method
                    let searchResults = try await engine.search(term: termCopy, type: typeCopy, options: optionsCopy)
                    return (termCopy, searchResults)
                }
            }

            // Collect results as they complete
            for try await (term, searchResults) in group {
                results[term] = searchResults
            }
        }

        return results
    }
}

/// Type of search to perform
///
/// SearchType determines how the search operation will locate matches.
/// Different search types are optimized for specific scenarios and use
/// different matching algorithms internally.
///
/// - Note: The search engine automatically selects the most appropriate algorithm
///   based on the chosen search type and options.
public enum SearchType: String, CaseIterable, Sendable {
    /// Searches for matches in file names and paths
    ///
    /// This search type looks for matches in file names only, not their contents.
    /// It's significantly faster than content searches and is ideal for locating
    /// files when you know part of their name.
    ///
    /// - Note: When used with `fuzzyMatching: true` in `SearchOptions`, this will
    ///   find approximate matches using Levenshtein distance.
    ///
    /// ```swift
    /// // Find all .swift files with "model" in their name
    /// let options = SearchOptions(fileExtensions: ["swift"])
    /// let results = try await searchMind.search("model", type: .file, options: options)
    /// ```
    case file

    /// Searches for matches within file contents
    ///
    /// This search type performs a full-text search inside files to find matches.
    /// It's more resource-intensive than file name searches but allows finding
    /// content regardless of the file name.
    ///
    /// - Important: Content searches read all matching files into memory, so use
    ///   appropriate file extension filtering to limit the search scope for better performance.
    ///
    /// ```swift
    /// // Find Swift files containing "protocol" in their contents
    /// let options = SearchOptions(fileExtensions: ["swift"])
    /// let results = try await searchMind.search("protocol", type: .fileContents, options: options)
    ///
    /// // Use the context property to see match surroundings
    /// for result in results {
    ///     print("Match in \(result.path):")
    ///     if let context = result.context {
    ///         print(context)
    ///     }
    /// }
    /// ```
    case fileContents

    /// Searches for matches in connected databases
    ///
    /// This search type performs a query on the connected database rather than the local filesystem.
    /// It is useful when your search source is remote or dynamically loaded, such as a Firebase Firestore,
    /// Realtime Database, Core Data, or SQL-based system.
    /// - Warning: This method currently supports firebase realtime databases at the moment. Other database types
    ///   like CoreData, SQLDatabases, Firestore and etc will be supoorted later.
    ///
    /// - Important: Make sure the database is properly initialized and configured before using this search type.
    ///   The behavior and performance of the query will vary based on the database type, schema structure, and indexing.
    ///
    /// - Note: When combined with `fuzzyMatching: true` in `SearchOptions`, results will be ranked using
    ///   approximate string matching logic if supported by the underlying database adapter.
    ///
    /// ```swift
    /// // Search a Firebase Firestore database for documents matching "swift"
    /// let options = SearchOptions(databaseType: .firestore, fuzzyMatching: true)
    /// let results = try await searchMind.search("swift", type: .database, options: options)
    ///
    /// for result in results {
    ///     print("Match in database document: \(result.path)")
    ///     if let metadata = result.metadata {
    ///         print("Metadata: \(metadata)")
    ///     }
    /// }
    /// ```
    case database
}

/// Options for configuring search behavior
///
/// SearchOptions provides detailed control over how search operations work, allowing
/// customization of matching behavior, search scope, and performance characteristics.
///
/// - Example: Basic search with default options
/// ```swift
/// // Uses default options (case-insensitive, fuzzy matching)
/// let results = try await searchMind.search("view", type: .file)
/// ```
///
/// - Example: Customized search with specific options
/// ```swift
/// // Specific search with custom options
/// let options = SearchOptions(
///     caseSensitive: true,
///     fuzzyMatching: false,
///     maxResults: 50,
///     searchPaths: [projectDirectory],
///     fileExtensions: ["swift", "md"],
///     timeout: 5.0
/// )
/// let results = try await searchMind.search("ViewModel", type: .file, options: options)
/// ```
public struct SearchOptions: Sendable {
    /// Determines whether searches are case-sensitive
    ///
    /// When `true`, the search will match the exact case of the search term.
    /// When `false` (default), the search is case-insensitive.
    ///
    /// - Example:
    /// ```swift
    /// // Case-sensitive search will match "ViewModel" but not "viewmodel"
    /// let options = SearchOptions(caseSensitive: true)
    /// ```
    public let caseSensitive: Bool

    /// A required API key for enabling AI-powered search algorithms, such as GPT-based semantic search.
    ///
    /// This key must be provided when using any search strategy that relies on external AI services.
    /// If the key is missing and an AI-based algorithm is selected (e.g., `GPTSemanticSearchAlgorithm`),
    /// an error will be thrown or the search will fail.
    ///
    /// - Important: This is mandatory for semantic searches. Omitting it while using AI algorithms
    /// will result in runtime errors or degraded functionality.
    ///
    /// - Example:
    /// ```swift
    /// let options = SearchOptions(apiKey: "sk-...")
    /// ```
    public let apiKey: String?

    /// Enables approximate (fuzzy) matching for file name searches
    ///
    /// When `true` (default), file name searches will use Levenshtein distance
    /// to find approximate matches, which is helpful for handling typos or
    /// slight variations.
    ///
    /// When `false`, only exact substring matches will be returned.
    ///
    /// - Note: This option only affects `.file` searches, not `.fileContents` searches.
    /// - Important: Fuzzy matching may be slower for large directory structures.
    public let fuzzyMatching: Bool

    /// Enables semantic search using a large language model.
    ///
    /// When `true`, `.fileContents` searches will be powered by GPT-based embeddings
    /// that understand the **meaning** of the query and the content, rather than just
    /// relying on exact or fuzzy text matches.
    ///
    /// This allows users to find relevant results based on intent and context. For example,
    /// searching for `"authentication"` might match content discussing `"login systems"`
    /// or `"OAuth flows"`, even if those exact words don’t appear in the text.
    ///
    /// - Important: Requires a valid OpenAI API key and network access.
    /// - Note: This option only affects `.fileContents` searches.
    /// - SeeAlso: `patternMatch` for syntax-based searching, and `fuzzyMatching` for typo tolerance.
    public let semantic: Bool

    /// Enables pattern-based search using regular expressions.
    ///
    /// When `true`, `.fileContents` searches will interpret the query as a
    /// regular expression pattern (e.g., `"\bclass\b"`).
    ///
    /// This is useful for advanced filtering based on syntax or naming conventions.
    ///
    /// - Note: This option only affects `.fileContents` searches.
    /// - Warning: Malformed regex patterns may cause errors or performance issues.
    public let patternMatch: Bool

    /// The maximum number of results to return from a search
    ///
    /// Limits the number of results returned from a search operation.
    /// This can improve performance when searching large directories.
    /// The default is 100.
    ///
    /// Results are sorted by relevance score before being limited, so the
    /// most relevant matches are always included.
    public let maxResults: Int

    /// Specifies the directories or files to search
    ///
    /// When provided, the search will only look in these locations.
    /// When `nil` (default), the search will use the current working directory.
    ///
    /// - Note: If a URL points to a file, only that file will be searched.
    ///   If it points to a directory, all supported files in that directory will be searched.
    public let searchPaths: [String]?

    /// Limits the search to files with specific extensions
    ///
    /// When provided, only files with these extensions will be included in the search.
    /// Extensions should not include the dot (e.g., use "swift" not ".swift").
    ///
    /// When `nil` (default), files of all types will be searched.
    ///
    /// - Example:
    /// ```swift
    /// // Only search Swift and Markdown files
    /// let options = SearchOptions(fileExtensions: ["swift", "md"])
    /// ```
    public let fileExtensions: [String]?

    /// Specifies a maximum duration for the search operation
    ///
    /// When provided, the search will be cancelled if it takes longer than
    /// this number of seconds. This is useful for searches in large directory
    /// structures or when searching file contents.
    ///
    /// When `nil` (default), the search will continue until completion.
    ///
    /// - Note: If a timeout occurs, a `SearchError.searchTimeout` error will be thrown.
    public let timeout: TimeInterval?

    /// Creates a new search options configuration
    ///
    /// - Parameters:
    ///   - caseSensitive: Whether the search is case-sensitive (default: `false`)
    ///   - fuzzyMatching: Whether to use fuzzy matching for file name searches (default: `true`)
    ///   - maxResults: Maximum number of results to return (default: `100`)
    ///   - searchPaths: Specific paths to search (default: current directory)
    ///   - fileExtensions: File extensions to include (default: all files)
    ///   - timeout: Maximum search duration in seconds (default: no timeout)
    ///
    /// - Returns: A configured SearchOptions instance
    public init(
        caseSensitive: Bool = false,
        apiKey: String? = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
        fuzzyMatching: Bool = true,
        semantic: Bool = false,
        patternMatch: Bool = false,
        maxResults: Int = 100,
        searchPaths: [String]? = nil,
        fileExtensions: [String]? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.caseSensitive = caseSensitive
        self.apiKey = apiKey
        self.fuzzyMatching = fuzzyMatching
        self.semantic = semantic
        self.patternMatch = patternMatch
        self.maxResults = max(1, maxResults) // Ensure maxResults is at least 1
        self.searchPaths = searchPaths
        self.fileExtensions = fileExtensions
        self.timeout = timeout
    }
}
