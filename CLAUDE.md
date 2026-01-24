# SwiftFasterWhisper — Project Overview (for Claude)

SwiftFasterWhisper is a macOS/iOS Swift framework that wraps the faster-whisper speech recognition engine (based on CTranslate2) to provide fast, on-device transcription and translation. The project aims to deliver a Swift-native API similar to Whisper.cpp, but using the higher-performance faster-whisper backend, enabling real-time streaming and low-latency transcription.

This project is a more generic version of IArabicSpeech (`/Users/amraboelela/develop/swift/IArabicSpeech`), supporting transcription for any language and translation from any language to English.

## Goals

- Provide a Swift-friendly interface for faster-whisper/CTranslate2
- Support real-time streaming audio input (e.g., 30ms chunks)
- Emit incremental segments and finalized subtitles
- Enable both transcription and translation with low latency
- Maintain performance similar to Python's faster-whisper implementation, but on macOS

## Core Components

### Swift API Layer

Swift classes and protocols for:
- Starting transcription
- Streaming audio input
- Receiving callbacks for segments
- Canceling transcription
- Provides async/await and delegate-based APIs

### C++ Wrapper (transcribe.cpp)

A C++ bridge that interacts with the faster-whisper engine.

Exposes functions like:
- `transcribe_stream(audio_chunk)`
- `get_new_segments()`
- `finalize_segments()`

### CTranslate2 / faster-whisper backend

- Uses the optimized CTranslate2 runtime for inference
- Supports Whisper models (ggml and converted formats)
- Offers speed improvements over whisper.cpp, especially on CPUs

## Streaming Strategy

The project implements streaming using:

1. A rolling audio buffer (e.g., 1–3 seconds)
2. A sliding window decode approach (e.g., decode every 1 second)
3. A segment deduplication strategy to prevent repeated output:
   - Use a cursor for "already emitted time"
   - Only emit segments that are stable and not overlapping with previous outputs
   - Keep a small margin to ensure the model doesn't finalize too early

## Key Features

- Low-latency transcription
- Streaming input (30ms chunks)
- Incremental segment output
- Translation support (any language to English)
- Cancelable transcription
- Swift concurrency support (async/await)

## Why SwiftFasterWhisper?

- Faster than whisper.cpp on CPU in many cases
- Provides a Swift-native API for macOS/iOS
- Useful for apps requiring real-time subtitles, live transcription, or translation

## Reference Implementation

This project is based on learnings from IArabicSpeech. When implementing features, refer to `/Users/amraboelela/develop/swift/IArabicSpeech` for architecture patterns and implementation details.

## Development Guidelines

- Follow Swift best practices and modern concurrency patterns
- Maintain compatibility with both macOS and iOS
- Optimize for low-latency, real-time performance
- Keep the API simple and Swift-idiomatic
- Document all public APIs thoroughly

## Rules
- Do not build project by yourself
- Do not run swift test by yourself
- instead of let self = self do let self
