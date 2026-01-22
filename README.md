# SwiftFasterWhisper

A high-performance macOS/iOS Swift framework for real-time speech recognition and translation using the faster-whisper engine (based on CTranslate2).

## Overview

SwiftFasterWhisper provides a Swift-native API for fast, on-device transcription and translation. It wraps the faster-whisper speech recognition engine, offering performance improvements over whisper.cpp while maintaining a clean, Swift-idiomatic interface.

### Key Features

- **Real-time Streaming**: Process audio in 30ms chunks with low latency
- **Incremental Output**: Receive segments as they're transcribed
- **Multi-language Support**: Transcribe speech in any language
- **Translation**: Translate from any language to English
- **Swift Concurrency**: Modern async/await and delegate-based APIs
- **Cancelable Operations**: Stop transcription at any time
- **High Performance**: Leverages CTranslate2 for optimized inference

## Architecture

### Components

1. **Swift API Layer**: Provides Swift-friendly interfaces for transcription, streaming, and callbacks
2. **C++ Wrapper**: Bridge between Swift and the faster-whisper engine (`transcribe.cpp`)
3. **CTranslate2 Backend**: Optimized runtime for Whisper model inference

### Streaming Approach

SwiftFasterWhisper uses a sophisticated streaming strategy:
- Rolling audio buffer (1-3 seconds)
- Sliding window decoding (every ~1 second)
- Segment deduplication to prevent repeated output
- Time cursor tracking for stable segment emission

## Why SwiftFasterWhisper?

- **Performance**: Faster than whisper.cpp on CPU in many cases
- **Swift-Native**: Clean API designed for Swift developers
- **Real-time Ready**: Built for live transcription and subtitling applications
- **Platform Support**: Works on both macOS and iOS

## Use Cases

- Real-time subtitles and captions
- Live transcription applications
- Multi-language translation
- Voice-to-text interfaces
- Accessibility tools

## Requirements

- macOS 12.0+ / iOS 15.0+
- Swift 5.5+
- Xcode 13.0+

## Installation

### Swift Package Manager

Add SwiftFasterWhisper to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/amraboelela/SwiftFasterWhisper.git", from: "1.0.0")
]
```

Or add it via Xcode: **File > Add Packages...**

### Model Setup

SwiftFasterWhisper requires a CTranslate2-format Whisper model. You have two options:

#### Option 1: Automatic Download (Recommended for Apps)

Add a helper to download the model on first launch:

```swift
import SwiftFasterWhisper

func getModelPath() async throws -> String {
    let fileManager = FileManager.default
    let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let modelDir = appSupport.appendingPathComponent("whisper-models/medium-ct2")

    // Check if already downloaded
    if fileManager.fileExists(atPath: modelDir.path) {
        let configFile = modelDir.appendingPathComponent("config.json")
        if fileManager.fileExists(atPath: configFile.path) {
            return modelDir.path
        }
    }

    // Download pre-converted CTranslate2 model from Hugging Face
    try fileManager.createDirectory(at: modelDir, withIntermediateDirectories: true)

    let baseURL = "https://huggingface.co/Systran/faster-whisper-medium/resolve/main"
    let files = ["config.json", "model.bin", "vocabulary.json", "tokenizer.json"]

    for fileName in files {
        let remoteURL = URL(string: "\(baseURL)/\(fileName)")!
        let localFileURL = modelDir.appendingPathComponent(fileName)

        let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
        try fileManager.moveItem(at: tempURL, to: localFileURL)
    }

    return modelDir.path
}

// Usage in your app
let modelPath = try await getModelPath()
let whisper = SwiftFasterWhisper(modelPath: modelPath)
try whisper.loadModel()
```

#### Option 2: Manual Conversion

If you prefer to convert the model yourself:

```bash
# Install converter
pip install ctranslate2 transformers

# Convert Whisper medium model (downloads ~3GB, outputs ~1.5GB)
ct2-transformers-converter --model openai/whisper-medium \
    --output_dir ~/whisper-models/medium-ct2 \
    --quantization float16
```

Then in your app:

```swift
let whisper = SwiftFasterWhisper(modelPath: "~/whisper-models/medium-ct2")
try whisper.loadModel()
```

### Available Model Sizes

| Model | Size (float16) | Speed | Quality |
|-------|---------------|-------|---------|
| tiny | ~75 MB | Fastest | Basic |
| base | ~150 MB | Fast | Good |
| small | ~500 MB | Medium | Better |
| **medium** | ~1.5 GB | Slower | **Recommended** |
| large-v3 | ~3 GB | Slowest | Best |

**For most apps, use `medium`** - it offers the best balance of quality and performance.

To use a different model size, replace `faster-whisper-medium` with:
- `Systran/faster-whisper-tiny`
- `Systran/faster-whisper-base`
- `Systran/faster-whisper-small`
- `Systran/faster-whisper-large-v3`

## Usage

### Basic Transcription

```swift
import SwiftFasterWhisper

// Initialize
let modelPath = try await getModelPath()  // See Model Setup above
let whisper = SwiftFasterWhisper(modelPath: modelPath)
try whisper.loadModel()

// Transcribe from file
let result = try await whisper.transcribe(audioFilePath: "audio.wav")
print("Transcribed: \(result.text)")
print("Language: \(result.language)")
print("Duration: \(result.duration)s")

// Transcribe from audio samples (16kHz mono float32)
let audioSamples: [Float] = loadAudio()  // Your audio loading code
let result = try await whisper.transcribe(audio: audioSamples)

// Transcribe with specific language
let result = try await whisper.transcribe(
    audioFilePath: "spanish.wav",
    language: "es"
)
```

### Translation (Any Language → English)

```swift
// Translate Spanish to English
let result = try await whisper.translate(
    audioFilePath: "spanish.wav",
    sourceLanguage: "es"
)
print("English translation: \(result.text)")

// Auto-detect source language
let result = try await whisper.translate(audioFilePath: "unknown.wav")
```

### Real-time Streaming

#### Delegate Pattern

```swift
import SwiftFasterWhisper

class MyDelegate: StreamingRecognizerDelegate {
    func recognizer(_ recognizer: StreamingRecognizer, didReceiveSegments segments: [TranscriptionSegment]) {
        for segment in segments {
            print("[\(segment.start)s - \(segment.end)s] \(segment.text)")
        }
    }

    func recognizer(_ recognizer: StreamingRecognizer, didFinishWithError error: Error?) {
        if let error = error {
            print("Error: \(error)")
        } else {
            print("Streaming finished")
        }
    }
}

// Setup
let modelPath = try await getModelPath()
let recognizer = StreamingRecognizer(modelPath: modelPath)
try recognizer.loadModel()

recognizer.delegate = MyDelegate()
try recognizer.startStreaming(language: "en")

// Feed audio chunks (e.g., 30ms chunks = 480 samples at 16kHz)
while streaming {
    let chunk: [Float] = getNextAudioChunk()  // Your audio capture
    try recognizer.addAudioChunk(chunk)

    // Poll for new segments every ~500ms
    let newSegments = try recognizer.getNewSegments()
    // Delegate will be called automatically
}

recognizer.stopStreaming()
```

#### Async/Await Pattern

```swift
let recognizer = StreamingRecognizer(modelPath: modelPath)
try recognizer.loadModel()

// Start streaming in background
Task {
    for await chunk in audioStream {  // Your audio stream
        try recognizer.addAudioChunk(chunk)
    }
    recognizer.stopStreaming()
}

// Consume segments
for try await segments in recognizer.streamingSegments(language: "en") {
    for segment in segments {
        print("[\(segment.start)s - \(segment.end)s] \(segment.text)")
    }
}
```

### Working with Segments

```swift
let result = try await whisper.transcribe(audioFilePath: "audio.wav")

// Full text
print(result.text)

// Individual segments with timestamps
for segment in result.segments {
    print("[\(segment.start)s -> \(segment.end)s]")
    print("  \(segment.text)")
}

// Language detection
print("Detected language: \(result.language)")
print("Confidence: \(result.languageProbability)")
```

### Error Handling

```swift
do {
    let result = try await whisper.transcribe(audio: audioData)
} catch RecognitionError.modelNotLoaded {
    print("Model not loaded - call loadModel() first")
} catch RecognitionError.invalidAudioData {
    print("Audio data is empty or invalid")
} catch RecognitionError.recognitionFailed(let message) {
    print("Recognition failed: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Testing

The test suite automatically downloads the model on first run (takes a few minutes):

```bash
swift test
```

The model is cached in `Tests/Models/whisper-medium-ct2` and reused for subsequent test runs.

## Related Projects

This project is a more generic version of [IArabicSpeech](https://github.com/amraboelela/IArabicSpeech), extending support from Arabic-specific recognition to multi-language transcription and translation.

## License

MIT License - see [LICENSE](LICENSE) file for details

## Author

Created by Amr Aboelela

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
