struct EmbeddingResponse: Codable {
    let object: String
    let data: [EmbeddingData]
    let model: String
    let usage: Usage
}

struct EmbeddingData: Codable {
    let object: String
    let index: Int
    let embedding: [Double]
}

struct Usage: Codable {
    let promptTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case totalTokens = "total_tokens"
    }
}
