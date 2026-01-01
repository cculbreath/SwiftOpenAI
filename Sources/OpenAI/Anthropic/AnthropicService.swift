//
//  AnthropicService.swift
//  SwiftOpenAI
//
//  Service implementation for the Anthropic Messages API.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif

// MARK: - AnthropicService Protocol

public protocol AnthropicService {
  /// Create a streaming message
  func messagesStream(
    parameters: AnthropicMessageParameter
  ) async throws -> AsyncThrowingStream<AnthropicStreamEvent, Error>

  /// Create a non-streaming message
  func messages(
    parameters: AnthropicMessageParameter
  ) async throws -> AnthropicMessageResponse

  /// List available models
  func listModels() async throws -> AnthropicModelsResponse

  /// Retrieve a specific model
  func retrieveModel(id: String) async throws -> AnthropicModel
}

// MARK: - DefaultAnthropicService

public class DefaultAnthropicService: AnthropicService {
  private let apiKey: String
  private let environment: AnthropicEnvironment
  private let httpClient: HTTPClient
  private let decoder: JSONDecoder
  private let debugEnabled: Bool

  public init(
    apiKey: String,
    environment: AnthropicEnvironment = .production,
    httpClient: HTTPClient? = nil,
    decoder: JSONDecoder = .init(),
    debugEnabled: Bool = false
  ) {
    self.apiKey = apiKey
    self.environment = environment
    self.httpClient = httpClient ?? HTTPClientFactory.createDefault()
    self.decoder = decoder
    self.debugEnabled = debugEnabled
  }

  // MARK: - Messages (Streaming)

  public func messagesStream(
    parameters: AnthropicMessageParameter
  ) async throws -> AsyncThrowingStream<AnthropicStreamEvent, Error> {
    // Ensure stream is enabled
    var params = parameters
    if !params.stream {
      params = AnthropicMessageParameter(
        model: params.model,
        messages: params.messages,
        system: params.system,
        maxTokens: params.maxTokens,
        stream: true,
        tools: params.tools,
        toolChoice: params.toolChoice,
        temperature: params.temperature,
        topP: params.topP,
        topK: params.topK,
        stopSequences: params.stopSequences,
        metadata: params.metadata
      )
    }

    // Build beta headers if needed
    var betaHeaders: [String] = []
    if hasWebFetchTool(params.tools) {
      betaHeaders.append("web-fetch-2025-09-10")
    }

    let request = try AnthropicAPI.messages.request(
      apiKey: apiKey,
      environment: environment,
      method: .post,
      params: params,
      betaHeaders: betaHeaders.isEmpty ? nil : betaHeaders
    )

    if debugEnabled {
      debugLog("[Anthropic] Request: \(request.url?.absoluteString ?? "nil")")
      if let body = request.httpBody, let bodyStr = String(data: body, encoding: .utf8) {
        debugLog("[Anthropic] Body: \(bodyStr)")
      }
    }

    let httpRequest = try HTTPRequest(from: request)
    let (byteStream, response) = try await httpClient.bytes(for: httpRequest)

    guard (200...299).contains(response.statusCode) else {
      // Try to read error body
      var errorBody = ""
      if case .lines(let lineStream) = byteStream {
        for try await line in lineStream {
          errorBody += line
        }
      }
      throw APIError.responseUnsuccessful(
        description: "Request failed",
        statusCode: response.statusCode,
        responseBody: errorBody
      )
    }

    return AsyncThrowingStream { continuation in
      let task = Task {
        do {
          guard case .lines(let lineStream) = byteStream else {
            throw APIError.requestFailed(description: "Expected line stream")
          }

          var pendingData = ""
          for try await line in lineStream {
            if Task.isCancelled {
              continuation.finish()
              return
            }

            // Handle SSE format
            if line.hasPrefix("event:") {
              // Event type line - we'll get the data next
              continue
            }

            if line.hasPrefix("data:") {
              let jsonString = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
              if jsonString.isEmpty || jsonString == "[DONE]" {
                continue
              }

              pendingData = jsonString
            } else if !pendingData.isEmpty && !line.isEmpty {
              // Multi-line data
              pendingData += line
            } else if pendingData.isEmpty && !line.isEmpty && !line.hasPrefix(":") {
              // Direct JSON (some implementations don't use data: prefix)
              pendingData = line
            }

            // Try to parse when we have data and hit an empty line (end of SSE message)
            if line.isEmpty && !pendingData.isEmpty {
              if let data = pendingData.data(using: .utf8) {
                do {
                  let event = try self.decoder.decode(AnthropicStreamEvent.self, from: data)
                  continuation.yield(event)

                  if self.debugEnabled {
                    self.debugLog("[Anthropic] Event: \(pendingData)")
                  }
                } catch {
                  if self.debugEnabled {
                    self.debugLog("[Anthropic] Decode error: \(error), data: \(pendingData)")
                  }
                }
              }
              pendingData = ""
            }
          }

          // Handle any remaining data
          if !pendingData.isEmpty, let data = pendingData.data(using: .utf8) {
            if let event = try? self.decoder.decode(AnthropicStreamEvent.self, from: data) {
              continuation.yield(event)
            }
          }

          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }

      continuation.onTermination = { @Sendable _ in
        task.cancel()
      }
    }
  }

  // MARK: - Messages (Non-Streaming)

  public func messages(
    parameters: AnthropicMessageParameter
  ) async throws -> AnthropicMessageResponse {
    // Ensure stream is disabled
    var params = parameters
    if params.stream {
      params = AnthropicMessageParameter(
        model: params.model,
        messages: params.messages,
        system: params.system,
        maxTokens: params.maxTokens,
        stream: false,
        tools: params.tools,
        toolChoice: params.toolChoice,
        temperature: params.temperature,
        topP: params.topP,
        topK: params.topK,
        stopSequences: params.stopSequences,
        metadata: params.metadata
      )
    }

    // Build beta headers if needed
    var betaHeaders: [String] = []
    if hasWebFetchTool(params.tools) {
      betaHeaders.append("web-fetch-2025-09-10")
    }

    let request = try AnthropicAPI.messages.request(
      apiKey: apiKey,
      environment: environment,
      method: .post,
      params: params,
      betaHeaders: betaHeaders.isEmpty ? nil : betaHeaders
    )

    if debugEnabled {
      debugLog("[Anthropic] Request: \(request.url?.absoluteString ?? "nil")")
    }

    let httpRequest = try HTTPRequest(from: request)
    let (data, response) = try await httpClient.data(for: httpRequest)

    guard (200...299).contains(response.statusCode) else {
      let errorBody = String(data: data, encoding: .utf8)
      throw APIError.responseUnsuccessful(
        description: "Request failed",
        statusCode: response.statusCode,
        responseBody: errorBody
      )
    }

    return try decoder.decode(AnthropicMessageResponse.self, from: data)
  }

  // MARK: - Models

  public func listModels() async throws -> AnthropicModelsResponse {
    let request = try AnthropicAPI.models(.list).request(
      apiKey: apiKey,
      environment: environment,
      method: .get
    )

    let httpRequest = try HTTPRequest(from: request)
    let (data, response) = try await httpClient.data(for: httpRequest)

    guard (200...299).contains(response.statusCode) else {
      let errorBody = String(data: data, encoding: .utf8)
      throw APIError.responseUnsuccessful(
        description: "Request failed",
        statusCode: response.statusCode,
        responseBody: errorBody
      )
    }

    return try decoder.decode(AnthropicModelsResponse.self, from: data)
  }

  public func retrieveModel(id: String) async throws -> AnthropicModel {
    let request = try AnthropicAPI.models(.retrieve(modelID: id)).request(
      apiKey: apiKey,
      environment: environment,
      method: .get
    )

    let httpRequest = try HTTPRequest(from: request)
    let (data, response) = try await httpClient.data(for: httpRequest)

    guard (200...299).contains(response.statusCode) else {
      let errorBody = String(data: data, encoding: .utf8)
      throw APIError.responseUnsuccessful(
        description: "Request failed",
        statusCode: response.statusCode,
        responseBody: errorBody
      )
    }

    return try decoder.decode(AnthropicModel.self, from: data)
  }

  // MARK: - Helpers

  private func hasWebFetchTool(_ tools: [AnthropicTool]?) -> Bool {
    guard let tools else { return false }
    return tools.contains { tool in
      if case .serverTool(let serverTool) = tool {
        return serverTool.type == "web_fetch_20250910"
      }
      return false
    }
  }

  private func debugLog(_ message: String) {
    #if DEBUG
    print(message)
    #endif
  }
}

// MARK: - AnthropicServiceFactory

public enum AnthropicServiceFactory {
  /// Creates a standard Anthropic service
  public static func service(
    apiKey: String,
    environment: AnthropicEnvironment = .production,
    httpClient: HTTPClient? = nil,
    debugEnabled: Bool = false
  ) -> AnthropicService {
    DefaultAnthropicService(
      apiKey: apiKey,
      environment: environment,
      httpClient: httpClient,
      debugEnabled: debugEnabled
    )
  }
}
