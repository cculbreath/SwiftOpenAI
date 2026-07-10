import XCTest
@testable import SwiftOpenAI

/// Guards the Anthropic Message Batches wire contract: the batch request body
/// must go through the sanctioned `.convertToSnakeCase` + `.sortedKeys`
/// serializer (so `customId` → `custom_id`, nested params snake-case, bytes
/// stable), and the response/JSONL-result shapes must decode with a plain
/// decoder (explicit snake_case CodingKeys).
final class AnthropicBatchTests: XCTestCase {

    // MARK: - Encode

    func testBatchRequestBodySerializesCustomIdAndNestedParams() throws {
        let params = AnthropicMessageParameter(model: "claude-x", messages: [.user("hi")], maxTokens: 7)
        let batch = AnthropicMessageBatchParameter(requests: [
            .init(customId: "dossier-synth-1", params: params),
        ])
        let json = String(decoding: try AnthropicRequestBody.encode(batch), as: UTF8.self)

        XCTAssertTrue(json.contains("\"custom_id\":\"dossier-synth-1\""), "customId must snake_case to custom_id")
        XCTAssertTrue(json.contains("\"requests\":["), "requests array must be present")
        XCTAssertTrue(json.contains("\"max_tokens\":7"), "nested params must snake_case (max_tokens)")
        XCTAssertFalse(json.contains("customId"), "camelCase customId must not appear on the wire")
    }

    func testBatchRequestEncodingIsDeterministic() throws {
        func body() throws -> Data {
            let params = AnthropicMessageParameter(model: "m", messages: [.user("x")], maxTokens: 1)
            return try AnthropicRequestBody.encode(
                AnthropicMessageBatchParameter(requests: [.init(customId: "c", params: params)]))
        }
        XCTAssertEqual(try body(), try body(), "identical batch request must encode to identical bytes")
    }

    // MARK: - Decode

    func testBatchResponseDecodesProcessingStatusAndResultsUrl() throws {
        let json = """
        { "id": "msgbatch_1", "type": "message_batch", "processing_status": "ended",
          "results_url": "https://api.anthropic.com/v1/messages/batches/msgbatch_1/results",
          "request_counts": { "processing": 0, "succeeded": 1, "errored": 0, "canceled": 0, "expired": 0 } }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnthropicMessageBatchResponse.self, from: json)

        XCTAssertEqual(decoded.id, "msgbatch_1")
        XCTAssertEqual(decoded.processingStatus, "ended")
        XCTAssertEqual(decoded.resultsUrl, "https://api.anthropic.com/v1/messages/batches/msgbatch_1/results")
        XCTAssertEqual(decoded.requestCounts?.succeeded, 1)
    }

    func testInProgressBatchHasNilResultsUrl() throws {
        let json = """
        { "id": "msgbatch_2", "type": "message_batch", "processing_status": "in_progress", "results_url": null }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnthropicMessageBatchResponse.self, from: json)

        XCTAssertEqual(decoded.processingStatus, "in_progress")
        XCTAssertNil(decoded.resultsUrl)
    }

    func testBatchResultLineDecodesSucceededMessage() throws {
        let json = """
        { "custom_id": "dossier-synth-1", "result": { "type": "succeeded", "message": { "id": "msg_1", "type": "message", "role": "assistant", "content": [ { "type": "text", "text": "hello" } ], "model": "claude-x", "stop_reason": "end_turn", "stop_sequence": null, "usage": { "input_tokens": 5, "output_tokens": 3 } } } }
        """.data(using: .utf8)!
        let line = try JSONDecoder().decode(AnthropicMessageBatchResultLine.self, from: json)

        XCTAssertEqual(line.customId, "dossier-synth-1")
        XCTAssertEqual(line.result.type, "succeeded")
        XCTAssertEqual(line.result.message?.content.count, 1)
        XCTAssertEqual(line.result.message?.usage.outputTokens, 3)
    }

    /// An errored result line carries the API's nested error envelope — decode
    /// it (real wire shape captured from a live failed batch) so callers can
    /// log WHY a request errored instead of a blind "no usable result".
    func testBatchResultLineDecodesErroredDetail() throws {
        let json = """
        { "custom_id": "dossier", "result": { "type": "errored", "error": { "type": "error", "error": { "details": { "error_visibility": "user_facing" }, "type": "invalid_request_error", "message": "`stream=True` is not supported in the Message Batches API" }, "request_id": null } } }
        """.data(using: .utf8)!
        let line = try JSONDecoder().decode(AnthropicMessageBatchResultLine.self, from: json)

        XCTAssertEqual(line.result.type, "errored")
        XCTAssertNil(line.result.message)
        XCTAssertEqual(line.result.error?.error?.type, "invalid_request_error")
        XCTAssertEqual(line.result.error?.describe,
                       "invalid_request_error: `stream=True` is not supported in the Message Batches API")
    }

    // MARK: - Stream normalization

    /// The Batch API rejects `stream=true` outright, and
    /// `AnthropicMessageParameter.init` DEFAULTS stream to true — so the batch
    /// Request initializer must force it false or a caller who forgets the
    /// override has every batched request errored (this shipped: the dossier
    /// synthesis batch failed on exactly this for its entire first day).
    func testBatchRequestForcesStreamFalse() throws {
        let defaultParams = AnthropicMessageParameter(model: "m", messages: [.user("x")], maxTokens: 1)
        XCTAssertTrue(defaultParams.stream, "precondition: the standalone default is stream=true")

        let batch = AnthropicMessageBatchParameter(requests: [
            .init(customId: "c", params: defaultParams),
            .init(customId: "d", params: AnthropicMessageParameter(
                model: "m", messages: [.user("y")], maxTokens: 1, stream: true)),
        ])
        XCTAssertFalse(batch.requests[0].params.stream)
        XCTAssertFalse(batch.requests[1].params.stream, "even an explicit stream=true is normalized")

        let json = String(decoding: try AnthropicRequestBody.encode(batch), as: UTF8.self)
        XCTAssertFalse(json.contains("\"stream\":true"), "no batched request may carry stream=true")
    }
}
