import Foundation

/// Errors that can occur during search operations
///
/// SearchError defines the specific errors that can occur when using the
/// SearchMind library. Each error case provides context-specific information
/// to help diagnose and handle issues.
///
/// This enum conforms to Swift's `Error` and `LocalizedError` protocols for
/// standard error handling, and `Sendable` for thread safety.
///
/// - Example: Error handling
/// ```swift
/// do {
///     let results = try await searchMind.search("protocol", type: .fileContents)
///     // Process results
/// } catch SearchError.invalidSearchPath(let path) {
///     print("The path does not exist: \(path)")
/// } catch SearchError.searchTimeout {
///     print("Search timed out, try narrowing your search")
/// } catch {
///     print("Error: \(error.localizedDescription)")
/// }
/// ```
public enum SearchError: Error, LocalizedError, Sendable {
    /// The specified search path does not exist
    ///
    /// This error occurs when a search path provided in `SearchOptions.searchPaths`
    /// does not exist or is not accessible.
    ///
    /// The associated value contains the path that was not found.
    case invalidSearchPath(String)
    
    /// Permission denied when trying to access a file
    ///
    /// This error occurs when the search operation cannot read a file due to
    /// permission restrictions.
    ///
    /// The associated value contains the path to the file that could not be accessed.
    case fileAccessDenied(String)
    
    /// Search operation exceeded the specified timeout
    ///
    /// This error occurs when a search operation takes longer than the timeout
    /// specified in `SearchOptions.timeout`.
    ///
    /// This is particularly common for content searches in large directories.
    case searchTimeout
    
    /// Search term cannot be empty
    ///
    /// This error occurs when an empty string is provided as the search term.
    /// Search terms must contain at least one character.
    case emptySearchTerm
    
    /// An unexpected internal error occurred
    ///
    /// This error represents unexpected issues that may occur during search operations.
    ///
    /// The associated value contains a message with details about the error.
    case internalError(String)
    
    /// Human-readable description of the error
    ///
    /// This property is part of the `LocalizedError` protocol and provides
    /// user-friendly error messages suitable for displaying to users.
    public var errorDescription: String? {
        switch self {
        case .invalidSearchPath(let path):
            return "Invalid search path: \(path)"
        case .fileAccessDenied(let path):
            return "Access denied to file: \(path)"
        case .searchTimeout:
            return "Search operation timed out"
        case .emptySearchTerm:
            return "Search term cannot be empty"
        case .internalError(let message):
            return "Internal error: \(message)"
        }
    }
}