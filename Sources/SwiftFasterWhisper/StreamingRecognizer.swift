//
// StreamingRecognizer.swift
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/23/2026.
//

import Foundation

/// Delegate protocol for streaming recognizer callbacks
public protocol StreamingRecognizerDelegate: AnyObject, Sendable {
    /// Called when new transcription segments are available
    /// - Parameters:
    ///   - recognizer: The streaming recognizer instance
    ///   - segments: New transcription segments
    func recognizer(_ recognizer: StreamingRecognizer, didReceiveSegments segments: [TranscriptionSegment])

    /// Called when streaming finishes or encounters an error
    /// - Parameters:
    ///   - recognizer: The streaming recognizer instance
    ///   - error: Error if streaming failed, nil if stopped normally
    func recognizer(_ recognizer: StreamingRecognizer, didFinishWithError error: Error?)
}

/// Handles streaming audio processing with buffering and concurrent transcription
/// Uses ModelManager as the underlying model wrapper
public actor StreamingRecognizer {
    private let modelManager: ModelManager
    private var buffer: [Float] = []
    public private(set) var isProcessing = false
    private let windowSize: Int
    private var pendingSegments: [TranscriptionSegment] = []
    private var activeTask: Task<Void, Never>?

    /// Delegate for receiving streaming callbacks
    private weak var _delegate: (any StreamingRecognizerDelegate)?

    /// Set delegate (actor-isolated)
    public func setDelegate(_ delegate: (any StreamingRecognizerDelegate)?) {
        self._delegate = delegate
    }

    /// Initialize with model path and window parameters
    /// - Parameters:
    ///   - modelPath: Path to the Whisper model
    ///   - windowSize: Size of transcription window in samples (default: 67200 = 4.2s at 16kHz)
    public init(modelPath: String, windowSize: Int = 67200) {
        self.modelManager = ModelManager(modelPath: modelPath)
        self.windowSize = windowSize
    }

    /// Load the model
    public func loadModel() async throws {
        try await modelManager.loadModel()
    }

    /// Configure streaming parameters
    /// - Parameters:
    ///   - language: Language code (nil for auto-detection)
    ///   - task: "transcribe" or "translate"
    public func configure(language: String? = nil, task: String = "transcribe") async {
        await modelManager.configure(language: language, task: task)
    }

    /// Add audio chunk for processing
    /// Handles buffering and triggers transcription when window is ready
    /// - Parameter chunk: Audio samples (16kHz mono float32)
    public func addAudioChunk(_ chunk: [Float]) async throws {
        // Add to buffer
        buffer.append(contentsOf: chunk)

        // Try to submit if we have enough buffer
        if buffer.count >= windowSize {
            if isProcessing {
                // Model is busy - find and remove the chunk with lowest energy
                let chunkSize = 16000  // 1 second at 16kHz
                let numChunks = buffer.count / chunkSize

                if numChunks > 0 {
                    var lowestEnergyIndex = 0
                    var lowestEnergy = Float.infinity

                    // Find chunk with lowest energy
                    for i in 0..<numChunks {
                        let start = i * chunkSize
                        let end = min(start + chunkSize, buffer.count)
                        let segment = buffer[start..<end]
                        let energy = segment.reduce(0.0) { $0 + abs($1) } / Float(segment.count)

                        if energy < lowestEnergy {
                            lowestEnergy = energy
                            lowestEnergyIndex = i
                        }
                    }

                    // Remove the lowest energy chunk
                    let removeStart = lowestEnergyIndex * chunkSize
                    let removeEnd = min(removeStart + chunkSize, buffer.count)
                    buffer.removeSubrange(removeStart..<removeEnd)

                    print("⚠️  Model busy, dropped chunk #\(lowestEnergyIndex + 1) (energy: \(String(format: "%.6f", lowestEnergy)), buffer: \(String(format: "%.2f", Float(buffer.count) / 16000.0))s)")
                }
            } else {
                // Model is free, submit now
                isProcessing = true

                // Extract window
                let window = Array(buffer.prefix(windowSize))

                // Remove window from buffer
                let removeAmount = min(windowSize, buffer.count)
                buffer.removeFirst(removeAmount)

                // Start transcription in background (non-blocking)
                activeTask = Task {
                    await self.processWindow(window)
                }
            }
        }
    }

    /// Process audio window in background
    /// - Parameter window: Audio samples to transcribe
    private func processWindow(_ window: [Float]) async {
        do {
            // Transcribe
            let segments = try await modelManager.transcribe(audio: window)

            // Store segments for polling and notify delegate
            if !segments.isEmpty {
                // Store for polling
                pendingSegments.append(contentsOf: segments)

                // Notify delegate if set
                _delegate?.recognizer(self, didReceiveSegments: segments)
            }
        } catch {
            print("❌ Transcription error: \(error)")
            _delegate?.recognizer(self, didFinishWithError: error)
        }

        isProcessing = false
    }

    /// Get new transcription segments (non-blocking poll)
    /// Returns any segments that have been processed since last call
    /// - Returns: Array of new segments, empty if none available
    public func getNewSegments() -> [TranscriptionSegment] {
        let segments = pendingSegments
        pendingSegments.removeAll()
        return segments
    }

    /// Flush any remaining buffer and transcribe it
    /// Useful for processing leftover audio at the end of streaming
    public func flush() async {
        guard buffer.count > 0 && !isProcessing else {
            return
        }

        isProcessing = true

        // Extract whatever is in the buffer
        let window = buffer
        print("🔄 Flushing \(String(format: "%.2f", Float(window.count) / 16000.0))s of buffered audio")

        // Clear buffer
        buffer.removeAll()

        // Transcribe in background
        activeTask = Task {
            await self.processWindow(window)
        }
    }

    /// Stop streaming and cleanup
    public func stop() {
        buffer.removeAll()
        pendingSegments.removeAll()
        activeTask = nil
        _delegate?.recognizer(self, didFinishWithError: nil)
    }
}
