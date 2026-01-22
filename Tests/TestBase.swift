//
// TestBase.swift
// SwiftFasterWhisper Tests
//
// Created by Amr Aboelela on 1/21/2026.
//

import Testing
import AVFoundation
@testable import SwiftFasterWhisper

class TestBase {
    let timeout: TimeInterval = 300

    // Shared model instance across all tests (loaded once)
    private static var sharedWhisper: SwiftFasterWhisper?
    private static var modelLoadLock = NSLock()

    // Access the shared instance
    func getWhisper() async throws -> SwiftFasterWhisper {
        TestBase.modelLoadLock.lock()
        defer { TestBase.modelLoadLock.unlock() }

        if TestBase.sharedWhisper == nil {
            let modelPath = try await downloadModelIfNeeded()
            print("Initializing SwiftFasterWhisper with large-v2 model...")
            let instance = SwiftFasterWhisper(modelPath: modelPath)
            try instance.loadModel()
            TestBase.sharedWhisper = instance
        }

        return TestBase.sharedWhisper!
    }

    // MARK: - Audio Processing

    func convertAudioToPCM(audioPath: String) throws -> [Float] {
        let audioURL = URL(fileURLWithPath: audioPath)
        let audioFile = try AVAudioFile(forReading: audioURL)
        let format = audioFile.processingFormat

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "SwiftFasterWhisperTestBase", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create target format"])
        }

        guard let converter = AVAudioConverter(from: format, to: targetFormat) else {
            throw NSError(domain: "SwiftFasterWhisperTestBase", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
        }

        let sourceFrameCount = AVAudioFrameCount(audioFile.length)
        let targetFrameCount = AVAudioFrameCount(Double(sourceFrameCount) * targetFormat.sampleRate / format.sampleRate)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: targetFrameCount) else {
            throw NSError(domain: "SwiftFasterWhisperTestBase", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create output buffer"])
        }

        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audioFile.length)) else {
            throw NSError(domain: "SwiftFasterWhisperTestBase", code: -4,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create input buffer"])
        }

        try audioFile.read(into: inputBuffer)
        inputBuffer.frameLength = AVAudioFrameCount(audioFile.length)

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            throw error
        }

        guard let floatChannelData = outputBuffer.floatChannelData else {
            throw NSError(domain: "SwiftFasterWhisperTestBase", code: -5,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to get float channel data"])
        }

        let frameCount = Int(outputBuffer.frameLength)
        let frames = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameCount))

        return frames
    }

    // MARK: - Text Processing Helpers

    func turkishLower(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "İ", with: "i")
            .replacingOccurrences(of: "I", with: "ı")
            .lowercased()
    }

    func cleanPunctuation(_ text: String) -> String {
        let punctuation = CharacterSet.punctuationCharacters
        return text.components(separatedBy: punctuation).joined(separator: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func tokenizeText(_ text: String) -> [Character] {
        return Array(text)
    }

    func editDistance<T: Equatable>(_ seq1: [T], _ seq2: [T]) -> Int {
        let len1 = seq1.count
        let len2 = seq2.count

        var dp = Array(repeating: Array(repeating: 0, count: len2 + 1), count: len1 + 1)

        for i in 0...len1 {
            dp[i][0] = i
        }
        for j in 0...len2 {
            dp[0][j] = j
        }

        for i in 1...len1 {
            for j in 1...len2 {
                if seq1[i-1] == seq2[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = 1 + min(
                        dp[i-1][j],
                        dp[i][j-1],
                        dp[i-1][j-1]
                    )
                }
            }
        }

        return dp[len1][len2]
    }

    func compareWithReference(generated: String, expected: String) -> (accuracy: Double, correct: Int, total: Int, editDistance: Int) {
        let expectedClean = turkishLower(cleanPunctuation(expected))
        let generatedClean = turkishLower(cleanPunctuation(generated))

        let expectedTokens = tokenizeText(expectedClean)
        let generatedTokens = tokenizeText(generatedClean)

        let editDist = editDistance(expectedTokens, generatedTokens)
        let maxLen = max(expectedTokens.count, generatedTokens.count)
        let correct = maxLen - editDist

        let accuracy = maxLen > 0 ? (Double(correct) / Double(maxLen) * 100.0) : 0.0

        return (accuracy, correct, maxLen, editDist)
    }

    // MARK: - Model Management

    func downloadModelIfNeeded() async throws -> String {
        let fileManager = FileManager.default

        let projectRoot = projectRootURL()
        let modelsDir = projectRoot.appendingPathComponent("Tests").appendingPathComponent("Models")
        let modelURL = modelsDir.appendingPathComponent("whisper-large-v2-ct2")

        try fileManager.createDirectory(
            at: modelsDir,
            withIntermediateDirectories: true
        )

        // Required model files
        let requiredFiles = ["config.json", "model.bin", "vocabulary.json", "tokenizer.json"]
        var missingFiles: [String] = []

        // Check which files are missing
        try fileManager.createDirectory(at: modelURL, withIntermediateDirectories: true)

        for fileName in requiredFiles {
            let filePath = modelURL.appendingPathComponent(fileName)
            if !fileManager.fileExists(atPath: filePath.path) {
                missingFiles.append(fileName)
            }
        }

        // If model.bin exists and is valid, we're good
        let modelBin = modelURL.appendingPathComponent("model.bin")
        if fileManager.fileExists(atPath: modelBin.path) {
            let attributes = try fileManager.attributesOfItem(atPath: modelBin.path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            // CTranslate2 large-v2 float16 model should be ~3GB
            if fileSize > 2_000_000_000 && missingFiles.isEmpty {
                print("✅ Using existing CTranslate2 model at \(modelURL.path)")
                return modelURL.path
            } else if fileSize > 2_000_000_000 && !missingFiles.isEmpty {
                print("⚠️ Model exists but missing files: \(missingFiles.joined(separator: ", "))")
                print("Downloading missing files...")
            } else if fileSize > 0 {
                print("⚠️ Model file seems too small (\(fileSize / 1024 / 1024) MB), re-downloading all files...")
                missingFiles = requiredFiles
            }
        } else {
            print("📥 Downloading Whisper large-v2 model (CTranslate2 format, ~3GB)...")
            print("This may take several minutes...")
            missingFiles = requiredFiles
        }

        // Download missing files from Hugging Face
        // Using Systran's official faster-whisper models
        let baseURL = "https://huggingface.co/Systran/faster-whisper-large-v2/resolve/main"

        for fileName in missingFiles {
            let remoteURL = URL(string: "\(baseURL)/\(fileName)")!
            let localFileURL = modelURL.appendingPathComponent(fileName)

            print("  Downloading \(fileName)...")

            let (tempURL, response) = try await URLSession.shared.download(from: remoteURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NSError(
                    domain: "TestBase",
                    code: -10,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to download \(fileName), HTTP status: \((response as? HTTPURLResponse)?.statusCode ?? -1)"]
                )
            }

            // Move downloaded file to final location
            if fileManager.fileExists(atPath: localFileURL.path) {
                try fileManager.removeItem(at: localFileURL)
            }
            try fileManager.moveItem(at: tempURL, to: localFileURL)

            let attributes = try fileManager.attributesOfItem(atPath: localFileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("  ✅ Downloaded \(fileName) (\(fileSize / 1024 / 1024) MB)")
        }

        // Verify model.bin size if it was downloaded
        if missingFiles.contains("model.bin") {
            let attributes = try fileManager.attributesOfItem(atPath: modelBin.path)
            let downloadedSize = attributes[.size] as? Int64 ?? 0

            guard downloadedSize > 500_000_000 else {
                throw NSError(
                    domain: "TestBase",
                    code: -11,
                    userInfo: [NSLocalizedDescriptionKey: "Downloaded model file is too small: \(downloadedSize) bytes"]
                )
            }

            print("✅ Model downloaded successfully to \(modelURL.path)")
            print("   Total size: \(downloadedSize / 1024 / 1024) MB")
        } else {
            print("✅ Model ready at \(modelURL.path)")
        }

        return modelURL.path
    }

    func projectRootURL() -> URL {
        let testFileURL = URL(fileURLWithPath: #filePath)
        var dir = testFileURL.deletingLastPathComponent()
        let fm = FileManager.default

        for _ in 0..<6 {
            let candidate = dir.appendingPathComponent("Package.swift")
            if fm.fileExists(atPath: candidate.path) {
                return dir
            }
            dir.deleteLastPathComponent()
        }

        fatalError("❌ Could not locate Package.swift")
    }

    func findTestFile(_ filename: String) throws -> String {
        let projectRoot = projectRootURL()
        let filePath = projectRoot.appendingPathComponent("Tests").appendingPathComponent(filename)

        struct SkipError: Error {
            let message: String
        }

        guard FileManager.default.fileExists(atPath: filePath.path) else {
            throw SkipError(message: "Could not find \(filename) in Tests directory")
        }

        return filePath.path
    }
}
