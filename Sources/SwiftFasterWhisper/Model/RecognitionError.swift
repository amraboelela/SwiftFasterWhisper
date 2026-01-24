//
// RecognitionError.swift
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/23/2026.
//

import Foundation

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
