// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The few POSIX thread calls libairspy, libairspyhf and our shim make, on
// Win32's own threads, locks and condition variables. MSVC has no
// pthread.h; on the include path only for a Windows build (src/CMakeLists.txt),
// where it stands in for the pthreads-win32 Airspy's own Windows builds use.
//
// Only what those three call is here. A call this lacks is a compile error
// on Windows, never a silent stub.

#ifndef HALO_SDR_USB_WIN32_PTHREAD_H
#define HALO_SDR_USB_WIN32_PTHREAD_H

#include <windows.h>
#include <errno.h>
#include <process.h>
#include <stdlib.h>

typedef HANDLE pthread_t;
typedef int pthread_attr_t;
typedef SRWLOCK pthread_mutex_t;
typedef CONDITION_VARIABLE pthread_cond_t;

#define PTHREAD_MUTEX_INITIALIZER SRWLOCK_INIT
#define PTHREAD_CREATE_JOINABLE 0
#define PTHREAD_CREATE_DETACHED 1

typedef struct {
  void* (*start)(void*);
  void* arg;
} hsu_pthread_start_t;

static unsigned __stdcall hsu_pthread_trampoline(void* param) {
  hsu_pthread_start_t start = *(hsu_pthread_start_t*)param;
  free(param);
  start.start(start.arg);
  return 0;
}

static __inline int pthread_create(pthread_t* thread, const pthread_attr_t* attr, void* (*start)(void*), void* arg) {
  (void)attr;
  hsu_pthread_start_t* param = (hsu_pthread_start_t*)malloc(sizeof(hsu_pthread_start_t));
  if (param == NULL) return ENOMEM;
  param->start = start;
  param->arg = arg;
  uintptr_t handle = _beginthreadex(NULL, 0, hsu_pthread_trampoline, param, 0, NULL);
  if (handle == 0) {
    free(param);
    return EAGAIN;
  }
  *thread = (HANDLE)handle;
  return 0;
}

static __inline int pthread_join(pthread_t thread, void** result) {
  WaitForSingleObject(thread, INFINITE);
  CloseHandle(thread);
  if (result != NULL) *result = NULL;
  return 0;
}

static __inline int pthread_attr_init(pthread_attr_t* attr) {
  *attr = PTHREAD_CREATE_JOINABLE;
  return 0;
}

static __inline int pthread_attr_setdetachstate(pthread_attr_t* attr, int state) {
  *attr = state;
  return 0;
}

static __inline int pthread_attr_destroy(pthread_attr_t* attr) {
  (void)attr;
  return 0;
}

static __inline int pthread_mutex_init(pthread_mutex_t* mutex, const void* attr) {
  (void)attr;
  InitializeSRWLock(mutex);
  return 0;
}

static __inline int pthread_mutex_destroy(pthread_mutex_t* mutex) {
  (void)mutex;
  return 0;
}

static __inline int pthread_mutex_lock(pthread_mutex_t* mutex) {
  AcquireSRWLockExclusive(mutex);
  return 0;
}

static __inline int pthread_mutex_unlock(pthread_mutex_t* mutex) {
  ReleaseSRWLockExclusive(mutex);
  return 0;
}

static __inline int pthread_cond_init(pthread_cond_t* cond, const void* attr) {
  (void)attr;
  InitializeConditionVariable(cond);
  return 0;
}

static __inline int pthread_cond_destroy(pthread_cond_t* cond) {
  (void)cond;
  return 0;
}

static __inline int pthread_cond_wait(pthread_cond_t* cond, pthread_mutex_t* mutex) {
  return SleepConditionVariableSRW(cond, mutex, INFINITE, 0) ? 0 : EINVAL;
}

static __inline int pthread_cond_signal(pthread_cond_t* cond) {
  WakeConditionVariable(cond);
  return 0;
}

static __inline int pthread_cond_broadcast(pthread_cond_t* cond) {
  WakeAllConditionVariable(cond);
  return 0;
}

#endif
