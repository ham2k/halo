// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

#include "iq_source_validation.h"

#include <gtest/gtest.h>

namespace record_windows {

TEST(IqSource, RejectsMonoAndUnknownSourcesBeforeAnyUpmixing) {
  EXPECT_EQ(ValidateIqSource(1, 48000, 48000), kIqInvalidFormat);
  EXPECT_EQ(ValidateIqSource(0, 48000, 48000), kIqInvalidFormat);
  EXPECT_EQ(ValidateIqSource(4, 48000, 48000), kIqInvalidFormat);
  EXPECT_EQ(ValidateIqSource(2, 0, 48000), kIqInvalidFormat);
}

TEST(IqSource, DoesNotAdvertiseBandwidthCreatedByResampling) {
  EXPECT_EQ(ValidateIqSource(2, 48000, 192000), kIqSampleRateMismatch);
  EXPECT_EQ(ValidateIqSource(2, 96000, 48000), kIqSampleRateMismatch);
  for (auto rate : {48000u, 96000u, 192000u}) EXPECT_EQ(ValidateIqSource(2, rate, rate), S_OK);
}

TEST(IqSource, LockedMissingAndUnsupportedDevicesHaveStableReasons) {
  EXPECT_STREQ(IqErrorMessage(AUDCLNT_E_DEVICE_IN_USE), "iq_audio_device_unavailable");
  EXPECT_STREQ(IqErrorMessage(AUDCLNT_E_DEVICE_INVALIDATED), "iq_audio_device_unavailable");
  EXPECT_STREQ(IqErrorMessage(AUDCLNT_E_EXCLUSIVE_MODE_NOT_ALLOWED), "iq_audio_unsupported");
  EXPECT_STREQ(IqErrorMessage(E_ACCESSDENIED), "iq_audio_permission_denied");
}

}  // namespace record_windows
