# SwiftFasterWhisper

A high-performance macOS/iOS Swift framework for real-time speech recognition and translation using the faster-whisper engine (based on CTranslate2).

## Overview

SwiftFasterWhisper provides a Swift-native API for fast, on-device transcription and translation. It wraps the faster-whisper speech recognition engine, offering performance improvements over whisper.cpp while maintaining a clean, Swift-idiomatic interface.

### Key Features

- **Real-time Streaming**: Process audio in 1-second increments using an expanding window
- **Incremental Output**: Receive segments as they're transcribed
- **Multi-language Support**: Transcribe speech in any language
- **Translation**: Translate from any language to English (slower than transcription, accuracy varies by language)
- **Swift Concurrency**: Modern async/await and delegate-based APIs
- **Cancelable Operations**: Stop transcription at any time
- **High Performance**: Leverages CTranslate2 for optimized inference

## Architecture

### Components

1. **Swift API Layer**: Provides Swift-friendly interfaces for transcription, streaming, and callbacks
2. **C++ Wrapper**: Bridge between Swift and the faster-whisper engine (`transcribe.cpp`)
3. **CTranslate2 Backend**: Optimized runtime for Whisper model inference

### Streaming Approach

SwiftFasterWhisper uses an expanding window streaming strategy with automatic silence detection:
- Start with 1-second audio window
- Expand by 1 second each iteration
- Stop expanding when a stable segment is emitted or max window length is reached (default: 3 seconds)
- **Automatically skip low-energy chunks (silence)** using RMS energy detection
- Detect stable segments via repetition (segment appears identically twice in consecutive windows)
- Emit stable segments and advance window to prevent duplicates

**Energy Detection:**
- Each 1-second chunk is analyzed for energy level before processing
- Chunks below the energy threshold (default: 0.01 RMS) are skipped as silence
- Adjustable threshold via `recognizer.energyThreshold` property
- Saves processing power and improves accuracy by ignoring silence

**Window Management:**
- Max window length prevents infinite expansion during long silence periods
- Default max: 3 seconds (configurable in future versions)
- Window resets after emitting a stable segment

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

| Model | Approx Size (float16) | Speed | Quality |
|-------|----------------------|-------|---------|
| tiny | ~70-80 MB | Fastest | Basic |
| base | ~140-160 MB | Fast | Good |
| small | ~400-500 MB | Medium | Better |
| **medium** | ~1.5-2 GB | Slower | **Recommended** |
| large-v2 | ~3-4 GB | Slowest | Best |
| large-v3 | ~3-4 GB | Slowest | Best (requires 128 mel bands - not compatible) |

**For most apps, use `medium`** - it offers the best balance of quality and performance.
**For best quality, use `large-v2`** (used in tests).

**Note on large-v3:** This model requires 128 mel band input features. SwiftFasterWhisper currently uses 80-band mel spectrograms (Whisper v1-v2 standard), so large-v3 is not compatible without audio conversion.

To use a different model size, replace `faster-whisper-medium` with:
- `Systran/faster-whisper-tiny`
- `Systran/faster-whisper-base`
- `Systran/faster-whisper-small`
- `Systran/faster-whisper-large-v2`
- ~~`Systran/faster-whisper-large-v3`~~ (incompatible - requires 128 mel bands)

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

**Note:** Translation uses Whisper's built-in translation capability, which can be slower than transcription and may be less accurate depending on the source language. For best results, use `large-v2` model.

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
    func recognizer(_ recognizer: StreamingRecognizer, didReceiveSegment segment: TranscriptionSegment?) {
        if let segment = segment {
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

// Optional: Adjust energy threshold for silence detection
// Default is 0.01 - increase for noisier environments, decrease for quieter audio
recognizer.energyThreshold = 0.02

// Feed audio chunks (1 second chunks = 16000 samples at 16kHz)
// Low-energy chunks are automatically skipped
while streaming {
    let chunk: [Float] = getNextAudioChunk()  // Your audio capture (16000 samples)
    let processed = try recognizer.addAudioChunk(chunk)  // Returns true if processed, false if skipped

    // Poll for new segment every ~500ms
    if let newSegment = try recognizer.getNewSegment() {
        print("New segment: \(newSegment.text)")
    }
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
for try await segment in recognizer.streamingSegments(language: "en") {
    if let segment = segment {
        print("[\(segment.start)s - \(segment.end)s] \(segment.text)")
    }
}
```

**Important: `getNewSegment()` Behavior**

The `getNewSegment()` method:
- Returns **only new segments** that haven't been returned before
- Does **not** return duplicate segments (automatic deduplication)
- Returns `nil` if no new segment is ready yet
- Expanding window emits one stable segment at a time when repetition is detected

This means you can call it repeatedly without worrying about receiving the same segment twice.

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

### Energy Detection (Streaming)

For streaming audio, you can control silence detection:

```swift
let recognizer = StreamingRecognizer(modelPath: modelPath)
try recognizer.loadModel()

// Check energy of an audio chunk
let chunk: [Float] = getAudioChunk()
let energy = recognizer.calculateEnergy(chunk)  // Returns RMS energy
print("Chunk energy: \(energy)")

// Check if chunk has sufficient energy (not silence)
if recognizer.hasSufficientEnergy(chunk) {
    print("Chunk has speech")
} else {
    print("Chunk is silence")
}

// Customize energy threshold (default: 0.01)
recognizer.energyThreshold = 0.02  // Higher = more aggressive silence filtering

// addAudioChunk returns whether chunk was processed
let processed = try recognizer.addAudioChunk(chunk)
if processed {
    print("Chunk processed")
} else {
    print("Chunk skipped (low energy)")
}
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

The test suite includes:
- **File Transcription/Translation Tests**: Test batch processing of complete audio files
- **Streaming Tests**: Test real-time streaming with 1-second audio chunks
  - Sends audio in 1s increments (16000 samples at 16kHz)
  - Automatically skips low-energy chunks (silence detection)
  - Polls `getNewSegment()` which returns a single segment or `nil`
  - Validates the expanding window approach with segment repetition detection
- **Energy Detection Tests**: Test silence detection and energy calculation
  - Validates RMS energy calculation
  - Tests automatic skipping of low-energy chunks
  - Verifies custom energy threshold configuration

The tests automatically download the large-v2 model on first run (takes a few minutes):

```bash
swift test
```

The model is cached in `Tests/Models/whisper-large-v2-ct2` and reused for subsequent test runs.

### Running Tests Serially

To ensure all tests run serially and avoid any model loading conflicts:

```bash
swift test --no-parallel
```

Or limit to a single worker:

```bash
swift test --num-workers 1
```

This ensures that test suites run one after another, preventing model loading conflicts and making the output easier to follow.

**Note**: Each individual test suite already uses `@Suite(.serialized)` to run its tests serially within the suite.

## Related Projects

This project is a more generic version of [IArabicSpeech](https://github.com/amraboelela/IArabicSpeech), extending support from Arabic-specific recognition to multi-language transcription and translation.

## License

MIT License - see [LICENSE](LICENSE) file for details

## Author

Created by Amr Aboelela

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
