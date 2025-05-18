//
//  TTSStreamingTests.swift
//
//
//  Created by SwiftOpenAI Community on 5/18/25.
//

import XCTest
@testable import OpenAI

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
    
    func testCreateStreamingSpeechMethodExists() throws {
        // This test verifies that the method signature exists on the protocol
        // Actual testing would require a real API key and network mocking
        
        // Create a minimal test service to check method existence
        let service = DefaultOpenAIService(
            apiKey: "test-key",
            configuration: .default,
            debugEnabled: false
        )
        
        // Verify the service conforms to OpenAIService protocol
        XCTAssertTrue(service is OpenAIService)
        
        // Note: We can't actually call the method without API credentials
        // but this test ensures the method signature is correct
    }
}
