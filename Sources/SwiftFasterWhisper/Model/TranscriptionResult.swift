//
// TranscriptionResult.swift
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/23/2026.
//

import Foundation

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
