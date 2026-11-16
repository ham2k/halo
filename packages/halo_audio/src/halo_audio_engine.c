// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// See halo_audio_engine.h. Included at the end of halo_audio.c rather than
// compiled on its own: the library stays one translation unit, and
// miniaudio's atomics — which build on MSVC, where C11's need an
// experimental flag — and its context are in scope.
//
// Memory order is sequentially consistent throughout. An audio thread does
// a handful of atomic operations per frame, which costs nothing next to the
// interpolation, and a weaker order is a bug nobody can test for.

#include "halo_audio_engine.h"

#define ENGINE_MAX_ENDPOINTS 64
#define ENGINE_SCRATCH_FRAMES 256
// Gains and gates ramp over 5 ms: a step in either clicks.
#define ENGINE_RAMP_FRAMES 240
// A bridge fades over 1 ms around a gap or a cut.
#define BRIDGE_FADE_FRAMES 48
// The resampler's correction is bounded at 2000 ppm, 3.5 cents, which no
// ear hears on a voice; it moves 1000 ppm for every 10 ms the depth is off,
// so an excess drains with a time constant of ten seconds.
#define BRIDGE_MAX_PPM 2000.0
#define BRIDGE_PPM_PER_FRAME (1000.0 / 480.0)
// The depth's average follows over half a second, which smooths away a
// packetized writer's sawtooth.
#define BRIDGE_AVERAGE_SECONDS 0.5
// How far the depth dips below its average is measured in one-second
// windows, and so is the longest stall the writer made: the target covers
// the deepest of each over the last twenty, so a burst raises it at once
// and is forgotten twenty seconds later.
#define BRIDGE_WINDOW_FRAMES HALO_AUDIO_ENGINE_RATE
#define BRIDGE_WINDOWS 20
// The integrator that learns the two clocks' steady drift, which the
// proportional term alone leaves the depth off by — 2 ms at 200 ppm, more
// than the safety margin. It integrates only within 2 ms of the target, so
// a jump of the target never winds it up, and it holds 1000 ppm at most,
// more than any two crystals differ.
#define BRIDGE_DRIFT_SECONDS 20.0
#define BRIDGE_DRIFT_BAND_FRAMES 96
#define BRIDGE_DRIFT_MAX_PPM 1000.0
// What the depth's lowest point is steered to: 2 ms in hand, which covers
// what the proportional term leaves the depth off by at 200 ppm of drift
// while the integrator below is still learning it.
#define BRIDGE_SAFETY_FRAMES 96

// The deepest a route's ring may be asked to grow.
#define BRIDGE_MAX_MS 10000

#define ENDPOINT_INPUT 1
#define ENDPOINT_OUTPUT 2
#define ENDPOINT_PUSHED 3
#define ENDPOINT_PULLED 4
#define ENDPOINT_RECEIVED 5  // a source a socket's receive thread pushes to
#define ENDPOINT_SENT 6      // a sink a sender thread pulls from

#define ENGINE_MAX_SOCKETS 16

static void store_f32(volatile ma_uint32* dst, float v) {
  ma_uint32 bits;
  memcpy(&bits, &v, sizeof(bits));
  ma_atomic_store_32(dst, bits);
}

static float load_f32(volatile ma_uint32* src) {
  ma_uint32 bits = ma_atomic_load_32(src);
  float v;
  memcpy(&v, &bits, sizeof(v));
  return v;
}

// Raises [peak] to [level] — written by one audio thread, taken by the
// control side, which may lose a level written in the same instant: a
// meter's reading, not an account.
static void raise_peak(volatile ma_uint32* peak, float level) {
  if (level > load_f32(peak)) store_f32(peak, level);
}

// --- The clock bridge -----------------------------------------------------

#define BRIDGE_FILLING 0
#define BRIDGE_RUNNING 1

typedef struct {
  float* ring;
  ma_uint32 capacity;  // frames, a power of two
  int channels;
  // Frame counters, wrapping: the writer owns write_pos, the reader
  // read_pos, and each only reads the other's.
  volatile ma_uint32 write_pos;
  volatile ma_uint32 read_pos;
  volatile ma_uint32 dropped;
  int writer_fade_in;  // the writer's: its last write was cut short

  // The reader's alone.
  int state;
  int start_depth;
  int max_depth;
  double frac;      // position between hist[1] and hist[2]
  float hist[4][2]; // the input frames around the read position
  int starved;      // holding the last value while fading out
  int was_running;  // filling again after running dry, not for the first time
  int gap;          // frames heard as silence since it ran dry
  int gap_base;     // the average depth when it did
  float env;        // the fade around a gap or a cut, 0..1
  int env_dir;      // -1 fading out, +1 fading in, 0 steady
  ma_uint32 pending_cut;
  double average;
  int window_frames;
  int window_min;
  int dips[BRIDGE_WINDOWS];    // below the average, per window
  int stalls[BRIDGE_WINDOWS];  // the writer's stalls, per window
  int dip_index;
  double drift_ppm;
  int target;

  // Published by the reader for the statistics.
  volatile ma_uint32 stat_average;  // f32, frames
  volatile ma_uint32 stat_target;
  volatile ma_uint32 stat_ppm;      // f32
  volatile ma_uint32 stat_underruns;
  volatile ma_uint32 stat_skips;
  volatile ma_uint32 stat_running;
} Bridge;

static int bridge_init(Bridge* b, int channels, int start_ms, int max_ms) {
  memset(b, 0, sizeof(*b));
  b->channels = channels;
  if (max_ms > BRIDGE_MAX_MS) max_ms = BRIDGE_MAX_MS;
  if (start_ms > max_ms) start_ms = max_ms;
  b->start_depth = start_ms * (HALO_AUDIO_ENGINE_RATE / 1000);
  b->max_depth = max_ms * (HALO_AUDIO_ENGINE_RATE / 1000);
  if (b->start_depth < BRIDGE_SAFETY_FRAMES) b->start_depth = BRIDGE_SAFETY_FRAMES;
  if (b->max_depth < 2 * b->start_depth) b->max_depth = 2 * b->start_depth;
  // Room for twice the maximum and a quarter second's burst on top, so a
  // writer running ahead is cut back by the reader, with a fade, before it
  // finds the ring full.
  ma_uint32 capacity = 1024;
  while (capacity < (ma_uint32)(2 * b->max_depth + HALO_AUDIO_ENGINE_RATE / 4)) capacity <<= 1;
  b->capacity = capacity;
  b->ring = (float*)calloc((size_t)capacity * channels, sizeof(float));
  if (b->ring == NULL) return -1;
  b->state = BRIDGE_FILLING;
  b->target = b->start_depth;
  b->window_min = INT32_MAX;
  store_f32(&b->stat_ppm, 0);
  return 0;
}

static void bridge_release(Bridge* b) { free(b->ring); }

// The writer's side. A write that does not fit leaves a seam between what
// it wrote and whatever is written next, and both sides of the seam are
// faded, or it clicks. So a whole write is taken only while it leaves a
// fade's worth of room behind it: the write that does not fit then always
// has room to fade out in. After a seam the writer takes nothing until a
// whole write fits again, and fades that one in.
static ma_uint32 bridge_write(Bridge* b, const float* in, ma_uint32 frames) {
  // An empty write is no whole write: taken as one, it would end a seam
  // with nothing faded in, and the next write would start at full level.
  if (frames == 0) return 0;
  ma_uint32 w = b->write_pos;
  ma_uint32 room = b->capacity - (w - ma_atomic_load_32(&b->read_pos));
  int fits = frames + BRIDGE_FADE_FRAMES <= room;
  ma_uint32 n;
  ma_uint32 fade_in = 0, fade_out = 0;
  if (fits) {
    n = frames;
    if (b->writer_fade_in) fade_in = n < BRIDGE_FADE_FRAMES ? n : BRIDGE_FADE_FRAMES;
    b->writer_fade_in = 0;
  } else if (!b->writer_fade_in) {
    n = frames < room ? frames : room;
    fade_out = n < BRIDGE_FADE_FRAMES ? n : BRIDGE_FADE_FRAMES;
    b->writer_fade_in = 1;
  } else {
    n = 0;
  }
  ma_uint32 mask = b->capacity - 1;
  for (ma_uint32 i = 0; i < n; i++) {
    float gain = 1;
    if (i < fade_in) gain = (float)i / (float)fade_in;
    if (i >= n - fade_out) gain *= (float)(n - 1 - i) / (float)fade_out;
    float* dst = b->ring + (size_t)((w + i) & mask) * b->channels;
    for (int c = 0; c < b->channels; c++) dst[c] = in[(size_t)i * b->channels + c] * gain;
  }
  ma_atomic_store_32(&b->write_pos, w + n);
  if (n < frames) ma_atomic_fetch_add_32(&b->dropped, frames - n);
  return n;
}

// The reader's side from here down.

static ma_uint32 bridge_depth(Bridge* b) { return ma_atomic_load_32(&b->write_pos) - b->read_pos; }

static int bridge_take(Bridge* b, float* frame) {
  ma_uint32 r = b->read_pos;
  if (ma_atomic_load_32(&b->write_pos) == r) return 0;
  const float* src = b->ring + (size_t)(r & (b->capacity - 1)) * b->channels;
  for (int c = 0; c < b->channels; c++) frame[c] = src[c];
  ma_atomic_store_32(&b->read_pos, r + 1);
  return 1;
}

// Everything the ring holds is dropped and it fills again from what comes
// next.
static void bridge_flush(Bridge* b) {
  ma_atomic_store_32(&b->read_pos, ma_atomic_load_32(&b->write_pos));
  b->state = BRIDGE_FILLING;
  b->starved = 0;
  b->was_running = 0;
  b->gap = 0;
  b->pending_cut = 0;
}

// The target covers a stall as long as the longest of the last twenty
// windows', starting at the bottom of a dip as deep as theirs.
static void bridge_retarget(Bridge* b) {
  int deepest = 0, longest = 0;
  for (int i = 0; i < BRIDGE_WINDOWS; i++) {
    if (b->dips[i] > deepest) deepest = b->dips[i];
    if (b->stalls[i] > longest) longest = b->stalls[i];
  }
  b->target = BRIDGE_SAFETY_FRAMES + deepest + longest;
  if (b->target > b->max_depth / 2) b->target = b->max_depth / 2;
}

static void bridge_record(int* slots, int index, int value) {
  if (value > slots[index]) slots[index] = value;
}

// Measures the depth once per read and steers the ratio by it.
static double bridge_steer(Bridge* b, int frames) {
  int depth = (int)bridge_depth(b);
  double alpha = (double)frames / (BRIDGE_AVERAGE_SECONDS * HALO_AUDIO_ENGINE_RATE);
  if (alpha > 1) alpha = 1;
  b->average += alpha * (depth - b->average);
  // The ring is lowest at the end of this read, not at its start, where
  // it is measured: a target set from the start's depth runs it dry by a
  // period.
  int lowest = depth - frames;
  if (lowest < b->window_min) b->window_min = lowest;
  b->window_frames += frames;
  if (b->window_frames >= BRIDGE_WINDOW_FRAMES) {
    int dip = (int)(b->average - b->window_min);
    bridge_record(b->dips, b->dip_index, dip < 0 ? 0 : dip);
    bridge_retarget(b);
    b->dip_index = (b->dip_index + 1) % BRIDGE_WINDOWS;
    b->dips[b->dip_index] = 0;
    b->stalls[b->dip_index] = 0;
    b->window_frames = 0;
    b->window_min = INT32_MAX;
  }
  if (depth > b->max_depth && b->pending_cut == 0 && !b->starved) {
    b->pending_cut = (ma_uint32)(depth - b->target);
    b->env_dir = -1;
    ma_atomic_fetch_add_32(&b->stat_skips, 1);
  }
  double error = b->average - b->target;
  if (fabs(error) < BRIDGE_DRIFT_BAND_FRAMES) {
    b->drift_ppm += error * BRIDGE_PPM_PER_FRAME * frames / (BRIDGE_DRIFT_SECONDS * HALO_AUDIO_ENGINE_RATE);
    if (b->drift_ppm > BRIDGE_DRIFT_MAX_PPM) b->drift_ppm = BRIDGE_DRIFT_MAX_PPM;
    if (b->drift_ppm < -BRIDGE_DRIFT_MAX_PPM) b->drift_ppm = -BRIDGE_DRIFT_MAX_PPM;
  }
  double ppm = error * BRIDGE_PPM_PER_FRAME + b->drift_ppm;
  if (ppm > BRIDGE_MAX_PPM) ppm = BRIDGE_MAX_PPM;
  if (ppm < -BRIDGE_MAX_PPM) ppm = -BRIDGE_MAX_PPM;
  store_f32(&b->stat_average, (float)b->average);
  ma_atomic_store_32(&b->stat_target, (ma_uint32)b->target);
  store_f32(&b->stat_ppm, (float)ppm);
  return 1.0 + ppm * 1e-6;
}

static float hermite(float p0, float p1, float p2, float p3, float t) {
  float c1 = 0.5f * (p2 - p0);
  float c2 = p0 - 2.5f * p1 + 2.0f * p2 - 0.5f * p3;
  float c3 = 0.5f * (p3 - p0) + 1.5f * (p1 - p2);
  return ((c3 * t + c2) * t + c1) * t + p1;
}

// Writes [frames] frames of the bridge's channels into [out].
static void bridge_read(Bridge* b, float* out, int frames) {
  int ch = b->channels;
  int i = 0;
  if (b->state == BRIDGE_FILLING) {
    // Run dry, it fills to the depth its stalls have called for, not back
    // to the start: refilled shallow, it grows toward the target at the
    // steering's 2 ms a second, and a stall whose audio never comes runs it
    // dry again long before it gets there.
    int need = b->was_running && b->target > b->start_depth ? b->target : b->start_depth;
    if ((int)bridge_depth(b) < need) {
      if (b->was_running) b->gap += frames;
      memset(out, 0, sizeof(float) * (size_t)frames * ch);
      ma_atomic_store_32(&b->stat_running, 0);
      store_f32(&b->stat_average, (float)bridge_depth(b));
      return;
    }
    memset(b->hist, 0, sizeof(b->hist));
    for (int k = 1; k < 4; k++) bridge_take(b, b->hist[k]);
    b->frac = 0;
    b->env = 0;
    b->env_dir = 1;
    b->starved = 0;
    b->average = bridge_depth(b);
    // The writer stalled for the depth the ring held plus the silence after
    // it, and a stall that long has to be covered next time — less what it
    // waited past its start to fill to the target, which is no stall of the
    // writer's: counted as one, every refill would raise the target the next
    // refill waits for. A writer that held its audio back through the stall
    // delivers it now, so the depth already stands near it. The window it
    // ran dry in measures no dip: its lowest point is the stall's.
    if (b->was_running && b->gap > 0) {
      int stall = b->gap_base + b->gap - (need - b->start_depth);
      bridge_record(b->stalls, b->dip_index, stall > 0 ? stall : 0);
      bridge_retarget(b);
      b->window_min = INT32_MAX;
    }
    b->was_running = 1;
    b->gap = 0;
    b->state = BRIDGE_RUNNING;
    ma_atomic_store_32(&b->stat_running, 1);
  }
  double ratio = bridge_steer(b, frames);
  for (; i < frames; i++) {
    float t = (float)b->frac;
    for (int c = 0; c < ch; c++) out[(size_t)i * ch + c] = hermite(b->hist[0][c], b->hist[1][c], b->hist[2][c], b->hist[3][c], t) * b->env;
    if (b->env_dir != 0) {
      b->env += (float)b->env_dir / BRIDGE_FADE_FRAMES;
      if (b->env >= 1) {
        b->env = 1;
        b->env_dir = 0;
      } else if (b->env <= 0) {
        b->env = 0;
        if (b->starved) {
          // Faded out on an empty ring: fill again.
          b->state = BRIDGE_FILLING;
          b->starved = 0;
          b->gap = frames - i - 1;
          ma_atomic_store_32(&b->stat_running, 0);
          memset(out + (size_t)(i + 1) * ch, 0, sizeof(float) * (size_t)(frames - i - 1) * ch);
          return;
        }
        if (b->pending_cut > 0) {
          ma_uint32 depth = bridge_depth(b);
          ma_uint32 cut = b->pending_cut < depth ? b->pending_cut : depth;
          ma_atomic_store_32(&b->read_pos, b->read_pos + cut);
          b->pending_cut = 0;
          b->average -= cut;
        }
        b->env_dir = 1;
      }
    }
    if (b->starved) continue;
    b->frac += ratio;
    while (b->frac >= 1.0) {
      float next[2];
      if (!bridge_take(b, next)) {
        b->starved = 1;
        b->gap_base = (int)b->average;
        b->env_dir = -1;
        b->frac = 0.999;
        ma_atomic_fetch_add_32(&b->stat_underruns, 1);
        break;
      }
      memmove(b->hist[0], b->hist[1], sizeof(b->hist[0]) * 3);
      for (int c = 0; c < ch; c++) b->hist[3][c] = next[c];
      b->frac -= 1.0;
    }
  }
}

// --- Endpoints, routes and the graph ----------------------------------------

typedef struct Route {
  int32_t id;
  int32_t source;
  int32_t sink;
  int source_channels;
  Bridge bridge;
  volatile ma_uint32 gain_left;  // f32, set by the control side
  volatile ma_uint32 gain_right;
  float current_left;            // the sink's thread's, ramping to the above
  float current_right;
} Route;

// The routes as the audio threads see them: never changed once published,
// replaced whole.
typedef struct {
  int count;
  Route* routes[];
} Graph;

typedef struct Endpoint {
  HaloAudioEngine* engine;
  int32_t id;
  int kind;
  int channels;
  // Odd while the endpoint's thread is inside a callback, push or pull: what
  // tells the control side a graph it replaced is no longer being read.
  volatile ma_uint32 busy;
  volatile ma_uint32 gate_open;
  int gate_was_open;  // the sink's thread's
  float gate_gain;    // the sink's thread's
  volatile ma_uint32 peak;
  int has_device;
  ma_device device;
  volatile ma_bool32 closing;
  HaloAudioPort on_lost;
  int64_t lost_token;
  float scratch[ENGINE_SCRATCH_FRAMES * 2];
  float mix[ENGINE_SCRATCH_FRAMES * 2];
  struct NetEndpoint* net;  // a network endpoint's (halo_audio_net.c)
} Endpoint;

// What a replaced graph, a removed route or a closed endpoint leaves to
// free once no audio thread can be reading it — when every endpoint that
// was open as it was retired has since been seen outside its callback.
typedef struct Retired {
  struct Retired* next;
  Graph* graph;
  Route* route;
  Endpoint* endpoint;
  int seen_count;
  Endpoint* seen[ENGINE_MAX_ENDPOINTS];
  ma_uint32 seen_busy[ENGINE_MAX_ENDPOINTS];
} Retired;

struct HaloAudioEngine {
  Graph* volatile graph;
  Endpoint* endpoints[ENGINE_MAX_ENDPOINTS];
  int32_t next_id;
  Retired* retired_head;
  Retired* retired_tail;
  struct NetSocket* sockets[ENGINE_MAX_SOCKETS];
};

// halo_audio_net.c's, which comes after this file.
static void net_endpoint_closing(Endpoint* ep);
static void net_free_all(HaloAudioEngine* engine);

static void enter(Endpoint* ep) { ma_atomic_fetch_add_32(&ep->busy, 1); }
static void leave(Endpoint* ep) { ma_atomic_fetch_add_32(&ep->busy, 1); }

static Graph* current_graph(HaloAudioEngine* e) { return (Graph*)ma_atomic_load_ptr(&e->graph); }

// The source's thread: [frames] frames into every route from it. A route
// whose ring is full drops what does not fit and counts it.
static void source_process(Endpoint* ep, const float* in, ma_uint32 frames) {
  enter(ep);
  Graph* g = current_graph(ep->engine);
  for (int r = 0; r < g->count; r++) {
    Route* route = g->routes[r];
    if (route->source == ep->id) bridge_write(&route->bridge, in, frames);
  }
  float loudest = 0;
  for (ma_uint32 i = 0; i < frames * (ma_uint32)ep->channels; i++) {
    float s = fabsf(in[i]);
    if (s > loudest) loudest = s;
  }
  raise_peak(&ep->peak, loudest);
  leave(ep);
}

static float ramp(float current, float target, float step) {
  if (current < target) return current + step < target ? current + step : target;
  if (current > target) return current - step > target ? current - step : target;
  return current;
}

// A step that covers the way from [current] to [target] in 5 ms, and no
// slower than unity's: a gain of 4 ramps as fast as a gain of 1.
static float ramp_step(float current, float target) {
  float step = fabsf(target - current) / ENGINE_RAMP_FRAMES;
  return step > 1.0f / ENGINE_RAMP_FRAMES ? step : 1.0f / ENGINE_RAMP_FRAMES;
}

// Mixes [frames] frames of [route] into the sink's mix.
static void mix_route(Endpoint* sink, Route* route, int frames) {
  bridge_read(&route->bridge, sink->scratch, frames);
  float target_left = load_f32(&route->gain_left), target_right = load_f32(&route->gain_right);
  float step_left = ramp_step(route->current_left, target_left), step_right = ramp_step(route->current_right, target_right);
  int sc = route->source_channels;
  for (int i = 0; i < frames; i++) {
    route->current_left = ramp(route->current_left, target_left, step_left);
    route->current_right = ramp(route->current_right, target_right, step_right);
    float l = sink->scratch[i * sc];
    float r = sc == 2 ? sink->scratch[i * sc + 1] : l;
    if (sink->channels == 2) {
      sink->mix[i * 2] += l * route->current_left;
      sink->mix[i * 2 + 1] += r * route->current_right;
    } else {
      sink->mix[i] += 0.5f * (l * route->current_left + r * route->current_right);
    }
  }
}

// The sink's thread: [frames] frames of its mix into [out].
static void sink_process(Endpoint* ep, float* out, ma_uint32 frames) {
  enter(ep);
  Graph* g = current_graph(ep->engine);
  int gate = (int)ma_atomic_load_32(&ep->gate_open);
  if (gate && !ep->gate_was_open) {
    for (int r = 0; r < g->count; r++) {
      if (g->routes[r]->sink == ep->id) bridge_flush(&g->routes[r]->bridge);
    }
  }
  ep->gate_was_open = gate;
  float loudest = 0;
  ma_uint32 done = 0;
  while (done < frames) {
    int n = (int)(frames - done < ENGINE_SCRATCH_FRAMES ? frames - done : ENGINE_SCRATCH_FRAMES);
    memset(ep->mix, 0, sizeof(float) * (size_t)n * ep->channels);
    for (int r = 0; r < g->count; r++) {
      if (g->routes[r]->sink == ep->id) mix_route(ep, g->routes[r], n);
    }
    float* dst = out + (size_t)done * ep->channels;
    for (int i = 0; i < n; i++) {
      ep->gate_gain = ramp(ep->gate_gain, gate ? 1.0f : 0.0f, 1.0f / ENGINE_RAMP_FRAMES);
      for (int c = 0; c < ep->channels; c++) {
        float s = ep->mix[i * ep->channels + c] * ep->gate_gain;
        dst[i * ep->channels + c] = s;
        if (fabsf(s) > loudest) loudest = fabsf(s);
      }
    }
    done += (ma_uint32)n;
  }
  raise_peak(&ep->peak, loudest);
  leave(ep);
}

// --- The control side ---------------------------------------------------------

static int quiescent(Retired* r) {
  for (int i = 0; i < r->seen_count; i++) {
    ma_uint32 then = r->seen_busy[i];
    if ((then & 1) && ma_atomic_load_32(&r->seen[i]->busy) == then) return 0;
  }
  return 1;
}

static void free_retired(Retired* r) {
  free(r->graph);
  if (r->route != NULL) {
    bridge_release(&r->route->bridge);
    free(r->route);
  }
  if (r->endpoint != NULL) free(r->endpoint->net);
  free(r->endpoint);
  free(r);
}

// Frees what no audio thread can still be reading — oldest first, and
// stopping at the first that may be, so an endpoint an older entry watches
// is never freed under it.
static void collect(HaloAudioEngine* e) {
  while (e->retired_head != NULL && quiescent(e->retired_head)) {
    Retired* r = e->retired_head;
    e->retired_head = r->next;
    if (e->retired_head == NULL) e->retired_tail = NULL;
    free_retired(r);
  }
}

// Queues [graph], [route] and [endpoint] (any may be NULL) to be freed once
// every open endpoint, and [endpoint] itself, has been outside its thread's
// callback since. A failed allocation leaks them rather than free them early.
static void retire(HaloAudioEngine* e, Graph* graph, Route* route, Endpoint* endpoint) {
  Retired* r = (Retired*)calloc(1, sizeof(Retired));
  if (r == NULL) return;
  r->graph = graph;
  r->route = route;
  r->endpoint = endpoint;
  for (int i = 0; i < ENGINE_MAX_ENDPOINTS; i++) {
    Endpoint* ep = e->endpoints[i];
    if (ep == NULL) continue;
    r->seen[r->seen_count] = ep;
    r->seen_busy[r->seen_count] = ma_atomic_load_32(&ep->busy);
    r->seen_count++;
  }
  if (endpoint != NULL && endpoint->kind != ENDPOINT_INPUT && endpoint->kind != ENDPOINT_OUTPUT) {
    // Not in the table any more, but a push or pull may still be inside it.
    r->seen[r->seen_count] = endpoint;
    r->seen_busy[r->seen_count] = ma_atomic_load_32(&endpoint->busy);
    r->seen_count++;
  }
  if (e->retired_tail != NULL) e->retired_tail->next = r;
  else e->retired_head = r;
  e->retired_tail = r;
}

static int route_goes(const Route* r, int32_t remove_route, int32_t remove_endpoint) {
  return r->id == remove_route || r->source == remove_endpoint || r->sink == remove_endpoint;
}

// Publishes the graph with [add] added and [remove_*] taken out, retiring
// the old one and every route taken out. -1 when it cannot be allocated,
// the graph left as it was.
static int publish(HaloAudioEngine* e, Route* add, int32_t remove_route, int32_t remove_endpoint) {
  Graph* old = current_graph(e);
  Graph* g = (Graph*)malloc(sizeof(Graph) + sizeof(Route*) * (size_t)(old->count + 1));
  if (g == NULL) return -1;
  g->count = 0;
  for (int i = 0; i < old->count; i++) {
    Route* r = old->routes[i];
    if (!route_goes(r, remove_route, remove_endpoint)) g->routes[g->count++] = r;
  }
  if (add != NULL) g->routes[g->count++] = add;
  ma_atomic_store_ptr(&e->graph, g);
  for (int i = 0; i < old->count; i++) {
    if (route_goes(old->routes[i], remove_route, remove_endpoint)) retire(e, NULL, old->routes[i], NULL);
  }
  retire(e, old, NULL, NULL);
  return 0;
}

// The table is written by the control side and read by whoever pushes or
// pulls, so its slots are atomic.
static Endpoint* slot(HaloAudioEngine* e, int i) { return (Endpoint*)ma_atomic_load_ptr(&e->endpoints[i]); }

static Endpoint* find_endpoint(HaloAudioEngine* e, int32_t id) {
  for (int i = 0; i < ENGINE_MAX_ENDPOINTS; i++) {
    Endpoint* ep = slot(e, i);
    if (ep != NULL && ep->id == id) return ep;
  }
  return NULL;
}

static Route* find_route(HaloAudioEngine* e, int32_t id) {
  Graph* g = current_graph(e);
  for (int i = 0; i < g->count; i++) {
    if (g->routes[i]->id == id) return g->routes[i];
  }
  return NULL;
}

static int is_source(const Endpoint* ep) { return ep->kind == ENDPOINT_INPUT || ep->kind == ENDPOINT_PUSHED || ep->kind == ENDPOINT_RECEIVED; }

HaloAudioEngine* halo_audio_engine_new(void) {
  HaloAudioEngine* e = (HaloAudioEngine*)calloc(1, sizeof(HaloAudioEngine));
  if (e == NULL) return NULL;
  Graph* g = (Graph*)calloc(1, sizeof(Graph));
  if (g == NULL) {
    free(e);
    return NULL;
  }
  e->graph = g;
  e->next_id = 1;
  return e;
}

static Endpoint* new_endpoint(HaloAudioEngine* e, int kind, int channels) {
  if (channels != 1 && channels != 2) return NULL;
  int free_slot = -1;
  for (int i = 0; i < ENGINE_MAX_ENDPOINTS; i++) {
    if (e->endpoints[i] == NULL) {
      free_slot = i;
      break;
    }
  }
  if (free_slot < 0) return NULL;
  Endpoint* ep = (Endpoint*)calloc(1, sizeof(Endpoint));
  if (ep == NULL) return NULL;
  ep->engine = e;
  ep->id = e->next_id++;
  ep->kind = kind;
  ep->channels = channels;
  ep->gate_open = 1;
  ep->gate_was_open = 1;
  ep->gate_gain = 1;
  ma_atomic_store_ptr(&e->endpoints[free_slot], ep);
  return ep;
}

static void drop_endpoint_slot(HaloAudioEngine* e, Endpoint* ep) {
  for (int i = 0; i < ENGINE_MAX_ENDPOINTS; i++) {
    if (e->endpoints[i] == ep) ma_atomic_store_ptr(&e->endpoints[i], NULL);
  }
}

static void device_callback(ma_device* device, void* output, const void* input, ma_uint32 frames) {
  Endpoint* ep = (Endpoint*)device->pUserData;
  if (ep->kind == ENDPOINT_INPUT) source_process(ep, (const float*)input, frames);
  else sink_process(ep, (float*)output, frames);
}

static void device_notification(const ma_device_notification* notification) {
  Endpoint* ep = (Endpoint*)notification->pDevice->pUserData;
  if (ep == NULL || ep->closing || ep->on_lost == 0) return;
  // A device stops by itself when it goes away — unplugged, or taken by
  // the system — and also when the system moves a default device to a new
  // default and starts it again. So this only tells the control side to
  // look: halo_audio_engine_endpoint_alive says which it was.
  if (notification->type == ma_device_notification_type_stopped) halo_audio_post(ep->on_lost, ep->lost_token);
}

static int32_t open_device(HaloAudioEngine* e, int kind, const char* device_id, int channels, HaloAudioPort on_lost, int64_t lost_token,
                           char* err, int err_len) {
  collect(e);
  ma_context* ctx = context();
  if (ctx == NULL) {
    set_error(err, err_len, "audio", MA_NO_BACKEND);
    return -1;
  }
  ma_device_id id;
  int named = id_from_hex(device_id, &id);
  if (named < 0) {
    set_error(err, err_len, "device id", MA_INVALID_ARGS);
    return -1;
  }
  Endpoint* ep = new_endpoint(e, kind, channels);
  if (ep == NULL) {
    set_error(err, err_len, "open device", MA_INVALID_ARGS);
    return -1;
  }
  ep->on_lost = on_lost;
  ep->lost_token = lost_token;

  ma_device_config config = ma_device_config_init(kind == ENDPOINT_INPUT ? ma_device_type_capture : ma_device_type_playback);
  if (kind == ENDPOINT_INPUT) {
    config.capture.pDeviceID = named ? &id : NULL;
    config.capture.format = ma_format_f32;
    config.capture.channels = (ma_uint32)channels;
  } else {
    config.playback.pDeviceID = named ? &id : NULL;
    config.playback.format = ma_format_f32;
    config.playback.channels = (ma_uint32)channels;
  }
  config.sampleRate = HALO_AUDIO_ENGINE_RATE;
  config.performanceProfile = ma_performance_profile_low_latency;
  config.periodSizeInMilliseconds = 5;
  config.dataCallback = device_callback;
  config.notificationCallback = device_notification;
  config.pUserData = ep;
  ma_result r = ma_device_init(ctx, &config, &ep->device);
  if (r != MA_SUCCESS) {
    set_error(err, err_len, "open device", r);
    drop_endpoint_slot(e, ep);
    free(ep);
    return -1;
  }
  ep->has_device = 1;
  r = ma_device_start(&ep->device);
  if (r != MA_SUCCESS) {
    set_error(err, err_len, "start device", r);
    ep->closing = MA_TRUE;
    ma_device_uninit(&ep->device);
    drop_endpoint_slot(e, ep);
    free(ep);
    return -1;
  }
  return ep->id;
}

int32_t halo_audio_engine_open_input(HaloAudioEngine* engine, const char* device_id, int channels, HaloAudioPort on_lost, int64_t lost_token,
                                     char* err, int err_len) {
  return open_device(engine, ENDPOINT_INPUT, device_id, channels, on_lost, lost_token, err, err_len);
}

int32_t halo_audio_engine_open_output(HaloAudioEngine* engine, const char* device_id, int channels, HaloAudioPort on_lost, int64_t lost_token,
                                      char* err, int err_len) {
  return open_device(engine, ENDPOINT_OUTPUT, device_id, channels, on_lost, lost_token, err, err_len);
}

int32_t halo_audio_engine_add_pushed(HaloAudioEngine* engine, int channels) {
  collect(engine);
  Endpoint* ep = new_endpoint(engine, ENDPOINT_PUSHED, channels);
  return ep == NULL ? -1 : ep->id;
}

int32_t halo_audio_engine_add_pulled(HaloAudioEngine* engine, int channels, int gated) {
  collect(engine);
  Endpoint* ep = new_endpoint(engine, ENDPOINT_PULLED, channels);
  if (ep == NULL) return -1;
  if (gated) {
    ep->gate_open = 0;
    ep->gate_was_open = 0;
    ep->gate_gain = 0;
  }
  return ep->id;
}

int halo_audio_engine_close_endpoint(HaloAudioEngine* engine, int32_t endpoint) {
  collect(engine);
  Endpoint* ep = find_endpoint(engine, endpoint);
  if (ep == NULL) return -1;
  if (ep->has_device) {
    ep->closing = MA_TRUE;
    // Waits out the device's callback: none runs after it.
    ma_device_uninit(&ep->device);
    ep->has_device = 0;
  }
  // A sender thread stopped, a receive thread's claim dropped: no network
  // thread touches it after this.
  net_endpoint_closing(ep);
  // Published while the endpoint is still in the table, so the old graph
  // and the routes it loses wait for its own thread too: a pull running on
  // another thread may be mixing them.
  if (publish(engine, NULL, -1, endpoint) != 0) {
    // The routes stay published, so the endpoint they name is kept too,
    // never freed: a leak, not a read of freed memory.
    return 0;
  }
  drop_endpoint_slot(engine, ep);
  retire(engine, NULL, NULL, ep);
  return 0;
}

int32_t halo_audio_engine_connect(HaloAudioEngine* engine, int32_t source, int32_t sink, int start_ms, int max_ms) {
  collect(engine);
  Endpoint* from = find_endpoint(engine, source);
  Endpoint* to = find_endpoint(engine, sink);
  if (from == NULL || to == NULL || from == to || !is_source(from) || is_source(to)) return -1;
  Route* route = (Route*)calloc(1, sizeof(Route));
  if (route == NULL) return -1;
  if (bridge_init(&route->bridge, from->channels, start_ms, max_ms) != 0) {
    free(route);
    return -1;
  }
  route->id = engine->next_id++;
  route->source = source;
  route->sink = sink;
  route->source_channels = from->channels;
  store_f32(&route->gain_left, 1);
  store_f32(&route->gain_right, 1);
  route->current_left = 1;
  route->current_right = 1;
  if (publish(engine, route, -1, -1) != 0) {
    bridge_release(&route->bridge);
    free(route);
    return -1;
  }
  return route->id;
}

int halo_audio_engine_disconnect(HaloAudioEngine* engine, int32_t route) {
  collect(engine);
  if (find_route(engine, route) == NULL) return -1;
  return publish(engine, NULL, route, -1);
}

int halo_audio_engine_set_gain(HaloAudioEngine* engine, int32_t route, float left, float right) {
  Route* r = find_route(engine, route);
  if (r == NULL) return -1;
  store_f32(&r->gain_left, left);
  store_f32(&r->gain_right, right);
  return 0;
}

int halo_audio_engine_set_gate(HaloAudioEngine* engine, int32_t sink, int open) {
  Endpoint* ep = find_endpoint(engine, sink);
  if (ep == NULL || is_source(ep)) return -1;
  ma_atomic_store_32(&ep->gate_open, open ? 1 : 0);
  return 0;
}

int halo_audio_engine_push(HaloAudioEngine* engine, int32_t source, const float* samples, int frames) {
  Endpoint* ep = find_endpoint(engine, source);
  if (ep == NULL || ep->kind != ENDPOINT_PUSHED || frames < 0) return -1;
  source_process(ep, samples, (ma_uint32)frames);
  return 0;
}

int halo_audio_engine_pull(HaloAudioEngine* engine, int32_t sink, float* out, int frames) {
  Endpoint* ep = find_endpoint(engine, sink);
  if (ep == NULL || ep->kind != ENDPOINT_PULLED || frames < 0) return -1;
  sink_process(ep, out, (ma_uint32)frames);
  return 0;
}

int halo_audio_engine_endpoint_alive(HaloAudioEngine* engine, int32_t endpoint) {
  Endpoint* ep = find_endpoint(engine, endpoint);
  if (ep == NULL) return -1;
  if (!ep->has_device) return 1;
  return ma_device_get_state(&ep->device) == ma_device_state_started ? 1 : 0;
}

int halo_audio_engine_route_stats(HaloAudioEngine* engine, int32_t route, double* out) {
  Route* r = find_route(engine, route);
  if (r == NULL) return -1;
  Bridge* b = &r->bridge;
  const double ms_per_frame = 1000.0 / HALO_AUDIO_ENGINE_RATE;
  out[HALO_AUDIO_ROUTE_STAT_DEPTH_MS] = load_f32(&b->stat_average) * ms_per_frame;
  out[HALO_AUDIO_ROUTE_STAT_TARGET_MS] = ma_atomic_load_32(&b->stat_target) * ms_per_frame;
  out[HALO_AUDIO_ROUTE_STAT_RATIO_PPM] = load_f32(&b->stat_ppm);
  out[HALO_AUDIO_ROUTE_STAT_UNDERRUNS] = ma_atomic_load_32(&b->stat_underruns);
  out[HALO_AUDIO_ROUTE_STAT_SKIPS] = ma_atomic_load_32(&b->stat_skips);
  out[HALO_AUDIO_ROUTE_STAT_DROPPED] = ma_atomic_load_32(&b->dropped);
  out[HALO_AUDIO_ROUTE_STAT_RUNNING] = ma_atomic_load_32(&b->stat_running);
  return 0;
}

float halo_audio_engine_take_peak(HaloAudioEngine* engine, int32_t endpoint) {
  Endpoint* ep = find_endpoint(engine, endpoint);
  if (ep == NULL) return -1;
  ma_uint32 bits = ma_atomic_exchange_32(&ep->peak, 0);
  float v;
  memcpy(&v, &bits, sizeof(v));
  return v;
}

void halo_audio_engine_free(HaloAudioEngine* engine) {
  if (engine == NULL) return;
  net_free_all(engine);
  for (int i = 0; i < ENGINE_MAX_ENDPOINTS; i++) {
    Endpoint* ep = engine->endpoints[i];
    if (ep != NULL && ep->has_device) {
      ep->closing = MA_TRUE;
      ma_device_uninit(&ep->device);
      ep->has_device = 0;
    }
  }
  // Nothing runs now: everything goes, retired or not.
  while (engine->retired_head != NULL) {
    Retired* r = engine->retired_head;
    engine->retired_head = r->next;
    free_retired(r);
  }
  Graph* g = current_graph(engine);
  for (int i = 0; i < g->count; i++) {
    bridge_release(&g->routes[i]->bridge);
    free(g->routes[i]);
  }
  free(g);
  for (int i = 0; i < ENGINE_MAX_ENDPOINTS; i++) {
    if (engine->endpoints[i] != NULL) free(engine->endpoints[i]->net);
    free(engine->endpoints[i]);
  }
  free(engine);
}
