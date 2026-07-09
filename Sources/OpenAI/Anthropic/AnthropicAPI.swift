//
//  AnthropicAPI.swift
//  SwiftOpenAI
//
//  Anthropic API endpoint definitions for direct Anthropic API integration.
//

import Foundation

// MARK: - AnthropicAPI

enum AnthropicAPI {
  case messages
  case countTokens
  case messageBatches
  case messageBatch(id: String)
  case messageBatchResults(id: String)
  case models(ModelCategory)
  case files(FileCategory)

  enum ModelCategory {
    case list
    case retrieve(modelID: String)
  }

  enum FileCategory {
    case upload
    case list
    case retrieveMetadata(fileID: String)
    case delete(fileID: String)
  }
}

// MARK: - AnthropicEnvironment

public struct AnthropicEnvironment {
  public let baseURL: String
  public let version: String

  public init(
    baseURL: String = "https://api.anthropic.com",
    version: String = "v1"
  ) {
    self.baseURL = baseURL
    self.version = version
  }

  public static let production = AnthropicEnvironment()
}

// MARK: - Endpoint Conformance

extension AnthropicAPI {
  func path(in environment: AnthropicEnvironment) -> String {
    let version = "/\(environment.version)"

    switch self {
    case .messages:
      return "\(version)/messages"
    case .countTokens:
      return "\(version)/messages/count_tokens"
    case .messageBatches:
      return "\(version)/messages/batches"
    case .messageBatch(let id):
      return "\(version)/messages/batches/\(id)"
    case .messageBatchResults(let id):
      return "\(version)/messages/batches/\(id)/results"
    case .models(let category):
      switch category {
      case .list:
        return "\(version)/models"
      case .retrieve(let modelID):
        return "\(version)/models/\(modelID)"
      }
    case .files(let category):
      switch category {
      case .upload, .list:
        return "\(version)/files"
      case .retrieveMetadata(let fileID), .delete(let fileID):
        return "\(version)/files/\(fileID)"
      }
    }
  }
}

// MARK: - AnthropicRequestBody

/// The single sanctioned serializer for Anthropic request bodies.
///
/// `.convertToSnakeCase` and `.sortedKeys` MUST travel together, and this is the
/// only place either is configured. Setting any `keyEncodingStrategy` makes
/// `JSONEncoder` buffer the converted keys into an unordered map and emit them in
/// process-seeded (and buffer-perturbed) hash order; without `.sortedKeys`,
/// identical content serializes with different key order between requests,
/// shifting the wire bytes and silently invalidating Anthropic's prompt-cache
/// prefix on nearly every turn.
///
/// Every Anthropic request body goes through `encode(_:)` so deterministic
/// ordering can never be forgotten. Do not construct a bare `JSONEncoder` for an
/// Anthropic body anywhere else.
enum AnthropicRequestBody {
  static func encode(_ value: any Encodable) throws -> Data {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(value)
  }
}

// MARK: - Request Building

extension AnthropicAPI {
  func request(
    apiKey: String,
    environment: AnthropicEnvironment,
    method: HTTPMethod,
    params: Encodable? = nil,
    queryItems: [URLQueryItem] = [],
    betaHeaders: [String]? = nil
  ) throws -> URLRequest {
    let finalPath = path(in: environment)
    guard var components = URLComponents(string: environment.baseURL) else {
      throw URLError(.badURL)
    }
    components.path = finalPath
    if !queryItems.isEmpty {
      components.queryItems = queryItems
    }

    guard let url = components.url else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

    // Add beta headers if specified
    if let betaHeaders, !betaHeaders.isEmpty {
      request.addValue(betaHeaders.joined(separator: ","), forHTTPHeaderField: "anthropic-beta")
    }

    request.httpMethod = method.rawValue

    if let params {
      // Single sanctioned serializer — see AnthropicRequestBody below. Never
      // build a bare JSONEncoder for an Anthropic body; sorting must not be
      // omittable.
      request.httpBody = try AnthropicRequestBody.encode(params)
    }

    return request
  }

  /// Builds a multipart/form-data request (used by the Files API upload endpoint).
  func multipartRequest(
    apiKey: String,
    environment: AnthropicEnvironment,
    method: HTTPMethod,
    boundary: String,
    body: Data,
    betaHeaders: [String]? = nil
  ) throws -> URLRequest {
    let finalPath = path(in: environment)
    guard var components = URLComponents(string: environment.baseURL) else {
      throw URLError(.badURL)
    }
    components.path = finalPath

    guard let url = components.url else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

    if let betaHeaders, !betaHeaders.isEmpty {
      request.addValue(betaHeaders.joined(separator: ","), forHTTPHeaderField: "anthropic-beta")
    }

    request.httpMethod = method.rawValue
    request.httpBody = body

    return request
  }
}
