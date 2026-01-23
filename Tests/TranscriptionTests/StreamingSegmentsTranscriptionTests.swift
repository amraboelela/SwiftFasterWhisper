//
// StreamingSegmentsTranscriptionTests.swift
// SwiftFasterWhisper Tests
//
// Created by Amr Aboelela on 1/22/2026.
//

import Testing
import Foundation
@testable import SwiftFasterWhisper

@Suite(.serialized)
struct StreamingSegmentsTranscriptionTests {

    struct TurkishTestSegment: Codable {
        let seg_id: String
        let text: String
        let english: String
    }

    private func runStreamingTranscriptionTest(fileName: String) async throws {
        print("\n========== TEST: Streaming Transcription \(fileName) (4s window) ==========")

        let base = TestBase()
        let audioPath = try base.findTestFile("turkish_segments/\(fileName).wav")
        let jsonPath = try base.findTestFile("turkish_segments/\(fileName).json")

        // Load expected transcriptions
        let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
        let segments = try JSONDecoder().decode([TurkishTestSegment].self, from: jsonData)

        // Combine all expected Turkish text
        let expectedText = segments.map { $0.text }.joined(separator: " ")

        // Get model path and convert audio
        let modelPath = try await base.downloadModelIfNeeded()
        let fullAudio = try base.convertAudioToPCM(audioPath: audioPath)

        print("Audio duration: \(String(format: "%.2f", Double(fullAudio.count) / 16000.0))s")
        print("Expected (Turkish): \(expectedText)")

        // Skip test if expected text is empty
        guard !expectedText.isEmpty else {
            print("⚠️  Skipping test - expected text is empty")
            print("================================================================\n")
            return
        }

        // Use streaming recognizer
        let recognizer = StreamingRecognizer(modelPath: modelPath)
        try recognizer.loadModel()
        try recognizer.startStreaming(language: "tr", task: "transcribe")

        let chunkSize = 8000  // 0.5 seconds
        var allSegments: [String] = []
        var offset = 0

        while offset < fullAudio.count {
            let end = min(offset + chunkSize, fullAudio.count)
            let chunk = Array(fullAudio[offset..<end])

            try recognizer.addAudioChunk(chunk)

            if let segment = try recognizer.getNewSegment() {
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                allSegments.append(text)
            }

            offset = end
        }

        // Final poll
        if let segment = try recognizer.getNewSegment() {
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            allSegments.append(text)
        }

        recognizer.stopStreaming()

        let generatedText = allSegments.joined(separator: " ")
        print("Generated (Turkish): \(generatedText)")

        // Compare using Turkish-aware comparison
        let comparison = base.compareWithReference(generated: generatedText, expected: expectedText)

        print("\nResults:")
        print("  Accuracy: \(String(format: "%.1f", comparison.accuracy))%")
        print("  Correct chars: \(comparison.correct)/\(comparison.total)")
        print("  Edit distance: \(comparison.editDistance)")

        #expect(comparison.accuracy > 60.0, "Streaming transcription accuracy should be > 60%")
        print("================================================================\n")
    }

    @Test func streamingTranscribe1_0013() async throws {
        try await runStreamingTranscriptionTest(fileName: "1-0013")
    }

    @Test func streamingTranscribe1_0100_2() async throws {
        try await runStreamingTranscriptionTest(fileName: "1-0100-2")
    }

    @Test func streamingTranscribe1_0150() async throws {
        try await runStreamingTranscriptionTest(fileName: "1-0150")
    }

    @Test func streamingTranscribe1_0250_4() async throws {
        try await runStreamingTranscriptionTest(fileName: "1-0250-4")
    }

    @Test func streamingTranscribe1_0300_5c() async throws {
        try await runStreamingTranscriptionTest(fileName: "1-0300-5c")
    }

    @Test func streamingTranscribe1_0500_3() async throws {
        try await runStreamingTranscriptionTest(fileName: "1-0500-3")
    }

    @Test func streamingTranscribe1_0701_3() async throws {
        try await runStreamingTranscriptionTest(fileName: "1-0701-3")
    }

    @Test func streamingTranscribe1_0703() async throws {
        try await runStreamingTranscriptionTest(fileName: "1-0703")
    }

    @Test func streamingTranscribe2_0050_2() async throws {
        try await runStreamingTranscriptionTest(fileName: "2-0050-2")
    }

    @Test func streamingTranscribe2_0100_2() async throws {
        try await runStreamingTranscriptionTest(fileName: "2-0100-2")
    }

    @Test func streamingTranscribe2_0150_5c() async throws {
        try await runStreamingTranscriptionTest(fileName: "2-0150-5c")
    }

    @Test func streamingTranscribe2_0200_3() async throws {
        try await runStreamingTranscriptionTest(fileName: "2-0200-3")
    }

    @Test func streamingTranscribe2_0300() async throws {
        try await runStreamingTranscriptionTest(fileName: "2-0300")
    }

    @Test func streamingTranscribe2_0350() async throws {
        try await runStreamingTranscriptionTest(fileName: "2-0350")
    }

    @Test func streamingTranscribe3_0100_4() async throws {
        try await runStreamingTranscriptionTest(fileName: "3-0100-4")
    }

    @Test func streamingTranscribe3_0400_5c() async throws {
        try await runStreamingTranscriptionTest(fileName: "3-0400-5c")
    }

    @Test func streamingTranscribe3_0800_3() async throws {
        try await runStreamingTranscriptionTest(fileName: "3-0800-3")
    }

    @Test func streamingTranscribe3_1000() async throws {
        try await runStreamingTranscriptionTest(fileName: "3-1000")
    }
}
