//
// EnergyStatistics.swift
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/24/2026.
//

import Foundation

/// Global energy statistics shared across all StreamingRecognizer instances
actor EnergyStatistics {
    static let shared = EnergyStatistics()

    private var _averageEnergy: Float = 0.0
    private var energyChunkCount: Int = 0
    private var totalTranscriptionTime: Double = 0.0  // Total time spent transcribing (seconds)
    private var totalChunksDuration: Double = 0.0    // Total duration of chunks sent (seconds)

    private init() {}

    /// Check if buffer is a dummy buffer (used for flushing in tests)
    /// - Parameter buffer: Audio samples to check
    /// - Returns: True if all samples are 0.1 (dummy buffer)
    static func isDummyBuffer(_ buffer: [Float]) -> Bool {
        return buffer.allSatisfy { abs($0 - 0.1) < 0.001 }
    }

    var averageEnergy: Float {
        return _averageEnergy
    }

    func getCurrentThreshold() -> Float {
        if energyChunkCount < 10 {
            return 0  // No dropping during first 10 chunks
        }

        let ratio = totalChunksDuration > 0 ? totalTranscriptionTime / totalChunksDuration : 1.0
        // If ratio = 1.2, then (ratio - 1.0) = 0.2 (20% threshold)
        // If ratio < 1.0 (model is faster than real-time), use minimum 1% threshold
        let thresholdFraction = max(0.01, ratio - 1.0)
        return _averageEnergy * Float(thresholdFraction)
    }

    func updateMetrics(energy: Float, chunkDuration: Double, transcriptionTime: Double, wasDropped: Bool) {
        // Update timing metrics
        totalTranscriptionTime += transcriptionTime
        totalChunksDuration += chunkDuration

        // Update energy average only if chunk was accepted
        if !wasDropped {
            if energyChunkCount == 0 {
                _averageEnergy = energy
            } else {
                _averageEnergy = (_averageEnergy * Float(energyChunkCount) + energy) / Float(energyChunkCount + 1)
            }
            energyChunkCount += 1
        }
    }

    func reset() {
        _averageEnergy = 0.0
        energyChunkCount = 0
        totalTranscriptionTime = 0.0
        totalChunksDuration = 0.0
    }
}
