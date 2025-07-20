<h1 align="center">SearchMind</h1>

<p align="center">
  <strong>An Intelligent AI-Powered Search Engine Framework for Swift</strong>
</p>

<p align="center">
  In today’s digital world, data grows faster than our ability to organize or find it. Files multiply, databases expand, and meaningful information hides under layers of noise.
</p>

> “The biggest challenge is not having data, but having access to the right data at the right time.” — Bernard Marr

<p align="center">
  SearchMind is a Swift package designed as an intelligent, adaptable search engine that goes beyond simple keyword matching. It understands context, adapts algorithms dynamically, and seamlessly works with both local files and remote data sources.
</p>

<p align="center">
  Imagine embedding a search engine in your app that doesn’t just look for exact matches but interprets your intent — whether it’s in a text document, a piece of code, or structured data in a database.
</p>

> “Search isn’t just about matching strings. It’s about finding meaning in complexity.” — Kathy Baxter (Google UX researcher)

<p align="center">
  SearchMind is built to deliver insight by unifying diverse search strategies — exact, fuzzy, semantic, and pattern matching — behind a modular, extensible interface.
</p>

## What SearchMind Is

SearchMind isn’t a simple search box — it’s a toolkit for building <strong>intelligent search experiences</strong>:

- A framework that abstracts data providers — local file systems, database connections, or custom sources — behind a consistent interface.
- A system that dynamically picks the best search algorithm based on data type and user needs.
- Support for <code>.database</code> providers, enabling seamless search over structured and unstructured remote data.
- Integration with AI-powered semantic search using embeddings to find meaning beyond text.

> “In a world drowning in data, effective search is the lifeline to knowledge.” — Hilary Mason

## Who Benefits

- Developers building apps with complex data needs, from notes apps to code analysis tools.
- Teams unifying search across multiple data sources without rewriting logic.
- Software projects requiring flexible, extensible, and testable search capabilities.
- Anyone who values fast, accurate, and context-aware search functionality in Swift.

## Why It’s Important

> “Without effective search, data is just noise.” — Niels Provos (Google Security Engineer)

> “The ability to find relevant information quickly is the foundation of productivity.” — Satya Nadella

SearchMind addresses the fundamental problem of **searching smarter, not harder**.

By decoupling algorithms from data structures and supporting multiple search modes, it removes the friction developers face when integrating powerful search features.

> “Great search is the difference between data overwhelm and actionable insight.” — Jeff Hammerbacher (Data Scientist)

SearchMind brings that kind of amplification to your Swift projects — an intelligent engine that adapts and evolves with your data and search needs, helping users find exactly what matters.

## Table of Contents
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Architecture](#architecture)
- [Project Vision](#project-vision)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Features
- Search for filenames, file contents, or Firebase Realtime Database entries
- Fuzzy, pattern, exact, and semantic search algorithm support
- Configurable search options (case sensitivity, max results, timeout, etc.)
- File extension and path filtering
- Fully concurrent and asynchronous architecture
- Dynamic provider architecture (.file, .fileContents, .database)
- Structured metadata generation per source
- Test matrix covering all algorithm/provider combinations
- Command Line Interface using Swift Argument Parser
- AI-Powered Search capabilities
- File Preview and Quick Actions
- Configurable Indexing

---

## Installation

### Swift Package Manager
Add the following to your `Package.swift` file:
```swift
dependencies: [
    .package(url: "https://github.com/your-repo/SearchMind.git", from: "1.0.0")
]
```

---

## Usage

### Basic Search
```swift
import SearchMind

let searchMind = SearchMind()

let results = try await searchMind.search("document", type: .file)

for result in results {
    print("Found: \(result.path) (Score: \(result.relevanceScore))")
}
```

### Advanced Search Options
```swift
let options = SearchOptions(
    caseSensitive: false,
    fuzzyMatching: true,
    maxResults: 50,
    searchPaths: ["/path/to/search"],
    fileExtensions: ["swift", "md"],
    timeout: 5.0
)

let results = try await searchMind.search("protocol", type: .fileContents, options: options)
```

### Firebase Database Search
```swift
let options = SearchOptions(
    searchPaths: ["users/posts"]
)

let results = try await searchMind.search("introduction", type: .database, options: options)
```

### Multi-term Search
```swift
let terms = ["class", "struct", "enum"]
let resultsByTerm = try await searchMind.multiSearch(terms: terms, type: .fileContents)

for (term, results) in resultsByTerm {
    print("Results for '\(term)'):")
    for result in results {
        print("  - \(result.path) (Score: \(result.relevanceScore))")
    }
}
```

### Command Line Usage (Concept)
```bash
$ searchmind help
Available commands:
  find      Search for files by name, keywords, or AI-inferred context
  index     Manually re-index specific directories
  config    Update or view indexing configurations
  version   Display the current version of SearchMind

$ searchmind find "tax documents 2020"
Found 2 results:
 1. /Users/username/Documents/Taxes/2020/Taxes-2020-Final.pdf
 2. /Users/username/Documents/Taxes/2020/Receipt-2020.jpg
```

---

## Architecture
SearchMind uses a strategy pattern and modular provider-based design:

### Algorithms
- **ExactMatchAlgorithm**: For literal matches
- **FuzzyMatchAlgorithm**: For approximate and misspelled queries
- **PatternMatchAlgorithm**: For regular expression-like pattern detection
- **GPTSemanticAlgorithm**: Embedding-based vector search (AI-powered)

### Providers
- **FileProvider**: Indexes file names only
- **FileContentsProvider**: Indexes the contents of text-based files
- **RealtimeDatabaseProvider**: Reads Firebase Realtime Database nodes

### Utilities
- `createMetadata(data:path:providerType:)`: Standardized metadata creation
- `extractText(from:)`: Generic data extraction across varying dictionary shapes

## Project Vision
SearchMind aims to be the go-to AI-powered search utility for macOS:

### Key Goals
- Cross-source search (files, cloud databases, etc.)
- Algorithm-agnostic engine with extensible input/output pipelines
- Fast CLI and future GUI integrations
- Accurate, AI-enhanced ranking of search results

## Roadmap
1. **Initial Architecture & Setup**
2. **File Search with CLI Support**
3. **Semantic Search & Embedding Pipelines**
4. **Database Search Support (✅)**
5. **Multi-source Merging + Relevance Tuning**
6. **GUI Layer for Spotlight-style Search Experience**

## Contributing
We’d love your input! You can:
- Propose features or improvements
- Fix bugs and submit PRs
- Help expand testing or add more providers (e.g. Firestore, iCloud, REST APIs)


## License
MIT
