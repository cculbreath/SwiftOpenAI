//
//  AnthropicBatchParameters.swift
//  SwiftOpenAI
//
//  Anthropic Message Batches API (`/v1/messages/batches`) — GA. Submit many
//  Messages API requests as one asynchronous batch (processed within 24h,
//  billed at a 50% discount), poll for completion, then read the JSONL results.
//
//  Request bodies travel through `AnthropicRequestBody.encode`
//  (`.convertToSnakeCase` + `.sortedKeys`), so the parameter types use plain
//  camelCase property names (e.g. `customId` → `custom_id`) with no CodingKeys —
//  matching every other Anthropic request in this module. Response types decode
//  with a plain `JSONDecoder`, so they carry explicit snake_case CodingKeys.
//

import Foundation

// MARK: - Request

/// Body for `POST /v1/messages/batches`.
public struct AnthropicMessageBatchParameter: Encodable {
  /// One entry in the batch: a caller-chosen id + the exact Messages API params
  /// that entry should run with (identical shape to a standalone `/v1/messages`
  /// request body — except `stream`, which this initializer normalizes).
  public struct Request: Encodable {
    /// Caller-unique id echoed back on the corresponding result line.
    public let customId: String
    public let params: AnthropicMessageParameter

    /// Normalizes `params.stream` to `false`: the Batch API rejects streaming
    /// requests ("`stream=True` is not supported in the Message Batches API"),
    /// and `AnthropicMessageParameter.init` defaults `stream` to `true` — a
    /// caller who forgets to override it would have every batched request
    /// errored. Streaming is meaningless inside a batch, so force it here.
    public init(customId: String, params: AnthropicMessageParameter) {
      self.customId = customId
      var normalized = params
      normalized.stream = false
      self.params = normalized
    }
  }

  public let requests: [Request]

  public init(requests: [Request]) {
    self.requests = requests
  }
}

// MARK: - Response

/// Response from `POST /v1/messages/batches` and `GET /v1/messages/batches/{id}`.
public struct AnthropicMessageBatchResponse: Decodable {
  public let id: String
  public let type: String
  /// `"in_progress"`, `"canceling"`, or `"ended"`. Results are only available
  /// once this is `"ended"`.
  public let processingStatus: String
  /// Populated once processing has ended; the endpoint to fetch JSONL results.
  public let resultsUrl: String?
  public let requestCounts: AnthropicMessageBatchRequestCounts?

  enum CodingKeys: String, CodingKey {
    case id
    case type
    case processingStatus = "processing_status"
    case resultsUrl = "results_url"
    case requestCounts = "request_counts"
  }
}

/// Per-status tallies for a batch's requests.
public struct AnthropicMessageBatchRequestCounts: Decodable {
  public let processing: Int
  public let succeeded: Int
  public let errored: Int
  public let canceled: Int
  public let expired: Int
}

// MARK: - Results (JSONL)

/// One line of the JSONL body from `GET /v1/messages/batches/{id}/results`.
public struct AnthropicMessageBatchResultLine: Decodable {
  public let customId: String
  public let result: Result

  /// The outcome for a single batched request. `type` is `"succeeded"`,
  /// `"errored"`, `"canceled"`, or `"expired"`; `message` is present only for
  /// a `"succeeded"` result, `error` only for an `"errored"` one.
  public struct Result: Decodable {
    public let type: String
    public let message: AnthropicMessageResponse?
    public let error: BatchResultError?
  }

  /// The error envelope on an `"errored"` result line — the standard API error
  /// shape nested under the result (`{"type":"error","error":{"type":…,
  /// "message":…}}`). Every field optional so an unexpected shape degrades to
  /// nils instead of failing the line decode; `describe` flattens whichever
  /// fields arrived for diagnostics.
  public struct BatchResultError: Decodable {
    public let type: String?
    public let error: Detail?

    public struct Detail: Decodable {
      public let type: String?
      public let message: String?
    }

    /// Best-effort one-line description for logs.
    public var describe: String {
      let kind = error?.type ?? type ?? "unknown"
      let message = error?.message ?? "no message"
      return "\(kind): \(message)"
    }
  }

  enum CodingKeys: String, CodingKey {
    case customId = "custom_id"
    case result
  }
}
