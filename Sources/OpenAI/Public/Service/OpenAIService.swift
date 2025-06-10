import Foundation

public enum APIError: Error {
  case requestFailed(description: String)
  case responseUnsuccessful(description: String, statusCode: Int, responseBody: String? = nil)
  case invalidData
  case jsonDecodingFailure(description: String)
  case dataCouldNotBeReadMissingData(description: String)
  case bothDecodingStrategiesFailed
  case timeOutError

  public var displayDescription: String {
    switch self {
    case .requestFailed(let description): 
      return description
    case .responseUnsuccessful(let description, let statusCode, let responseBody):
      if let body = responseBody {
        return "Status \(statusCode): \(description) - Response: \(body)"
      } else {
        return "Status \(statusCode): \(description)"
      }
    case .invalidData: 
      return "Invalid data"
    case .jsonDecodingFailure(let description): 
      return description
    case .dataCouldNotBeReadMissingData(let description): 
      return description
    case .bothDecodingStrategiesFailed: 
      return "Decoding strategies failed."
    case .timeOutError: 
      return "Time Out Error."
    }
  }
}

public enum Authorization {
  case apiKey(String)
  case bearer(String)

  var headerField: String {
    switch self {
    case .apiKey:
      "api-key"
    case .bearer:
      "Authorization"
    }
  }

  var value: String {
    switch self {
    case .apiKey(let value):
      value
    case .bearer(let value):
      "Bearer \(value)"
    }
  }
}

public struct OpenAIEnvironment {
  let baseURL: String
  let proxyPath: String?
  let version: String?
}

public protocol OpenAIService {
  var session: URLSession { get }
  var decoder: JSONDecoder { get }
  var openAIEnvironment: OpenAIEnvironment { get }

  func createTranscription(parameters: AudioTranscriptionParameters) async throws -> AudioObject
  func createTranslation(parameters: AudioTranslationParameters) async throws -> AudioObject
  func createSpeech(parameters: AudioSpeechParameters) async throws -> AudioSpeechObject
  func createStreamingSpeech(parameters: AudioSpeechParameters) async throws -> AsyncThrowingStream<AudioSpeechChunkObject, Error>
  func startChat(parameters: ChatCompletionParameters) async throws -> ChatCompletionObject
  func startStreamedChat(parameters: ChatCompletionParameters) async throws -> AsyncThrowingStream<ChatCompletionChunkObject, Error>
  func createEmbeddings(parameters: EmbeddingParameter) async throws -> OpenAIResponse<EmbeddingObject>
  func createFineTuningJob(parameters: FineTuningJobParameters) async throws -> FineTuningJobObject
  func listFineTuningJobs(after lastJobID: String?, limit: Int?) async throws -> OpenAIResponse<FineTuningJobObject>
  func retrieveFineTuningJob(id: String) async throws -> FineTuningJobObject
  func cancelFineTuningJobWith(id: String) async throws -> FineTuningJobObject
  func listFineTuningEventsForJobWith(id: String, after lastEventId: String?, limit: Int?) async throws -> OpenAIResponse<FineTuningJobEventObject>
  func listFiles() async throws -> OpenAIResponse<FileObject>
  func uploadFile(parameters: FileParameters) async throws -> FileObject
  func deleteFileWith(id: String) async throws -> DeletionStatus
  func retrieveFileWith(id: String) async throws -> FileObject
  func retrieveContentForFileWith(id: String) async throws -> [[String: Any]]
  func legacyCreateImages(parameters: ImageCreateParameters) async throws -> OpenAIResponse<ImageObject>
  func legacyEditImage(parameters: ImageEditParameters) async throws -> OpenAIResponse<ImageObject>
  func legacyCreateImageVariations(parameters: ImageVariationParameters) async throws -> OpenAIResponse<ImageObject>
  func createImages(parameters: CreateImageParameters) async throws -> CreateImageResponse
  func editImage(parameters: CreateImageEditParameters) async throws -> CreateImageResponse
  func createImageVariations(parameters: CreateImageVariationParameters) async throws -> CreateImageResponse
  func listModels() async throws -> OpenAIResponse<ModelObject>
  func retrieveModelWith(id: String) async throws -> ModelObject
  func deleteFineTuneModelWith(id: String) async throws -> DeletionStatus
  func createModerationFromText(parameters: ModerationParameter<String>) async throws -> ModerationObject
  func createModerationFromTexts(parameters: ModerationParameter<[String]>) async throws -> ModerationObject
  func createAssistant(parameters: AssistantParameters) async throws -> AssistantObject
  func retrieveAssistant(id: String) async throws -> AssistantObject
  func modifyAssistant(id: String, parameters: AssistantParameters) async throws -> AssistantObject
  func deleteAssistant(id: String) async throws -> DeletionStatus
  func listAssistants(limit: Int?, order: String?, after: String?, before: String?) async throws -> OpenAIResponse<AssistantObject>
  func createThread(parameters: CreateThreadParameters) async throws -> ThreadObject
  func retrieveThread(id: String) async throws -> ThreadObject
  func modifyThread(id: String, parameters: ModifyThreadParameters) async throws -> ThreadObject
  func deleteThread(id: String) async throws -> DeletionStatus
  func createMessage(threadID: String, parameters: MessageParameter) async throws -> MessageObject
  func retrieveMessage(threadID: String, messageID: String) async throws -> MessageObject
  func modifyMessage(threadID: String, messageID: String, parameters: ModifyMessageParameters) async throws -> MessageObject
  func deleteMessage(threadID: String, messageID: String) async throws -> DeletionStatus
  func listMessages(threadID: String, limit: Int?, order: String?, after: String?, before: String?, runID: String?) async throws -> OpenAIResponse<MessageObject>
  func createRun(threadID: String, parameters: RunParameter) async throws -> RunObject
  func retrieveRun(threadID: String, runID: String) async throws -> RunObject
  func modifyRun(threadID: String, runID: String, parameters: ModifyRunParameters) async throws -> RunObject
  func listRuns(threadID: String, limit: Int?, order: String?, after: String?, before: String?) async throws -> OpenAIResponse<RunObject>
  func cancelRun(threadID: String, runID: String) async throws -> RunObject
  func submitToolOutputsToRun(threadID: String, runID: String, parameters: RunToolsOutputParameter) async throws -> RunObject
  func createThreadAndRun(parameters: CreateThreadAndRunParameter) async throws -> RunObject
  func retrieveRunstep(threadID: String, runID: String, stepID: String) async throws -> RunStepObject
  func listRunSteps(threadID: String, runID: String, limit: Int?, order: String?, after: String?, before: String?) async throws -> OpenAIResponse<RunStepObject>
  func createThreadAndRunStream(parameters: CreateThreadAndRunParameter) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error>
  func createRunStream(threadID: String, parameters: RunParameter) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error>
  func submitToolOutputsToRunStream(threadID: String, runID: String, parameters: RunToolsOutputParameter) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error>
  func createBatch(parameters: BatchParameter) async throws -> BatchObject
  func retrieveBatch(id: String) async throws -> BatchObject
  func cancelBatch(id: String) async throws -> BatchObject
  func listBatch(after: String?, limit: Int?) async throws -> OpenAIResponse<BatchObject>
  func createVectorStore(parameters: VectorStoreParameter) async throws -> VectorStoreObject
  func listVectorStores(limit: Int?, order: String?, after: String?, before: String?) async throws -> OpenAIResponse<VectorStoreObject>
  func retrieveVectorStore(id: String) async throws -> VectorStoreObject
  func modifyVectorStore(parameters: VectorStoreParameter, id: String) async throws -> VectorStoreObject
  func deleteVectorStore(id: String) async throws -> DeletionStatus
  func createVectorStoreFile(vectorStoreID: String, parameters: VectorStoreFileParameter) async throws -> VectorStoreFileObject
  func listVectorStoreFiles(vectorStoreID: String, limit: Int?, order: String?, after: String?, before: String?, filter: String?) async throws -> OpenAIResponse<VectorStoreFileObject>
  func retrieveVectorStoreFile(vectorStoreID: String, fileID: String) async throws -> VectorStoreFileObject
  func deleteVectorStoreFile(vectorStoreID: String, fileID: String) async throws -> DeletionStatus
  func createVectorStoreFileBatch(vectorStoreID: String, parameters: VectorStoreFileBatchParameter) async throws -> VectorStoreFileBatchObject
  func retrieveVectorStoreFileBatch(vectorStoreID: String, batchID: String) async throws -> VectorStoreFileBatchObject
  func cancelVectorStoreFileBatch(vectorStoreID: String, batchID: String) async throws -> VectorStoreFileBatchObject
  func listVectorStoreFilesInABatch(vectorStoreID: String, batchID: String, limit: Int?, order: String?, after: String?, before: String?, filter: String?) async throws -> OpenAIResponse<VectorStoreFileObject>
  func responseCreate(_ parameters: ModelResponseParameter) async throws -> ResponseModel
  func responseModel(id: String) async throws -> ResponseModel
}

extension OpenAIService {
  public func fetchContentsOfFile(request: URLRequest) async throws -> [[String: Any]] {
    printCurlCommand(request)
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw APIError.requestFailed(description: "invalid response unable to get a valid HTTPURLResponse")
    }
    printHTTPURLResponse(httpResponse, data: data)
    guard httpResponse.statusCode == 200 else {
      var errorMessage = "status code \(httpResponse.statusCode)"
      var responseBody: String? = nil
      do {
        let error = try decoder.decode(OpenAIErrorResponse.self, from: data)
        errorMessage += " \(error.error.message ?? "NO ERROR MESSAGE PROVIDED")"
      } catch {
        responseBody = String(data: data, encoding: .utf8)
        if let body = responseBody {
          errorMessage += " - Raw response: \(body)"
        }
      }
      throw APIError.responseUnsuccessful(
        description: errorMessage,
        statusCode: httpResponse.statusCode,
        responseBody: responseBody)
    }
    var content: [[String: Any]] = []
    if let jsonString = String(data: data, encoding: .utf8) {
      let lines = jsonString.split(separator: "\n")
      for line in lines {
        #if DEBUG
        print("DEBUG Received line:\n\(line)")
        #endif
        if let lineData = line.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: lineData, options: .allowFragments) as? [String: Any] {
          content.append(jsonObject)
        }
      }
    }
    return content
  }

  public func fetchAudio(with request: URLRequest) async throws -> Data {
    printCurlCommand(request)
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw APIError.requestFailed(description: "Invalid response: unable to get a valid HTTPURLResponse")
    }
    printHTTPURLResponse(httpResponse, data: data)
    guard httpResponse.statusCode == 200 else {
      var errorMessage = "Status code \(httpResponse.statusCode)"
      var responseBody: String? = nil
      do {
        let errorResponse = try decoder.decode(OpenAIErrorResponse.self, from: data)
        errorMessage += " \(errorResponse.error.message ?? "NO ERROR MESSAGE PROVIDED")"
      } catch {
        responseBody = String(data: data, encoding: .utf8)
        if let errorString = responseBody, !errorString.isEmpty {
          errorMessage += " - \(errorString)"
        } else {
          errorMessage += " - No error message provided"
        }
      }
      throw APIError.responseUnsuccessful(
        description: errorMessage,
        statusCode: httpResponse.statusCode,
        responseBody: responseBody)
    }
    return data
  }

  public func fetch<T: Decodable>(
    debugEnabled: Bool,
    type: T.Type,
    with request: URLRequest
  ) async throws -> T {
    if debugEnabled {
      printCurlCommand(request)
    }
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw APIError.requestFailed(description: "invalid response unable to get a valid HTTPURLResponse")
    }
    if debugEnabled {
      printHTTPURLResponse(httpResponse, data: data)
    }
    guard httpResponse.statusCode == 200 else {
      var errorMessage = "status code \(httpResponse.statusCode)"
      var responseBody: String? = nil
      
      do {
        let error = try decoder.decode(OpenAIErrorResponse.self, from: data)
        errorMessage += " \(error.error.message ?? "NO ERROR MESSAGE PROVIDED")"
      } catch {
        responseBody = String(data: data, encoding: .utf8)
        
        if let jsonData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
          if let error = jsonData["error"] as? [String: Any] {
            if let message = error["message"] as? String {
              errorMessage += " - \(message)"
            }
            if let metadata = error["metadata"] as? [String: Any],
               let raw = metadata["raw"] as? String {
              errorMessage += " - Provider error: \(raw)"
            }
          }
        } else if let body = responseBody {
          errorMessage += " - Raw response: \(body)"
        }
      }
      
      throw APIError.responseUnsuccessful(
        description: errorMessage,
        statusCode: httpResponse.statusCode,
        responseBody: responseBody
      )
    }
    #if DEBUG
    if debugEnabled {
      try print("DEBUG JSON FETCH API = \(JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any])")
    }
    #endif
    do {
      return try decoder.decode(type, from: data)
    } catch DecodingError.keyNotFound(let key, let context) {
      let debug = "Key '\(key.stringValue)' not found: \(context.debugDescription)"
      let codingPath = "codingPath: \(context.codingPath)"
      let debugMessage = debug + codingPath
      #if DEBUG
      if debugEnabled {
        print(debugMessage)
      }
      #endif
      throw APIError.dataCouldNotBeReadMissingData(description: debugMessage)
    } catch {
      #if DEBUG
      if debugEnabled {
        print("\(error)")
      }
      #endif
      throw APIError.jsonDecodingFailure(description: error.localizedDescription)
    }
  }

  public func fetchStream<T: Decodable>(
    debugEnabled: Bool,
    type _: T.Type,
    with request: URLRequest
  ) async throws -> AsyncThrowingStream<T, Error> {
    if debugEnabled {
      printCurlCommand(request)
    }

    let (data, response) = try await session.bytes(
      for: request,
      delegate: session.delegate as? URLSessionTaskDelegate)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw APIError.requestFailed(description: "invalid response unable to get a valid HTTPURLResponse")
    }
    if debugEnabled {
      printHTTPURLResponse(httpResponse)
    }
    guard httpResponse.statusCode == 200 else {
      var errorMessage = "status code \(httpResponse.statusCode)"
      var responseBody: String? = nil
      do {
        let data = try await data.reduce(into: Data()) { data, byte in
          data.append(byte)
        }
        let error = try decoder.decode(OpenAIErrorResponse.self, from: data)
        errorMessage += " \(error.error.message ?? "NO ERROR MESSAGE PROVIDED")"
        responseBody = String(data: data, encoding: .utf8)
      } catch {
        if let data = try? await data.reduce(into: Data()) { d, byte in
          d.append(byte)
        } {
          responseBody = String(data: data, encoding: .utf8)
          if let body = responseBody {
            errorMessage += " - Raw response: \(body)"
          }
        }
      }
      throw APIError.responseUnsuccessful(
        description: errorMessage,
        statusCode: httpResponse.statusCode,
        responseBody: responseBody)
    }
    return AsyncThrowingStream { continuation in
      let task = Task {
        do {
          for try await line in data.lines {
            if line.hasPrefix("data:"), line != "data: [DONE]",
               let data = line.dropFirst(5).data(using: .utf8) {
              #if DEBUG
              if debugEnabled {
                try print("DEBUG JSON STREAM LINE = \(JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any])")
              }
              #endif
              do {
                let decoded = try self.decoder.decode(T.self, from: data)
                continuation.yield(decoded)
              } catch DecodingError.keyNotFound(let key, let context) {
                let debug = "Key '\(key.stringValue)' not found: \(context.debugDescription)"
                let codingPath = "codingPath: \(context.codingPath)"
                let debugMessage = debug + codingPath
                #if DEBUG
                if debugEnabled {
                  print(debugMessage)
                }
                #endif
                throw APIError.dataCouldNotBeReadMissingData(description: debugMessage)
              } catch {
                #if DEBUG
                if debugEnabled {
                  debugPrint("CONTINUATION ERROR DECODING \(error.localizedDescription)")
                }
                #endif
                continuation.finish(throwing: error)
              }
            }
          }
          continuation.finish()
        } catch DecodingError.keyNotFound(let key, let context) {
          let debug = "Key '\(key.stringValue)' not found: \(context.debugDescription)"
          let codingPath = "codingPath: \(context.codingPath)"
          let debugMessage = debug + codingPath
          #if DEBUG
          if debugEnabled {
            print(debugMessage)
          }
          #endif
          throw APIError.dataCouldNotBeReadMissingData(description: debugMessage)
        } catch {
          #if DEBUG
          if debugEnabled {
            print("CONTINUATION ERROR DECODING \(error.localizedDescription)")
          }
          #endif
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { @Sendable _ in
        task.cancel()
      }
    }
  }

  public func fetchAssistantStreamEvents(
    with request: URLRequest,
    debugEnabled: Bool
  ) async throws -> AsyncThrowingStream<AssistantStreamEvent, Error> {
    printCurlCommand(request)

    let (data, response) = try await session.bytes(
      for: request,
      delegate: session.delegate as? URLSessionTaskDelegate)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw APIError.requestFailed(description: "invalid response unable to get a valid HTTPURLResponse")
    }
    printHTTPURLResponse(httpResponse)
    guard httpResponse.statusCode == 200 else {
      var errorMessage = "status code \(httpResponse.statusCode)"
      var responseBody: String? = nil
      do {
        let data = try await data.reduce(into: Data()) { data, byte in
          data.append(byte)
        }
        let error = try decoder.decode(OpenAIErrorResponse.self, from: data)
        errorMessage += " \(error.error.message ?? "NO ERROR MESSAGE PROVIDED")"
        responseBody = String(data: data, encoding: .utf8)
      } catch {
        if let data = try? await data.reduce(into: Data()) { d, byte in
          d.append(byte)
        } {
          responseBody = String(data: data, encoding: .utf8)
          if let body = responseBody {
            errorMessage += " - Raw response: \(body)"
          }
        }
      }
      throw APIError.responseUnsuccessful(
        description: errorMessage,
        statusCode: httpResponse.statusCode,
        responseBody: responseBody)
    }
    return AsyncThrowingStream { continuation in
      let task = Task {
        do {
          for try await line in data.lines {
            if line.hasPrefix("data:"), line != "data: [DONE]",
               let data = line.dropFirst(5).data(using: .utf8) {
              do {
                if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
                   let object = json["object"] as? String,
                   let eventObject = AssistantStreamEventObject(rawValue: object) {
                  switch eventObject {
                  case .threadMessageDelta:
                    let decoded = try self.decoder.decode(MessageDeltaObject.self, from: data)
                    continuation.yield(.threadMessageDelta(decoded))
                  case .threadRunStepDelta:
                    let decoded = try self.decoder.decode(RunStepDeltaObject.self, from: data)
                    continuation.yield(.threadRunStepDelta(decoded))
                  case .threadRun:
                    let decoded = try self.decoder.decode(RunObject.self, from: data)
                    switch RunObject.Status(rawValue: decoded.status) {
                    case .queued:
                      continuation.yield(.threadRunQueued(decoded))
                    case .inProgress:
                      continuation.yield(.threadRunInProgress(decoded))
                    case .requiresAction:
                      continuation.yield(.threadRunRequiresAction(decoded))
                    case .cancelling:
                      continuation.yield(.threadRunCancelling(decoded))
                    case .cancelled:
                      continuation.yield(.threadRunCancelled(decoded))
                    case .failed:
                      continuation.yield(.threadRunFailed(decoded))
                    case .completed:
                      continuation.yield(.threadRunCompleted(decoded))
                    case .expired:
                      continuation.yield(.threadRunExpired(decoded))
                    default:
                      #if DEBUG
                      if debugEnabled {
                        try print("DEBUG threadRun status not found = \(JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any])")
                      }
                      #endif
                    }
                  default:
                    #if DEBUG
                    if debugEnabled {
                      try print("DEBUG EVENT \(eventObject.rawValue) IGNORED = \(JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any])")
                    }
                    #endif
                  }
                } else {
                  #if DEBUG
                  if debugEnabled {
                    try print("DEBUG EVENT DECODE IGNORED = \(JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any])")
                  }
                  #endif
                }
              } catch DecodingError.keyNotFound(let key, let context) {
                #if DEBUG
                if debugEnabled {
                  try print("DEBUG Decoding Object Failed = \(JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any])")
                }
                #endif
                let debug = "Key '\(key.stringValue)' not found: \(context.debugDescription)"
                let codingPath = "codingPath: \(context.codingPath)"
                let debugMessage = debug + codingPath
                #if DEBUG
                if debugEnabled {
                  print(debugMessage)
                }
                #endif
                throw APIError.dataCouldNotBeReadMissingData(description: debugMessage)
              } catch {
                #if DEBUG
                if debugEnabled {
                  debugPrint("CONTINUATION ERROR DECODING \(error.localizedDescription)")
                }
                #endif
                continuation.finish(throwing: error)
              }
            }
          }
          continuation.finish()
        } catch DecodingError.keyNotFound(let key, let context) {
          let debug = "Key '\(key.stringValue)' not found: \(context.debugDescription)"
          let codingPath = "codingPath: \(context.codingPath)"
          let debugMessage = debug + codingPath
          #if DEBUG
          if debugEnabled {
            print(debugMessage)
          }
          #endif
          throw APIError.dataCouldNotBeReadMissingData(description: debugMessage)
        } catch {
          #if DEBUG
          if debugEnabled {
            print("CONTINUATION ERROR DECODING \(error.localizedDescription)")
          }
          #endif
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { @Sendable _ in
        task.cancel()
      }
    }
  }

  private func prettyPrintJSON(_ data: Data) -> String? {
    guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
          let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
          let prettyPrintedString = String(data: prettyData, encoding: .utf8)
    else { return nil }
    return prettyPrintedString
  }

  private func printCurlCommand(_ request: URLRequest) {
    guard let url = request.url, let httpMethod = request.httpMethod else {
      debugPrint("Invalid URL or HTTP method.")
      return
    }

    var baseCommand = "curl \(url.absoluteString)"

    if httpMethod != "GET" {
      baseCommand += " -X \(httpMethod)"
    }

    if let headers = request.allHTTPHeaderFields {
      for (header, value) in headers {
        let maskedValue = header.lowercased() == "authorization" ? maskAuthorizationToken(value) : value
        baseCommand += " \\\n-H \"\(header): \(maskedValue)\""
      }
    }

    if let httpBody = request.httpBody, let bodyString = prettyPrintJSON(httpBody) {
      baseCommand += " \\\n-d '\(bodyString)'"
    }

    #if DEBUG
    print(baseCommand)
    #endif
  }

  private func prettyPrintJSON(_ data: Data) -> String {
    guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
          let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
          let prettyPrintedString = String(data: prettyData, encoding: .utf8)
    else { return "Could not print JSON - invalid format" }
    return prettyPrintedString
  }

  private func printHTTPURLResponse(
    _ response: HTTPURLResponse,
    data: Data? = nil
  ) {
    #if DEBUG
    print("\n- - - - - - - - - - INCOMING RESPONSE - - - - - - - - - -\n")
    print("URL: \(response.url?.absoluteString ?? "No URL")")
    print("Status Code: \(response.statusCode)")
    print("Headers: \(response.allHeaderFields)")
    if let mimeType = response.mimeType {
      print("MIME Type: \(mimeType)")
    }
    if let data = data {
      if response.mimeType == "application/json" {
        print("Body: \(prettyPrintJSON(data))")
      } else if let bodyString = String(data: data, encoding: .utf8) {
        print("Body: \(bodyString)")
      }
    }
    print("\n- - - - - - - - - - - - - - - - - - - - - - - - - - - -\n")
    #endif
  }

  private func maskAuthorizationToken(_ token: String) -> String {
    if token.count > 6 {
      let prefix = String(token.prefix(3))
      let suffix = String(token.suffix(3))
      return "\(prefix)................\(suffix)"
    } else {
      return "INVALID TOKEN LENGTH"
    }
  }
}

extension OpenAIService {
  public func fetchAudioStream(
    debugEnabled: Bool,
    with request: URLRequest
  ) async throws -> AsyncThrowingStream<AudioSpeechChunkObject, Error> {
    if debugEnabled {
      printCurlCommand(request)
    }

    let (data, response) = try await session.bytes(
      for: request,
      delegate: session.delegate as? URLSessionTaskDelegate
    )
    
    guard let httpResponse = response as? HTTPURLResponse else {
      throw APIError.requestFailed(description: "invalid response unable to get a valid HTTPURLResponse")
    }
    
    if debugEnabled {
      printHTTPURLResponse(httpResponse)
    }
    
    guard httpResponse.statusCode == 200 else {
      var errorMessage = "status code \(httpResponse.statusCode)"
      var responseBody: String? = nil
      do {
        let errorData = try await data.reduce(into: Data()) { accumulator, byte in
          accumulator.append(byte)
        }
        let error = try decoder.decode(OpenAIErrorResponse.self, from: errorData)
        errorMessage += " \(error.error.message ?? "NO ERROR MESSAGE PROVIDED")"
        responseBody = String(data: errorData, encoding: .utf8)
      } catch {
        if let errorData = try? await data.reduce(into: Data()) { accumulator, byte in
          accumulator.append(byte)
        } {
          responseBody = String(data: errorData, encoding: .utf8)
          if let body = responseBody {
            errorMessage += " - Raw response: \(body)"
          }
        }
      }
      throw APIError.responseUnsuccessful(
        description: errorMessage,
        statusCode: httpResponse.statusCode,
        responseBody: responseBody)
    }
    
    return AsyncThrowingStream { continuation in
      let task = Task {
        do {
          var chunkIndex = 0
          var currentChunk = Data()
          let chunkSize = 4096
          
          for try await byte in data {
            currentChunk.append(byte)
            
            if currentChunk.count >= chunkSize {
              let audioChunk = AudioSpeechChunkObject(
                chunk: currentChunk,
                isLastChunk: false,
                chunkIndex: chunkIndex
              )
              continuation.yield(audioChunk)
              
              chunkIndex += 1
              currentChunk = Data()
              
              #if DEBUG
              if debugEnabled {
                print("DEBUG: Yielded audio chunk \(chunkIndex) with \(chunkSize) bytes")
              }
              #endif
            }
          }
          
          if !currentChunk.isEmpty {
            let audioChunk = AudioSpeechChunkObject(
              chunk: currentChunk,
              isLastChunk: false,
              chunkIndex: chunkIndex
            )
            continuation.yield(audioChunk)
            chunkIndex += 1
          }
          
          let finalChunk = AudioSpeechChunkObject(
            chunk: Data(),
            isLastChunk: true,
            chunkIndex: chunkIndex
          )
          continuation.yield(finalChunk)
          continuation.finish()
          
        } catch {
          #if DEBUG
          if debugEnabled {
            print("AUDIO STREAM ERROR: \(error.localizedDescription)")
          }
          #endif
          continuation.finish(throwing: error)
        }
      }
      
      continuation.onTermination = { @Sendable _ in
        task.cancel()
      }
    }
  }
}
