//
// streaming_buffer.cpp
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/21/2026.
//

#include "streaming_buffer.h"
#include <algorithm>
#include <iostream>

StreamingBuffer::StreamingBuffer(size_t buffer_seconds, size_t sample_rate)
    : buffer_size_samples_(buffer_seconds * sample_rate),
      sample_rate_(sample_rate),
      emitted_time_cursor_(0.0f),
      min_decode_samples_(sample_rate)  // 1 second minimum
{
    buffer_.reserve(buffer_size_samples_);
}

void StreamingBuffer::add_chunk(const std::vector<float> &chunk) {
    // Add new chunk to buffer
    buffer_.insert(buffer_.end(), chunk.begin(), chunk.end());

    // If buffer exceeds max size, remove oldest samples
    if (buffer_.size() > buffer_size_samples_) {
        size_t excess = buffer_.size() - buffer_size_samples_;
        buffer_.erase(buffer_.begin(), buffer_.begin() + excess);

        // Update cursor to account for removed samples
        float removed_time = static_cast<float>(excess) / sample_rate_;
        emitted_time_cursor_ = std::max(0.0f, emitted_time_cursor_ - removed_time);
    }
}

std::vector<float> StreamingBuffer::get_buffer() const {
    return buffer_;
}

void StreamingBuffer::update_cursor(float time) {
    emitted_time_cursor_ = time;
}

bool StreamingBuffer::is_ready_to_decode() const {
    return buffer_.size() >= min_decode_samples_;
}

float StreamingBuffer::get_cursor() const {
    return emitted_time_cursor_;
}

void StreamingBuffer::reset() {
    buffer_.clear();
    emitted_time_cursor_ = 0.0f;
}

size_t StreamingBuffer::size() const {
    return buffer_.size();
}

float StreamingBuffer::duration() const {
    return static_cast<float>(buffer_.size()) / sample_rate_;
}
