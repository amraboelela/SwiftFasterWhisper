//
// StreamingTranscriptionTests.swift
// SwiftFasterWhisper Tests
//
// Created by Amr Aboelela on 1/21/2026.
//

import Testing
import AVFoundation
@testable import SwiftFasterWhisper

@Suite(.serialized)
struct StreamingTranscriptionTests {

    @Test func streamEnglishAudioWithChunks() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== STREAMING TEST (English, 1s chunks) ==========")

        let audioPath = try base.findTestFile("jfk.wav")
        let fullAudio = try base.convertAudioToPCM(audioPath: audioPath)

        print("Audio file: \(audioPath)")
        print("Full audio duration: \(String(format: "%.2f", Double(fullAudio.count) / 16000.0))s")
        print("Total samples: \(fullAudio.count)")

        let recognizer = StreamingRecognizer(modelPath: modelPath)
        // Model loaded in configure()
        try await recognizer.configure(language: "en")

        var allText = ""

        print("\n--- Sending 1s audio chunks ---")

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

        let fullText = allText.lowercased()

        let expectedText = "and so my fellow americans ask not what your country can do for you ask what you can do for your country"
        let comparison = base.compareWithReference(generated: fullText, expected: expectedText)

        print("========== ACCURACY ANALYSIS ==========")
        print("Expected: \(expectedText)")
        print("Generated: \(fullText)")
        print("\nMetrics:")
        print("  Accuracy: \(String(format: "%.2f", comparison.accuracy))%")
        print("=======================================\n")

        #expect(comparison.accuracy > 80.0,
            "Streaming transcription accuracy should be greater than 80%. Got \(String(format: "%.2f", comparison.accuracy))%")

        #expect(!allText.isEmpty, "Should receive at least some text")
    }

    @Test func streamTurkishAudioWithChunks() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== STREAMING TEST (Turkish, 1s chunks) ==========")

        let audioPath = try base.findTestFile("05-speech.wav")
        let fullAudio = try base.convertAudioToPCM(audioPath: audioPath)

        print("Audio file: \(audioPath)")
        print("Full audio duration: \(String(format: "%.2f", Double(fullAudio.count) / 16000.0))s")

        let recognizer = StreamingRecognizer(modelPath: modelPath)
        // Model loaded in configure()
        try await recognizer.configure(language: "tr")

        var allText = ""

        print("\n--- Sending 1s audio chunks ---")

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

        let fullText = allText

        let expectedTurkish = "Kuraklık yüzünden yeterince ot bitmiyor. Biz de boyayı sulandırmak zorunda kaldık. Canlı başla uğraşıyoruz ama anca bu kadar oluyor."
        let comparison = base.compareWithReference(generated: fullText, expected: expectedTurkish)

        print("========== ACCURACY ANALYSIS ==========")
        print("Expected: \(expectedTurkish)")
        print("Generated: \(fullText)")
        print("\nMetrics:")
        print("  Accuracy: \(String(format: "%.2f", comparison.accuracy))%")
        print("=======================================\n")

        #expect(comparison.accuracy > 35.0,
            "Turkish streaming accuracy should be greater than 35%. Got \(String(format: "%.2f", comparison.accuracy))%")
    }

    @Test func streamReturnsEmptyWhenNoTextReady() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== TEST: getNewText() returns empty string ==========")

        let recognizer = StreamingRecognizer(modelPath: modelPath)
        // Model loaded in configure()
        try await recognizer.configure(language: "en")

        // Poll immediately without adding audio - should return empty string
        let text1 = await recognizer.getNewText()
        print("Poll before any audio: \(text1.isEmpty ? "empty string ✅" : "got text (unexpected)")")
        #expect(text1.isEmpty, "Should return empty string when no audio has been added")

        // Add very small chunk (too small for a full segment)
        let smallChunk = [Float](repeating: 0.0, count: 1600)  // 0.1 second
        await recognizer.addAudioChunk(smallChunk)

        let text2 = await recognizer.getNewText()
        print("Poll after tiny chunk: \(text2.isEmpty ? "empty string ✅" : "got text")")
        // May or may not be empty - just testing the API works

        await recognizer.stop()
        print("=======================================================\n")
    }
}
