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
    private var readIndex = 0
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
        await modelManager.configure(language: language, task: task)
        try await modelManager.startStreaming()
    }

    /// Add audio chunk to queue (producer - fast, non-blocking)
    /// Starts consumer task if not already running
    /// - Parameter chunk: Audio samples (16kHz mono float32, typically 30ms chunks work well)
    /// - Returns: New transcribed text since last call
    public func addAudioChunk(_ chunk: [Float]) -> String {
        // Drop all pending chunks if backlog is too large
        if chunksQueue.count >= 100 {
            let dropCount = chunksQueue.count
            chunksQueue.removeAll()
            readIndex = 0
            print("#debug ⚠️  Dropped all \(dropCount) pending chunks, starting fresh")
        }

        chunksQueue.append(chunk)

        // Start consumer if not already running (set flag first to prevent race)
        if !isConsuming {
            isConsuming = true
            startConsumer()
        }

        return getNewText()
    }

    /// Start the consumer loop
    private func startConsumer() {
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.consumeLoop()
        }
    }

    /// Consume chunks in a loop (actor-owned)
    private func consumeLoop() async {
        while true {
            guard let chunk = dequeueChunk() else {
                // Queue exhausted - reset consuming flag and exit
                isConsuming = false
                return
            }
            let texts = await modelManager.processChunk(chunk)
            appendTexts(texts)
        }
    }

    /// Dequeue next chunk from queue (O(1) using index)
    private func dequeueChunk() -> [Float]? {
        guard readIndex < chunksQueue.count else {
            // Queue exhausted - reset for next batch
            chunksQueue.removeAll()
            readIndex = 0
            return nil
        }
        let chunk = chunksQueue[readIndex]
        readIndex += 1
        return chunk
    }

    /// Append texts to pending text (actor-isolated, fast)
    private func appendTexts(_ texts: [String]) {
        for text in texts {
            if !pendingText.isEmpty {
                pendingText += " "
            }
            pendingText += text
        }
    }

    /// Get new transcription text (non-blocking poll)
    /// Returns accumulated text since last call and clears it
    /// - Returns: Transcribed text since last call
    private func getNewText() -> String {
        let text = pendingText
        pendingText = ""
        return text
    }

    /// Stop streaming and cleanup
    public func stop() async {
        // Clear all state
        chunksQueue.removeAll()
        readIndex = 0
        isConsuming = false
        pendingText = ""
        await modelManager.stopStreaming()
    }

    /// Reset global energy statistics (useful for testing)
    public static func resetEnergyStatistics() async {
        await EnergyStatistics.shared.reset()
    }
}
