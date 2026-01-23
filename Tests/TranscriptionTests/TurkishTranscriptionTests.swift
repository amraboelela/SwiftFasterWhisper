//
// TurkishTranscriptionTests.swift
// SwiftFasterWhisper Tests
//
// Created by Amr Aboelela on 1/22/2026.
//

import Testing
import Foundation
@testable import SwiftFasterWhisper

@Suite(.serialized)
struct TurkishTranscriptionTests {

    struct TurkishTestSegment: Codable {
        let seg_id: String
        let text: String
        let english: String
    }

    private func runTranscriptionTest(fileName: String) async throws {
        print("\n========== TEST: Turkish Transcription \(fileName) ==========")

        let base = TestBase()
        let audioPath = try base.findTestFile("turkish_segments/\(fileName).wav")
        let jsonPath = try base.findTestFile("turkish_segments/\(fileName).json")

        // Load expected transcriptions
        let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
        let segments = try JSONDecoder().decode([TurkishTestSegment].self, from: jsonData)

        // Combine all expected text
        let expectedText = segments.map { $0.text }.joined(separator: " ")
        print("Expected (Turkish): \(expectedText)")

        // Skip test if expected text is empty
        guard !expectedText.isEmpty else {
            print("⚠️  Skipping test - expected text is empty")
            print("==========================================================\n")
            return
        }

        // Transcribe with Whisper
        let whisper = try await base.getWhisper()
        let result = try await whisper.transcribe(
            audioFilePath: audioPath,
            language: "tr"
        )

        let generatedText = result.segments.map { $0.text.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
        print("Generated: \(generatedText)")

        // Compare using Turkish-aware comparison
        let comparison = base.compareWithReference(generated: generatedText, expected: expectedText)

        print("\nResults:")
        print("  Accuracy: \(String(format: "%.1f", comparison.accuracy))%")
        print("  Correct chars: \(comparison.correct)/\(comparison.total)")
        print("  Edit distance: \(comparison.editDistance)")

        #expect(comparison.accuracy > 70.0, "Turkish transcription accuracy should be > 70%")
        print("==========================================================\n")
    }

    @Test func transcribe1_0013() async throws {
        try await runTranscriptionTest(fileName: "1-0013")
    }

    @Test func transcribe1_0100_2() async throws {
        try await runTranscriptionTest(fileName: "1-0100-2")
    }

    @Test func transcribe1_0150() async throws {
        try await runTranscriptionTest(fileName: "1-0150")
    }

    @Test func transcribe1_0250_4() async throws {
        try await runTranscriptionTest(fileName: "1-0250-4")
    }

    @Test func transcribe1_0300_5c() async throws {
        try await runTranscriptionTest(fileName: "1-0300-5c")
    }

    @Test func transcribe1_0500_3() async throws {
        try await runTranscriptionTest(fileName: "1-0500-3")
    }

    @Test func transcribe1_0701_3() async throws {
        try await runTranscriptionTest(fileName: "1-0701-3")
    }

    @Test func transcribe1_0703() async throws {
        try await runTranscriptionTest(fileName: "1-0703")
    }

    @Test func transcribe2_0050_2() async throws {
        try await runTranscriptionTest(fileName: "2-0050-2")
    }

    @Test func transcribe2_0100_2() async throws {
        try await runTranscriptionTest(fileName: "2-0100-2")
    }

    @Test func transcribe2_0150_5c() async throws {
        try await runTranscriptionTest(fileName: "2-0150-5c")
    }

    @Test func transcribe2_0200_3() async throws {
        try await runTranscriptionTest(fileName: "2-0200-3")
    }

    @Test func transcribe2_0300() async throws {
        try await runTranscriptionTest(fileName: "2-0300")
    }

    @Test func transcribe2_0350() async throws {
        try await runTranscriptionTest(fileName: "2-0350")
    }

    @Test func transcribe3_0100_4() async throws {
        try await runTranscriptionTest(fileName: "3-0100-4")
    }

    @Test func transcribe3_0400_5c() async throws {
        try await runTranscriptionTest(fileName: "3-0400-5c")
    }

    @Test func transcribe3_0500_2() async throws {
        try await runTranscriptionTest(fileName: "3-0500-2")
    }

    @Test func transcribe3_0800_3() async throws {
        try await runTranscriptionTest(fileName: "3-0800-3")
    }

    @Test func transcribe3_1000() async throws {
        try await runTranscriptionTest(fileName: "3-1000")
    }
}
