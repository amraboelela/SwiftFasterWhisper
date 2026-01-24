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
/// Supports adding audio chunks and maintaining a sliding window (4.2s window, 4s shift, 0.2s overlap)
class StreamingBuffer {
public:
    /// Constructor
    /// @param sample_rate Audio sample rate in Hz (default: 16000)
    explicit StreamingBuffer(size_t sample_rate = 16000);

    /// Add an audio chunk to the buffer
    /// @param chunk Audio samples to add
    void add_chunk(const std::vector<float> &chunk);

    /// Get a 4-second window from the current position for transcription
    /// @return Vector of audio samples (4 seconds worth)
    std::vector<float> get_window() const;

    /// Check if buffer has enough audio for a 4-second window
    /// @return true if buffer has at least 4 seconds from current window position
    bool is_ready_to_decode() const;

    /// Slide the window forward by 3.5 seconds
    void slide_window();

    /// Trim samples from the beginning of the buffer after emitting a segment
    /// Also resets window position to 0
    /// @param samples Number of samples to remove from the beginning
    void trim_samples(size_t samples);

    /// Reset the buffer and window position
    void reset();

    /// Get buffer size in samples
    /// @return Number of samples in buffer
    size_t size() const;

    /// Get buffer duration in seconds
    /// @return Duration in seconds
    float duration() const;

    /// Get current window start position
    /// @return Window start position in samples
    size_t window_position() const;

private:
    std::vector<float> buffer_;          // Accumulated audio buffer
    size_t sample_rate_;                 // Audio sample rate (16000 Hz)
    size_t window_start_;                // Current window start position (in samples)

    static constexpr size_t WINDOW_SIZE_SAMPLES = 67200;  // 4.2 seconds at 16kHz
    static constexpr size_t SLIDE_SIZE_SAMPLES = 56000;   // 3.5 seconds at 16kHz (deprecated)
};

#endif // STREAMING_BUFFER_H
