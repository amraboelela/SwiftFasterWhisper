//
// streaming_buffer.cpp
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/21/2026.
//

#include "streaming_buffer.h"
#include <algorithm>
#include <iostream>

StreamingBuffer::StreamingBuffer(size_t sample_rate)
    : sample_rate_(sample_rate),
      window_start_(0)
{
    buffer_.reserve(WINDOW_SIZE_SAMPLES * 2);  // Reserve space for 8 seconds
}

void StreamingBuffer::add_chunk(const std::vector<float> &chunk) {
    // Accumulate audio in the buffer
    buffer_.insert(buffer_.end(), chunk.begin(), chunk.end());
}

std::vector<float> StreamingBuffer::get_window() const {
    // Check if we have enough samples for a full 4-second window
    if (window_start_ >= buffer_.size() ||
        window_start_ + WINDOW_SIZE_SAMPLES > buffer_.size()) {
        // Not enough audio for a full window
        return std::vector<float>();
    }

    // Return exactly 4 seconds from current window position
    return std::vector<float>(
        buffer_.begin() + window_start_,
        buffer_.begin() + window_start_ + WINDOW_SIZE_SAMPLES
    );
}

bool StreamingBuffer::is_ready_to_decode() const {
    // Check if we have at least 4 seconds from the current window position
    return window_start_ < buffer_.size() &&
           (window_start_ + WINDOW_SIZE_SAMPLES) <= buffer_.size();
}

void StreamingBuffer::slide_window() {
    // Slide the window forward by 3.5 seconds
    // Make sure we don't go beyond the buffer
    size_t new_position = window_start_ + SLIDE_SIZE_SAMPLES;

    // Only slide if we'll still have a full 4-second window available
    if (new_position + WINDOW_SIZE_SAMPLES <= buffer_.size()) {
        window_start_ = new_position;
    }
    // If we can't slide anymore, window_start_ stays at current position
}

void StreamingBuffer::trim_samples(size_t samples) {
    if (samples >= buffer_.size()) {
        // Trim everything
        buffer_.clear();
        window_start_ = 0;
    } else {
        // Remove samples from beginning
        buffer_.erase(buffer_.begin(), buffer_.begin() + samples);
        // Reset window to start
        window_start_ = 0;
    }
}

void StreamingBuffer::reset() {
    buffer_.clear();
    window_start_ = 0;
}

size_t StreamingBuffer::size() const {
    return buffer_.size();
}

float StreamingBuffer::duration() const {
    return static_cast<float>(buffer_.size()) / sample_rate_;
}

size_t StreamingBuffer::window_position() const {
    return window_start_;
}
