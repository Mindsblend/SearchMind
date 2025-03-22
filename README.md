# SearchMind
### A Swift package for efficient and flexible searching in files and file contents, using the best algorithm for each search scenario

SearchMind is a macOS utility that will help you find that elusive file you've been searching for—whether it's a selfie from a few years back or an important document with many versions floating around. Our goal is to streamline file discovery so you can spend less time combing through directories and more time getting things done.

---

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
- Search for filenames or file contents
- Fuzzy matching support for approximate searches
- Configurable search options (case sensitivity, max results, etc.)
- File extension filtering
- Concurrent search capabilities
- Timeout support for long-running searches
- Clear error handling
- Extensible architecture with swappable search algorithms
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

// Initialize the search engine
let searchMind = SearchMind()

// Simple file name search
let results = try await searchMind.search("document", type: .file)

// Print results
for result in results {
    print("Found: \(result.path) (Score: \(result.relevanceScore))")
}
```

### Advanced Search Options
```swift
// Configure search options
let options = SearchOptions(
    caseSensitive: false,
    fuzzyMatching: true,
    maxResults: 50,
    searchPaths: [URL(fileURLWithPath: "/path/to/search")],
    fileExtensions: ["swift", "md"],
    timeout: 5.0 // 5 second timeout
)

// Search with options
let results = try await searchMind.search("protocol", type: .fileContents, options: options)
```

### Multi-term Search
```swift
// Search for multiple terms concurrently
let terms = ["class", "struct", "enum"]
let resultsByTerm = try await searchMind.multiSearch(terms: terms, type: .fileContents)

// Process results
for (term, results) in resultsByTerm {
    print("Results for '\(term)':")
    for result in results {
        print("  - \(result.path) (Score: \(result.relevanceScore))")
        if let context = result.context {
            print("    Context: \(context)")
        }
    }
}
```

### Command Line Usage (Concept)
Here's an example of what CLI usage might look like:

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
SearchMind uses a strategy pattern to dynamically select the most appropriate search algorithm based on the search parameters:

- **ExactMatchAlgorithm**: Used for simple file name searches
- **FuzzyMatchAlgorithm**: Used for approximate file name searches
- **PatternMatchAlgorithm**: Used for file content searches

You can also implement custom search algorithms by conforming to the `SearchAlgorithm` protocol and initializing `SearchMind` with your custom engine.

The project is designed with a modular architecture where the core search engine is independent, allowing for integration with a GUI or other services in the future.

---

## Project Vision
We want **SearchMind** to leverage AI and advanced indexing to provide lightning-fast, accurate results to your file search queries. Instead of remembering cryptic folder structures or slogging through a Finder window, you'll be able to run a simple command and let SearchMind do the heavy lifting.

### Key Goals
- Intelligent indexing and search results
- Fast, command-line-based interactions using SwiftArgumentParser
- Minimal resource usage
- A user-friendly macOS integration, eventually with a GUI

---

## Roadmap
1. **Idea & Planning**
   - Outline architectural needs
   - Research AI/ML solutions for file search
2. **Proof of Concept**
   - Implement a simple command-line interface with Swift Argument Parser
   - Basic file indexing and search functionality
3. **Alpha Release**
   - Preliminary AI-driven search
   - Collaboration with contributors to refine indexing, search logic, and user experience
4. **Beta Release**
   - Feature enhancements, bug fixes, and performance optimization
5. **Stable v1.0**
   - Polished CLI/GUI (if applicable)
   - Comprehensive documentation and improved AI features

---

## Contributing
We'd love your help shaping the direction of **SearchMind**. Please consider:

- Opening feature requests and bug reports
- Submitting pull requests
- Suggesting improvements or documentation updates

Join us and help create a robust AI-powered search tool for macOS users!

---

## License
MIT

---

### Questions or Suggestions?
Feel free to open a discussion or issue in the repository! We'd love to have your feedback on how best to implement AI-driven search on macOS using Swift.