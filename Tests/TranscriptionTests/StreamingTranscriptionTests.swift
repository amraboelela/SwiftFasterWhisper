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

        print("\n========== STREAMING TEST (English, 0.5s chunks) ==========")

        let audioPath = try base.findTestFile("jfk.wav")
        let fullAudio = try base.convertAudioToPCM(audioPath: audioPath)

        print("Audio file: \(audioPath)")
        print("Full audio duration: \(String(format: "%.2f", Double(fullAudio.count) / 16000.0))s")
        print("Total samples: \(fullAudio.count)")

        let recognizer = StreamingRecognizer(modelPath: modelPath)
        try recognizer.loadModel()
        try recognizer.startStreaming(language: "en")

        let chunkSize = 8000  // 0.5 seconds (16000 samples/sec)
        var allSegments: [String] = []
        var offset = 0

        print("\n--- Sending 0.5s audio chunks ---")

        while offset < fullAudio.count {
            let end = min(offset + chunkSize, fullAudio.count)
            let chunk = Array(fullAudio[offset..<end])

            print("[Chunk \(offset / chunkSize + 1)] Sending \(String(format: "%.2f", Float(chunk.count) / 16000.0))s")

            try recognizer.addAudioChunk(chunk)

            // Check for new segments (blocking call, returns empty array if not ready)
            let segments = try recognizer.getNewSegments()
            for segment in segments {
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                print("📤 Received segment: '\(text)'")
                allSegments.append(text)
            }

            offset = end
        }

        recognizer.stopStreaming()

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

        print("\n========== STREAMING TEST (Turkish, 0.5s chunks) ==========")

        let audioPath = try base.findTestFile("05-speech.wav")
        let fullAudio = try base.convertAudioToPCM(audioPath: audioPath)

        print("Audio file: \(audioPath)")
        print("Full audio duration: \(String(format: "%.2f", Double(fullAudio.count) / 16000.0))s")

        let recognizer = StreamingRecognizer(modelPath: modelPath)
        try recognizer.loadModel()
        try recognizer.startStreaming(language: "tr")

        let chunkSize = 8000  // 0.5 seconds (16000 samples/sec)
        var allSegments: [String] = []
        var offset = 0

        print("\n--- Sending 0.5s audio chunks ---")

        while offset < fullAudio.count {
            let end = min(offset + chunkSize, fullAudio.count)
            let chunk = Array(fullAudio[offset..<end])

            print("[Chunk \(offset / chunkSize + 1)] Sending \(String(format: "%.2f", Float(chunk.count) / 16000.0))s")

            try recognizer.addAudioChunk(chunk)

            // Check for new segments (blocking call, returns empty array if not ready)
            let segments = try recognizer.getNewSegments()
            for segment in segments {
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                print("📤 Received segment: '\(text)'")
                allSegments.append(text)
            }

            offset = end
        }

        recognizer.stopStreaming()

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
        try recognizer.loadModel()
        try recognizer.startStreaming(language: "en")

        // Poll immediately without adding audio - should return empty array
        let segments1 = try recognizer.getNewSegments()
        print("Poll before any audio: \(segments1.isEmpty ? "empty array ✅" : "\(segments1.count) segments (unexpected)")")
        #expect(segments1.isEmpty, "Should return empty array when no audio has been added")

        // Add very small chunk (too small for a full segment)
        let smallChunk = [Float](repeating: 0.0, count: 1600)  // 0.1 second
        try recognizer.addAudioChunk(smallChunk)

        let segments2 = try recognizer.getNewSegments()
        print("Poll after tiny chunk: \(segments2.isEmpty ? "empty array ✅" : "\(segments2.count) segments")")
        // May or may not be empty - just testing the API works

        recognizer.stopStreaming()
        print("=======================================================\n")
    }
}
