// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SDRplay's RSPs, through the API the operator installs with SDRplay's own
// software — loaded when first asked for, never shipped with the app.
// Internal to halo_sdr_usb.c: the app reaches it only through the hsu_*
// surface.

#ifndef HALO_SDR_USB_SDRPLAY_H
#define HALO_SDR_USB_SDRPLAY_H

#include <stdint.h>

#include "halo_sdr_usb.h"

/// Where both the vendor callbacks and the test source put their samples.
void hsu_ring_write(hsu_device* device, const float* iq, int32_t count);
void hsu_ring_write_i16(hsu_device* device, const int16_t* xi, const int16_t* xq, int32_t count);

/// 1 when an SDRplay API of a version this speaks loads, 0 otherwise —
/// always 0 on macOS, where a signed, sandboxed app may not load a library
/// it did not ship.
int32_t hsu_sdrplay_available(void);

/// Fills in what [hsu_open] needs about the receiver and the handle every
/// other call takes; 0 on success.
int32_t hsu_sdrplay_open(hsu_device* device, const char* serial, uint32_t* rates, int32_t* rate_count, uint64_t* min_hz, uint64_t* max_hz,
                         void** handle, char* error, int32_t error_size);
void hsu_sdrplay_close(void* handle);
int32_t hsu_sdrplay_set_sample_rate(void* handle, uint32_t rate);
int32_t hsu_sdrplay_set_frequency(void* handle, uint64_t hz);
int32_t hsu_sdrplay_set_gain(void* handle, int32_t step);
int32_t hsu_sdrplay_start(void* handle, hsu_device* device);
int32_t hsu_sdrplay_stop(void* handle);
int32_t hsu_sdrplay_streaming(void* handle);

#endif
