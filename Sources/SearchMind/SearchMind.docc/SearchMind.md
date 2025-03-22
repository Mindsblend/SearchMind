# ``SearchMind``

A Swift package for efficient, flexible searching in files and file contents.

## Overview

SearchMind provides a simple yet powerful API for searching file names and contents. It automatically selects the most appropriate algorithm for each search scenario, optimizing for both accuracy and performance.

```swift
import SearchMind

// Create search instance
let searchMind = SearchMind()

// Search in file names
let fileResults = try await searchMind.search("model", type: .file)

// Search in file contents
let contentResults = try await searchMind.search("protocol", type: .fileContents)
```

## Topics

### Essentials

- ``SearchMind/SearchMind``
- ``SearchType``
- ``SearchOptions``
- ``SearchMind/SearchMind/SearchResult``
- ``SearchError``

### Basic Searching

- ``SearchMind/SearchMind/search(_:type:options:)``
- ``SearchMind/SearchMind/multiSearch(terms:type:options:)``

### Configuring Searches

- ``SearchOptions/caseSensitive``
- ``SearchOptions/fuzzyMatching``
- ``SearchOptions/maxResults``
- ``SearchOptions/searchPaths``
- ``SearchOptions/fileExtensions``
- ``SearchOptions/timeout``

### Error Handling

- ``SearchError/invalidSearchPath(_:)``
- ``SearchError/fileAccessDenied(_:)``
- ``SearchError/searchTimeout``
- ``SearchError/emptySearchTerm``
- ``SearchError/internalError(_:)``

## Advanced Usage

### Customizing Search with Options

SearchMind provides multiple configuration options to fine-tune your searches:

```swift
// Configure search options
let options = SearchOptions(
    caseSensitive: true,       // Match exact case
    fuzzyMatching: false,      // Only exact matches
    maxResults: 50,            // Limit to 50 results
    searchPaths: [projectDir], // Only search in project directory
    fileExtensions: ["swift"], // Only search Swift files
    timeout: 5.0               // Time out after 5 seconds
)

// Perform search with options
let results = try await searchMind.search("ViewModel", 
                                        type: .file, 
                                        options: options)
```

### Searching Multiple Terms Concurrently

For efficient searching of multiple terms:

```swift
// Define multiple search terms
let terms = ["class", "struct", "enum"]

// Search all terms concurrently
let resultsByTerm = try await searchMind.multiSearch(terms: terms,
                                                  type: .fileContents)

// Process results by term
for (term, results) in resultsByTerm {
    print("\(term): \(results.count) matches")
    
    for result in results {
        print("  - \(result.path)")
        if let context = result.context {
            print("    \(context)")
        }
    }
}
```

### Working with Search Results

Each search result contains detailed information:

```swift
for result in results {
    // Get basic info
    print("Match: \(result.path)")
    print("Type: \(result.matchType)")
    print("Relevance: \(result.relevanceScore)")
    
    // Get context for content matches
    if let context = result.context {
        print("Context: \(context)")
    }
}

// Sort results by path instead of relevance
let sortedByPath = results.sorted { 
    $0.path.localizedCompare($1.path) == .orderedAscending 
}
```