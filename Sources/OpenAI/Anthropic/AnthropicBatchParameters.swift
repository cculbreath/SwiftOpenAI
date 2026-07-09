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
  /// request body).
  public struct Request: Encodable {
    /// Caller-unique id echoed back on the corresponding result line.
    public let customId: String
    public let params: AnthropicMessageParameter

    public init(customId: String, params: AnthropicMessageParameter) {
      self.customId = customId
      self.params = params
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
  /// a `"succeeded"` result.
  public struct Result: Decodable {
    public let type: String
    public let message: AnthropicMessageResponse?
  }

  enum CodingKeys: String, CodingKey {
    case customId = "custom_id"
    case result
  }
}
