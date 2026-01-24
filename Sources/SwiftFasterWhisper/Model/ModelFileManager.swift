//
// ModelFileManager.swift
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/23/2026.
//

import Foundation
import CryptoKit

/// Manages model file downloads, storage, and validation
public struct ModelFileManager {

    /// Get the default models directory
    public static func defaultModelsDirectory() throws -> URL {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw RecognitionError.modelLoadFailed("Could not access Application Support directory")
        }
        let dir = appSupport.appendingPathComponent("SwiftFasterWhisper")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Check if a model exists and is valid
    public static func modelExists(name: String) -> Bool {
        guard let modelsDir = try? defaultModelsDirectory() else {
            return false
        }

        let modelDir = modelsDir.appendingPathComponent(name)
        let fm = FileManager.default

        // Check required files
        let requiredFiles = ["config.json", "model.bin"]
        for file in requiredFiles {
            let filePath = modelDir.appendingPathComponent(file)
            if !fm.fileExists(atPath: filePath.path) {
                return false
            }
        }

        // Check model.bin size (should be > 10 MB)
        let modelBin = modelDir.appendingPathComponent("model.bin")
        if let attributes = try? fm.attributesOfItem(atPath: modelBin.path),
           let fileSize = attributes[.size] as? Int64 {
            return fileSize > 10_000_000
        }

        return false
    }

    /// Ensure a Whisper model is available, downloading if necessary
    public static func ensureWhisperModel(
        size: WhisperModelSize = .medium,
        progressCallback: DownloadProgressCallback? = nil
    ) async throws -> URL {

        // Check environment variable override
        if let customPath = ProcessInfo.processInfo.environment["WHISPER_MODEL_PATH"] {
            print("Using WHISPER_MODEL_PATH: \(customPath)")
            return URL(fileURLWithPath: customPath)
        }

        let modelsDir = try defaultModelsDirectory()
        let modelDir = modelsDir.appendingPathComponent(size.directoryName)

        // Check if model already exists
        if modelExists(name: size.directoryName) {
            return modelDir
        }

        // For int8 quantized models, download float16 first and then quantize
        if size.needsQuantization {
            return try await downloadAndQuantizeModel(size: size, progressCallback: progressCallback)
        }

        print("📥 Downloading Whisper \(size.rawValue) model (\(size.approximateSize))...")
        print("   Saving to: \(modelDir.path)")
        print("This may take several minutes (only happens once)...")

        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

        let baseURL = "https://huggingface.co/\(size.huggingFaceRepo)/resolve/main"
        let requiredFiles = ["config.json", "model.bin", "vocabulary.txt"]

        for fileName in requiredFiles {
            try await downloadFile(
                from: "\(baseURL)/\(fileName)",
                to: modelDir.appendingPathComponent(fileName),
                progressCallback: progressCallback
            )
        }

        // Verify model integrity
        let modelBin = modelDir.appendingPathComponent("model.bin")
        let attributes = try FileManager.default.attributesOfItem(atPath: modelBin.path)
        let downloadedSize = attributes[.size] as? Int64 ?? 0

        guard downloadedSize > 50_000_000 else {
            throw RecognitionError.modelLoadFailed("Downloaded model file is too small: \(downloadedSize) bytes")
        }

        print("✅ Whisper \(size.rawValue) model ready at \(modelDir.path)")
        print("   Total size: \(downloadedSize / 1024 / 1024) MB")

        return modelDir
    }

    /// Download float16 model and quantize it to int8
    private static func downloadAndQuantizeModel(
        size: WhisperModelSize,
        progressCallback: DownloadProgressCallback? = nil
    ) async throws -> URL {

        let modelsDir = try defaultModelsDirectory()
        let finalModelDir = modelsDir.appendingPathComponent(size.directoryName)
        let tempModelDir = modelsDir.appendingPathComponent("whisper-large-v2-ct2-float16-temp")

        print("📥 Downloading Whisper large-v2 model (float16, ~3GB)...")
        print("This may take several minutes (only happens once)...")

        try FileManager.default.createDirectory(at: tempModelDir, withIntermediateDirectories: true)

        let baseURL = "https://huggingface.co/\(size.huggingFaceRepo)/resolve/main"
        let requiredFiles = ["config.json", "model.bin", "vocabulary.txt"]

        // Download float16 model
        for fileName in requiredFiles {
            try await downloadFile(
                from: "\(baseURL)/\(fileName)",
                to: tempModelDir.appendingPathComponent(fileName),
                progressCallback: progressCallback
            )
        }

        print("📦 Quantizing model to int8 (~3GB → ~1.5GB)...")
        print("This may take a few minutes...")

        // Find ct2-transformers-converter
        let converterPaths = [
            "/usr/local/bin/ct2-transformers-converter",
            "/opt/homebrew/bin/ct2-transformers-converter",
            FileManager.default.homeDirectoryForCurrentUser.path + "/develop/python/env/bin/ct2-transformers-converter",
            FileManager.default.homeDirectoryForCurrentUser.path + "/.local/bin/ct2-transformers-converter"
        ]

        var converterPath: String?
        for path in converterPaths {
            if FileManager.default.fileExists(atPath: path) {
                converterPath = path
                break
            }
        }

        guard let converter = converterPath else {
            // Clean up temp directory
            try? FileManager.default.removeItem(at: tempModelDir)

            throw RecognitionError.modelLoadFailed("""
                ct2-transformers-converter not found. Please install CTranslate2:

                pip install ctranslate2

                Or set WHISPER_MODEL_PATH to a pre-quantized model.
                """)
        }

        // Quantize using ct2-transformers-converter
        let process = Process()
        process.executableURL = URL(fileURLWithPath: converter)
        process.arguments = [
            "--model", tempModelDir.path,
            "--output_dir", finalModelDir.path,
            "--quantization", "int8",
            "--copy_files", "vocabulary.txt"
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if let output = String(data: outputData, encoding: .utf8), !output.isEmpty {
            print(output)
        }

        if process.terminationStatus != 0 {
            if let error = String(data: errorData, encoding: .utf8) {
                print("❌ Quantization error: \(error)")
            }

            // Clean up
            try? FileManager.default.removeItem(at: tempModelDir)
            try? FileManager.default.removeItem(at: finalModelDir)

            throw RecognitionError.modelLoadFailed("Failed to quantize model. Exit code: \(process.terminationStatus)")
        }

        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempModelDir)

        // Verify quantized model
        guard modelExists(name: size.directoryName) else {
            throw RecognitionError.modelLoadFailed("Quantization completed but model files not found")
        }

        let modelBin = finalModelDir.appendingPathComponent("model.bin")
        let attributes = try FileManager.default.attributesOfItem(atPath: modelBin.path)
        let finalSize = attributes[.size] as? Int64 ?? 0

        print("✅ Whisper large-v2 int8 model ready at \(finalModelDir.path)")
        print("   Final size: \(finalSize / 1024 / 1024) MB")

        return finalModelDir
    }

    /// Download a file with retry logic and progress tracking
    private static func downloadFile(
        from urlString: String,
        to destination: URL,
        maxRetries: Int = 3,
        progressCallback: DownloadProgressCallback?
    ) async throws {

        guard let url = URL(string: urlString) else {
            throw RecognitionError.modelLoadFailed("Invalid URL: \(urlString)")
        }

        let fileName = destination.lastPathComponent
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                print("  Downloading \(fileName)... (attempt \(attempt)/\(maxRetries))")

                // Create download task
                let (tempURL, response) = try await URLSession.shared.download(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw RecognitionError.modelLoadFailed(
                        "Failed to download \(fileName), HTTP status: \((response as? HTTPURLResponse)?.statusCode ?? -1)"
                    )
                }

                // Move downloaded file
                let fm = FileManager.default
                if fm.fileExists(atPath: destination.path) {
                    try fm.removeItem(at: destination)
                }
                try fm.moveItem(at: tempURL, to: destination)

                // Get file size
                let attributes = try fm.attributesOfItem(atPath: destination.path)
                let fileSize = attributes[.size] as? Int64 ?? 0

                print("  ✅ Downloaded \(fileName) (\(fileSize / 1024 / 1024) MB)")

                // Call progress callback
                progressCallback?(fileName, 1.0, fileSize, fileSize)

                return  // Success!

            } catch {
                lastError = error
                if attempt < maxRetries {
                    print("  ⚠️ Download failed, retrying...")
                    try await Task.sleep(for: .seconds(2))
                }
            }
        }

        throw lastError ?? RecognitionError.modelLoadFailed("Failed to download \(fileName) after \(maxRetries) attempts")
    }

    /// Clear all downloaded models
    public static func clearAllModels() throws {
        let modelsDir = try defaultModelsDirectory()
        let fm = FileManager.default

        if fm.fileExists(atPath: modelsDir.path) {
            try fm.removeItem(at: modelsDir)
            print("✅ Cleared all models from \(modelsDir.path)")
        }
    }

    /// Get disk space used by models
    public static func getModelsSize() throws -> Int64 {
        let modelsDir = try defaultModelsDirectory()
        let fm = FileManager.default

        guard fm.fileExists(atPath: modelsDir.path) else {
            return 0
        }

        var totalSize: Int64 = 0

        let enumerator = fm.enumerator(at: modelsDir, includingPropertiesForKeys: [.fileSizeKey])
        while let fileURL = enumerator?.nextObject() as? URL {
            if let attributes = try? fm.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }

        return totalSize
    }
}
