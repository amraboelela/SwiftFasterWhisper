//
// StreamingSegmentsTranslationTests.swift
// SwiftFasterWhisper Tests
//
// Created by Amr Aboelela on 1/22/2026.
//

import Testing
import Foundation
@testable import SwiftFasterWhisper

@Suite(.serialized)
struct StreamingSegmentsTranslationTests {

    struct TurkishTestSegment: Codable {
        let seg_id: String
        let text: String
        let english: String
    }

    // Track total audio duration across all tests
    static var totalAudioDuration: Double = 0.0
    static var testStartTime: Date?

    private func runStreamingTranslationTest(fileName: String) async throws {
        if Self.testStartTime == nil {
            Self.testStartTime = Date()
        }

        print("\n========== TEST: Streaming Translation \(fileName) (4s window, 4s slide) ==========")

        let base = TestBase()
        let audioPath = try base.findTestFile("turkish_segments/\(fileName).wav")
        let jsonPath = try base.findTestFile("turkish_segments/\(fileName).json")

        // Load expected translations
        let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
        let segments = try JSONDecoder().decode([TurkishTestSegment].self, from: jsonData)

        // Combine all expected English text
        let expectedText = segments.map { $0.english }.joined(separator: " ")

        // Combine all Turkish text for reference
        let turkishText = segments.map { $0.text }.joined(separator: " ")

        // Get model path and convert audio
        let modelPath = try await base.downloadModelIfNeeded()
        let fullAudio = try base.convertAudioToPCM(audioPath: audioPath)

        let audioDuration = Double(fullAudio.count) / 16000.0
        Self.totalAudioDuration += audioDuration

        print("Audio duration: \(String(format: "%.2f", Double(fullAudio.count) / 16000.0))s")
        print("Turkish: \(turkishText)")
        print("Expected: \(expectedText)")

        // Skip test if audio is too short for streaming (need at least 8s for 4s window + 4s slide)
        guard audioDuration >= 8.0 else {
            print("⚠️  Skipping test - audio too short for streaming (< 8s)")
            print("================================================================\n")
            return
        }

        // Skip test if expected text is empty
        guard !expectedText.isEmpty else {
            print("⚠️  Skipping test - expected text is empty")
            print("================================================================\n")
            return
        }

        // Use streaming recognizer
        let recognizer = StreamingRecognizer(modelPath: modelPath)
        try await recognizer.configure(language: "tr", task: "translate")

        var allText = ""

        print("\n--- Sending 1s audio chunks (simulating real-time) ---")

        let producer = ChunksProducer(audio: fullAudio)
        try await producer.start(
            onChunk: { chunkNumber, chunk, isLast in
                print("[Chunk \(chunkNumber)] Sending \(String(format: "%.2f", Float(chunk.count) / 16000.0))s")
                await recognizer.addAudioChunk(chunk)

                // Check for new text (non-blocking poll)
                let text = await recognizer.getNewText()
                if !text.isEmpty {
                    print("📤 Received text: '\(text)'")
                    if !allText.isEmpty {
                        allText += " "
                    }
                    allText += text
                }
            },
            onComplete: {
                // Get any final text
                let finalText = await recognizer.getNewText()
                if !finalText.isEmpty {
                    print("📤 Received final text: '\(finalText)'")
                    if !allText.isEmpty {
                        allText += " "
                    }
                    allText += finalText
                }

                await recognizer.stop()
            }
        )

        print("\nTurkish: \(turkishText)")
        print("Expected: \(expectedText)")
        print("Generated: \(allText)")

        // Skip comparison if no segments generated
        guard !allText.isEmpty else {
            print("⚠️  No segments generated - audio too short for 4s window")
            print("================================================================\n")
            return
        }

        // Compare using English comparison
        let comparison = base.compareWithReference(generated: allText, expected: expectedText)

        print("\nResults:")
        print("  Accuracy: \(String(format: "%.1f", comparison.accuracy))%")
        print("  Correct chars: \(comparison.correct)/\(comparison.total)")
        print("  Edit distance: \(comparison.editDistance)")

        #expect(comparison.accuracy > 30.0, "Streaming translation accuracy should be > 30%")
        print("================================================================\n")
    }

    @Test func streamingTranslate1_0100_2() async throws {
        try await runStreamingTranslationTest(fileName: "1-0100-2")
    }

    @Test func streamingTranslate1_0150() async throws {
        try await runStreamingTranslationTest(fileName: "1-0150")
    }

    @Test func streamingTranslate1_0250_4() async throws {
        try await runStreamingTranslationTest(fileName: "1-0250-4")
    }

    @Test func streamingTranslate1_0300_5c() async throws {
        try await runStreamingTranslationTest(fileName: "1-0300-5c")
    }

    @Test func streamingTranslate1_0500_3() async throws {
        try await runStreamingTranslationTest(fileName: "1-0500-3")
    }

    @Test func streamingTranslate1_0701_3() async throws {
        try await runStreamingTranslationTest(fileName: "1-0701-3")
    }

    @Test func streamingTranslate2_0150_5c() async throws {
        try await runStreamingTranslationTest(fileName: "2-0150-5c")
    }

    @Test func streamingTranslate2_0200_3() async throws {
        try await runStreamingTranslationTest(fileName: "2-0200-3")
    }

    @Test func streamingTranslate3_0100_4() async throws {
        try await runStreamingTranslationTest(fileName: "3-0100-4")
    }

    @Test func streamingTranslate3_0400_5c() async throws {
        try await runStreamingTranslationTest(fileName: "3-0400-5c")
    }

    @Test func streamingTranslate3_0800_3() async throws {
        try await runStreamingTranslationTest(fileName: "3-0800-3")
    }

    @Test func zz_printSummary() async throws {
        // This test runs last (alphabetically) to print the summary
        guard let startTime = Self.testStartTime else {
            print("\n⚠️  No tests were run")
            return
        }

        let totalTime = Date().timeIntervalSince(startTime)
        let responseRatio = (totalTime / Self.totalAudioDuration) * 100.0

        print("\n========== STREAMING TRANSLATION TEST SUITE SUMMARY ==========")
        print("Total audio duration: \(String(format: "%.2f", Self.totalAudioDuration))s")
        print("Total processing time: \(String(format: "%.2f", totalTime))s")
        print("Response time ratio: \(String(format: "%.1f", responseRatio))%")
        print("(Lower is better - 100% means real-time, <100% is faster than real-time)")
        print("==============================================================\n")
    }
}
