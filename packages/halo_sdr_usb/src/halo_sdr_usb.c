// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// See halo_sdr_usb.h. The vendor libraries call back on threads of their own
// with blocks of samples; each block goes into the device's ring under its
// lock, and the app copies out only the windows it draws.
//
// Built without HALO_SDR_USB_NO_USB, the Airspy libraries are compiled in
// alongside (src/airspy, src/airspyhf) and link libusb. Without it — a Linux
// build machine with no libusb to link — every kind reports itself
// unavailable rather than the build failing.

#include "halo_sdr_usb.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <pthread.h>

#ifndef HALO_SDR_USB_NO_USB
#include "airspy/airspy.h"
#include "airspyhf/airspyhf.h"
#endif

#include "sdrplay.h"

/// Complex samples the ring holds: a fifth of a second at 10 MS/s, the
/// fastest receiver here, so a reader polling twenty times a second never
/// finds what it asked for overwritten.
#define HSU_RING (1 << 21)

#define HSU_MAX_RATES 16

struct hsu_device {
  int32_t kind;
  pthread_mutex_t lock;
  float* ring;
  uint64_t written;

  uint32_t rates[HSU_MAX_RATES];
  int32_t rate_count;
  uint32_t rate;
  uint64_t min_hz;
  uint64_t max_hz;

  /// The vendor library's own handle.
  void* handle;

#ifdef HALO_SDR_USB_TEST_SOURCE
  pthread_t test_thread;
  volatile int test_running;
  int32_t test_offset;
#endif
};

static void put_error(char* error, int32_t size, const char* message) {
  if (error == NULL || size <= 0) return;
  snprintf(error, (size_t)size, "%s", message);
}

static hsu_device* device_new(int32_t kind) {
  hsu_device* d = (hsu_device*)calloc(1, sizeof(hsu_device));
  if (d == NULL) return NULL;
  d->ring = (float*)calloc((size_t)HSU_RING * 2, sizeof(float));
  if (d->ring == NULL) {
    free(d);
    return NULL;
  }
  d->kind = kind;
  pthread_mutex_init(&d->lock, NULL);
  return d;
}

static void device_free(hsu_device* d) {
  pthread_mutex_destroy(&d->lock);
  free(d->ring);
  free(d);
}

/// [count] complex samples, interleaved, into the ring. Called on a vendor
/// library's thread.
void hsu_ring_write(hsu_device* d, const float* iq, int32_t count) {
  if (count <= 0) return;
  pthread_mutex_lock(&d->lock);
  if (count > HSU_RING) {
    // Only the newest fit; the rest are counted as written and lost.
    iq += (size_t)(count - HSU_RING) * 2;
    d->written += (uint64_t)(count - HSU_RING);
    count = HSU_RING;
  }
  uint32_t at = (uint32_t)(d->written % HSU_RING);
  int32_t first = count < (int32_t)(HSU_RING - at) ? count : (int32_t)(HSU_RING - at);
  memcpy(d->ring + (size_t)at * 2, iq, (size_t)first * 2 * sizeof(float));
  if (count > first) memcpy(d->ring, iq + (size_t)first * 2, (size_t)(count - first) * 2 * sizeof(float));
  // Counted after the copy: a reader never sees an index whose samples are
  // not all there.
  d->written += (uint64_t)count;
  pthread_mutex_unlock(&d->lock);
}

/// Separate 16-bit I and Q arrays — SDRplay's — scaled to ±1 and
/// interleaved into the ring.
void hsu_ring_write_i16(hsu_device* d, const int16_t* xi, const int16_t* xq, int32_t count) {
  float block[2 * 1024];
  while (count > 0) {
    int32_t n = count < 1024 ? count : 1024;
    for (int32_t i = 0; i < n; i++) {
      block[2 * i] = xi[i] / 32768.0f;
      block[2 * i + 1] = xq[i] / 32768.0f;
    }
    hsu_ring_write(d, block, n);
    xi += n;
    xq += n;
    count -= n;
  }
}

// ---------------------------------------------------------------------------
// Airspy R2 / Mini

#ifndef HALO_SDR_USB_NO_USB

static void sort_rates(hsu_device* d) {
  for (int32_t i = 1; i < d->rate_count; i++) {
    uint32_t v = d->rates[i];
    int32_t j = i - 1;
    while (j >= 0 && d->rates[j] > v) {
      d->rates[j + 1] = d->rates[j];
      j--;
    }
    d->rates[j + 1] = v;
  }
}

static int airspy_block(airspy_transfer* transfer) {
  hsu_ring_write((hsu_device*)transfer->ctx, (const float*)transfer->samples, transfer->sample_count);
  return 0;
}

/// An Airspy's serial number, which it prints in hex; 0 for none given.
/// Returns -1 for one that is not all hex digits: read as far as it goes, a
/// typo would come out as 0, and 0 opens whichever receiver is found first.
static int hex_serial(const char* serial, uint64_t* out) {
  *out = 0;
  if (serial == NULL || serial[0] == 0) return 0;
  if (serial[0] == '0' && (serial[1] == 'x' || serial[1] == 'X')) serial += 2;
  char* end = NULL;
  uint64_t value = strtoull(serial, &end, 16);
  if (end == serial || *end != 0 || value == 0) return -1;
  *out = value;
  return 0;
}

static hsu_device* airspy_open_device(uint64_t serial, char* error, int32_t error_size) {
  struct airspy_device* dev = NULL;
  int r = serial != 0 ? airspy_open_sn(&dev, serial) : airspy_open(&dev);
  if (r != AIRSPY_SUCCESS) {
    put_error(error, error_size, airspy_error_name((enum airspy_error)r));
    return NULL;
  }
  hsu_device* d = device_new(HSU_KIND_AIRSPY);
  if (d == NULL) {
    airspy_close(dev);
    put_error(error, error_size, "out of memory");
    return NULL;
  }
  d->handle = dev;
  airspy_set_sample_type(dev, AIRSPY_SAMPLE_FLOAT32_IQ);
  uint32_t count = 0;
  airspy_get_samplerates(dev, &count, 0);
  if (count > HSU_MAX_RATES) count = HSU_MAX_RATES;
  if (count > 0 && airspy_get_samplerates(dev, d->rates, count) == AIRSPY_SUCCESS) d->rate_count = (int32_t)count;
  sort_rates(d);
  d->min_hz = 24000000ULL;
  d->max_hz = 1800000000ULL;
  return d;
}

// ---------------------------------------------------------------------------
// Airspy HF+ (Dual Port, Discovery, Ranger)

static int airspyhf_block(airspyhf_transfer_t* transfer) {
  hsu_ring_write((hsu_device*)transfer->ctx, (const float*)transfer->samples, transfer->sample_count);
  return 0;
}

static hsu_device* airspyhf_open_device(uint64_t serial, char* error, int32_t error_size) {
  airspyhf_device_t* dev = NULL;
  int r = serial != 0 ? airspyhf_open_sn(&dev, serial) : airspyhf_open(&dev);
  if (r != AIRSPYHF_SUCCESS) {
    put_error(error, error_size, "no Airspy HF+ could be opened");
    return NULL;
  }
  hsu_device* d = device_new(HSU_KIND_AIRSPYHF);
  if (d == NULL) {
    airspyhf_close(dev);
    put_error(error, error_size, "out of memory");
    return NULL;
  }
  d->handle = dev;
  uint32_t count = 0;
  airspyhf_get_samplerates(dev, &count, 0);
  if (count > HSU_MAX_RATES) count = HSU_MAX_RATES;
  if (count > 0 && airspyhf_get_samplerates(dev, d->rates, count) == AIRSPYHF_SUCCESS) d->rate_count = (int32_t)count;
  sort_rates(d);
  // Its HF and VHF ports together; 31-60 MHz between them hears nothing.
  d->min_hz = 9000ULL;
  d->max_hz = 260000000ULL;
  airspyhf_set_hf_agc(dev, 1);
  return d;
}

#endif

// ---------------------------------------------------------------------------
// A tone, for the binding's own tests

#ifdef HALO_SDR_USB_TEST_SOURCE

#if defined(_WIN32)
#include <windows.h>
static void test_sleep_ms(int ms) { Sleep((DWORD)ms); }
#else
#include <unistd.h>
static void test_sleep_ms(int ms) { usleep((useconds_t)ms * 1000); }
#endif

static void* test_tone(void* arg) {
  hsu_device* d = (hsu_device*)arg;
  float block[2 * 1024];
  double phase = 0;
  const double step = 2 * 3.14159265358979323846 * d->test_offset / (double)d->rate;
  while (d->test_running) {
    // A millisecond's worth at a time, roughly in real time.
    int32_t n = (int32_t)(d->rate / 1000);
    if (n > 1024) n = 1024;
    for (int32_t i = 0; i < n; i++) {
      block[2 * i] = (float)cos(phase);
      block[2 * i + 1] = (float)sin(phase);
      phase += step;
    }
    hsu_ring_write(d, block, n);
    test_sleep_ms(1);
  }
  return NULL;
}

HSU_EXPORT hsu_device* hsu_open_test_tone(uint32_t rate, int32_t offset_hz) {
  hsu_device* d = device_new(0);
  if (d == NULL) return NULL;
  d->rates[0] = rate;
  d->rate_count = 1;
  d->rate = rate;
  d->min_hz = 0;
  d->max_hz = 6000000000ULL;
  d->test_offset = offset_hz;
  return d;
}

#endif

// ---------------------------------------------------------------------------
// The surface

HSU_EXPORT int32_t hsu_available(int32_t kind) {
  switch (kind) {
#ifndef HALO_SDR_USB_NO_USB
    case HSU_KIND_AIRSPY:
    case HSU_KIND_AIRSPYHF:
      return 1;
#endif
    case HSU_KIND_SDRPLAY:
      return hsu_sdrplay_available();
    default:
      return 0;
  }
}

HSU_EXPORT hsu_device* hsu_open(int32_t kind, const char* serial, char* error, int32_t error_size) {
  put_error(error, error_size, "");
  hsu_device* d = NULL;
  switch (kind) {
#ifndef HALO_SDR_USB_NO_USB
    case HSU_KIND_AIRSPY:
    case HSU_KIND_AIRSPYHF: {
      uint64_t number;
      if (hex_serial(serial, &number) != 0) {
        put_error(error, error_size, "the serial number is not hexadecimal, as the receiver prints it");
        return NULL;
      }
      d = kind == HSU_KIND_AIRSPY ? airspy_open_device(number, error, error_size) : airspyhf_open_device(number, error, error_size);
      break;
    }
#endif
    case HSU_KIND_SDRPLAY: {
      d = device_new(HSU_KIND_SDRPLAY);
      if (d == NULL) {
        put_error(error, error_size, "out of memory");
        return NULL;
      }
      if (hsu_sdrplay_open(d, serial, d->rates, &d->rate_count, &d->min_hz, &d->max_hz, &d->handle, error, error_size) != 0) {
        device_free(d);
        return NULL;
      }
      break;
    }
    default:
      put_error(error, error_size, "this receiver cannot be opened in this build");
      return NULL;
  }
  if (d != NULL && d->rate_count > 0) d->rate = d->rates[0];
  return d;
}

HSU_EXPORT void hsu_close(hsu_device* d) {
  if (d == NULL) return;
  hsu_stop(d);
  switch (d->kind) {
#ifndef HALO_SDR_USB_NO_USB
    case HSU_KIND_AIRSPY:
      airspy_close((struct airspy_device*)d->handle);
      break;
    case HSU_KIND_AIRSPYHF:
      airspyhf_close((airspyhf_device_t*)d->handle);
      break;
#endif
    case HSU_KIND_SDRPLAY:
      hsu_sdrplay_close(d->handle);
      break;
    default:
      break;
  }
  device_free(d);
}

HSU_EXPORT int32_t hsu_sample_rates(hsu_device* d, uint32_t* rates, int32_t capacity) {
  for (int32_t i = 0; i < d->rate_count && i < capacity; i++) rates[i] = d->rates[i];
  return d->rate_count;
}

HSU_EXPORT uint64_t hsu_min_frequency(hsu_device* d) { return d->min_hz; }

HSU_EXPORT uint64_t hsu_max_frequency(hsu_device* d) { return d->max_hz; }

HSU_EXPORT int32_t hsu_set_sample_rate(hsu_device* d, uint32_t rate) {
  // SDRplay's API changes it on a running stream; the Airspy libraries are
  // given it between streams, as their own tools do.
  int32_t restart = d->kind != HSU_KIND_SDRPLAY && hsu_streaming(d) == HSU_STREAMING;
  if (restart) hsu_stop(d);
  int32_t r = 0;
  switch (d->kind) {
#ifndef HALO_SDR_USB_NO_USB
    case HSU_KIND_AIRSPY:
      r = airspy_set_samplerate((struct airspy_device*)d->handle, rate);
      break;
    case HSU_KIND_AIRSPYHF:
      r = airspyhf_set_samplerate((airspyhf_device_t*)d->handle, rate);
      break;
#endif
    case HSU_KIND_SDRPLAY:
      r = hsu_sdrplay_set_sample_rate(d->handle, rate);
      break;
    default:
      break;
  }
  if (r == 0) d->rate = rate;
  if (restart) hsu_start(d);
  return r;
}

HSU_EXPORT int32_t hsu_set_frequency(hsu_device* d, uint64_t hz) {
  switch (d->kind) {
#ifndef HALO_SDR_USB_NO_USB
    case HSU_KIND_AIRSPY:
      return airspy_set_freq((struct airspy_device*)d->handle, (uint32_t)hz);
    case HSU_KIND_AIRSPYHF:
      return airspyhf_set_freq((airspyhf_device_t*)d->handle, (uint32_t)hz);
#endif
    case HSU_KIND_SDRPLAY:
      return hsu_sdrplay_set_frequency(d->handle, hz);
    default:
      return 0;
  }
}

HSU_EXPORT int32_t hsu_set_gain(hsu_device* d, int32_t step) {
  switch (d->kind) {
#ifndef HALO_SDR_USB_NO_USB
    case HSU_KIND_AIRSPY: {
      struct airspy_device* dev = (struct airspy_device*)d->handle;
      if (step < 0) {
        airspy_set_lna_agc(dev, 1);
        return airspy_set_mixer_agc(dev, 1);
      }
      // The linearity preset sets all three stages at once, from 0 to 21.
      return airspy_set_linearity_gain(dev, (uint8_t)(step > 21 ? 21 : step));
    }
    case HSU_KIND_AIRSPYHF:
      // Its AGC is the only gain it is given: an HF front end that clips on
      // a strong signal is worse than one a few dB down.
      return 0;
#endif
    case HSU_KIND_SDRPLAY:
      return hsu_sdrplay_set_gain(d->handle, step);
    default:
      return 0;
  }
}

HSU_EXPORT int32_t hsu_start(hsu_device* d) {
  switch (d->kind) {
#ifndef HALO_SDR_USB_NO_USB
    case HSU_KIND_AIRSPY:
      return airspy_start_rx((struct airspy_device*)d->handle, airspy_block, d);
    case HSU_KIND_AIRSPYHF:
      return airspyhf_start((airspyhf_device_t*)d->handle, airspyhf_block, d);
#endif
    case HSU_KIND_SDRPLAY:
      return hsu_sdrplay_start(d->handle, d);
#ifdef HALO_SDR_USB_TEST_SOURCE
    case 0:
      if (d->test_running) return 0;
      d->test_running = 1;
      return pthread_create(&d->test_thread, NULL, test_tone, d);
#endif
    default:
      return 0;
  }
}

HSU_EXPORT int32_t hsu_stop(hsu_device* d) {
  if (hsu_streaming(d) == HSU_STOPPED) return 0;
  switch (d->kind) {
#ifndef HALO_SDR_USB_NO_USB
    case HSU_KIND_AIRSPY:
      return airspy_stop_rx((struct airspy_device*)d->handle);
    case HSU_KIND_AIRSPYHF:
      return airspyhf_stop((airspyhf_device_t*)d->handle);
#endif
    case HSU_KIND_SDRPLAY:
      return hsu_sdrplay_stop(d->handle);
#ifdef HALO_SDR_USB_TEST_SOURCE
    case 0:
      d->test_running = 0;
      pthread_join(d->test_thread, NULL);
      return 0;
#endif
    default:
      return 0;
  }
}

HSU_EXPORT int32_t hsu_streaming(hsu_device* d) {
  switch (d->kind) {
#ifndef HALO_SDR_USB_NO_USB
    case HSU_KIND_AIRSPY:
      return airspy_is_streaming((struct airspy_device*)d->handle) == AIRSPY_TRUE ? HSU_STREAMING : HSU_STOPPED;
    case HSU_KIND_AIRSPYHF:
      return airspyhf_is_streaming((airspyhf_device_t*)d->handle) ? HSU_STREAMING : HSU_STOPPED;
#endif
    case HSU_KIND_SDRPLAY:
      return hsu_sdrplay_streaming(d->handle);
#ifdef HALO_SDR_USB_TEST_SOURCE
    case 0:
      return d->test_running ? HSU_STREAMING : HSU_STOPPED;
#endif
    default:
      return HSU_STOPPED;
  }
}

HSU_EXPORT uint64_t hsu_written(hsu_device* d) {
  pthread_mutex_lock(&d->lock);
  uint64_t written = d->written;
  pthread_mutex_unlock(&d->lock);
  return written;
}

HSU_EXPORT int32_t hsu_read(hsu_device* d, uint64_t from, int32_t count, float* out) {
  if (count <= 0) return 0;
  pthread_mutex_lock(&d->lock);
  uint64_t written = d->written;
  uint64_t oldest = written > HSU_RING ? written - HSU_RING : 0;
  if (from < oldest || from >= written) {
    pthread_mutex_unlock(&d->lock);
    return 0;
  }
  if ((uint64_t)count > written - from) count = (int32_t)(written - from);
  uint32_t at = (uint32_t)(from % HSU_RING);
  int32_t first = count < (int32_t)(HSU_RING - at) ? count : (int32_t)(HSU_RING - at);
  memcpy(out, d->ring + (size_t)at * 2, (size_t)first * 2 * sizeof(float));
  if (count > first) memcpy(out + (size_t)first * 2, d->ring, (size_t)(count - first) * 2 * sizeof(float));
  pthread_mutex_unlock(&d->lock);
  return count;
}

HSU_EXPORT int32_t hsu_capacity(hsu_device* d) {
  (void)d;
  return HSU_RING;
}
