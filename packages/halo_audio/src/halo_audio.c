// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// See halo_audio.h. miniaudio is compiled into this translation unit, with
// everything above the device layer that the binding does not use left out.

#define MA_NO_ENGINE
#define MA_NO_NODE_GRAPH
#define MA_NO_RESOURCE_MANAGER
#define MA_NO_GENERATION
// Apple: link the frameworks rather than dlopen them, which notarization
// rejects (miniaudio.h § 2.2). The build files link CoreFoundation,
// CoreAudio and AudioToolbox.
#if defined(__APPLE__)
#define MA_NO_RUNTIME_LINKING
#endif
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio/miniaudio.h"

#include "halo_audio.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static ma_context g_context;
static int g_context_ready = 0;
static int g_null_backend = 0;

static ma_context* context(void) {
  if (g_context_ready) return &g_context;
  ma_result r;
  if (g_null_backend) {
    ma_backend backend = ma_backend_null;
    r = ma_context_init(&backend, 1, NULL, &g_context);
  } else {
    r = ma_context_init(NULL, 0, NULL, &g_context);
  }
  if (r != MA_SUCCESS) return NULL;
  g_context_ready = 1;
  return &g_context;
}

int halo_audio_use_null_backend(void) {
  if (g_context_ready) return -1;
  g_null_backend = 1;
  return 0;
}

static void set_error(char* err, int err_len, const char* what, ma_result r) {
  if (err == NULL || err_len <= 0) return;
  snprintf(err, (size_t)err_len, "%s: %s", what, ma_result_description(r));
}

// --- Device ids as hex ------------------------------------------------------

#define ID_HEX_LEN (2 * sizeof(ma_device_id) + 1)

static void id_to_hex(const ma_device_id* id, char* out) {
  const unsigned char* bytes = (const unsigned char*)id;
  size_t n = sizeof(ma_device_id);
  while (n > 0 && bytes[n - 1] == 0) n--;
  static const char digits[] = "0123456789abcdef";
  for (size_t i = 0; i < n; i++) {
    out[2 * i] = digits[bytes[i] >> 4];
    out[2 * i + 1] = digits[bytes[i] & 0xf];
  }
  out[2 * n] = 0;
}

static int hex_value(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

// 1 when [hex] named a device, 0 for the default (NULL or empty), -1 when
// it is not an id this binding wrote.
static int id_from_hex(const char* hex, ma_device_id* out) {
  memset(out, 0, sizeof(*out));
  if (hex == NULL || hex[0] == 0) return 0;
  size_t len = strlen(hex);
  if (len % 2 != 0 || len / 2 > sizeof(ma_device_id)) return -1;
  unsigned char* bytes = (unsigned char*)out;
  for (size_t i = 0; i < len / 2; i++) {
    int hi = hex_value(hex[2 * i]), lo = hex_value(hex[2 * i + 1]);
    if (hi < 0 || lo < 0) return -1;
    bytes[i] = (unsigned char)(hi << 4 | lo);
  }
  return 1;
}

// --- Enumeration --------------------------------------------------------------

typedef struct {
  char id[ID_HEX_LEN];
  char name[MA_MAX_DEVICE_NAME_LENGTH + 1];
  int is_default;
} DeviceEntry;

static DeviceEntry* g_devices[2] = {NULL, NULL};
static int g_device_count[2] = {0, 0};

int halo_audio_enumerate(int capture) {
  int which = capture ? 1 : 0;
  ma_context* ctx = context();
  if (ctx == NULL) return -1;
  ma_device_info *playback, *captures;
  ma_uint32 playback_count, capture_count;
  if (ma_context_get_devices(ctx, &playback, &playback_count, &captures, &capture_count) != MA_SUCCESS) return -1;
  ma_device_info* infos = which ? captures : playback;
  ma_uint32 count = which ? capture_count : playback_count;

  free(g_devices[which]);
  g_devices[which] = count > 0 ? (DeviceEntry*)calloc(count, sizeof(DeviceEntry)) : NULL;
  if (count > 0 && g_devices[which] == NULL) {
    g_device_count[which] = 0;
    return -1;
  }
  for (ma_uint32 i = 0; i < count; i++) {
    id_to_hex(&infos[i].id, g_devices[which][i].id);
    strncpy(g_devices[which][i].name, infos[i].name, MA_MAX_DEVICE_NAME_LENGTH);
    g_devices[which][i].is_default = infos[i].isDefault ? 1 : 0;
  }
  g_device_count[which] = (int)count;
  return (int)count;
}

static DeviceEntry* entry(int capture, int index) {
  int which = capture ? 1 : 0;
  if (index < 0 || index >= g_device_count[which]) return NULL;
  return &g_devices[which][index];
}

const char* halo_audio_device_id(int capture, int index) {
  DeviceEntry* e = entry(capture, index);
  return e ? e->id : "";
}

const char* halo_audio_device_name(int capture, int index) {
  DeviceEntry* e = entry(capture, index);
  return e ? e->name : "";
}

int halo_audio_device_is_default(int capture, int index) {
  DeviceEntry* e = entry(capture, index);
  return e ? e->is_default : 0;
}

// --- Files --------------------------------------------------------------------

// miniaudio's char* file functions take the platform's narrow encoding,
// which on Windows is the ANSI code page, not UTF-8: a path under a user
// name outside it would not open. The wide variants take UTF-16.
#if defined(_WIN32)
static wchar_t* wide_path(const char* path) {
  int n = MultiByteToWideChar(CP_UTF8, 0, path, -1, NULL, 0);
  if (n <= 0) return NULL;
  wchar_t* wide = (wchar_t*)malloc(sizeof(wchar_t) * (size_t)n);
  if (wide != NULL) MultiByteToWideChar(CP_UTF8, 0, path, -1, wide, n);
  return wide;
}
#endif

static ma_result decoder_open(const char* path, const ma_decoder_config* config, ma_decoder* decoder) {
#if defined(_WIN32)
  wchar_t* wide = wide_path(path);
  if (wide == NULL) return MA_INVALID_ARGS;
  ma_result r = ma_decoder_init_file_w(wide, config, decoder);
  free(wide);
  return r;
#else
  return ma_decoder_init_file(path, config, decoder);
#endif
}

static ma_result encoder_open(const char* path, const ma_encoder_config* config, ma_encoder* encoder) {
#if defined(_WIN32)
  wchar_t* wide = wide_path(path);
  if (wide == NULL) return MA_INVALID_ARGS;
  ma_result r = ma_encoder_init_file_w(wide, config, encoder);
  free(wide);
  return r;
#else
  return ma_encoder_init_file(path, config, encoder);
#endif
}

int64_t halo_audio_file_length_ms(const char* path) {
  ma_decoder decoder;
  ma_decoder_config config = ma_decoder_config_init(ma_format_f32, 0, 0);
  if (decoder_open(path, &config, &decoder) != MA_SUCCESS) return -1;
  ma_uint64 frames = 0;
  ma_result r = ma_decoder_get_length_in_pcm_frames(&decoder, &frames);
  ma_uint32 rate = decoder.outputSampleRate;
  ma_decoder_uninit(&decoder);
  if (r != MA_SUCCESS || rate == 0) return -1;
  return (int64_t)(frames * 1000 / rate);
}

int64_t halo_audio_decode(const char* path, int rate, int channels, float** out, char* err, int err_len) {
  *out = NULL;
  ma_decoder decoder;
  ma_decoder_config config = ma_decoder_config_init(ma_format_f32, (ma_uint32)channels, (ma_uint32)rate);
  ma_result r = decoder_open(path, &config, &decoder);
  if (r != MA_SUCCESS) {
    set_error(err, err_len, "open file", r);
    return -1;
  }
  const ma_uint64 chunk = 4096;
  ma_uint64 frames = 0, capacity = 0;
  float* samples = NULL;
  for (;;) {
    if (frames + chunk > capacity) {
      capacity = capacity == 0 ? (ma_uint64)rate : capacity * 2;
      float* grown = (float*)realloc(samples, (size_t)(capacity * (ma_uint64)channels * sizeof(float)));
      if (grown == NULL) {
        free(samples);
        ma_decoder_uninit(&decoder);
        set_error(err, err_len, "decode", MA_OUT_OF_MEMORY);
        return -1;
      }
      samples = grown;
    }
    ma_uint64 read = 0;
    r = ma_decoder_read_pcm_frames(&decoder, samples + frames * (ma_uint64)channels, chunk, &read);
    frames += read;
    if (r != MA_SUCCESS || read < chunk) break;
  }
  ma_decoder_uninit(&decoder);
  *out = samples;
  return (int64_t)frames;
}

void halo_audio_free(void* buffer) { free(buffer); }

// Windows above the line this close together are one sound (150 ms).
#define SOUND_GAP_WINDOWS 15

static int compare_floats(const void* a, const void* b) {
  float x = *(const float*)a, y = *(const float*)b;
  return x < y ? -1 : (x > y ? 1 : 0);
}

int halo_audio_normalize(const char* from, const char* to, float peak, float max_gain, float trim_above_floor_db, float trim_below_loudest_db, int min_sound_ms,
                         int lead_ms, int tail_ms, int cut_end_ms, char* err, int err_len) {
  ma_decoder decoder;
  ma_decoder_config decoder_config = ma_decoder_config_init(ma_format_s16, 0, 0);
  ma_result r = decoder_open(from, &decoder_config, &decoder);
  if (r != MA_SUCCESS) {
    set_error(err, err_len, "open file", r);
    return -1;
  }
  ma_uint32 channels = decoder.outputChannels;
  ma_uint32 rate = decoder.outputSampleRate;
  // Read whole: a message is a minute at most, about 6 MB, and the loudest
  // sample has to be known before the first one is written.
  const ma_uint64 chunk = 4096;
  ma_uint64 frames = 0, capacity = 0;
  ma_int16* samples = NULL;
  for (;;) {
    if (frames + chunk > capacity) {
      capacity = capacity == 0 ? 48000 : capacity * 2;
      ma_int16* grown = (ma_int16*)realloc(samples, (size_t)(capacity * channels * sizeof(ma_int16)));
      if (grown == NULL) {
        free(samples);
        ma_decoder_uninit(&decoder);
        set_error(err, err_len, "normalize", MA_OUT_OF_MEMORY);
        return -1;
      }
      samples = grown;
    }
    ma_uint64 read = 0;
    r = ma_decoder_read_pcm_frames(&decoder, samples + frames * channels, chunk, &read);
    frames += read;
    if (r != MA_SUCCESS || read < chunk) break;
  }
  ma_decoder_uninit(&decoder);

  // Dropped before anything is measured: what is there is the press of
  // Stop, whatever its length.
  if (trim_above_floor_db > 0.0f && cut_end_ms > 0) {
    const ma_uint64 cut = (ma_uint64)cut_end_ms * rate / 1000;
    frames = frames > cut ? frames - cut : 0;
  }

  int loudest = 0;
  for (ma_uint64 i = 0; i < frames * channels; i++) {
    int v = samples[i] < 0 ? -(int)samples[i] : samples[i];
    if (v > loudest) loudest = v;
  }

  // The first and last 10 ms windows with sound in them: louder, by RMS,
  // than the room's own noise by [trim_above_floor_db] — the floor being the
  // quietest tenth of the windows — but never asked to come within
  // [trim_below_loudest_db] of the loudest window, or a recording with
  // little room in it would have its soft speech taken for the floor.
  ma_uint64 first = 0, last = frames, heard_from = 0, heard_to = frames;
  if (trim_above_floor_db > 0.0f && loudest > 0 && frames > 0) {
    const ma_uint64 window = rate / 100 > 0 ? rate / 100 : 1;
    const ma_uint64 count = (frames + window - 1) / window;
    float* rms = (float*)malloc((size_t)count * sizeof(float));
    float* sorted = (float*)malloc((size_t)count * sizeof(float));
    if (rms == NULL || sorted == NULL) {
      free(rms);
      free(sorted);
      free(samples);
      set_error(err, err_len, "normalize", MA_OUT_OF_MEMORY);
      return -1;
    }
    float loudest_rms = 0.0f;
    for (ma_uint64 w = 0; w < count; w++) {
      ma_uint64 from_frame = w * window, to_frame = from_frame + window < frames ? from_frame + window : frames;
      double sum = 0.0;
      for (ma_uint64 i = from_frame * channels; i < to_frame * channels; i++) sum += (double)samples[i] * (double)samples[i];
      rms[w] = (float)sqrt(sum / (double)((to_frame - from_frame) * channels));
      sorted[w] = rms[w];
      if (rms[w] > loudest_rms) loudest_rms = rms[w];
    }
    qsort(sorted, (size_t)count, sizeof(float), compare_floats);
    const float floor_rms = sorted[count / 10];
    free(sorted);
    float threshold = floor_rms * powf(10.0f, trim_above_floor_db / 20.0f);
    const float ceiling = loudest_rms * powf(10.0f, -trim_below_loudest_db / 20.0f);
    if (threshold > ceiling) threshold = ceiling;
    // Sound is a region at least [min_sound_ms] long, a region being such
    // windows at most SOUND_GAP_WINDOWS apart: a soft syllable dips under
    // the line between its parts and is still one sound, while a mouse
    // click on Record or Stop, with room either side of it, is shorter than
    // any word and would hold the room beside it in.
    const ma_uint64 min_span = min_sound_ms > 0 ? ((ma_uint64)min_sound_ms + 9) / 10 : 1;
    heard_from = frames;
    heard_to = 0;
    ma_uint64 region_from = 0, region_to = 0;
    int in_region = 0;
    for (ma_uint64 w = 0; w <= count; w++) {
      const int loud_enough = w < count && rms[w] >= threshold;
      if (loud_enough && in_region && w - region_to <= SOUND_GAP_WINDOWS) {
        region_to = w + 1;
        continue;
      }
      if (in_region && (loud_enough || w == count || w - region_to > SOUND_GAP_WINDOWS)) {
        if (region_to - region_from >= min_span) {
          if (heard_from == frames) heard_from = region_from * window;
          heard_to = region_to * window < frames ? region_to * window : frames;
        }
        in_region = 0;
      }
      if (loud_enough) {
        region_from = w;
        region_to = w + 1;
        in_region = 1;
      }
    }
    free(rms);
    // Nothing long enough to be sound: kept whole rather than cut to nothing.
    if (heard_from == frames) {
      heard_from = 0;
      heard_to = frames;
    }
    const ma_uint64 lead = (ma_uint64)lead_ms * rate / 1000, tail = (ma_uint64)tail_ms * rate / 1000;
    first = heard_from > lead ? heard_from - lead : 0;
    last = heard_to + tail < frames ? heard_to + tail : frames;
  }
  ma_int16* kept = samples + first * channels;
  frames = last - first;

  // The peak of what is kept: a click on Record trimmed away would otherwise
  // set the gain, and leave the voice as quiet as before.
  loudest = 0;
  for (ma_uint64 i = 0; i < frames * channels; i++) {
    int v = kept[i] < 0 ? -(int)kept[i] : kept[i];
    if (v > loudest) loudest = v;
  }

  float gain = loudest == 0 ? 1.0f : peak * 32767.0f / (float)loudest;
  if (gain > max_gain) gain = max_gain;
  if (gain > 1.0f) {
    for (ma_uint64 i = 0; i < frames * channels; i++) {
      float v = (float)kept[i] * gain;
      v += v < 0 ? -0.5f : 0.5f;
      kept[i] = (ma_int16)(v > 32767.0f ? 32767.0f : (v < -32768.0f ? -32768.0f : v));
    }
  }

  // The margins kept around the sound fade in and out: what room is left in
  // them comes and goes rather than switching on and off.
  if (heard_from > first) {
    const ma_uint64 fade = heard_from - first;
    for (ma_uint64 f = 0; f < fade; f++) {
      for (ma_uint32 c = 0; c < channels; c++) kept[f * channels + c] = (ma_int16)((float)kept[f * channels + c] * (float)f / (float)fade);
    }
  }
  if (last > heard_to) {
    const ma_uint64 fade = last - heard_to, from_frame = heard_to - first;
    for (ma_uint64 f = 0; f < fade; f++) {
      for (ma_uint32 c = 0; c < channels; c++) {
        kept[(from_frame + f) * channels + c] = (ma_int16)((float)kept[(from_frame + f) * channels + c] * (float)(fade - f) / (float)fade);
      }
    }
  }

  ma_encoder encoder;
  ma_encoder_config encoder_config = ma_encoder_config_init(ma_encoding_format_wav, ma_format_s16, channels, rate);
  r = encoder_open(to, &encoder_config, &encoder);
  if (r != MA_SUCCESS) {
    free(samples);
    set_error(err, err_len, "create file", r);
    return -1;
  }
  ma_uint64 written = 0;
  r = ma_encoder_write_pcm_frames(&encoder, kept, frames, &written);
  ma_encoder_uninit(&encoder);
  free(samples);
  if (r != MA_SUCCESS || written != frames) {
    set_error(err, err_len, "write file", r != MA_SUCCESS ? r : MA_ERROR);
    return -1;
  }
  return 0;
}

// --- Playback -----------------------------------------------------------------

// Every output plays this one format; the decoder converts each file to it
// and the device converts it to its own.
#define OUTPUT_FORMAT ma_format_f32
#define OUTPUT_CHANNELS 1
#define OUTPUT_RATE 48000

struct HaloAudioOutput {
  ma_device device;
  // Guards the four fields below, which the audio thread reads every
  // period: a play or a stop swaps the decoder under it, and the callback
  // reads frames under it.
  ma_spinlock lock;
  ma_decoder* decoder;
  ma_bool32 ended;
  HaloAudioEndFn on_end;
  int64_t token;
  HaloAudioEndFn on_lost;
  int64_t lost_token;
  volatile ma_bool32 closing;
};

static void output_callback(ma_device* device, void* output, const void* input, ma_uint32 frames) {
  (void)input;
  HaloAudioOutput* out = (HaloAudioOutput*)device->pUserData;
  HaloAudioEndFn ended_fn = NULL;
  int64_t ended_token = 0;
  ma_spinlock_lock(&out->lock);
  if (out->decoder != NULL && !out->ended) {
    ma_uint64 read = 0;
    ma_decoder_read_pcm_frames(out->decoder, output, frames, &read);
    if (read < frames) {
      out->ended = MA_TRUE;
      ended_fn = out->on_end;
      ended_token = out->token;
    }
  }
  ma_spinlock_unlock(&out->lock);
  // Outside the lock: the binding's callback only posts a message, but it
  // is still not the audio thread's business to hold the lock through it.
  if (ended_fn != NULL) ended_fn(ended_token);
}

static void output_notification(const ma_device_notification* notification) {
  HaloAudioOutput* out = (HaloAudioOutput*)notification->pDevice->pUserData;
  if (out == NULL || out->closing || out->on_lost == NULL) return;
  // A device stops by itself when it goes away — unplugged, or taken by
  // the system — and that is the only stop this binding does not ask for.
  if (notification->type == ma_device_notification_type_stopped) out->on_lost(out->lost_token);
}

HaloAudioOutput* halo_audio_output_open(const char* device_id, HaloAudioEndFn on_lost, int64_t lost_token, char* err, int err_len) {
  ma_context* ctx = context();
  if (ctx == NULL) {
    set_error(err, err_len, "audio", MA_NO_BACKEND);
    return NULL;
  }
  ma_device_id id;
  int named = id_from_hex(device_id, &id);
  if (named < 0) {
    set_error(err, err_len, "device id", MA_INVALID_ARGS);
    return NULL;
  }
  HaloAudioOutput* out = (HaloAudioOutput*)calloc(1, sizeof(HaloAudioOutput));
  if (out == NULL) {
    set_error(err, err_len, "open device", MA_OUT_OF_MEMORY);
    return NULL;
  }
  out->on_lost = on_lost;
  out->lost_token = lost_token;

  ma_device_config config = ma_device_config_init(ma_device_type_playback);
  config.playback.pDeviceID = named ? &id : NULL;
  config.playback.format = OUTPUT_FORMAT;
  config.playback.channels = OUTPUT_CHANNELS;
  config.sampleRate = OUTPUT_RATE;
  config.dataCallback = output_callback;
  config.notificationCallback = output_notification;
  config.pUserData = out;
  ma_result r = ma_device_init(ctx, &config, &out->device);
  if (r != MA_SUCCESS) {
    set_error(err, err_len, "open device", r);
    free(out);
    return NULL;
  }
  r = ma_device_start(&out->device);
  if (r != MA_SUCCESS) {
    set_error(err, err_len, "start device", r);
    out->closing = MA_TRUE;
    ma_device_uninit(&out->device);
    free(out);
    return NULL;
  }
  return out;
}

int halo_audio_output_alive(HaloAudioOutput* out) {
  return out != NULL && ma_device_get_state(&out->device) == ma_device_state_started ? 1 : 0;
}

static void decoder_free(ma_decoder* decoder) {
  if (decoder == NULL) return;
  ma_decoder_uninit(decoder);
  free(decoder);
}

int halo_audio_output_play(HaloAudioOutput* out, const char* path, HaloAudioEndFn on_end, int64_t token, char* err, int err_len) {
  ma_decoder* decoder = (ma_decoder*)calloc(1, sizeof(ma_decoder));
  if (decoder == NULL) {
    set_error(err, err_len, "play", MA_OUT_OF_MEMORY);
    return -1;
  }
  // Opened before the swap, so the audio thread never waits on a file.
  ma_decoder_config config = ma_decoder_config_init(OUTPUT_FORMAT, OUTPUT_CHANNELS, OUTPUT_RATE);
  ma_result r = decoder_open(path, &config, decoder);
  if (r != MA_SUCCESS) {
    set_error(err, err_len, "open file", r);
    free(decoder);
    return -1;
  }
  ma_spinlock_lock(&out->lock);
  ma_decoder* previous = out->decoder;
  out->decoder = decoder;
  out->ended = MA_FALSE;
  out->on_end = on_end;
  out->token = token;
  ma_spinlock_unlock(&out->lock);
  decoder_free(previous);
  return 0;
}

void halo_audio_output_stop(HaloAudioOutput* out) {
  if (out == NULL) return;
  ma_spinlock_lock(&out->lock);
  ma_decoder* previous = out->decoder;
  out->decoder = NULL;
  out->on_end = NULL;
  ma_spinlock_unlock(&out->lock);
  decoder_free(previous);
}

void halo_audio_output_close(HaloAudioOutput* out) {
  if (out == NULL) return;
  out->closing = MA_TRUE;
  ma_device_uninit(&out->device);
  decoder_free(out->decoder);
  free(out);
}

// --- Recording ----------------------------------------------------------------

struct HaloAudioRecorder {
  ma_encoder encoder;
  ma_device device;
  volatile float peak;  // written by the audio thread, read and reset by the caller
};

static void record_callback(ma_device* device, void* output, const void* input, ma_uint32 frames) {
  (void)output;
  HaloAudioRecorder* recorder = (HaloAudioRecorder*)device->pUserData;
  ma_encoder_write_pcm_frames(&recorder->encoder, input, frames, NULL);
  const ma_int16* samples = (const ma_int16*)input;
  int loudest = 0;
  for (ma_uint32 i = 0; i < frames; i++) {
    int s = samples[i] < 0 ? -(int)samples[i] : samples[i];
    if (s > loudest) loudest = s;
  }
  float level = (float)loudest / 32768.0f;
  if (level > recorder->peak) recorder->peak = level;
}

HaloAudioRecorder* halo_audio_record(const char* path, const char* device_id, char* err, int err_len) {
  ma_context* ctx = context();
  if (ctx == NULL) {
    set_error(err, err_len, "audio", MA_NO_BACKEND);
    return NULL;
  }
  ma_device_id id;
  int named = id_from_hex(device_id, &id);
  if (named < 0) {
    set_error(err, err_len, "device id", MA_INVALID_ARGS);
    return NULL;
  }
  HaloAudioRecorder* recorder = (HaloAudioRecorder*)calloc(1, sizeof(HaloAudioRecorder));
  if (recorder == NULL) {
    set_error(err, err_len, "record", MA_OUT_OF_MEMORY);
    return NULL;
  }

  ma_encoder_config encoder_config = ma_encoder_config_init(ma_encoding_format_wav, ma_format_s16, 1, 48000);
  ma_result r = encoder_open(path, &encoder_config, &recorder->encoder);
  if (r != MA_SUCCESS) {
    set_error(err, err_len, "create file", r);
    free(recorder);
    return NULL;
  }

  ma_device_config config = ma_device_config_init(ma_device_type_capture);
  config.capture.pDeviceID = named ? &id : NULL;
  config.capture.format = ma_format_s16;
  config.capture.channels = 1;
  config.sampleRate = 48000;
  config.dataCallback = record_callback;
  config.pUserData = recorder;
  r = ma_device_init(ctx, &config, &recorder->device);
  if (r != MA_SUCCESS) {
    set_error(err, err_len, "open device", r);
    ma_encoder_uninit(&recorder->encoder);
    free(recorder);
    return NULL;
  }
  r = ma_device_start(&recorder->device);
  if (r != MA_SUCCESS) {
    set_error(err, err_len, "start device", r);
    ma_device_uninit(&recorder->device);
    ma_encoder_uninit(&recorder->encoder);
    free(recorder);
    return NULL;
  }
  return recorder;
}

float halo_audio_recorder_take_peak(HaloAudioRecorder* recorder) {
  if (recorder == NULL) return 0;
  float peak = recorder->peak;
  recorder->peak = 0;
  return peak;
}

void halo_audio_recorder_free(HaloAudioRecorder* recorder) {
  if (recorder == NULL) return;
  ma_device_uninit(&recorder->device);
  ma_encoder_uninit(&recorder->encoder);
  free(recorder);
}
