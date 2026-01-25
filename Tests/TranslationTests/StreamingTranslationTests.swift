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

        print("Audio file: \(audioPath)")
        print("Full audio duration: \(String(format: "%.2f", Double(fullAudio.count) / 16000.0))s")

        let recognizer = StreamingRecognizer(modelPath: modelPath)
        // Model loaded in configure()
        try await recognizer.configure(language: "tr", task: "translate")

        var allText = ""

        print("\n--- Sending 1s audio chunks ---")

        let producer = ChunksProducer(audio: fullAudio)
        try await producer.start(
            onChunk: { chunkNumber, chunk, isLast in
                print("[Chunk \(chunkNumber)] Sending \(String(format: "%.2f", Float(chunk.count) / 16000.0))s")

                await recognizer.addAudioChunk(chunk)

                // Check for new text (non-blocking)
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
                // Flush any remaining buffer
                await recognizer.flush()

                // Get any final text (including from flush)
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

        let expectedTurkish = "Kuraklık yüzünden yeterince ot bitmiyor. Biz de boyayı sulandırmak zorunda kaldık. Canlı başla uğraşıyoruz ama anca bu kadar oluyor."
        let expectedEnglish = "we've had enough of the drought. we had to water the plant. we're trying our best but that's all we can do."
        let comparison = base.compareWithReference(generated: fullText, expected: expectedEnglish)

        print("========== ACCURACY ANALYSIS ==========")
        print("Turkish: \(expectedTurkish)")
        print("Expected: \(expectedEnglish)")
        print("Generated: \(fullText)")
        print("\nMetrics:")
        print("  Accuracy: \(String(format: "%.2f", comparison.accuracy))%")
        print("=======================================\n")

        #expect(comparison.accuracy > 30.0,
            "Streaming translation accuracy should be greater than 30%. Got \(String(format: "%.2f", comparison.accuracy))%")
    }

    @Test func streamTranslateTurkish3_0100_4WithChunks() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== STREAMING TRANSLATION TEST (Turkish 3-0100-4 → English, 1s chunks) ==========")

        let audioPath = try base.findTestFile("turkish_segments/3-0100-4.wav")
        let fullAudio = try base.convertAudioToPCM(audioPath: audioPath)

        print("Audio file: \(audioPath)")
        print("Full audio duration: \(String(format: "%.2f", Double(fullAudio.count) / 16000.0))s")

        let recognizer = StreamingRecognizer(modelPath: modelPath)
        // Model loaded in configure()
        try await recognizer.configure(language: "tr", task: "translate")

        var allText = ""

        print("\n--- Sending 1s audio chunks ---")

        let producer = ChunksProducer(audio: fullAudio)
        try await producer.start(
            onChunk: { chunkNumber, chunk, isLast in
                print("[Chunk \(chunkNumber)] Sending \(String(format: "%.2f", Float(chunk.count) / 16000.0))s")

                await recognizer.addAudioChunk(chunk)

                // Check for new text (non-blocking)
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
                // Flush any remaining buffer
                await recognizer.flush()

                // Get any final text (including from flush)
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

        let expectedTurkish = "...bir akına bile çıkamadık. Neden? Çünkü Bey'imizin çıbanlı başı dertte.  Bütün oba halkı senin yaşlılığından şikayetçi."
        let expectedEnglish = "we couldn't even go to an action. why? because our bey's wife is in trouble. the whole tribe is complaining about your old age."

        print("========== ACCURACY ANALYSIS ==========")
        print("Turkish: \(expectedTurkish)")
        print("Expected: \(expectedEnglish)")
        print("Generated: \(fullText)")

        // Fail if no segments generated
        #expect(!fullText.isEmpty, "No segments generated - all were filtered as hallucinations")

        let comparison = base.compareWithReference(generated: fullText, expected: expectedEnglish)

        print("\nMetrics:")
        print("  Accuracy: \(String(format: "%.2f", comparison.accuracy))%")
        print("=======================================\n")

        #expect(comparison.accuracy > 30.0,
            "Streaming translation accuracy should be greater than 30%. Got \(String(format: "%.2f", comparison.accuracy))%")
    }

    @Test func streamTranslateTurkish12WithChunks() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()

        print("\n========== STREAMING TRANSLATION TEST (Turkish 12 → English, 1s chunks) ==========")

        let audioPath = try base.findTestFile("12-speech.wav")
        let fullAudio = try base.convertAudioToPCM(audioPath: audioPath)

        print("Audio file: \(audioPath)")
        print("Full audio duration: \(String(format: "%.2f", Double(fullAudio.count) / 16000.0))s")

        let recognizer = StreamingRecognizer(modelPath: modelPath)
        // Model loaded in configure()
        try await recognizer.configure(language: "tr", task: "translate")

        var allText = ""

        print("\n--- Sending 1s audio chunks ---")

        let producer = ChunksProducer(audio: fullAudio)
        try await producer.start(
            onChunk: { chunkNumber, chunk, isLast in
                print("[Chunk \(chunkNumber)] Sending \(String(format: "%.2f", Float(chunk.count) / 16000.0))s")

                await recognizer.addAudioChunk(chunk)

                // Check for new text (non-blocking)
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
                // Flush any remaining buffer
                await recognizer.flush()

                // Get any final text (including from flush)
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

        let expectedTurkish = "Başka bir çare bulmalıyız. Çok arıyorum."
        let expectedEnglish = "we have to find another way. i'm looking very hard."

        // Fail if no segments generated
        #expect(!fullText.isEmpty, "No segments generated - all were filtered as hallucinations")

        let comparison = base.compareWithReference(generated: fullText, expected: expectedEnglish)

        print("========== ACCURACY ANALYSIS ==========")
        print("Turkish: \(expectedTurkish)")
        print("Expected: \(expectedEnglish)")
        print("Generated: \(fullText)")
        print("\nMetrics:")
        print("  Accuracy: \(String(format: "%.2f", comparison.accuracy))%")
        print("=======================================\n")

        #expect(comparison.accuracy > 30.0,
            "Streaming translation accuracy should be greater than 30%. Got \(String(format: "%.2f", comparison.accuracy))%")
    }
}
