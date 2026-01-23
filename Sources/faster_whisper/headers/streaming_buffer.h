//
// streaming_buffer.h
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/21/2026.
//

#ifndef STREAMING_BUFFER_H
#define STREAMING_BUFFER_H

#include <vector>
#include <cstddef>

/// StreamingBuffer manages a rolling audio buffer for real-time transcription
/// Supports adding audio chunks and maintaining a sliding window for decoding
class StreamingBuffer {
public:
    /// Constructor
    /// @param buffer_seconds Maximum buffer duration in seconds (default: 30)
    /// @param sample_rate Audio sample rate in Hz (default: 16000)
    explicit StreamingBuffer(size_t buffer_seconds = 30, size_t sample_rate = 16000);

    /// Add an audio chunk to the buffer
    /// @param chunk Audio samples to add
    void add_chunk(const std::vector<float> &chunk);

    /// Get the current buffer contents for transcription
    /// @return Vector of audio samples
    std::vector<float> get_buffer() const;

    /// Update the time cursor after emitting segments
    /// @param time Time in seconds of the last emitted segment
    void update_cursor(float time);

    /// Check if buffer is ready for decoding
    /// @return true if buffer has enough audio for decoding
    bool is_ready_to_decode() const;

    /// Get the current time cursor
    /// @return Time cursor in seconds
    float get_cursor() const;

    /// Reset the buffer and cursor
    void reset();

    /// Get buffer size in samples
    /// @return Number of samples in buffer
    size_t size() const;

    /// Get buffer duration in seconds
    /// @return Duration in seconds
    float duration() const;

    /// Trim samples from the beginning of the buffer (after emitting segments)
    /// @param samples Number of samples to remove from the beginning
    void trim_samples(size_t samples);

private:
    std::vector<float> buffer_;          // Rolling audio buffer
    size_t buffer_size_samples_;         // Maximum buffer size in samples
    size_t sample_rate_;                 // Audio sample rate
    float emitted_time_cursor_;          // Track what's been emitted (in seconds)
    size_t min_decode_samples_;          // Minimum samples needed to decode
};

#endif // STREAMING_BUFFER_H
