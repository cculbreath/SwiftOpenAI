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

  enum CodingKeys: String, CodingKey {
    case inputTokens = "input_tokens"
    case outputTokens = "output_tokens"
    case cacheCreationInputTokens = "cache_creation_input_tokens"
    case cacheReadInputTokens = "cache_read_input_tokens"
  }
}

/// Stream content block (initially empty)
public struct AnthropicStreamContentBlock: Decodable {
  public let type: String
  public let text: String?
  public let id: String?
  public let name: String?
  public let input: [String: AnthropicDynamicValue]?
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
  case unknown(type: String)

  private enum CodingKeys: String, CodingKey {
    case type
    case text
    case partialJson = "partial_json"
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
