//
// WhisperTranscriptionTests.swift
// SwiftFasterWhisper Tests
//
// Created by Amr Aboelela on 1/21/2026.
//

import Testing
import AVFoundation
@testable import SwiftFasterWhisper

@Suite(.serialized)
struct WhisperTranscriptionTests {

    @Test func transcribeFromAudioFrames() async throws {
        let base = TestBase()
        let whisper = try await base.getWhisper()

        print("\n========== TRANSCRIPTION TEST (Audio Frames) ==========")

        let audioPath = try base.findTestFile("jfk.wav")
        let audioFrames = try base.convertAudioToPCM(audioPath: audioPath)

        print("Loading audio file: \(audioPath)")
        print("Duration: \(String(format: "%.2f", Double(audioFrames.count) / 16000.0)) seconds")
        print("Loaded \(audioFrames.count) PCM samples")

        let result = try await whisper.transcribe(audio: audioFrames)

        #expect(result.segments.count > 0, "Should receive at least one segment")
        #expect(result.duration > 0, "Duration should be positive")
        #expect(!result.language.isEmpty, "Language should be detected")

        let fullText = result.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        print("\n========== TRANSCRIPTION RESULT ==========")
        print("Language: \(result.language) (confidence: \(result.languageProbability))")
        print("Duration: \(result.duration) seconds")
        print("Segments: \(result.segments.count)")
        print("Full text: \(fullText)")
        print("==========================================\n")

        let expectedText = "and so my fellow americans ask not what your country can do for you ask what you can do for your country"
        #expect(fullText == expectedText, "Transcription should match expected text")
    }

    @Test func transcribeFromFile() async throws {
        let base = TestBase()
        let whisper = try await base.getWhisper()

        print("\n========== TRANSCRIPTION TEST (File Path) ==========")

        let audioPath = try base.findTestFile("jfk.wav")
        let result = try await whisper.transcribe(audioFilePath: audioPath)

        #expect(result.segments.count > 0, "Should receive at least one segment")
        #expect(result.duration > 0, "Duration should be positive")

        print("✅ Transcribed \(result.segments.count) segments from file")
    }

    @Test func transcribeWithSpecificLanguage() async throws {
        let base = TestBase()
        let whisper = try await base.getWhisper()

        print("\n========== TRANSCRIPTION WITH LANGUAGE TEST ==========")

        let audioPath = try base.findTestFile("jfk.wav")
        let audioFrames = try base.convertAudioToPCM(audioPath: audioPath)

        let result = try await whisper.transcribe(audio: audioFrames, language: "en")

        #expect(result.segments.count > 0, "Should receive at least one segment")
        print("✅ English transcription: \(result.text)")
    }

    @Test func autoLanguageDetection() async throws {
        let base = TestBase()
        let whisper = try await base.getWhisper()

        print("\n========== AUTO LANGUAGE DETECTION TEST ==========")

        let audioPath = try base.findTestFile("jfk.wav")
        let audioFrames = try base.convertAudioToPCM(audioPath: audioPath)

        let result = try await whisper.transcribe(audio: audioFrames)

        #expect(!result.language.isEmpty, "Language should be auto-detected")
        #expect(result.languageProbability > 0, "Language confidence should be positive")

        print("✅ Auto-detected language: \(result.language) (confidence: \(result.languageProbability))")
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
