//
// SwiftFasterWhisperBridge.cpp
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/21/2026.
//

#include "SwiftFasterWhisper-Bridging.h"
#include "whisper/whisper_audio.h"
#include "feature_extractor.h"
#include "transcribe.h"
#include "streaming_buffer.h"
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <map>
#include <vector>
#include <memory>

// Global map to store streaming buffers for each model
static std::map<WhisperModelHandle, std::shared_ptr<StreamingBuffer>> streaming_buffers;
static std::map<WhisperModelHandle, std::vector<Segment>> streaming_segments_cache;
static std::map<WhisperModelHandle, std::string> streaming_language;

extern "C" {

FloatArray whisper_load_audio(const char* filename) {
    FloatArray result = {nullptr, 0};

    if (!filename) {
        return result;
    }

    // Load audio using whisper audio processor
    std::vector<float> audio = whisper::AudioProcessor::load_audio(filename);

    if (audio.empty()) {
        return result;
    }

    // Allocate C array and copy data
    result.length = audio.size();
    result.data = static_cast<float*>(malloc(result.length * sizeof(float)));
    if (result.data) {
        std::memcpy(result.data, audio.data(), result.length * sizeof(float));
    } else {
        result.length = 0;
    }

    return result;
}

FloatMatrix whisper_extract_mel_spectrogram(const float* audio, unsigned long length) {
    FloatMatrix result = {nullptr, 0, 0};

    if (!audio || length == 0) {
        return result;
    }

    // Convert to std::vector
    std::vector<float> audio_vec(audio, audio + length);

    // Create feature extractor
    FeatureExtractor extractor(80, 16000, 160, 30, 400);

    // Extract mel spectrogram
    Matrix mel_spec = extractor.compute_mel_spectrogram(audio_vec, 160);

    if (mel_spec.empty()) {
        return result;
    }

    // Allocate C 2D array and copy data
    result.rows = mel_spec.size();
    result.cols = mel_spec[0].size();
    result.data = static_cast<float**>(malloc(result.rows * sizeof(float*)));

    if (result.data) {
        for (unsigned long i = 0; i < result.rows; ++i) {
            result.data[i] = static_cast<float*>(malloc(result.cols * sizeof(float)));
            if (result.data[i]) {
                std::memcpy(result.data[i], mel_spec[i].data(), result.cols * sizeof(float));
            } else {
                // Cleanup on failure
                for (unsigned long j = 0; j < i; ++j) {
                    free(result.data[j]);
                }
                free(result.data);
                result.data = nullptr;
                result.rows = 0;
                result.cols = 0;
                return result;
            }
        }
    } else {
        result.rows = 0;
        result.cols = 0;
    }

    return result;
}

void whisper_free_float_array(FloatArray array) {
    if (array.data) {
        free(array.data);
    }
}

void whisper_free_float_matrix(FloatMatrix matrix) {
    if (matrix.data) {
        for (unsigned long i = 0; i < matrix.rows; ++i) {
            if (matrix.data[i]) {
                free(matrix.data[i]);
            }
        }
        free(matrix.data);
    }
}

// Model management and transcription functions

WhisperModelHandle whisper_create_model(const char* model_path) {
    if (!model_path) {
        return nullptr;
    }

    try {
        // Create WhisperModel with full CTranslate2 parameters
        auto* model = new WhisperModel(
            model_path,           // model_size_or_path
            "cpu",                // device
            {0},                  // device_index (at least one device needed)
            "float32",            // compute_type
            0,                    // cpu_threads (0 = auto)
            1,                    // num_workers
            "",                   // download_root
            false,                // local_files_only
            {},                   // files
            "",                   // revision
            ""                    // use_auth_token
        );
        return static_cast<WhisperModelHandle>(model);
    } catch (const std::exception& e) {
        std::cerr << "Failed to create Whisper model: " << e.what() << std::endl;
        return nullptr;
    }
}

void whisper_destroy_model(WhisperModelHandle model) {
    if (model) {
        // Clean up streaming resources if any
        streaming_buffers.erase(model);
        streaming_segments_cache.erase(model);
        streaming_language.erase(model);

        delete static_cast<WhisperModel*>(model);
    }
}

TranscriptionResult whisper_transcribe(
    WhisperModelHandle model,
    const float* audio,
    unsigned long audio_length,
    const char* language
) {
    TranscriptionResult result = {nullptr, 0, nullptr, 0.0f, 0.0f};

    if (!model || !audio || audio_length == 0) {
        return result;
    }

    try {
        auto* whisper_model = static_cast<WhisperModel*>(model);

        // Convert audio to std::vector
        std::vector<float> audio_vec(audio, audio + audio_length);

        // Transcribe
        std::optional<std::string> lang = language ? std::optional<std::string>(language) : std::nullopt;
        auto [segments, info] = whisper_model->transcribe(audio_vec, lang, true);

        // Allocate and copy segments
        result.segment_count = segments.size();
        if (result.segment_count > 0) {
            result.segments = static_cast<TranscriptionSegment*>(
                malloc(result.segment_count * sizeof(TranscriptionSegment))
            );

            for (size_t i = 0; i < segments.size(); ++i) {
                const auto& seg = segments[i];

                // Allocate and copy text
                result.segments[i].text = static_cast<char*>(malloc(seg.text.length() + 1));
                std::strcpy(result.segments[i].text, seg.text.c_str());

                result.segments[i].start = seg.start;
                result.segments[i].end = seg.end;
            }
        }

        // Allocate and copy language
        result.language = static_cast<char*>(malloc(info.language.length() + 1));
        std::strcpy(result.language, info.language.c_str());

        result.language_probability = info.language_probability;
        result.duration = info.duration;

    } catch (const std::exception& e) {
        std::cerr << "Transcription failed: " << e.what() << std::endl;
    }

    return result;
}

TranscriptionResult whisper_translate(
    WhisperModelHandle model,
    const float* audio,
    unsigned long audio_length,
    const char* source_language
) {
    TranscriptionResult result = {nullptr, 0, nullptr, 0.0f, 0.0f};

    if (!model || !audio || audio_length == 0) {
        return result;
    }

    try {
        auto* whisper_model = static_cast<WhisperModel*>(model);

        // Convert audio to std::vector
        std::vector<float> audio_vec(audio, audio + audio_length);

        // Translate (will use the translate method when implemented)
        // For now, use transcribe with note that full translation requires task="translate"
        std::optional<std::string> lang = source_language ? std::optional<std::string>(source_language) : std::nullopt;
        auto [segments, info] = whisper_model->translate(audio_vec, lang);

        // Allocate and copy segments
        result.segment_count = segments.size();
        if (result.segment_count > 0) {
            result.segments = static_cast<TranscriptionSegment*>(
                malloc(result.segment_count * sizeof(TranscriptionSegment))
            );

            for (size_t i = 0; i < segments.size(); ++i) {
                const auto& seg = segments[i];

                // Allocate and copy text
                result.segments[i].text = static_cast<char*>(malloc(seg.text.length() + 1));
                std::strcpy(result.segments[i].text, seg.text.c_str());

                result.segments[i].start = seg.start;
                result.segments[i].end = seg.end;
            }
        }

        // Allocate and copy language (source language)
        result.language = static_cast<char*>(malloc(info.language.length() + 1));
        std::strcpy(result.language, info.language.c_str());

        result.language_probability = info.language_probability;
        result.duration = info.duration;

    } catch (const std::exception& e) {
        std::cerr << "Translation failed: " << e.what() << std::endl;
    }

    return result;
}

// Streaming functions

void whisper_start_streaming(
    WhisperModelHandle model,
    const char* language
) {
    if (!model) {
        return;
    }

    // Create streaming buffer for this model
    streaming_buffers[model] = std::make_shared<StreamingBuffer>(30, 16000);  // 30 seconds buffer for better context
    streaming_segments_cache[model] = std::vector<Segment>();
    streaming_language[model] = language ? std::string(language) : "";
}

void whisper_add_audio_chunk(
    WhisperModelHandle model,
    const float* chunk,
    unsigned long chunk_length
) {
    if (!model || !chunk || chunk_length == 0) {
        return;
    }

    auto it = streaming_buffers.find(model);
    if (it == streaming_buffers.end()) {
        std::cerr << "Streaming not started for this model" << std::endl;
        return;
    }

    std::vector<float> chunk_vec(chunk, chunk + chunk_length);
    it->second->add_chunk(chunk_vec);
}

TranscriptionSegment* whisper_get_new_segments(
    WhisperModelHandle model,
    unsigned long* count
) {
    *count = 0;

    if (!model) {
        return nullptr;
    }

    auto buffer_it = streaming_buffers.find(model);
    if (buffer_it == streaming_buffers.end()) {
        std::cerr << "Streaming not started for this model" << std::endl;
        return nullptr;
    }

    auto buffer = buffer_it->second;

    // Check if ready to decode
    if (!buffer->is_ready_to_decode()) {
        return nullptr;
    }

    try {
        auto* whisper_model = static_cast<WhisperModel*>(model);

        // Get current buffer (full audio from beginning)
        std::vector<float> audio = buffer->get_buffer();

        // Transcribe full buffer from beginning
        std::optional<std::string> lang = streaming_language[model].empty() ?
            std::nullopt : std::optional<std::string>(streaming_language[model]);

        auto [segments, info] = whisper_model->transcribe(audio, lang, true);

        // Get previous segments
        std::vector<Segment>& prev_segments = streaming_segments_cache[model];

        // Check if first segment is stable (same as previous first segment)
        std::vector<Segment> stable_segments;

        if (!prev_segments.empty() && !segments.empty()) {
            // Compare first segment only
            if (segments[0].text == prev_segments[0].text) {
                // First segment is stable - emit it!
                stable_segments.push_back(segments[0]);
            }
        }

        // Update cache with current segments
        streaming_segments_cache[model] = segments;

        // If first segment is stable, emit and advance window
        if (!stable_segments.empty()) {
            float segment_end = stable_segments[0].end;
            size_t trim_samples = static_cast<size_t>(segment_end * 16000);
            buffer->trim_samples(trim_samples);

            // Clear cache - next transcription starts fresh
            streaming_segments_cache[model].clear();
        }

        // Allocate and copy stable segments
        *count = stable_segments.size();
        if (*count > 0) {
            TranscriptionSegment* result = static_cast<TranscriptionSegment*>(
                malloc(*count * sizeof(TranscriptionSegment))
            );

            for (size_t i = 0; i < stable_segments.size(); ++i) {
                const auto& seg = stable_segments[i];

                // Allocate and copy text
                result[i].text = static_cast<char*>(malloc(seg.text.length() + 1));
                std::strcpy(result[i].text, seg.text.c_str());

                result[i].start = seg.start;
                result[i].end = seg.end;
            }

            return result;
        }

    } catch (const std::exception& e) {
        std::cerr << "Streaming transcription failed: " << e.what() << std::endl;
    }

    return nullptr;
}

void whisper_stop_streaming(WhisperModelHandle model) {
    if (!model) {
        return;
    }

    // Clean up streaming resources
    streaming_buffers.erase(model);
    streaming_segments_cache.erase(model);
    streaming_language.erase(model);
}

void whisper_free_transcription_result(TranscriptionResult result) {
    if (result.segments) {
        for (unsigned long i = 0; i < result.segment_count; ++i) {
            if (result.segments[i].text) {
                free(result.segments[i].text);
            }
        }
        free(result.segments);
    }
    if (result.language) {
        free(result.language);
    }
}

void whisper_free_segments(TranscriptionSegment* segments, unsigned long count) {
    if (segments) {
        for (unsigned long i = 0; i < count; ++i) {
            if (segments[i].text) {
                free(segments[i].text);
            }
        }
        free(segments);
    }
}

} // extern "C"
