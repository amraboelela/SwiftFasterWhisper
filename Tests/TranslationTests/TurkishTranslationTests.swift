//
// TurkishTranslationTests.swift
// SwiftFasterWhisper Tests
//
// Created by Amr Aboelela on 1/22/2026.
//

import Testing
import Foundation
@testable import SwiftFasterWhisper

@Suite(.serialized)
struct TurkishTranslationTests {

    struct TurkishTestSegment: Codable {
        let seg_id: String
        let text: String
        let english: String
    }

    // Track total audio duration across all tests
    static var totalAudioDuration: Double = 0.0
    static var testStartTime: Date?

    private func runTranslationTest(fileName: String) async throws {
        if Self.testStartTime == nil {
            Self.testStartTime = Date()
        }

        print("\n========== TEST: Turkish→English Translation \(fileName) ==========")

        let base = TestBase()
        let audioPath = try base.findTestFile("turkish_segments/\(fileName).wav")
        let jsonPath = try base.findTestFile("turkish_segments/\(fileName).json")

        // Load expected translations
        let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
        let segments = try JSONDecoder().decode([TurkishTestSegment].self, from: jsonData)

        // Combine all expected text
        let expectedTurkish = segments.map { $0.text }.joined(separator: " ")
        let expectedEnglish = segments.map { $0.english }.joined(separator: " ")

        // Get audio duration
        let fullAudio = try base.convertAudioToPCM(audioPath: audioPath)
        let audioDuration = Double(fullAudio.count) / 16000.0
        Self.totalAudioDuration += audioDuration

        print("Audio duration: \(String(format: "%.2f", audioDuration))s")
        print("Turkish (original): \(expectedTurkish)")
        print("Expected (English): \(expectedEnglish)")

        // Skip test if expected text is empty
        guard !expectedEnglish.isEmpty else {
            print("⚠️  Skipping test - expected text is empty")
            print("================================================================\n")
            return
        }

        // Translate with Whisper's built-in translation
        let whisper = try await base.getWhisper()
        let result = try await whisper.translate(
            audioFilePath: audioPath,
            sourceLanguage: "tr"
        )

        let generatedText = result.segments.map { $0.text.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
        print("Generated (Whisper): \(generatedText)")

        // Compare using English comparison
        let comparison = base.compareWithReference(generated: generatedText, expected: expectedEnglish)

        print("\nResults:")
        print("  Accuracy: \(String(format: "%.1f", comparison.accuracy))%")
        print("  Correct chars: \(comparison.correct)/\(comparison.total)")
        print("  Edit distance: \(comparison.editDistance)")

        #expect(comparison.accuracy > 20.0, "Turkish→English translation accuracy should be > 20%")
        print("================================================================\n")
    }

    @Test func translate1_0013() async throws {
        try await runTranslationTest(fileName: "1-0013")
    }

    @Test func translate1_0100_2() async throws {
        try await runTranslationTest(fileName: "1-0100-2")
    }

    @Test func translate1_0150() async throws {
        try await runTranslationTest(fileName: "1-0150")
    }

    @Test func translate1_0250_4() async throws {
        try await runTranslationTest(fileName: "1-0250-4")
    }

    @Test func translate1_0300_5c() async throws {
        try await runTranslationTest(fileName: "1-0300-5c")
    }

    @Test func translate1_0500_3() async throws {
        try await runTranslationTest(fileName: "1-0500-3")
    }

    @Test func translate1_0701_3() async throws {
        try await runTranslationTest(fileName: "1-0701-3")
    }

    @Test func translate1_0703() async throws {
        try await runTranslationTest(fileName: "1-0703")
    }

    @Test func translate2_0050_2() async throws {
        try await runTranslationTest(fileName: "2-0050-2")
    }

    @Test func translate2_0100_2() async throws {
        try await runTranslationTest(fileName: "2-0100-2")
    }

    @Test func translate2_0150_5c() async throws {
        try await runTranslationTest(fileName: "2-0150-5c")
    }

    @Test func translate2_0200_3() async throws {
        try await runTranslationTest(fileName: "2-0200-3")
    }

    @Test func translate2_0300() async throws {
        try await runTranslationTest(fileName: "2-0300")
    }

    @Test func translate2_0350() async throws {
        try await runTranslationTest(fileName: "2-0350")
    }

    @Test func translate3_0100_4() async throws {
        try await runTranslationTest(fileName: "3-0100-4")
    }

    @Test func translate3_0400_5c() async throws {
        try await runTranslationTest(fileName: "3-0400-5c")
    }

    @Test func translate3_0800_3() async throws {
        try await runTranslationTest(fileName: "3-0800-3")
    }

    @Test func translate3_1000() async throws {
        try await runTranslationTest(fileName: "3-1000")
    }

    @Test func zz_printSummary() async throws {
        // This test runs last (alphabetically) to print the summary
        guard let startTime = Self.testStartTime else {
            print("\n⚠️  No tests were run")
            return
        }

        let totalTime = Date().timeIntervalSince(startTime)
        let responseRatio = (totalTime / Self.totalAudioDuration) * 100.0

        print("\n========== TRANSLATION TEST SUITE SUMMARY ==========")
        print("Total audio duration: \(String(format: "%.2f", Self.totalAudioDuration))s")
        print("Total processing time: \(String(format: "%.2f", totalTime))s")
        print("Response time ratio: \(String(format: "%.1f", responseRatio))%")
        print("(Lower is better - 100% means real-time, <100% is faster than real-time)")
        print("====================================================\n")
    }
}
