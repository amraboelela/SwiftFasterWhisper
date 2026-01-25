//
// ModelManager.swift
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/22/2026.
//

import Foundation
import CryptoKit
import faster_whisper

/// Progress callback for model downloads
public typealias DownloadProgressCallback = (String, Double, Int64, Int64) -> Void

/// Manages model downloads and provides model control for transcription
/// Combines model management utilities with class-based model execution
public class ModelManager {

    // MARK: - Instance Properties (Model Control)

    private var modelHandle: WhisperModelHandle?
    private let modelPath: String
    private var language: String?
    private var task: String = "transcribe"
    private var isModelBusy = false

    // MARK: - Initialization

    /// Initialize with model path
    /// - Parameter modelPath: Path to the CTranslate2 Whisper model directory
    public init(modelPath: String) {
        self.modelPath = modelPath
    }

    deinit {
        if let handle = modelHandle {
            whisper_stop_streaming(handle)
            whisper_destroy_model(handle)
        }
    }

    // MARK: - Model Loading

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

    /// Configure streaming parameters
    /// - Parameters:
    ///   - language: Optional language code (nil for auto-detection)
    ///   - task: Task type - "transcribe" (default) or "translate"
    public func configure(language: String? = nil, task: String = "transcribe") {
        self.language = language
        self.task = task
    }

    /// Start streaming session (call once before transcribing)
    /// - Throws: `RecognitionError` if model not loaded
    public func startStreaming() throws {
        guard let handle = modelHandle else {
            throw RecognitionError.modelNotLoaded
        }
        whisper_start_streaming(handle, language, task)
    }

    /// Stop streaming and reset state
    public func stopStreaming() {
        guard let handle = modelHandle else {
            return
        }
        whisper_stop_streaming(handle)
    }

    /// Add audio chunk to streaming buffer (incremental feeding)
    /// - Parameter chunk: Audio samples (16kHz mono float32)
    /// - Throws: `RecognitionError` if model not loaded or streaming not started
    public func addChunk(_ chunk: [Float]) throws {
        guard let handle = modelHandle else {
            throw RecognitionError.modelNotLoaded
        }

        guard !chunk.isEmpty else {
            return
        }

        chunk.withUnsafeBufferPointer { buffer in
            whisper_add_audio_chunk(handle, buffer.baseAddress, UInt(chunk.count))
        }
    }

    /// Get new transcription segments from C++ streaming buffer
    /// - Returns: Array of new segments
    /// - Throws: `RecognitionError` if model not loaded
    public func getNewSegments() throws -> [TranscriptionSegment] {
        guard let handle = modelHandle else {
            throw RecognitionError.modelNotLoaded
        }

        var count: UInt = 0
        let cSegments = whisper_get_new_segments(handle, &count)

        guard count > 0, let cSegments = cSegments else {
            return []
        }
        defer { whisper_free_segments(cSegments, count) }

        var result: [TranscriptionSegment] = []
        for i in 0..<Int(count) {
            let seg = cSegments[i]
            let text = seg.text != nil ? String(cString: seg.text) : ""
            result.append(TranscriptionSegment(
                text: text,
                start: seg.start,
                end: seg.end
            ))
        }

        return result
    }

    // MARK: - Transcription

    /// Process audio and return transcription segments
    /// This is a blocking call that runs the model
    /// - Parameter audio: Audio samples (16kHz mono float32)
    /// - Returns: Array of transcription segments
    /// - Throws: `RecognitionError` if transcription fails
    public func transcribe(audio: [Float]) async throws -> [TranscriptionSegment] {
        guard let handle = modelHandle else {
            throw RecognitionError.modelNotLoaded
        }

        guard !audio.isEmpty else {
            return []
        }

        // Wait if model is busy
        while isModelBusy {
            try await Task.sleep(for: .milliseconds(100))
        }

        isModelBusy = true
        defer { isModelBusy = false }

        // Transcribe audio
        let segments: [TranscriptionSegment] = await Task.detached { [handle, audio] in
            audio.withUnsafeBufferPointer { buffer in
                whisper_add_audio_chunk(handle, buffer.baseAddress, UInt(audio.count))
            }

            var count: UInt = 0
            let cSegments = whisper_get_new_segments(handle, &count)

            guard count > 0, let cSegments = cSegments else {
                return []
            }
            defer { whisper_free_segments(cSegments, count) }

            var result: [TranscriptionSegment] = []
            for i in 0..<Int(count) {
                let seg = cSegments[i]
                let text = seg.text != nil ? String(cString: seg.text) : ""
                result.append(TranscriptionSegment(
                    text: text,
                    start: seg.start,
                    end: seg.end
                ))
            }

            return result
        }.value

        return segments
    }
}
