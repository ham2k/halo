// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

// Exercise the private production callback without a wall clock or a test
// symbol in the shared library.
#include "../src/halo_audio.c"

#include <assert.h>

static void render(HaloAudioOutput* tone, float* samples, ma_uint32 frames) {
  // miniaudio's callback receives a zeroed output buffer.
  memset(samples, 0, frames * sizeof(*samples));
  sidetone_callback(&tone->device, samples, NULL, frames);
}

static float peak(const float* samples, ma_uint32 frames) {
  float level = 0;
  for (ma_uint32 i = 0; i < frames; i++) {
    level = fmaxf(level, fabsf(samples[i]));
  }
  return level;
}

static void check_waveform(ma_uint32 sample_rate) {
  HaloAudioOutput tone = {0};
  tone.device.pUserData = &tone;
  tone.device.sampleRate = sample_rate;
  float silence[17];
  render(&tone, silence, 17);
  assert(peak(silence, 17) == 0);

  // A key-down must produce tone within the first millisecond rendered by
  // the callback, while the envelope is still rising. Neither callback
  // boundaries nor a change in block size should reset it.
  float mark[240];
  halo_audio_sidetone_set(&tone, 600);
  render(&tone, mark, 64);
  render(&tone, mark + 64, 31);
  render(&tone, mark + 95, 145);
  assert(peak(mark, sample_rate / 1000) > 0.005f);
  const ma_uint32 half_period = sample_rate / (2 * 600);
  assert(mark[half_period - 1] > 0);
  assert(mark[half_period + 1] < 0);
  assert(peak(mark, 64) < 0.05f);
  assert(peak(mark + 160, 80) > 0.095f);

  float space[192];
  halo_audio_sidetone_set(&tone, 0);
  render(&tone, space, 64);
  render(&tone, space + 64, 53);
  render(&tone, space + 117, 75);
  // Smooth release, then silence after the 3 ms envelope.
  assert(peak(space, 48) > 0.05f);
  const ma_uint32 release_frames = (sample_rate * 3 + 999) / 1000;
  assert(peak(space + release_frames, 192 - release_frames) < 0.00001f);
  render(&tone, silence, 17);
  assert(peak(silence, 17) == 0);
}

int main(void) {
  assert(halo_audio_use_null_backend() == 0);
  char error[256] = {0};
  HaloAudioOutput* stream = halo_audio_sidetone_open(error, sizeof(error));
  if (stream == NULL) {
    fprintf(stderr, "opening null sidetone: %s\n", error);
    return 1;
  }
  // The real open path must bypass miniaudio's fixed-size staging buffer
  // without dropping zero-fill while the oscillator is idle.
  assert(stream->device.noFixedSizedCallback);
  assert(!stream->device.noPreSilencedOutputBuffer);
  assert(stream->device.sampleRate == stream->device.playback.internalSampleRate);
  halo_audio_output_close(stream);

  check_waveform(44100);
  check_waveform(48000);
  return 0;
}
