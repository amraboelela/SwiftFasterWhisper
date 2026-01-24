//
// SwiftFasterWhisper-Bridging.h
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/21/2026.
//

#ifndef SwiftFasterWhisper_Bridging_h
#define SwiftFasterWhisper_Bridging_h

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// C API for whisper audio processing
typedef struct {
    float* data;
    unsigned long length;
} FloatArray;

typedef struct {
    float** data;
    unsigned long rows;
    unsigned long cols;
} FloatMatrix;

// Opaque pointer to WhisperModel (C++ class)
typedef void* WhisperModelHandle;

// Transcription result structure
typedef struct {
    char* text;              // Transcribed text
    float start;             // Start time in seconds
    float end;               // End time in seconds
} TranscriptionSegment;

typedef struct {
    TranscriptionSegment* segments;
    unsigned long segment_count;
    char* language;
    float language_probability;
    float duration;
} TranscriptionResult;

// Audio processing functions
FloatArray whisper_load_audio(const char* filename);
FloatMatrix whisper_extract_mel_spectrogram(const float* audio, unsigned long length);

// Model management functions
WhisperModelHandle whisper_create_model(const char* model_path);
void whisper_destroy_model(WhisperModelHandle model);

// Batch transcription
TranscriptionResult whisper_transcribe(
    WhisperModelHandle model,
    const float* audio,
    unsigned long audio_length,
    const char* language  // NULL for auto-detect
);

// Translation (any language → English)
TranscriptionResult whisper_translate(
    WhisperModelHandle model,
    const float* audio,
    unsigned long audio_length,
    const char* source_language  // NULL for auto-detect
);

// Streaming transcription functions
void whisper_start_streaming(
    WhisperModelHandle model,
    const char* language,  // NULL for auto-detect
    const char* task       // "transcribe" or "translate", NULL defaults to "transcribe"
);

void whisper_add_audio_chunk(
    WhisperModelHandle model,
    const float* chunk,
    unsigned long chunk_length
);

TranscriptionSegment* whisper_get_new_segments(
    WhisperModelHandle model,
    unsigned long* count  // Output: number of segments
);

void whisper_stop_streaming(WhisperModelHandle model);

// Memory cleanup functions
void whisper_free_float_array(FloatArray array);
void whisper_free_float_matrix(FloatMatrix matrix);
void whisper_free_transcription_result(TranscriptionResult result);
void whisper_free_segments(TranscriptionSegment* segments, unsigned long count);

#ifdef __cplusplus
}
#endif

#endif /* SwiftFasterWhisper_Bridging_h */
