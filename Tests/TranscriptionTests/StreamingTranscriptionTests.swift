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

        print("Full audio duration: \(String(format: "%.2f", Double(fullAudio.count) / 16000.0))s")
        print("Total samples: \(fullAudio.count)")

        let recognizer = StreamingRecognizer(modelPath: modelPath)
        try recognizer.loadModel()
        try recognizer.startStreaming(language: "en")

        let chunkSize = 16000  // 1 second at 16kHz
        var allSegments: [String] = []
        var offset = 0

        print("\n--- Sending 1s audio chunks ---")

        while offset < fullAudio.count {
            let end = min(offset + chunkSize, fullAudio.count)
            let chunk = Array(fullAudio[offset..<end])

            let energy = recognizer.calculateEnergy(chunk)
            print("\n[Chunk \(offset / chunkSize + 1)] Energy: \(String(format: "%.6f", energy)), Sending \(String(format: "%.2f", Float(chunk.count) / 16000.0))s of audio")

            let processed = try recognizer.addAudioChunk(chunk)

            if !processed {
                print("⏭️  Skipped (low energy)")
                offset = end
                continue
            }

            // Poll for new segment
            if let segment = try recognizer.getNewSegment() {
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                print("📤 Received segment: '\(text)'")
                print("   Timing: \(String(format: "%.2f", segment.start))s - \(String(format: "%.2f", segment.end))s")
                allSegments.append(text)
            } else {
                print("⏳ No segment ready yet (nil returned)")
            }

            offset = end
        }

        // Final poll after all audio
        print("\n--- Final poll after all audio sent ---")
        if let segment = try recognizer.getNewSegment() {
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            print("📤 Final segment: '\(text)'")
            allSegments.append(text)
        }

        recognizer.stopStreaming()

        let fullText = allSegments.joined(separator: " ").lowercased()
        print("\n========== STREAMING RESULTS ==========")
        print("Total segments received: \(allSegments.count)")
        print("Full transcription: \(fullText)")
        print("=======================================\n")

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

        print("Full audio duration: \(String(format: "%.2f", Double(fullAudio.count) / 16000.0))s")

        let recognizer = StreamingRecognizer(modelPath: modelPath)
        try recognizer.loadModel()
        try recognizer.startStreaming(language: "tr")

        let chunkSize = 16000  // 1 second
        var allSegments: [String] = []
        var offset = 0

        print("\n--- Sending 1s audio chunks ---")

        while offset < fullAudio.count {
            let end = min(offset + chunkSize, fullAudio.count)
            let chunk = Array(fullAudio[offset..<end])

            let energy = recognizer.calculateEnergy(chunk)
            print("\n[Chunk \(offset / chunkSize + 1)] Energy: \(String(format: "%.6f", energy)), Sending \(String(format: "%.2f", Float(chunk.count) / 16000.0))s")

            let processed = try recognizer.addAudioChunk(chunk)

            if !processed {
                print("⏭️  Skipped (low energy)")
                offset = end
                continue
            }

            // Poll for new segment (returns single segment or nil)
            if let segment = try recognizer.getNewSegment() {
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                print("📤 Received segment: '\(text)'")
                allSegments.append(text)
            } else {
                print("⏳ No segment ready yet")
            }

            offset = end
        }

        // Final poll
        if let segment = try recognizer.getNewSegment() {
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            print("📤 Final segment: '\(text)'")
            allSegments.append(text)
        }

        recognizer.stopStreaming()

        let fullText = allSegments.joined(separator: " ")
        print("\n========== STREAMING RESULTS ==========")
        print("Total segments: \(allSegments.count)")
        print("Full text: \(fullText)")
        print("=======================================\n")

        let expectedTurkish = "Kuraklık yüzünden yeterince ot bitmiyor. Biz de boyayı sulandırmak zorunda kaldık. Canlı başla uğraşıyoruz ama anca bu kadar oluyor."
        let comparison = base.compareWithReference(generated: fullText, expected: expectedTurkish)

        print("========== ACCURACY ANALYSIS ==========")
        print("Expected: \(expectedTurkish)")
        print("Generated: \(fullText)")
        print("\nMetrics:")
        print("  Accuracy: \(String(format: "%.2f", comparison.accuracy))%")
        print("=======================================\n")

        #expect(comparison.accuracy > 70.0,
            "Turkish streaming accuracy should be greater than 70%. Got \(String(format: "%.2f", comparison.accuracy))%")
    }

    @Test func streamReturnsNilWhenNoSegmentReady() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== TEST: getNewSegment() returns nil ==========")

        let recognizer = StreamingRecognizer(modelPath: modelPath)
        try recognizer.loadModel()
        try recognizer.startStreaming(language: "en")

        // Poll immediately without adding audio - should return nil
        let segment1 = try recognizer.getNewSegment()
        print("Poll before any audio: \(segment1 == nil ? "nil ✅" : "segment (unexpected)")")
        #expect(segment1 == nil, "Should return nil when no audio has been added")

        // Add very small chunk (too small for a full segment)
        let smallChunk = [Float](repeating: 0.0, count: 1600)  // 0.1 second
        try recognizer.addAudioChunk(smallChunk)

        let segment2 = try recognizer.getNewSegment()
        print("Poll after tiny chunk: \(segment2 == nil ? "nil ✅" : "segment")")
        // May or may not be nil - just testing the API works

        recognizer.stopStreaming()
        print("=======================================================\n")
    }
}
