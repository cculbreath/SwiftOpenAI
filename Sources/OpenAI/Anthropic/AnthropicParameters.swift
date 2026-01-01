//
//  AnthropicParameters.swift
//  SwiftOpenAI
//
//  Request and response parameter types for the Anthropic Messages API.
//

import Foundation

// MARK: - AnthropicMessageParameter

/// Parameters for creating a message via the Anthropic Messages API.
public struct AnthropicMessageParameter: Encodable {
  /// The model to use (e.g., "claude-sonnet-4-20250514")
  public let model: String

  /// The messages in the conversation
  public let messages: [AnthropicMessage]

  /// System prompt (replaces OpenAI's "developer" role)
  public let system: AnthropicSystemContent?

  /// Maximum tokens to generate
  public let maxTokens: Int

  /// Whether to stream the response
  public let stream: Bool

  /// Tools available for the model to use
  public let tools: [AnthropicTool]?

  /// How the model should choose tools
  public let toolChoice: AnthropicToolChoice?

  /// Temperature for sampling (0.0 to 1.0)
  public let temperature: Double?

  /// Top-p sampling parameter
  public let topP: Double?

  /// Top-k sampling parameter
  public let topK: Int?

  /// Stop sequences
  public let stopSequences: [String]?

  /// Metadata for the request
  public let metadata: AnthropicMetadata?

  public init(
    model: String,
    messages: [AnthropicMessage],
    system: AnthropicSystemContent? = nil,
    maxTokens: Int = 4096,
    stream: Bool = true,
    tools: [AnthropicTool]? = nil,
    toolChoice: AnthropicToolChoice? = nil,
    temperature: Double? = nil,
    topP: Double? = nil,
    topK: Int? = nil,
    stopSequences: [String]? = nil,
    metadata: AnthropicMetadata? = nil
  ) {
    self.model = model
    self.messages = messages
    self.system = system
    self.maxTokens = maxTokens
    self.stream = stream
    self.tools = tools
    self.toolChoice = toolChoice
    self.temperature = temperature
    self.topP = topP
    self.topK = topK
    self.stopSequences = stopSequences
    self.metadata = metadata
  }

  enum CodingKeys: String, CodingKey {
    case model
    case messages
    case system
    case maxTokens = "max_tokens"
    case stream
    case tools
    case toolChoice = "tool_choice"
    case temperature
    case topP = "top_p"
    case topK = "top_k"
    case stopSequences = "stop_sequences"
    case metadata
  }
}

// MARK: - AnthropicSystemContent

/// System content can be a simple string or an array of content blocks with cache control
public enum AnthropicSystemContent: Encodable {
  case text(String)
  case blocks([AnthropicSystemBlock])

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .text(let text):
      try container.encode(text)
    case .blocks(let blocks):
      try container.encode(blocks)
    }
  }
}

/// A system content block with optional cache control
public struct AnthropicSystemBlock: Encodable {
  public let type: String
  public let text: String
  public let cacheControl: AnthropicCacheControl?

  public init(text: String, cacheControl: AnthropicCacheControl? = nil) {
    self.type = "text"
    self.text = text
    self.cacheControl = cacheControl
  }

  enum CodingKeys: String, CodingKey {
    case type
    case text
    case cacheControl = "cache_control"
  }
}

/// Cache control directive for prompt caching
public struct AnthropicCacheControl: Encodable {
  public let type: String

  public init(type: String = "ephemeral") {
    self.type = type
  }

  public static let ephemeral = AnthropicCacheControl(type: "ephemeral")
}

// MARK: - AnthropicMessage

/// A message in the Anthropic conversation format.
public struct AnthropicMessage: Codable {
  /// The role: "user" or "assistant"
  public let role: String

  /// The content of the message
  public let content: AnthropicContent

  public init(role: String, content: AnthropicContent) {
    self.role = role
    self.content = content
  }

  /// Convenience initializer for text-only messages
  public static func user(_ text: String) -> AnthropicMessage {
    AnthropicMessage(role: "user", content: .text(text))
  }

  public static func assistant(_ text: String) -> AnthropicMessage {
    AnthropicMessage(role: "assistant", content: .text(text))
  }

  /// Create a user message with tool result
  public static func toolResult(toolUseId: String, content: String, isError: Bool = false) -> AnthropicMessage {
    AnthropicMessage(
      role: "user",
      content: .blocks([
        .toolResult(AnthropicToolResultBlock(
          toolUseId: toolUseId,
          content: content,
          isError: isError
        ))
      ])
    )
  }

  /// Create an assistant message with tool use
  public static func toolUse(id: String, name: String, input: [String: Any]) -> AnthropicMessage {
    AnthropicMessage(
      role: "assistant",
      content: .blocks([
        .toolUse(AnthropicToolUseBlock(id: id, name: name, input: input))
      ])
    )
  }
}

// MARK: - AnthropicContent

/// Content can be a simple string or an array of content blocks.
public enum AnthropicContent: Codable {
  case text(String)
  case blocks([AnthropicContentBlock])

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .text(let text):
      try container.encode(text)
    case .blocks(let blocks):
      try container.encode(blocks)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let text = try? container.decode(String.self) {
      self = .text(text)
    } else if let blocks = try? container.decode([AnthropicContentBlock].self) {
      self = .blocks(blocks)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Content must be a string or array of content blocks"
      )
    }
  }
}

// MARK: - AnthropicContentBlock

/// A content block in a message.
public enum AnthropicContentBlock: Codable {
  case text(AnthropicTextBlock)
  case image(AnthropicImageBlock)
  case toolUse(AnthropicToolUseBlock)
  case toolResult(AnthropicToolResultBlock)

  private enum CodingKeys: String, CodingKey {
    case type
  }

  public func encode(to encoder: Encoder) throws {
    switch self {
    case .text(let block):
      try block.encode(to: encoder)
    case .image(let block):
      try block.encode(to: encoder)
    case .toolUse(let block):
      try block.encode(to: encoder)
    case .toolResult(let block):
      try block.encode(to: encoder)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "text":
      self = .text(try AnthropicTextBlock(from: decoder))
    case "image":
      self = .image(try AnthropicImageBlock(from: decoder))
    case "tool_use":
      self = .toolUse(try AnthropicToolUseBlock(from: decoder))
    case "tool_result":
      self = .toolResult(try AnthropicToolResultBlock(from: decoder))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type, in: container,
        debugDescription: "Unknown content block type: \(type)"
      )
    }
  }
}

// MARK: - Content Block Types

public struct AnthropicTextBlock: Codable {
  public let type: String
  public let text: String

  public init(text: String) {
    self.type = "text"
    self.text = text
  }
}

public struct AnthropicImageBlock: Codable {
  public let type: String
  public let source: AnthropicImageSource

  public init(source: AnthropicImageSource) {
    self.type = "image"
    self.source = source
  }
}

public struct AnthropicImageSource: Codable {
  public let type: String
  public let mediaType: String
  public let data: String

  public init(mediaType: String, data: String) {
    self.type = "base64"
    self.mediaType = mediaType
    self.data = data
  }

  enum CodingKeys: String, CodingKey {
    case type
    case mediaType = "media_type"
    case data
  }
}

public struct AnthropicToolUseBlock: Codable {
  public let type: String
  public let id: String
  public let name: String
  public let input: [String: AnthropicDynamicValue]

  public init(id: String, name: String, input: [String: Any]) {
    self.type = "tool_use"
    self.id = id
    self.name = name
    self.input = input.mapValues { AnthropicDynamicValue($0) }
  }

  enum CodingKeys: String, CodingKey {
    case type
    case id
    case name
    case input
  }
}

public struct AnthropicToolResultBlock: Codable {
  public let type: String
  public let toolUseId: String
  public let content: String
  public let isError: Bool?

  public init(toolUseId: String, content: String, isError: Bool = false) {
    self.type = "tool_result"
    self.toolUseId = toolUseId
    self.content = content
    self.isError = isError ? true : nil
  }

  enum CodingKeys: String, CodingKey {
    case type
    case toolUseId = "tool_use_id"
    case content
    case isError = "is_error"
  }
}

// MARK: - AnthropicTool

/// Tool definition for function calling or server-side tools.
public enum AnthropicTool: Encodable {
  case function(AnthropicFunctionTool)
  case serverTool(AnthropicServerTool)

  public func encode(to encoder: Encoder) throws {
    switch self {
    case .function(let tool):
      try tool.encode(to: encoder)
    case .serverTool(let tool):
      try tool.encode(to: encoder)
    }
  }
}

/// A function tool definition (custom tool).
public struct AnthropicFunctionTool: Encodable {
  public let name: String
  public let description: String?
  public let inputSchema: [String: AnthropicDynamicValue]

  public init(name: String, description: String? = nil, inputSchema: [String: Any]) {
    self.name = name
    self.description = description
    self.inputSchema = inputSchema.mapValues { AnthropicDynamicValue($0) }
  }

  enum CodingKeys: String, CodingKey {
    case name
    case description
    case inputSchema = "input_schema"
  }
}

/// Server-side tools provided by Anthropic.
public struct AnthropicServerTool: Encodable {
  public let type: String
  public let name: String?
  public let maxUses: Int?

  public init(type: String, name: String? = nil, maxUses: Int? = nil) {
    self.type = type
    self.name = name
    self.maxUses = maxUses
  }

  /// Web search tool
  public static func webSearch(name: String = "web_search", maxUses: Int? = 5) -> AnthropicServerTool {
    AnthropicServerTool(type: "web_search_20250305", name: name, maxUses: maxUses)
  }

  /// Web fetch tool (requires beta header)
  public static func webFetch(name: String = "web_fetch", maxUses: Int? = nil) -> AnthropicServerTool {
    AnthropicServerTool(type: "web_fetch_20250910", name: name, maxUses: maxUses)
  }

  enum CodingKeys: String, CodingKey {
    case type
    case name
    case maxUses = "max_uses"
  }
}

// MARK: - AnthropicToolChoice

/// How the model should choose tools.
public enum AnthropicToolChoice: Encodable, Equatable {
  case auto
  case any
  case none
  case tool(name: String)

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .auto:
      try container.encode(["type": "auto"])
    case .any:
      try container.encode(["type": "any"])
    case .none:
      try container.encode(["type": "none"])
    case .tool(let name):
      try container.encode(["type": "tool", "name": name])
    }
  }
}

// MARK: - AnthropicMetadata

/// Request metadata.
public struct AnthropicMetadata: Encodable {
  public let userId: String?

  public init(userId: String? = nil) {
    self.userId = userId
  }

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
  }
}

// MARK: - AnthropicMessageResponse

/// Non-streaming response from the Messages API.
public struct AnthropicMessageResponse: Decodable {
  public let id: String
  public let type: String
  public let role: String
  public let content: [AnthropicResponseContentBlock]
  public let model: String
  public let stopReason: String?
  public let stopSequence: String?
  public let usage: AnthropicUsage

  enum CodingKeys: String, CodingKey {
    case id
    case type
    case role
    case content
    case model
    case stopReason = "stop_reason"
    case stopSequence = "stop_sequence"
    case usage
  }
}

// MARK: - AnthropicResponseContentBlock

/// Content block in a response.
public enum AnthropicResponseContentBlock: Decodable {
  case text(AnthropicTextBlock)
  case toolUse(AnthropicToolUseResponseBlock)

  private enum CodingKeys: String, CodingKey {
    case type
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "text":
      self = .text(try AnthropicTextBlock(from: decoder))
    case "tool_use":
      self = .toolUse(try AnthropicToolUseResponseBlock(from: decoder))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type, in: container,
        debugDescription: "Unknown response content block type: \(type)"
      )
    }
  }
}

/// Tool use block in response (with raw JSON input).
public struct AnthropicToolUseResponseBlock: Decodable {
  public let type: String
  public let id: String
  public let name: String
  public let input: [String: AnthropicDynamicValue]
}

// MARK: - AnthropicUsage

/// Token usage information.
public struct AnthropicUsage: Decodable {
  public let inputTokens: Int
  public let outputTokens: Int
  public let cacheCreationInputTokens: Int?
  public let cacheReadInputTokens: Int?

  enum CodingKeys: String, CodingKey {
    case inputTokens = "input_tokens"
    case outputTokens = "output_tokens"
    case cacheCreationInputTokens = "cache_creation_input_tokens"
    case cacheReadInputTokens = "cache_read_input_tokens"
  }
}

// MARK: - AnthropicModelsResponse

/// Response from the models list endpoint.
public struct AnthropicModelsResponse: Decodable {
  public let data: [AnthropicModel]
  public let firstId: String?
  public let hasMore: Bool
  public let lastId: String?

  enum CodingKeys: String, CodingKey {
    case data
    case firstId = "first_id"
    case hasMore = "has_more"
    case lastId = "last_id"
  }
}

/// An Anthropic model.
public struct AnthropicModel: Decodable, Identifiable {
  public let id: String
  public let createdAt: String?
  public let displayName: String
  public let type: String

  enum CodingKeys: String, CodingKey {
    case id
    case createdAt = "created_at"
    case displayName = "display_name"
    case type
  }
}

// MARK: - AnthropicDynamicValue

/// Type-erased Codable wrapper for dynamic JSON values.
/// Named to avoid collision with other AnyCodable types in the module.
public struct AnthropicDynamicValue: Codable {
  public let value: Any

  public init(_ value: Any) {
    self.value = value
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if container.decodeNil() {
      self.value = NSNull()
    } else if let bool = try? container.decode(Bool.self) {
      self.value = bool
    } else if let int = try? container.decode(Int.self) {
      self.value = int
    } else if let double = try? container.decode(Double.self) {
      self.value = double
    } else if let string = try? container.decode(String.self) {
      self.value = string
    } else if let array = try? container.decode([AnthropicDynamicValue].self) {
      self.value = array.map { $0.value }
    } else if let dict = try? container.decode([String: AnthropicDynamicValue].self) {
      self.value = dict.mapValues { $0.value }
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unable to decode AnthropicDynamicValue"
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch value {
    case is NSNull:
      try container.encodeNil()
    case let bool as Bool:
      try container.encode(bool)
    case let int as Int:
      try container.encode(int)
    case let double as Double:
      try container.encode(double)
    case let string as String:
      try container.encode(string)
    case let array as [Any]:
      try container.encode(array.map { AnthropicDynamicValue($0) })
    case let dict as [String: Any]:
      try container.encode(dict.mapValues { AnthropicDynamicValue($0) })
    default:
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: container.codingPath,
          debugDescription: "Unable to encode AnthropicDynamicValue"
        )
      )
    }
  }
}
