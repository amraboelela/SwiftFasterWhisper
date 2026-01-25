//
// StreamingRecognizer.swift
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/23/2026.
//

import Foundation

/// Handles streaming audio processing using producer-consumer pattern
/// Producer: addAudioChunk() quickly adds chunks to queue
/// Consumer: Background task processes chunks and sends to C++
public actor StreamingRecognizer {
    private let modelManager: ModelManager
    private var pendingText: String = ""

    // Producer-consumer pattern
    private var chunksQueue: [[Float]] = []
    private var isConsuming = false

    /// Initialize with model path
    /// - Parameters:
    ///   - modelPath: Path to the Whisper model
    public init(modelPath: String) {
        self.modelManager = ModelManager(modelPath: modelPath)
    }

    /// Configure streaming parameters and load model if needed
    /// - Parameters:
    ///   - language: Language code (nil for auto-detection)
    ///   - task: "transcribe" or "translate"
    public func configure(language: String? = nil, task: String = "transcribe") async throws {
        try await modelManager.loadModel()
        modelManager.configure(language: language, task: task)
        try modelManager.startStreaming()
    }

    /// Add audio chunk to queue (producer - fast, non-blocking)
    /// Starts consumer task if not already running
    /// - Parameter chunk: Audio samples (16kHz mono float32, recommended: 16000 samples = 1s)
    public func addAudioChunk(_ chunk: [Float]) {
        chunksQueue.append(chunk)

        // Only start consumer if not already running
        if !isConsuming {
            consumeChunks()
        }
    }

    /// Consume chunks from queue in background task
    private func consumeChunks() {
        isConsuming = true
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            // Process all chunks in queue
            while await !self.chunksQueue.isEmpty {
                if let chunk = await self.dequeueChunk() {
                    await self.processChunk(chunk)
                }
            }

            // Done - reset flag via actor method
            await self.resetConsuming()
        }
    }

    private func resetConsuming() {
        isConsuming = false
    }

    /// Dequeue next chunk from queue (actor-isolated)
    private func dequeueChunk() -> [Float]? {
        guard !chunksQueue.isEmpty else { return nil }
        return chunksQueue.removeFirst()
    }

    /// Process a single chunk (consumer)
    private func processChunk(_ chunk: [Float]) async {
        // Calculate chunk energy and duration
        let energy = chunk.reduce(0.0) { $0 + abs($1) } / Float(chunk.count)
        let chunkDuration = Double(chunk.count) / 16000.0  // Duration in seconds (assuming 16kHz)

        // Get current threshold from statistics
        let threshold = await EnergyStatistics.shared.getCurrentThreshold()

        // Check if we should drop this chunk (only after first 10 chunks)
        if threshold > 0 && energy < threshold {
            let average = await EnergyStatistics.shared.averageEnergy
            let thresholdPercentage = average > 0 ? (threshold / average) * 100.0 : 0.0
            print("⚠️  Dropped low-energy chunk (energy: \(String(format: "%.6f", energy)), threshold: \(String(format: "%.6f", threshold)) (\(String(format: "%.1f", thresholdPercentage))%), avg: \(String(format: "%.6f", average)))")

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
        do {
            try await modelManager.addChunk(chunk)

            // Synchronously poll for new segments
            let newSegments = try await modelManager.getNewSegments()

            let transcriptionTime = Date().timeIntervalSince(startTime)

            // Update statistics with transcription metrics
            await EnergyStatistics.shared.updateMetrics(
                energy: energy,
                chunkDuration: chunkDuration,
                transcriptionTime: transcriptionTime,
                wasDropped: false
            )

            if !newSegments.isEmpty {
                for segment in newSegments {
                    let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        if !pendingText.isEmpty {
                            pendingText += " "
                        }
                        pendingText += text
                    }
                }
            }
        } catch {
            print("❌ Chunk processing error: \(error)")
        }
    }

    /// Get new transcription text (non-blocking poll)
    /// Returns accumulated text since last call and clears it
    /// - Returns: Transcribed text since last call
    public func getNewText() -> String {
        let text = pendingText
        pendingText = ""
        return text
    }

    /// Flush any remaining buffer and transcribe it
    /// Useful for processing leftover audio at the end of streaming
    public func flush() async {
        // Poll one more time for any final segments
        do {
            let finalSegments = try await modelManager.getNewSegments()

            if !finalSegments.isEmpty {
                for segment in finalSegments {
                    let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        if !pendingText.isEmpty {
                            pendingText += " "
                        }
                        pendingText += text
                    }
                }
            }
        } catch {
            print("❌ Flush error: \(error)")
        }
    }

    /// Stop streaming and cleanup
    public func stop() async {
        // Clear all state
        chunksQueue.removeAll()
        pendingText = ""
        modelManager.stopStreaming()
    }

    /// Reset global energy statistics (useful for testing)
    public static func resetEnergyStatistics() async {
        await EnergyStatistics.shared.reset()
    }
}
