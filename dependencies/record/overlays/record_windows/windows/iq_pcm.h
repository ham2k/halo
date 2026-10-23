// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

#pragma once

#include <cstddef>
#include <cstdint>
#include <vector>

namespace record_windows {

enum class IqFormatStatus { valid, invalidFormat, sampleRateMismatch };

inline IqFormatStatus ValidateIqFormat(unsigned int channels, unsigned int rate, unsigned int requestedRate) {
  if (channels != 2 || rate == 0) return IqFormatStatus::invalidFormat;
  if (rate != requestedRate) return IqFormatStatus::sampleRateMismatch;
  return IqFormatStatus::valid;
}

// WASAPI integer PCM is little endian; valid bits are left aligned in the
// container. Keep the most significant signed 16 bits without changing time
// or channel order. Reject a partial stereo frame rather than shifting I/Q.
inline bool IqPcm16(const uint8_t* data, size_t bytes, unsigned int sampleBytes,
                    bool silent, std::vector<uint8_t>& output) {
  if (sampleBytes < 2 || sampleBytes > 4 || bytes % (sampleBytes * 2) != 0 || (!data && !silent)) return false;
  const size_t samples = bytes / sampleBytes;
  output.assign(samples * 2, 0);
  if (silent) return true;
  for (size_t i = 0; i < samples; ++i) {
    output[i * 2] = data[i * sampleBytes + sampleBytes - 2];
    output[i * 2 + 1] = data[i * sampleBytes + sampleBytes - 1];
  }
  return true;
}

}  // namespace record_windows
