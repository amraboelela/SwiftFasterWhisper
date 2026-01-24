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
#include <algorithm>
#include <sstream>
#include <set>

// Global map to store streaming buffers for each model
static std::map<WhisperModelHandle, std::shared_ptr<StreamingBuffer>> streaming_buffers;
static std::map<WhisperModelHandle, std::string> streaming_language;
static std::map<WhisperModelHandle, std::string> streaming_task;  // "transcribe" or "translate"
static std::map<WhisperModelHandle, size_t> last_transcribed_position;  // Track last transcribed window position

// Common hallucination phrases to filter out
static bool isHallucination(const std::string& text) {
    std::string lowercased = text;
    std::transform(lowercased.begin(), lowercased.end(), lowercased.begin(), ::tolower);

    // Trim whitespace
    size_t start = lowercased.find_first_not_of(" \t\n\r");
    size_t end = lowercased.find_last_not_of(" \t\n\r");
    if (start == std::string::npos) return true; // Empty or all whitespace
    lowercased = lowercased.substr(start, end - start + 1);

    // Common hallucination patterns for silence/background noise
    static const std::vector<std::string> hallucinations = {
        "see you in next video",
        "see you in the next",
        "see you in the next video",
        "see you in the next video.",
        "i hope you enjoyed this video",
        "hope you enjoyed this video",
        "i hope you enjoyed this video.",
        "hope you enjoyed this video.",
        "i hope you enjoyed",
        "subscribe",
        "don't forget to subscribe",
        "like and subscribe",
        "thanks for watching",
        "thank you for watching",
        "bye bye",
        "- bye.",
        "bye.",
        "-i'm going.",
        "for example.",
        "see you.",
        "-what? -what?",
        "wow.",
        "see you later",
        "see you next time",
        "music",
        "applause",
        "laughter",
        "silence",
        "translated by",
        "-thank you.",
        "translation by",
        "translation and translation by",
        "subtitle by",
        "subtitled by",
        "-goodbye.",
        "bye!",
        "please subscribe",
        "i'm sorry, i'm sorry",
        "come on, come on",
        "come on, come on.",
        "-come on. -come on.",
        "-turkish. -turkish.",
        "-i'm sorry. -it's okay.",
        "-let's go. -let's go.",
        "to be continued",
        "subtitle",
        "subtitles",
        "captions",
        // Turkish-specific hallucinations
        "altyazı",
        "m.k.",
        // Profanity filters
        "asshole",
        "assholes",
        "fuck",
        "fucking",
        "shit",
        "damn",
        "bitch",
        "bastard",
        "crap",
        "hell"
    };

    // Exact matches only for potentially ambiguous words
    static const std::vector<std::string> exactMatches = {
        "bye",
        "goodbye",
        "thank you",
        "the end",
        ".",
        "?",
        "!",
        "..."
    };

    // Check for exact matches or if text starts with common patterns
    for (const auto& hallucination : hallucinations) {
        if (lowercased == hallucination || lowercased.find(hallucination) == 0) {
            return true;
        }
    }

    // Check for exact matches only (not prefix)
    for (const auto& exactMatch : exactMatches) {
        if (lowercased == exactMatch) {
            return true;
        }
    }

    // Filter very short outputs (likely hallucinations)
    if (lowercased.length() <= 2) {
        return true;
    }

    // Filter repetitive patterns (e.g., "a a a a")
    std::istringstream iss(lowercased);
    std::vector<std::string> words;
    std::string word;
    while (iss >> word) {
        words.push_back(word);
    }

    if (words.size() > 1) {
        std::set<std::string> uniqueWords(words.begin(), words.end());
        // If most words are the same, likely a hallucination
        if (static_cast<double>(uniqueWords.size()) / words.size() < 0.5) {
            return true;
        }
    }

    // Filter bracketed annotations like (music), [laughter], (footsteps), *door closes*, -The End-
    if ((lowercased.front() == '(' && lowercased.back() == ')') ||
        (lowercased.front() == '[' && lowercased.back() == ']') ||
        (lowercased.front() == '*' && lowercased.back() == '*') ||
        (lowercased.front() == '-' && lowercased.back() == '-')) {
        return true;
    }

    return false;
}

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
        streaming_language.erase(model);
        streaming_task.erase(model);
        last_transcribed_position.erase(model);

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
    const char* language,
    const char* task
) {
    if (!model) {
        return;
    }

    // Create streaming buffer with 4-second sliding window (4s shifts)
    streaming_buffers[model] = std::make_shared<StreamingBuffer>(16000);
    streaming_language[model] = language ? std::string(language) : "";
    streaming_task[model] = task ? std::string(task) : "transcribe";
    last_transcribed_position[model] = SIZE_MAX;  // Initialize to invalid position
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

bool whisper_is_window_ready(WhisperModelHandle model) {
    if (!model) {
        return false;
    }

    auto buffer_it = streaming_buffers.find(model);
    if (buffer_it == streaming_buffers.end()) {
        return false;
    }

    return buffer_it->second->is_ready_to_decode();
}

void whisper_trim_buffer(
    WhisperModelHandle model,
    unsigned long sample_count
) {
    if (!model || sample_count == 0) {
        return;
    }

    auto buffer_it = streaming_buffers.find(model);
    if (buffer_it == streaming_buffers.end()) {
        std::cerr << "Streaming not started for this model" << std::endl;
        return;
    }

    auto buffer = buffer_it->second;
    if (buffer->size() >= sample_count) {
        buffer->trim_samples(sample_count);
        // Reset transcribed position since we trimmed
        last_transcribed_position[model] = SIZE_MAX;
    }
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

    // Check if we have a full 4-second window ready
    if (!buffer->is_ready_to_decode()) {
        return nullptr;
    }

    // Only transcribe if window position has changed since last transcription
    size_t current_position = buffer->window_position();
    if (last_transcribed_position[model] == current_position) {
        return nullptr;  // Already transcribed at this position
    }

    // Mark this position as transcribed BEFORE we actually transcribe
    // This prevents multiple transcriptions of the same window
    last_transcribed_position[model] = current_position;

    try {
        auto* whisper_model = static_cast<WhisperModel*>(model);

        // Get 4-second window from current position
        std::vector<float> window_audio = buffer->get_window();
        std::optional<std::string> lang = streaming_language[model].empty() ?
            std::nullopt : std::optional<std::string>(streaming_language[model]);

        std::string task = streaming_task[model];
        std::vector<Segment> segments;
        TranscriptionInfo info;

        if (task == "translate") {
            auto [trans_segs, trans_info] = whisper_model->translate(window_audio, lang);
            segments = trans_segs;
            info = trans_info;
        } else {
            auto [trans_segs, trans_info] = whisper_model->transcribe(window_audio, lang, true);
            segments = trans_segs;
            info = trans_info;
        }

        // Filter out hallucinations
        std::vector<Segment> filtered_segments;
        for (const auto& seg : segments) {
            std::string trimmed_text = seg.text;
            // Trim whitespace
            size_t start = trimmed_text.find_first_not_of(" \t\n\r");
            size_t end = trimmed_text.find_last_not_of(" \t\n\r");
            if (start != std::string::npos && end != std::string::npos) {
                trimmed_text = trimmed_text.substr(start, end - start + 1);
            }

            // Skip hallucinations
            if (!isHallucination(trimmed_text)) {
                filtered_segments.push_back(seg);
            } else {
                std::cout << "⚠️  Filtered hallucination: \"" << trimmed_text << "\"" << std::endl;
            }
        }

        // Emit all non-hallucination segments immediately
        // Trim by 4 seconds, leaving 0.2s in buffer for overlap with next window
        size_t trim_samples = 64000;  // 4 seconds at 16kHz
        if (buffer->size() >= trim_samples) {
            buffer->trim_samples(trim_samples);
        }

        // Reset transcribed position since we trimmed (buffer reset to position 0)
        last_transcribed_position[model] = SIZE_MAX;

        // Allocate and copy all filtered segments
        *count = filtered_segments.size();
        if (*count > 0) {
            TranscriptionSegment* result = static_cast<TranscriptionSegment*>(
                malloc(*count * sizeof(TranscriptionSegment))
            );

            for (size_t i = 0; i < filtered_segments.size(); ++i) {
                const auto& seg = filtered_segments[i];

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
    streaming_language.erase(model);
    streaming_task.erase(model);
    last_transcribed_position.erase(model);
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
