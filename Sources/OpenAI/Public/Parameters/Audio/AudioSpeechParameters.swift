//
//  AudioSpeechParameters.swift
//
//
//  Created by James Rochabrun on 11/14/23.
//

import Foundation

/// [Generates audio from the input text.](https://platform.openai.com/docs/api-reference/audio/createSpeech)
public struct AudioSpeechParameters: Encodable {
  public init(
    model: TTSModel,
    input: String,
    voice: Voice,
    instructions: String? = nil,
    responseFormat: ResponseFormat? = nil,
    speed: Double? = nil,
    stream: Bool? = nil)
  {
    self.model = model.rawValue
    self.input = input
    self.voice = voice.rawValue
    self.instructions = instructions
    self.responseFormat = responseFormat?.rawValue
    self.speed = speed
    self.stream = stream
  }

  public enum TTSModel {
    case tts1
    case tts1HD
    case gpt4oMiniTTS
    case custom(model: String)

    var rawValue: String {
      switch self {
      case .tts1:
        "tts-1"
      case .tts1HD:
        "tts-1-hd"
      case .gpt4oMiniTTS:
        "gpt-4o-mini-tts"
      case .custom(let model):
        model
      }
    }
  }

  public enum Voice: String {
    case alloy
    case ash
    case ballad
    case cedar
    case coral
    case echo
    case fable
    case marin
    case nova
    case onyx
    case sage
    case shimmer
    case verse
  }

  public enum ResponseFormat: String {
    case mp3
    case opus
    case aac
    case flac
  }

  enum CodingKeys: String, CodingKey {
    case model
    case input
    case voice
    case instructions
    case responseFormat = "response_format"
    case speed
    case stream
  }

  /// One of the available [TTS models](https://platform.openai.com/docs/models/tts): tts-1, tts-1-hd, or gpt-4o-mini-tts
  let model: String
  /// The text to generate audio for. The maximum length is 4096 characters.
  let input: String
  /// The voice to use when generating the audio.
  let voice: String
  /// Control the voice style with natural language instructions. Only supported by gpt-4o-mini-tts.
  let instructions: String?
  /// Defaults to mp3, The format to audio in. Supported formats are mp3, opus, aac, and flac.
  let responseFormat: String?
  /// Defaults to 1,  The speed of the generated audio. Select a value from 0.25 to 4.0. 1.0 is the default.
  let speed: Double?
  /// Whether to stream the audio response. When true, the response will be streamed as chunks instead of returning all at once.
  public var stream: Bool?
}
