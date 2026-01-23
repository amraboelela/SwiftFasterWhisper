//
// StreamingTranslationTests.swift
// SwiftFasterWhisper Tests
//
// Created by Amr Aboelela on 1/21/2026.
//

import Testing
import AVFoundation
@testable import SwiftFasterWhisper

@Suite(.serialized)
struct StreamingTranslationTests {

    @Test func streamTranslateTurkishWithChunks() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== STREAMING TRANSLATION TEST (Turkish → English, 1s chunks) ==========")

        let audioPath = try base.findTestFile("05-speech.wav")
        let fullAudio = try base.convertAudioToPCM(audioPath: audioPath)

        print("Full audio duration: \(String(format: "%.2f", Double(fullAudio.count) / 16000.0))s")

        let recognizer = StreamingRecognizer(modelPath: modelPath)
        try recognizer.loadModel()
        try recognizer.startStreaming(language: "tr")  // Note: Translation in streaming not yet implemented

        let chunkSize = 16000  // 1 second
        var allSegments: [String] = []
        var offset = 0

        print("\n--- Sending 1s audio chunks ---")

        while offset < fullAudio.count {
            let end = min(offset + chunkSize, fullAudio.count)
            let chunk = Array(fullAudio[offset..<end])

            print("\n[Chunk \(offset / chunkSize + 1)] Sending \(String(format: "%.2f", Float(chunk.count) / 16000.0))s")

            try recognizer.addAudioChunk(chunk)

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
        print("Full translation: \(fullText)")
        print("===================================================\n")

        // Note: For now this tests transcription (not translation) in streaming mode
        // Translation support in streaming will be added later
        let expectedTurkish = "Kuraklık yüzünden yeterince ot bitmiyor. Biz de boyayı sulandırmak zorunda kaldık. Canlı başla uğraşıyoruz ama anca bu kadar oluyor."
        let comparison = base.compareWithReference(generated: fullText, expected: expectedTurkish)

        print("========== ACCURACY ANALYSIS ==========")
        print("Expected: \(expectedTurkish)")
        print("Generated: \(fullText)")
        print("\nMetrics:")
        print("  Accuracy: \(String(format: "%.2f", comparison.accuracy))%")
        print("=======================================\n")

        #expect(comparison.accuracy > 30.0,
            "Streaming accuracy should be greater than 30%. Got \(String(format: "%.2f", comparison.accuracy))%")
    }

    @Test func streamTranslateTurkish06WithChunks() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== STREAMING TRANSLATION TEST (Turkish 06 → English, 1s chunks) ==========")

        let audioPath = try base.findTestFile("06-speech.wav")
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

            print("\n[Chunk \(offset / chunkSize + 1)] Sending \(String(format: "%.2f", Float(chunk.count) / 16000.0))s")

            try recognizer.addAudioChunk(chunk)

            if let segment = try recognizer.getNewSegment() {
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                print("📤 Received segment: '\(text)'")
                allSegments.append(text)
            } else {
                print("⏳ No segment ready yet")
            }

            offset = end
        }

        if let segment = try recognizer.getNewSegment() {
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            print("📤 Final segment: '\(text)'")
            allSegments.append(text)
        }

        recognizer.stopStreaming()

        let fullText = allSegments.joined(separator: " ")
        print("\n========== STREAMING RESULTS ==========")
        print("Total segments: \(allSegments.count)")
        print("Full translation: \(fullText)")
        print("===================================================\n")

        let expectedTurkish = "Çivi totunu yapraklarıyla köklerini denediniz mi?"
        let comparison = base.compareWithReference(generated: fullText, expected: expectedTurkish)

        print("========== ACCURACY ANALYSIS ==========")
        print("Expected: \(expectedTurkish)")
        print("Generated: \(fullText)")
        print("\nMetrics:")
        print("  Accuracy: \(String(format: "%.2f", comparison.accuracy))%")
        print("=======================================\n")

        #expect(comparison.accuracy > 10.0,
            "Streaming accuracy should be greater than 10%. Got \(String(format: "%.2f", comparison.accuracy))%")
    }

    @Test func streamTranslateTurkish12WithChunks() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== STREAMING TRANSLATION TEST (Turkish 12 → English, 1s chunks) ==========")

        let audioPath = try base.findTestFile("12-speech.wav")
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

            print("\n[Chunk \(offset / chunkSize + 1)] Sending \(String(format: "%.2f", Float(chunk.count) / 16000.0))s")

            try recognizer.addAudioChunk(chunk)

            if let segment = try recognizer.getNewSegment() {
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                print("📤 Received segment: '\(text)'")
                allSegments.append(text)
            } else {
                print("⏳ No segment ready yet")
            }

            offset = end
        }

        if let segment = try recognizer.getNewSegment() {
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            print("📤 Final segment: '\(text)'")
            allSegments.append(text)
        }

        recognizer.stopStreaming()

        let fullText = allSegments.joined(separator: " ")
        print("\n========== STREAMING RESULTS ==========")
        print("Total segments: \(allSegments.count)")
        print("Full translation: \(fullText)")
        print("===================================================\n")

        let expectedTurkish = "Başka bir çare bulmalıyız. Çok arıyorum."
        let comparison = base.compareWithReference(generated: fullText, expected: expectedTurkish)

        print("========== ACCURACY ANALYSIS ==========")
        print("Expected: \(expectedTurkish)")
        print("Generated: \(fullText)")
        print("\nMetrics:")
        print("  Accuracy: \(String(format: "%.2f", comparison.accuracy))%")
        print("=======================================\n")

        #expect(comparison.accuracy > 10.0,
            "Streaming accuracy should be greater than 10%. Got \(String(format: "%.2f", comparison.accuracy))%")
    }
}
