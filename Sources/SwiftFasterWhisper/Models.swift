//
// Models.swift
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/21/2026.
//

import Foundation

/// Represents a single transcription segment with timing information
public struct TranscriptionSegment: Sendable {
    /// The transcribed or translated text
    public let text: String

    /// Start time in seconds
    public let start: Float

    /// End time in seconds
    public let end: Float

    public init(text: String, start: Float, end: Float) {
        self.text = text
        self.start = start
        self.end = end
    }
}

/// Complete transcription result with language detection and metadata
public struct TranscriptionResult: Sendable {
    /// Array of transcribed segments
    public let segments: [TranscriptionSegment]

    /// Detected or specified language code (e.g., "en", "es", "ar")
    public let language: String

    /// Confidence of language detection (0.0 to 1.0)
    public let languageProbability: Float

    /// Total audio duration in seconds
    public let duration: Float

    /// Combined text from all segments
    public var text: String {
        segments.map(\.text).joined()
    }

    public init(
        segments: [TranscriptionSegment],
        language: String,
        languageProbability: Float,
        duration: Float
    ) {
        self.segments = segments
        self.language = language
        self.languageProbability = languageProbability
        self.duration = duration
    }
}

/// Errors that can occur during speech recognition
public enum RecognitionError: Error, CustomStringConvertible {
    /// Audio data is invalid or empty
    case invalidAudioData

    /// Recognition process failed
    case recognitionFailed(String)

    /// Translation process failed
    case translationFailed(String)

    /// Model is not loaded
    case modelNotLoaded

    /// Failed to load model
    case modelLoadFailed(String)

    /// Model path is invalid
    case invalidModelPath

    /// Streaming is not active
    case streamingNotActive

    /// Failed to start streaming
    case streamingStartFailed(String)

    public var description: String {
        switch self {
        case .invalidAudioData:
            return "Invalid or empty audio data"
        case .recognitionFailed(let message):
            return "Recognition failed: \(message)"
        case .translationFailed(let message):
            return "Translation failed: \(message)"
        case .modelNotLoaded:
            return "Model not loaded"
        case .modelLoadFailed(let message):
            return "Failed to load model: \(message)"
        case .invalidModelPath:
            return "Invalid model path"
        case .streamingNotActive:
            return "Streaming is not active"
        case .streamingStartFailed(let message):
            return "Failed to start streaming: \(message)"
        }
    }
}
