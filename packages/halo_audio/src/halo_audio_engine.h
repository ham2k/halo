// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The live audio engine (docs/design/audio.md): endpoints that audio enters
// and leaves through, and routes between them, each route a clock bridge —
// a ring buffer whose reader resamples by a ratio steered to hold the
// buffer's depth, so two endpoints on different clocks never drain or flood
// it. Everything inside runs at 48 kHz, 32-bit float; an endpoint is mono or
// stereo, interleaved.
//
// Two threads per route and nothing shared beyond it: the source's thread
// writes the route's ring (a device callback, or whoever calls push), and
// the sink's thread reads it (a device callback, or whoever calls pull).
// Neither locks, allocates or calls out. Every other function here is the
// control side, called from one thread at a time — the Dart isolate that
// owns the engine. Push and pull may run on threads of their own while the
// control side works, except while it closes that same endpoint or frees
// the engine.

#ifndef HALO_AUDIO_ENGINE_H
#define HALO_AUDIO_ENGINE_H

#include <stdint.h>

#include "halo_audio.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct HaloAudioEngine HaloAudioEngine;

/// The engine's one rate.
#define HALO_AUDIO_ENGINE_RATE 48000

/// The route statistics [halo_audio_engine_route_stats] writes, in order.
#define HALO_AUDIO_ROUTE_STAT_DEPTH_MS 0     // the ring's depth, averaged over half a second
#define HALO_AUDIO_ROUTE_STAT_TARGET_MS 1    // the depth the bridge steers that average to
#define HALO_AUDIO_ROUTE_STAT_RATIO_PPM 2    // how much faster than nominal the reader consumes
#define HALO_AUDIO_ROUTE_STAT_UNDERRUNS 3    // times the reader found the ring empty
#define HALO_AUDIO_ROUTE_STAT_SKIPS 4        // times the reader cut a ring past its maximum back
#define HALO_AUDIO_ROUTE_STAT_DROPPED 5      // frames the writer found no room for
#define HALO_AUDIO_ROUTE_STAT_RUNNING 6      // 1 while the reader plays the ring, 0 while it fills it first
#define HALO_AUDIO_ROUTE_STAT_COUNT 7

HALO_AUDIO_API HaloAudioEngine* halo_audio_engine_new(void);

/// Closes every endpoint and frees the engine. Blocks until each device's
/// thread is out of its callback; push and pull must not be running.
HALO_AUDIO_API void halo_audio_engine_free(HaloAudioEngine* engine);

/// Opens the capture device [device_id] (NULL or "" for the system default)
/// as a source of [channels] (1 or 2) channels. [on_lost] is posted
/// [lost_token] when the device stops by itself — gone, or being moved to a
/// new default, which [halo_audio_engine_endpoint_alive] tells apart a
/// moment later. The endpoint's id, or -1 with the reason written to [err].
HALO_AUDIO_API int32_t halo_audio_engine_open_input(HaloAudioEngine* engine, const char* device_id, int channels, HaloAudioPort on_lost,
                                                    int64_t lost_token, char* err, int err_len);

/// Opens the playback device [device_id] as a sink; as for
/// [halo_audio_engine_open_input].
HALO_AUDIO_API int32_t halo_audio_engine_open_output(HaloAudioEngine* engine, const char* device_id, int channels, HaloAudioPort on_lost,
                                                     int64_t lost_token, char* err, int err_len);

/// A source fed by [halo_audio_engine_push]. The endpoint's id, or -1.
HALO_AUDIO_API int32_t halo_audio_engine_add_pushed(HaloAudioEngine* engine, int channels);

/// A sink drained by [halo_audio_engine_pull]. A [gated] sink starts with
/// its gate shut and passes nothing until [halo_audio_engine_set_gate]
/// opens it — what a radio's transmit audio is, so a microphone cannot
/// reach it between the sink's creation and the first key. The endpoint's
/// id, or -1.
HALO_AUDIO_API int32_t halo_audio_engine_add_pulled(HaloAudioEngine* engine, int channels, int gated);

/// Closes [endpoint] and every route to or from it. A device's is closed
/// before this returns. 0, or -1 for an id that is not open.
HALO_AUDIO_API int halo_audio_engine_close_endpoint(HaloAudioEngine* engine, int32_t endpoint);

/// A route from [source] to [sink] at unity gain. Its bridge fills to
/// [start_ms] before the sink hears it — and again after the ring runs dry —
/// and is cut back when it holds more than [max_ms] (ten seconds at most).
/// The route's id, or -1 when either end is not open, is the wrong way
/// round, or is the same.
HALO_AUDIO_API int32_t halo_audio_engine_connect(HaloAudioEngine* engine, int32_t source, int32_t sink, int start_ms, int max_ms);

/// Removes [route]. 0, or -1 for an id that is not connected.
HALO_AUDIO_API int halo_audio_engine_disconnect(HaloAudioEngine* engine, int32_t route);

/// Sets [route]'s gain into the sink's left and right channels (linear; a
/// mono sink hears their mean). Ramped over 5 ms. 0, or -1.
HALO_AUDIO_API int halo_audio_engine_set_gain(HaloAudioEngine* engine, int32_t route, float left, float right);

/// Opens or shuts [sink]'s gate, ramped over 5 ms. Opening drops whatever
/// its routes held while it was shut, so what was said before the key never
/// goes out after it. 0, or -1.
HALO_AUDIO_API int halo_audio_engine_set_gate(HaloAudioEngine* engine, int32_t sink, int open);

/// Writes [frames] interleaved frames into every route from the pushed
/// source [source]. One thread at a time per source. A route whose ring is
/// full drops what does not fit and counts it as DROPPED; nothing is to be
/// sent again. 0, or -1 for an id that is not a pushed source.
HALO_AUDIO_API int halo_audio_engine_push(HaloAudioEngine* engine, int32_t source, const float* samples, int frames);

/// Reads [frames] interleaved frames of the pulled sink [sink]'s mix into
/// [out]. One thread at a time per sink. 0, or -1 for an id that is not a
/// pulled sink.
HALO_AUDIO_API int halo_audio_engine_pull(HaloAudioEngine* engine, int32_t sink, float* out, int frames);

/// 1 while [endpoint] runs — a device started, or an endpoint that has
/// none — 0 for a device that has stopped, -1 for an id that is not open.
HALO_AUDIO_API int halo_audio_engine_endpoint_alive(HaloAudioEngine* engine, int32_t endpoint);

/// Writes [route]'s statistics into [out], HALO_AUDIO_ROUTE_STAT_COUNT of
/// them. 0, or -1.
HALO_AUDIO_API int halo_audio_engine_route_stats(HaloAudioEngine* engine, int32_t route, double* out);

// --- The network edge (halo_audio_net.c) -----------------------------------------

/// The sender statistics [halo_audio_engine_sender_stats] writes, in order.
#define HALO_AUDIO_SENDER_STAT_SENT 0         // packets sent
#define HALO_AUDIO_SENDER_STAT_REANCHORED 1   // times it fell so far behind it started again from now
#define HALO_AUDIO_SENDER_STAT_LATE_MAX_US 2  // the latest it woke past a packet's deadline
#define HALO_AUDIO_SENDER_STAT_LATE_MEAN_US 3 // how late it woke on average
#define HALO_AUDIO_SENDER_STAT_COUNT 4

/// A UDP socket bound to [port] (0 for any) on every IPv4 address, with a
/// receive thread of its own. The datagrams no endpoint claims are queued:
/// [on_datagrams] is posted [token] when the queue was empty and is not,
/// and [halo_audio_engine_socket_take] reads them. The socket's id, or -1
/// with the reason written to [err].
HALO_AUDIO_API int32_t halo_audio_engine_open_socket(HaloAudioEngine* engine, int port, HaloAudioPort on_datagrams, int64_t token, char* err,
                                                     int err_len);

/// The port [socket] is bound to, or -1.
HALO_AUDIO_API int halo_audio_engine_socket_port(HaloAudioEngine* engine, int32_t socket);

/// Sends [length] bytes to [host] (a numeric address) and [port] from
/// [socket]. 0, or -1.
HALO_AUDIO_API int halo_audio_engine_socket_send(HaloAudioEngine* engine, int32_t socket, const char* host, int port, const uint8_t* bytes,
                                                 int length);

/// Takes the oldest queued datagram into [out] (cut to [capacity] bytes),
/// and where it came from into [host] and [port]. Its length; 0 when the
/// queue is empty, after which the next datagram calls on_datagrams again;
/// -1 for a socket that is not open.
HALO_AUDIO_API int halo_audio_engine_socket_take(HaloAudioEngine* engine, int32_t socket, uint8_t* out, int capacity, char* host, int host_length,
                                                 int* port);

/// How many datagrams for Dart [socket] has dropped — longer than it
/// queues, or with its queue full — or -1.
HALO_AUDIO_API int halo_audio_engine_socket_dropped(HaloAudioEngine* engine, int32_t socket);

/// Closes [socket], every endpoint on it first. 0, or -1.
HALO_AUDIO_API int halo_audio_engine_close_socket(HaloAudioEngine* engine, int32_t socket);

/// A stereo source of a FlexRadio's `dax_rx` stream [stream_id]: the VITA-49
/// type 3 packets with that stream id arriving on [socket], at 24 kHz,
/// brought to the engine's rate. A packet the counter says was lost is
/// filled with the last one repeated, crossfaded in and out, 1.3 ms of each
/// packet held back for it. The endpoint's id, or -1.
HALO_AUDIO_API int32_t halo_audio_engine_add_flex_dax_rx(HaloAudioEngine* engine, int32_t socket, uint32_t stream_id);

/// A gated stereo sink sent from [socket] to [host]:[port] as a FlexRadio's
/// `dax_tx` stream [stream_id]: VITA-49 type 1 packets of 128 frames at
/// 24 kHz, one every 5.33 ms by a thread of its own, while
/// [halo_audio_engine_set_sending] says so — [ahead] packets of silence
/// first. The endpoint's id, or -1.
HALO_AUDIO_API int32_t halo_audio_engine_add_flex_dax_tx(HaloAudioEngine* engine, int32_t socket, const char* host, int port, uint32_t stream_id,
                                                         int ahead);

/// Starts or stops [endpoint]'s packets. A radio that transmits noise when
/// nothing arrives (a Flex on DAX) is sent them, silence or not, for as
/// long as it may be on the air. 0, or -1 for an id that is not a sender.
HALO_AUDIO_API int halo_audio_engine_set_sending(HaloAudioEngine* engine, int32_t endpoint, int sending);

/// The receiver statistics [halo_audio_engine_receiver_stats] writes.
#define HALO_AUDIO_RECEIVER_STAT_PACKETS 0  // packets received
#define HALO_AUDIO_RECEIVER_STAT_LOST 1     // packets the counter says never came
#define HALO_AUDIO_RECEIVER_STAT_COUNT 2

/// Writes a receiver's statistics into [out]. 0, or -1.
HALO_AUDIO_API int halo_audio_engine_receiver_stats(HaloAudioEngine* engine, int32_t endpoint, double* out);

/// Writes a sender's statistics into [out], HALO_AUDIO_SENDER_STAT_COUNT of
/// them. 0, or -1.
HALO_AUDIO_API int halo_audio_engine_sender_stats(HaloAudioEngine* engine, int32_t endpoint, double* out);

/// The loudest sample through [endpoint] since the last call, 0..1, or -1.
HALO_AUDIO_API float halo_audio_engine_take_peak(HaloAudioEngine* engine, int32_t endpoint);

#ifdef __cplusplus
}
#endif

#endif
