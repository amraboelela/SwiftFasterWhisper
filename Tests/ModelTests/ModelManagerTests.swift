//
// ModelManagerTests.swift
// SwiftFasterWhisper Tests
//
// Created by Amr Aboelela on 1/22/2026.
//

import Testing
import Foundation
@testable import SwiftFasterWhisper

@Suite(.serialized)
struct ModelManagerTests {

    @Test func defaultModelsDirectory() async throws {
        print("\n========== TEST: Default Models Directory ==========")

        let modelsDir = try ModelFileManager.defaultModelsDirectory()

        print("Models directory: \(modelsDir.path)")

        // Verify it's in Application Support
        #expect(modelsDir.path.contains("Application Support"), "Should be in Application Support")
        #expect(modelsDir.path.contains("SwiftFasterWhisper"), "Should contain SwiftFasterWhisper")

        // Verify directory exists
        let exists = FileManager.default.fileExists(atPath: modelsDir.path)
        #expect(exists, "Directory should be created")

        print("✅ Models directory is valid and exists")
        print("====================================================\n")
    }

    @Test func modelExists() async throws {
        print("\n========== TEST: Model Exists Check ==========")

        // Test with non-existent model
        let nonExistent = ModelFileManager.modelExists(name: "whisper-nonexistent-ct2")
        #expect(!nonExistent, "Non-existent model should return false")
        print("✅ Non-existent model returns false")

        // Test with actual medium model (should exist from other tests)
        let base = TestBase()
        _ = try await base.downloadModelIfNeeded()

        let mediumExists = ModelFileManager.modelExists(name: "whisper-medium-ct2")
        print("Medium model exists: \(mediumExists)")

        print("==============================================\n")
    }

    @Test func ensureWhisperModelWithCustomPath() async throws {
        print("\n========== TEST: Ensure Whisper Model with Custom Path ==========")

        // Set environment variable
        let base = TestBase()
        let testModelPath = try await base.downloadModelIfNeeded()

        setenv("WHISPER_MODEL_PATH", testModelPath, 1)
        defer { unsetenv("WHISPER_MODEL_PATH") }

        let modelURL = try await ModelFileManager.ensureWhisperModel()

        print("Model URL: \(modelURL.path)")
        #expect(modelURL.path == testModelPath, "Should use WHISPER_MODEL_PATH")

        print("✅ Environment variable override works")
        print("==================================================================\n")
    }

    @Test func ensureWhisperModelDownload() async throws {
        print("\n========== TEST: Ensure Whisper Model Download ==========")

        // This will either use existing or download
        let modelURL = try await ModelFileManager.ensureWhisperModel(size: WhisperModelSize.medium)

        print("Model URL: \(modelURL.path)")

        // Verify model files exist
        let requiredFiles = ["config.json", "model.bin", "vocabulary.txt"]
        for fileName in requiredFiles {
            let filePath = modelURL.appendingPathComponent(fileName)
            let exists = FileManager.default.fileExists(atPath: filePath.path)
            print("  \(exists ? "✅" : "❌") \(fileName)")
            #expect(exists, "\(fileName) should exist")
        }

        // Verify model.bin size
        let modelBin = modelURL.appendingPathComponent("model.bin")
        let attributes = try FileManager.default.attributesOfItem(atPath: modelBin.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let sizeMB = fileSize / 1024 / 1024

        print("Model size: \(sizeMB) MB")
        #expect(fileSize > 50_000_000, "Model should be larger than 50 MB")

        print("✅ Whisper model is valid")
        print("=========================================================\n")
    }

    @Test func getModelsSize() async throws {
        print("\n========== TEST: Get Models Size ==========")

        let totalSize = try ModelFileManager.getModelsSize()
        let sizeMB = totalSize / 1024 / 1024

        print("Total models size: \(sizeMB) MB")
        #expect(totalSize >= 0, "Size should be non-negative")

        if totalSize > 0 {
            print("✅ Models are using disk space: \(sizeMB) MB")
        } else {
            print("ℹ️ No models downloaded yet")
        }

        print("===========================================\n")
    }

    @Test func modelSizeEnum() {
        print("\n========== TEST: Model Size Enum ==========")

        let allSizes = WhisperModelSize.allCases

        #expect(allSizes.count == 6, "Should have 6 model sizes")

        for size in allSizes {
            print("Model: \(size.rawValue)")
            print("  HuggingFace repo: \(size.huggingFaceRepo)")
            print("  Directory name: \(size.directoryName)")
            print("  Approximate size: \(size.approximateSize)")
        }

        // Test specific values
        #expect(WhisperModelSize.medium.huggingFaceRepo == "Systran/faster-whisper-medium")
        #expect(WhisperModelSize.tiny.directoryName == "whisper-tiny-ct2")

        print("✅ All model sizes have correct metadata")
        print("===========================================\n")
    }

    @Test func downloadProgressCallback() async throws {
        print("\n========== TEST: Download Progress Callback ==========")

        var progressCallbacks: [(String, Double)] = []

        let callback: DownloadProgressCallback = { fileName, progress, downloaded, total in
            progressCallbacks.append((fileName, progress))
            print("Progress: \(fileName) - \(Int(progress * 100))%")
        }

        // This will reuse existing model, so may not trigger progress
        _ = try await ModelFileManager.ensureWhisperModel(
            size: WhisperModelSize.medium,
            progressCallback: callback
        )

        print("Progress callbacks received: \(progressCallbacks.count)")

        if progressCallbacks.isEmpty {
            print("ℹ️ Model already exists, no download needed")
        } else {
            print("✅ Progress callback was triggered")
        }

        print("======================================================\n")
    }
}
