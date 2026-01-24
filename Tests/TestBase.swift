//
// TestBase.swift
// SwiftFasterWhisper Tests
//
// Created by Amr Aboelela on 1/21/2026.
//

import Testing
import AVFoundation
@testable import SwiftFasterWhisper

// Actor to manage shared model instance safely in async contexts
actor TestModelManager {
    private var sharedWhisper: SwiftFasterWhisper?

    func getWhisper(modelPath: String) async throws -> SwiftFasterWhisper {
        if sharedWhisper == nil {
            print("Initializing SwiftFasterWhisper with medium model...")
            let instance = SwiftFasterWhisper(modelPath: modelPath)
            try await instance.loadModel()
            sharedWhisper = instance
        }
        return sharedWhisper!
    }
}

class TestBase {
    let timeout: TimeInterval = 300

    // Shared model manager across all tests
    private static let modelManager = TestModelManager()

    func getWhisper() async throws -> SwiftFasterWhisper {
        let modelPath = try await downloadModelIfNeeded()
        return try await TestBase.modelManager.getWhisper(modelPath: modelPath)
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
        // Use ModelFileManager to download to Application Support
        let modelURL = try await ModelFileManager.ensureWhisperModel(size: .medium)
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
