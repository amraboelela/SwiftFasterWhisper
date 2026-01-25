//
// ModelManager.swift
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/22/2026.
//

import Foundation
import faster_whisper

/// Progress callback for model downloads
public typealias DownloadProgressCallback = (String, Double, Int64, Int64) -> Void

/// Manages model downloads and provides model control for transcription
/// Combines model management utilities with actor-based model execution
///
/// ## Thread Safety
/// ModelManager is a **single-consumer actor**:
/// - All inference must be serialized through this actor
/// - Only one task should call `processChunk()` at a time
/// - Concurrent calls are automatically serialized by the actor
/// - The C++ Whisper handle is NOT thread-safe and must remain actor-isolated
public actor ModelManager {

    // MARK: - Instance Properties (Model Control)

    private var modelHandle: WhisperModelHandle?
    private let modelPath: String
    private var language: String?
    private var task: String = "transcribe"
    private var isModelLoaded = false
    private var isStreaming = false

    // MARK: - Initialization

    /// Initialize with model path
    /// - Parameter modelPath: Path to the CTranslate2 Whisper model directory
    public init(modelPath: String) {
        self.modelPath = modelPath
    }

    deinit {
        // Note: deinit is not async and doesn't guarantee isolation
        // Use shutdown() for proper cleanup
        if let handle = modelHandle {
            whisper_stop_streaming(handle)
            whisper_destroy_model(handle)
        }
    }

    /// Explicit shutdown - call this before releasing the ModelManager
    public func shutdown() {
        guard let handle = modelHandle else { return }
        if isStreaming {
            whisper_stop_streaming(handle)
        }
        whisper_destroy_model(handle)
        modelHandle = nil
        isModelLoaded = false
        isStreaming = false
    }

    // MARK: - Model Loading

    /// Load the Whisper model (idempotent - safe to call multiple times)
    /// - Throws: `RecognitionError` if model loading fails
    public func loadModel() throws {
        // Already loaded - skip
        guard !isModelLoaded else { return }

        guard !modelPath.isEmpty else {
            throw RecognitionError.invalidModelPath
        }

        let handle = whisper_create_model(modelPath)
        guard handle != nil else {
            throw RecognitionError.modelLoadFailed("Failed to create model from path: \(modelPath)")
        }

        self.modelHandle = handle
        self.isModelLoaded = true
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
        guard !isStreaming else { return }

        whisper_start_streaming(handle, language, task)
        isStreaming = true
    }

    /// Stop streaming and reset state
    public func stopStreaming() {
        guard let handle = modelHandle else {
            return
        }
        guard isStreaming else { return }

        whisper_stop_streaming(handle)
        isStreaming = false
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

    /// Process a single audio chunk with energy filtering
    /// - Parameters:
    ///   - chunk: Audio samples (16kHz mono float32)
    /// - Returns: Array of transcribed text strings
    public func processChunk(_ chunk: [Float]) async -> [String] {
        // Calculate chunk energy and duration (pure computation, safe anywhere)
        let energy = chunk.reduce(0.0) { $0 + abs($1) } / Float(chunk.count)
        let chunkDuration = Double(chunk.count) / 16000.0

        // Get current threshold from statistics
        let threshold = await EnergyStatistics.shared.getCurrentThreshold()

        // Check if we should drop this chunk
        if threshold > 0 && energy < threshold {
            let average = await EnergyStatistics.shared.averageEnergy
            let thresholdPercentage = average > 0 ? (threshold / average) * 100.0 : 0.0
            print("⚠️  Dropped low-energy chunk (energy: \(String(format: "%.6f", energy)), threshold: \(String(format: "%.6f", threshold)) (\(String(format: "%.1f", thresholdPercentage))%), avg: \(String(format: "%.6f", average)))")

            // Update metrics in background
            Task(priority: .background) {
                await EnergyStatistics.shared.updateMetrics(
                    energy: energy,
                    chunkDuration: chunkDuration,
                    transcriptionTime: 0.0,
                    wasDropped: true
                )
            }
            return []
        }

        // Measure transcription time
        let startTime = Date()

        // ALL C++ calls happen inside the actor (safe)
        guard let handle = modelHandle else {
            print("❌ Model not loaded")
            return []
        }

        do {
            // Add chunk to C++ (actor-isolated, safe)
            try chunk.withUnsafeBufferPointer { buffer in
                whisper_add_audio_chunk(handle, buffer.baseAddress, UInt(chunk.count))
            }

            // Get segments from C++ (actor-isolated, safe)
            var count: UInt = 0
            let cSegments = whisper_get_new_segments(handle, &count)

            let transcriptionTime = Date().timeIntervalSince(startTime)

            // Update statistics in background
            Task(priority: .background) {
                await EnergyStatistics.shared.updateMetrics(
                    energy: energy,
                    chunkDuration: chunkDuration,
                    transcriptionTime: transcriptionTime,
                    wasDropped: false
                )
            }

            guard count > 0, let cSegments = cSegments else {
                return []
            }
            defer { whisper_free_segments(cSegments, count) }

            var result: [String] = []
            for i in 0..<Int(count) {
                let seg = cSegments[i]
                if let text = seg.text {
                    let trimmed = String(cString: text).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        result.append(trimmed)
                    }
                }
            }

            return result
        } catch {
            print("❌ Chunk processing error: \(error)")
            return []
        }
    }
}
