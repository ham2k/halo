// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The engine's network edge (docs/design/audio.md § 4): a UDP socket with a
// receive thread of its own, the endpoints whose packets it claims, and the
// paced senders that frame a sink's mix into packets. Included at the end of
// halo_audio.c after halo_audio_engine.c, whose types it extends.
//
// A socket's receive thread claims the datagrams of the streams it has been
// told about and queues every other one for Dart, which reads them as it
// would a RawDatagramSocket's: a radio sends its audio to the same port as
// the rest of its traffic.

#if defined(_WIN32)
typedef SOCKET net_fd;
#define NET_NO_FD INVALID_SOCKET
#define net_close closesocket
#else
#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>
#if defined(__APPLE__)
#include <mach/mach_time.h>
#endif
typedef int net_fd;
#define NET_NO_FD (-1)
#define net_close close
#endif

#define ENGINE_MAX_SOCKETS 16
#define NET_MAX_CLAIMS 16
// The datagrams queued for Dart: a FlexRadio's DAX IQ packet, which its
// spectrum is drawn from, is 4128 bytes, and at 192 kHz some 375 of them
// come each second, so a queue that drops a packet this size, or holds
// less than the second Dart can be held up for, leaves the spectrum blank.
#define NET_DATAGRAM_BYTES 8192
#define NET_QUEUE_SLOTS 512
// How long a receive waits before it looks whether it should stop.
#define NET_RECEIVE_POLL_MS 50

// --- The monotonic clock and sleeping to a deadline ---------------------------

static uint64_t mono_ns(void) {
#if defined(_WIN32)
  static LARGE_INTEGER frequency;
  if (frequency.QuadPart == 0) QueryPerformanceFrequency(&frequency);
  LARGE_INTEGER counter;
  QueryPerformanceCounter(&counter);
  return (uint64_t)((double)counter.QuadPart * 1e9 / (double)frequency.QuadPart);
#elif defined(__APPLE__)
  static mach_timebase_info_data_t timebase;
  if (timebase.denom == 0) mach_timebase_info(&timebase);
  return mach_absolute_time() * timebase.numer / timebase.denom;
#else
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
#endif
}

// Sleeps until the monotonic clock reads [deadline]. An absolute deadline,
// so a late wake-up does not push every later packet back with it.
static void sleep_until_ns(uint64_t deadline, void* timer) {
#if defined(_WIN32)
  uint64_t now = mono_ns();
  if (deadline <= now) return;
  LARGE_INTEGER due;
  due.QuadPart = -(LONGLONG)((deadline - now) / 100);
  if (timer != NULL && SetWaitableTimer((HANDLE)timer, &due, 0, NULL, NULL, FALSE)) {
    WaitForSingleObject((HANDLE)timer, INFINITE);
  } else {
    Sleep((DWORD)((deadline - now) / 1000000));
  }
#elif defined(__APPLE__)
  (void)timer;
  static mach_timebase_info_data_t timebase;
  if (timebase.denom == 0) mach_timebase_info(&timebase);
  mach_wait_until(deadline * timebase.denom / timebase.numer);
#else
  (void)timer;
  struct timespec ts;
  ts.tv_sec = (time_t)(deadline / 1000000000ull);
  ts.tv_nsec = (long)(deadline % 1000000000ull);
  while (clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &ts, NULL) != 0) {
  }
#endif
}

static void* new_sleep_timer(void) {
#if defined(_WIN32)
  // CREATE_WAITABLE_TIMER_HIGH_RESOLUTION, which older SDKs do not name.
  return (void*)CreateWaitableTimerExW(NULL, NULL, 0x00000002, TIMER_ALL_ACCESS);
#else
  return NULL;
#endif
}

static void free_sleep_timer(void* timer) {
#if defined(_WIN32)
  if (timer != NULL) CloseHandle((HANDLE)timer);
#else
  (void)timer;
#endif
}

// --- Half-band filters, for the 2:1 rate changes at an endpoint's edge ----------

// 47 taps of a Blackman-windowed half-band: flat through a voice's band,
// 70 dB down past the new Nyquist, half a millisecond of delay at 48 kHz.
#define HALFBAND_TAPS 47
static float g_halfband[HALFBAND_TAPS];
static int g_halfband_ready = 0;

static void halfband_design(void) {
  if (g_halfband_ready) return;
  const int mid = HALFBAND_TAPS / 2;
  const double pi = 3.14159265358979323846;
  for (int i = 0; i < HALFBAND_TAPS; i++) {
    int k = i - mid;
    double ideal = k == 0 ? 0.5 : sin(pi * k / 2.0) / (pi * k);
    double w = 0.42 - 0.5 * cos(2 * pi * i / (HALFBAND_TAPS - 1)) + 0.08 * cos(4 * pi * i / (HALFBAND_TAPS - 1));
    g_halfband[i] = (float)(ideal * w);
  }
  g_halfband_ready = 1;
}

typedef struct {
  float history[2][HALFBAND_TAPS];  // per channel, newest last
} HalfBand;

static float halfband_step(float* history, float in) {
  memmove(history, history + 1, sizeof(float) * (HALFBAND_TAPS - 1));
  history[HALFBAND_TAPS - 1] = in;
  float acc = 0;
  for (int i = 0; i < HALFBAND_TAPS; i++) acc += g_halfband[i] * history[i];
  return acc;
}

// [frames] interleaved frames of [channels] at half the rate into 2*[frames]
// at the full rate: a zero between each pair, filtered, doubled back to
// unity.
static void halfband_up(HalfBand* f, int channels, const float* in, int frames, float* out) {
  for (int i = 0; i < frames; i++) {
    for (int c = 0; c < channels; c++) {
      out[(2 * i) * channels + c] = 2 * halfband_step(f->history[c], in[i * channels + c]);
      out[(2 * i + 1) * channels + c] = 2 * halfband_step(f->history[c], 0);
    }
  }
}

// 2*[frames] interleaved frames at the full rate into [frames] at half.
static void halfband_down(HalfBand* f, int channels, const float* in, int frames, float* out) {
  for (int i = 0; i < frames; i++) {
    for (int c = 0; c < channels; c++) {
      out[i * channels + c] = halfband_step(f->history[c], in[(2 * i) * channels + c]);
      halfband_step(f->history[c], in[(2 * i + 1) * channels + c]);
    }
  }
}

// --- Big-endian words -------------------------------------------------------------

static uint32_t read_be32(const uint8_t* p) { return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3]; }

static void write_be32(uint8_t* p, uint32_t v) {
  p[0] = (uint8_t)(v >> 24);
  p[1] = (uint8_t)(v >> 16);
  p[2] = (uint8_t)(v >> 8);
  p[3] = (uint8_t)v;
}

static float read_be_float(const uint8_t* p) {
  uint32_t bits = read_be32(p);
  float v;
  memcpy(&v, &bits, sizeof(v));
  return v;
}

static void write_be_float(uint8_t* p, float v) {
  uint32_t bits;
  memcpy(&bits, &v, sizeof(bits));
  write_be32(p, bits);
}

// --- Sockets ------------------------------------------------------------------------

// VITA-49 as a FlexRadio's DAX audio carries it (docs/design/cat.md § The
// computer's voice keyer): 128 frames of 24 kHz stereo float32,
// big-endian, after a 28-byte header — the stream id, the class id
// 0x00001C2D/0x534C03E3, UTC seconds and a sample count. The radio's own
// audio is type 3; what it transmits must be type 1.
#define FLEX_DAX_FRAMES 128
#define FLEX_DAX_HEADER 28
#define FLEX_DAX_PACKET (FLEX_DAX_HEADER + FLEX_DAX_FRAMES * 2 * 4)

// How much of each received packet is held back to fade across a gap:
// 1.3 ms at 24 kHz.
#define DAX_HOLD_FRAMES 32
// How long a gap is filled with the last packet repeated (10.7 ms at
// 24 kHz), and how long the repeat then takes to fade to silence: a lost
// packet or two heard as the sound going on, a longer loss not as a buzz
// at the repeat's 4 ms period.
#define DAX_REPEAT_FRAMES 256
#define DAX_REPEAT_FADE_FRAMES 128

typedef struct {
  uint16_t length;
  uint16_t port;
  char host[INET6_ADDRSTRLEN];
  uint8_t data[NET_DATAGRAM_BYTES];
} QueuedDatagram;

typedef struct {
  uint32_t stream_id;
  Endpoint* endpoint;
} Claim;

typedef struct NetSocket {
  HaloAudioEngine* engine;
  int32_t id;
  net_fd fd;
  int port;
  ma_thread thread;
  int thread_running;
  volatile ma_uint32 stop;

  // The streams the receive thread hands to endpoints. Changed by the
  // control side and read by the receive thread under the lock: the thread
  // holds it while it pushes a claimed packet, so an endpoint taken off
  // this list is never pushed to again once the lock is released.
  ma_spinlock claims_lock;
  Claim claims[NET_MAX_CLAIMS];
  int claim_count;

  // Every other datagram, for Dart: the receive thread writes, the control
  // side reads.
  QueuedDatagram* queue;
  volatile ma_uint32 queue_write;
  volatile ma_uint32 queue_read;
  volatile ma_uint32 queue_dropped;
  volatile ma_uint32 notified;
  HaloAudioPort on_datagrams;
  int64_t token;

  // The address the control side last sent to, resolved once: a voice
  // keyer's message sends to the radio about 190 times a second, and only
  // the control side reads or writes these.
  char sent_host[64];
  int sent_port;
  struct sockaddr_storage sent_to;
  int sent_to_length;
} NetSocket;

// What a network endpoint carries beside an Endpoint's own fields.
typedef struct NetEndpoint {
  NetSocket* socket;
  uint32_t stream_id;
  HalfBand filter;

  // A receiver's: the packet counter last seen, and the end of the last
  // packet, held back until the next shows whether it may be heard as is
  // or must fade out into a gap.
  int seen;
  uint32_t last_count;
  int held;
  float tail[DAX_HOLD_FRAMES * 2];
  // The last packet as it came, repeated over a gap.
  float last[FLEX_DAX_FRAMES * 2];
  int last_frames;
  volatile ma_uint32 stat_packets;
  volatile ma_uint32 stat_lost;

  // A sender's.
  ma_thread thread;
  int thread_running;
  volatile ma_uint32 stop;
  volatile ma_uint32 sending;
  struct sockaddr_storage to;
  int to_length;
  int ahead;
  uint32_t count;
  uint64_t frames_sent;
  volatile ma_uint32 stat_sent;
  volatile ma_uint32 stat_reanchored;
  volatile ma_uint32 stat_late_max_us;
  volatile ma_uint32 stat_late_mean_us;  // f32
} NetEndpoint;

static int net_ready(void) {
#if defined(_WIN32)
  static int started = 0;
  if (!started) {
    WSADATA data;
    if (WSAStartup(MAKEWORD(2, 2), &data) != 0) return 0;
    started = 1;
  }
#endif
  return 1;
}

static NetSocket* find_socket(HaloAudioEngine* e, int32_t id) {
  for (int i = 0; i < ENGINE_MAX_SOCKETS; i++) {
    if (e->sockets[i] != NULL && e->sockets[i]->id == id) return e->sockets[i];
  }
  return NULL;
}

static void queue_datagram(NetSocket* s, const uint8_t* data, int length, const struct sockaddr_storage* from) {
  ma_uint32 w = s->queue_write;
  if (w - ma_atomic_load_32(&s->queue_read) >= NET_QUEUE_SLOTS || length > NET_DATAGRAM_BYTES) {
    ma_atomic_fetch_add_32(&s->queue_dropped, 1);
    return;
  }
  QueuedDatagram* slot_ = &s->queue[w % NET_QUEUE_SLOTS];
  slot_->length = (uint16_t)length;
  memcpy(slot_->data, data, (size_t)length);
  slot_->host[0] = 0;
  slot_->port = 0;
  if (from->ss_family == AF_INET) {
    const struct sockaddr_in* in4 = (const struct sockaddr_in*)from;
    inet_ntop(AF_INET, &in4->sin_addr, slot_->host, sizeof(slot_->host));
    slot_->port = ntohs(in4->sin_port);
  } else if (from->ss_family == AF_INET6) {
    const struct sockaddr_in6* in6 = (const struct sockaddr_in6*)from;
    inet_ntop(AF_INET6, &in6->sin6_addr, slot_->host, sizeof(slot_->host));
    slot_->port = ntohs(in6->sin6_port);
  }
  ma_atomic_store_32(&s->queue_write, w + 1);
  // One notice per run of datagrams: the reader takes until the queue is
  // empty, and only then is another notice owed.
  if (ma_atomic_exchange_32(&s->notified, 1) == 0) halo_audio_post(s->on_datagrams, s->token);
}

// --- FlexRadio DAX ----------------------------------------------------------------


// The payload of a VITA-49 packet with a stream id: where it starts and how
// many bytes it holds, from the header's own flags. 0 when [data] is no
// such packet.
static int vita_payload(const uint8_t* data, int length, int* offset, int* bytes) {
  if (length < 8) return 0;
  uint32_t header = read_be32(data);
  int type = (int)(header >> 28);
  if (type != 1 && type != 3) return 0;
  int words = (int)(header & 0xffff);
  if (words * 4 > length) return 0;
  int at = 8;
  if (header & (1u << 27)) at += 8;         // class id
  if ((header >> 22) & 3) at += 4;          // integer timestamp
  if ((header >> 20) & 3) at += 8;          // fractional timestamp
  int end = words * 4 - ((header & (1u << 26)) ? 4 : 0);  // trailer
  if (end < at) return 0;
  *offset = at;
  *bytes = end - at;
  return 1;
}

// [frames] frames at 24 kHz into [ep] at the engine's rate.
static void dax_emit(Endpoint* ep, NetEndpoint* n, const float* frames24, int frames) {
  float out[FLEX_DAX_FRAMES * 4];
  while (frames > 0) {
    int chunk = frames < FLEX_DAX_FRAMES ? frames : FLEX_DAX_FRAMES;
    halfband_up(&n->filter, 2, frames24, chunk, out);
    source_process(ep, out, (ma_uint32)(chunk * 2));
    frames24 += chunk * 2;
    frames -= chunk;
  }
}

// Frame [k] of a gap, channel [c]: the last packet repeated, each repeat's
// start crossfaded with the end of the one before over the hold, so no
// repeat jumps mid-cycle — a period of the packet less the hold. Faded out
// after DAX_REPEAT_FRAMES.
static float dax_repeat(const NetEndpoint* n, int k, int c) {
  int period = n->last_frames - DAX_HOLD_FRAMES;
  if (period < DAX_HOLD_FRAMES || k >= DAX_REPEAT_FRAMES + DAX_REPEAT_FADE_FRAMES) return 0;
  float env = k < DAX_REPEAT_FRAMES ? 1.0f : 1.0f - (float)(k - DAX_REPEAT_FRAMES) / DAX_REPEAT_FADE_FRAMES;
  int j = k % period;
  float v = n->last[j * 2 + c];
  if (j < DAX_HOLD_FRAMES) {
    float g = (j + 0.5f) / DAX_HOLD_FRAMES;
    v = n->last[(period + j) * 2 + c] * (1 - g) + v * g;
  }
  return v * env;
}

// One packet into the endpoint, after [lost] packets that never came. The
// lost ones are filled — the held-back end of the last packet with them —
// so the stream keeps its timeline and the bridge does not run dry over
// them: with the last packet repeated, crossfaded from where it left off
// and into this one's start, so a short loss is heard as the sound going
// on, never as a click or a hole. Without the crossfades a lost packet
// clicks; the stream's first packet starts mid-signal as surely as one
// after a gap does, and fades in.
static void dax_receive(Endpoint* ep, NetEndpoint* n, float* in, int frames, int lost) {
  if (frames <= DAX_HOLD_FRAMES) return;
  float heard[FLEX_DAX_FRAMES * 2];
  memcpy(heard, in, sizeof(float) * (size_t)frames * 2);
  if (!n->held) {
    for (int i = 0; i < DAX_HOLD_FRAMES; i++) {
      float gain = (float)i / DAX_HOLD_FRAMES;
      in[i * 2] *= gain;
      in[i * 2 + 1] *= gain;
    }
  } else if (lost == 0) {
    dax_emit(ep, n, n->tail, DAX_HOLD_FRAMES);
  } else {
    int length = DAX_HOLD_FRAMES + lost * FLEX_DAX_FRAMES;
    float fill[FLEX_DAX_FRAMES * 2];
    for (int k = 0; k < length; k += FLEX_DAX_FRAMES) {
      int m = length - k < FLEX_DAX_FRAMES ? length - k : FLEX_DAX_FRAMES;
      for (int i = 0; i < m; i++) {
        fill[i * 2] = dax_repeat(n, k + i, 0);
        fill[i * 2 + 1] = dax_repeat(n, k + i, 1);
      }
      dax_emit(ep, n, fill, m);
    }
    for (int i = 0; i < DAX_HOLD_FRAMES; i++) {
      float g = (i + 0.5f) / DAX_HOLD_FRAMES;
      in[i * 2] = in[i * 2] * g + dax_repeat(n, length + i, 0) * (1 - g);
      in[i * 2 + 1] = in[i * 2 + 1] * g + dax_repeat(n, length + i, 1) * (1 - g);
    }
  }
  dax_emit(ep, n, in, frames - DAX_HOLD_FRAMES);
  memcpy(n->tail, in + (frames - DAX_HOLD_FRAMES) * 2, sizeof(n->tail));
  memcpy(n->last, heard, sizeof(float) * (size_t)frames * 2);
  n->last_frames = frames;
  n->held = 1;
}

// The receive thread: a claimed dax_rx packet into its endpoint.
static int claim_flex_dax(NetSocket* s, const uint8_t* data, int length) {
  if (length < 8 || (read_be32(data) >> 28) != 3) return 0;
  uint32_t stream_id = read_be32(data + 4);
  int offset, bytes;
  if (!vita_payload(data, length, &offset, &bytes)) return 0;
  ma_spinlock_lock(&s->claims_lock);
  Endpoint* ep = NULL;
  for (int i = 0; i < s->claim_count; i++) {
    if (s->claims[i].stream_id == stream_id) ep = s->claims[i].endpoint;
  }
  if (ep == NULL) {
    ma_spinlock_unlock(&s->claims_lock);
    return 0;
  }
  NetEndpoint* n = ep->net;
  float in[FLEX_DAX_FRAMES * 2];
  int frames = bytes / 8;
  if (frames > FLEX_DAX_FRAMES) frames = FLEX_DAX_FRAMES;
  for (int i = 0; i < frames * 2; i++) in[i] = read_be_float(data + offset + i * 4);
  // The 4-bit packet counter is all that says a packet was lost: the
  // radio's timestamps are fill (0xa5a5a5a5). Arrival time cannot: Wi-Fi
  // holds packets back for 200 ms with nothing lost, and then a gap that
  // long means nothing. A run of 16 or more reads as fewer.
  uint32_t count = (read_be32(data) >> 16) & 15u;
  int lost = n->seen ? (int)((count - n->last_count - 1) & 15u) : 0;
  n->seen = 1;
  n->last_count = count;
  ma_atomic_fetch_add_32(&n->stat_packets, 1);
  if (lost > 0) ma_atomic_fetch_add_32(&n->stat_lost, (ma_uint32)lost);
  dax_receive(ep, n, in, frames, lost);
  ma_spinlock_unlock(&s->claims_lock);
  return 1;
}

static ma_thread_result MA_THREADCALL receive_thread(void* data) {
  NetSocket* s = (NetSocket*)data;
  uint8_t buffer[NET_DATAGRAM_BYTES + 1];
  while (!ma_atomic_load_32(&s->stop)) {
    struct sockaddr_storage from;
    socklen_t from_length = sizeof(from);
    int n = (int)recvfrom(s->fd, (char*)buffer, sizeof(buffer), 0, (struct sockaddr*)&from, &from_length);
    if (n <= 0) continue;  // the poll's timeout, or an error the next call meets again
    if (claim_flex_dax(s, buffer, n)) continue;
    queue_datagram(s, buffer, n, &from);
  }
  return (ma_thread_result)0;
}

// The sender: one packet of the sink's mix per period, on an absolute
// deadline, framed and sent. The mix is pulled every period whether or not
// it is sent, so its routes stay drained.
static void send_flex_dax(Endpoint* ep, NetEndpoint* n, const float* samples) {
  uint8_t packet[FLEX_DAX_PACKET];
  write_be32(packet, (1u << 28) | (1u << 27) | (1u << 22) | (1u << 20) | ((n->count & 15u) << 16) | (FLEX_DAX_PACKET / 4));
  write_be32(packet + 4, n->stream_id);
  write_be32(packet + 8, 0x00001C2D);
  write_be32(packet + 12, 0x534C03E3);
  write_be32(packet + 16, (uint32_t)time(NULL));
  write_be32(packet + 20, (uint32_t)(n->frames_sent >> 32));
  write_be32(packet + 24, (uint32_t)n->frames_sent);
  for (int i = 0; i < FLEX_DAX_FRAMES * 2; i++) write_be_float(packet + FLEX_DAX_HEADER + i * 4, samples == NULL ? 0.0f : samples[i]);
  // The timeline moves on whether or not the packet went; only one that
  // went is counted as sent, so a link that is down reads as nothing sent.
  const int sent = (int)sendto(n->socket->fd, (const char*)packet, FLEX_DAX_PACKET, 0, (const struct sockaddr*)&n->to, (socklen_t)n->to_length);
  n->count++;
  n->frames_sent += FLEX_DAX_FRAMES;
  if (sent == FLEX_DAX_PACKET) ma_atomic_fetch_add_32(&n->stat_sent, 1);
  (void)ep;
}

static ma_thread_result MA_THREADCALL sender_thread(void* data) {
  Endpoint* ep = (Endpoint*)data;
  NetEndpoint* n = ep->net;
  void* timer = new_sleep_timer();
  const uint64_t period = (uint64_t)FLEX_DAX_FRAMES * 1000000000ull / 24000;
  float mix[FLEX_DAX_FRAMES * 2 * 2], half[FLEX_DAX_FRAMES * 2];
  uint64_t next = mono_ns();
  double late_sum = 0;
  uint64_t late_count = 0;
  ma_uint32 late_max = 0;
  int was_sending = 0;
  while (!ma_atomic_load_32(&n->stop)) {
    sleep_until_ns(next, timer);
    uint64_t now = mono_ns();
    ma_uint32 late_us = now > next ? (ma_uint32)((now - next) / 1000) : 0;
    if (late_us > late_max) late_max = late_us;
    late_sum += late_us;
    late_count++;
    sink_process(ep, mix, FLEX_DAX_FRAMES * 2);
    halfband_down(&n->filter, 2, mix, FLEX_DAX_FRAMES, half);
    int sending = (int)ma_atomic_load_32(&n->sending);
    if (sending && !was_sending) {
      // The radio plays what arrives as it arrives: this many packets of
      // silence ahead of the first keep it fed through a late wake-up.
      for (int i = 0; i < n->ahead; i++) send_flex_dax(ep, n, NULL);
    }
    if (sending) send_flex_dax(ep, n, half);
    was_sending = sending;
    next += period;
    if (now > next + 4 * period) {
      // Fallen too far behind to catch up without a burst: start again from
      // now.
      next = now;
      ma_atomic_fetch_add_32(&n->stat_reanchored, 1);
    }
    ma_atomic_store_32(&n->stat_late_max_us, late_max);
    store_f32(&n->stat_late_mean_us, (float)(late_sum / (double)late_count));
  }
  free_sleep_timer(timer);
  return (ma_thread_result)0;
}

// --- The control side ---------------------------------------------------------------

static int resolve(const char* host, int port, struct sockaddr_storage* out, int* out_length) {
  struct addrinfo hints, *found = NULL;
  memset(&hints, 0, sizeof(hints));
  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_DGRAM;
  hints.ai_flags = AI_NUMERICHOST;
  char service[8];
  snprintf(service, sizeof(service), "%d", port);
  if (getaddrinfo(host, service, &hints, &found) != 0 || found == NULL) return -1;
  memcpy(out, found->ai_addr, found->ai_addrlen);
  *out_length = (int)found->ai_addrlen;
  freeaddrinfo(found);
  return 0;
}

int32_t halo_audio_engine_open_socket(HaloAudioEngine* engine, int port, HaloAudioPort on_datagrams, int64_t token, char* err, int err_len) {
  collect(engine);
  if (!net_ready()) {
    snprintf(err, (size_t)err_len, "socket: the network stack did not start");
    return -1;
  }
  int index = -1;
  for (int i = 0; i < ENGINE_MAX_SOCKETS; i++) {
    if (engine->sockets[i] == NULL) {
      index = i;
      break;
    }
  }
  if (index < 0) {
    snprintf(err, (size_t)err_len, "socket: too many open");
    return -1;
  }
  NetSocket* s = (NetSocket*)calloc(1, sizeof(NetSocket));
  QueuedDatagram* queue = (QueuedDatagram*)calloc(NET_QUEUE_SLOTS, sizeof(QueuedDatagram));
  if (s == NULL || queue == NULL) {
    free(s);
    free(queue);
    snprintf(err, (size_t)err_len, "socket: out of memory");
    return -1;
  }
  s->queue = queue;
  s->engine = engine;
  s->on_datagrams = on_datagrams;
  s->token = token;
  s->fd = socket(AF_INET, SOCK_DGRAM, 0);
  if (s->fd == NET_NO_FD) {
    snprintf(err, (size_t)err_len, "socket: %s", strerror(errno));
    free(queue);
    free(s);
    return -1;
  }
  struct sockaddr_in local;
  memset(&local, 0, sizeof(local));
  local.sin_family = AF_INET;
  local.sin_addr.s_addr = htonl(INADDR_ANY);
  local.sin_port = htons((uint16_t)port);
  if (bind(s->fd, (struct sockaddr*)&local, sizeof(local)) != 0) {
    snprintf(err, (size_t)err_len, "socket: bind %d: %s", port, strerror(errno));
    net_close(s->fd);
    free(queue);
    free(s);
    return -1;
  }
  socklen_t local_length = sizeof(local);
  getsockname(s->fd, (struct sockaddr*)&local, &local_length);
  s->port = ntohs(local.sin_port);
#if defined(_WIN32)
  DWORD timeout = NET_RECEIVE_POLL_MS;
#else
  struct timeval timeout = {0, NET_RECEIVE_POLL_MS * 1000};
#endif
  setsockopt(s->fd, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));
  // A radio's audio comes in bursts the receive thread may be late for.
  int buffer = 1 << 20;
  setsockopt(s->fd, SOL_SOCKET, SO_RCVBUF, (const char*)&buffer, sizeof(buffer));
  s->id = engine->next_id++;
  if (ma_thread_create(&s->thread, ma_thread_priority_realtime, 0, receive_thread, s, NULL) != MA_SUCCESS) {
    snprintf(err, (size_t)err_len, "socket: no receive thread");
    net_close(s->fd);
    free(queue);
    free(s);
    return -1;
  }
  s->thread_running = 1;
  engine->sockets[index] = s;
  return s->id;
}

int halo_audio_engine_socket_port(HaloAudioEngine* engine, int32_t socket_id) {
  NetSocket* s = find_socket(engine, socket_id);
  return s == NULL ? -1 : s->port;
}

int halo_audio_engine_socket_send(HaloAudioEngine* engine, int32_t socket_id, const char* host, int port, const uint8_t* bytes, int length) {
  NetSocket* s = find_socket(engine, socket_id);
  if (s == NULL || length < 0) return -1;
  if (s->sent_to_length == 0 || port != s->sent_port || strncmp(host, s->sent_host, sizeof(s->sent_host)) != 0) {
    if (strlen(host) >= sizeof(s->sent_host) || resolve(host, port, &s->sent_to, &s->sent_to_length) != 0) {
      s->sent_to_length = 0;
      return -1;
    }
    snprintf(s->sent_host, sizeof(s->sent_host), "%s", host);
    s->sent_port = port;
  }
  return sendto(s->fd, (const char*)bytes, length, 0, (const struct sockaddr*)&s->sent_to, (socklen_t)s->sent_to_length) == length ? 0 : -1;
}

int halo_audio_engine_socket_dropped(HaloAudioEngine* engine, int32_t socket_id) {
  NetSocket* s = find_socket(engine, socket_id);
  return s == NULL ? -1 : (int)ma_atomic_load_32(&s->queue_dropped);
}

int halo_audio_engine_socket_take(HaloAudioEngine* engine, int32_t socket_id, uint8_t* out, int capacity, char* host, int host_length, int* port) {
  NetSocket* s = find_socket(engine, socket_id);
  if (s == NULL) return -1;
  ma_uint32 r = s->queue_read;
  if (ma_atomic_load_32(&s->queue_write) == r) {
    // Empty: owed a notice for the next datagram, then looked at once more
    // for one that came in before the notice was owed.
    ma_atomic_store_32(&s->notified, 0);
    if (ma_atomic_load_32(&s->queue_write) == r) return 0;
    ma_atomic_store_32(&s->notified, 1);
  }
  QueuedDatagram* d = &s->queue[r % NET_QUEUE_SLOTS];
  int length = d->length < capacity ? d->length : capacity;
  memcpy(out, d->data, (size_t)length);
  snprintf(host, (size_t)host_length, "%s", d->host);
  *port = d->port;
  ma_atomic_store_32(&s->queue_read, r + 1);
  return length;
}

static void stop_sender(NetEndpoint* n) {
  if (!n->thread_running) return;
  ma_atomic_store_32(&n->stop, 1);
  ma_thread_wait(&n->thread);
  n->thread_running = 0;
}

static void drop_claim(NetEndpoint* n, Endpoint* ep) {
  NetSocket* s = n->socket;
  ma_spinlock_lock(&s->claims_lock);
  for (int i = 0; i < s->claim_count; i++) {
    if (s->claims[i].endpoint == ep) {
      s->claims[i] = s->claims[--s->claim_count];
      break;
    }
  }
  ma_spinlock_unlock(&s->claims_lock);
}

// Called by close_endpoint before the endpoint leaves the graph: after it,
// no network thread touches the endpoint.
static void net_endpoint_closing(Endpoint* ep) {
  NetEndpoint* n = ep->net;
  if (n == NULL) return;
  if (ep->kind == ENDPOINT_SENT) stop_sender(n);
  else drop_claim(n, ep);
}

int32_t halo_audio_engine_add_flex_dax_rx(HaloAudioEngine* engine, int32_t socket_id, uint32_t stream_id) {
  collect(engine);
  NetSocket* s = find_socket(engine, socket_id);
  if (s == NULL || s->claim_count >= NET_MAX_CLAIMS) return -1;
  NetEndpoint* n = (NetEndpoint*)calloc(1, sizeof(NetEndpoint));
  if (n == NULL) return -1;
  Endpoint* ep = new_endpoint(engine, ENDPOINT_RECEIVED, 2);
  if (ep == NULL) {
    free(n);
    return -1;
  }
  halfband_design();
  n->socket = s;
  n->stream_id = stream_id;
  ep->net = n;
  ma_spinlock_lock(&s->claims_lock);
  s->claims[s->claim_count].stream_id = stream_id;
  s->claims[s->claim_count].endpoint = ep;
  s->claim_count++;
  ma_spinlock_unlock(&s->claims_lock);
  return ep->id;
}

int32_t halo_audio_engine_add_flex_dax_tx(HaloAudioEngine* engine, int32_t socket_id, const char* host, int port, uint32_t stream_id, int ahead) {
  collect(engine);
  NetSocket* s = find_socket(engine, socket_id);
  if (s == NULL) return -1;
  NetEndpoint* n = (NetEndpoint*)calloc(1, sizeof(NetEndpoint));
  if (n == NULL) return -1;
  if (resolve(host, port, &n->to, &n->to_length) != 0) {
    free(n);
    return -1;
  }
  // Gated, as every sink that reaches a transmitter is.
  Endpoint* ep = new_endpoint(engine, ENDPOINT_SENT, 2);
  if (ep == NULL) {
    free(n);
    return -1;
  }
  ep->gate_open = 0;
  ep->gate_was_open = 0;
  ep->gate_gain = 0;
  halfband_design();
  n->socket = s;
  n->stream_id = stream_id;
  n->ahead = ahead < 0 ? 0 : ahead;
  ep->net = n;
  if (ma_thread_create(&n->thread, ma_thread_priority_realtime, 0, sender_thread, ep, NULL) != MA_SUCCESS) {
    ep->net = NULL;
    free(n);
    halo_audio_engine_close_endpoint(engine, ep->id);
    return -1;
  }
  n->thread_running = 1;
  return ep->id;
}

int halo_audio_engine_set_sending(HaloAudioEngine* engine, int32_t endpoint, int sending) {
  Endpoint* ep = find_endpoint(engine, endpoint);
  if (ep == NULL || ep->kind != ENDPOINT_SENT) return -1;
  ma_atomic_store_32(&ep->net->sending, sending ? 1 : 0);
  return 0;
}

int halo_audio_engine_receiver_stats(HaloAudioEngine* engine, int32_t endpoint, double* out) {
  Endpoint* ep = find_endpoint(engine, endpoint);
  if (ep == NULL || ep->kind != ENDPOINT_RECEIVED) return -1;
  out[HALO_AUDIO_RECEIVER_STAT_PACKETS] = ma_atomic_load_32(&ep->net->stat_packets);
  out[HALO_AUDIO_RECEIVER_STAT_LOST] = ma_atomic_load_32(&ep->net->stat_lost);
  return 0;
}

int halo_audio_engine_sender_stats(HaloAudioEngine* engine, int32_t endpoint, double* out) {
  Endpoint* ep = find_endpoint(engine, endpoint);
  if (ep == NULL || ep->kind != ENDPOINT_SENT) return -1;
  NetEndpoint* n = ep->net;
  out[HALO_AUDIO_SENDER_STAT_SENT] = ma_atomic_load_32(&n->stat_sent);
  out[HALO_AUDIO_SENDER_STAT_REANCHORED] = ma_atomic_load_32(&n->stat_reanchored);
  out[HALO_AUDIO_SENDER_STAT_LATE_MAX_US] = ma_atomic_load_32(&n->stat_late_max_us);
  out[HALO_AUDIO_SENDER_STAT_LATE_MEAN_US] = load_f32(&n->stat_late_mean_us);
  return 0;
}

static void close_socket(HaloAudioEngine* engine, NetSocket* s) {
  // Its endpoints first: a sender sends on this socket, and the receive
  // thread pushes to the others.
  for (int i = 0; i < ENGINE_MAX_ENDPOINTS; i++) {
    Endpoint* ep = engine->endpoints[i];
    if (ep != NULL && ep->net != NULL && ep->net->socket == s) halo_audio_engine_close_endpoint(engine, ep->id);
  }
  if (s->thread_running) {
    ma_atomic_store_32(&s->stop, 1);
    ma_thread_wait(&s->thread);
  }
  net_close(s->fd);
  for (int i = 0; i < ENGINE_MAX_SOCKETS; i++) {
    if (engine->sockets[i] == s) engine->sockets[i] = NULL;
  }
  free(s->queue);
  free(s);
}

int halo_audio_engine_close_socket(HaloAudioEngine* engine, int32_t socket_id) {
  NetSocket* s = find_socket(engine, socket_id);
  if (s == NULL) return -1;
  close_socket(engine, s);
  return 0;
}

// Called by halo_audio_engine_free before anything is freed.
static void net_free_all(HaloAudioEngine* engine) {
  for (int i = 0; i < ENGINE_MAX_SOCKETS; i++) {
    if (engine->sockets[i] != NULL) close_socket(engine, engine->sockets[i]);
  }
}
