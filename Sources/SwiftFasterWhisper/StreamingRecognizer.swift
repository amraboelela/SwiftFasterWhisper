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
        if isStreaming {
            stopStreaming()
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

    /// Start streaming transcription
    /// - Parameter language: Optional language code (nil for auto-detection)
    /// - Throws: `RecognitionError` if streaming start fails
    public func startStreaming(language: String? = nil) throws {
        guard let handle = modelHandle else {
            throw RecognitionError.modelNotLoaded
        }

        guard !isStreaming else {
            return  // Already streaming
        }

        whisper_start_streaming(handle, language)
        isStreaming = true
    }

    /// Add an audio chunk for processing
    /// Call this repeatedly with 1-second audio chunks (16000 samples at 16kHz)
    /// - Parameter chunk: Audio samples (16kHz mono float32, recommended size: 16000 samples = 1 second)
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

    /// Poll for a new transcription segment
    /// Call this periodically (e.g., every 100-500ms) to check for a new stable segment
    /// - Returns: A new segment if one is ready, or nil if no segment is available yet
    /// - Throws: `RecognitionError` if streaming is not active
    public func getNewSegment() throws -> TranscriptionSegment? {
        guard let handle = modelHandle else {
            throw RecognitionError.modelNotLoaded
        }

        guard isStreaming else {
            throw RecognitionError.streamingNotActive
        }

        var count: UInt = 0
        let segments = whisper_get_new_segments(handle, &count)

        guard count > 0, let segments = segments else {
            return nil
        }
        defer { whisper_free_segments(segments, count) }

        // Return only the first segment (expanding window emits one stable segment at a time)
        let segment = segments[0]
        let text = segment.text != nil ? String(cString: segment.text) : ""
        return TranscriptionSegment(
            text: text,
            start: segment.start,
            end: segment.end
        )
    }

    /// Stop streaming transcription
    public func stopStreaming() {
        guard let handle = modelHandle, isStreaming else {
            return
        }

        whisper_stop_streaming(handle)
        isStreaming = false
        delegate?.recognizer(self, didFinishWithError: nil)
    }

    // MARK: - Async/Await Streaming

    /// Stream transcription segments using AsyncThrowingStream
    /// - Parameter language: Optional language code (nil for auto-detection)
    /// - Returns: AsyncThrowingStream of individual segments (nil if no segment ready yet)
    ///
    /// Usage:
    /// ```swift
    /// for try await segment in recognizer.streamingSegments() {
    ///     if let segment = segment {
    ///         print(segment.text)
    ///     }
    /// }
    /// ```
    public func streamingSegments(language: String? = nil) -> AsyncThrowingStream<TranscriptionSegment?, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try startStreaming(language: language)

                    // Poll for segments every 500ms
                    while isStreaming {
                        let segment = try getNewSegment()
                        continuation.yield(segment)
                        try await Task.sleep(for: .milliseconds(500))
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
