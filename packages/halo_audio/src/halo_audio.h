// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Flat C API over miniaudio for the Dart FFI binding: list the sound devices,
// play a file to one, record from one into a WAV file.
//
// No miniaudio type crosses this boundary. A device is named by its id
// written as hex (the bytes of miniaudio's per-backend ma_device_id union,
// trailing zeros trimmed), an output and a recorder are opaque pointers, and
// every string is NUL-terminated UTF-8.
//
// Single-threaded from the caller's side: every function here is called from
// the Dart isolate that owns the binding. The calls that cross threads are
// an output's two callbacks, which miniaudio's threads make — the binding
// passes NativeCallable.listeners, which only post a message.

#ifndef HALO_AUDIO_H
#define HALO_AUDIO_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define HALO_AUDIO_API __declspec(dllexport)
#else
// `used` as well as `visibility`: on macOS the sources link STATICALLY into
// the app executable, nothing references these at link time (Dart resolves
// them at runtime through DynamicLibrary.process()), and a Release build's
// dead-stripping would otherwise discard every one. See halo_qjs.h.
#define HALO_AUDIO_API __attribute__((used, visibility("default")))
#endif

typedef struct HaloAudioOutput HaloAudioOutput;
typedef struct HaloAudioRecorder HaloAudioRecorder;

/// Called from the audio thread, and only posts: when an output has handed
/// its device the last of a file (the device still sounding the few tens of
/// milliseconds it holds, which the caller's tail covers), and when an
/// output's device stopped without being asked to — unplugged.
typedef void (*HaloAudioEndFn)(int64_t token);

/// [HaloAudioEndFn] for a file played into an output, with [failed] 1 when
/// the file stopped short because it could not be read further, else 0.
typedef void (*HaloAudioPlayedFn)(int64_t token, int32_t failed);

/// Selects miniaudio's null backend — real-time pacing, no hardware — for
/// every call after it. Only before the first call that touches a device;
/// the tests use it. Returns 0, or -1 when a context already exists.
HALO_AUDIO_API int halo_audio_use_null_backend(void);

/// Reads the system's devices — capture when [capture] is non-zero,
/// playback otherwise — into the list the three accessors below read.
/// Returns how many, or -1 when no audio backend could be opened.
HALO_AUDIO_API int halo_audio_enumerate(int capture);
HALO_AUDIO_API const char* halo_audio_device_id(int capture, int index);
HALO_AUDIO_API const char* halo_audio_device_name(int capture, int index);
HALO_AUDIO_API int halo_audio_device_is_default(int capture, int index);

/// The length of the audio file at [path] in milliseconds, or -1 when it
/// cannot be decoded (WAV, FLAC and MP3 can).
HALO_AUDIO_API int64_t halo_audio_file_length_ms(const char* path);

/// Decodes the audio file at [path] to interleaved 32-bit float samples at
/// [rate] Hz and [channels] channels (a mono file copied to each), into a
/// buffer at [*out] the caller frees with halo_audio_free. The number of
/// frames, or -1 with the reason written to [err].
HALO_AUDIO_API int64_t halo_audio_decode(const char* path, int rate, int channels, float** out, char* err, int err_len);
HALO_AUDIO_API void halo_audio_free(void* buffer);

/// Writes the audio file at [from] to [to] as a 16-bit WAV of the same
/// channels and rate, scaled so its loudest sample reaches [peak] (0..1) —
/// never made quieter, and made at most [max_gain] times louder. With
/// [trim_above_floor_db] above 0, the start and the end are cut to the 10 ms
/// stretches whose RMS is that many dB above the recording's noise floor
/// (its quietest tenth) — or within [trim_below_loudest_db] of its loudest
/// stretch, when that is the lower bar — in runs of at least [min_sound_ms],
/// keeping [lead_ms] before and [tail_ms] after, faded in and out, the last
/// [cut_end_ms] dropped first. 0, or -1 with the reason written to [err].
HALO_AUDIO_API int halo_audio_normalize(const char* from, const char* to, float peak, float max_gain, float trim_above_floor_db, float trim_below_loudest_db,
                                        int min_sound_ms, int lead_ms, int tail_ms, int cut_end_ms, char* err, int err_len);

/// Opens the device [device_id] (NULL or "" for the system default) and
/// starts it playing silence, until a file is played into it. Kept open
/// between files, so a play costs a file open and nothing more. [on_lost]
/// is called with [lost_token] if the device stops by itself. NULL on
/// failure, with the reason written to [err].
HALO_AUDIO_API HaloAudioOutput* halo_audio_output_open(const char* device_id, HaloAudioEndFn on_lost, int64_t lost_token, char* err, int err_len);

/// Whether [out]'s device is still running — false once it has gone away.
HALO_AUDIO_API int halo_audio_output_alive(HaloAudioOutput* out);

/// Plays [path] into [out], replacing whatever it was playing. [on_end] is
/// called with [token] when the file runs out, or breaks off where it could
/// not be read; the device plays silence after it. 0, or -1 with the reason
/// written to [err] when the file will not open.
HALO_AUDIO_API int halo_audio_output_play(HaloAudioOutput* out, const char* path, HaloAudioPlayedFn on_end, int64_t token, char* err, int err_len);

/// Silences [out] at once, its device left running.
HALO_AUDIO_API void halo_audio_output_stop(HaloAudioOutput* out);

/// Closes [out]'s device and frees it. Blocks until the audio thread is out
/// of its callback, so neither callback is called after.
HALO_AUDIO_API void halo_audio_output_close(HaloAudioOutput* out);

/// Starts recording from the device [device_id] (NULL or "" for the system
/// default) into a 16-bit mono 48 kHz WAV file at [path]. NULL on failure,
/// with the reason written to [err].
HALO_AUDIO_API HaloAudioRecorder* halo_audio_record(const char* path, const char* device_id, char* err, int err_len);

/// The loudest sample since the last call, 0..1 — what a level meter shows.
HALO_AUDIO_API float halo_audio_recorder_take_peak(HaloAudioRecorder* recorder);

/// Stops [recorder], finishes its file and frees it. 0, or -1 with the
/// reason written to [err] when the file holds only part of the recording:
/// a write to it failed, or the device stopped without being asked to —
/// unplugged.
HALO_AUDIO_API int halo_audio_recorder_free(HaloAudioRecorder* recorder, char* err, int err_len);

#ifdef __cplusplus
}
#endif

#endif
