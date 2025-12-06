//
//  AudioSpeechChunkObject.swift
//
//
//  Created by SwiftOpenAI Community on 5/18/25.
//

import Foundation

/// A single chunk of streaming audio data from the TTS API
public struct AudioSpeechChunkObject {
    /// The audio chunk data
    public let chunk: Data
    
    /// Indicates if this is the final chunk
    public let isLastChunk: Bool
    
    /// Optional metadata about the chunk
    public let chunkIndex: Int?
    
    public init(chunk: Data, isLastChunk: Bool = false, chunkIndex: Int? = nil) {
        self.chunk = chunk
        self.isLastChunk = isLastChunk
        self.chunkIndex = chunkIndex
    }
}
