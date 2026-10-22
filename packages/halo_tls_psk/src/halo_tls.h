// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
#ifndef HALO_TLS_H
#define HALO_TLS_H
#include <stddef.h>
#include <stdint.h>
#if defined(_WIN32)
#define HALO_TLS_API __declspec(dllexport)
#else
// Dart's native asset bindings resolve these exported symbols at runtime.
#define HALO_TLS_API __attribute__((used, visibility("default")))
#endif
#ifdef __cplusplus
extern "C" {
#endif
typedef struct HaloTls HaloTls;
// State calls: -1 needs encrypted input, -2 needs output drained, -3 peer
// close_notify, -4 protocol error. Read/write return a positive byte count.
// No pointers into Mbed TLS, callbacks, file descriptors or secrets escape.
HALO_TLS_API HaloTls *halo_tls_new(const uint8_t *psk, size_t psk_len, const uint8_t *identity, size_t identity_len);
HALO_TLS_API void halo_tls_free(HaloTls *tls);
HALO_TLS_API int halo_tls_feed(HaloTls *tls, const uint8_t *bytes, size_t size);
HALO_TLS_API int halo_tls_drain(HaloTls *tls, uint8_t *bytes, size_t size);
HALO_TLS_API int halo_tls_handshake(HaloTls *tls);
HALO_TLS_API int halo_tls_read(HaloTls *tls, uint8_t *bytes, size_t size);
HALO_TLS_API int halo_tls_write(HaloTls *tls, const uint8_t *bytes, size_t size);
HALO_TLS_API int halo_tls_close_notify(HaloTls *tls);
#ifdef __cplusplus
}
#endif
#endif
