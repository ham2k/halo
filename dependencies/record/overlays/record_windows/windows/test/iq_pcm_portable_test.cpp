// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

#include "../iq_pcm.h"
#include <iostream>

using namespace record_windows;

#define CHECK(condition) do { if (!(condition)) { std::cerr << "Failed at line " << __LINE__ << std::endl; return 1; } } while (false)

int main() {
  CHECK(ValidateIqFormat(1, 48000, 48000) == IqFormatStatus::invalidFormat);
  CHECK(ValidateIqFormat(4, 48000, 48000) == IqFormatStatus::invalidFormat);
  CHECK(ValidateIqFormat(2, 0, 48000) == IqFormatStatus::invalidFormat);
  CHECK(ValidateIqFormat(2, 48000, 192000) == IqFormatStatus::sampleRateMismatch);
  for (auto rate : {48000u, 96000u, 192000u}) CHECK(ValidateIqFormat(2, rate, rate) == IqFormatStatus::valid);
  const std::vector<uint8_t> expected = {0x34, 0x12, 0xcd, 0xab};
  std::vector<uint8_t> output;
  for (unsigned int width : {2u, 3u, 4u}) {
    std::vector<uint8_t> input(width * 2, 0xff);
    input[width - 2] = 0x34;
    input[width - 1] = 0x12;
    input[width * 2 - 2] = 0xcd;
    input[width * 2 - 1] = 0xab;
    CHECK(IqPcm16(input.data(), input.size(), width, false, output));
    CHECK(output == expected);
    CHECK(!IqPcm16(input.data(), input.size() - 1, width, false, output));
    CHECK(IqPcm16(nullptr, input.size(), width, true, output));
    CHECK(output == std::vector<uint8_t>(4, 0));
    CHECK(!IqPcm16(nullptr, input.size(), width, false, output));
  }
  CHECK(!IqPcm16(expected.data(), expected.size(), 1, false, output));
  return 0;
}
