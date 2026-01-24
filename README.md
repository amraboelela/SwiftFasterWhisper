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

// Or stream real-time audio (with auto-download)
let recognizer = StreamingRecognizer()
try await recognizer.loadModel()  // Auto-downloads model on first use
await recognizer.configure(language: "en")

// Or with custom model path
let recognizer = StreamingRecognizer(modelPath: modelPath)
try await recognizer.loadModel()
await recognizer.configure(language: "en")

// Feed 1s chunks (16000 samples at 16kHz)
try await recognizer.addAudioChunk(audioChunk)

// Poll for new segments (non-blocking)
let segments = await recognizer.getNewSegments()
for segment in segments {
    print(segment.text)
}
```

## Overview

SwiftFasterWhisper provides a Swift-native API for fast, on-device transcription and translation. It wraps the faster-whisper speech recognition engine, offering performance improvements over whisper.cpp while maintaining a clean, Swift-idiomatic interface.

### Key Features

- **Real-time Streaming**: Process audio using 4.2-second sliding window with 1-second chunks
- **Near Real-Time Performance**: Background transcription with single-flight model execution guard
- **Smart Buffer Management**: Automatically drops lowest-energy chunks when model is busy to preserve important audio content
- **Non-blocking API**: Background transcription with async/await support
- **Incremental Output**: Poll for segments using non-blocking `getNewSegments()` method
- **Multi-language Support**: Transcribe speech in any language
- **Translation**: Translate from any language to English using Whisper's speech-to-English capability (not a replacement for dedicated MT models)
- **Swift Concurrency**: Modern async/await with actor-based thread safety
- **Cancelable Operations**: Stop streaming at any time
- **High Performance**: Leverages CTranslate2 for optimized inference

## Architecture

### Components

1. **ModelManager**: Model wrapper that handles both model management and transcription
   - Runs transcription in background using Task.detached
   - Uses busy flag to prevent concurrent model calls (single-flight execution)
   - Provides static utilities for downloading and managing models
   - No knowledge of streaming or buffering

2. **StreamingRecognizer**: Handles streaming orchestration
   - Buffers audio chunks into 4.2s windows (67200 samples)
   - Calls ModelManager.transcribe() when window is ready
   - Removes processed window from buffer after each transcription
   - Smart overflow handling: drops lowest-energy chunks when model is busy to preserve important audio

3. **C++ Wrapper**: Bridge between Swift and faster-whisper engine (`transcribe.cpp`)

4. **CTranslate2 Backend**: Optimized runtime for Whisper model inference

### Streaming Approach

**Streaming Parameters (defaults):**
```
Chunk size:   1.0s  (16000 samples at 16kHz)
Window size:  4.2s  (67200 samples)
Shift size:   4.2s  (67200 samples per submission)
Overlap:      0.0s  (no overlap, clean boundaries)
```

**TL;DR:**
- Feed 1s audio chunks via `addAudioChunk()`
- Internally buffers until 4.2s of audio accumulated
- Submits 4.2s window for transcription (removes from buffer immediately)
- Poll for segments using `await getNewSegments()`

---

SwiftFasterWhisper uses a concurrent streaming strategy for real-time transcription:

**Design:**
- **4.2-second audio window** (67200 samples at 16kHz) for transcription
- **1-second chunks** (16000 samples) recommended for feeding audio
- **4.2-second shift** between transcriptions (no overlap, clean boundaries)
- **Background transcription**: Runs in Task, doesn't block main thread
- **Single-flight execution**: Busy flag prevents concurrent model calls
- **Intelligent buffer management**: Drops lowest-energy chunks when buffer is full and model is busy

**How It Works:**
1. User calls `addAudioChunk()` with 1s chunks (non-blocking, returns immediately)
2. StreamingRecognizer accumulates chunks into a buffer
3. When buffer reaches 4.2s and model is not busy:
   - Extracts 4.2s window from buffer
   - Spawns background Task calling ModelManager.transcribe()
   - Sets busy flag to prevent concurrent calls
   - Removes the window from buffer
4. If buffer is full and model is busy:
   - Scans all 1-second chunks in buffer and calculates energy for each
   - Drops the chunk with the lowest energy (prioritizes keeping important audio content)
   - This automatically removes silence first while preserving speech
5. When transcription completes:
   - Stores segments for polling via `getNewSegments()`
   - Clears busy flag
6. User polls `await getNewSegments()` to retrieve new segments (non-blocking)

**Concurrency Benefits:**
- Non-blocking API allows UI updates while transcribing
- Background tasks enable parallel audio feeding and transcription
- Busy flag prevents model overload (one in-flight transcription at a time)
- Smart buffer management preserves important audio by dropping low-energy chunks when needed
- Thread-safe segment queue using Swift actors

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

**Important:** Translation uses Whisper's built-in speech-to-English capability, which is optimized for robustness over linguistic nuance. It is **not a replacement for dedicated machine translation models** like NLLB or Google Translate. Whisper translation:

- Works directly from speech (not transcription → translation)
- Prioritizes capturing meaning over perfect grammar
- Quality varies significantly by source language
- Works best with the `large-v2` or `medium` model

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
try await recognizer.loadModel()

// Keep strong reference to delegate to prevent deallocation
let delegate = MyDelegate()
await recognizer.setDelegate(delegate)
await recognizer.configure(language: "en")

// Feed audio chunks (1 second chunks = 16000 samples at 16kHz recommended)
// Chunks are accumulated in a 4.2-second sliding window
while streaming {
    let chunk: [Float] = getNextAudioChunk()  // Your audio capture (16000 samples = 1s)
    try await recognizer.addAudioChunk(chunk)

    // Poll for new segments (non-blocking, retrieves from internal queue)
    let newSegments = await recognizer.getNewSegments()
    for segment in newSegments {
        print("New segment: \(segment.text)")
    }
}

await recognizer.stop()
```

#### Async/Await Pattern

```swift
let recognizer = StreamingRecognizer(modelPath: modelPath)
try await recognizer.loadModel()
await recognizer.configure(language: "en")

// Feed audio chunks in background
Task {
    for await chunk in audioStream {  // Your audio stream
        try await recognizer.addAudioChunk(chunk)
    }
    await recognizer.stop()
}

// Poll for segments in main loop
while streaming {
    let segments = await recognizer.getNewSegments()
    for segment in segments {
        print("[\(segment.start)s - \(segment.end)s] \(segment.text)")
    }

    // Small delay to avoid tight loop
    try await Task.sleep(for: .milliseconds(100))
}
```

**Important: `getNewSegments()` Behavior**

The `getNewSegments()` method:
- Returns **array of new segments** from the internal queue
- Is **non-blocking** - returns immediately with segments or empty array
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
- **Streaming Tests**: Test real-time streaming with 1-second audio chunks
  - Uses 4.2-second sliding window with 4.2-second shift (no overlap)
  - Sends audio in 1s increments (16000 samples at 16kHz)
  - Simulates real-time by adding 1-second delays between chunks
  - Polls `getNewSegments()` which retrieves segments from internal queue
  - Background transcription runs concurrently with audio feeding
  - Validates smart buffer management (drops lowest-energy chunks when model is busy)
  - Validates non-blocking async API
- **Streaming Segments Tests**: Test streaming with Turkish audio segments
  - Tests files with duration > 8 seconds (minimum for 4.2s window)
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
