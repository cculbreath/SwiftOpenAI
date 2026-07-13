import XCTest
@testable import SwiftOpenAI

/// Guards the Anthropic extended-thinking streaming surface used by the live
/// reasoning overlay (voice profile, KC refinement, skills refine):
///   (A) `AnthropicThinking.adaptiveSummarized` sends `display: "summarized"` so the
///       server streams human-readable `thinking_delta` text (default is empty/omitted);
///   (B) the SSE decoder maps `thinking_delta` / `signature_delta` content-block deltas
///       onto typed cases instead of silently dropping them to `.unknown`.
final class AnthropicThinkingStreamTests: XCTestCase {

    // MARK: - Guard A: request-side display flag

    func testAdaptiveSummarizedEncodesDisplay() throws {
        let data = try JSONEncoder().encode(AnthropicThinking.adaptiveSummarized)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: String]
        XCTAssertEqual(obj?["type"], "adaptive")
        XCTAssertEqual(obj?["display"], "summarized")
    }

    func testAdaptiveOmitsDisplay() throws {
        let data = try JSONEncoder().encode(AnthropicThinking.adaptive)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: String]
        XCTAssertEqual(obj?["type"], "adaptive")
        XCTAssertNil(obj?["display"], "bare .adaptive must not send a display field")
    }

    // MARK: - Guard B: response-side delta decoding

    func testThinkingDeltaDecodes() throws {
        let json = #"{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"Weighing the tone of the samples"}}"#
        let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: Data(json.utf8))
        guard case .contentBlockDelta(let delta) = event else {
            return XCTFail("expected .contentBlockDelta, got \(event)")
        }
        guard case .thinkingDelta(let text) = delta.delta else {
            return XCTFail("expected .thinkingDelta, got \(delta.delta)")
        }
        XCTAssertEqual(text, "Weighing the tone of the samples")
        XCTAssertEqual(delta.delta.thinking, "Weighing the tone of the samples")
    }

    func testSignatureDeltaDecodes() throws {
        let json = #"{"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"abc123=="}}"#
        let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: Data(json.utf8))
        guard case .contentBlockDelta(let delta) = event,
              case .signatureDelta(let sig) = delta.delta else {
            return XCTFail("expected .signatureDelta, got \(event)")
        }
        XCTAssertEqual(sig, "abc123==")
    }

    func testTextDeltaStillDecodes() throws {
        let json = #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"{\"tone\":"}}"#
        let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: Data(json.utf8))
        guard case .contentBlockDelta(let delta) = event,
              case .textDelta(let text) = delta.delta else {
            return XCTFail("expected .textDelta, got \(event)")
        }
        XCTAssertEqual(text, "{\"tone\":")
    }
}
