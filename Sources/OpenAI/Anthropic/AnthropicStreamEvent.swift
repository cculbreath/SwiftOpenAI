//
//  AnthropicStreamEvent.swift
//  SwiftOpenAI
//
//  Streaming event types for the Anthropic Messages API.
//

import Foundation

// MARK: - AnthropicStreamEvent

/// Represents all possible streaming events from the Anthropic Messages API.
public enum AnthropicStreamEvent: Decodable {
  /// Initial event when message starts
  case messageStart(AnthropicMessageStartEvent)

  /// Delta event for content block
  case contentBlockStart(AnthropicContentBlockStartEvent)

  /// Text delta within a content block
  case contentBlockDelta(AnthropicContentBlockDeltaEvent)

  /// Content block finished
  case contentBlockStop(AnthropicContentBlockStopEvent)

  /// Message delta (stop reason, usage updates)
  case messageDelta(AnthropicMessageDeltaEvent)

  /// Final event when message is complete
  case messageStop(AnthropicMessageStopEvent)

  /// Ping event (keep-alive)
  case ping

  /// Error event
  case error(AnthropicErrorEvent)

  /// Unknown event type
  case unknown(String)

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "message_start":
      self = try .messageStart(AnthropicMessageStartEvent(from: decoder))
    case "content_block_start":
      self = try .contentBlockStart(AnthropicContentBlockStartEvent(from: decoder))
    case "content_block_delta":
      self = try .contentBlockDelta(AnthropicContentBlockDeltaEvent(from: decoder))
    case "content_block_stop":
      self = try .contentBlockStop(AnthropicContentBlockStopEvent(from: decoder))
    case "message_delta":
      self = try .messageDelta(AnthropicMessageDeltaEvent(from: decoder))
    case "message_stop":
      self = try .messageStop(AnthropicMessageStopEvent(from: decoder))
    case "ping":
      self = .ping
    case "error":
      self = try .error(AnthropicErrorEvent(from: decoder))
    default:
      self = .unknown(type)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case type
  }
}

// MARK: - Event Types

/// Initial event containing the message object
public struct AnthropicMessageStartEvent: Decodable {
  public let type: String
  public let message: AnthropicStreamMessage

  public struct AnthropicStreamMessage: Decodable {
    public let id: String
    public let type: String
    public let role: String
    public let content: [AnthropicStreamContentBlock]
    public let model: String
    public let stopReason: String?
    public let stopSequence: String?
    public let usage: AnthropicStreamUsage

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
}

/// Usage in stream events (may have partial data)
public struct AnthropicStreamUsage: Decodable {
  public let inputTokens: Int?
  public let outputTokens: Int?
  public let cacheCreationInputTokens: Int?
  public let cacheReadInputTokens: Int?
  public let serverToolUse: AnthropicServerToolUsage?

  enum CodingKeys: String, CodingKey {
    case inputTokens = "input_tokens"
    case outputTokens = "output_tokens"
    case cacheCreationInputTokens = "cache_creation_input_tokens"
    case cacheReadInputTokens = "cache_read_input_tokens"
    case serverToolUse = "server_tool_use"
  }
}

/// Stream content block (initially empty for text/tool_use; server tool result
/// blocks arrive fully populated in `content_block_start`)
public struct AnthropicStreamContentBlock: Decodable {
  public let type: String
  public let text: String?
  public let id: String?
  public let name: String?
  public let input: [String: AnthropicDynamicValue]?

  /// For "web_search_tool_result" / "web_fetch_tool_result" blocks: the id of
  /// the originating server_tool_use block.
  public let toolUseId: String?

  /// For "web_search_tool_result" / "web_fetch_tool_result" blocks: the full
  /// result payload. Server tool results are not streamed via deltas — the
  /// complete content arrives in `content_block_start`, so it is decoded here
  /// for faithful reconstruction of the assistant message in agentic loops.
  public let content: AnthropicStreamServerToolResultContent?

  enum CodingKeys: String, CodingKey {
    case type
    case text
    case id
    case name
    case input
    case toolUseId = "tool_use_id"
    case content
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    type = try container.decode(String.self, forKey: .type)
    text = try container.decodeIfPresent(String.self, forKey: .text)
    id = try container.decodeIfPresent(String.self, forKey: .id)
    name = try container.decodeIfPresent(String.self, forKey: .name)
    input = try container.decodeIfPresent([String: AnthropicDynamicValue].self, forKey: .input)
    toolUseId = try container.decodeIfPresent(String.self, forKey: .toolUseId)
    switch type {
    case "web_search_tool_result", "web_fetch_tool_result":
      content = try container.decodeIfPresent(AnthropicStreamServerToolResultContent.self, forKey: .content)
    default:
      // Other block types may carry a differently-shaped `content`; only the
      // server tool result shapes are modeled here.
      content = nil
    }
  }
}

/// Decoded `content` of a server tool result block in `content_block_start`.
/// Mirrors the SSE JSON: an array is a web_search result list; objects branch
/// on their `type` discriminator.
public enum AnthropicStreamServerToolResultContent: Decodable {
  case webSearch(AnthropicWebSearchToolResultContent)
  case webFetch(AnthropicWebFetchToolResultContent)

  private enum CodingKeys: String, CodingKey {
    case type
  }

  public init(from decoder: Decoder) throws {
    let singleValue = try decoder.singleValueContainer()
    if let results = try? singleValue.decode([AnthropicWebSearchResult].self) {
      self = .webSearch(.results(results))
      return
    }

    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "web_search_tool_result_error":
      self = .webSearch(.error(try AnthropicWebSearchToolResultError(from: decoder)))
    case "web_fetch_result":
      self = .webFetch(.fetchResult(try AnthropicWebFetchResult(from: decoder)))
    case "web_fetch_tool_result_error":
      self = .webFetch(.error(try AnthropicWebFetchToolResultError(from: decoder)))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type, in: container,
        debugDescription: "Unknown server tool result content type: \(type)"
      )
    }
  }
}

/// Content block start event
public struct AnthropicContentBlockStartEvent: Decodable {
  public let type: String
  public let index: Int
  public let contentBlock: AnthropicStreamContentBlock

  enum CodingKeys: String, CodingKey {
    case type
    case index
    case contentBlock = "content_block"
  }
}

/// Content block delta event
public struct AnthropicContentBlockDeltaEvent: Decodable {
  public let type: String
  public let index: Int
  public let delta: AnthropicContentDelta

  enum CodingKeys: String, CodingKey {
    case type
    case index
    case delta
  }
}

/// Delta content in a content block
public enum AnthropicContentDelta: Decodable {
  case textDelta(text: String)
  case inputJsonDelta(partialJson: String)
  /// Incremental extended-thinking text (summary when `thinking.display == "summarized"`).
  case thinkingDelta(thinking: String)
  /// The cryptographic signature emitted at the end of a thinking block. Opaque; only
  /// needed when replaying thinking blocks back to the API on the same model.
  case signatureDelta(signature: String)
  case unknown(type: String)

  private enum CodingKeys: String, CodingKey {
    case type
    case text
    case partialJson = "partial_json"
    case thinking
    case signature
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "text_delta":
      let text = try container.decode(String.self, forKey: .text)
      self = .textDelta(text: text)
    case "input_json_delta":
      let partialJson = try container.decode(String.self, forKey: .partialJson)
      self = .inputJsonDelta(partialJson: partialJson)
    case "thinking_delta":
      let thinking = try container.decode(String.self, forKey: .thinking)
      self = .thinkingDelta(thinking: thinking)
    case "signature_delta":
      let signature = try container.decode(String.self, forKey: .signature)
      self = .signatureDelta(signature: signature)
    default:
      self = .unknown(type: type)
    }
  }

  /// Get the text delta if this is a text delta
  public var text: String? {
    if case .textDelta(let text) = self {
      return text
    }
    return nil
  }

  /// Get the partial JSON if this is an input_json_delta
  public var partialJson: String? {
    if case .inputJsonDelta(let json) = self {
      return json
    }
    return nil
  }

  /// Get the thinking delta text if this is a thinking_delta
  public var thinking: String? {
    if case .thinkingDelta(let thinking) = self {
      return thinking
    }
    return nil
  }
}

/// Content block stop event
public struct AnthropicContentBlockStopEvent: Decodable {
  public let type: String
  public let index: Int
}

/// Message delta event (contains stop reason and final usage)
public struct AnthropicMessageDeltaEvent: Decodable {
  public let type: String
  public let delta: AnthropicMessageDeltaContent
  public let usage: AnthropicStreamUsage?
}

/// Delta content for the message itself
public struct AnthropicMessageDeltaContent: Decodable {
  /// Raw stop reason passthrough — no filtering of unknown values. Notably
  /// includes "pause_turn": the server-side tool loop (web_search/web_fetch)
  /// paused; re-send the conversation with the assistant turn appended and the
  /// server resumes where it left off.
  public let stopReason: String?

  public let stopSequence: String?

  enum CodingKeys: String, CodingKey {
    case stopReason = "stop_reason"
    case stopSequence = "stop_sequence"
  }
}

/// Message stop event (final event)
public struct AnthropicMessageStopEvent: Decodable {
  public let type: String
}

/// Error event
public struct AnthropicErrorEvent: Decodable {
  public let type: String
  public let error: AnthropicError
}

/// Error details
public struct AnthropicError: Decodable {
  public let type: String
  public let message: String
}

// MARK: - Convenience Extensions

extension AnthropicStreamEvent {
  /// Returns true if this is a text delta event
  public var isTextDelta: Bool {
    if case .contentBlockDelta(let event) = self,
       case .textDelta = event.delta {
      return true
    }
    return false
  }

  /// Extract text delta if present
  public var textDelta: String? {
    if case .contentBlockDelta(let event) = self {
      return event.delta.text
    }
    return nil
  }

  /// Returns true if this is a tool use start event
  public var isToolUseStart: Bool {
    if case .contentBlockStart(let event) = self,
       event.contentBlock.type == "tool_use" {
      return true
    }
    return false
  }

  /// Get tool use info from content block start
  public var toolUseInfo: (id: String, name: String)? {
    if case .contentBlockStart(let event) = self,
       event.contentBlock.type == "tool_use",
       let id = event.contentBlock.id,
       let name = event.contentBlock.name {
      return (id: id, name: name)
    }
    return nil
  }

  /// Returns true if this is a server tool use start event (e.g. web_search,
  /// web_fetch). Deliberately disjoint from `isToolUseStart` — server tools run
  /// on Anthropic's side and must not be dispatched to a local tool executor.
  /// Like regular tool_use, the input streams via input_json_delta.
  public var isServerToolUseStart: Bool {
    if case .contentBlockStart(let event) = self,
       event.contentBlock.type == "server_tool_use" {
      return true
    }
    return false
  }

  /// Get server tool use info from content block start
  public var serverToolUseInfo: (id: String, name: String)? {
    if case .contentBlockStart(let event) = self,
       event.contentBlock.type == "server_tool_use",
       let id = event.contentBlock.id,
       let name = event.contentBlock.name {
      return (id: id, name: name)
    }
    return nil
  }

  /// Returns true if this is an input_json_delta for tool use
  public var isToolInputDelta: Bool {
    if case .contentBlockDelta(let event) = self,
       case .inputJsonDelta = event.delta {
      return true
    }
    return false
  }

  /// Get partial JSON for tool input
  public var toolInputPartialJson: String? {
    if case .contentBlockDelta(let event) = self {
      return event.delta.partialJson
    }
    return nil
  }

  /// Get stop reason if present (from message_delta)
  public var stopReason: String? {
    if case .messageDelta(let event) = self {
      return event.delta.stopReason
    }
    return nil
  }

  /// Get usage if present (from message_start or message_delta)
  public var usage: AnthropicStreamUsage? {
    switch self {
    case .messageStart(let event):
      return event.message.usage
    case .messageDelta(let event):
      return event.usage
    default:
      return nil
    }
  }

  /// Get message ID (from message_start)
  public var messageId: String? {
    if case .messageStart(let event) = self {
      return event.message.id
    }
    return nil
  }
}
