//
// SwiftFasterWhisper.swift
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/21/2026.
//

import Foundation
import faster_whisper

/// Main class for speech recognition and translation using faster-whisper
public final class SwiftFasterWhisper {
    private var modelHandle: WhisperModelHandle?
    private let modelPath: String

    /// Check if model is loaded
    public var isModelLoaded: Bool {
        modelHandle != nil
    }

    /// Initialize with model path
    /// - Parameter modelPath: Path to the CTranslate2 Whisper model directory
    public init(modelPath: String) {
        self.modelPath = modelPath
    }

    deinit {
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

    // MARK: - Batch Transcription

    /// Transcribe audio from a file path
    /// - Parameters:
    ///   - audioFilePath: Path to audio file (WAV format recommended)
    ///   - language: Optional language code (nil for auto-detection)
    /// - Returns: Transcription result with segments and metadata
    /// - Throws: `RecognitionError` if transcription fails
    public func transcribe(audioFilePath: String, language: String? = nil) async throws -> TranscriptionResult {
        guard let handle = modelHandle else {
            throw RecognitionError.modelNotLoaded
        }

        // Load audio
        let audioArray = whisper_load_audio(audioFilePath)
        guard audioArray.data != nil, audioArray.length > 0 else {
            throw RecognitionError.invalidAudioData
        }
        defer { whisper_free_float_array(audioArray) }

        // Transcribe
        let result = whisper_transcribe(
            handle,
            audioArray.data,
            audioArray.length,
            language
        )
        defer { whisper_free_transcription_result(result) }

        return try convertToSwiftResult(result)
    }

    /// Transcribe audio from float array
    /// - Parameters:
    ///   - audio: Audio samples (16kHz mono float32)
    ///   - language: Optional language code (nil for auto-detection)
    /// - Returns: Transcription result with segments and metadata
    /// - Throws: `RecognitionError` if transcription fails
    public func transcribe(audio: [Float], language: String? = nil) async throws -> TranscriptionResult {
        guard let handle = modelHandle else {
            throw RecognitionError.modelNotLoaded
        }

        guard !audio.isEmpty else {
            throw RecognitionError.invalidAudioData
        }

        let result = audio.withUnsafeBufferPointer { buffer in
            whisper_transcribe(
                handle,
                buffer.baseAddress,
                UInt(audio.count),
                language
            )
        }
        defer { whisper_free_transcription_result(result) }

        return try convertToSwiftResult(result)
    }

    // MARK: - Translation

    /// Translate audio from a file path to English
    /// - Parameters:
    ///   - audioFilePath: Path to audio file (WAV format recommended)
    ///   - sourceLanguage: Optional source language code (nil for auto-detection)
    /// - Returns: Translation result with segments and metadata
    /// - Throws: `RecognitionError` if translation fails
    public func translate(audioFilePath: String, sourceLanguage: String? = nil) async throws -> TranscriptionResult {
        guard let handle = modelHandle else {
            throw RecognitionError.modelNotLoaded
        }

        // Load audio
        let audioArray = whisper_load_audio(audioFilePath)
        guard audioArray.data != nil, audioArray.length > 0 else {
            throw RecognitionError.invalidAudioData
        }
        defer { whisper_free_float_array(audioArray) }

        // Translate
        let result = whisper_translate(
            handle,
            audioArray.data,
            audioArray.length,
            sourceLanguage
        )
        defer { whisper_free_transcription_result(result) }

        return try convertToSwiftResult(result)
    }

    /// Translate audio from float array to English
    /// - Parameters:
    ///   - audio: Audio samples (16kHz mono float32)
    ///   - sourceLanguage: Optional source language code (nil for auto-detection)
    /// - Returns: Translation result with segments and metadata
    /// - Throws: `RecognitionError` if translation fails
    public func translate(audio: [Float], sourceLanguage: String? = nil) async throws -> TranscriptionResult {
        guard let handle = modelHandle else {
            throw RecognitionError.modelNotLoaded
        }

        guard !audio.isEmpty else {
            throw RecognitionError.invalidAudioData
        }

        let result = audio.withUnsafeBufferPointer { buffer in
            whisper_translate(
                handle,
                buffer.baseAddress,
                UInt(audio.count),
                sourceLanguage
            )
        }
        defer { whisper_free_transcription_result(result) }

        return try convertToSwiftResult(result)
    }

    // MARK: - Helper Methods

    private func convertToSwiftResult(_ cResult: faster_whisper.TranscriptionResult) throws -> TranscriptionResult {
        guard cResult.segment_count > 0, cResult.segments != nil else {
            throw RecognitionError.recognitionFailed("No segments returned")
        }

        let segments = cResult.segments!

        let swiftSegments = (0..<Int(cResult.segment_count)).map { i in
            let segment = segments[i]
            let text = segment.text != nil ? String(cString: segment.text) : ""
            return TranscriptionSegment(
                text: text,
                start: segment.start,
                end: segment.end
            )
        }

        let language = cResult.language != nil ? String(cString: cResult.language) : ""

        return TranscriptionResult(
            segments: swiftSegments,
            language: language,
            languageProbability: cResult.language_probability,
            duration: cResult.duration
        )
    }

    /// Get the path to a bundled model if available
    /// - Returns: Path to bundled model, or nil if not found
    public static func bundledModelPath() -> String? {
        #if SWIFT_PACKAGE
        return nil
        #else
        return Bundle.main.path(forResource: "whisper-medium-ct2", ofType: nil)
        #endif
    }
}
