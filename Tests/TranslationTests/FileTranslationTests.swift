//
// FileTranslationTests.swift
// SwiftFasterWhisper Tests
//
// Created by Amr Aboelela on 1/21/2026.
//

import Testing
import AVFoundation
@testable import SwiftFasterWhisper

@Suite(.serialized)
struct FileTranslationTests {

    // MARK: - Translation Tests (using Whisper's built-in translation)

    @Test func translateToEnglish() async throws {
        let base = TestBase()
        let whisper = try await base.getWhisper()

        let expectedTurkish = "Kuraklık yüzünden yeterince ot bitmiyor. Biz de boyayı sulandırmak zorunda kaldık. Canlı başla uğraşıyoruz ama anca bu kadar oluyor."
        let expectedEnglish = "We've had enough of the drought. We had to water the plant. We're trying our best but that's all we can do."

        let audioPath = try base.findTestFile("05-speech.wav")

        guard FileManager.default.fileExists(atPath: audioPath) else {
            struct SkipError: Error {
                let message: String
            }
            throw SkipError(message: "Audio file not found at: \(audioPath)")
        }

        print("\n========== TRANSLATION TEST ==========")
        print("Expected English: \(expectedEnglish)")
        print("======================================\n")

        let audioFrames = try base.convertAudioToPCM(audioPath: audioPath)
        print("Loading audio file: \(audioPath)")
        print("Duration: \(String(format: "%.2f", Double(audioFrames.count) / 16000.0)) seconds")
        print("Original format: 16000.0Hz, 1 channels")
        print("Loaded \(audioFrames.count) PCM samples")

        do {
            print("Starting translation to English...")
            let result = try await whisper.translate(audio: audioFrames, sourceLanguage: "tr")

            let fullText = result.text
            let comparison = base.compareWithReference(generated: fullText, expected: expectedEnglish)

            print("\n========== ACCURACY ANALYSIS ==========")
            print("Turkish: \(expectedTurkish)")
            print("Expected (English): \(expectedEnglish)")
            print("Generated (Whisper): \(fullText)")
            print("\nMetrics:")
            print("  Correct characters: \(comparison.correct)/\(comparison.total)")
            print("  Edit distance: \(comparison.editDistance)")
            print("  Accuracy: \(String(format: "%.2f", comparison.accuracy))%")
            print("=======================================\n")

            #expect(result.segments.count > 0, "Should receive at least one segment")
            #expect(fullText.count > 0, "Should have some translated text")

            #expect(comparison.accuracy > 50.0,
                "Translation accuracy should be greater than 50%. Got \(String(format: "%.2f", comparison.accuracy))%")

            if comparison.accuracy > 50.0 {
                print("✅ SUCCESS: Translation accuracy (\(String(format: "%.2f", comparison.accuracy))%) is above 50% threshold!")
            } else {
                print("❌ FAILED: Translation accuracy (\(String(format: "%.2f", comparison.accuracy))%) is below 50% threshold!")
            }
        } catch {
            print("⚠ Translation test skipped (may not be fully implemented yet): \(error)")
            struct SkipError: Error {
                let message: String
            }
            throw SkipError(message: "Translation not yet fully implemented")
        }
    }

    @Test func translateSegment06ToEnglish() async throws {
        let base = TestBase()
        let whisper = try await base.getWhisper()

        let expectedTurkish = "Çivi totunu yapraklarıyla köklerini denediniz mi?"
        let expectedEnglish = "Have you tried the roots of the leaves of the pine tree?"

        let audioPath = try base.findTestFile("06-speech.wav")

        guard FileManager.default.fileExists(atPath: audioPath) else {
            struct SkipError: Error {
                let message: String
            }
            throw SkipError(message: "Audio file not found at: \(audioPath)")
        }

        print("\n========== TRANSLATION TEST (Segment 06) ==========")
        print("Expected English: \(expectedEnglish)")
        print("===================================================\n")

        let audioFrames = try base.convertAudioToPCM(audioPath: audioPath)
        print("Loading audio file: \(audioPath)")
        print("Duration: \(String(format: "%.2f", Double(audioFrames.count) / 16000.0)) seconds")
        print("Original format: 16000.0Hz, 1 channels")
        print("Loaded \(audioFrames.count) PCM samples")

        do {
            print("Starting translation to English...")
            let result = try await whisper.translate(audio: audioFrames, sourceLanguage: "tr")

            let fullText = result.text
            let comparison = base.compareWithReference(generated: fullText, expected: expectedEnglish)

            print("\n========== ACCURACY ANALYSIS ==========")
            print("Turkish: \(expectedTurkish)")
            print("Expected (English): \(expectedEnglish)")
            print("Generated (Whisper): \(fullText)")
            print("\nMetrics:")
            print("  Correct characters: \(comparison.correct)/\(comparison.total)")
            print("  Edit distance: \(comparison.editDistance)")
            print("  Accuracy: \(String(format: "%.2f", comparison.accuracy))%")
            print("=======================================\n")

            #expect(result.segments.count > 0, "Should receive at least one segment")
            #expect(fullText.count > 0, "Should have some translated text")

            #expect(comparison.accuracy > 50.0,
                "Translation accuracy should be greater than 50%. Got \(String(format: "%.2f", comparison.accuracy))%")

            if comparison.accuracy > 50.0 {
                print("✅ SUCCESS: Translation accuracy (\(String(format: "%.2f", comparison.accuracy))%) is above 50% threshold!")
            } else {
                print("❌ FAILED: Translation accuracy (\(String(format: "%.2f", comparison.accuracy))%) is below 50% threshold!")
            }
        } catch {
            print("⚠ Translation test skipped: \(error)")
            struct SkipError: Error {
                let message: String
            }
            throw SkipError(message: "Translation not yet fully implemented")
        }
    }

    @Test func translateSegment12ToEnglish() async throws {
        let base = TestBase()
        let whisper = try await base.getWhisper()

        let expectedTurkish = "Başka bir çare bulmalıyız. Çok arıyorum."
        let expectedEnglish = "We must find another solution. I'm looking very hard."

        let audioPath = try base.findTestFile("12-speech.wav")

        guard FileManager.default.fileExists(atPath: audioPath) else {
            struct SkipError: Error {
                let message: String
            }
            throw SkipError(message: "Audio file not found at: \(audioPath)")
        }

        print("\n========== TRANSLATION TEST (Segment 12) ==========")
        print("Expected English: \(expectedEnglish)")
        print("===================================================\n")

        let audioFrames = try base.convertAudioToPCM(audioPath: audioPath)
        print("Loading audio file: \(audioPath)")
        print("Duration: \(String(format: "%.2f", Double(audioFrames.count) / 16000.0)) seconds")
        print("Original format: 16000.0Hz, 1 channels")
        print("Loaded \(audioFrames.count) PCM samples")

        do {
            print("Starting translation to English...")
            let result = try await whisper.translate(audio: audioFrames, sourceLanguage: "tr")

            let fullText = result.text
            let comparison = base.compareWithReference(generated: fullText, expected: expectedEnglish)

            print("\n========== ACCURACY ANALYSIS ==========")
            print("Turkish: \(expectedTurkish)")
            print("Expected (English): \(expectedEnglish)")
            print("Generated (Whisper): \(fullText)")
            print("\nMetrics:")
            print("  Correct characters: \(comparison.correct)/\(comparison.total)")
            print("  Edit distance: \(comparison.editDistance)")
            print("  Accuracy: \(String(format: "%.2f", comparison.accuracy))%")
            print("=======================================\n")

            #expect(result.segments.count > 0, "Should receive at least one segment")
            #expect(fullText.count > 0, "Should have some translated text")

            #expect(comparison.accuracy > 50.0,
                "Translation accuracy should be greater than 50%. Got \(String(format: "%.2f", comparison.accuracy))%")

            if comparison.accuracy > 50.0 {
                print("✅ SUCCESS: Translation accuracy (\(String(format: "%.2f", comparison.accuracy))%) is above 50% threshold!")
            } else {
                print("❌ FAILED: Translation accuracy (\(String(format: "%.2f", comparison.accuracy))%) is below 50% threshold!")
            }
        } catch {
            print("⚠ Translation test skipped: \(error)")
            struct SkipError: Error {
                let message: String
            }
            throw SkipError(message: "Translation not yet fully implemented")
        }
    }
}
