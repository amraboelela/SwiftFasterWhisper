//
// ChunksProducer.swift
// SwiftFasterWhisper Tests
//
// Created by Amr Aboelela on 1/24/2026.
//

import Foundation
@testable import SwiftFasterWhisper

/// Produces audio chunks in real-time simulation
/// Sends 1-second chunks with 1-second delays to simulate live streaming
class ChunksProducer {
    private let fullAudio: [Float]
    private let chunkSize: Int
    private var offset: Int = 0

    /// Initialize with audio samples
    /// - Parameters:
    ///   - audio: Full audio samples (16kHz mono float32)
    ///   - chunkSize: Size of each chunk in samples (default: 16000 = 1s)
    init(audio: [Float], chunkSize: Int = 16000) {
        self.fullAudio = audio
        self.chunkSize = chunkSize
        self.offset = 0
    }

    /// Start producing chunks with callbacks
    /// - Parameters:
    ///   - onChunk: Called for each chunk with (chunkNumber, chunk, isLast)
    ///   - onComplete: Called when all chunks have been sent
    func start(
        onChunk: @escaping (Int, [Float], Bool) async throws -> Void,
        onComplete: @escaping () async -> Void
    ) async throws {
        var chunkNumber = 1

        // Send real audio chunks
        while offset < fullAudio.count {
            let end = min(offset + chunkSize, fullAudio.count)
            var chunk = Array(fullAudio[offset..<end])

            // Pad last chunk with zeros to match chunkSize if needed
            if chunk.count < chunkSize {
                let paddingNeeded = chunkSize - chunk.count
                chunk.append(contentsOf: [Float](repeating: 0.0, count: paddingNeeded))
            }

            let isLastChunk = (end >= fullAudio.count)
            try await onChunk(chunkNumber, chunk, false)

            offset = end
            chunkNumber += 1

            // Simulate real-time: wait 1 second before sending next chunk
            if !isLastChunk {
                try await Task.sleep(for: .seconds(1))
            }
        }

        // Send silence equal to 140% of audio duration to allow final processing
        let audioDuration = Int(ceil(Double(fullAudio.count) / Double(chunkSize)))
        let silenceDuration = Int(ceil(Double(audioDuration) * 1.4))
        let silenceChunk = [Float](repeating: 0.1, count: chunkSize)
        for i in 1...silenceDuration {
            try await onChunk(chunkNumber, silenceChunk, i == silenceDuration)
            chunkNumber += 1
            try await Task.sleep(for: .seconds(1))
        }

        await onComplete()
    }

    /// Reset to beginning
    func reset() {
        offset = 0
    }
}
