//
// FileTranscriptionTests.swift
// SwiftFasterWhisper Tests
//
// Created by Amr Aboelela on 1/21/2026.
//

import Testing
import AVFoundation
@testable import SwiftFasterWhisper

@Suite(.serialized)
struct FileTranscriptionTests {

    @Test func transcribeEnglishAudio() async throws {
        let base = TestBase()
        let whisper = try await base.getWhisper()

        print("\n========== TRANSCRIPTION TEST (English) ==========")

        let audioPath = try base.findTestFile("jfk.wav")
        let audioFrames = try base.convertAudioToPCM(audioPath: audioPath)

        let result = try await whisper.transcribe(audio: audioFrames)
        let fullText = result.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        print("Language: \(result.language) (confidence: \(result.languageProbability))")
        print("Duration: \(result.duration) seconds")
        print("Segments: \(result.segments.count)")
        print("==========================================")

        let expectedText = "and so my fellow americans ask not what your country can do for you ask what you can do for your country"
        let comparison = base.compareWithReference(generated: fullText, expected: expectedText)

        print("========== ACCURACY ANALYSIS ==========")
        print("Expected: \(expectedText)")
        print("Generated: \(fullText)")
        print("\nMetrics:")
        print("  Correct characters: \(comparison.correct)/\(comparison.total)")
        print("  Edit distance: \(comparison.editDistance)")
        print("  Accuracy: \(String(format: "%.2f", comparison.accuracy))%")
        print("=======================================\n")

        #expect(comparison.accuracy > 80.0,
            "Transcription accuracy should be greater than 80%. Got \(String(format: "%.2f", comparison.accuracy))%")
    }

    @Test func transcribeTurkishAudio05() async throws {
        let base = TestBase()
        let whisper = try await base.getWhisper()

        print("\n========== TRANSCRIPTION TEST (Turkish 05) ==========")

        let expectedTurkish = "Kuraklık yüzünden yeterince ot bitmiyor. Biz de boyayı sulandırmak zorunda kaldık. Canlı başla uğraşıyoruz ama anca bu kadar oluyor."
        let audioPath = try base.findTestFile("05-speech.wav")
        let audioFrames = try base.convertAudioToPCM(audioPath: audioPath)

        let result = try await whisper.transcribe(audio: audioFrames, language: "tr")
        let fullText = result.text

        print("Language: \(result.language)")
        print("Duration: \(result.duration) seconds")
        print("Segments: \(result.segments.count)")
        print("==========================================")

        let comparison = base.compareWithReference(generated: fullText, expected: expectedTurkish)

        print("========== ACCURACY ANALYSIS ==========")
        print("Expected: \(expectedTurkish)")
        print("Generated: \(fullText)")
        print("\nMetrics:")
        print("  Correct characters: \(comparison.correct)/\(comparison.total)")
        print("  Edit distance: \(comparison.editDistance)")
        print("  Accuracy: \(String(format: "%.2f", comparison.accuracy))%")
        print("=======================================\n")

        #expect(comparison.accuracy > 70.0,
            "Turkish transcription accuracy should be greater than 70%. Got \(String(format: "%.2f", comparison.accuracy))%")
    }

    @Test func transcribeTurkishAudio06() async throws {
        let base = TestBase()
        let whisper = try await base.getWhisper()

        print("\n========== TRANSCRIPTION TEST (Turkish 06) ==========")

        let expectedTurkish = "Çivi totunu yapraklarıyla köklerini denediniz mi?"
        let audioPath = try base.findTestFile("06-speech.wav")
        let audioFrames = try base.convertAudioToPCM(audioPath: audioPath)

        let result = try await whisper.transcribe(audio: audioFrames, language: "tr")
        let fullText = result.text

        print("Language: \(result.language)")
        print("Duration: \(result.duration) seconds")
        print("Segments: \(result.segments.count)")
        print("==========================================")

        let comparison = base.compareWithReference(generated: fullText, expected: expectedTurkish)

        print("========== ACCURACY ANALYSIS ==========")
        print("Expected: \(expectedTurkish)")
        print("Generated: \(fullText)")
        print("\nMetrics:")
        print("  Correct characters: \(comparison.correct)/\(comparison.total)")
        print("  Edit distance: \(comparison.editDistance)")
        print("  Accuracy: \(String(format: "%.2f", comparison.accuracy))%")
        print("=======================================\n")

        #expect(comparison.accuracy > 70.0,
            "Turkish transcription accuracy should be greater than 70%. Got \(String(format: "%.2f", comparison.accuracy))%")
    }

    @Test func transcribeTurkishAudio12() async throws {
        let base = TestBase()
        let whisper = try await base.getWhisper()

        print("\n========== TRANSCRIPTION TEST (Turkish 12) ==========")

        let expectedTurkish = "Başka bir çare bulmalıyız. Çok arıyorum."
        let audioPath = try base.findTestFile("12-speech.wav")
        let audioFrames = try base.convertAudioToPCM(audioPath: audioPath)

        let result = try await whisper.transcribe(audio: audioFrames, language: "tr")
        let fullText = result.text

        print("Language: \(result.language)")
        print("Duration: \(result.duration) seconds")
        print("Segments: \(result.segments.count)")
        print("==========================================")

        let comparison = base.compareWithReference(generated: fullText, expected: expectedTurkish)

        print("========== ACCURACY ANALYSIS ==========")
        print("Expected: \(expectedTurkish)")
        print("Generated: \(fullText)")
        print("\nMetrics:")
        print("  Correct characters: \(comparison.correct)/\(comparison.total)")
        print("  Edit distance: \(comparison.editDistance)")
        print("  Accuracy: \(String(format: "%.2f", comparison.accuracy))%")
        print("=======================================\n")

        #expect(comparison.accuracy > 60.0,
            "Turkish transcription accuracy should be greater than 60%. Got \(String(format: "%.2f", comparison.accuracy))%")
    }

    @Test func emptyAudioError() async throws {
        let base = TestBase()
        let whisper = try await base.getWhisper()

        do {
            _ = try await whisper.transcribe(audio: [])
            Issue.record("Should throw error for empty audio")
        } catch let error as RecognitionError {
            if case .invalidAudioData = error {
                print("✅ Correctly threw invalidAudioData error for empty audio")
            } else {
                Issue.record("Expected invalidAudioData error, got: \(error)")
            }
        }
    }
}
