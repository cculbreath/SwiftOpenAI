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

  /// Output configuration: structured-output `format` and (optionally) `effort`.
  /// Structured outputs are GA as of Claude 4.6 — no beta header needed.
  /// The legacy top-level `output_format` field was deprecated; use `output_config.format` instead.
  public let outputConfig: AnthropicOutputConfig?

  /// Thinking configuration. When set, encodes the `thinking` request field
  /// (e.g. `{"type": "adaptive"}`). Omitted from the wire when nil.
  public let thinking: AnthropicThinking?

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
    metadata: AnthropicMetadata? = nil,
    outputConfig: AnthropicOutputConfig? = nil,
    thinking: AnthropicThinking? = nil
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
    self.outputConfig = outputConfig
    self.thinking = thinking
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
    case outputConfig = "output_config"
    case thinking
  }
}

// MARK: - AnthropicThinking

/// Thinking configuration for the `thinking` request field.
/// Modeled as an enum so additional variants can be added later.
public enum AnthropicThinking: Encodable {
  /// Adaptive thinking: the model decides when and how much to think.
  /// Encodes as `{"type": "adaptive"}`.
  case adaptive

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .adaptive:
      try container.encode("adaptive", forKey: .type)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case type
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
public struct AnthropicCacheControl: Codable {
  public let type: String

  /// Optional cache TTL ("5m" default when omitted, or "1h").
  public let ttl: String?

  public init(type: String = "ephemeral", ttl: String? = nil) {
    self.type = type
    self.ttl = ttl
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
  case document(AnthropicDocumentBlock)
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
    case .document(let block):
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
    case "document":
      self = .document(try AnthropicDocumentBlock(from: decoder))
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

public struct AnthropicImageBlock: Codable {
  public let type: String
  public let source: AnthropicImageSource
  public let cacheControl: AnthropicCacheControl?

  public init(source: AnthropicImageSource, cacheControl: AnthropicCacheControl? = nil) {
    self.type = "image"
    self.source = source
    self.cacheControl = cacheControl
  }

  enum CodingKeys: String, CodingKey {
    case type
    case source
    case cacheControl = "cache_control"
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

public struct AnthropicDocumentBlock: Codable {
  public let type: String
  public let source: AnthropicDocumentSource
  public let cacheControl: AnthropicCacheControl?

  public init(source: AnthropicDocumentSource, cacheControl: AnthropicCacheControl? = nil) {
    self.type = "document"
    self.source = source
    self.cacheControl = cacheControl
  }

  enum CodingKeys: String, CodingKey {
    case type
    case source
    case cacheControl = "cache_control"
  }
}

/// The source for a document content block.
///
/// Supports three wire shapes:
/// - `.base64` → `{"type": "base64", "media_type": ..., "data": ...}`
/// - `.url` → `{"type": "url", "url": ...}`
/// - `.file` → `{"type": "file", "file_id": ...}` — references a file uploaded via the
///   Files API (requires the `files-api-2025-04-14` beta header on the request).
public enum AnthropicDocumentSource: Codable {
  case base64(mediaType: String, data: String)
  case url(String)
  case file(id: String)

  /// Creates a base64 document source.
  public init(mediaType: String, data: String) {
    self = .base64(mediaType: mediaType, data: data)
  }

  private enum CodingKeys: String, CodingKey {
    case type
    case mediaType = "media_type"
    case data
    case url
    case fileId = "file_id"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "base64":
      self = .base64(
        mediaType: try container.decode(String.self, forKey: .mediaType),
        data: try container.decode(String.self, forKey: .data)
      )
    case "url":
      self = .url(try container.decode(String.self, forKey: .url))
    case "file":
      self = .file(id: try container.decode(String.self, forKey: .fileId))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type, in: container,
        debugDescription: "Unknown document source type: \(type)"
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .base64(let mediaType, let data):
      try container.encode("base64", forKey: .type)
      try container.encode(mediaType, forKey: .mediaType)
      try container.encode(data, forKey: .data)
    case .url(let url):
      try container.encode("url", forKey: .type)
      try container.encode(url, forKey: .url)
    case .file(let id):
      try container.encode("file", forKey: .type)
      try container.encode(id, forKey: .fileId)
    }
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
  public let cacheControl: AnthropicCacheControl?

  public init(
    toolUseId: String,
    content: String,
    isError: Bool = false,
    cacheControl: AnthropicCacheControl? = nil
  ) {
    self.type = "tool_result"
    self.toolUseId = toolUseId
    self.content = content
    self.isError = isError ? true : nil
    self.cacheControl = cacheControl
  }

  enum CodingKeys: String, CodingKey {
    case type
    case toolUseId = "tool_use_id"
    case content
    case isError = "is_error"
    case cacheControl = "cache_control"
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
  public let cacheControl: AnthropicCacheControl?
  /// Strict tool use (GA, no beta header). When `true`, Anthropic enforces the
  /// `input_schema` server-side so `tool_use.input` always validates. Requires a
  /// strict-compatible schema (every object `additionalProperties: false`, every
  /// property in `required`). Encoded only when non-nil, so non-strict tools keep
  /// byte-identical wire output (prompt-cache prefix unaffected).
  public let strict: Bool?

  public init(
    name: String,
    description: String? = nil,
    inputSchema: [String: Any],
    cacheControl: AnthropicCacheControl? = nil,
    strict: Bool? = nil
  ) {
    self.name = name
    self.description = description
    self.inputSchema = inputSchema.mapValues { AnthropicDynamicValue($0) }
    self.cacheControl = cacheControl
    self.strict = strict
  }

  enum CodingKeys: String, CodingKey {
    case name
    case description
    case inputSchema = "input_schema"
    case cacheControl = "cache_control"
    case strict
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

// MARK: - AnthropicOutputConfig

/// Output configuration block sent as the request's `output_config` field.
/// Replaces the deprecated top-level `output_format` parameter.
/// Carries the structured-output `format` and (optionally) `effort`.
public struct AnthropicOutputConfig: Encodable {
  /// Structured-output format (e.g. JSON schema).
  public let format: AnthropicOutputFormat?

  /// Effort level controlling thinking depth and overall token spend.
  public let effort: AnthropicEffort?

  public init(format: AnthropicOutputFormat? = nil, effort: AnthropicEffort? = nil) {
    self.format = format
    self.effort = effort
  }

  /// Convenience initializer for a JSON-schema-formatted response.
  public static func schema(_ schema: [String: Any]) -> AnthropicOutputConfig {
    AnthropicOutputConfig(format: .schema(schema: schema))
  }

  /// Convenience initializer for an effort-only output configuration.
  public static func effort(_ effort: AnthropicEffort) -> AnthropicOutputConfig {
    AnthropicOutputConfig(effort: effort)
  }

  enum CodingKeys: String, CodingKey {
    case format
    case effort
  }
}

// MARK: - AnthropicEffort

/// Effort level for `output_config.effort`.
public enum AnthropicEffort: String, Encodable {
  case low
  case medium
  case high
  case xhigh
  case max
}

// MARK: - AnthropicOutputFormat

/// Structured-output format. Wire shape goes inside `output_config.format`.
public enum AnthropicOutputFormat: Encodable {
  case text
  case jsonSchema(AnthropicJSONSchemaFormat)

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .text:
      try container.encode(["type": "text"])
    case .jsonSchema(let format):
      try container.encode(format)
    }
  }

  /// Convenience initializer for creating JSON schema output format
  public static func schema(
    schema: [String: Any]
  ) -> AnthropicOutputFormat {
    .jsonSchema(AnthropicJSONSchemaFormat(schema: schema))
  }
}

/// JSON schema format specification
/// Format: { "type": "json_schema", "schema": {...} }
public struct AnthropicJSONSchemaFormat: Encodable {
  public let type: String
  public let schema: [String: AnthropicDynamicValue]

  public init(schema: [String: Any]) {
    self.type = "json_schema"
    self.schema = schema.mapValues { AnthropicDynamicValue($0) }
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

// MARK: - Token Counting

/// Parameters for `POST /v1/messages/count_tokens`.
/// Reuses the Messages API parameter types so a prospective request can be
/// counted exactly as it would be sent.
public struct AnthropicTokenCountParameter: Encodable {
  /// The model the request will be sent to (token counts are model-specific).
  public let model: String

  /// The messages in the conversation.
  public let messages: [AnthropicMessage]

  /// System prompt.
  public let system: AnthropicSystemContent?

  /// Tools available for the model to use.
  public let tools: [AnthropicTool]?

  public init(
    model: String,
    messages: [AnthropicMessage],
    system: AnthropicSystemContent? = nil,
    tools: [AnthropicTool]? = nil
  ) {
    self.model = model
    self.messages = messages
    self.system = system
    self.tools = tools
  }
}

/// Response from `POST /v1/messages/count_tokens`.
public struct AnthropicTokenCountResponse: Decodable {
  /// The total number of input tokens for the provided request.
  public let inputTokens: Int

  enum CodingKeys: String, CodingKey {
    case inputTokens = "input_tokens"
  }
}

// MARK: - Files API

/// Metadata for a file stored via the Anthropic Files API (`/v1/files`).
public struct AnthropicFileMetadata: Decodable, Identifiable {
  public let id: String
  public let filename: String
  public let mimeType: String
  public let sizeBytes: Int
  public let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case filename
    case mimeType = "mime_type"
    case sizeBytes = "size_bytes"
    case createdAt = "created_at"
  }
}

/// Response from the Files API list endpoint (`GET /v1/files`).
public struct AnthropicFileListResponse: Decodable {
  public let data: [AnthropicFileMetadata]
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

/// Response from the Files API delete endpoint (`DELETE /v1/files/{id}`).
public struct AnthropicFileDeletedResponse: Decodable {
  public let id: String
  public let type: String?
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
