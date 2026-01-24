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
        try await recognizer.loadModel()
        await recognizer.configure(language: "en")

        var allSegments: [String] = []

        print("\n--- Sending 1s audio chunks ---")

        let producer = ChunksProducer(audio: fullAudio)
        try await producer.start(
            onChunk: { chunkNumber, chunk, isLast in
                print("[Chunk \(chunkNumber)] Sending \(String(format: "%.2f", Float(chunk.count) / 16000.0))s")

                try await recognizer.addAudioChunk(chunk)

                // Check for new segments (non-blocking poll)
                let segments = await recognizer.getNewSegments()
                for segment in segments {
                    let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("📤 Received segment: '\(text)'")
                    allSegments.append(text)
                }
            },
            onComplete: {
                await recognizer.stop()
            }
        )

        let fullText = allSegments.joined(separator: " ").lowercased()

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

        #expect(allSegments.count > 0, "Should receive at least one segment")
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
        try await recognizer.loadModel()
        await recognizer.configure(language: "tr")

        var allSegments: [String] = []

        print("\n--- Sending 1s audio chunks ---")

        let producer = ChunksProducer(audio: fullAudio)
        try await producer.start(
            onChunk: { chunkNumber, chunk, isLast in
                print("[Chunk \(chunkNumber)] Sending \(String(format: "%.2f", Float(chunk.count) / 16000.0))s")

                try await recognizer.addAudioChunk(chunk)

                // Check for new segments (non-blocking poll)
                let segments = await recognizer.getNewSegments()
                for segment in segments {
                    let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("📤 Received segment: '\(text)'")
                    allSegments.append(text)
                }
            },
            onComplete: {
                await recognizer.stop()
            }
        )

        let fullText = allSegments.joined(separator: " ")

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

    @Test func streamReturnsEmptyWhenNoSegmentReady() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== TEST: getNewSegments() returns empty array ==========")

        let recognizer = StreamingRecognizer(modelPath: modelPath)
        try await recognizer.loadModel()
        await recognizer.configure(language: "en")

        // Poll immediately without adding audio - should return empty array
        let segments1 = await recognizer.getNewSegments()
        print("Poll before any audio: \(segments1.isEmpty ? "empty array ✅" : "\(segments1.count) segments (unexpected)")")
        #expect(segments1.isEmpty, "Should return empty array when no audio has been added")

        // Add very small chunk (too small for a full segment)
        let smallChunk = [Float](repeating: 0.0, count: 1600)  // 0.1 second
        try await recognizer.addAudioChunk(smallChunk)

        let segments2 = await recognizer.getNewSegments()
        print("Poll after tiny chunk: \(segments2.isEmpty ? "empty array ✅" : "\(segments2.count) segments")")
        // May or may not be empty - just testing the API works

        await recognizer.stop()
        print("=======================================================\n")
    }
}
