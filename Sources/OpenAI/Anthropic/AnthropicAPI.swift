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
  case models(ModelCategory)

  enum ModelCategory {
    case list
    case retrieve(modelID: String)
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
    case .models(let category):
      switch category {
      case .list:
        return "\(version)/models"
      case .retrieve(let modelID):
        return "\(version)/models/\(modelID)"
      }
    }
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
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      request.httpBody = try encoder.encode(params)
    }

    return request
  }
}
