//
// EnergyDetectionTests.swift
// SwiftFasterWhisper Tests
//
// Created by Amr Aboelela on 1/21/2026.
//

import Testing
import AVFoundation
@testable import SwiftFasterWhisper

@Suite(.serialized)
struct EnergyDetectionTests {

    @Test func calculateEnergyForSilence() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== TEST: Energy calculation for silence ==========")

        let recognizer = StreamingRecognizer(modelPath: modelPath)

        // Pure silence (all zeros)
        let silence = [Float](repeating: 0.0, count: 16000)
        let energy = recognizer.calculateEnergy(silence)

        print("Silence energy: \(energy)")
        print("Expected: 0.0")

        #expect(energy == 0.0, "Silence should have zero energy")
        #expect(!recognizer.hasSufficientEnergy(silence), "Silence should not have sufficient energy")

        print("==========================================================\n")
    }

    @Test func calculateEnergyForLowAmplitudeAudio() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== TEST: Energy calculation for low amplitude ==========")

        let recognizer = StreamingRecognizer(modelPath: modelPath)

        // Very low amplitude audio (below default threshold of 0.01)
        let lowAmplitude = [Float](repeating: 0.005, count: 16000)
        let energy = recognizer.calculateEnergy(lowAmplitude)

        print("Low amplitude energy: \(energy)")
        print("Energy threshold: \(recognizer.energyThreshold)")
        print("Has sufficient energy: \(recognizer.hasSufficientEnergy(lowAmplitude))")

        #expect(abs(energy - 0.005) < 0.001, "Low amplitude energy should be approximately 0.005")
        #expect(energy < recognizer.energyThreshold, "Low amplitude should be below threshold")
        #expect(!recognizer.hasSufficientEnergy(lowAmplitude), "Low amplitude should not have sufficient energy")

        print("=================================================================\n")
    }

    @Test func calculateEnergyForNormalAudio() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== TEST: Energy calculation for normal audio ==========")

        let recognizer = StreamingRecognizer(modelPath: modelPath)

        // Normal amplitude audio (above threshold)
        let normalAmplitude = [Float](repeating: 0.1, count: 16000)
        let energy = recognizer.calculateEnergy(normalAmplitude)

        print("Normal amplitude energy: \(energy)")
        print("Energy threshold: \(recognizer.energyThreshold)")
        print("Has sufficient energy: \(recognizer.hasSufficientEnergy(normalAmplitude))")

        #expect(abs(energy - 0.1) < 0.001, "Normal amplitude energy should be approximately 0.1")
        #expect(energy > recognizer.energyThreshold, "Normal amplitude should be above threshold")
        #expect(recognizer.hasSufficientEnergy(normalAmplitude), "Normal amplitude should have sufficient energy")

        print("================================================================\n")
    }

    @Test func calculateEnergyForRealAudio() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== TEST: Energy calculation for real audio ==========")

        let recognizer = StreamingRecognizer(modelPath: modelPath)

        let audioPath = try base.findTestFile("jfk.wav")
        let fullAudio = try base.convertAudioToPCM(audioPath: audioPath)

        // Take first 1-second chunk (16000 samples)
        let chunk = Array(fullAudio.prefix(16000))
        let energy = recognizer.calculateEnergy(chunk)

        print("Real audio energy (first 1s): \(String(format: "%.6f", energy))")
        print("Energy threshold: \(recognizer.energyThreshold)")
        print("Has sufficient energy: \(recognizer.hasSufficientEnergy(chunk))")

        #expect(energy > 0.0, "Real audio should have non-zero energy")
        #expect(recognizer.hasSufficientEnergy(chunk), "Speech audio should have sufficient energy")

        print("==============================================================\n")
    }

    @Test func addAudioChunkSkipsLowEnergy() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== TEST: addAudioChunk skips low energy chunks ==========")

        let recognizer = StreamingRecognizer(modelPath: modelPath)
        try recognizer.loadModel()
        try recognizer.startStreaming(language: "en")

        // Test silence chunk
        let silence = [Float](repeating: 0.0, count: 16000)
        let processedSilence = try recognizer.addAudioChunk(silence)

        print("Silence chunk processed: \(processedSilence)")
        #expect(!processedSilence, "Silence chunk should be skipped (return false)")

        // Test low energy chunk
        let lowEnergy = [Float](repeating: 0.005, count: 16000)
        let processedLowEnergy = try recognizer.addAudioChunk(lowEnergy)

        print("Low energy chunk processed: \(processedLowEnergy)")
        #expect(!processedLowEnergy, "Low energy chunk should be skipped (return false)")

        // Test normal energy chunk
        let normalEnergy = [Float](repeating: 0.1, count: 16000)
        let processedNormal = try recognizer.addAudioChunk(normalEnergy)

        print("Normal energy chunk processed: \(processedNormal)")
        #expect(processedNormal, "Normal energy chunk should be processed (return true)")

        recognizer.stopStreaming()

        print("==================================================================\n")
    }

    @Test func customEnergyThreshold() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== TEST: Custom energy threshold ==========")

        let recognizer = StreamingRecognizer(modelPath: modelPath)

        let chunk = [Float](repeating: 0.05, count: 16000)
        let energy = recognizer.calculateEnergy(chunk)

        print("Chunk energy: \(energy)")

        // Default threshold (0.01)
        print("\nWith default threshold (0.01):")
        print("  Has sufficient energy: \(recognizer.hasSufficientEnergy(chunk))")
        #expect(recognizer.hasSufficientEnergy(chunk), "Should have sufficient energy with default threshold")

        // Increase threshold to 0.1
        recognizer.energyThreshold = 0.1
        print("\nWith custom threshold (0.1):")
        print("  Has sufficient energy: \(recognizer.hasSufficientEnergy(chunk))")
        #expect(!recognizer.hasSufficientEnergy(chunk), "Should NOT have sufficient energy with higher threshold")

        // Lower threshold to 0.001
        recognizer.energyThreshold = 0.001
        print("\nWith custom threshold (0.001):")
        print("  Has sufficient energy: \(recognizer.hasSufficientEnergy(chunk))")
        #expect(recognizer.hasSufficientEnergy(chunk), "Should have sufficient energy with lower threshold")

        print("====================================================\n")
    }

    @Test func streamingWithMixedEnergyChunks() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== TEST: Streaming with mixed energy chunks ==========")

        let audioPath = try base.findTestFile("jfk.wav")
        let fullAudio = try base.convertAudioToPCM(audioPath: audioPath)

        let recognizer = StreamingRecognizer(modelPath: modelPath)
        try recognizer.loadModel()
        try recognizer.startStreaming(language: "en")

        var processedCount = 0
        var skippedCount = 0
        var offset = 0
        let chunkSize = 16000

        print("\n--- Processing chunks with energy detection ---")

        while offset < min(fullAudio.count, 5 * chunkSize) {  // Process first 5 seconds
            let end = min(offset + chunkSize, fullAudio.count)
            let chunk = Array(fullAudio[offset..<end])

            let energy = recognizer.calculateEnergy(chunk)
            let processed = try recognizer.addAudioChunk(chunk)

            if processed {
                print("[Chunk \(offset / chunkSize + 1)] Energy: \(String(format: "%.6f", energy)) - PROCESSED ✅")
                processedCount += 1
            } else {
                print("[Chunk \(offset / chunkSize + 1)] Energy: \(String(format: "%.6f", energy)) - SKIPPED (low energy)")
                skippedCount += 1
            }

            offset = end
        }

        recognizer.stopStreaming()

        print("\n--- Summary ---")
        print("Processed chunks: \(processedCount)")
        print("Skipped chunks: \(skippedCount)")
        print("Total chunks: \(processedCount + skippedCount)")

        #expect(processedCount > 0, "Should process at least some chunks with speech")

        print("===============================================================\n")
    }
}
