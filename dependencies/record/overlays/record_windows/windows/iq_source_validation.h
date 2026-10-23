// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

#pragma once

#include <windows.h>
#include <audioclient.h>

#include "iq_pcm.h"

namespace record_windows {

constexpr HRESULT kIqDeviceUnavailable = MAKE_HRESULT(SEVERITY_ERROR, FACILITY_ITF, 0x620);
constexpr HRESULT kIqInvalidFormat = MAKE_HRESULT(SEVERITY_ERROR, FACILITY_ITF, 0x621);
constexpr HRESULT kIqSampleRateMismatch = MAKE_HRESULT(SEVERITY_ERROR, FACILITY_ITF, 0x622);
constexpr HRESULT kIqUnsupported = MAKE_HRESULT(SEVERITY_ERROR, FACILITY_ITF, 0x623);

inline HRESULT ValidateIqSource(unsigned int channels, unsigned int rate, unsigned int requestedRate) {
  switch (ValidateIqFormat(channels, rate, requestedRate)) {
    case IqFormatStatus::invalidFormat: return kIqInvalidFormat;
    case IqFormatStatus::sampleRateMismatch: return kIqSampleRateMismatch;
    default: return S_OK;
  }
}

inline const char* IqErrorMessage(HRESULT hr) {
  if (hr == kIqDeviceUnavailable || hr == AUDCLNT_E_DEVICE_INVALIDATED ||
      hr == AUDCLNT_E_DEVICE_IN_USE || hr == AUDCLNT_E_SERVICE_NOT_RUNNING ||
      hr == HRESULT_FROM_WIN32(ERROR_NOT_FOUND)) return "iq_audio_device_unavailable";
  if (hr == kIqInvalidFormat || hr == AUDCLNT_E_UNSUPPORTED_FORMAT) return "iq_audio_invalid_format";
  if (hr == kIqSampleRateMismatch) return "iq_audio_sample_rate_mismatch";
  if (hr == kIqUnsupported || hr == AUDCLNT_E_EXCLUSIVE_MODE_NOT_ALLOWED) return "iq_audio_unsupported";
  if (hr == E_ACCESSDENIED) return "iq_audio_permission_denied";
  return nullptr;
}

}  // namespace record_windows
