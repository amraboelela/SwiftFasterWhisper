//
// StreamingRecognizer.swift
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/23/2026.
//

import Foundation

/// Delegate protocol for streaming recognizer callbacks
public protocol StreamingRecognizerDelegate: AnyObject, Sendable {
    /// Called when new transcription segments are available
    /// - Parameters:
    ///   - recognizer: The streaming recognizer instance
    ///   - segments: New transcription segments
    func recognizer(_ recognizer: StreamingRecognizer, didReceiveSegments segments: [TranscriptionSegment])

    /// Called when streaming finishes or encounters an error
    /// - Parameters:
    ///   - recognizer: The streaming recognizer instance
    ///   - error: Error if streaming failed, nil if stopped normally
    func recognizer(_ recognizer: StreamingRecognizer, didFinishWithError error: Error?)
}

/// Handles streaming audio processing by sending chunks to C++ incrementally
/// Uses ModelManager as the underlying model wrapper
public actor StreamingRecognizer {
    private let modelManager: ModelManager
    private var pendingSegments: [TranscriptionSegment] = []
    private var isProcessing = false

    /// Delegate for receiving streaming callbacks
    private weak var _delegate: (any StreamingRecognizerDelegate)?

    /// Set delegate (actor-isolated)
    public func setDelegate(_ delegate: (any StreamingRecognizerDelegate)?) {
        self._delegate = delegate
    }

    /// Initialize with model path
    /// - Parameters:
    ///   - modelPath: Path to the Whisper model
    public init(modelPath: String) {
        self.modelManager = ModelManager(modelPath: modelPath)
    }

    /// Load the model
    public func loadModel() async throws {
        try await modelManager.loadModel()
    }

    /// Configure streaming parameters
    /// - Parameters:
    ///   - language: Language code (nil for auto-detection)
    ///   - task: "transcribe" or "translate"
    public func configure(language: String? = nil, task: String = "transcribe") async throws {
        await modelManager.configure(language: language, task: task)
        try await modelManager.startStreaming()
    }

    /// Add audio chunk for processing (sends directly to C++)
    /// - Parameter chunk: Audio samples (16kHz mono float32, recommended: 16000 samples = 1s)
    public func addAudioChunk(_ chunk: [Float]) async throws {
        // Calculate chunk energy and duration
        let energy = chunk.reduce(0.0) { $0 + abs($1) } / Float(chunk.count)
        let chunkDuration = Double(chunk.count) / 16000.0  // Duration in seconds (assuming 16kHz)

        // Get current threshold from statistics
        let threshold = await EnergyStatistics.shared.getCurrentThreshold()

        // Check if we should drop this chunk (only after first 10 chunks)
        if threshold > 0 && energy < threshold {
            let average = await EnergyStatistics.shared.averageEnergy
            print("⚠️  Dropped low-energy chunk (energy: \(String(format: "%.6f", energy)), threshold: \(String(format: "%.6f", threshold)), avg: \(String(format: "%.6f", average)))")

            // Update metrics even for dropped chunks (with 0 transcription time)
            await EnergyStatistics.shared.updateMetrics(
                energy: energy,
                chunkDuration: chunkDuration,
                transcriptionTime: 0.0,
                wasDropped: true
            )
            return
        }

        // Measure transcription time
        let startTime = Date()

        // Send chunk directly to C++ streaming buffer
        try await modelManager.addChunk(chunk)

        // Synchronously poll for new segments
        isProcessing = true
        let newSegments = try await modelManager.getNewSegments()
        isProcessing = false

        let transcriptionTime = Date().timeIntervalSince(startTime)

        // Update statistics with transcription metrics
        await EnergyStatistics.shared.updateMetrics(
            energy: energy,
            chunkDuration: chunkDuration,
            transcriptionTime: transcriptionTime,
            wasDropped: false
        )

        if !newSegments.isEmpty {
            pendingSegments.append(contentsOf: newSegments)
            _delegate?.recognizer(self, didReceiveSegments: newSegments)
        }
    }

    /// Get new transcription segments (non-blocking poll)
    /// Returns any segments that have been processed since last call
    /// - Returns: Array of new segments, empty if none available
    public func getNewSegments() -> [TranscriptionSegment] {
        let segments = pendingSegments
        pendingSegments.removeAll()
        return segments
    }

    /// Flush any remaining buffer and transcribe it
    /// Useful for processing leftover audio at the end of streaming
    public func flush() async {
        // Poll one more time for any final segments
        do {
            isProcessing = true
            let finalSegments = try await modelManager.getNewSegments()
            isProcessing = false

            if !finalSegments.isEmpty {
                pendingSegments.append(contentsOf: finalSegments)
            }
        } catch {
            isProcessing = false
            print("❌ Flush error: \(error)")
        }
    }

    /// Stop streaming and cleanup
    public func stop() async {
        pendingSegments.removeAll()
        await modelManager.stopStreaming()
        _delegate?.recognizer(self, didFinishWithError: nil)
    }

    /// Reset global energy statistics (useful for testing)
    public static func resetEnergyStatistics() async {
        await EnergyStatistics.shared.reset()
    }
}
