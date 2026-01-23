//
// LoadModelTests.swift
// SwiftFasterWhisper Tests
//
// Created by Amr Aboelela on 1/21/2026.
//

import Foundation
import Testing
@testable import SwiftFasterWhisper

@Suite(.serialized)
struct LoadModelTests {

    @Test func loadModel() async throws {
        let base = TestBase()
        let modelPath = try await base.downloadModelIfNeeded()
        let recognizer = SwiftFasterWhisper(modelPath: modelPath)

        #expect(!recognizer.isModelLoaded, "Model should not be loaded initially")

        try await recognizer.loadModel()
        #expect(recognizer.isModelLoaded, "Model should be loaded after loadModel()")
        print("✅ Model loaded successfully from \(modelPath)")
    }

    @Test func invalidModelPath() async throws {
        let invalidRecognizer = SwiftFasterWhisper(modelPath: "/nonexistent/path")

        do {
            try await invalidRecognizer.loadModel()
            Issue.record("Should have thrown RecognitionError")
        } catch is RecognitionError {
            // Expected error
            print("✅ Correctly threw RecognitionError for invalid model path")
        } catch {
            Issue.record("Should throw RecognitionError, got: \(error)")
        }
    }
}
