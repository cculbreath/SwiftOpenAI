//
//  TTSStreamingTests.swift
//
//
//  Created by SwiftOpenAI Community on 5/18/25.
//

import XCTest
@testable import SwiftOpenAI

final class TTSStreamingTests: XCTestCase {

    func testAudioSpeechParametersWithStreaming() throws {
        // Test that AudioSpeechParameters includes stream parameter
        let parameters = AudioSpeechParameters(
            model: .tts1,
            input: "Hello, this is a test",
            voice: .alloy,
            stream: true
        )

        // Verify the parameters were set correctly
        XCTAssertEqual(parameters.input, "Hello, this is a test")
        XCTAssertEqual(parameters.voice, "alloy")
        XCTAssertEqual(parameters.stream, true)
    }

    func testAudioSpeechChunkObject() throws {
        // Test AudioSpeechChunkObject creation
        let testData = "test audio data".data(using: .utf8)!
        let chunk = AudioSpeechChunkObject(
            chunk: testData,
            isLastChunk: false,
            chunkIndex: 1
        )

        XCTAssertEqual(chunk.chunk, testData)
        XCTAssertFalse(chunk.isLastChunk)
        XCTAssertEqual(chunk.chunkIndex, 1)
    }

    func testAudioSpeechChunkObjectFinalChunk() throws {
        // Test final chunk creation
        let finalChunk = AudioSpeechChunkObject(
            chunk: Data(),
            isLastChunk: true,
            chunkIndex: 10
        )

        XCTAssertTrue(finalChunk.chunk.isEmpty)
        XCTAssertTrue(finalChunk.isLastChunk)
        XCTAssertEqual(finalChunk.chunkIndex, 10)
    }
}
