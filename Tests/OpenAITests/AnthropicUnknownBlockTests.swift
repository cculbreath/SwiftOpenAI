import XCTest
@testable import SwiftOpenAI

/// Guards tolerant decoding of unmodeled content block types:
///   (A) a response containing a block type this client doesn't model
///       (`code_execution_tool_result` was the first observed in the wild —
///       it appeared in responses that declared only web_fetch) decodes into
///       `.unknown` instead of failing the WHOLE response decode, which killed
///       entire agent runs;
///   (B) the unknown block round-trips decode→encode BYTE-FAITHFULLY through
///       the sanctioned request serializer, so agentic loops can echo an
///       assistant turn containing it back verbatim without understanding it.
///
/// Fixture strings are in the canonical form `AnthropicRequestBody.encode`
/// produces: sorted keys, no whitespace, forward slashes escaped as `\/`.
final class AnthropicUnknownBlockTests: XCTestCase {

    // MARK: - Guard A: response decode survives unknown block types

    func testResponseWithUnknownBlockTypeDecodes() throws {
        let json = """
        {"id":"msg_01","type":"message","role":"assistant","model":"claude-opus-4-8",
         "content":[
           {"type":"text","text":"Looking at the posting now."},
           {"type":"code_execution_tool_result","tool_use_id":"srvtoolu_01","content":{"type":"code_execution_result","stdout":"parsed 3 postings","stderr":"","return_code":0}},
           {"type":"tool_use","id":"toolu_01","name":"recommend_jobs","input":{"recommendations":[]}}
         ],
         "stop_reason":"tool_use","stop_sequence":null,
         "usage":{"input_tokens":100,"output_tokens":50}}
        """
        let response = try JSONDecoder().decode(AnthropicMessageResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.content.count, 3, "every block survives, including the unknown one")
        guard case .unknown(let block) = response.content[1] else {
            return XCTFail("index 1 should decode as .unknown, got \(response.content[1])")
        }
        XCTAssertEqual(block.type, "code_execution_tool_result")
        // The neighbors decode as their modeled types — tolerance is per-block.
        guard case .text = response.content[0] else { return XCTFail("index 0 should stay .text") }
        guard case .toolUse(let call) = response.content[2] else { return XCTFail("index 2 should stay .toolUse") }
        XCTAssertEqual(call.name, "recommend_jobs")
    }

    // MARK: - Guard B: byte-faithful echo of the unknown block

    func testUnknownBlockRoundTripsByteFaithfully() throws {
        // Canonical form (sorted keys, no whitespace) covering nesting, arrays,
        // string/int/bool/null leaves — everything AnthropicDynamicValue carries.
        let wire = #"{"content":{"return_code":0,"stderr":null,"stdout":"ok","truncated":false},"nested":[1,"two",{"three":3}],"tool_use_id":"srvtoolu_01","type":"code_execution_tool_result"}"#

        let block = try JSONDecoder().decode(AnthropicContentBlock.self, from: Data(wire.utf8))
        guard case .unknown(let unknownBlock) = block else {
            return XCTFail("unmodeled type should decode as .unknown, got \(block)")
        }
        XCTAssertEqual(unknownBlock.type, "code_execution_tool_result")

        let reencoded = String(decoding: try AnthropicRequestBody.encode(block), as: UTF8.self)
        XCTAssertEqual(reencoded, wire, "echoed unknown block must re-encode byte-identically")
    }

    func testUnknownResponseBlockEchoesThroughRequestEncoding() throws {
        // The response-side decode and the request-side echo agree: decoding the
        // same object via AnthropicResponseContentBlock produces an unknown block
        // whose raw payload encodes to the same canonical bytes.
        let wire = #"{"payload":{"a":1},"type":"some_future_block"}"#
        let responseBlock = try JSONDecoder().decode(AnthropicResponseContentBlock.self, from: Data(wire.utf8))
        guard case .unknown(let unknownBlock) = responseBlock else {
            return XCTFail("should decode as .unknown, got \(responseBlock)")
        }
        let echoed = AnthropicContentBlock.unknown(unknownBlock)
        let reencoded = String(decoding: try AnthropicRequestBody.encode(echoed), as: UTF8.self)
        XCTAssertEqual(reencoded, wire)
    }
}
