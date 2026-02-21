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
        metadata: params.metadata,
        outputFormat: params.outputFormat
      )
    }

    // Build beta headers if needed
    var betaHeaders: [String] = []
    if hasWebFetchTool(params.tools) {
      betaHeaders.append("web-fetch-2025-09-10")
    }
    // Structured outputs are GA as of Claude 4.6 — no beta header needed.

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
      // Try to read error body with detailed diagnostics
      var errorBody = ""
      var streamType = "unknown"

      switch byteStream {
      case .lines(let lineStream):
        streamType = "lines"
        do {
          for try await line in lineStream {
            errorBody += line
          }
        } catch {
          // Error reading stream - captured in errorBody if possible
        }
      case .bytes(let byteStream):
        streamType = "bytes"
        // Try to read bytes directly
        do {
          var data = Data()
          for try await byte in byteStream {
            data.append(byte)
          }
          errorBody = String(data: data, encoding: .utf8) ?? "(non-UTF8 data, \(data.count) bytes)"
        } catch {
          // Error reading bytes - captured in errorBody if possible
        }
      }

      // Log errors only when debug is enabled
      if debugEnabled {
        debugLog("🚨 [Anthropic] HTTP \(response.statusCode) error (stream type: \(streamType))")
        debugLog("🚨 [Anthropic] Error body: \(errorBody.isEmpty ? "(empty)" : errorBody)")
        if let body = request.httpBody, let requestStr = String(data: body, encoding: .utf8) {
          let truncated = requestStr.count > 2000 ? String(requestStr.prefix(2000)) + "... [truncated]" : requestStr
          debugLog("🚨 [Anthropic] Request body (truncated): \(truncated)")
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
          var lineCount = 0
          if self.debugEnabled {
            self.debugLog("[Anthropic SSE] Starting stream iteration")
          }
          for try await line in lineStream {
            lineCount += 1
            // Only log raw lines when debug is enabled (very verbose)
            if self.debugEnabled {
              self.debugLog("[Anthropic SSE] Line \(lineCount): '\(line)'")
            }

            if Task.isCancelled {
              continuation.finish()
              return
            }

            // Handle SSE format
            if line.hasPrefix("event:") {
              // A new event line means previous event is complete
              // Parse any pending data before processing this new event
              if !pendingData.isEmpty, let data = pendingData.data(using: .utf8) {
                do {
                  let event = try self.decoder.decode(AnthropicStreamEvent.self, from: data)
                  if self.debugEnabled {
                    self.debugLog("[Anthropic SSE] ✅ Yielding event from pending data: \(String(describing: event).prefix(100))")
                  }
                  continuation.yield(event)
                } catch {
                  if self.debugEnabled {
                    self.debugLog("[Anthropic SSE] ❌ Decode error: \(error), data: \(pendingData.prefix(200))")
                  }
                }
                pendingData = ""
              }
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
              if self.debugEnabled {
                self.debugLog("[Anthropic SSE] Parsing pending data: \(pendingData.prefix(200))...")
              }
              if let data = pendingData.data(using: .utf8) {
                do {
                  let event = try self.decoder.decode(AnthropicStreamEvent.self, from: data)
                  continuation.yield(event)

                  if self.debugEnabled {
                    self.debugLog("[Anthropic] Event: \(pendingData)")
                  }
                } catch {
                  if self.debugEnabled {
                    self.debugLog("[Anthropic SSE] Decode error: \(error), data: \(pendingData)")
                  }
                  if self.debugEnabled {
                    self.debugLog("[Anthropic] Decode error: \(error), data: \(pendingData)")
                  }
                }
              }
              pendingData = ""
            }
          }
          if self.debugEnabled {
            self.debugLog("[Anthropic SSE] Stream ended after \(lineCount) lines")
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
        metadata: params.metadata,
        outputFormat: params.outputFormat
      )
    }

    // Build beta headers if needed
    var betaHeaders: [String] = []
    if hasWebFetchTool(params.tools) {
      betaHeaders.append("web-fetch-2025-09-10")
    }
    // Structured outputs are GA as of Claude 4.6 — no beta header needed.

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
