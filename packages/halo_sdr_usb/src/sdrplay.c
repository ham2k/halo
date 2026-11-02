// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// See sdrplay.h. SDRplay's API is proprietary and not shipped here; the
// operator installs it with SDRplay's software, and this loads it at
// runtime. The declarations below are our own, written to the layout SDRplay
// publishes for API 3.x: only the calls made here, and only as much of each
// structure as is read or written, always through the API's own pointers —
// a structure the API allocates is never sized from these.
//
// The one exception is [sdrp_device], which GetDevices fills as an array and
// so must match the published size exactly.

#include "sdrplay.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#if defined(__APPLE__)

int32_t hsu_sdrplay_available(void) { return 0; }

int32_t hsu_sdrplay_open(hsu_device* device, const char* serial, uint32_t* rates, int32_t* rate_count, uint64_t* min_hz, uint64_t* max_hz,
                         void** handle, char* error, int32_t error_size) {
  (void)device;
  (void)serial;
  (void)rates;
  (void)rate_count;
  (void)min_hz;
  (void)max_hz;
  (void)handle;
  if (error != NULL && error_size > 0) snprintf(error, (size_t)error_size, "SDRplay's API cannot be loaded on macOS");
  return -1;
}

void hsu_sdrplay_close(void* handle) { (void)handle; }
int32_t hsu_sdrplay_set_sample_rate(void* handle, uint32_t rate) {
  (void)handle;
  (void)rate;
  return -1;
}
int32_t hsu_sdrplay_set_frequency(void* handle, uint64_t hz) {
  (void)handle;
  (void)hz;
  return -1;
}
int32_t hsu_sdrplay_set_gain(void* handle, int32_t step) {
  (void)handle;
  (void)step;
  return -1;
}
int32_t hsu_sdrplay_start(void* handle, hsu_device* device) {
  (void)handle;
  (void)device;
  return -1;
}
int32_t hsu_sdrplay_stop(void* handle) {
  (void)handle;
  return -1;
}
int32_t hsu_sdrplay_streaming(void* handle) {
  (void)handle;
  return HSU_STOPPED;
}

#else

#if defined(_WIN32)
#include <windows.h>
typedef HMODULE sdrp_lib;
#define SDRP_CALL __cdecl
#else
#include <dlfcn.h>
typedef void* sdrp_lib;
#define SDRP_CALL
#endif

#include <pthread.h>

// ---------------------------------------------------------------------------
// API 3.x, as published

enum {
  SDRP_SUCCESS = 0,
  SDRP_TUNER_A = 1,
  SDRP_RSPDUO_ID = 3,
  SDRP_RSPDUO_SINGLE_TUNER = 1,
  SDRP_UPDATE_DEV_FS = 0x00000001,
  SDRP_UPDATE_TUNER_FRF = 0x00020000,
  SDRP_UPDATE_TUNER_BW = 0x00040000,
  SDRP_UPDATE_CTRL_AGC = 0x01000000,
  SDRP_UPDATE_EXT1_NONE = 0,
  SDRP_AGC_50HZ = 2,
  SDRP_IF_ZERO = 0,
  SDRP_EVENT_DEVICE_REMOVED = 2,
  SDRP_EVENT_DEVICE_FAILURE = 4,
  SDRP_MAX_DEVICES = 16,
};

typedef struct {
  char serial[64];
  unsigned char hw_ver;
  int tuner;
  int rspduo_mode;
  unsigned char valid;
  double rspduo_sample_freq;
  void* dev;
} sdrp_device;

/// The head of DevParamsT: the device's sample rate.
typedef struct {
  double ppm;
  struct {
    double fs_hz;
    unsigned char sync_update;
    unsigned char re_cal;
  } fs;
} sdrp_dev_params;

/// The head of RxChannelParamsT: TunerParamsT, then ControlParamsT.
typedef struct {
  int bw_type;
  int if_type;
  int lo_mode;
  struct {
    int gr_db;
    unsigned char lna_state;
    unsigned char sync_update;
    int min_gr;
    struct {
      float curr;
      float max;
      float min;
    } values;
  } gain;
  struct {
    double rf_hz;
    unsigned char sync_update;
  } rf;
  struct {
    unsigned char dc_cal;
    unsigned char speed_up;
    int track_time;
    int refresh_rate_time;
  } dc_offset_tuner;
  struct {
    unsigned char dc_enable;
    unsigned char iq_enable;
  } dc_offset;
  struct {
    unsigned char enable;
    unsigned char factor;
    unsigned char wide_band;
  } decimation;
  struct {
    int enable;
    int set_point_dbfs;
    unsigned short attack_ms;
    unsigned short decay_ms;
    unsigned short decay_delay_ms;
    unsigned short decay_threshold_db;
    int sync_update;
  } agc;
} sdrp_channel_params;

typedef struct {
  sdrp_dev_params* dev;
  sdrp_channel_params* channel_a;
  sdrp_channel_params* channel_b;
} sdrp_device_params;

typedef struct {
  unsigned int first_sample;
  int gr_changed;
  int rf_changed;
  int fs_changed;
  unsigned int num_samples;
} sdrp_stream_params;

typedef void(SDRP_CALL* sdrp_stream_fn)(short* xi, short* xq, sdrp_stream_params* params, unsigned int count, unsigned int reset, void* ctx);
typedef void(SDRP_CALL* sdrp_event_fn)(int event, int tuner, void* params, void* ctx);

typedef struct {
  sdrp_stream_fn stream_a;
  sdrp_stream_fn stream_b;
  sdrp_event_fn event;
} sdrp_callbacks;

typedef int(SDRP_CALL* sdrp_void_fn)(void);
typedef int(SDRP_CALL* sdrp_version_fn)(float* version);
typedef int(SDRP_CALL* sdrp_get_devices_fn)(sdrp_device* devices, unsigned int* count, unsigned int max);
typedef int(SDRP_CALL* sdrp_select_fn)(sdrp_device* device);
typedef const char*(SDRP_CALL* sdrp_error_string_fn)(int error);
typedef int(SDRP_CALL* sdrp_get_params_fn)(void* dev, sdrp_device_params** params);
typedef int(SDRP_CALL* sdrp_init_fn)(void* dev, sdrp_callbacks* callbacks, void* ctx);
typedef int(SDRP_CALL* sdrp_uninit_fn)(void* dev);
typedef int(SDRP_CALL* sdrp_update_fn)(void* dev, int tuner, int reason, int reason_ext1);

static struct {
  int tried;
  sdrp_lib lib;
  sdrp_void_fn open;
  sdrp_void_fn close;
  sdrp_version_fn version;
  sdrp_void_fn lock;
  sdrp_void_fn unlock;
  sdrp_get_devices_fn get_devices;
  sdrp_select_fn select;
  sdrp_select_fn release;
  sdrp_error_string_fn error_string;
  sdrp_get_params_fn get_params;
  sdrp_init_fn init;
  sdrp_uninit_fn uninit;
  sdrp_update_fn update;
} api;

static pthread_mutex_t api_lock = PTHREAD_MUTEX_INITIALIZER;

/// sdrplay_api_Open and Close are for the process, not for a receiver: one
/// Close ends every receiver's session. So they are counted, and the API
/// closed only when the last user lets go.
static int api_users = 0;

/// Opens the API for one more user, checking its version the first time;
/// 0 on success, or the API's error, or -1 for a version this does not speak.
static int sdrp_acquire(float* version) {
  pthread_mutex_lock(&api_lock);
  int r = 0;
  if (api_users == 0) {
    r = api.open();
    if (r == 0 && (api.version(version) != 0 || *version < 3.0f || *version >= 4.0f)) {
      api.close();
      r = -1;
    }
  }
  if (r == 0) api_users++;
  pthread_mutex_unlock(&api_lock);
  return r;
}

static void sdrp_release(void) {
  pthread_mutex_lock(&api_lock);
  if (api_users > 0 && --api_users == 0) api.close();
  pthread_mutex_unlock(&api_lock);
}

static void* sdrp_symbol(const char* name) {
#if defined(_WIN32)
  return (void*)GetProcAddress(api.lib, name);
#else
  return dlsym(api.lib, name);
#endif
}

static sdrp_lib sdrp_load(void) {
#if defined(_WIN32)
  // Where SDRplay's installer puts it, then wherever the DLL search finds one.
  char path[MAX_PATH];
  DWORD size = sizeof(path);
  if (RegGetValueA(HKEY_LOCAL_MACHINE, "SOFTWARE\\SDRplay\\Service\\API", "Install_Dir", RRF_RT_REG_SZ, NULL, path, &size) == ERROR_SUCCESS) {
#if defined(_M_ARM64)
    const char* arch = "\\ARM64\\sdrplay_api.dll";
#else
    const char* arch = "\\x64\\sdrplay_api.dll";
#endif
    if (strlen(path) + strlen(arch) < sizeof(path)) {
      strcat(path, arch);
      HMODULE lib = LoadLibraryA(path);
      if (lib != NULL) return lib;
    }
  }
  return LoadLibraryA("sdrplay_api.dll");
#else
  void* lib = dlopen("libsdrplay_api.so.3", RTLD_NOW);
  if (lib == NULL) lib = dlopen("libsdrplay_api.so", RTLD_NOW);
  return lib;
#endif
}

/// Loads it once; 1 when every call made here is there and the version is
/// one whose layout this was written to.
static int sdrp_ready(void) {
  pthread_mutex_lock(&api_lock);
  if (!api.tried) {
    api.tried = 1;
    api.lib = sdrp_load();
    if (api.lib != NULL) {
      api.open = (sdrp_void_fn)sdrp_symbol("sdrplay_api_Open");
      api.close = (sdrp_void_fn)sdrp_symbol("sdrplay_api_Close");
      api.version = (sdrp_version_fn)sdrp_symbol("sdrplay_api_ApiVersion");
      api.lock = (sdrp_void_fn)sdrp_symbol("sdrplay_api_LockDeviceApi");
      api.unlock = (sdrp_void_fn)sdrp_symbol("sdrplay_api_UnlockDeviceApi");
      api.get_devices = (sdrp_get_devices_fn)sdrp_symbol("sdrplay_api_GetDevices");
      api.select = (sdrp_select_fn)sdrp_symbol("sdrplay_api_SelectDevice");
      api.release = (sdrp_select_fn)sdrp_symbol("sdrplay_api_ReleaseDevice");
      api.error_string = (sdrp_error_string_fn)sdrp_symbol("sdrplay_api_GetErrorString");
      api.get_params = (sdrp_get_params_fn)sdrp_symbol("sdrplay_api_GetDeviceParams");
      api.init = (sdrp_init_fn)sdrp_symbol("sdrplay_api_Init");
      api.uninit = (sdrp_uninit_fn)sdrp_symbol("sdrplay_api_Uninit");
      api.update = (sdrp_update_fn)sdrp_symbol("sdrplay_api_Update");
    }
  }
  int ready = api.lib != NULL && api.open && api.close && api.version && api.lock && api.unlock && api.get_devices && api.select && api.release &&
              api.error_string && api.get_params && api.init && api.uninit && api.update;
  pthread_mutex_unlock(&api_lock);
  return ready;
}

// ---------------------------------------------------------------------------
// One receiver

/// The rates offered, and the analog bandwidth each is paired with: always
/// narrower than the rate, so what is drawn is inside the filter.
static const uint32_t sdrp_rates[] = {2000000, 6000000, 8000000};
static const int sdrp_bandwidths[] = {1536, 5000, 7000};
#define SDRP_RATE_COUNT 3

typedef struct {
  sdrp_device device;
  sdrp_device_params* params;
  hsu_device* owner;
  volatile int streaming;
  volatile int lost;
} sdrp_receiver;

static void SDRP_CALL sdrp_stream(short* xi, short* xq, sdrp_stream_params* params, unsigned int count, unsigned int reset, void* ctx) {
  (void)params;
  (void)reset;
  sdrp_receiver* r = (sdrp_receiver*)ctx;
  hsu_ring_write_i16(r->owner, xi, xq, (int32_t)count);
}

static void SDRP_CALL sdrp_event(int event, int tuner, void* params, void* ctx) {
  (void)tuner;
  (void)params;
  sdrp_receiver* r = (sdrp_receiver*)ctx;
  if (event == SDRP_EVENT_DEVICE_REMOVED || event == SDRP_EVENT_DEVICE_FAILURE) r->lost = 1;
}

static void sdrp_put_error(char* error, int32_t size, const char* prefix, int code) {
  if (error == NULL || size <= 0) return;
  const char* why = api.error_string != NULL ? api.error_string(code) : NULL;
  snprintf(error, (size_t)size, "%s%s%s", prefix, why != NULL ? ": " : "", why != NULL ? why : "");
}

int32_t hsu_sdrplay_available(void) {
  if (!sdrp_ready()) return 0;
  float version = 0;
  if (sdrp_acquire(&version) != 0) return 0;
  sdrp_release();
  return 1;
}

int32_t hsu_sdrplay_open(hsu_device* device, const char* serial, uint32_t* rates, int32_t* rate_count, uint64_t* min_hz, uint64_t* max_hz,
                         void** handle, char* error, int32_t error_size) {
  if (!sdrp_ready()) {
    snprintf(error, (size_t)error_size, "SDRplay's API is not installed");
    return -1;
  }
  float version = 0;
  int r = sdrp_acquire(&version);
  if (r == -1) {
    snprintf(error, (size_t)error_size, "SDRplay's API is version %.2f; this app speaks 3.x", version);
    return -1;
  }
  if (r != SDRP_SUCCESS) {
    sdrp_put_error(error, error_size, "SDRplay's API would not open", r);
    return -1;
  }
  sdrp_device found[SDRP_MAX_DEVICES];
  unsigned int count = 0;
  memset(found, 0, sizeof(found));
  api.lock();
  r = api.get_devices(found, &count, SDRP_MAX_DEVICES);
  int pick = -1;
  for (unsigned int i = 0; r == SDRP_SUCCESS && i < count && pick < 0; i++) {
    if (serial == NULL || serial[0] == 0 || strcmp(found[i].serial, serial) == 0) pick = (int)i;
  }
  if (pick < 0) {
    api.unlock();
    sdrp_release();
    snprintf(error, (size_t)error_size, "%s", r == SDRP_SUCCESS ? "no SDRplay receiver found" : "SDRplay's API could not list receivers");
    return -1;
  }
  sdrp_receiver* receiver = (sdrp_receiver*)calloc(1, sizeof(sdrp_receiver));
  if (receiver == NULL) {
    api.unlock();
    sdrp_release();
    snprintf(error, (size_t)error_size, "out of memory");
    return -1;
  }
  receiver->device = found[pick];
  receiver->owner = device;
  // An RSPduo is used as one receiver, on its first tuner.
  if (receiver->device.hw_ver == SDRP_RSPDUO_ID) {
    receiver->device.tuner = SDRP_TUNER_A;
    receiver->device.rspduo_mode = SDRP_RSPDUO_SINGLE_TUNER;
  }
  r = api.select(&receiver->device);
  api.unlock();
  if (r != SDRP_SUCCESS) {
    sdrp_put_error(error, error_size, "the SDRplay receiver is in use", r);
    free(receiver);
    sdrp_release();
    return -1;
  }
  r = api.get_params(receiver->device.dev, &receiver->params);
  if (r != SDRP_SUCCESS || receiver->params == NULL || receiver->params->dev == NULL || receiver->params->channel_a == NULL) {
    sdrp_put_error(error, error_size, "SDRplay's API gave no settings", r);
    api.release(&receiver->device);
    free(receiver);
    sdrp_release();
    return -1;
  }
  sdrp_channel_params* channel = receiver->params->channel_a;
  receiver->params->dev->fs.fs_hz = sdrp_rates[0];
  channel->bw_type = sdrp_bandwidths[0];
  channel->if_type = SDRP_IF_ZERO;
  channel->agc.enable = SDRP_AGC_50HZ;
  for (int i = 0; i < SDRP_RATE_COUNT; i++) rates[i] = sdrp_rates[i];
  *rate_count = SDRP_RATE_COUNT;
  *min_hz = 1000ULL;
  *max_hz = 2000000000ULL;
  *handle = receiver;
  return 0;
}

static int32_t sdrp_apply(sdrp_receiver* receiver, int reason) {
  if (!receiver->streaming) return 0;
  return api.update(receiver->device.dev, receiver->device.tuner == 0 ? SDRP_TUNER_A : receiver->device.tuner, reason, SDRP_UPDATE_EXT1_NONE);
}

void hsu_sdrplay_close(void* handle) {
  sdrp_receiver* receiver = (sdrp_receiver*)handle;
  if (receiver == NULL) return;
  hsu_sdrplay_stop(receiver);
  api.lock();
  api.release(&receiver->device);
  api.unlock();
  sdrp_release();
  free(receiver);
}

int32_t hsu_sdrplay_set_sample_rate(void* handle, uint32_t rate) {
  sdrp_receiver* receiver = (sdrp_receiver*)handle;
  for (int i = 0; i < SDRP_RATE_COUNT; i++) {
    if (sdrp_rates[i] != rate) continue;
    receiver->params->dev->fs.fs_hz = rate;
    receiver->params->channel_a->bw_type = sdrp_bandwidths[i];
    return sdrp_apply(receiver, SDRP_UPDATE_DEV_FS | SDRP_UPDATE_TUNER_BW);
  }
  return -1;
}

int32_t hsu_sdrplay_set_frequency(void* handle, uint64_t hz) {
  sdrp_receiver* receiver = (sdrp_receiver*)handle;
  receiver->params->channel_a->rf.rf_hz = (double)hz;
  return sdrp_apply(receiver, SDRP_UPDATE_TUNER_FRF);
}

int32_t hsu_sdrplay_set_gain(void* handle, int32_t step) {
  // Its AGC, always: the gain reduction and LNA state it would otherwise
  // take differ by model and by band.
  (void)handle;
  (void)step;
  return 0;
}

int32_t hsu_sdrplay_start(void* handle, hsu_device* device) {
  sdrp_receiver* receiver = (sdrp_receiver*)handle;
  if (receiver->streaming) return 0;
  receiver->owner = device;
  receiver->lost = 0;
  sdrp_callbacks callbacks = {sdrp_stream, NULL, sdrp_event};
  int r = api.init(receiver->device.dev, &callbacks, receiver);
  if (r == SDRP_SUCCESS) receiver->streaming = 1;
  return r;
}

int32_t hsu_sdrplay_stop(void* handle) {
  sdrp_receiver* receiver = (sdrp_receiver*)handle;
  if (!receiver->streaming) return 0;
  receiver->streaming = 0;
  return api.uninit(receiver->device.dev);
}

int32_t hsu_sdrplay_streaming(void* handle) {
  sdrp_receiver* receiver = (sdrp_receiver*)handle;
  if (receiver->lost) return HSU_LOST;
  return receiver->streaming ? HSU_STREAMING : HSU_STOPPED;
}

#endif
