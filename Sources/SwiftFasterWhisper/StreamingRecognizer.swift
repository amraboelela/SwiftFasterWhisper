//
// StreamingRecognizer.swift
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/21/2026.
//

import Foundation
import faster_whisper

/// Delegate protocol for streaming recognition callbacks
public protocol StreamingRecognizerDelegate: AnyObject, Sendable {
    /// Called when a new transcription segment is available
    /// - Parameters:
    ///   - recognizer: The streaming recognizer instance
    ///   - segment: A new stable transcription segment (or nil if no segment ready yet)
    func recognizer(_ recognizer: StreamingRecognizer, didReceiveSegment segment: TranscriptionSegment?)

    /// Called when streaming finishes or encounters an error
    /// - Parameters:
    ///   - recognizer: The streaming recognizer instance
    ///   - error: Error if streaming failed, nil if stopped normally
    func recognizer(_ recognizer: StreamingRecognizer, didFinishWithError error: Error?)
}

/// Real-time streaming speech recognizer
public final class StreamingRecognizer {
    private var modelHandle: WhisperModelHandle?
    private let modelPath: String
    private var isStreaming = false

    /// Energy threshold for manual silence detection (not used internally)
    /// Default: 0.01 (adjust based on your audio levels)
    /// Typical values: silence < 0.01, background noise ~0.015, speech > 0.02
    /// Use with calculateEnergy() and hasSufficientEnergy() for custom filtering
    public var energyThreshold: Float = 0.01

    /// Delegate for receiving streaming callbacks
    public weak var delegate: (any StreamingRecognizerDelegate)?

    /// Check if currently streaming
    public var streamingActive: Bool {
        isStreaming
    }

    /// Initialize with model path
    /// - Parameter modelPath: Path to the CTranslate2 Whisper model directory
    public init(modelPath: String) {
        self.modelPath = modelPath
    }

    deinit {
        // Stop streaming synchronously for deinit
        if isStreaming, let handle = modelHandle {
            isStreaming = false
            whisper_stop_streaming(handle)
        }

        if let handle = modelHandle {
            whisper_destroy_model(handle)
        }
    }

    /// Load the Whisper model
    /// - Throws: `RecognitionError` if model loading fails
    public func loadModel() throws {
        guard !modelPath.isEmpty else {
            throw RecognitionError.invalidModelPath
        }

        let handle = whisper_create_model(modelPath)
        guard handle != nil else {
            throw RecognitionError.modelLoadFailed("Failed to create model from path: \(modelPath)")
        }

        self.modelHandle = handle
    }

    // MARK: - Streaming Control

    /// Start streaming transcription or translation
    /// - Parameters:
    ///   - language: Optional language code (nil for auto-detection)
    ///   - task: Task type - "transcribe" (default) or "translate"
    /// - Throws: `RecognitionError` if streaming start fails
    public func startStreaming(language: String? = nil, task: String = "transcribe") throws {
        guard let handle = modelHandle else {
            throw RecognitionError.modelNotLoaded
        }

        guard !isStreaming else {
            return  // Already streaming
        }

        whisper_start_streaming(handle, language, task)
        isStreaming = true
    }

    /// Add an audio chunk for processing
    /// Call this repeatedly with audio chunks (recommended: 1-second chunks = 16000 samples at 16kHz)
    /// Internally uses a 4-second sliding window
    /// - Parameter chunk: Audio samples (16kHz mono float32, any size but 16000 samples recommended)
    /// - Throws: `RecognitionError` if streaming is not active
    public func addAudioChunk(_ chunk: [Float]) throws {
        guard let handle = modelHandle else {
            throw RecognitionError.modelNotLoaded
        }

        guard isStreaming else {
            throw RecognitionError.streamingNotActive
        }

        guard !chunk.isEmpty else {
            return
        }

        chunk.withUnsafeBufferPointer { buffer in
            whisper_add_audio_chunk(
                handle,
                buffer.baseAddress,
                UInt(chunk.count)
            )
        }
    }

    /// Calculate RMS (Root Mean Square) energy of an audio chunk
    /// - Parameter chunk: Audio samples
    /// - Returns: RMS energy value
    public func calculateEnergy(_ chunk: [Float]) -> Float {
        guard !chunk.isEmpty else { return 0.0 }

        let sumOfSquares = chunk.reduce(0.0) { $0 + ($1 * $1) }
        return sqrt(sumOfSquares / Float(chunk.count))
    }

    /// Check if audio chunk has sufficient energy (not silence)
    /// - Parameter chunk: Audio samples
    /// - Returns: True if energy is above threshold, false if silence
    public func hasSufficientEnergy(_ chunk: [Float]) -> Bool {
        return calculateEnergy(chunk) >= energyThreshold
    }

    /// Get new transcription segments
    /// Call this after adding audio chunks to check if transcription is ready
    /// - Returns: Array of segments if ready, empty array if not ready yet
    /// - Throws: `RecognitionError` if streaming is not active
    public func getNewSegments() throws -> [TranscriptionSegment] {
        guard let handle = modelHandle else {
            throw RecognitionError.modelNotLoaded
        }

        guard isStreaming else {
            throw RecognitionError.streamingNotActive
        }

        var count: UInt = 0
        let segments = whisper_get_new_segments(handle, &count)

        guard count > 0, let segments = segments else {
            return []
        }
        defer { whisper_free_segments(segments, count) }

        var result: [TranscriptionSegment] = []
        for i in 0..<Int(count) {
            let seg = segments[i]
            let text = seg.text != nil ? String(cString: seg.text) : ""
            result.append(TranscriptionSegment(
                text: text,
                start: seg.start,
                end: seg.end
            ))
        }

        return result
    }

    /// Stop streaming transcription
    public func stopStreaming() {
        guard let handle = modelHandle, isStreaming else {
            return
        }

        isStreaming = false
        whisper_stop_streaming(handle)
        delegate?.recognizer(self, didFinishWithError: nil)
    }
}
