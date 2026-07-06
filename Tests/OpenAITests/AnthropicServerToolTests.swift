import XCTest
@testable import SwiftOpenAI

/// Guards the Anthropic server-side web tools (web_search / web_fetch):
///   (A) tool declarations ship the exact snake_case keys, lexicographically
///       sorted, and a mixed tools array (function + web_search + web_fetch)
///       leaves the function-tool wire bytes byte-identical — the prompt-cache
///       prefix must not shift when server tools are appended;
///   (B) the new content blocks (server_tool_use, web_search_tool_result,
///       web_fetch_tool_result) round-trip decode→encode BYTE-FAITHFULLY —
///       agentic loops echo assistant content (including encrypted_content and
///       fetched documents) back verbatim in the next request;
///   (C) stop_reason "pause_turn" passes through undamaged (String passthrough,
///       nothing filters unknown values);
///   (D) content_block_start carries the new block types, and server_tool_use
///       input streams via input_json_delta like regular tool_use.
///
/// Fixture strings are in the canonical form `AnthropicRequestBody.encode`
/// produces: sorted keys, no whitespace, forward slashes escaped as `\/`
/// (raw string literals keep the `\/` verbatim). JSONDecoder reads both forms.
final class AnthropicServerToolTests: XCTestCase {

    // MARK: - Helpers

    private func encodedString(tools: [AnthropicTool]) throws -> String {
        let param = AnthropicMessageParameter(model: "m", messages: [], maxTokens: 1, tools: tools)
        let data = try AnthropicRequestBody.encode(param)
        return String(decoding: data, as: UTF8.self)
    }

    /// Encodes a request with exactly one tool and returns that tool's JSON object.
    private func soloToolJSON(_ tool: AnthropicTool, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let json = try encodedString(tools: [tool])
        let start = try XCTUnwrap(json.range(of: "\"tools\":["), "tools array missing", file: file, line: line).upperBound
        let end = json.index(json.endIndex, offsetBy: -2) // strip trailing "]}"
        return String(json[start..<end])
    }

    /// Decodes a content block from canonical wire JSON, re-encodes it through the
    /// sanctioned request serializer, and asserts the bytes are identical.
    @discardableResult
    private func assertByteFaithfulRoundTrip(_ wire: String, file: StaticString = #filePath, line: UInt = #line) throws -> AnthropicContentBlock {
        let block = try JSONDecoder().decode(AnthropicContentBlock.self, from: Data(wire.utf8))
        let reencoded = String(decoding: try AnthropicRequestBody.encode(block), as: UTF8.self)
        XCTAssertEqual(reencoded, wire, "echoed block must re-encode byte-identically", file: file, line: line)
        return block
    }

    // MARK: - Guard A: server tool declarations

    func testWebSearchToolEncodesExpectedWireShape() throws {
        let tool = AnthropicTool.serverTool(.webSearch(
            maxUses: 3,
            allowedDomains: ["eventbrite.com", "meetup.com"],
            userLocation: AnthropicUserLocation(
                city: "Cupertino", region: "California", country: "US", timezone: "America/Los_Angeles")))

        let expected = #"{"allowed_domains":["eventbrite.com","meetup.com"],"max_uses":3,"name":"web_search","type":"web_search_20260209","user_location":{"city":"Cupertino","country":"US","region":"California","timezone":"America\/Los_Angeles","type":"approximate"}}"#
        XCTAssertEqual(try soloToolJSON(tool), expected)
    }

    func testWebFetchToolEncodesExpectedWireShape() throws {
        let tool = AnthropicTool.serverTool(.webFetch(
            maxUses: 2,
            blockedDomains: ["paywalled.example"],
            citations: AnthropicCitationsConfig(enabled: true),
            maxContentTokens: 20000))

        let expected = #"{"blocked_domains":["paywalled.example"],"citations":{"enabled":true},"max_content_tokens":20000,"max_uses":2,"name":"web_fetch","type":"web_fetch_20260209"}"#
        XCTAssertEqual(try soloToolJSON(tool), expected)
    }

    func testDefaultFactoriesEmitOnlyTypeAndName() throws {
        XCTAssertEqual(try soloToolJSON(.serverTool(.webSearch())),
                       #"{"name":"web_search","type":"web_search_20260209"}"#)
        XCTAssertEqual(try soloToolJSON(.serverTool(.webFetch())),
                       #"{"name":"web_fetch","type":"web_fetch_20260209"}"#)
    }

    func testOlderToolVariantTypesAreCallerSuppliable() throws {
        XCTAssertEqual(try soloToolJSON(.serverTool(.webSearch(type: "web_search_20250305"))),
                       #"{"name":"web_search","type":"web_search_20250305"}"#)
        XCTAssertEqual(try soloToolJSON(.serverTool(.webFetch(type: "web_fetch_20250910"))),
                       #"{"name":"web_fetch","type":"web_fetch_20250910"}"#)
    }

    func testMixedToolsArrayLeavesFunctionToolBytesUnchanged() throws {
        let function = AnthropicFunctionTool(
            name: "record_events",
            description: "Record discovered networking events",
            inputSchema: [
                "type": "object",
                "properties": [
                    "eventName": ["type": "string"],
                    "startsAt": ["type": "string"],
                ],
                "required": ["eventName", "startsAt"],
                "additionalProperties": false,
            ],
            strict: true)

        // The function tool's bytes when it is the only tool...
        let functionJSON = try soloToolJSON(.function(function))

        // ...must appear verbatim (and first) when server tools are appended.
        let mixed = try encodedString(tools: [
            .function(function),
            .serverTool(.webSearch()),
            .serverTool(.webFetch()),
        ])
        XCTAssertTrue(mixed.contains("\"tools\":[" + functionJSON + ","),
                      "function-tool bytes must be unchanged and first in the mixed tools array")
        XCTAssertTrue(mixed.contains(#"{"name":"web_search","type":"web_search_20260209"}"#))
        XCTAssertTrue(mixed.contains(#"{"name":"web_fetch","type":"web_fetch_20260209"}"#))
    }

    // MARK: - Guard B: content block round-trips (multi-turn echo)

    func testServerToolUseBlockRoundTrip() throws {
        let wire = #"{"id":"srvtoolu_01A","input":{"query":"sf tech networking events july 2026"},"name":"web_search","type":"server_tool_use"}"#
        let block = try assertByteFaithfulRoundTrip(wire)

        guard case .serverToolUse(let serverToolUse) = block else {
            return XCTFail("expected .serverToolUse, got \(block)")
        }
        XCTAssertEqual(serverToolUse.id, "srvtoolu_01A")
        XCTAssertEqual(serverToolUse.name, "web_search")
        XCTAssertEqual(serverToolUse.input["query"]?.value as? String, "sf tech networking events july 2026")
    }

    func testWebSearchToolResultResultsRoundTrip() throws {
        let wire = #"{"content":[{"encrypted_content":"EqgfCioIABiwOpaque1","page_age":"January 3, 2026","title":"SF Tech Mixers","type":"web_search_result","url":"https:\/\/example.com\/events"},{"encrypted_content":"Ep8dCkoQOpaque2","title":"Meetup Calendar","type":"web_search_result","url":"https:\/\/example.org\/calendar"}],"tool_use_id":"srvtoolu_01A","type":"web_search_tool_result"}"#
        let block = try assertByteFaithfulRoundTrip(wire)

        guard case .webSearchToolResult(let result) = block,
              case .results(let results) = result.content else {
            return XCTFail("expected .webSearchToolResult with results, got \(block)")
        }
        XCTAssertEqual(result.toolUseId, "srvtoolu_01A")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].encryptedContent, "EqgfCioIABiwOpaque1")
        XCTAssertEqual(results[0].pageAge, "January 3, 2026")
        XCTAssertEqual(results[0].url, "https://example.com/events")
        XCTAssertNil(results[1].pageAge, "absent page_age must stay absent (not null) on re-encode")
    }

    func testWebSearchToolResultErrorRoundTrip() throws {
        let wire = #"{"content":{"error_code":"max_uses_exceeded","type":"web_search_tool_result_error"},"tool_use_id":"srvtoolu_01A","type":"web_search_tool_result"}"#
        let block = try assertByteFaithfulRoundTrip(wire)

        guard case .webSearchToolResult(let result) = block,
              case .error(let error) = result.content else {
            return XCTFail("expected .webSearchToolResult with error, got \(block)")
        }
        XCTAssertEqual(error.errorCode, "max_uses_exceeded")
    }

    func testWebFetchToolResultDocumentRoundTrip() throws {
        let wire = #"{"content":{"content":{"citations":{"enabled":true},"source":{"data":"RSVP by July 10. Doors at 6pm.","media_type":"text\/plain","type":"text"},"title":"Event Details","type":"document"},"retrieved_at":"2026-07-06T12:00:00Z","type":"web_fetch_result","url":"https:\/\/example.com\/event\/42"},"tool_use_id":"srvtoolu_02B","type":"web_fetch_tool_result"}"#
        let block = try assertByteFaithfulRoundTrip(wire)

        guard case .webFetchToolResult(let result) = block,
              case .fetchResult(let fetched) = result.content else {
            return XCTFail("expected .webFetchToolResult with fetch result, got \(block)")
        }
        XCTAssertEqual(result.toolUseId, "srvtoolu_02B")
        XCTAssertEqual(fetched.url, "https://example.com/event/42")
        XCTAssertEqual(fetched.retrievedAt, "2026-07-06T12:00:00Z")
        XCTAssertEqual(fetched.content.title, "Event Details")
        XCTAssertEqual(fetched.content.citations?.enabled, true)
        guard case .text(let mediaType, let data) = fetched.content.source else {
            return XCTFail("expected plain-text document source, got \(fetched.content.source)")
        }
        XCTAssertEqual(mediaType, "text/plain")
        XCTAssertEqual(data, "RSVP by July 10. Doors at 6pm.")
    }

    func testWebFetchToolResultErrorRoundTrip() throws {
        let wire = #"{"content":{"error_code":"url_not_accessible","type":"web_fetch_tool_result_error"},"tool_use_id":"srvtoolu_02B","type":"web_fetch_tool_result"}"#
        let block = try assertByteFaithfulRoundTrip(wire)

        guard case .webFetchToolResult(let result) = block,
              case .error(let error) = result.content else {
            return XCTFail("expected .webFetchToolResult with error, got \(block)")
        }
        XCTAssertEqual(error.errorCode, "url_not_accessible")
    }

    // MARK: - Guard C: pause_turn passthrough

    func testPauseTurnStopReasonDecodesFromMessageDelta() throws {
        let sse = #"{"delta":{"stop_reason":"pause_turn","stop_sequence":null},"type":"message_delta","usage":{"output_tokens":31}}"#
        let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: Data(sse.utf8))
        XCTAssertEqual(event.stopReason, "pause_turn")
    }

    func testPauseTurnResponseWithServerToolBlocksDecodes() throws {
        let json = #"""
        {"id":"msg_01","type":"message","role":"assistant","model":"claude-x","content":[{"type":"text","text":"Searching for events."},{"type":"server_tool_use","id":"srvtoolu_01A","name":"web_search","input":{"query":"events"}},{"type":"web_search_tool_result","tool_use_id":"srvtoolu_01A","content":[{"type":"web_search_result","url":"https://example.com","title":"T","encrypted_content":"EqES"}]}],"stop_reason":"pause_turn","stop_sequence":null,"usage":{"input_tokens":100,"output_tokens":50,"server_tool_use":{"web_search_requests":1}}}
        """#
        let response = try JSONDecoder().decode(AnthropicMessageResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.stopReason, "pause_turn")
        XCTAssertEqual(response.content.count, 3)
        guard case .serverToolUse(let serverToolUse) = response.content[1] else {
            return XCTFail("expected .serverToolUse at index 1")
        }
        XCTAssertEqual(serverToolUse.name, "web_search")
        guard case .webSearchToolResult(let result) = response.content[2],
              case .results(let results) = result.content else {
            return XCTFail("expected .webSearchToolResult with results at index 2")
        }
        XCTAssertEqual(results.first?.encryptedContent, "EqES")
        XCTAssertEqual(response.usage.serverToolUse?.webSearchRequests, 1)
    }

    // MARK: - Guard D: streaming

    func testContentBlockStartWithServerToolUseDecodes() throws {
        let sse = #"{"content_block":{"id":"srvtoolu_01A","input":{},"name":"web_search","type":"server_tool_use"},"index":1,"type":"content_block_start"}"#
        let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: Data(sse.utf8))

        guard case .contentBlockStart(let start) = event else {
            return XCTFail("expected .contentBlockStart, got \(event)")
        }
        XCTAssertEqual(start.contentBlock.type, "server_tool_use")
        XCTAssertTrue(event.isServerToolUseStart)
        XCTAssertEqual(event.serverToolUseInfo?.id, "srvtoolu_01A")
        XCTAssertEqual(event.serverToolUseInfo?.name, "web_search")
        // Server tools must NOT look like client tool calls — nothing should
        // dispatch them to a local tool executor.
        XCTAssertFalse(event.isToolUseStart)
        XCTAssertNil(event.toolUseInfo?.id)
    }

    func testServerToolUseInputStreamsViaInputJsonDelta() throws {
        let sse = #"{"delta":{"partial_json":"{\"query\": \"tech","type":"input_json_delta"},"index":1,"type":"content_block_delta"}"#
        let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: Data(sse.utf8))
        XCTAssertTrue(event.isToolInputDelta)
        XCTAssertEqual(event.toolInputPartialJson, "{\"query\": \"tech")
    }

    func testContentBlockStartWithWebSearchToolResultDecodes() throws {
        let sse = #"{"content_block":{"content":[{"encrypted_content":"Eq","title":"T","type":"web_search_result","url":"https://example.com"}],"tool_use_id":"srvtoolu_01A","type":"web_search_tool_result"},"index":2,"type":"content_block_start"}"#
        let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: Data(sse.utf8))

        guard case .contentBlockStart(let start) = event else {
            return XCTFail("expected .contentBlockStart, got \(event)")
        }
        XCTAssertEqual(start.contentBlock.type, "web_search_tool_result")
        XCTAssertEqual(start.contentBlock.toolUseId, "srvtoolu_01A")
        guard case .webSearch(.results(let results))? = start.contentBlock.content else {
            return XCTFail("expected web search results content")
        }
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].encryptedContent, "Eq")
    }

    func testContentBlockStartWithWebFetchToolResultDecodes() throws {
        let sse = #"{"content_block":{"content":{"content":{"source":{"data":"Body","media_type":"text/plain","type":"text"},"type":"document"},"type":"web_fetch_result","url":"https://example.com/p"},"tool_use_id":"srvtoolu_02B","type":"web_fetch_tool_result"},"index":3,"type":"content_block_start"}"#
        let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: Data(sse.utf8))

        guard case .contentBlockStart(let start) = event else {
            return XCTFail("expected .contentBlockStart, got \(event)")
        }
        XCTAssertEqual(start.contentBlock.type, "web_fetch_tool_result")
        XCTAssertEqual(start.contentBlock.toolUseId, "srvtoolu_02B")
        guard case .webFetch(.fetchResult(let fetched))? = start.contentBlock.content else {
            return XCTFail("expected web fetch result content")
        }
        XCTAssertEqual(fetched.url, "https://example.com/p")
        guard case .text(_, let data) = fetched.content.source else {
            return XCTFail("expected plain-text document source")
        }
        XCTAssertEqual(data, "Body")
    }

    func testContentBlockStartWithTextBlockStillDecodes() throws {
        // Regression guard for the custom AnthropicStreamContentBlock decode:
        // plain text block starts must be unaffected.
        let sse = #"{"content_block":{"text":"","type":"text"},"index":0,"type":"content_block_start"}"#
        let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: Data(sse.utf8))

        guard case .contentBlockStart(let start) = event else {
            return XCTFail("expected .contentBlockStart, got \(event)")
        }
        XCTAssertEqual(start.contentBlock.type, "text")
        XCTAssertEqual(start.contentBlock.text, "")
        XCTAssertNil(start.contentBlock.toolUseId)
        XCTAssertNil(start.contentBlock.content)
    }

    func testWebSearchToolResultErrorContentBlockStartDecodes() throws {
        // Error variant also arrives via content_block_start — branch on object shape.
        let sse = #"{"content_block":{"content":{"error_code":"too_many_requests","type":"web_search_tool_result_error"},"tool_use_id":"srvtoolu_01A","type":"web_search_tool_result"},"index":2,"type":"content_block_start"}"#
        let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: Data(sse.utf8))

        guard case .contentBlockStart(let start) = event,
              case .webSearch(.error(let error))? = start.contentBlock.content else {
            return XCTFail("expected web search error content")
        }
        XCTAssertEqual(error.errorCode, "too_many_requests")
    }
}
