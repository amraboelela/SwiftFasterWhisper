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

    private func runTranslationTest(fileName: String) async throws {
        print("\n========== TEST: Turkish→English Translation \(fileName) ==========")

        let base = TestBase()
        let audioPath = try base.findTestFile("turkish_segments/\(fileName).wav")
        let jsonPath = try base.findTestFile("turkish_segments/\(fileName).json")

        // Load expected translations
        let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
        let segments = try JSONDecoder().decode([TurkishTestSegment].self, from: jsonData)

        // Combine all expected English text
        let expectedText = segments.map { $0.english }.joined(separator: " ")
        print("Expected (English): \(expectedText)")

        // Translate with Whisper's built-in translation
        let whisper = try await base.getWhisper()
        let result = try await whisper.translate(
            audioFilePath: audioPath,
            sourceLanguage: "tr"
        )

        let generatedText = result.segments.map { $0.text.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
        print("Generated (Whisper): \(generatedText)")

        // Compare using English comparison
        let comparison = base.compareWithReference(generated: generatedText, expected: expectedText)

        print("\nResults:")
        print("  Accuracy: \(String(format: "%.1f", comparison.accuracy))%")
        print("  Correct chars: \(comparison.correct)/\(comparison.total)")
        print("  Edit distance: \(comparison.editDistance)")

        #expect(comparison.accuracy > 60.0, "Turkish→English translation accuracy should be > 60%")
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

    @Test func translate3_0500_2() async throws {
        try await runTranslationTest(fileName: "3-0500-2")
    }

    @Test func translate3_0800_3() async throws {
        try await runTranslationTest(fileName: "3-0800-3")
    }

    @Test func translate3_1000() async throws {
        try await runTranslationTest(fileName: "3-1000")
    }
}
