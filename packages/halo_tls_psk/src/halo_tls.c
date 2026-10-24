// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
#include "halo_tls.h"
#include <stdlib.h>
#include <string.h>
#include "mbedtls/ssl.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/platform_util.h"

#if defined(_MSC_VER)
// Retain the Windows entropy dependency when this shim is linked statically.
#pragma comment(lib, "bcrypt.lib")
#endif

#define BUFFER_LIMIT (64 * 1024)
typedef struct { uint8_t data[BUFFER_LIMIT]; size_t offset, length; } Buffer;
struct HaloTls {
    mbedtls_ssl_context ssl;
    mbedtls_ssl_config config;
    mbedtls_entropy_context entropy;
    mbedtls_ctr_drbg_context random;
    Buffer incoming, outgoing;
};

static int append(Buffer *buffer, const uint8_t *bytes, size_t size) {
    if (size > BUFFER_LIMIT - buffer->length) return -1;
    if (buffer->offset + buffer->length + size > BUFFER_LIMIT) {
        memmove(buffer->data, buffer->data + buffer->offset, buffer->length);
        buffer->offset = 0;
    }
    memcpy(buffer->data + buffer->offset + buffer->length, bytes, size);
    buffer->length += size;
    return (int)size;
}

static int take(Buffer *buffer, uint8_t *bytes, size_t size) {
    if (size > buffer->length) size = buffer->length;
    memcpy(bytes, buffer->data + buffer->offset, size);
    buffer->offset += size;
    buffer->length -= size;
    if (!buffer->length) buffer->offset = 0;
    return (int)size;
}

static int receive(void *opaque, unsigned char *bytes, size_t size) {
    HaloTls *tls = opaque;
    if (!tls->incoming.length) return MBEDTLS_ERR_SSL_WANT_READ;
    return take(&tls->incoming, bytes, size);
}

static int send_bytes(void *opaque, const unsigned char *bytes, size_t size) {
    HaloTls *tls = opaque;
    int count = append(&tls->outgoing, bytes, size);
    return count < 0 ? MBEDTLS_ERR_SSL_WANT_WRITE : count;
}

static int result(int code) {
    if (code == MBEDTLS_ERR_SSL_WANT_READ) return -1;
    if (code == MBEDTLS_ERR_SSL_WANT_WRITE) return -2;
    if (code == MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY) return -3;
    return code < 0 ? -4 : code;
}

HaloTls *halo_tls_new(const uint8_t *psk, size_t psk_len, const uint8_t *identity, size_t identity_len) {
    if (!psk || psk_len == 0 || psk_len > 256 || !identity || identity_len > 128) return NULL;
    HaloTls *tls = calloc(1, sizeof(*tls));
    if (!tls) return NULL;
    mbedtls_ssl_init(&tls->ssl);
    mbedtls_ssl_config_init(&tls->config);
    mbedtls_entropy_init(&tls->entropy);
    mbedtls_ctr_drbg_init(&tls->random);
    const unsigned char personalization[] = "halo_tls_psk";
    if (mbedtls_ctr_drbg_seed(&tls->random, mbedtls_entropy_func, &tls->entropy, personalization, sizeof(personalization) - 1)) goto fail;
    if (mbedtls_ssl_config_defaults(&tls->config, MBEDTLS_SSL_IS_CLIENT, MBEDTLS_SSL_TRANSPORT_STREAM, MBEDTLS_SSL_PRESET_DEFAULT)) goto fail;
    static const int suites[] = {
        MBEDTLS_TLS_ECDHE_PSK_WITH_CHACHA20_POLY1305_SHA256,
        MBEDTLS_TLS_ECDHE_PSK_WITH_AES_256_CBC_SHA384,
        0
    };
    mbedtls_ssl_conf_min_tls_version(&tls->config, MBEDTLS_SSL_VERSION_TLS1_2);
    mbedtls_ssl_conf_max_tls_version(&tls->config, MBEDTLS_SSL_VERSION_TLS1_2);
    mbedtls_ssl_conf_ciphersuites(&tls->config, suites);
    mbedtls_ssl_conf_rng(&tls->config, mbedtls_ctr_drbg_random, &tls->random);
    if (mbedtls_ssl_conf_psk(&tls->config, psk, psk_len, identity, identity_len)) goto fail;
    if (mbedtls_ssl_setup(&tls->ssl, &tls->config)) goto fail;
    mbedtls_ssl_set_bio(&tls->ssl, tls, send_bytes, receive, NULL);
    return tls;
fail:
    halo_tls_free(tls);
    return NULL;
}

void halo_tls_free(HaloTls *tls) {
    if (!tls) return;
    mbedtls_ssl_free(&tls->ssl);
    mbedtls_ssl_config_free(&tls->config);
    mbedtls_ctr_drbg_free(&tls->random);
    mbedtls_entropy_free(&tls->entropy);
    mbedtls_platform_zeroize(tls, sizeof(*tls));
    free(tls);
}

int halo_tls_feed(HaloTls *tls, const uint8_t *bytes, size_t size) { return append(&tls->incoming, bytes, size); }
int halo_tls_drain(HaloTls *tls, uint8_t *bytes, size_t size) { return take(&tls->outgoing, bytes, size); }
int halo_tls_handshake(HaloTls *tls) { return result(mbedtls_ssl_handshake(&tls->ssl)); }
int halo_tls_read(HaloTls *tls, uint8_t *bytes, size_t size) { return result(mbedtls_ssl_read(&tls->ssl, bytes, size)); }
int halo_tls_write(HaloTls *tls, const uint8_t *bytes, size_t size) { return result(mbedtls_ssl_write(&tls->ssl, bytes, size)); }
int halo_tls_close_notify(HaloTls *tls) { return result(mbedtls_ssl_close_notify(&tls->ssl)); }
