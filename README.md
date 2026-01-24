# SwiftFasterWhisper

A high-performance macOS/iOS Swift framework for real-time speech recognition and translation using the faster-whisper engine (based on CTranslate2).

**Built for developers who want Whisper accuracy without whisper.cpp constraints, using a fully Swift-native API.**

## Quick Start

```swift
import SwiftFasterWhisper

// Initialize and load model (auto-downloads on first use)
let whisper = SwiftFasterWhisper()
try await whisper.loadModel()

// Transcribe audio file
let result = try await whisper.transcribe(audioFilePath: "audio.wav")
print(result.text)

// Or stream real-time audio
let recognizer = StreamingRecognizer(modelPath: modelPath)
try recognizer.loadModel()
try recognizer.startStreaming(language: "en")

// Feed 0.5s chunks, get segments automatically
try recognizer.addAudioChunk(audioChunk)  // Triggers transcription when buffer ready
if let segment = try await recognizer.getNewSegment() {
    print(segment.text)
}
```

## Overview

SwiftFasterWhisper provides a Swift-native API for fast, on-device transcription and translation. It wraps the faster-whisper speech recognition engine, offering performance improvements over whisper.cpp while maintaining a clean, Swift-idiomatic interface.

### Key Features

- **Real-time Streaming**: Process audio using 4-second sliding window with 0.5-second chunks
- **Near Real-Time Performance**: CPU-bound; typically ~1.4–1.7× audio duration (e.g., 15s audio processes in ~20-25s)
- **Event-Driven Architecture**: No polling - transcription triggered automatically when buffer ready
- **Non-blocking API**: Background transcription with async/await support
- **Incremental Output**: Receive segments as they're transcribed from thread-safe queue
- **Multi-language Support**: Transcribe speech in any language
- **Translation**: Translate from any language to English (quality varies by language)
- **Swift Concurrency**: Modern async/await and delegate-based APIs with actor-based thread safety
- **Cancelable Operations**: Stop transcription at any time
- **High Performance**: Leverages CTranslate2 for optimized inference with parallel processing

## Architecture

### Components

1. **Swift API Layer**: Provides Swift-friendly interfaces for transcription, streaming, and callbacks
2. **C++ Wrapper**: Bridge between Swift and the faster-whisper engine (`transcribe.cpp`)
3. **CTranslate2 Backend**: Optimized runtime for Whisper model inference

### Streaming Approach

**TL;DR:**
- Feed 0.5s audio chunks via `addAudioChunk()`
- Internally buffers 4s of audio
- Automatically transcribes when ready (event-driven, no polling)
- Receive segments via delegate callback or `await getNewSegment()`

---

SwiftFasterWhisper uses an event-driven streaming strategy for real-time transcription:

**Design:**
- **4-second audio window** for transcription
- **0.5-second chunks** (8000 samples at 16kHz) recommended for feeding audio
- **3.5-second shift** between transcriptions (overlapping 0.5s for continuity)
- **Event-driven transcription**: Triggered inside `addAudioChunk()` when C++ backend signals buffer is ready
- Segments are queued in a thread-safe actor and retrieved asynchronously

**How It Works:**
1. User calls `addAudioChunk()` with 0.5s chunks (non-blocking, returns immediately)
2. C++ accumulates audio in a 4-second sliding window
3. When window is ready (4s of audio accumulated), `addAudioChunk()` detects this via `whisper_should_transcribe()`
4. Swift spawns a background task to call C++ transcription (blocking call runs in background)
5. When transcription completes, segments are:
   - Added to thread-safe queue (accessible via `await getNewSegment()`)
   - Delivered to delegate callback (if set)
6. Window shifts by 3.5 seconds after transcription to maintain continuity

**Event-Driven (No Polling):**
- Transcription is triggered inside `addAudioChunk()` when the C++ backend signals the buffer is ready
- When true, spawns background task for transcription
- No wasteful polling loops - transcription happens exactly when needed
- Delegate callbacks provide real-time segment delivery

**Performance:**
- Non-blocking API allows UI updates while transcribing
- Background tasks enable parallel audio feeding and transcription
- Thread-safe segment queue using Swift actors
- Typical response time: ~1.4–1.7× real-time (15s audio: ~20-25s processing)

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

SwiftFasterWhisper automatically downloads models on first use. Models are stored in `~/Library/Application Support/SwiftFasterWhisper/`.

#### Option 1: Automatic Download (Recommended)

No setup needed! Just initialize and load:

```swift
import SwiftFasterWhisper

// Initialize with default medium model
let whisper = SwiftFasterWhisper()
try await whisper.loadModel()  // Automatically downloads on first use

// Or choose a different model size
let whisper = SwiftFasterWhisper(modelSize: .small)
try await whisper.loadModel()

// Optional: Track download progress
whisper.downloadProgressCallback = { fileName, progress, downloaded, total in
    print("Downloading \(fileName): \(Int(progress * 100))%")
}
```

**Environment Variables:**
- `WHISPER_MODEL_PATH`: Override auto-download with custom Whisper model path

#### Option 2: Custom Model Path

If you've already converted a model or want to use a specific location:

```swift
let whisper = SwiftFasterWhisper(modelPath: "/path/to/your/whisper-model")
try await whisper.loadModel()
```

#### Option 3: Manual Conversion

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

Model names follow the `Systran/faster-whisper-*` convention on Hugging Face.

| Model | Approx Size (float16) | Speed | Quality |
|-------|----------------------|-------|---------|
| tiny | ~75 MB | Fastest | Basic |
| base | ~140 MB | Fast | Good |
| small | ~460 MB | Medium | Better |
| **medium** | **~1.5 GB** | Slower | **Recommended** |
| large-v2 | ~3.0 GB | Slowest | Best |

**For most apps, use `medium`** - it offers the best balance of quality and performance.
**For best quality, use `large-v2`** (used in tests).

⚠️ **large-v3 is NOT supported**
It requires 128 mel bands, while SwiftFasterWhisper uses 80-band mel spectrograms (Whisper v1-v2 standard).

To use a different model size, replace `faster-whisper-medium` with:
- `Systran/faster-whisper-tiny`
- `Systran/faster-whisper-base`
- `Systran/faster-whisper-small`
- `Systran/faster-whisper-large-v2`

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

**Note:** Translation uses Whisper's built-in translation capability, which can be slower than transcription and may be less accurate depending on the source language. For best results, use `large-v2` or `medium` model.

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

// Keep strong reference to delegate to prevent deallocation
let delegate = MyDelegate()
recognizer.delegate = delegate
try recognizer.startStreaming(language: "en")

// Feed audio chunks (0.5 second chunks = 8000 samples at 16kHz recommended)
// Chunks are accumulated in a 4-second sliding window
while streaming {
    let chunk: [Float] = getNextAudioChunk()  // Your audio capture (8000 samples = 0.5s)
    try recognizer.addAudioChunk(chunk)

    // Poll for new segment (non-blocking, retrieves from background queue)
    if let newSegment = try await recognizer.getNewSegment() {
        print("New segment: \(newSegment.text)")
    }
}

await recognizer.stopStreaming()
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
    await recognizer.stopStreaming()
}

// Consume segments (non-blocking)
for try await segment in recognizer.streamingSegments(language: "en") {
    if let segment = segment {
        print("[\(segment.start)s - \(segment.end)s] \(segment.text)")
    }
}
```

**Important: `getNewSegment()` Behavior**

The `getNewSegment()` method:
- Returns **only new segments** from the background queue
- Is **non-blocking** - returns immediately with segment or `nil`
- Does **not** return duplicate segments (automatic deduplication)
- Background task handles the blocking transcription calls
- Thread-safe segment queue using Swift actors

This means you can call it repeatedly in your main loop without blocking the UI.

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

### Optional: Manual Energy Detection

While streaming automatically processes all chunks in the background, you can still manually check audio energy for custom filtering:

```swift
let recognizer = StreamingRecognizer(modelPath: modelPath)
try recognizer.loadModel()

// Check energy of an audio chunk
let chunk: [Float] = getAudioChunk()
let energy = recognizer.calculateEnergy(chunk)  // Returns RMS energy
print("Chunk energy: \(energy)")

// Check if chunk has sufficient energy (not silence)
// Default threshold: 0.01
if recognizer.hasSufficientEnergy(chunk) {
    print("Chunk has speech")
} else {
    print("Chunk is silence - skip processing")
}

// Customize energy threshold (default: 0.01)
recognizer.energyThreshold = 0.02  // Higher = more aggressive filtering
```

**Note:** These methods are provided for custom filtering but are not used automatically by the streaming engine.

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

### Model Management

SwiftFasterWhisper provides utilities for managing downloaded models:

```swift
import SwiftFasterWhisper

// Check if a model exists
let exists = ModelManager.modelExists(name: "whisper-medium-ct2")

// Get disk space used by all models
let totalSize = try ModelManager.getModelsSize()
print("Models use \(totalSize / 1024 / 1024) MB")

// Clear all downloaded models (free up disk space)
try ModelManager.clearAllModels()

// Get models directory path
let modelsDir = try ModelManager.defaultModelsDirectory()
print("Models stored at: \(modelsDir.path)")
```

**Available Model Sizes:**

```swift
WhisperModelSize.tiny      // ~75 MB   - Fastest, basic quality
WhisperModelSize.base      // ~140 MB  - Fast, good quality
WhisperModelSize.small     // ~460 MB  - Medium speed, better quality
WhisperModelSize.medium    // ~1.5 GB  - Slower, recommended quality
WhisperModelSize.largeV2   // ~3 GB    - Slowest, best quality
```

## Testing

The test suite includes:
- **File Transcription/Translation Tests**: Test batch processing of complete audio files
- **Streaming Tests**: Test real-time streaming with 0.5-second audio chunks
  - Uses 4-second sliding window with 3.5-second shift
  - Sends audio in 0.5s increments (8000 samples at 16kHz)
  - Polls `getNewSegment()` which retrieves segments from background queue
  - Background transcription runs in parallel with audio feeding
  - Validates non-blocking async API
- **Streaming Segments Tests**: Test streaming with Turkish audio segments
  - Tests files with duration > 7 seconds (minimum for 4s window)
  - Validates transcription and translation accuracy
  - Measures response time ratio (processing time / audio duration)
- **Turkish Audio Tests**: Test transcription and translation with Turkish audio segments from Ertugrul series

The tests automatically download the large-v2 model on first run (takes a few minutes):

```bash
swift test
```

The model is cached in `~/Library/Application Support/SwiftFasterWhisper/` and reused for subsequent test runs.

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
