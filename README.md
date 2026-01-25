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
let recognizer = StreamingRecognizer()
try await recognizer.configure(language: "en")  // Auto-loads model

// Or with custom model path
let recognizer = StreamingRecognizer(modelPath: modelPath)
try await recognizer.configure(language: "en")  // Loads model automatically

// Feed 1s chunks (16000 samples at 16kHz)
await recognizer.addAudioChunk(audioChunk)

// Poll for new text (non-blocking)
let text = await recognizer.getNewText()
if !text.isEmpty {
    print(text)
}
```

## Overview

SwiftFasterWhisper provides a Swift-native API for fast, on-device transcription and translation. It wraps the faster-whisper speech recognition engine, offering performance improvements over whisper.cpp while maintaining a clean, Swift-idiomatic interface.

### Key Features

- **Real-time Streaming**: Incremental chunk-by-chunk processing with immediate segment polling
- **Adaptive Energy Filtering**: Automatically drops low-energy chunks based on processing speed
- **Synchronous Processing**: Direct C++ calls with no actor overhead for maximum performance
- **Non-blocking API**: async/await support for smooth UI integration
- **Incremental Output**: Poll for text using non-blocking `getNewText()` method
- **Multi-language Support**: Transcribe speech in any language
- **Translation**: Translate from any language to English using Whisper's speech-to-English capability (not a replacement for dedicated MT models)
- **Swift Concurrency**: Modern async/await pattern
- **Cancelable Operations**: Stop streaming at any time
- **High Performance**: Leverages CTranslate2 for optimized inference

## Architecture

### Components

1. **ModelManager**: Synchronous model wrapper
   - Direct calls to C++ transcription engine
   - No background tasks or busy flags
   - Provides static utilities for downloading and managing models

2. **StreamingRecognizer**: Actor-based producer-consumer streaming orchestration
   - **Producer**: `addAudioChunk()` quickly adds chunks to actor-isolated queue
   - **Consumer**: Background task processes chunks from queue and sends to C++
   - Polls for new segments after each chunk is processed
   - Adaptive energy filtering based on processing speed
   - Thread-safe via Swift actor isolation

3. **EnergyStatistics**: Global adaptive threshold calculator (actor-based)
   - Tracks processing speed ratio (transcription time / audio duration)
   - Automatically adjusts energy threshold based on model performance
   - Drops low-energy chunks when ratio > 1.0 (model falling behind)
   - Thread-safe via Swift actor isolation

4. **C++ Streaming Buffer**: Manages audio window and transcription
   - Accumulates chunks until 4-second window ready
   - Decides when to transcribe based on buffer size
   - Handles window sliding and overlap

5. **CTranslate2 Backend**: Optimized runtime for Whisper model inference

### Streaming Approach

**Streaming Parameters:**
```
Chunk size:   1.0s  (16000 samples at 16kHz)
Window size:  4.0s  (64000 samples in C++ buffer)
Shift size:   4.0s  (complete window processed each time)
Overlap:      0.2s  (small overlap for continuity)
```

**TL;DR:**
- Feed 1s audio chunks via `addAudioChunk()`
- C++ accumulates until 4s window ready
- Synchronously polls for segments after each chunk
- Adaptive energy filtering drops low-quality chunks when model falls behind

---

SwiftFasterWhisper uses a synchronous streaming strategy with adaptive filtering:

**Design:**
- **4-second audio window** in C++ buffer for transcription
- **1-second chunks** (16000 samples) recommended for feeding audio
- **Synchronous polling**: After each chunk, immediately poll for new segments
- **Adaptive energy filtering**: Automatically drops low-energy chunks when processing speed ratio > 1.0
- **Global statistics**: Tracks performance across all sessions for accurate threshold calculation

**How It Works:**
1. **Producer**: User calls `addAudioChunk()` - actor-isolated append to queue
2. **Consumer**: Background task dequeues chunk and processes it:
   - Calculates chunk energy (average absolute amplitude)
   - If ratio > 1.0 (model falling behind):
     - Threshold = average_energy × (ratio - 1.0)
     - Example: ratio = 1.2 → threshold = average × 0.2 (20%)
     - Drops chunk if energy < threshold
   - Accepted chunks sent to C++ streaming buffer
3. C++ accumulates until 4s window ready
4. Transcribes and returns segments
5. Updates global statistics (transcription time, chunk duration)
6. Returns segments to Swift layer via polling

**Actor Isolation Benefits:**
- Thread-safe queue access without manual locks
- Clean separation between producer (user thread) and consumer (background task)
- Swift concurrency handles synchronization automatically

**Adaptive Filtering Benefits:**
- Automatically adjusts to system performance
- Drops silence/background noise first (lowest energy)
- Preserves important speech (higher energy)
- Prevents buffer overflow and audio loss
- Self-tuning based on actual processing speed

**Performance Tracking:**
- `ratio = totalTranscriptionTime / totalChunksDuration`
- ratio < 1.0: Model faster than real-time → minimal/no dropping (1% threshold)
- ratio = 1.0: Perfect real-time → baseline dropping
- ratio > 1.0: Model falling behind → aggressive dropping to catch up
- Statistics persist across sessions for stable thresholds

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

```swift
import SwiftFasterWhisper

// Setup
let modelPath = try await getModelPath()
let recognizer = StreamingRecognizer(modelPath: modelPath)
try await recognizer.configure(language: "en")

// Feed audio chunks (1 second chunks = 16000 samples at 16kHz recommended)
// Chunks are accumulated in a 4.2-second sliding window
while streaming {
    let chunk: [Float] = getNextAudioChunk()  // Your audio capture (16000 samples = 1s)
    await recognizer.addAudioChunk(chunk)  // Actor-isolated, thread-safe

    // Poll for new text (non-blocking)
    let text = await recognizer.getNewText()
    if !text.isEmpty {
        print(text)
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
        await recognizer.addAudioChunk(chunk)  // Actor-isolated
    }
    await recognizer.stop()
}

// Poll for segments in main loop
while streaming {
    let text = await recognizer.getNewText()
    if !text.isEmpty {
        print(text)
    }

    // Small delay to avoid tight loop
    try await Task.sleep(for: .milliseconds(100))
}
```

**Important: `getNewText()` Behavior**

The `getNewText()` method:
- Returns **accumulated text** since last call
- Is **non-blocking** - returns immediately with text or empty string
- **Clears** the accumulated text after returning it
- Background task handles the blocking transcription calls

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
