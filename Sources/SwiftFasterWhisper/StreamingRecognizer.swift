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
    /// Called when new transcription segments are available
    /// - Parameters:
    ///   - recognizer: The streaming recognizer instance
    ///   - segments: Array of new transcription segments
    func recognizer(_ recognizer: StreamingRecognizer, didReceiveSegments segments: [TranscriptionSegment])

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
    /// Call this repeatedly with small audio chunks (e.g., 30ms)
    /// - Parameter chunk: Audio samples (16kHz mono float32)
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

    /// Poll for new transcription segments
    /// Call this periodically (e.g., every 100-500ms) to check for new segments
    /// - Returns: Array of new segments, or empty array if none available
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

        return (0..<Int(count)).map { i in
            let segment = segments[i]
            let text = segment.text != nil ? String(cString: segment.text) : ""
            return TranscriptionSegment(
                text: text,
                start: segment.start,
                end: segment.end
            )
        }
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
    /// - Returns: AsyncThrowingStream of segment arrays
    ///
    /// Usage:
    /// ```swift
    /// for try await segments in recognizer.streamingSegments() {
    ///     for segment in segments {
    ///         print(segment.text)
    ///     }
    /// }
    /// ```
    public func streamingSegments(language: String? = nil) -> AsyncThrowingStream<[TranscriptionSegment], Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try startStreaming(language: language)

                    // Poll for segments every 500ms
                    while isStreaming {
                        let segments = try getNewSegments()
                        if !segments.isEmpty {
                            continuation.yield(segments)
                        }
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
