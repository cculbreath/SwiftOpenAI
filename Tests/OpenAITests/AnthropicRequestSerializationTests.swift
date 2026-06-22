import XCTest
@testable import SwiftOpenAI

/// Guards the Anthropic request-body serialization seam — the one that historically
/// only surfaced bugs at runtime. A tool `input_schema` is a Swift `Dictionary`, so
/// it must ship through `AnthropicRequestBody.encode` (the single sanctioned
/// serializer) with:
///   (A) our camelCase keys + the JSON-Schema keyword `additionalProperties` VERBATIM
///       (no snake_case mangling), and `strict` emitted only when set; and
///   (C) object keys lexicographically SORTED, so the rendered request — and thus
///       Anthropic's prompt-cache prefix — is byte-stable across process launches.
/// The prior wire test (`AnthropicMessagesServiceTests.wireObject`) used a bare
/// `JSONEncoder`, so neither property was covered.
final class AnthropicRequestSerializationTests: XCTestCase {

    private func encodedString(tools: [AnthropicTool]) throws -> String {
        let param = AnthropicMessageParameter(model: "m", messages: [], maxTokens: 1, tools: tools)
        let data = try AnthropicRequestBody.encode(param)
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Guard A: strict tool schema ships camelCase + additionalProperties verbatim

    func testStrictToolSchemaShipsCamelCaseAndAdditionalPropertiesVerbatim() throws {
        // A complete_analysis-shaped schema: nested objects, camelCase param names,
        // a nullable type-array, `additionalProperties` at every object level.
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "dependencyUsage": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "importCount": ["type": "integer"],
                            "usageNotes": ["type": "string"],
                        ],
                        "required": ["importCount", "usageNotes"],
                        "additionalProperties": false,
                    ],
                ],
                "codeExcerpts": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "lineRange": ["type": ["string", "null"]],
                            "tiedToClaim": ["type": ["string", "null"]],
                            "excerpt": ["type": "string"],
                        ],
                        "required": ["lineRange", "tiedToClaim", "excerpt"],
                        "additionalProperties": false,
                    ],
                ],
                "productionQuality": [
                    "type": "object",
                    "properties": [
                        "infraAndDeploy": ["type": "string"],
                    ],
                    "required": ["infraAndDeploy"],
                    "additionalProperties": false,
                ],
            ],
            "required": ["dependencyUsage", "codeExcerpts", "productionQuality"],
            "additionalProperties": false,
        ]
        let tool = AnthropicFunctionTool(name: "complete_analysis", inputSchema: schema, strict: true)
        let json = try encodedString(tools: [.function(tool)])

        // `additionalProperties` survives verbatim (camelCase JSON-Schema keyword) — NOT snake-cased.
        XCTAssertTrue(json.contains("\"additionalProperties\":false"), "additionalProperties must ship camelCase")
        XCTAssertFalse(json.contains("additional_properties"), "the JSON-Schema keyword must not be snake-cased")

        // Our camelCase param names ship verbatim — schema keys are NOT translated.
        for camel in ["importCount", "usageNotes", "lineRange", "tiedToClaim", "infraAndDeploy"] {
            XCTAssertTrue(json.contains("\"\(camel)\""), "\(camel) must ship verbatim")
        }
        for snake in ["import_count", "usage_notes", "line_range", "tied_to_claim", "infra_and_deploy"] {
            XCTAssertFalse(json.contains(snake), "\(snake) must NOT appear — .convertToSnakeCase must not reach schema dicts")
        }

        // strict tool-use opt-in is emitted.
        XCTAssertTrue(json.contains("\"strict\":true"), "strict:true must be emitted when set")

        // Nullable type-array is preserved (arrays keep order; only object keys are sorted).
        XCTAssertTrue(json.contains("[\"string\",\"null\"]"), "nullable type ['string','null'] must survive verbatim")
    }

    func testNonStrictToolOmitsStrictKey() throws {
        // `strict` is nil by default -> encodeIfPresent omits it -> byte-identical to pre-change,
        // so non-strict tools (and the whole onboarding interview) keep a stable cache prefix.
        let tool = AnthropicFunctionTool(name: "read_file", inputSchema: ["type": "object", "additionalProperties": false])
        let json = try encodedString(tools: [.function(tool)])
        XCTAssertFalse(json.contains("\"strict\""), "non-strict tools must not emit a strict key")
    }

    // MARK: - Guard C: dict-backed keys are SORTED on the wire (prompt-cache stability)

    func testDynamicSchemaDictKeysAreSortedForCacheStability() throws {
        // `input_schema` is a Swift Dictionary -> per-process-randomized iteration order.
        // `.sortedKeys` must impose a lexicographic order on the wire so the rendered request
        // (and Anthropic's prompt-cache prefix) is byte-stable across process launches. Author
        // keys deliberately OUT of order, then assert sorted output. (Encode-twice equality can't
        // catch a dropped `.sortedKeys`: Dictionary order is stable *within* a process — only the
        // sortedness assertion below pins it.)
        let unsorted = ["hotelField", "alphaField", "golfField", "bravoField",
                        "foxtrotField", "charlieField", "echoField", "deltaField"]
        var properties: [String: Any] = [:]
        for key in unsorted { properties[key] = ["type": "string"] }
        let schema: [String: Any] = [
            "type": "object",
            "properties": properties,
            "additionalProperties": false,
        ]
        let tool = AnthropicFunctionTool(name: "t", inputSchema: schema)
        let json = try encodedString(tools: [.function(tool)])

        // Each key appears exactly once (properties key only). Their wire offsets, taken in
        // sorted-key order, must be ascending — i.e. the keys are emitted lexicographically sorted.
        var offsets: [Int] = []
        for key in unsorted.sorted() {
            let range = try XCTUnwrap(json.range(of: "\"\(key)\""), "\(key) missing from wire")
            offsets.append(json.distance(from: json.startIndex, to: range.lowerBound))
        }
        XCTAssertEqual(offsets, offsets.sorted(),
                       "schema dict keys must be lexicographically sorted on the wire (.sortedKeys)")
    }

    func testEncodingIsDeterministic() throws {
        // Sanity: identical requests encode to identical bytes (no timestamp/UUID/unstable encoder
        // config leaking into the body). Cross-process stability is pinned by the sorted-keys test.
        func body() throws -> Data {
            let tool = AnthropicFunctionTool(
                name: "t",
                inputSchema: ["type": "object",
                              "properties": ["b": ["type": "string"], "a": ["type": "string"]],
                              "additionalProperties": false],
                strict: true)
            return try AnthropicRequestBody.encode(
                AnthropicMessageParameter(model: "m", messages: [], maxTokens: 1, tools: [.function(tool)]))
        }
        XCTAssertEqual(try body(), try body(), "identical request must encode to identical bytes")
    }
}
