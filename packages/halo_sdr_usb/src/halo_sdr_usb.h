// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A USB SDR receiver as the app sees one: open it, tune it, start and stop
// it, and read back the latest of what it sampled. Everything a vendor
// library does on its own threads ends in one ring of complex samples; the
// app reads from that ring at its own pace and never sees a callback, so no
// sample stream ever crosses into Dart.

#ifndef HALO_SDR_USB_H
#define HALO_SDR_USB_H

#include <stdint.h>

#if defined(_WIN32)
#define HSU_EXPORT __declspec(dllexport)
#else
#define HSU_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/// The receivers this opens. Values are part of the Dart binding.
enum {
  HSU_KIND_AIRSPY = 1,
  HSU_KIND_AIRSPYHF = 2,
  HSU_KIND_SDRPLAY = 3,
};

/// What [hsu_streaming] reports.
enum {
  HSU_STOPPED = 0,
  HSU_STREAMING = 1,
  /// The device stopped streaming without being asked: unplugged, or a USB
  /// error the vendor library gave up on.
  HSU_LOST = -1,
};

typedef struct hsu_device hsu_device;

/// 1 when this build can open [kind] on this machine, 0 when it cannot: no
/// USB support compiled in, or for SDRplay, no SDRplay API installed.
HSU_EXPORT int32_t hsu_available(int32_t kind);

/// Opens the receiver of [kind] with serial number [serial] — an Airspy's in
/// hex, an SDRplay's as it prints it — or the first one found when [serial]
/// is empty. Null on failure, with why in [error] (always terminated).
HSU_EXPORT hsu_device* hsu_open(int32_t kind, const char* serial, char* error, int32_t error_size);

/// Stops it if streaming, releases it, and frees [device].
HSU_EXPORT void hsu_close(hsu_device* device);

/// The sample rates it offers, in samples a second, as many as fit in
/// [rates]; the count it has, whether or not they all fit.
HSU_EXPORT int32_t hsu_sample_rates(hsu_device* device, uint32_t* rates, int32_t capacity);

/// The tunable range, in Hz.
HSU_EXPORT uint64_t hsu_min_frequency(hsu_device* device);
HSU_EXPORT uint64_t hsu_max_frequency(hsu_device* device);

/// 0 on success; a vendor library's own error code otherwise. A rate change
/// while streaming stops and restarts an Airspy's stream around it; an
/// SDRplay receiver takes it live.
HSU_EXPORT int32_t hsu_set_sample_rate(hsu_device* device, uint32_t rate);
HSU_EXPORT int32_t hsu_set_frequency(hsu_device* device, uint64_t hz);

/// The receiver's own gain step, or -1 for its automatic gain.
HSU_EXPORT int32_t hsu_set_gain(hsu_device* device, int32_t step);

HSU_EXPORT int32_t hsu_start(hsu_device* device);
HSU_EXPORT int32_t hsu_stop(hsu_device* device);

/// [HSU_STOPPED], [HSU_STREAMING] or [HSU_LOST].
HSU_EXPORT int32_t hsu_streaming(hsu_device* device);

/// How many complex samples have been written since it was opened — the
/// index one past the newest.
HSU_EXPORT uint64_t hsu_written(hsu_device* device);

/// Copies complex samples [from] .. [from] + [count] (absolute indexes, as
/// [hsu_written] counts them) into [out] as interleaved I/Q floats. Returns
/// how many it copied: fewer when [from] has been overwritten already, or
/// lies past the newest.
HSU_EXPORT int32_t hsu_read(hsu_device* device, uint64_t from, int32_t count, float* out);

/// The ring's size in complex samples: a reader more than this far behind
/// has lost what lies between.
HSU_EXPORT int32_t hsu_capacity(hsu_device* device);

#ifdef HALO_SDR_USB_TEST_SOURCE
/// A receiver that is a thread writing a tone at [offset_hz] from the
/// centre, at [rate] — for the binding's tests, which have no hardware.
/// Never compiled into the app.
HSU_EXPORT hsu_device* hsu_open_test_tone(uint32_t rate, int32_t offset_hz);
#endif

#ifdef __cplusplus
}
#endif

#endif
