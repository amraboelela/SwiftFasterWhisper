//
// TranscriptionSegment.swift
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/23/2026.
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
